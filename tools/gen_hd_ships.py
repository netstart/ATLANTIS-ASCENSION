"""Naves em alta definição (pré-renderizadas, metálicas, motor brilhante) para o hangar e as três frotas inimigas.

Uso:  python tools/gen_hd_ships.py [--preview DIR] [--staging-only]
Rode com o `python` comum (sem -I): precisa de numpy e Pillow instalados no usuário.

Lê as naves baixadas em D:\\src\\assets-downloaded (ou $ATLANTIS_DOWNLOADS), todas com licença livre para uso
comercial e LICENSE_SOURCE.txt na pasta do pacote:
- MillionthVector (CC BY 3.0 na OpenGameArt; o Credits.txt do zip diz CC BY 4.0): Faction 1, 2, 5, 7, 10,
  Blue fighter, Yellow starship, Fighter (Fighter1).
- Carlos Alface, "XENIS" (CC BY 3.0).
- W_K_Studio / whiteknightstudios (CC0): aranhas e insetos alienígenas.
Os normal maps dos pacotes (…_normal.png, …N.png, …-n.png) ficam de fora; servem para luz 2D no futuro.

Saída, no mesmo formato da série Void (SpriteBank só troca o caminho e a escala):
- <grupo>/<nome>_base.png: tela quadrada com a nave centrada, apontando para CIMA, com acabamento comum
  (contraste e saturação normalizados, nitidez leve, luz de borda e contorno escuro fino).
- <grupo>/<nome>_engine.png: tira horizontal de ENGINE_FRAMES quadros do mesmo tamanho, com a chama de cada
  bocal (achado sozinho na borda de baixo do casco) para ser desenhada ATRÁS da nave.
- player/<nome>_engine_boost.png: a mesma chama, mais longa e forte, para a nave acelerando para cima
  (o jogo já troca motor ocioso por motor em potência).
- player/<nome>_glow.png: silhueta borrada e branca da nave, na METADE da resolução (1 texel por unidade, o
  desenho é o mesmo: lado da base / 2), para o brilho de acento e o pulso de borda da evolução do hangar
  (scripts/view/ship_livery.gd). Vem do contorno da arte, então tem a licença da nave.
Grupos: player (os 12 do hangar, ids de data/ships.json) e klaed, nairan, nautolan (tipos de data/enemies.json).
Escala: TEXELS_PER_UNIT texels por unidade lógica; a nave é desenhada com tamanho = lado da textura / 2.

Grava em D:\\src\\assets-downloaded\\atlantis-mix\\ships (área de preparo, com sources.json) e em
assets/art/hd/ (a menos que --staging-only). Determinístico: mesma entrada, mesmos bytes.

Licenças sem manifesto em tools/*_assets.json: como tools/gen_portraits.py, o próprio gerador registra cada arquivo
em assets/asset_index.json (origem tools/gen_hd_ships.py) com a entrada do autor da nave (LICENSE_IDS), e o
tools/sync_assets.py preserva essas linhas. Manifesto não serviria: o arquivo final não é cópia do baixado (recorte,
escala, acabamento e chama própria). Os .import das texturas HD ficam no repositório com mipmaps/generate=true
(o jogo as desenha com filtro linear com mipmaps); arquivo novo precisa disso também (tests/sprite_bank_tests.gd).
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import os
import pathlib
import sys
from dataclasses import dataclass, field

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = pathlib.Path(__file__).resolve().parent.parent
DOWNLOADS = pathlib.Path(os.environ.get("ATLANTIS_DOWNLOADS", "D:/src/assets-downloaded"))
STAGING = DOWNLOADS / "atlantis-mix" / "ships"
OUT = ROOT / "assets" / "art" / "hd"
VOID = ROOT / "assets" / "art" / "void"

TEXELS_PER_UNIT = 2
ENGINE_FRAMES = 6
## Pluma do jogador acelerando, em relação à de cruzeiro.
BOOST = 1.45
## Cor média do mar do jogo (ocean_backdrop.gd, paleta "ocean": mid e lit) para as folhas de revisão.
WATER_MID = (10, 42, 58)
WATER_LIT = (28, 69, 88)

OGA = "opengameart"
MV = {
    "f1": f"{OGA}/set-faction1-spaceships/Faction1-Spaceships-by-MillionthVector",
    "f2": f"{OGA}/set-faction2-spaceships/Faction2-Spaceships-by-MillionthVector",
    "f3": f"{OGA}/set-faction3-spaceships/Faction3-Spaceships-by-MillionthVector",
    "f5": f"{OGA}/set-faction5-spaceships/Faction5-Spaceships-by-MillionthVector",
    "f6": f"{OGA}/set-faction6-spaceships/Faction6-Spaceships-by-MillionthVector",
    "f7": f"{OGA}/set-faction7-spaceships/Faction7-Spaceships-by-MillionthVector",
    "f10": f"{OGA}/set-faction10-spaceships/Faction10-Spaceships-by-MillionthVector",
}
XENIS = f"{OGA}/spaceships-xenis/Spaceships-16"
SPIDERS = "itch/whiteknightstudios-8-alien-bug-spider-sprites/Spiders"
BUGS_A = "itch/whiteknightstudios-alien-bug-sprites/My project (3).png"
BUGS_B = "itch/whiteknightstudios-top-down-alien-bug-sprites-2/bugz.png"
BUGS_C = "itch/whiteknightstudios-top-down-bug-sprites/Bugs topdown.png"

## Chama por grupo: (núcleo, meio, borda) em RGB 0..1 e estilo. "jet" = pluma de motor; "bio" = brilho
## bioluminescente curto e pulsante (insetos não têm bocal).
FLAMES = {
    "player": {"core": (0.92, 1.0, 1.0), "mid": (0.35, 0.85, 1.0), "edge": (0.08, 0.35, 1.0), "style": "jet"},
    "klaed": {"core": (1.0, 0.96, 0.78), "mid": (1.0, 0.58, 0.12), "edge": (0.9, 0.16, 0.04), "style": "jet"},
    "nairan": {"core": (1.0, 0.86, 0.8), "mid": (1.0, 0.25, 0.22), "edge": (0.62, 0.02, 0.12), "style": "bio"},
    "nautolan": {"core": (0.88, 1.0, 0.98), "mid": (0.25, 1.0, 0.88), "edge": (0.0, 0.5, 0.62), "style": "jet"},
}
## Lado maior da nave em unidades lógicas por tipo inimigo: ~1,3x o tamanho visível da série Void.
KIND_UNITS = {
    "scout": 30, "fighter": 36, "support": 40, "bomber": 42, "torpedo": 50, "frigate": 54,
    "battlecruiser": 112, "dreadnought": 128,
}


@dataclass
class Spec:
    group: str
    name: str
    src: str
    units: float
    rotate: int = 0  # graus anti-horário (90: nave que aponta para a direita passa a apontar para cima)
    cell: tuple | None = None  # (colunas, linhas, coluna, linha) numa folha de vários sprites
    outline: bool = True
    ## Bocais manuais (fração da largura da nave para o centro, fração da altura para a boca, fração da
    ## largura para o diâmetro). Vazio: acha sozinho pela borda de baixo.
    nozzles: list = field(default_factory=list)
    plume: float = 1.0  # multiplica o comprimento da chama
    despeckle: bool = False  # tira traços finos de 1–3 px (riscos de velocidade da Faction 7)
    ## Clareia os meios-tons (gama) e acende uma borda fina na cor dada: casco quase preto some no mar escuro.
    lift: float = 0.0
    rim: tuple | None = None
    license: str = ""


def mv(pack: str, file: str) -> str:
    return f"{MV[pack]}/{file}"


# Hangar, na ordem de data/ships.json. Aparência pelo papel: veloz = fina, defesa/explosiva = robusta.
PLAYER = [
    Spec("player", "falcon", f"{OGA}/blue-fighter-spaceship/BlueFighterSpaceship-by-MillionthVector/blueships1.png",
         56, rotate=90),
    Spec("player", "manta", f"{OGA}/fighter-spaceship/Fighter1-by-MillionthVector/topdownfighter.png", 56, rotate=90),
    Spec("player", "hydra", mv("f7", "blue2.png"), 56, despeckle=True),
    Spec("player", "tempest", mv("f2", "blueship2.png"), 54),
    Spec("player", "trident", f"{OGA}/yellow-starship/Starship-by-MillionthVector/ospaceship-main.png", 52,
         rotate=90),
    Spec("player", "atlas", mv("f7", "att5.png"), 52),
    Spec("player", "ram", mv("f7", "att3.png"), 60),
    Spec("player", "swarm", mv("f7", "blue1.png"), 58, despeckle=True),
    Spec("player", "eclipse", mv("f2", "blueship4.png"), 54),
    Spec("player", "nova", mv("f2", "blueship3.png"), 54),
    Spec("player", "titan", mv("f1", "smallorange.png"), 56),
    Spec("player", "ascension", mv("f2", "blueship1.png"), 58),
]

# Maré Negra (Kla'ed): preto e vermelho da Faction 5, preto e laranja da Faction 10 (aponta para a direita).
KLAED = [
    # Os dois menores da Faction 5 são quase pretos: meios-tons mais claros e borda vermelha fina (leitura no mar).
    Spec("klaed", "scout", mv("f5", "F5S1.png"), KIND_UNITS["scout"], plume=1.4, lift=0.45, rim=(1.0, 0.36, 0.24)),
    Spec("klaed", "fighter", mv("f5", "F5S2.png"), KIND_UNITS["fighter"], plume=1.4, lift=0.4, rim=(1.0, 0.36, 0.24)),
    Spec("klaed", "bomber", mv("f5", "F5S3.png"), KIND_UNITS["bomber"], plume=1.4),
    Spec("klaed", "support", mv("f10", "shuttlenoweps.png"), KIND_UNITS["support"], rotate=90),
    Spec("klaed", "torpedo", mv("f10", "cruiser.png"), KIND_UNITS["torpedo"], rotate=90),
    Spec("klaed", "frigate", mv("f5", "F5S4.png"), KIND_UNITS["frigate"], plume=1.4),
    Spec("klaed", "battlecruiser", mv("f10", "carrier.png"), KIND_UNITS["battlecruiser"], rotate=90),
    Spec("klaed", "dreadnought", mv("f10", "destroyer.png"), KIND_UNITS["dreadnought"], rotate=90),
]

# Nairan: insetos e aranhas (as aranhas olham para baixo na folha e giram 180°).
NAIRAN = [
    Spec("nairan", "scout", BUGS_A, KIND_UNITS["scout"], cell=(5, 4, 1, 3)),
    Spec("nairan", "fighter", BUGS_A, KIND_UNITS["fighter"], cell=(5, 4, 0, 1)),
    Spec("nairan", "bomber", BUGS_B, KIND_UNITS["bomber"], cell=(3, 4, 1, 3)),
    Spec("nairan", "support", BUGS_C, KIND_UNITS["support"], cell=(3, 3, 2, 1)),
    Spec("nairan", "torpedo", BUGS_C, KIND_UNITS["torpedo"], cell=(3, 3, 0, 1)),
    Spec("nairan", "frigate", BUGS_B, KIND_UNITS["frigate"], cell=(3, 4, 1, 0)),
    # Aranhas: as pernas ocupam o quadrado todo; 0,88x para o corpo ficar do porte dos outros cruzadores.
    Spec("nairan", "battlecruiser", f"{SPIDERS}/4.png", KIND_UNITS["battlecruiser"] * 0.88, rotate=180),
    Spec("nairan", "dreadnought", f"{SPIDERS}/7.png", KIND_UNITS["dreadnought"] * 0.88, rotate=180),
]

# Nautolan: XENIS (halo azul-petróleo), alienígenas roxos da Faction 3 e vermelhos da Faction 6.
NAUTOLAN = [
    Spec("nautolan", "scout", f"{XENIS}/xenis-blue-c-1.png", KIND_UNITS["scout"], outline=False),
    Spec("nautolan", "fighter", f"{XENIS}/xenis-blue-b-1.png", KIND_UNITS["fighter"], outline=False),
    Spec("nautolan", "bomber", mv("f6", "RD3.png"), KIND_UNITS["bomber"]),
    Spec("nautolan", "support", mv("f3", "alien4.png"), KIND_UNITS["support"]),
    Spec("nautolan", "torpedo", mv("f3", "alien2.png"), KIND_UNITS["torpedo"]),
    Spec("nautolan", "frigate", f"{XENIS}/xenis-blue-a-1.png", KIND_UNITS["frigate"], outline=False),
    Spec("nautolan", "battlecruiser", mv("f3", "alien1.png"), KIND_UNITS["battlecruiser"]),
    Spec("nautolan", "dreadnought", mv("f6", "redship4.png"), KIND_UNITS["dreadnought"]),
]

SPECS = PLAYER + KLAED + NAIRAN + NAUTOLAN

LICENSES = {
    "MillionthVector": "CC-BY-3.0",
    "Carlos Alface": "CC-BY-3.0",
    "W_K_Studio": "CC0-1.0",
}
## Entrada de licenses/registry.json de cada autor (linhas de assets/asset_index.json).
LICENSE_IDS = {
    "MillionthVector": "millionthvector_spaceships",
    "Carlos Alface": "alface_xenis_spaceships",
    "W_K_Studio": "wk_studio_alien_bugs",
}
SOURCE = "tools/gen_hd_ships.py"
## Brilho da evolução: raio do borrão em unidades lógicas (o mesmo em texels: a textura tem 1 texel por unidade).
GLOW_BLUR = 3.0


def author_of(spec: Spec) -> str:
    if "xenis" in spec.src:
        return "Carlos Alface"
    if spec.src.startswith("itch/whiteknightstudios"):
        return "W_K_Studio"
    return "MillionthVector"


# ---------------------------------------------------------------- recorte e escala


def components(mask: np.ndarray) -> list[np.ndarray]:
    """Componentes conexas (4 vizinhos) por preenchimento do Pillow, sem scipy. Ignora grãos de até 8 px."""
    # .copy(): a imagem de fromarray pode ser só leitura, e o floodfill escreveria em lugar nenhum.
    img = Image.fromarray(np.where(mask, 255, 0).astype(np.uint8), "L").copy()
    out = []
    for _ in range(4000):
        hits = np.flatnonzero(np.asarray(img) == 255)
        if hits.size == 0:
            break
        y, x = divmod(int(hits[0]), img.width)
        ImageDraw.floodfill(img, (x, y), 128)
        comp = np.asarray(img) == 128
        if comp.sum() > 8:
            out.append(comp)
        ImageDraw.floodfill(img, (x, y), 0)
    return out


def isolate(im: Image.Image) -> Image.Image:
    """Fica só com a nave: tira riscos de velocidade soltos, poeira e antenas da célula vizinha."""
    rgba = np.asarray(im).copy()
    mask = rgba[..., 3] > 24
    # Liga partes separadas por 1 px (halo e casco) antes de medir.
    grown = np.asarray(Image.fromarray(mask.astype(np.uint8) * 255).filter(ImageFilter.MaxFilter(3))) > 0
    comps = components(grown)
    if not comps:
        return im
    areas = [int(c.sum()) for c in comps]
    big = max(areas)
    keep = np.zeros_like(mask)
    for comp, area in zip(comps, areas):
        if area >= big * 0.15:
            keep |= comp
    rgba[..., 3] = np.where(keep, rgba[..., 3], 0)
    return Image.fromarray(rgba, "RGBA")


def load(spec: Spec) -> Image.Image:
    im = Image.open(DOWNLOADS / spec.src).convert("RGBA")
    if spec.cell:
        cols, rows, c, r = spec.cell
        cw, ch = im.width / cols, im.height / rows
        im = im.crop((round(c * cw), round(r * ch), round((c + 1) * cw), round((r + 1) * ch)))
    if spec.despeckle:
        # Abertura morfológica: o que tem menos de 5 px de espessura some; depois volta a borda suave.
        a = im.getchannel("A")
        body = a.point(lambda v: 255 if v > 24 else 0).filter(ImageFilter.MinFilter(5)).filter(ImageFilter.MaxFilter(7))
        rgba = np.asarray(im).copy()
        rgba[..., 3] = (rgba[..., 3].astype(np.uint16) * np.asarray(body) // 255).astype(np.uint8)
        im = Image.fromarray(rgba, "RGBA")
    im = isolate(im)
    if spec.rotate:
        im = im.rotate(spec.rotate, expand=True, resample=Image.Resampling.BICUBIC)
    bbox = im.getchannel("A").point(lambda a: 255 if a > 8 else 0).getbbox()
    return im.crop(bbox)


def downscale(im: Image.Image, long_px: int) -> Image.Image:
    """LANCZOS com alfa pré-multiplicado (sem franja escura na borda)."""
    k = long_px / max(im.size)
    size = (max(1, round(im.width * k)), max(1, round(im.height * k)))
    return im.convert("RGBa").resize(size, Image.Resampling.LANCZOS).convert("RGBA")


# ---------------------------------------------------------------- acabamento comum


def shift(a: np.ndarray, dx: int, dy: int) -> np.ndarray:
    out = np.zeros_like(a)
    h, w = a.shape
    xs, xd = (slice(0, w - dx), slice(dx, w)) if dx >= 0 else (slice(-dx, w), slice(0, w + dx))
    ys, yd = (slice(0, h - dy), slice(dy, h)) if dy >= 0 else (slice(-dy, h), slice(0, h + dy))
    out[yd, xd] = a[ys, xs]
    return out


def finish(im: Image.Image, spec: Spec) -> Image.Image:
    """Uma família só: tom e saturação parecidos, nitidez, luz de borda vinda de cima-esquerda NA TELA e contorno."""
    rgb_img = im.convert("RGB").filter(ImageFilter.UnsharpMask(radius=1.2, percent=55, threshold=1))
    rgb = np.asarray(rgb_img).astype(np.float32) / 255.0
    a = np.asarray(im.getchannel("A")).astype(np.float32) / 255.0
    solid = a > 0.5
    lum = rgb @ np.array([0.299, 0.587, 0.114], np.float32)
    if solid.sum() > 16:
        lo, hi = np.percentile(lum[solid], [2, 98])
        stretched = (rgb - lo) / max(hi - lo, 1e-3) * 0.9 + 0.03
        rgb = rgb * 0.55 + np.clip(stretched, 0, 1) * 0.45
        lum = rgb @ np.array([0.299, 0.587, 0.114], np.float32)
        sat = np.abs(rgb - lum[..., None]).mean(-1)
        k = float(np.clip(0.16 / max(float(sat[solid].mean()), 1e-3), 0.9, 1.25))
        rgb = np.clip(lum[..., None] + (rgb - lum[..., None]) * k, 0, 1)
    # Luz de borda: o jogo gira o inimigo 180°, então a luz dele vem de baixo-direita na textura.
    d = max(1, round(max(im.size) / 90))
    lx, ly = (-d, -d) if spec.group == "player" else (d, d)
    edge = np.clip(a - shift(a, -lx, -ly), 0, 1)
    edge = np.asarray(Image.fromarray((edge * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.6)))
    edge = edge.astype(np.float32) / 255.0 * a
    rgb = np.clip(rgb + edge[..., None] * np.array([0.55, 0.62, 0.7], np.float32) * 0.55, 0, 1)
    if spec.lift > 0.0:
        rgb = np.clip(rgb, 0, 1) ** (1.0 / (1.0 + spec.lift))
    if spec.rim is not None:
        # Borda de dentro, toda a volta, na cor do rim (1 texel e meio).
        inner = np.asarray(Image.fromarray((a * 255).astype(np.uint8)).filter(ImageFilter.MinFilter(3)))
        band = np.clip(a - inner.astype(np.float32) / 255.0, 0, 1)
        band = np.asarray(Image.fromarray((band * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.5)))
        band = band.astype(np.float32) / 255.0 * a * 0.75
        rgb = rgb + (np.array(spec.rim, np.float32) - rgb) * band[..., None]
    out = np.dstack([rgb, a])
    if spec.outline:
        grown = np.asarray(Image.fromarray((a * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(3)))
        ring = np.clip(grown.astype(np.float32) / 255.0 - a, 0, 1) * 0.8
        dark = np.array([0.03, 0.045, 0.07], np.float32)
        alpha = a + ring * (1 - a)
        col = (rgb * a[..., None] + dark * (ring * (1 - a))[..., None]) / np.maximum(alpha, 1e-4)[..., None]
        out = np.dstack([col, alpha])
    return Image.fromarray((np.clip(out, 0, 1) * 255 + 0.5).astype(np.uint8), "RGBA")


# ---------------------------------------------------------------- bocais e chama


def find_nozzles(alpha: np.ndarray) -> list[tuple[float, float, float]]:
    """Bocais na borda de baixo: colunas cujo casco maciço desce até perto do ponto mais baixo.

    "Maciço" = densidade de alfa numa janela; tira pernas, antenas e lâminas finas, que não soltam chama.
    Devolve (x do centro, y da boca, diâmetro) em pixels da nave já escalada.
    """
    h, w = alpha.shape
    k = max(3, (round(min(w, h) * 0.07) // 2) * 2 + 1)
    dens = np.asarray(Image.fromarray(((alpha > 0.5) * 255).astype(np.uint8)).filter(ImageFilter.BoxBlur(k // 2)))
    solid = dens > 150
    if not solid.any():
        solid = alpha > 0.5
    rows = np.arange(h)[:, None]
    bottom = np.where(solid, rows, -1).max(0)
    ymax = int(bottom.max())
    tol = max(3, round(h * 0.07))
    cols = bottom >= ymax - tol
    runs, start = [], None
    for x in range(w + 1):
        on = x < w and bool(cols[x])
        if on and start is None:
            start = x
        if not on and start is not None:
            runs.append((start, x))
            start = None
    # Junta bocais separados por fresta de 1–2 px.
    merged = []
    for r in runs:
        if merged and r[0] - merged[-1][1] <= 2:
            merged[-1] = (merged[-1][0], r[1])
        else:
            merged.append(r)
    merged = sorted(merged, key=lambda r: r[0] - r[1])[:4]
    out = []
    for x0, x1 in sorted(merged):
        width = x1 - x0
        y = float(bottom[x0:x1].mean())
        if width > w * 0.3:
            # Popa larga e lisa: dois bocais em vez de uma chama da largura da nave.
            for f in (0.27, 0.73):
                out.append((x0 + width * f, y, width * 0.32))
        else:
            out.append(((x0 + x1) / 2, y, max(3.0, width * 0.9)))
    return out


def smooth(t: np.ndarray) -> np.ndarray:
    t = np.clip(t, 0, 1)
    return t * t * (3 - 2 * t)


def flame_frame(size: int, nozzles: list, colors: dict, frame: int, boost: bool) -> Image.Image:
    """Um quadro da chama: pluma afilada com núcleo claro, halo suave na boca, tremor determinístico."""
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float32) + 0.5
    inten = np.zeros((size, size), np.float32)
    core = np.zeros((size, size), np.float32)
    style = colors["style"]
    t = 2 * math.pi * frame / ENGINE_FRAMES
    for i, (cx, cy, dia, nominal) in enumerate(nozzles):
        ph = i * 1.7
        flick = 1 + 0.11 * math.sin(t + ph) + 0.05 * math.sin(2 * t + 2 * ph + 0.6)
        bright = 0.92 + 0.08 * math.cos(t + ph * 0.5)
        if style == "bio":
            # Brilho redondo e pulsante: lanterna de inseto, não motor.
            r = nominal * 0.85 * (1 + 0.12 * math.sin(t + ph))
            d2 = ((xx - cx) / r) ** 2 + ((yy - (cy + r * 0.15)) / (r * 1.25)) ** 2
            inten = np.maximum(inten, np.exp(-d2 * 1.6) * bright)
            core = np.maximum(core, np.exp(-d2 * 5.0) * bright)
            continue
        half = dia / 2 * (1 + 0.05 * math.sin(t + ph + 1.3)) * (1.1 if boost else 1.0)
        length = nominal * (BOOST if boost else 1.0) * flick
        y0 = cy - 2.0  # começa um pouco dentro do casco, que cobre a emenda
        v = (yy - y0) / length
        prof = np.clip(1 - v, 0, 1) ** 0.65 * (0.72 + 0.28 * np.clip(v * 5, 0, 1))
        u = np.abs(xx - cx) / np.maximum(half * prof, 1e-3)
        body = np.where((v >= 0) & (v <= 1), np.clip(1 - u * u, 0, 1) * np.clip(1 - v, 0, 1) ** 0.75, 0)
        uc = np.abs(xx - cx) / np.maximum(half * 0.42 * prof, 1e-3)
        vc = v / 0.55
        cor = np.where((v >= 0) & (vc <= 1), np.clip(1 - uc * uc, 0, 1) * np.clip(1 - vc, 0, 1) ** 0.8, 0)
        # Brilho na boca do bocal (bloom falso).
        hr = dia * 0.9
        halo = np.exp(-(((xx - cx) / hr) ** 2 + ((yy - cy) / (hr * 0.8)) ** 2) * 2.2) * 0.45
        inten = np.maximum(inten, np.maximum(body, halo) * bright)
        core = np.maximum(core, cor * bright)
    total = np.clip(inten * 0.85 + core * 0.55, 0, 1)
    edge, mid, hot = (np.array(colors[k], np.float32) for k in ("edge", "mid", "core"))
    c = edge + (mid - edge) * smooth(total * 2.2)[..., None]
    c = c + (hot - c) * smooth(total * 1.6 - 0.45)[..., None]
    alpha = np.clip(smooth(total * 1.5) ** 0.85, 0, 1)
    rgba = np.dstack([c, alpha])
    return Image.fromarray((np.clip(rgba, 0, 1) * 255 + 0.5).astype(np.uint8), "RGBA")


# ---------------------------------------------------------------- montagem


def build(spec: Spec) -> dict:
    src = load(spec)
    long_px = round(spec.units * TEXELS_PER_UNIT)
    ship = finish(downscale(src, long_px), spec)
    w, h = ship.size
    flame = FLAMES[spec.group]
    alpha = np.asarray(ship.getchannel("A")).astype(np.float32) / 255.0
    if spec.nozzles:
        nozzles = [(fx * w, fy * h, fd * w) for fx, fy, fd in spec.nozzles]
    else:
        nozzles = find_nozzles(alpha)
    # Comprimento nominal da pluma: proporcional ao bocal, com teto pela altura da nave (nave grande não
    # arrasta meia tela de fogo). Acelerando, o jogador usa BOOST vezes esse comprimento.
    cap = h * (0.15 if spec.units >= 100 else 0.27) * spec.plume
    # Bocal mínimo: chama fina demais some no mar em tela de celular.
    nozzles = [(x, y, max(d, w * 0.1)) for x, y, d in nozzles]
    boost = BOOST if spec.group == "player" else 1.0
    if flame["style"] == "bio":
        lengths = [n[2] * 0.9 for n in nozzles]
        reach = max((y + L * boost - h for (_, y, _), L in zip(nozzles, lengths)), default=0.0)
    else:
        lengths = [min(n[2] * 2.2 * spec.plume, cap) for n in nozzles]
        reach = max((y - 2 + L * boost * 1.16 - h for (_, y, _), L in zip(nozzles, lengths)), default=0.0)
    pad = math.ceil(max(4.0, reach + 3))
    side = max(w, h + 2 * pad) + 2
    side += side % 2
    ox, oy = (side - w) // 2, (side - h) // 2
    base = Image.new("RGBA", (side, side))
    base.paste(ship, (ox, oy))
    placed = [(x + ox, y + oy, d, L) for (x, y, d), L in zip(nozzles, lengths)]
    strips = {}
    variants = [("engine", False)] + ([("engine_boost", True)] if spec.group == "player" else [])
    for label, is_boost in variants:
        strip = Image.new("RGBA", (side * ENGINE_FRAMES, side))
        for f in range(ENGINE_FRAMES):
            strip.paste(flame_frame(side, placed, flame, f, is_boost), (f * side, 0))
        strips[label] = strip
    return {"spec": spec, "base": base, "strips": strips, "side": side, "ship": (w, h), "nozzles": placed}


def glow(base: Image.Image) -> Image.Image:
    """Silhueta branca borrada, na metade da resolução da base (1 texel por unidade lógica)."""
    half = base.getchannel("A").resize((base.width // 2, base.height // 2), Image.Resampling.BOX)
    a = half.filter(ImageFilter.MaxFilter(3)).filter(ImageFilter.GaussianBlur(GLOW_BLUR))
    # Reforça o miolo do borrão: o brilho aparece como auréola, não como névoa rala.
    a = a.point(lambda v: min(255, round(v * 1.6)))
    out = Image.new("RGBA", half.size, (255, 255, 255, 0))
    out.putalpha(a)
    return out


def save_png(im: Image.Image, path: pathlib.Path) -> int:
    path.parent.mkdir(parents=True, exist_ok=True)
    im.save(path, optimize=True)
    return path.stat().st_size


# ---------------------------------------------------------------- folhas de revisão


def water(size: tuple[int, int]) -> Image.Image:
    w, h = size
    g = np.linspace(0, 1, h, dtype=np.float32)[:, None, None]
    a, b = np.array(WATER_MID, np.float32), np.array(WATER_LIT, np.float32)
    col = a + (b - a) * (0.5 + 0.5 * np.sin(g * 9.0)) * 0.6
    return Image.fromarray(np.broadcast_to(col, (h, w, 3)).astype(np.uint8), "RGB").convert("RGBA")


def composite(entry: dict, frame: int, boost: bool = False) -> Image.Image:
    side = entry["side"]
    strip = entry["strips"]["engine_boost" if boost else "engine"]
    out = strip.crop((frame * side, 0, (frame + 1) * side, side))
    out.alpha_composite(entry["base"])
    return out


def old_sprite(spec: Spec) -> Image.Image | None:
    path = VOID / ("main_ship/base_full.png" if spec.group == "player" else f"{spec.group}/{spec.name}_base.png")
    if not path.exists():
        return None
    im = Image.open(path).convert("RGBA")
    eng = VOID / ("main_ship/engine_base_idle.png" if spec.group == "player" else f"{spec.group}/{spec.name}_engine.png")
    if eng.exists():
        e = Image.open(eng).convert("RGBA")
        e = e.crop((0, 0, e.height, e.height))
        e.alpha_composite(im)
        im = e
    return im


def grid(cells: list, cols: int, pad: int) -> Image.Image:
    """Cola imagens RGBA numa grade sobre o mar, cada uma centrada na sua célula."""
    cw = max(c.width for c in cells) + pad
    ch = max(c.height for c in cells) + pad
    rows = math.ceil(len(cells) / cols)
    sheet = water((cw * min(cols, len(cells)), ch * rows))
    for i, c in enumerate(cells):
        x, y = (i % cols) * cw, (i // cols) * ch
        sheet.alpha_composite(c, (x + (cw - c.width) // 2, y + (ch - c.height) // 2))
    return sheet


def pair(old: Image.Image | None, new: Image.Image, gap: int) -> Image.Image:
    """Nave antiga (Void) à esquerda e a nova à direita, na mesma escala."""
    ow = old.width + gap if old is not None else 0
    out = Image.new("RGBA", (ow + new.width, max(new.height, old.height if old is not None else 0)))
    if old is not None:
        out.alpha_composite(old, (0, (out.height - old.height) // 2))
    out.alpha_composite(new, (ow, (out.height - new.height) // 2))
    return out


def stack(sheets: list) -> Image.Image:
    out = water((max(s.width for s in sheets), sum(s.height for s in sheets)))
    y = 0
    for s in sheets:
        out.alpha_composite(s, (0, y))
        y += s.height
    return out


def preview(entries: list, folder: pathlib.Path) -> list[pathlib.Path]:
    """Folhas de revisão sobre a cor do mar do jogo.

    hd_ships_1x.png: 1 px = 1 unidade lógica (o campo tem 270 de largura), antiga (Void) ao lado da nova.
    hd_ships_4x_<grupo>.png: 4x, antiga e nova. hd_engines_frames.png: todos os quadros do motor (2x).
    """
    folder.mkdir(parents=True, exist_ok=True)
    paths = []
    groups = ["player", "klaed", "nairan", "nautolan"]

    def logical(e: dict, scale: int, frame: int = 1) -> Image.Image:
        im = composite(e, frame)
        return im.resize((im.width * scale // TEXELS_PER_UNIT,) * 2, Image.Resampling.LANCZOS)

    def old(e: dict, scale: int) -> Image.Image | None:
        im = old_sprite(e["spec"])
        return None if im is None else im.resize((im.width * scale, im.height * scale), Image.Resampling.NEAREST)

    sheets = []
    for g in groups:
        items = [e for e in entries if e["spec"].group == g]
        cells = [pair(old(e, 1), logical(e, 1), 2) for e in items]
        sheets.append(grid(cells, 6 if g == "player" else 4, 8))
    path = folder / "hd_ships_1x.png"
    stack(sheets).save(path)
    paths.append(path)
    for g in groups:
        items = [e for e in entries if e["spec"].group == g]
        cells = [pair(old(e, 4), logical(e, 4), 8) for e in items]
        path = folder / f"hd_ships_4x_{g}.png"
        grid(cells, 4, 24).save(path)
        paths.append(path)
    # Motores: todos os quadros, a 2x da textura, para conferir tremor e posição dos bocais.
    pick = [e for e in entries if e["spec"].group == "player"][:4] + [
        e for e in entries if e["spec"].name in ("fighter", "frigate") and e["spec"].group != "player"]
    rows = []
    for e in pick:
        for boost in (False, True) if e["spec"].group == "player" else (False,):
            rows.append(grid([composite(e, f, boost) for f in range(ENGINE_FRAMES)], ENGINE_FRAMES, 4))
    path = folder / "hd_engines_frames.png"
    stack(rows).save(path)
    paths.append(path)
    return paths


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--preview", type=pathlib.Path, help="pasta (fora de assets) para as folhas de revisão")
    ap.add_argument("--staging-only", action="store_true", help="não grava em assets/art/hd")
    args = ap.parse_args()
    entries, total, table, rows = [], 0, [], []
    for spec in SPECS:
        e = build(spec)
        entries.append(e)
        files = {"base": e["base"], **e["strips"]}
        if spec.group == "player":
            files["glow"] = glow(e["base"])
        author = author_of(spec)
        for label, im in files.items():
            rel = f"{spec.group}/{spec.name}_{label}.png"
            total += save_png(im, STAGING / rel)
            if not args.staging_only:
                target = OUT / rel
                save_png(im, target)
                rows.append({"file": target.relative_to(ROOT).as_posix(), "source": SOURCE,
                             "license_id": LICENSE_IDS[author],
                             "sha256": hashlib.sha256(target.read_bytes()).hexdigest()})
        table.append({
            "id": spec.name if spec.group == "player" else f"{spec.group}_{spec.name}",
            "group": spec.group, "source": spec.src, "cell": spec.cell, "rotate_ccw": spec.rotate,
            "author": author, "license": LICENSES[author], "texture": e["side"],
            "draw_size": e["side"] / TEXELS_PER_UNIT, "ship_px": list(e["ship"]),
            "nozzles": [[round(v, 1) for v in n[:3]] for n in e["nozzles"]],
        })
        print(f"{table[-1]['id']:24s} {e['side']:4d}px  nave {e['ship'][0]}x{e['ship'][1]}  "
              f"bocais {len(e['nozzles'])}  <- {spec.src}")
    (STAGING / "sources.json").write_text(json.dumps(table, indent=1, ensure_ascii=False) + "\n", encoding="utf-8")
    if rows:
        index_path = ROOT / "assets" / "asset_index.json"
        index = json.loads(index_path.read_text(encoding="utf-8")) if index_path.exists() else []
        index = [r for r in index if r.get("source") != SOURCE] + rows
        index.sort(key=lambda item: item["file"])
        index_path.write_text(json.dumps(index, indent=1, ensure_ascii=False) + "\n", encoding="utf-8", newline="\n")
    print(f"total {total / 1024:.0f} KB em {len(SPECS)} naves")
    if args.preview:
        for p in preview(entries, args.preview):
            print("revisão:", p)
    return 0


if __name__ == "__main__":
    sys.exit(main())
