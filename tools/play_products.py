"""Cria ou atualiza no Play Console os produtos das naves premium e os pacotes de Pérolas (API Android Publisher v3,
monetization).

Só os produtos NOVOS desta ferramenta (catalog()): ship_premium_<id> x3, o pacote premium_fleet, os quatro pacotes de
Pérolas pearls_<total> (lidos de PEARL_PACKS em scripts/core/iap.gd, a fonte dos ids, quantidades e preços-alvo), o
remove_ads ("Remover anúncios") e o season_gold ("Maré Dourada", passe). Os produtos que já existem (turbo,
support, pinturas...) nunca são tocados: a ferramenta recusa qualquer id fora dela.

Consumível: a API de produtos únicos (onetimeproducts) não tem campo "consumível"; um produto vira consumível porque o
app chama consumePurchase depois de creditar (scripts/core/iap.gd e play_billing_provider.gd), o que libera a compra
de novo. Por isso os pacotes de Pérolas têm o mesmo corpo dos outros produtos (opção de compra compatível, quantidade 1).

Para cada produto, de forma idempotente (rodar de novo só reaplica o mesmo estado):
1. pricing:convertRegionPrices com o preço em USD: preço local de cada região (o que o Console faz com "aplicar a
   todas as regiões") e o preço de regiões novas (USD/EUR);
2. onetimeproducts.patch com allowMissing=true e regionsVersion: produto único com fichas nos 11 idiomas e uma
   opção de compra "<id-com-hífens>-compra", compatível com versões anteriores (legacyCompatible, a que a Billing
   Library do plugin usa), como os produtos que já existem (docs/store/play-console.md);
3. purchaseOptions:batchUpdateStates: ativa a opção de compra que ainda não está ACTIVE.

Credenciais: JSON da conta de serviço em PLAY_SERVICE_ACCOUNT_JSON ou --key ARQUIVO (como tools/play_publish.py).
Precisa de google-auth e requests (pip install google-auth requests).

  python tools/play_products.py --dry-run          # imprime os corpos das requisições, sem rede
  python tools/play_products.py apply              # cria/atualiza e ativa (pede credenciais)
  python tools/play_products.py list               # lista os produtos únicos do app (id, estado, preço US)

Textos: tools/i18n/command_premium.py (os do jogo) e tools/i18n/play_products.py (os da ficha).
"""

from __future__ import annotations

import argparse
import importlib.util
import json
import pathlib
import re
import sys
from decimal import Decimal

ROOT = pathlib.Path(__file__).resolve().parent.parent
PACKAGE = "io.github.netstart.atlantisascension"
APP = f"https://androidpublisher.googleapis.com/androidpublisher/v3/applications/{PACKAGE}"
LANGS = ["pt_BR", "en", "es", "de", "fr", "ru", "id", "ja", "ko", "zh_TW", "zh_CN"]
## Idioma do jogo -> código da ficha na Play.
PLAY_LOCALES = {"pt_BR": "pt-BR", "en": "en-US", "es": "es-ES", "de": "de-DE", "fr": "fr-FR", "ru": "ru-RU",
                "id": "id", "ja": "ja-JP", "ko": "ko-KR", "zh_TW": "zh-TW", "zh_CN": "zh-CN"}
## Separador entre as frases da descrição (japonês e chinês não usam espaço).
GLUE = {"ja": "", "zh_TW": "", "zh_CN": ""}
TITLE_MAX = 55
DESC_MAX = 200
## Os produtos novos (mesmos ids e preços-alvo de scripts/core/iap.gd).
PREMIUM_SHIPS = ["hippocampus", "nereid", "amphitrite"]
SHIP_USD = "2.99"
FLEET_ID = "premium_fleet"
FLEET_USD = "5.99"
REMOVE_ADS_ID = "remove_ads"
REMOVE_ADS_USD = "2.99"
SEASON_ID = "season_gold"
SEASON_USD = "4.99"
IAP = ROOT / "scripts" / "core" / "iap.gd"
## Separador de milhar do título dos pacotes, por idioma (como Locale.format_number no jogo).
THOUSANDS = {"pt_BR": ".", "es": ".", "de": ".", "id": ".", "fr": "\u202f", "ru": "\u00a0"}


class PlayError(Exception):
    pass


def _module(path: pathlib.Path) -> dict:
    spec = importlib.util.spec_from_file_location(f"i18n_{path.stem}", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module.STRINGS


def texts() -> dict:
    out: dict = {}
    for name in ("ui", "command_premium", "command_iap", "play_products"):
        out.update(_module(ROOT / "tools" / "i18n" / f"{name}.py"))
    return out


def kits() -> dict:
    ships = json.loads((ROOT / "data" / "ships.json").read_text(encoding="utf-8"))
    return {s["id"]: s.get("kit", "") for s in ships if "premium" in s}


def pearl_packs() -> list[dict]:
    """[{id, usd, pearls}] de PEARL_PACKS em scripts/core/iap.gd, na ordem de lá."""
    text = IAP.read_text(encoding="utf-8")
    found = re.findall(r'\{"id": "(pearls_\d+)", "kind": "consumable", "usd": "([\d.]+)", "pearls": (\d+)', text)
    if len(found) != 4:
        raise SystemExit(f"PEARL_PACKS em {IAP.relative_to(ROOT)}: {len(found)} pacotes, esperado 4")
    return [{"id": pid, "usd": usd, "pearls": int(n)} for pid, usd, n in found]


def number(value: int, lang: str) -> str:
    return f"{value:,}".replace(",", THOUSANDS.get(lang, ","))


def catalog() -> list[dict]:
    """[{id, usd, listings: [{languageCode, title, description}]}] dos produtos novos (naves premium e Pérolas)."""
    t = texts()
    kit = kits()
    out = []
    for ship in PREMIUM_SHIPS:
        listings = []
        for i, lang in enumerate(LANGS):
            name = t[f"ship.{ship}"][i]
            desc = GLUE.get(lang, " ").join([t[f"store.premium_lore_{ship}"][i],
                             t["store.premium_kit"][i].replace("%s", t[f"ship.{kit[ship]}"][i]),
                             t["store.premium_note"][i]])
            listings.append({"languageCode": PLAY_LOCALES[lang],
                             "title": t["play.premium_title"][i].replace("%s", name), "description": desc})
        out.append({"id": f"ship_premium_{ship}", "usd": SHIP_USD, "listings": listings})
    listings = []
    for i, lang in enumerate(LANGS):
        each = [t[f"ship.{s}"][i] for s in PREMIUM_SHIPS]
        comma = "、" if lang in GLUE else ", "
        names = comma.join(each[:-1]) + t["play.list_and"][i] + each[-1]
        desc = GLUE.get(lang, " ").join([t["store.premium_fleet_desc"][i], t["play.premium_fleet_ships"][i].replace("%s", names),
                         t["store.premium_note"][i]])
        listings.append({"languageCode": PLAY_LOCALES[lang], "title": t["play.premium_fleet_title"][i],
                         "description": desc})
    out.append({"id": FLEET_ID, "usd": FLEET_USD, "listings": listings})
    for pack in pearl_packs():
        listings = []
        for i, lang in enumerate(LANGS):
            desc = GLUE.get(lang, " ").join([t["store.pearls_intro"][i], t["store.pearls_note"][i]])
            listings.append({"languageCode": PLAY_LOCALES[lang],
                             "title": t["play.pearls_title"][i].replace("%s", number(pack["pearls"], lang)),
                             "description": desc})
        out.append({"id": pack["id"], "usd": pack["usd"], "listings": listings})
    remove_ads = []
    for i, lang in enumerate(LANGS):
        remove_ads.append({"languageCode": PLAY_LOCALES[lang], "title": t["play.remove_ads_title"][i],
                           "description": t["store.remove_ads_desc"][i]})
    out.append({"id": REMOVE_ADS_ID, "usd": REMOVE_ADS_USD, "listings": remove_ads})
    season = []
    for i, lang in enumerate(LANGS):
        season.append({"languageCode": PLAY_LOCALES[lang], "title": t["play.season_title"][i],
                       "description": t["store.season_desc"][i]})
    out.append({"id": SEASON_ID, "usd": SEASON_USD, "listings": season})
    return out


def check_catalog(products: list[dict]) -> list[str]:
    errors = []
    for p in products:
        if len(p["listings"]) != len(LANGS):
            errors.append(f"{p['id']}: {len(p['listings'])} fichas, esperado {len(LANGS)}")
        for item in p["listings"]:
            if not 0 < len(item["title"]) <= TITLE_MAX:
                errors.append(f"{p['id']} [{item['languageCode']}]: título com {len(item['title'])} caracteres")
            if not 0 < len(item["description"]) <= DESC_MAX:
                errors.append(f"{p['id']} [{item['languageCode']}]: descrição com {len(item['description'])} caracteres")
            if "%" in item["title"] + item["description"]:
                errors.append(f"{p['id']} [{item['languageCode']}]: marcador sobrando")
    return errors


def option_id(product_id: str) -> str:
    return product_id.replace("_", "-") + "-compra"


def money(currency: str, amount: str) -> dict:
    value = Decimal(amount)
    units = int(value)
    return {"currencyCode": currency, "units": str(units), "nanos": int((value - units) * 1_000_000_000)}


def product_body(p: dict, prices: dict) -> dict:
    """Corpo do OneTimeProduct. `prices`: resposta do convertRegionPrices (ou um marcador no --dry-run)."""
    regional = [{"regionCode": code, "price": item["price"], "availability": "AVAILABLE"}
                for code, item in sorted(prices.get("convertedRegionPrices", {}).items())]
    other = prices.get("convertedOtherRegionsPrice", {})
    return {
        "packageName": PACKAGE,
        "productId": p["id"],
        "listings": p["listings"],
        "purchaseOptions": [{
            "purchaseOptionId": option_id(p["id"]),
            "buyOption": {"legacyCompatible": True, "multiQuantityEnabled": False},
            "regionalPricingAndAvailabilityConfigs": regional,
            "newRegionsConfig": {"usdPrice": other.get("usdPrice", money("USD", p["usd"])),
                                 "eurPrice": other.get("eurPrice", money("EUR", p["usd"])),
                                 "availability": "AVAILABLE"},
        }],
    }


# ---------------------------------------------------------------- rede


def session(key_path: str | None):
    import os
    from google.auth.transport.requests import AuthorizedSession
    from google.oauth2 import service_account

    if key_path:
        info = json.loads(pathlib.Path(key_path).read_text(encoding="utf-8"))
    elif os.environ.get("PLAY_SERVICE_ACCOUNT_JSON"):
        info = json.loads(os.environ["PLAY_SERVICE_ACCOUNT_JSON"])
    else:
        raise PlayError("sem credenciais: defina PLAY_SERVICE_ACCOUNT_JSON ou passe --key")
    scope = "https://www.googleapis.com/auth/androidpublisher"
    return AuthorizedSession(service_account.Credentials.from_service_account_info(info, scopes=[scope]))


def call(http, method: str, path: str, body: dict | None = None, params: dict | None = None) -> dict:
    r = http.request(method, APP + path, json=body, params=params, timeout=60)
    if r.status_code >= 400:
        try:
            err = r.json()["error"]
            raise PlayError(f"{err.get('code', r.status_code)} {err.get('status', '')}: {err.get('message', '')}")
        except (ValueError, KeyError):
            raise PlayError(f"HTTP {r.status_code}: {r.text[:500]}") from None
    return r.json() if r.content else {}


def convert(http, usd: str) -> dict:
    return call(http, "POST", "/pricing:convertRegionPrices", {"price": money("USD", usd)})


def apply(http, products: list[dict]) -> None:
    for p in products:
        prices = convert(http, p["usd"])
        version = prices.get("regionVersion", {}).get("version", "")
        if not version:
            raise PlayError(f"{p['id']}: convertRegionPrices sem regionVersion")
        params = {"allowMissing": "true", "regionsVersion.version": version,
                  "updateMask": "listings,purchaseOptions"}
        saved = call(http, "PATCH", f"/onetimeproducts/{p['id']}", product_body(p, prices), params)
        opt = option_id(p["id"])
        state = next((o.get("state", "") for o in saved.get("purchaseOptions", [])
                      if o.get("purchaseOptionId") == opt), "")
        print(f"{p['id']}: gravado ({len(prices.get('convertedRegionPrices', {}))} regiões, {version}), "
              f"opção {opt} {state or '?'}")
        if state != "ACTIVE":
            call(http, "POST", f"/oneTimeProducts/{p['id']}/purchaseOptions:batchUpdateStates", {"requests": [
                {"activatePurchaseOptionRequest": {"packageName": PACKAGE, "productId": p["id"],
                                                   "purchaseOptionId": opt}}]})
            print(f"{p['id']}: opção {opt} ativada")


def list_products(http) -> None:
    token = ""
    while True:
        params = {"pageSize": 100}
        if token:
            params["pageToken"] = token
        page = call(http, "GET", "/oneTimeProducts", params=params)
        for p in page.get("oneTimeProducts", []):
            for o in p.get("purchaseOptions", []):
                us = next((c["price"] for c in o.get("regionalPricingAndAvailabilityConfigs", [])
                           if c.get("regionCode") == "US"), {})
                price = f"{us.get('units', '0')}.{int(us.get('nanos', 0)) // 10_000_000:02d} {us.get('currencyCode', '')}"
                print(f"{p['productId']:28s} {o.get('purchaseOptionId', ''):34s} {o.get('state', ''):10s} US {price}")
        token = page.get("nextPageToken", "")
        if not token:
            return


def dry_run(products: list[dict]) -> None:
    for p in products:
        print(f"# {p['id']}  (US$ {p['usd']}, opção {option_id(p['id'])})")
        print(f"POST {APP}/pricing:convertRegionPrices")
        print(json.dumps({"price": money("USD", p["usd"])}, ensure_ascii=False))
        marker = {"convertedRegionPrices": {"<região>": {"price": "<preço local da conversão>"}}}
        body = product_body(p, marker)
        print(f"PATCH {APP}/onetimeproducts/{p['id']}?allowMissing=true&regionsVersion.version=<da conversão>"
              "&updateMask=listings,purchaseOptions")
        print(json.dumps(body, ensure_ascii=False, indent=1))
        print(f"POST {APP}/oneTimeProducts/{p['id']}/purchaseOptions:batchUpdateStates  (se a opção não está ACTIVE)")
        print(json.dumps({"requests": [{"activatePurchaseOptionRequest": {
            "packageName": PACKAGE, "productId": p["id"], "purchaseOptionId": option_id(p["id"])}}]}))
        print()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--key", help="JSON da conta de serviço (padrão: PLAY_SERVICE_ACCOUNT_JSON)")
    parser.add_argument("--dry-run", action="store_true", help="só imprime os corpos das requisições (sem rede)")
    parser.add_argument("--only", help="ids separados por vírgula (padrão: todos os desta ferramenta)")
    parser.add_argument("command", nargs="?", choices=["apply", "list"], default="apply")
    args = parser.parse_args()
    products = catalog()
    if args.only:
        wanted = set(args.only.split(","))
        unknown = wanted - {p["id"] for p in products}
        if unknown:
            parser.error(f"fora do catálogo desta ferramenta (produtos antigos não são tocados): {sorted(unknown)}")
        products = [p for p in products if p["id"] in wanted]
    errors = check_catalog(products)
    if errors:
        print("\n".join(errors), file=sys.stderr)
        return 1
    if args.dry_run:
        if args.command == "list":
            print(f"GET {APP}/oneTimeProducts?pageSize=100")
        else:
            dry_run(products)
        return 0
    try:
        http = session(args.key)
        if args.command == "list":
            list_products(http)
        else:
            apply(http, products)
    except PlayError as e:
        print(f"erro da Play: {e}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
