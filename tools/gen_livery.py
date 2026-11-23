"""Evolução da aeronave pelo nível do hangar (scripts/view/ship_livery.gd) e as avarias, em arte HD.

Desde 1.26 cada nível do 2 ao 10 monta uma PEÇA FÍSICA nova no casco (data/livery.json "levels"), cumulativa, no
mesmo acabamento metálico das naves HD (tools/gen_hd_ships.py): relevo com chanfro, luz de cima à esquerda na tela,
brilho especular, luz de borda, contorno escuro fino e sombra da peça sobre o casco. A cor vem da própria nave: uma
tabela luminância -> cor tirada dos pixels do casco no matiz dominante, então a peça parece do mesmo metal.

  2 armor         placas de blindagem nos flancos           6 canards       estabilizadores perto do nariz
  3 wing_guns     canhões de asa com boca acesa             7 missile_pods  casulos de mísseis laterais
  4 boosters      segundo par de motores (chama na vista)   8 sensor        domo sensor com antenas, no eixo
  5 fins          extensões de asa com friso aceso          9 coils         bobinas de energia acesas
 10 crown         coroa de ouro na popa e o acabamento de ouro em placas, canhões, motores, aletas e estabilizadores

Âncoras por nave em data/livery.json (fração da caixa opaca, lado esquerdo; as peças em par são espelhadas com a
mesma luz). Escala das peças pela caixa (data/livery.json "scale"); "points" diz à vista onde ficam a boca dos
canhões, os jatos e as pontas das aletas.

Saída:
  assets/art/hd/player/<nave>_evo.png       tira de 9 quadros (níveis 2..10) do tamanho da base: a nave montada;
  assets/art/hd/player/<nave>_evo_glow.png  a silhueta borrada de cada quadro (brilho de acento, pulso de ouro);
  assets/art/hd/player/<nave>_jet.png       chama dos propulsores extras, 6 quadros de cruzeiro + 6 de potência;
  assets/art/generated/livery/icon_<peça>.png  emblema 96x96 de cada peça (ladrilhos da Oficina);
  assets/art/generated/livery/crack.png     rachadura das avarias.
A nave montada e o brilho dela carregam a licença da nave (a base vem do pacote do autor); jatos, emblemas e
rachadura são do projeto (MIT, "atlantis_generated"). Tudo é registrado em assets/asset_index.json (origem
tools/gen_livery.py), que o tools/sync_assets.py preserva; arquivos que sobraram de versões antigas são apagados.
As texturas novas em assets/art/hd precisam de mipmaps no .import: o gerador liga mipmaps/generate nos .import que
já existem (rode o Godot com --import depois e rode este gerador de novo na primeira vez).

Uso: python tools/gen_livery.py [--preview DIR]   (numpy e Pillow; --preview grava as folhas de revisão)
Determinístico: mesma entrada, mesmos bytes.
"""
from __future__ import annotations

import hashlib
import json
import math
import pathlib
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import gen_hd_ships as hd  # noqa: E402  (chama, brilho e as cores de motor das naves)

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "art" / "generated" / "livery"
HD = ROOT / "assets" / "art" / "hd" / "player"
DATA = ROOT / "data" / "livery.json"
INDEX = ROOT / "assets" / "asset_index.json"
HITBOXES = ROOT / "data" / "hitboxes.json"
OWN_LICENSE = "atlantis_generated"
SOURCE = "tools/gen_livery.py"
TPU = hd.TEXELS_PER_UNIT
ICON = 96
SS = 4  # superamostragem das peças (bordas macias)
## Raio em unidades em volta do ponto de acerto (a cabine, data/hitboxes.json) que nenhuma peça nem sombra cobre
## (tests/livery_tests.gd).
CLEAR = 3.0

GOLD_RAMP = ((0.24, 0.13, 0.03), (0.78, 0.55, 0.16), (1.0, 0.84, 0.4), (1.0, 0.97, 0.82))
WARM_RAMP = ((0.3, 0.04, 0.03), (0.85, 0.22, 0.1), (1.0, 0.55, 0.3), (1.0, 0.9, 0.8))
LIGHT = np.array([-0.5, -0.72, 0.85], np.float32) / np.linalg.norm([-0.5, -0.72, 0.85])
HALF = (LIGHT + np.array([0, 0, 1], np.float32)) / np.linalg.norm(LIGHT + np.array([0, 0, 1], np.float32))
OUTLINE = (0.03, 0.045, 0.07)


# ---------------------------------------------------------------- peças (unidades, lado esquerdo, nariz para cima)
# Primitivas: (forma, material, relevo, dados). forma: poly [(x, y)...], rect (x0, y0, x1, y1), tube (rect com perfil
# de cilindro vertical), oval (x0, y0, x1, y1). material: hull, plate (casco mais claro), dark, gold, glass, glow,
# warm; "trim" vira ouro na coroa (nível 10) e hull antes. relevo: altura do chanfro em unidades.

def _armor() -> list:
    """Placa de blindagem em duas camadas, com rebites e uma fenda acesa (a primeira peça tem de se ver)."""
    z = 1.4
    return _scaled([
        ("poly", "trim", 1.2, [(-1.2, -5.6), (1.7, -4.3), (2.3, 3.5), (0.0, 5.9), (-2.7, 4.0), (-2.9, -3.7)]),
        ("poly", "plate", 0.7, [(-0.7, -3.7), (1.0, -2.9), (1.4, 2.6), (0.0, 4.1), (-1.8, 2.9), (-1.9, -2.7)]),
        ("oval", "dark", 0.3, (-2.2, -3.4, -1.3, -2.5)), ("oval", "dark", 0.3, (0.9, 3.0, 1.8, 3.9)),
        ("rect", "glow", 0.0, (-0.35, -1.9, 0.35, 1.9)),
    ], z)


def _scaled(prims: list, z: float) -> list:
    out = []
    for shape, mat, relief, data in prims:
        if isinstance(data, list):
            data = [(x * z, y * z) for x, y in data]
        else:
            data = tuple(v * z for v in data)
        out.append((shape, mat, relief, data))
    return out


def _gun() -> list:
    return [
        ("tube", "trim", 1.0, (-2.3, -1.2, 2.3, 5.2)),
        ("tube", "dark", 0.9, (-0.95, -11.0, 0.95, 0.0)),
        ("tube", "hull", 0.8, (-1.15, -6.4, 1.15, -5.4)),
        ("tube", "hull", 0.9, (-1.4, -11.8, 1.4, -9.6)),
        ("oval", "glow", 0.0, (-0.6, -12.0, 0.6, -11.1)),
        ("rect", "glow", 0.0, (-0.35, 0.6, 0.35, 3.8)),
    ]


def _booster() -> list:
    return [
        ("poly", "dark", 0.9, [(-2.2, 4.6), (2.2, 4.6), (2.9, 7.6), (-2.9, 7.6)]),
        ("tube", "hull", 1.4, (-2.8, -6.0, 2.8, 5.2)),
        ("tube", "dark", 0.8, (-2.2, -6.6, 2.2, -4.8)),
        ("tube", "trim", 1.2, (-3.1, -1.2, 3.1, 0.6)),
        ("oval", "glow", 0.0, (-1.9, 6.8, 1.9, 7.9)),
    ]


def _fin() -> list:
    return [
        ("poly", "hull", 1.3, [(1.5, -4.0), (-3.0, -1.0), (-10.0, 6.5), (-11.0, 10.0), (-8.4, 10.0), (-3.0, 6.6),
                               (1.5, 5.0)]),
        ("poly", "glow", 0.0, [(-2.6, 0.1), (-3.2, -0.5), (-9.9, 6.6), (-9.3, 7.2)]),
        ("poly", "trim", 0.8, [(-10.3, 7.6), (-11.0, 10.0), (-8.4, 10.0), (-8.6, 8.4)]),
    ]


def _canard() -> list:
    return [
        ("poly", "hull", 1.0, [(1.2, -2.2), (-6.0, 1.0), (-7.2, 3.6), (1.2, 2.6)]),
        ("poly", "trim", 0.5, [(-6.0, 1.0), (-7.2, 3.6), (-6.0, 3.4), (-5.2, 1.7)]),
    ]


def _pod() -> list:
    return [
        ("tube", "warm", 0.9, (-1.75, -6.4, -0.25, -2.0)), ("tube", "warm", 0.9, (0.25, -6.4, 1.75, -2.0)),
        ("oval", "warm", 0.9, (-1.75, -7.2, -0.25, -5.6)), ("oval", "warm", 0.9, (0.25, -7.2, 1.75, -5.6)),
        ("tube", "hull", 1.4, (-2.4, -3.6, 2.4, 6.2)),
        ("tube", "dark", 0.9, (-2.5, 1.8, 2.5, 2.8)),
        ("tube", "dark", 0.7, (-1.6, 6.0, 1.6, 7.0)),
    ]


def _sensor() -> list:
    return [
        ("poly", "dark", 0.3, [(1.2, 1.4), (1.8, 1.0), (4.2, 7.4), (3.6, 7.7)]),
        ("poly", "dark", 0.3, [(-1.2, 1.4), (-1.8, 1.0), (-4.2, 7.4), (-3.6, 7.7)]),
        ("oval", "glow", 0.0, (3.3, 7.0, 4.5, 8.2)), ("oval", "glow", 0.0, (-4.5, 7.0, -3.3, 8.2)),
        ("oval", "trim", 1.0, (-3.4, -3.4, 3.4, 3.4)),
        ("oval", "glass", 1.6, (-2.4, -2.4, 2.4, 2.4)),
    ]


def _coil() -> list:
    out = [("tube", "dark", 1.0, (-1.4, -4.6, 1.4, 4.6)), ("rect", "glow", 0.0, (-0.7, -4.2, 0.7, 4.2))]
    for y in (-3.8, -1.6, 0.6, 2.8):
        out.append(("tube", "trim", 0.8, (-1.95, y, 1.95, y + 0.85)))
    return _scaled(out, 1.25)


def _crown() -> list:
    """Coroa da popa (no eixo): asas de ouro em V com três pontas e gema acesa."""
    left = [(0.0, -1.6), (-4.0, -0.6), (-8.6, 1.2), (-6.4, 2.6), (-9.2, 4.8), (-5.0, 4.4), (-2.6, 6.4), (0.0, 4.6)]
    right = [(-x, y) for x, y in left]
    return [
        ("poly", "gold", 1.3, left), ("poly", "gold", 1.3, right),
        ("poly", "gold", 1.2, [(0.0, -5.2), (1.6, -1.2), (0.0, 1.6), (-1.6, -1.2)]),
        ("oval", "glass", 1.4, (-1.5, 0.6, 1.5, 3.6)),
    ]


PARTS = {"armor": _armor, "wing_guns": _gun, "boosters": _booster, "fins": _fin, "canards": _canard,
         "missile_pods": _pod, "sensor": _sensor, "coils": _coil, "crown": _crown}
## Peças no eixo (uma só, sem espelho).
CENTER = {"sensor", "crown"}
## Peças que ficam ATRÁS do casco (presas por baixo): o casco cobre a emenda. As outras vão por cima, com sombra.
UNDER = {"fins"}


# ---------------------------------------------------------------- cor e luz

def smooth(t: np.ndarray) -> np.ndarray:
    t = np.clip(t, 0, 1)
    return t * t * (3 - 2 * t)


def ramp(stops: tuple, t: np.ndarray) -> np.ndarray:
    stops = np.array(stops, np.float32)
    x = np.clip(t, 0, 1) * (len(stops) - 1)
    i = np.minimum(x.astype(np.int32), len(stops) - 2)
    f = (x - i)[..., None]
    return stops[i] * (1 - f) + stops[i + 1] * f


def palette(base: Image.Image) -> tuple[np.ndarray, float]:
    """Tabela 64 x RGB: luminância -> cor média do casco no matiz dominante da nave (o metal dela), e a
    luminância mediana do casco (o tom de uma face plana da peça, para ela não sair mais clara que a nave)."""
    rgba = np.asarray(base).astype(np.float32) / 255.0
    solid = rgba[..., 3] > 0.9
    rgb = rgba[..., :3][solid]
    lum = rgb @ hd.LUMA
    chroma = rgb - lum[:, None]
    sat = np.abs(chroma).max(1)
    hue = np.arctan2(chroma[:, 2] - chroma[:, 1], chroma[:, 0] * 1.5)
    colored = sat > 0.06
    if colored.sum() > 40:
        hist, edges = np.histogram(hue[colored], bins=24, range=(-math.pi, math.pi), weights=sat[colored])
        peak = (edges[hist.argmax()] + edges[hist.argmax() + 1]) / 2
        near = np.abs(np.angle(np.exp(1j * (hue - peak)))) < 0.9
        keep = near | ~colored
    else:
        keep = np.ones(len(rgb), bool)
    rgb, lum = rgb[keep], lum[keep]
    table = np.zeros((64, 3), np.float32)
    filled = np.zeros(64, bool)
    bins = np.clip((lum * 63.99).astype(np.int32), 0, 63)
    for b in range(64):
        sel = bins == b
        if sel.sum() >= 3:
            table[b] = rgb[sel].mean(0)
            filled[b] = True
    xs = np.arange(64)
    for c in range(3):
        table[:, c] = np.interp(xs, xs[filled], table[filled, c]) if filled.any() else xs / 63
    # Suaviza e garante a rampa crescente em luminância (sem faixas).
    k = np.array([1, 2, 3, 2, 1], np.float32) / 9
    table = np.stack([np.convolve(np.pad(table[:, c], 2, mode="edge"), k, "valid") for c in range(3)], 1)
    return np.clip(table, 0, 1), float(np.median(lum))


def from_table(table: np.ndarray, lum: np.ndarray) -> np.ndarray:
    x = np.clip(lum, 0, 1) * 63
    i = np.minimum(x.astype(np.int32), 62)
    f = (x - i)[..., None]
    return table[i] * (1 - f) + table[i + 1] * f


def blur(a: np.ndarray, r: float) -> np.ndarray:
    if r <= 0:
        return a
    im = Image.fromarray(np.clip(a * 255, 0, 255).astype(np.uint8))
    return np.asarray(im.filter(ImageFilter.GaussianBlur(r))).astype(np.float32) / 255.0


# ---------------------------------------------------------------- render de uma peça

class Part:
    """Uma peça pronta em pixels da nave: imagem RGBA e o canto em pixels (float) relativo à âncora."""

    def __init__(self, image: Image.Image, origin: tuple[int, int]) -> None:
        self.image = image
        self.origin = origin


def render(prims: list, k: float, mirror: bool, metal: tuple, accent: tuple, gold: bool,
           frac: tuple[float, float], ppu: float = TPU) -> Part:
    """Rasteriza as primitivas (unidades * k) com a âncora em `frac` dentro do texel de origem.

    Devolve a peça já reduzida para `ppu` texels por unidade, com contorno escuro e luz de borda."""
    pts_all = []
    for _, _, _, data in prims:
        if isinstance(data, list):
            pts_all += data
        else:
            pts_all += [(data[0], data[1]), (data[2], data[3])]
    reach = max(max(abs(x), abs(y)) for x, y in pts_all) * k + 3
    half = math.ceil(reach * ppu)
    side = 2 * half
    big = side * SS
    s = ppu * SS * k
    ox, oy = (half + frac[0]) * SS, (half + frac[1]) * SS
    sx = -1.0 if mirror else 1.0

    def to_px(x: float, y: float) -> tuple[float, float]:
        return ox + x * sx * s, oy + y * s

    rgb = np.zeros((big, big, 3), np.float32)
    alpha = np.zeros((big, big), np.float32)
    yy, xx = np.mgrid[0:big, 0:big].astype(np.float32) + 0.5
    acc = np.array(accent, np.float32)
    table, mid = metal
    flat = float(LIGHT[2])
    for shape, mat, relief, data in prims:
        if mat == "trim":
            mat = "gold" if gold else "hull"
        layer = Image.new("L", (big, big), 0)
        d = ImageDraw.Draw(layer)
        if shape == "poly":
            d.polygon([to_px(x, y) for x, y in data], fill=255)
        else:
            (x0, y0), (x1, y1) = to_px(data[0], data[1]), to_px(data[2], data[3])
            box = (min(x0, x1), min(y0, y1), max(x0, x1), max(y0, y1))
            if shape == "oval":
                d.ellipse(box, fill=255)
            elif shape == "tube":
                d.rounded_rectangle(box, radius=min(box[2] - box[0], box[3] - box[1]) * 0.22, fill=255)
            else:
                d.rectangle(box, fill=255)
        m = np.asarray(layer).astype(np.float32) / 255.0
        if m.max() <= 0:
            continue
        bevel = max(1.0, relief * s * 0.9)
        h = blur(m, bevel * 0.55) * m
        if shape == "tube":
            (x0, _), (x1, _) = to_px(data[0], data[1]), to_px(data[2], data[3])
            cx, r = (x0 + x1) / 2, max(abs(x1 - x0) / 2, 1)
            h = np.minimum(np.sqrt(np.clip(1 - ((xx - cx) / r) ** 2, 0, 1)), h * 1.6) * m
        elif shape == "oval" and mat in ("glass", "gold", "hull", "warm"):
            (x0, y0), (x1, y1) = to_px(data[0], data[1]), to_px(data[2], data[3])
            cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
            rx, ry = max(abs(x1 - x0) / 2, 1), max(abs(y1 - y0) / 2, 1)
            h = np.sqrt(np.clip(1 - ((xx - cx) / rx) ** 2 - ((yy - cy) / ry) ** 2, 0, 1)) * m
        height = h * relief * s
        gy, gx = np.gradient(height)
        n = np.dstack([-gx, -gy, np.ones_like(gx)])
        n /= np.linalg.norm(n, axis=2, keepdims=True)
        diff = np.clip(n @ LIGHT, 0, 1)
        spec = np.clip(n @ HALF, 0, 1) ** 28
        lum = 0.16 + 0.84 * diff
        # Face plana no tom mediano do casco; chanfros de cima à esquerda clareiam, os do outro lado escurecem.
        tone = mid * (0.3 + 0.7 * diff / flat)
        if mat == "hull":
            col = from_table(table, tone) + spec[..., None] * 0.4
        elif mat == "plate":
            col = from_table(table, min(0.85, mid * 1.35) * (0.3 + 0.7 * diff / flat)) + spec[..., None] * 0.5
        elif mat == "dark":
            base = from_table(table, tone * 0.5)
            col = base * 0.7 + (base @ hd.LUMA)[..., None] * 0.3 + spec[..., None] * 0.35
        elif mat == "gold":
            col = ramp(GOLD_RAMP, lum * 0.9) + spec[..., None] * 0.7
        elif mat == "warm":
            col = ramp(WARM_RAMP, lum * 0.85) + spec[..., None] * 0.6
        elif mat == "glass":
            col = acc * (0.25 + 0.55 * lum)[..., None] + spec[..., None] * 1.0
            col += np.clip(1 - np.hypot(xx - xx[m > 0.5].mean(), yy - yy[m > 0.5].mean()) / (s * 3), 0, 1)[
                ..., None] * acc * 0.25
        else:  # glow: aceso, sem luz; miolo quase branco
            core = blur(m, max(1.0, s * 0.25))
            col = acc + (np.array([1.0, 1.0, 1.0], np.float32) - acc) * smooth(core * 1.6 - 0.5)[..., None] * 0.8
            col = np.broadcast_to(col, (big, big, 3))
        col = np.clip(col, 0, 1)
        rgb = rgb * (1 - m[..., None]) + col * m[..., None]
        alpha = alpha + m * (1 - alpha)
    small = side
    rgba = np.dstack([rgb * alpha[..., None], alpha])  # pré-multiplicado para reduzir sem franja
    im = Image.fromarray((np.clip(rgba, 0, 1) * 255 + 0.5).astype(np.uint8), "RGBA")
    im = im.resize((small, small), Image.Resampling.LANCZOS)
    arr = np.asarray(im).astype(np.float32) / 255.0
    a = arr[..., 3]
    col = arr[..., :3] / np.maximum(a, 1e-4)[..., None]
    # Luz de borda de cima à esquerda (a mesma família das naves) e contorno escuro fino.
    lit = np.clip(a - hd.shift(a, 1, 1), 0, 1) * a
    col = np.clip(col + lit[..., None] * np.array([0.55, 0.62, 0.7], np.float32) * 0.45, 0, 1)
    grown = np.asarray(Image.fromarray((a * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(3)))
    ring = np.clip(grown.astype(np.float32) / 255.0 - a, 0, 1) * 0.85
    out_a = a + ring * (1 - a)
    out_c = (col * a[..., None] + np.array(OUTLINE, np.float32) * (ring * (1 - a))[..., None]) / np.maximum(
        out_a, 1e-4)[..., None]
    out = np.dstack([np.clip(out_c, 0, 1), out_a])
    return Part(Image.fromarray((out * 255 + 0.5).astype(np.uint8), "RGBA"), (-half, -half))


# ---------------------------------------------------------------- montagem por nave

def used_box(base: Image.Image) -> tuple[int, int, int, int]:
    """Caixa opaca como o Image.get_used_rect do Godot (alfa > 0)."""
    return base.getchannel("A").getbbox()


def ship_scale(cfg: dict, ship: dict, box: tuple) -> float:
    if "k" in ship:
        return float(ship["k"])
    sc = cfg["scale"]
    short = min(box[2] - box[0], box[3] - box[1]) / TPU
    return float(np.clip(short / sc["ref"], sc["min"], sc["max"]))


def anchor_px(box: tuple, frac: list, mirror: bool = False) -> tuple[float, float]:
    fx = 1.0 - frac[0] if mirror else frac[0]
    return box[0] + (box[2] - box[0]) * fx, box[1] + (box[3] - box[1]) * frac[1]


def instances(cfg: dict, ship: dict, part: str) -> list[bool]:
    """Lados de uma peça: [False] no eixo, [False, True] em par (esquerda e espelhada)."""
    if part not in ship:
        return []
    return [False] if part in CENTER else [False, True]


def place(canvas: Image.Image, part: Part, at: tuple[float, float]) -> None:
    x, y = math.floor(at[0]), math.floor(at[1])
    canvas.alpha_composite(part.image, (x + part.origin[0], y + part.origin[1])) if (
        x + part.origin[0] >= 0 and y + part.origin[1] >= 0) else _paste_clipped(canvas, part, x, y)


def _paste_clipped(canvas: Image.Image, part: Part, x: int, y: int) -> None:
    layer = Image.new("RGBA", canvas.size)
    layer.paste(part.image, (x + part.origin[0], y + part.origin[1]))
    canvas.alpha_composite(layer)


def shadow(hull_alpha: np.ndarray, over: Image.Image, hit: tuple[float, float]) -> Image.Image:
    """Sombra das peças de cima sobre o casco: o alfa delas borrado, deslocado para baixo à direita."""
    a = np.asarray(over.getchannel("A")).astype(np.float32) / 255.0
    a = hd.shift(blur(a, 1.4), 2, 2) * hull_alpha * 0.42
    # O ponto de acerto fica limpo: nem peça nem sombra num raio de CLEAR unidades.
    side = a.shape[0]
    yy, xx = np.mgrid[0:side, 0:side].astype(np.float32) + 0.5
    a *= smooth((np.hypot(xx - hit[0], yy - hit[1]) - CLEAR * TPU) / TPU)
    out = np.zeros(a.shape + (4,), np.float32)
    out[..., :3] = 0.02
    out[..., 3] = a
    return Image.fromarray((out * 255 + 0.5).astype(np.uint8), "RGBA")


def assemble(ship_id: str, cfg: dict) -> dict:
    base = Image.open(HD / f"{ship_id}_base.png").convert("RGBA")
    ship = cfg["ships"][ship_id]
    box = used_box(base)
    k = ship_scale(cfg, ship, box)
    metal = palette(base)
    accent = tuple(int(ship["accent"][i:i + 2], 16) / 255.0 for i in (1, 3, 5))
    hull_alpha = np.asarray(base.getchannel("A")).astype(np.float32) / 255.0
    hit = hit_point(ship_id, base.width)
    order = [lv["id"] for lv in cfg["levels"]]
    frames, glows = [], []
    for upto in range(len(order)):
        gold = upto == len(order) - 1
        under = Image.new("RGBA", base.size)
        over = Image.new("RGBA", base.size)
        for part in order[:upto + 1]:
            for mirror in instances(cfg, ship, part):
                at = anchor_px(box, ship[part], mirror)
                frac = (at[0] - math.floor(at[0]), at[1] - math.floor(at[1]))
                piece = render(PARTS[part](), k, mirror, metal, accent, gold, frac)
                place(under if part in UNDER else over, piece, at)
        frame = under.copy()
        frame.alpha_composite(base)
        frame.alpha_composite(shadow(hull_alpha, over, hit))
        frame.alpha_composite(over)
        frames.append(frame)
        glows.append(hd.glow(frame))
    check_clear(ship_id, base, frames[-1], hit)
    return {"id": ship_id, "base": base, "frames": frames, "glows": glows, "k": k, "box": box}


def hit_point(ship_id: str, side: int) -> tuple[float, float]:
    """Ponto de acerto da nave em texels do quadro: o centro mais o "offset" de data/hitboxes.json (a cabine)."""
    ships = json.loads(HITBOXES.read_text(encoding="utf-8")).get("ships", {}) if HITBOXES.exists() else {}
    off = ships.get(ship_id, {}).get("offset", [0.0, 0.0])
    return side / 2 + off[0] * TPU, side / 2 + off[1] * TPU


def check_clear(ship_id: str, base: Image.Image, frame: Image.Image, hit: tuple[float, float]) -> None:
    """Falha se alguma peça encosta no ponto de acerto: mude a âncora em data/livery.json."""
    b = np.asarray(base).astype(np.int32)
    f = np.asarray(frame).astype(np.int32)
    side = b.shape[0]
    yy, xx = np.mgrid[0:side, 0:side].astype(np.float32) + 0.5
    near = np.hypot(xx - hit[0], yy - hit[1]) <= CLEAR * TPU
    if np.abs(f - b).max(2)[near].max() > 8:
        raise SystemExit(f"{ship_id}: peça sobre o ponto de acerto (raio {CLEAR} unidades); mova a âncora")


def strip(images: list) -> Image.Image:
    w, h = images[0].size
    out = Image.new("RGBA", (w * len(images), h))
    for i, im in enumerate(images):
        out.paste(im, (i * w, 0))
    return out


# ---------------------------------------------------------------- jatos dos propulsores

JET = 48  # quadro do jato em texels (24 unidades)


def jet_strip(flame: dict, width_units: float) -> Image.Image:
    """6 quadros de cruzeiro e 6 de potência; a boca no alto do quadro, no centro (x = JET/2, y = 2)."""
    d = width_units * TPU
    nozzle = [(JET / 2, 2.0, d, min(d * 2.2, JET * 0.42))]
    frames = [hd.flame_frame(JET, nozzle, flame, f, False) for f in range(hd.ENGINE_FRAMES)]
    frames += [hd.flame_frame(JET, nozzle, flame, f, True) for f in range(hd.ENGINE_FRAMES)]
    return strip(frames)


def flame_of(ship_id: str) -> dict:
    for spec in hd.PREMIUM:
        if spec.name == ship_id and spec.premium is not None and spec.premium.flame:
            return spec.premium.flame
    return hd.FLAMES["player"]


# ---------------------------------------------------------------- emblemas e rachadura

GENERIC = [(0.5, 0.1), (0.6, 0.38), (0.84, 0.62), (0.82, 0.72), (0.58, 0.68), (0.55, 0.84), (0.45, 0.84),
           (0.42, 0.68), (0.18, 0.72), (0.16, 0.62), (0.4, 0.38)]
## Âncoras de cada peça no emblema (fração do ícone, lado esquerdo).
ICON_AT = {"armor": (0.38, 0.52), "wing_guns": (0.3, 0.56), "boosters": (0.42, 0.56), "fins": (0.4, 0.42),
           "canards": (0.42, 0.34), "missile_pods": (0.3, 0.56), "sensor": (0.5, 0.36), "coils": (0.37, 0.55),
           "crown": (0.5, 0.6)}
ICON_METAL = (np.stack([np.linspace(0.1, 0.78, 64), np.linspace(0.16, 0.88, 64), np.linspace(0.24, 1.0, 64)], 1), 0.6)


def icon(part: str, accent: tuple) -> Image.Image:
    """Nave genérica apagada e a peça montada nela, acesa no mesmo acabamento do jogo."""
    im = Image.new("RGBA", (ICON * SS, ICON * SS))
    d = ImageDraw.Draw(im)
    d.polygon([(x * ICON * SS, y * ICON * SS) for x, y in GENERIC], fill=(46, 70, 96, 255))
    im = im.resize((ICON, ICON), Image.Resampling.LANCZOS)
    ppu = 2.6
    for mirror in ([False] if part in CENTER else [False, True]):
        fx, fy = ICON_AT[part]
        at = ((1 - fx if mirror else fx) * ICON, fy * ICON)
        frac = (at[0] - math.floor(at[0]), at[1] - math.floor(at[1]))
        piece = render(PARTS[part](), 1.0, mirror, ICON_METAL, accent, part == "crown", frac, ppu)
        if part == "boosters":
            jet = hd.flame_frame(40, [(20, 2, 4.4 * ppu, 14)], hd.FLAMES["player"], 1, False)
            im.alpha_composite(jet, (math.floor(at[0]) - 20, math.floor(at[1] + 7.2 * ppu) - 2))
        place(im, piece, at)
    return im


def crack() -> Image.Image:
    """Rachadura em zigue-zague: borda escura larga e fio quente fino no meio (determinística)."""
    im = Image.new("RGBA", (24 * SS, 24 * SS))
    d = ImageDraw.Draw(im)
    w = 24 * SS
    pts = [(0.12, 0.2), (0.34, 0.4), (0.3, 0.55), (0.52, 0.62), (0.6, 0.82), (0.86, 0.88)]
    branch = [(0.52, 0.62), (0.74, 0.46), (0.88, 0.4)]
    for line, width, color in ((pts, 2.6, (10, 8, 8, 230)), (branch, 2.0, (10, 8, 8, 210)),
                               (pts, 0.9, (255, 150, 70, 255)), (branch, 0.7, (255, 150, 70, 220))):
        d.line([(x * w, y * w) for x, y in line], fill=color, width=round(width * SS), joint="curve")
    return im.resize((24, 24), Image.Resampling.LANCZOS)


# ---------------------------------------------------------------- gravação

def png(im: Image.Image, path: pathlib.Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    im.save(path, optimize=True)


def mipmaps_on(path: pathlib.Path) -> None:
    imp = path.with_name(path.name + ".import")
    if imp.exists():
        text = imp.read_text(encoding="utf-8")
        if "mipmaps/generate=false" in text:
            imp.write_text(text.replace("mipmaps/generate=false", "mipmaps/generate=true"), encoding="utf-8",
                           newline="\n")


def license_of(index: list, ship_id: str) -> str:
    want = f"assets/art/hd/player/{ship_id}_base.png"
    for row in index:
        if row["file"] == want:
            return row["license_id"]
    raise SystemExit(f"sem licença registrada para {want} (rode tools/gen_hd_ships.py)")


def main() -> int:
    cfg = json.loads(DATA.read_text(encoding="utf-8"))
    ships = [r["id"] for r in json.loads((ROOT / "data" / "ships.json").read_text(encoding="utf-8"))]
    index = json.loads(INDEX.read_text(encoding="utf-8")) if INDEX.exists() else []
    index = [r for r in index if r.get("source") != SOURCE]
    rows, built = [], []

    def save(im: Image.Image, target: pathlib.Path, license_id: str, hd_tex: bool) -> None:
        png(im, target)
        if hd_tex:
            mipmaps_on(target)
        rows.append({"file": target.relative_to(ROOT).as_posix(), "source": SOURCE, "license_id": license_id,
                     "sha256": hashlib.sha256(target.read_bytes()).hexdigest()})

    for ship_id in ships:
        if ship_id not in cfg["ships"] or not (HD / f"{ship_id}_base.png").exists():
            continue
        e = assemble(ship_id, cfg)
        built.append(e)
        lic = license_of(index, ship_id)
        save(strip(e["frames"]), HD / f"{ship_id}_evo.png", lic, True)
        save(strip(e["glows"]), HD / f"{ship_id}_evo_glow.png", lic, True)
        save(jet_strip(flame_of(ship_id), cfg["points"]["jet_width"]), HD / f"{ship_id}_jet.png", OWN_LICENSE, True)
        print(f"{ship_id:12s} k={e['k']:.2f}  {len(e['frames'])} quadros")
    files = {"crack": crack()}
    for lv in cfg["levels"]:
        files["icon_" + lv["id"]] = icon(lv["id"], (0.44, 0.91, 1.0))
    keep = set()
    for name, im in files.items():
        target = OUT / f"{name}.png"
        save(im, target, OWN_LICENSE, False)
        keep.add(target.name)
    # Arte de versões antigas (divisa, emblemas dos marcos de luz) que não sai mais.
    for old in OUT.glob("*.png"):
        if old.name not in keep:
            old.unlink()
            imp = old.with_name(old.name + ".import")
            if imp.exists():
                imp.unlink()
    index = sorted(index + rows, key=lambda item: item["file"])
    INDEX.write_text(json.dumps(index, indent=1, ensure_ascii=False) + "\n", encoding="utf-8", newline="\n")
    if "--preview" in sys.argv:
        preview(built, files, cfg, pathlib.Path(sys.argv[sys.argv.index("--preview") + 1]))
    print(f"{len(rows)} arquivos da evolução gerados")
    return 0


def preview(built: list, files: dict, cfg: dict, folder: pathlib.Path) -> None:
    """Folha 15 naves x níveis 1..10 sobre o mar (2x) e a fileira dos emblemas."""
    folder.mkdir(parents=True, exist_ok=True)
    z = 2
    cell = max(e["base"].width for e in built) * z
    sheet = hd.water((cell * 10, cell * len(built)))
    for r, e in enumerate(built):
        for c, im in enumerate([e["base"]] + e["frames"]):
            big = im.resize((im.width * z, im.height * z), Image.Resampling.LANCZOS)
            sheet.alpha_composite(big, (c * cell + (cell - big.width) // 2, r * cell + (cell - big.height) // 2))
    sheet.save(folder / "evo_sheet_gen.png")
    icons = [files["icon_" + lv["id"]] for lv in cfg["levels"]]
    row = Image.new("RGBA", (ICON * len(icons), ICON), (10, 30, 44, 255))
    for i, ic in enumerate(icons):
        row.alpha_composite(ic, (i * ICON, 0))
    row.save(folder / "evo_icons.png")
    print("prévia:", folder)


if __name__ == "__main__":
    sys.exit(main())
