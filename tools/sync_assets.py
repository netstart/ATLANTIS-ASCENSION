"""Copia para res://assets só os arquivos que o jogo usa (docs/policies/licencas.md).

Uso:  python -I tools/sync_assets.py
Lê todo tools/*_assets.json. Cada manifesto diz a pasta do pacote baixado (pack_root, dentro de
c:\\src\\downloads\\assets\\ por padrão, ou em $ATLANTIS_DOWNLOADS), o id da licença no registro e o
que copiar (pastas e arquivos). Escreve assets/asset_index.json com origem e hash de tudo, usado
por tools/check_licenses.py para conferir que todo arquivo tem licença registrada.

Origem: tools/sync_assets.py do projeto hyakki (mesmo autor, MIT).
"""
import hashlib
import json
import os
import pathlib
import shutil
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
ASSETS = ROOT / "assets"
DOWNLOADS = pathlib.Path(os.environ.get("ATLANTIS_DOWNLOADS", "C:/src/downloads/assets"))
SKIP_SUFFIXES = {".gif"}
## Textos copiados com fim de linha LF (o .gitattributes do repositório também força LF; assim o
## hash em asset_index.json vale para o arquivo do checkout em qualquer sistema).
TEXT_SUFFIXES = {".txt", ".md", ".json", ".csv"}


def sha256(path: pathlib.Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def copy_file(src: pathlib.Path, dst: pathlib.Path, license_id: str, index: list) -> None:
    dst.parent.mkdir(parents=True, exist_ok=True)
    if src.suffix.lower() in TEXT_SUFFIXES:
        content = src.read_bytes().replace(b"\r\n", b"\n").replace(b"\r", b"\n")
        if not dst.exists() or dst.read_bytes() != content:
            dst.write_bytes(content)
    elif not dst.exists() or sha256(src) != sha256(dst):
        shutil.copy2(src, dst)
    index.append({
        "file": dst.relative_to(ROOT).as_posix(),
        "source": src.relative_to(DOWNLOADS).as_posix() if src.is_relative_to(DOWNLOADS) else src.as_posix(),
        "license_id": license_id,
        "sha256": sha256(dst),
    })


def sync_manifest(manifest_path: pathlib.Path, index: list) -> int:
    data = json.loads(manifest_path.read_text(encoding="utf-8"))
    pack = DOWNLOADS / data["pack_root"]
    license_id = data["license_id"]
    missing = 0
    for src_rel, dst_rel in data.get("folders", {}).items():
        src_dir = pack / src_rel
        if not src_dir.is_dir():
            print(f"FALTA pasta: {src_dir}")
            missing += 1
            continue
        for src in sorted(src_dir.rglob("*")):
            if not src.is_file() or src.suffix.lower() in SKIP_SUFFIXES:
                continue
            if src.name.lower().startswith(("preview", "sample")):
                continue
            rel = src.relative_to(src_dir)
            dst = ASSETS / dst_rel / pathlib.Path(*[p.replace(" ", "_") for p in rel.parts])
            copy_file(src, dst, license_id, index)
    for src_rel, dst_rel in data.get("files", {}).items():
        src = pack / src_rel
        if not src.is_file():
            print(f"FALTA arquivo: {src}")
            missing += 1
            continue
        copy_file(src, ASSETS / dst_rel, license_id, index)
    return missing


def main() -> int:
    index: list = []
    missing = 0
    for path in sorted((ROOT / "tools").glob("*_assets.json")):
        missing += sync_manifest(path, index)
    # Assets gerados pelo próprio repositório (source começando com "tools/") continuam no índice.
    old_index = ASSETS / "asset_index.json"
    if old_index.exists():
        for row in json.loads(old_index.read_text(encoding="utf-8")):
            target = ROOT / row["file"]
            if row.get("source", "").startswith("tools/") and target.exists():
                index.append({**row, "sha256": sha256(target)})
    index.sort(key=lambda item: item["file"])
    ASSETS.mkdir(exist_ok=True)
    (ASSETS / "asset_index.json").write_text(
        json.dumps(index, indent=1, ensure_ascii=False) + "\n", encoding="utf-8", newline="\n")
    print(f"{len(index)} arquivos sincronizados, {missing} faltando")
    return 1 if missing else 0


if __name__ == "__main__":
    sys.exit(main())
