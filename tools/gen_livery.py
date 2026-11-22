"""Arte própria da evolução visual da aeronave (scripts/view/ship_livery.gd) e das avarias, em
assets/art/generated/livery/.

Desde as naves HD (1.25) a evolução é luz por cima da arte, guiada por data/livery.json, não peças coladas no casco:
cada nave tem só o brilho da silhueta (player/<id>_glow.png, de tools/gen_hd_ships.py, licença da nave). Aqui sai o
que é do projeto (MIT, licença "atlantis_generated"):
  - stripe.png  divisa branca 16x16 (friso do esquadrão, tingida com o acento na hora de desenhar);
  - crack.png   rachadura 24x24 escura com fio quente (avaria a 2/3 e 1/3 do casco);
  - icon_<marco>.png  emblema 96x96 de cada marco de data/livery.json (ladrilhos da Oficina): uma silhueta de nave
    genérica apagada e só o efeito do marco aceso, na cor dele.

Registra cada arquivo em assets/asset_index.json (origem tools/gen_livery.py), que o tools/sync_assets.py preserva,
e apaga as camadas antigas de 48x48 (alinhadas à nave Void) que sobraram na pasta.
Uso: python tools/gen_livery.py [--preview DIR]   (Pillow; --preview grava a folha dos emblemas)
"""
from __future__ import annotations

import hashlib
import json
import math
import pathlib
import sys

from PIL import Image, ImageDraw, ImageFilter

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "art" / "generated" / "livery"
DATA = ROOT / "data" / "livery.json"
LICENSE_ID = "atlantis_generated"
SOURCE = "tools/gen_livery.py"
ICON = 96
SS = 4  # superamostragem dos desenhos (bordas macias)

CYAN = (111, 232, 255)
GOLD = (255, 214, 110)
FLAME = (120, 220, 255)
HOT = (235, 252, 255)
PORT = (255, 70, 80)
STARBOARD = (80, 255, 140)
DIM = (52, 78, 104)


def canvas(size: int) -> tuple[Image.Image, ImageDraw.ImageDraw]:
    im = Image.new("RGBA", (size * SS, size * SS), (0, 0, 0, 0))
    return im, ImageDraw.Draw(im)


def done(im: Image.Image, size: int) -> Image.Image:
    return im.resize((size, size), Image.Resampling.LANCZOS)


def p(*xy: float) -> list:
    """Pontos em fração do ícone -> pixels da superamostragem."""
    return [(xy[i] * ICON * SS, xy[i + 1] * ICON * SS) for i in range(0, len(xy), 2)]


def glow(im: Image.Image, color: tuple, at: tuple, r: float, strength: float = 1.0) -> None:
    layer = Image.new("RGBA", im.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    cx, cy = at[0] * ICON * SS, at[1] * ICON * SS
    rr = r * ICON * SS
    d.ellipse((cx - rr, cy - rr, cx + rr, cy + rr), fill=color + (round(200 * strength),))
    layer = layer.filter(ImageFilter.GaussianBlur(rr * 0.6))
    im.alpha_composite(layer)


def hull(d: ImageDraw.ImageDraw, color: tuple = DIM) -> None:
    """Silhueta genérica de nave (nariz para cima), apagada: o marco acende por cima dela."""
    d.polygon(p(0.5, 0.12, 0.62, 0.42, 0.88, 0.66, 0.86, 0.74, 0.6, 0.68, 0.56, 0.8, 0.44, 0.8, 0.4, 0.68,
                0.14, 0.74, 0.12, 0.66, 0.38, 0.42), fill=color + (255,))


def flame(d: ImageDraw.ImageDraw, x: float, length: float, color: tuple) -> None:
    d.polygon(p(x - 0.045, 0.79, x + 0.045, 0.79, x, 0.79 + length), fill=color + (255,))
    d.polygon(p(x - 0.02, 0.79, x + 0.02, 0.79, x, 0.79 + length * 0.55), fill=HOT + (255,))


def chevron(d: ImageDraw.ImageDraw, x: float, y: float, w: float, color: tuple) -> None:
    d.polygon(p(x - w, y, x, y - w * 0.7, x + w, y, x + w, y + w * 0.45, x, y - w * 0.25, x - w, y + w * 0.45),
              fill=color + (255,))


def icon(kind: str) -> Image.Image:
    im, d = canvas(ICON)
    if kind == "aura":
        d.ellipse(p(0.08, 0.1, 0.92, 0.94), outline=CYAN + (230,), width=3 * SS)
        glow(im, CYAN, (0.5, 0.52), 0.42, 0.35)
        d = ImageDraw.Draw(im)
    if kind == "trim":
        glow(im, GOLD, (0.5, 0.5), 0.46, 0.8)
        d = ImageDraw.Draw(im)
    if kind == "accent_glow":
        glow(im, CYAN, (0.5, 0.5), 0.44, 1.0)
        d = ImageDraw.Draw(im)
    hull(d, (150, 120, 60) if kind == "trim" else DIM)
    if kind == "trim":
        outline = p(0.5, 0.12, 0.62, 0.42, 0.88, 0.66, 0.86, 0.74, 0.6, 0.68, 0.56, 0.8, 0.44, 0.8, 0.4, 0.68,
                    0.14, 0.74, 0.12, 0.66, 0.38, 0.42, 0.5, 0.12)
        d.line(outline, fill=GOLD + (255,), width=3 * SS, joint="curve")
    if kind in ("tuned_engine", "afterburner"):
        length = 0.16 if kind == "tuned_engine" else 0.2
        for x in (0.45, 0.55):
            flame(d, x, length, FLAME)
        if kind == "afterburner":
            glow(im, FLAME, (0.5, 0.9), 0.12, 0.9)
    if kind == "stripes":
        for x in (0.3, 0.7):
            chevron(d, x, 0.62, 0.08, CYAN)
    if kind == "nav_lights":
        glow(im, PORT, (0.15, 0.7), 0.08)
        glow(im, STARBOARD, (0.85, 0.7), 0.08)
    if kind == "sensor":
        d.polygon(p(0.5, 0.16, 0.56, 0.27, 0.5, 0.38, 0.44, 0.27), fill=(150, 250, 255, 255))
        glow(im, CYAN, (0.5, 0.27), 0.1, 0.9)
    if kind == "runes":
        for k in range(4):
            y = 0.36 + k * 0.1
            d.rectangle(p(0.485, y, 0.515, y + 0.05), fill=CYAN + (230,))
        glow(im, HOT, (0.5, 0.36), 0.07, 1.0)
    return done(im, ICON)


def stripe() -> Image.Image:
    im, d = canvas(16)
    w = 16 * SS
    d.polygon([(w * 0.1, w * 0.72), (w * 0.5, w * 0.3), (w * 0.9, w * 0.72), (w * 0.9, w * 0.92), (w * 0.5, w * 0.52),
               (w * 0.1, w * 0.92)], fill=(255, 255, 255, 255))
    return done(im, 16)


def crack() -> Image.Image:
    """Rachadura em zigue-zague: borda escura larga e fio quente fino no meio (determinística)."""
    im, d = canvas(24)
    w = 24 * SS
    pts = [(0.12, 0.2), (0.34, 0.4), (0.3, 0.55), (0.52, 0.62), (0.6, 0.82), (0.86, 0.88)]
    branch = [(0.52, 0.62), (0.74, 0.46), (0.88, 0.4)]
    for line, width, color in ((pts, 2.6, (10, 8, 8, 230)), (branch, 2.0, (10, 8, 8, 210)),
                               (pts, 0.9, (255, 150, 70, 255)), (branch, 0.7, (255, 150, 70, 220))):
        d.line([(x * w, y * w) for x, y in line], fill=color, width=round(width * SS), joint="curve")
    return done(im, 24)


def png(im: Image.Image, path: pathlib.Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    im.save(path, optimize=True)


def main() -> int:
    levels = json.loads(DATA.read_text(encoding="utf-8"))["levels"]
    files = {"stripe": stripe(), "crack": crack()}
    for lv in levels:
        files["icon_" + lv["id"]] = icon(lv["id"])
    keep = set()
    rows = []
    for name, im in files.items():
        target = OUT / f"{name}.png"
        png(im, target)
        keep.add(target.name)
        rows.append({"file": target.relative_to(ROOT).as_posix(), "source": SOURCE, "license_id": LICENSE_ID,
                     "sha256": hashlib.sha256(target.read_bytes()).hexdigest()})
    # Camadas antigas (48x48 da nave Void) que não saem mais.
    for old in OUT.glob("*.png"):
        if old.name not in keep:
            old.unlink()
            imp = old.with_name(old.name + ".import")
            if imp.exists():
                imp.unlink()
    index_path = ROOT / "assets" / "asset_index.json"
    index = json.loads(index_path.read_text(encoding="utf-8")) if index_path.exists() else []
    index = [r for r in index if r.get("source") != SOURCE] + rows
    index.sort(key=lambda item: item["file"])
    index_path.write_text(json.dumps(index, indent=1, ensure_ascii=False) + "\n", encoding="utf-8", newline="\n")
    if "--preview" in sys.argv:
        folder = pathlib.Path(sys.argv[sys.argv.index("--preview") + 1])
        folder.mkdir(parents=True, exist_ok=True)
        icons = [files["icon_" + lv["id"]] for lv in levels]
        sheet = Image.new("RGBA", (ICON * len(icons), ICON), (10, 30, 44, 255))
        for i, ic in enumerate(icons):
            sheet.alpha_composite(ic, (i * ICON, 0))
        sheet.alpha_composite(files["crack"].resize((72, 72)), (0, 0))
        sheet.save(folder / "livery_icons.png")
        print("prévia:", folder / "livery_icons.png")
    print(f"{len(rows)} arquivos da evolução gerados em {OUT.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
