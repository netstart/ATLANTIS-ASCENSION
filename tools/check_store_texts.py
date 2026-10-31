"""Confere os limites de caracteres da Google Play nos textos de docs/store/listing.md.

Título <= 30, descrição curta <= 80, descrição longa <= 4.000 e "Novidades" <= 500 caracteres (contagem em
caracteres Unicode, como o Play Console). Roda em tools/run_checks.ps1:

    python -I tools/check_store_texts.py
"""

from __future__ import annotations

import pathlib
import re
import sys

LISTING = pathlib.Path(__file__).resolve().parent.parent / "docs" / "store" / "listing.md"
LIMITS = {"title": 30, "short": 80, "long": 4000, "news": 500}


def sections(text: str) -> dict[str, str]:
    """Seções '## ...' do arquivo, pelo título."""
    out: dict[str, str] = {}
    for block in re.split(r"^## ", text, flags=re.M)[1:]:
        head, _, body = block.partition("\n")
        out[head.strip()] = body
    return out


def field(body: str, label: str) -> str:
    """Valor de '**Rótulo ...:** valor' (pode continuar nas linhas seguintes até a linha em branco)."""
    match = re.search(r"^\*\*" + label + r"[^*]*:\*\*[ \t]*(.*?)(?:\n\s*\n|\Z)", body, flags=re.M | re.S)
    return " ".join(match.group(1).split()) if match else ""


def long_description(body: str, label: str) -> str:
    match = re.search(r"^\*\*" + label + r":\*\*\s*\n(.*?)(?=^\*\*)", body, flags=re.M | re.S)
    return match.group(1).strip() if match else ""


def main() -> int:
    errors: list[str] = []
    checked = 0
    for name, body in sections(LISTING.read_text(encoding="utf-8")).items():
        labels = None
        if name.startswith("Português"):
            labels = ("Título", "Descrição curta", "Descrição longa", "Novidades")
        elif name.startswith("English"):
            labels = ("Title", "Short description", "Long description", "What's new")
        if labels is not None:
            values = {"title": field(body, labels[0]), "short": field(body, labels[1]),
                      "long": long_description(body, labels[2]), "news": field(body, labels[3])}
            for key, value in values.items():
                checked += 1
                if not value:
                    errors.append(f"{name}: '{key}' não encontrado")
                elif len(value) > LIMITS[key]:
                    errors.append(f"{name}: '{key}' tem {len(value)} caracteres (máx. {LIMITS[key]})")
        elif name.startswith("Outros idiomas"):
            for row in re.findall(r"^\|(?! Idioma|---)(.+)\|\s*$", body, flags=re.M):
                lang, title, short = (cell.strip() for cell in row.split("|"))
                checked += 2
                if len(title) > LIMITS["title"]:
                    errors.append(f"{lang}: título com {len(title)} caracteres (máx. {LIMITS['title']})")
                if len(short) > LIMITS["short"]:
                    errors.append(f"{lang}: descrição curta com {len(short)} caracteres (máx. {LIMITS['short']})")
    for error in errors:
        print("ERRO:", error)
    if errors or checked < 20:
        print(f"textos da loja: FALHOU ({checked} campos conferidos)")
        return 1
    print(f"textos da loja: {checked} campos dentro dos limites da Play")
    return 0


if __name__ == "__main__":
    sys.exit(main())
