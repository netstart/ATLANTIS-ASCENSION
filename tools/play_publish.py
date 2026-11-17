"""Consulta e promove versões na Google Play (API Android Publisher v3), para o CI.

Credenciais: JSON da conta de serviço na variável PLAY_SERVICE_ACCOUNT_JSON ou em --key ARQUIVO.
Precisa de google-auth e requests (pip install google-auth requests).

  python tools/play_publish.py has-version 37        # imprime true ou false
  python tools/play_publish.py promote --from alpha --to production --fraction 0.2 [--dry-run]
"""

from __future__ import annotations

import argparse
import json
import os
import sys

PACKAGE = "io.github.netstart.atlantisascension"
API = f"https://androidpublisher.googleapis.com/androidpublisher/v3/applications/{PACKAGE}/edits"
SCOPE = "https://www.googleapis.com/auth/androidpublisher"
NO_PRODUCTION = ("a conta ainda não tem acesso à produção (teste fechado com 12 testadores por 14 dias, "
                 "depois 'Solicitar acesso à produção' no Play Console)")


class PlayError(Exception):
    def __init__(self, status: str, message: str) -> None:
        super().__init__(message)
        self.status = status


def session(key_path: str | None):
    from google.auth.transport.requests import AuthorizedSession
    from google.oauth2 import service_account

    if key_path:
        with open(key_path, encoding="utf-8") as f:
            info = json.load(f)
    elif os.environ.get("PLAY_SERVICE_ACCOUNT_JSON"):
        info = json.loads(os.environ["PLAY_SERVICE_ACCOUNT_JSON"])
    else:
        raise PlayError("", "sem credenciais: defina PLAY_SERVICE_ACCOUNT_JSON ou passe --key")
    return AuthorizedSession(service_account.Credentials.from_service_account_info(info, scopes=[SCOPE]))


def call(http, method: str, path: str = "", body: dict | None = None) -> dict:
    r = http.request(method, API + path, json=body, timeout=60)
    if r.status_code >= 400:
        try:
            err = r.json()["error"]
            raise PlayError(err.get("status", ""), f"{err.get('code', r.status_code)} {err.get('status', '')}: "
                                                   f"{err.get('message', '')}")
        except (ValueError, KeyError):
            raise PlayError("", f"HTTP {r.status_code}: {r.text[:500]}") from None
    return r.json() if r.content else {}


def has_version(http, code: int) -> bool:
    edit = call(http, "POST")["id"]
    try:
        for track in call(http, "GET", f"/{edit}/tracks").get("tracks", []):
            for release in track.get("releases", []):
                if str(code) in release.get("versionCodes", []):
                    return True
        return False
    finally:
        call(http, "DELETE", f"/{edit}")


def promote(http, source: str, target: str, fraction: float, dry_run: bool) -> None:
    edit = call(http, "POST")["id"]
    committed = False
    try:
        releases = [r for r in call(http, "GET", f"/{edit}/tracks/{source}").get("releases", [])
                    if r.get("versionCodes")]
        if not releases:
            raise PlayError("", f"a faixa {source} não tem versão para promover")
        latest = max(releases, key=lambda r: max(int(c) for c in r["versionCodes"]))
        release = {"versionCodes": latest["versionCodes"], "status": "completed"}
        for field in ("name", "releaseNotes"):
            if field in latest:
                release[field] = latest[field]
        if fraction < 1:
            release.update(status="inProgress", userFraction=fraction)
        call(http, "PUT", f"/{edit}/tracks/{target}", {"track": target, "releases": [release]})
        label = f"{release.get('name', '')} {latest['versionCodes']} de {source} para {target} ({release['status']}"
        label += f", {fraction:.0%})" if fraction < 1 else ")"
        if dry_run:
            call(http, "POST", f"/{edit}:validate")
            print(f"dry-run ok: {label}")
        else:
            call(http, "POST", f"/{edit}:commit")
            committed = True
            print(f"promovida: {label}")
    finally:
        if not committed:
            try:
                call(http, "DELETE", f"/{edit}")
            except PlayError:
                pass


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--key", help="JSON da conta de serviço (padrão: PLAY_SERVICE_ACCOUNT_JSON)")
    sub = parser.add_subparsers(dest="command", required=True)
    hv = sub.add_parser("has-version", help="o versionCode já está em alguma faixa?")
    hv.add_argument("code", type=int)
    pr = sub.add_parser("promote", help="leva a versão mais nova de uma faixa para outra")
    pr.add_argument("--from", dest="source", default="alpha")
    pr.add_argument("--to", dest="target", default="production")
    pr.add_argument("--fraction", type=float, default=0.2)
    pr.add_argument("--dry-run", action="store_true", help="valida o edit em vez de publicar")
    args = parser.parse_args()

    if args.command == "promote" and not 0 < args.fraction <= 1:
        parser.error("--fraction precisa estar entre 0 (exclusivo) e 1")
    try:
        http = session(args.key)
        if args.command == "has-version":
            print("true" if has_version(http, args.code) else "false")
        else:
            promote(http, args.source, args.target, args.fraction, args.dry_run)
    except PlayError as e:
        print(f"erro da Play: {e}", file=sys.stderr)
        if e.status == "FAILED_PRECONDITION" and args.command == "promote" and args.target == "production":
            print(f"provável causa: {NO_PRODUCTION}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
