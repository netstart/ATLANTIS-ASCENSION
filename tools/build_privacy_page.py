"""Gera docs/privacy/index.html a partir de docs/store/privacy-policy.md.

A Google Play exige a política de privacidade numa URL pública em HTML (não PDF, não editável). Esta página é
autocontida (sem script, sem fonte externa, sem rastreio) e serve para o GitHub Pages
(https://netstart.github.io/ATLANTIS-ASCENSION/privacy/ com o Pages publicando a pasta docs/) ou para qualquer
hospedagem estática. O Markdown é a fonte: edite só ele e rode

    python -I tools/build_privacy_page.py

Com --check, só confere se a página está em dia (usado em tools/run_checks.ps1).
"""

from __future__ import annotations

import html
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
SOURCE = ROOT / "docs" / "store" / "privacy-policy.md"
TARGET = ROOT / "docs" / "privacy" / "index.html"

PAGE = """<!doctype html>
<html lang="pt-BR">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Atlantis Ascension — Política de privacidade / Privacy policy</title>
<style>
:root {{ color-scheme: dark; --bg: #050b1a; --card: #0b1a2e; --text: #d8ecf5; --dim: #8fb3c9; --cyan: #2ff3e0;
  --gold: #ffc94a; }}
body {{ margin: 0; background: var(--bg); color: var(--text); font: 16px/1.6 system-ui, sans-serif; }}
main {{ max-width: 760px; margin: 0 auto; padding: 32px 16px 64px; }}
h1 {{ color: #f4fbff; font-size: 1.7rem; line-height: 1.25; margin: 0 0 4px; }}
h2 {{ color: var(--cyan); font-size: 1.25rem; margin: 40px 0 8px; padding-top: 16px;
  border-top: 1px solid #16324a; }}
p {{ margin: 0 0 14px; }}
em {{ color: var(--dim); }}
strong {{ color: #f4fbff; }}
code {{ background: var(--card); padding: 1px 5px; border-radius: 4px; font-size: .9em; }}
a {{ color: var(--gold); }}
</style>
</head>
<body>
<main>
{body}
</main>
</body>
</html>
"""


def inline(text: str) -> str:
    out = html.escape(text, quote=False)
    out = re.sub(r"`([^`]+)`", r"<code>\1</code>", out)
    out = re.sub(r"\*\*([^*]+)\*\*", r"<strong>\1</strong>", out)
    out = re.sub(r"\*([^*]+)\*", r"<em>\1</em>", out)
    return re.sub(r"\[([^\]]+)\]\((https?://[^)]+)\)", r'<a href="\2">\1</a>', out)


def render(markdown: str) -> str:
    blocks: list[str] = []
    for chunk in re.split(r"\n\s*\n", markdown.strip()):
        line = " ".join(part.strip() for part in chunk.splitlines())
        if line.startswith("## "):
            title = line[3:]
            anchor = ' id="en" lang="en"' if title == "English" else ' id="pt-br"'
            blocks.append(f"<h2{anchor}>{inline(title)}</h2>")
        elif line.startswith("# "):
            blocks.append(f"<h1>{inline(line[2:])}</h1>")
        else:
            blocks.append(f"<p>{inline(line)}</p>")
    return PAGE.format(body="\n".join(blocks))


def main() -> int:
    page = render(SOURCE.read_text(encoding="utf-8"))
    if "--check" in sys.argv:
        current = TARGET.read_text(encoding="utf-8") if TARGET.exists() else ""
        if current != page:
            print(f"desatualizada: {TARGET.relative_to(ROOT)} (rode python -I tools/build_privacy_page.py)")
            return 1
        print("política de privacidade em HTML: em dia")
        return 0
    TARGET.parent.mkdir(parents=True, exist_ok=True)
    TARGET.write_text(page, encoding="utf-8", newline="\n")
    print(f"gerada: {TARGET.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
