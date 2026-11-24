"""Submarino e navio de guerra do Protocolo (inimigos na água, só o míssil teleguiado os atinge), em arte HD própria.

Mesmo formato e acabamento das naves HD (tools/gen_hd_ships.py): tela quadrada, 2 texels por unidade lógica, nave
apontando para CIMA (o jogo gira os inimigos em PI), luz que vem de cima à esquerda NA TELA (de baixo à direita na
textura), relevo com chanfro, brilho especular de metal, oclusão nas frestas, luz de borda e contorno escuro fino.
Tudo procedural (campos de distância em numpy, superamostrado SS vezes e reduzido), sem arte de terceiros: licença do
projeto ("atlantis_generated", MIT).

  sea/submarine_base.png  submarino visto de cima: casco escuro com ladrilhos anecoicos, vela (torre) com lemes de
                          vela e periscópios, escotilhas de míssil com aro coral, faixas coral do Protocolo e a cruz
                          de lemes da popa.
  sea/warship_base.png    fragata/destróier: proa em ponta, castelo de proa, canhão, células de lançamento vertical,
                          ponte com vidros acesos, mastro com radar, chaminé, lançador de mísseis giratório com as
                          ogivas coral, defesa de ponto e o heliponto na popa, com faixas coral.
  sea/<nome>_engine.png   tira de 6 quadros com a espuma da hélice (branca, desenhada ATRÁS do casco, na popa); a
                          esteira comprida na água a vista desenha (scripts/view/sea_view.gd).
  sea/foam.png            FOAM_FRAMES flocos de espuma granulada (32 x 32, brancos, tingidos na vista): a esteira em V,
                          a água batida e a onda de proa são feitas deles.

Registra cada arquivo em assets/asset_index.json (origem tools/gen_sea_ships.py) e liga mipmaps nos .import (as
texturas HD são desenhadas com filtro linear com mipmaps; na primeira vez rode o Godot com --import e este gerador de
novo). Depois rode tools/fit_hitboxes.py.

Uso: python tools/gen_sea_ships.py [--preview DIR]   (numpy e Pillow; determinístico: mesmos bytes a cada rodada)
"""
from __future__ import annotations

import hashlib
import json
import math
import pathlib
import sys

import numpy as np
from PIL import Image, ImageFilter

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "art" / "hd" / "sea"
INDEX = ROOT / "assets" / "asset_index.json"
LICENSE_ID = "atlantis_generated"
SOURCE = "tools/gen_sea_ships.py"
TPU = 2  # texels por unidade lógica (igual a gen_hd_ships.TEXELS_PER_UNIT)
SS = 4  # superamostragem
PPU = TPU * SS
FRAMES = 6
## Luz na textura (x para a direita, y para baixo, z para fora): de baixo à direita, que vira cima à esquerda na tela.
LIGHT = np.array([0.45, 0.55, 0.7], np.float32)
LIGHT /= np.linalg.norm(LIGHT)
HALF = (LIGHT + np.array([0, 0, 1], np.float32))
HALF /= np.linalg.norm(HALF)

CORAL = (0.86, 0.22, 0.24)
CORAL_HI = (1.0, 0.46, 0.42)
FOAM = (0.9, 0.97, 1.0)


class Canvas:
    """Albedo, altura (unidades), brilho metálico e emissão, pintados camada por camada (pintor)."""

    def __init__(self, side_units: float):
        self.side = side_units
        n = int(round(side_units * PPU))
        self.n = n
        c = (np.arange(n, dtype=np.float32) + 0.5) / PPU - side_units / 2
        self.y, self.x = np.meshgrid(c, c, indexing="ij")
        self.alpha = np.zeros((n, n), np.float32)
        self.albedo = np.zeros((n, n, 3), np.float32)
        self.height = np.zeros((n, n), np.float32)
        self.metal = np.zeros((n, n), np.float32)
        self.glow = np.zeros((n, n, 3), np.float32)

    def paint(self, mask: np.ndarray, color, height=None, metal: float | None = None, add_height: bool = False):
        m = np.clip(mask, 0, 1).astype(np.float32)
        col = np.asarray(color, np.float32)
        if col.ndim == 1:
            col = np.broadcast_to(col, self.albedo.shape)
        self.albedo = self.albedo * (1 - m[..., None]) + col * m[..., None]
        if height is not None:
            h = np.broadcast_to(np.asarray(height, np.float32), m.shape)
            self.height = self.height + h * m if add_height else self.height * (1 - m) + h * m
        if metal is not None:
            self.metal = self.metal * (1 - m) + metal * m
        self.alpha = np.maximum(self.alpha, m)

    def decal(self, mask: np.ndarray, color, k: float = 1.0):
        """Tinta sem relevo (faixas, marcas do heliponto): só o albedo, onde já há casco."""
        m = np.clip(mask, 0, 1).astype(np.float32) * self.alpha * k
        self.albedo = self.albedo * (1 - m[..., None]) + np.asarray(color, np.float32) * m[..., None]

    def emit(self, mask: np.ndarray, color, k: float = 1.0):
        m = np.clip(mask, 0, 1).astype(np.float32) * k
        self.glow = np.maximum(self.glow, np.asarray(color, np.float32) * m[..., None])


# ---------------------------------------------------------------- formas (unidades, y para baixo, proa em -y)


def box(c: Canvas, cx, cy, hw, hh, r=0.0) -> np.ndarray:
    """Distância com sinal a um retângulo de cantos arredondados (negativa dentro)."""
    qx = np.abs(c.x - cx) - (hw - r)
    qy = np.abs(c.y - cy) - (hh - r)
    out = np.hypot(np.maximum(qx, 0), np.maximum(qy, 0))
    return out + np.minimum(np.maximum(qx, qy), 0) - r


def circle(c: Canvas, cx, cy, r) -> np.ndarray:
    return np.hypot(c.x - cx, c.y - cy) - r


def inside(d: np.ndarray) -> np.ndarray:
    return (d <= 0).astype(np.float32)


def bevel(d: np.ndarray, width: float) -> np.ndarray:
    """0 na borda, 1 a `width` unidades para dentro, suave."""
    t = np.clip(-d / width, 0, 1)
    return t * t * (3 - 2 * t)


def noise(c: Canvas, cell: float, seed: int) -> np.ndarray:
    """Ruído de valor suave (-1..1), determinístico, com grão de `cell` unidades."""
    rng = np.random.default_rng(seed)
    k = max(2, int(math.ceil(c.side / cell)) + 1)
    small = Image.fromarray(((rng.random((k, k)) * 255).astype(np.uint8)), "L")
    big = small.resize((c.n, c.n), Image.Resampling.BICUBIC)
    return np.asarray(big, np.float32) / 127.5 - 1.0


# ---------------------------------------------------------------- acabamento


def gauss(a: np.ndarray, sigma_units: float) -> np.ndarray:
    """Borrão gaussiano separável (o Pillow não borra imagem em ponto flutuante)."""
    s = sigma_units * PPU
    r = int(math.ceil(s * 3))
    k = np.exp(-0.5 * (np.arange(-r, r + 1, dtype=np.float32) / s) ** 2)
    k /= k.sum()
    out = np.pad(a.astype(np.float32), r, mode="edge")
    out = sum(k[i] * out[:, i:i + a.shape[1]] for i in range(2 * r + 1))
    out = sum(k[i] * out[i:i + a.shape[0], :] for i in range(2 * r + 1))
    return out.astype(np.float32)


def shade(c: Canvas) -> Image.Image:
    """Luz difusa e especular pelo relevo, oclusão nas frestas, emissão; reduz SS vezes; borda e contorno."""
    h = gauss(c.height, 0.18)
    gy, gx = np.gradient(h, 1.0 / PPU)
    n = np.dstack([-gx * 0.9, -gy * 0.9, np.ones_like(h)])
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    diff = np.clip(n @ LIGHT, 0, 1)
    spec = np.clip(n @ HALF, 0, 1) ** 28
    sheen = np.clip(n @ HALF, 0, 1) ** 6
    ao = np.clip(1 - np.clip(gauss(c.height, 1.4) - c.height, 0, None) * 0.55, 0.45, 1)
    alb = c.albedo
    m = c.metal[..., None]
    rgb = alb * (0.34 + 0.86 * diff[..., None]) * ao[..., None]
    rgb = rgb + (spec[..., None] * (0.25 + 0.75 * m) * 0.8 + sheen[..., None] * m * 0.12) * np.array(
        [0.92, 0.97, 1.0], np.float32)
    rgb = np.clip(rgb + c.glow, 0, 1)
    a = c.alpha
    pre = np.dstack([rgb * a[..., None], a])
    side = c.n // SS
    chans = []
    for k in range(4):
        ch = Image.fromarray(pre[..., k].astype(np.float32), "F").resize((side, side), Image.Resampling.BOX)
        chans.append(np.asarray(ch, np.float32))
    a = chans[3]
    rgb = np.dstack(chans[:3]) / np.maximum(a, 1e-4)[..., None]
    # Luz de borda vinda da luz (de baixo à direita na textura) e contorno escuro fino, como em gen_hd_ships.finish.
    sh = np.zeros_like(a)
    sh[:-1, :-1] = a[1:, 1:]
    edge = np.clip(a - sh, 0, 1)
    edge = np.asarray(Image.fromarray((edge * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.6)),
                      np.float32) / 255 * a
    rgb = np.clip(rgb + edge[..., None] * np.array([0.55, 0.65, 0.75], np.float32) * 0.6, 0, 1)
    grown = np.asarray(Image.fromarray((a * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(3)), np.float32) / 255
    ring = np.clip(grown - a, 0, 1) * 0.8
    dark = np.array([0.02, 0.035, 0.06], np.float32)
    out_a = a + ring * (1 - a)
    col = (rgb * a[..., None] + dark * (ring * (1 - a))[..., None]) / np.maximum(out_a, 1e-4)[..., None]
    rgba = np.dstack([col, out_a])
    img = Image.fromarray((np.clip(rgba, 0, 1) * 255 + 0.5).astype(np.uint8), "RGBA")
    return img


# ---------------------------------------------------------------- submarino


SUB_LEN = 42.0
SUB_BEAM = 5.4  # meia boca


def submarine() -> tuple[Canvas, list]:
    c = Canvas(60.0)
    L = SUB_LEN
    t = (c.y + L / 2) / L  # 0 na proa, 1 na popa
    tc = np.clip(t, 0, 1)
    w = np.full_like(t, SUB_BEAM)
    bow = tc < 0.2
    w = np.where(bow, SUB_BEAM * np.sqrt(np.clip(1 - ((0.2 - tc) / 0.2) ** 2, 0, 1)), w)
    aft = tc > 0.6
    w = np.where(aft, SUB_BEAM * (1 - np.clip((tc - 0.6) / 0.4, 0, 1) ** 1.7 * 0.86), w)
    w = np.where((t < 0) | (t > 1), 0, w)
    hull = (np.abs(c.x) < w).astype(np.float32)
    u = np.clip(np.abs(c.x) / np.maximum(w, 1e-3), 0, 1)
    cyl = np.sqrt(np.clip(1 - u * u, 0, 1))
    tiles = ((np.abs(np.mod(c.x + 0.4, 1.6) - 0.8) < 0.07) | (np.abs(np.mod(c.y, 1.6) - 0.8) < 0.07)).astype(np.float32)
    grain = noise(c, 2.5, 11) * 0.015 + noise(c, 0.8, 12) * 0.01
    base = np.array([0.18, 0.205, 0.25], np.float32)
    alb = base[None, None, :] + grain[..., None] - tiles[..., None] * 0.025
    # Dorso claro (casco molhado refletindo o céu) e quilha mais escura nas bordas.
    alb = alb * (0.78 + 0.32 * cyl[..., None])
    # Popa: lemes em cruz (horizontais, atrás do casco, e o vertical no eixo) e a hélice.
    fin_y = L / 2 - 4.2
    fin = box(c, 0, fin_y, 6.8, 0.95, 0.45)
    taper = np.clip(1 - (np.abs(c.x) - 3.0) / 5.0, 0.35, 1)
    fin_m = inside(fin - (1 - taper) * 0.9)
    c.paint(fin_m, (0.14, 0.16, 0.2), 1.1 + bevel(fin, 0.5) * 0.5, 0.35)
    c.decal(fin_m * (np.abs(c.x) > 5.3), CORAL)
    rud = box(c, 0, L / 2 - 2.0, 0.55, 4.4, 0.5)
    c.paint(hull, alb, 0.2 + cyl * 2.4, 0.45)
    c.paint(inside(rud), (0.13, 0.15, 0.19), 2.6 + bevel(rud, 0.3) * 0.6, 0.35)
    c.paint(inside(circle(c, 0, L / 2 + 0.6, 1.25)), (0.35, 0.32, 0.26), 0.9 + bevel(circle(c, 0, L / 2 + 0.6, 1.25),
                                                                                       0.8) * 0.7, 0.9)
    # Faixas coral do Protocolo (proa e popa) e a seta no dorso da proa.
    c.decal(((np.abs(c.y - (-L / 2 + 5.2)) < 0.55) | (np.abs(c.y - (-L / 2 + 6.9)) < 0.28)).astype(np.float32), CORAL)
    c.decal((np.abs(c.y - (L / 2 - 9.5)) < 0.5).astype(np.float32), CORAL)
    tip = -L / 2 + 1.5
    chev = (np.abs(np.abs(c.x) - (c.y - tip) * 0.55) < 0.32) & (c.y > tip) & (c.y < tip + 3.0)
    c.decal(chev.astype(np.float32), CORAL_HI, 0.9)
    # Escotilhas dos mísseis: duas fileiras de cinco, tampas de metal claro com aro coral.
    for row in range(5):
        for side in (-1, 1):
            cx, cy = side * 1.95, 0.4 + row * 2.45
            d = circle(c, cx, cy, 1.0)
            rim = inside(d) - inside(d + 0.3)
            c.paint(inside(d), (0.27, 0.3, 0.35), 2.45 + bevel(d, 0.45) * 0.25, 0.7)
            c.decal(rim, CORAL)
            c.paint(inside(d + 0.72), (0.4, 0.43, 0.47), 2.75, 0.85)
    # Vela (torre): gota alongada, mais alta, frente redonda e traseira afilada.
    sy = -8.2
    sail = box(c, 0, sy, 2.1, 4.9, 2.0)
    sail = np.maximum(sail, np.abs(c.x) - 2.1 * np.clip(1 - (c.y - (sy + 1.5)) / 7.0, 0.35, 1))
    c.paint(inside(sail), (0.17, 0.195, 0.235), 3.0 + bevel(sail, 0.9) * 1.7, 0.5)
    planes = box(c, 0, sy - 1.7, 5.4, 0.65, 0.5)
    planes_m = inside(planes) * (np.abs(c.x) > 1.6)
    c.paint(planes_m, (0.15, 0.17, 0.21), 3.6 + bevel(planes, 0.35) * 0.4, 0.4)
    c.decal(planes_m * (np.abs(c.x) > 4.3), CORAL)
    c.paint(inside(box(c, 0, sy - 0.6, 1.1, 1.7, 0.7)), (0.07, 0.08, 0.1), 4.4, 0.2)
    for py, pr in ((sy + 0.6, 0.45), (sy + 1.9, 0.38), (sy + 3.0, 0.32)):
        d = circle(c, 0, py, pr)
        c.paint(inside(d), (0.5, 0.53, 0.57), 5.2 + bevel(d, pr) * 0.5, 0.95)
    c.emit(inside(circle(c, 0, sy - 3.4, 0.42)), CORAL_HI, 0.85)
    c.emit(inside(circle(c, 0, sy + 1.9, 0.18)), (0.6, 1.0, 1.0), 0.8)
    # Espuma da hélice: um bocal no centro da popa.
    return c, [(0.0, L / 2 + 1.4, 7.0)]


# ---------------------------------------------------------------- navio de guerra


WAR_LEN = 60.0
WAR_BEAM = 7.4


def warship() -> tuple[Canvas, list]:
    c = Canvas(74.0)
    L = WAR_LEN
    t = (c.y + L / 2) / L
    tc = np.clip(t, 0, 1)
    w = WAR_BEAM * np.clip(tc / 0.36, 0, 1) ** 0.58
    w = w * (1 - 0.13 * np.clip((tc - 0.62) / 0.38, 0, 1))
    w = np.where((t < 0) | (t > 1), 0, w)
    hull_d = np.abs(c.x) - w
    hull = inside(hull_d)
    grain = noise(c, 3.0, 21) * 0.02 + noise(c, 0.7, 22) * 0.012
    deck_col = np.array([0.33, 0.37, 0.42], np.float32)
    plank = (np.abs(np.mod(c.y, 2.2) - 1.1) < 0.05).astype(np.float32)
    alb = deck_col[None, None, :] + grain[..., None] - plank[..., None] * 0.03
    gun = bevel(hull_d, 0.9)
    fore = (c.y < -L / 2 + 0.42 * L).astype(np.float32)
    c.paint(hull, alb * (0.7 + 0.3 * gun[..., None]), 1.4 + gun * 0.6 + fore * 0.35, 0.3)
    # Borda do convés (amurada) e o passadiço escuro dos dois lados.
    c.decal(inside(hull_d) - inside(hull_d + 0.45), (0.2, 0.22, 0.26))
    c.decal((inside(hull_d + 0.9) - inside(hull_d + 1.35)) * (t > 0.2), (0.25, 0.28, 0.32), 0.8)
    c.decal((np.abs(c.y - (-L / 2 + 0.42 * L)) < 0.14).astype(np.float32) * hull, (0.18, 0.2, 0.24))
    # Proa: faixas coral do Protocolo e a âncora (ponto escuro de cada lado).
    for yy, ww in ((-L / 2 + 6.0, 0.5), (-L / 2 + 7.6, 0.25)):
        c.decal((np.abs(c.y - yy) < ww).astype(np.float32), CORAL)
    for s in (-1, 1):
        c.paint(inside(circle(c, s * 2.0, -L / 2 + 9.5, 0.45)), (0.08, 0.09, 0.1), 1.6, 0.2)
    # Canhão de proa: torre de frente redonda e o cano para a proa.
    ty = -L / 2 + 16.0
    tur = np.minimum(box(c, 0, ty + 0.8, 2.6, 2.4, 0.8), circle(c, 0, ty - 0.6, 2.6))
    c.paint(inside(tur), (0.46, 0.5, 0.55), 2.6 + bevel(tur, 1.1) * 1.4, 0.65)
    bar = box(c, 0, ty - 5.6, 0.36, 3.6, 0.3)
    c.paint(inside(bar), (0.55, 0.58, 0.62), 3.6 + bevel(bar, 0.36) * 0.3, 0.95)
    c.paint(inside(circle(c, 0, ty - 9.1, 0.3)), (0.05, 0.05, 0.06), 3.7, 0.2)
    c.decal(inside(box(c, 0, ty + 2.2, 1.6, 0.35, 0.2)), CORAL)
    # Células de lançamento vertical (VLS): 2 x 4 tampas, algumas com o aro coral aceso.
    vy = -L / 2 + 22.4
    vls = box(c, 0, vy, 3.4, 2.5, 0.4)
    c.paint(inside(vls), (0.25, 0.28, 0.32), 1.95 + bevel(vls, 0.4) * 0.15, 0.4)
    for i in range(4):
        for j in range(2):
            cell = box(c, -2.4 + i * 1.6, vy - 1.2 + j * 2.4 - 0.0, 0.62, 0.92, 0.15)
            c.paint(inside(cell), (0.36, 0.39, 0.43), 2.1 + bevel(cell, 0.25) * 0.12, 0.75)
            if (i + j) % 2 == 0:
                c.decal(inside(cell) - inside(cell + 0.2), CORAL)
    # Ponte e superestrutura: bloco de faces inclinadas (furtivo), vidros acesos na frente.
    by = -L / 2 + 31.0
    sup = box(c, 0, by, 5.2, 5.6, 1.4)
    sup = np.maximum(sup, np.abs(c.x) - (5.2 - np.clip(-(c.y - (by - 2.0)) * 0.55, 0, 2.6)))
    c.paint(inside(sup), (0.5, 0.54, 0.58), 2.4 + bevel(sup, 1.5) * 2.8, 0.55)
    win = (np.abs(c.y - (by - 4.3)) < 0.32) & (np.abs(c.x) < 2.6)
    c.paint(win.astype(np.float32), (0.05, 0.12, 0.16), 4.6, 0.9)
    c.emit(win.astype(np.float32), (0.35, 0.95, 1.0), 0.7)
    deck2 = box(c, 0, by + 0.8, 3.2, 3.0, 0.8)
    c.paint(inside(deck2), (0.43, 0.47, 0.51), 5.2 + bevel(deck2, 0.8) * 0.8, 0.5)
    # Mastro: viga, verga em cruz, radar (disco) e a luz coral no topo.
    yard = box(c, 0, by + 0.6, 4.0, 0.25, 0.2)
    c.paint(inside(yard), (0.62, 0.65, 0.68), 6.9, 0.9)
    dish = circle(c, 0, by + 0.6, 1.9)
    c.paint(inside(dish), (0.58, 0.62, 0.66), 7.2 + bevel(dish, 1.6) * 0.9, 0.85)
    c.paint(inside(box(c, 0, by + 0.6, 1.7, 0.42, 0.3)), (0.2, 0.22, 0.25), 8.3, 0.4)
    c.emit(inside(circle(c, 0, by + 0.6, 0.35)), CORAL_HI, 1.0)
    for s in (-1, 1):
        c.emit(inside(circle(c, s * 4.0, by + 0.6, 0.3)), (0.45, 1.0, 1.0) if s > 0 else CORAL_HI, 0.9)
    # Botes salva-vidas nos flancos.
    for s in (-1, 1):
        for k in range(2):
            boat = box(c, s * 6.0, by - 1.6 + k * 3.6, 0.65, 1.35, 0.6)
            c.paint(inside(boat), (0.72, 0.72, 0.7), 2.2 + bevel(boat, 0.5) * 0.4, 0.2)
    # Chaminé: ovalada, alta, com a grade escura e fuligem.
    fy = by + 8.3
    fun = box(c, 0, fy, 2.2, 2.8, 1.7)
    c.paint(inside(fun), (0.4, 0.43, 0.47), 2.6 + bevel(fun, 1.0) * 3.6, 0.55)
    for s in (-1, 1):
        hole = box(c, s * 0.85, fy, 0.55, 1.6, 0.5)
        c.paint(inside(hole), (0.04, 0.04, 0.05), 5.4, 0.1)
    c.decal(inside(fun) - inside(fun + 0.35), CORAL)
    # Lançador de mísseis giratório: base redonda, caixa com 2 x 2 tubos e as ogivas coral.
    ly = by + 14.6
    ring = circle(c, 0, ly, 3.0)
    c.paint(inside(ring), (0.3, 0.33, 0.37), 2.1 + bevel(ring, 0.6) * 0.3, 0.6)
    lb = box(c, 0, ly, 2.7, 2.3, 0.5)
    c.paint(inside(lb), (0.42, 0.46, 0.5), 2.6 + bevel(lb, 0.7) * 1.3, 0.7)
    for i in (-1, 1):
        for j in (-1, 1):
            tube = circle(c, i * 1.22, ly + j * 1.05, 0.78)
            c.paint(inside(tube), (0.12, 0.13, 0.15), 3.6, 0.3)
            war = circle(c, i * 1.22, ly + j * 1.05, 0.56)
            c.paint(inside(war), CORAL, 3.7 + bevel(war, 0.56) * 0.5, 0.5)
            c.emit(inside(circle(c, i * 1.22 - 0.15, ly + j * 1.05 - 0.15, 0.2)), CORAL_HI, 0.6)
    # Defesa de ponto (domo branco) e o heliponto na popa com o círculo e o "H" e a faixa coral do Protocolo.
    cy = ly + 4.8
    dome = circle(c, 0, cy, 1.35)
    c.paint(inside(dome), (0.78, 0.8, 0.82), 2.2 + bevel(dome, 1.35) * 1.4, 0.4)
    c.paint(inside(box(c, 0, cy - 1.6, 0.18, 0.9, 0.1)), (0.6, 0.63, 0.66), 3.0, 0.9)
    hy = L / 2 - 5.2
    pad = box(c, 0, hy, w.max() - 1.6, 4.4, 0.6)
    c.decal(inside(pad) * hull, (0.24, 0.27, 0.3))
    rr = np.abs(np.hypot(c.x, c.y - hy) - 3.0)
    c.decal((rr < 0.28).astype(np.float32), (0.82, 0.84, 0.82), 0.85)
    hmark = (inside(box(c, -0.9, hy, 0.22, 1.2)) + inside(box(c, 0.9, hy, 0.22, 1.2)) + inside(box(c, 0, hy, 0.9, 0.2)))
    c.decal(np.clip(hmark, 0, 1), (0.85, 0.87, 0.85), 0.9)
    for k in range(-4, 5):
        stripe = (np.abs(c.y - (L / 2 - 0.55)) < 0.4) & (np.abs(c.x - k * 1.4) < 0.42)
        c.decal(stripe.astype(np.float32), CORAL if k % 2 == 0 else (0.85, 0.85, 0.8))
    # Duas hélices: a espuma sai dos dois lados da popa.
    return c, [(-3.0, L / 2 + 0.6, 5.6), (3.0, L / 2 + 0.6, 5.6)]


# ---------------------------------------------------------------- espuma da hélice


def wash_strip(side_px: int, props: list, seed: int) -> Image.Image:
    """FRAMES quadros da espuma da hélice: borbulhar branco que se abre para trás da popa, em laço sem emenda."""
    n = side_px
    yy, xx = np.mgrid[0:n, 0:n].astype(np.float32)
    xu = (xx + 0.5) / TPU - n / TPU / 2
    yu = (yy + 0.5) / TPU - n / TPU / 2
    rng = np.random.default_rng(seed)
    fields = []
    for k in range(4):
        small = Image.fromarray((rng.random((n // 3 + 2, n // 3 + 2)) * 255).astype(np.uint8), "L")
        fields.append(np.asarray(small.resize((n, n), Image.Resampling.BICUBIC), np.float32) / 255.0)
    strip = Image.new("RGBA", (n * FRAMES, n))
    for f in range(FRAMES):
        ph = math.tau * f / FRAMES
        churn = (fields[0] * math.cos(ph) + fields[1] * math.sin(ph)) * 0.5 + 0.5
        fine = (fields[2] * math.cos(ph * 2) + fields[3] * math.sin(ph * 2)) * 0.5 + 0.5
        a = np.zeros((n, n), np.float32)
        for px, py, length in props:
            v = (yu - py + 1.2) / length
            spread = 0.9 + v * 1.6
            u = np.abs(xu - px) / np.maximum(spread, 1e-3)
            body = np.where((v >= 0) & (v <= 1), np.clip(1 - u * u, 0, 1) * np.clip(1 - v, 0, 1) ** 0.8, 0)
            a = np.maximum(a, body)
        foam = a * (0.45 + 0.75 * churn) * (0.6 + 0.6 * fine)
        alpha = np.clip(foam * 1.15, 0, 0.92)
        col = np.broadcast_to(np.array(FOAM, np.float32), (n, n, 3))
        rgba = np.dstack([col, alpha])
        strip.paste(Image.fromarray((rgba * 255 + 0.5).astype(np.uint8), "RGBA"), (f * n, 0))
    return strip


# ---------------------------------------------------------------- saída


FOAM_SIDE = 32
FOAM_FRAMES = 4


def foam_strip(seed: int = 51) -> Image.Image:
    """Flocos de espuma: mancha irregular (ruído suave) com grão (pontos soltos e bolhas), borda que se desfaz."""
    n = FOAM_SIDE
    yy, xx = np.mgrid[0:n, 0:n].astype(np.float32)
    r = np.hypot(xx + 0.5 - n / 2, yy + 0.5 - n / 2) / (n / 2)
    strip = Image.new("RGBA", (n * FOAM_FRAMES, n))
    for f in range(FOAM_FRAMES):
        rng = np.random.default_rng(seed + f)
        small = Image.fromarray((rng.random((6, 6)) * 255).astype(np.uint8), "L")
        blob = np.asarray(small.resize((n, n), Image.Resampling.BICUBIC), np.float32) / 255.0
        speck = rng.random((n, n)).astype(np.float32)
        body = np.clip(1 - r, 0, 1) ** 0.7 * np.clip(blob * 1.6 - 0.2, 0, 1)
        grain = np.where(speck > 0.62, 1.0, 0.35 + 0.4 * speck)
        alpha = np.clip(body * grain * 1.5, 0, 1)
        alpha = np.asarray(Image.fromarray((alpha * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.45)),
                           np.float32) / 255.0
        col = np.broadcast_to(np.array((0.93, 0.98, 1.0), np.float32), (n, n, 3))
        strip.paste(Image.fromarray((np.dstack([col, alpha]) * 255 + 0.5).astype(np.uint8), "RGBA"), (f * n, 0))
    return strip


def mipmaps_on(path: pathlib.Path) -> None:
    imp = path.with_name(path.name + ".import")
    if imp.exists():
        text = imp.read_text(encoding="utf-8")
        if "mipmaps/generate=false" in text:
            imp.write_text(text.replace("mipmaps/generate=false", "mipmaps/generate=true"), encoding="utf-8",
                           newline="\n")


def build() -> dict:
    out = {}
    for name, make, seed in (("submarine", submarine, 31), ("warship", warship, 41)):
        canvas, props = make()
        base = shade(canvas)
        out[name] = {"base": base, "engine": wash_strip(base.height, props, seed)}
    return out


def preview(built: dict, folder: pathlib.Path) -> None:
    """Folha sobre a cor do mar: 1x e 4x, girada como no jogo, com a espuma do quadro 0."""
    folder.mkdir(parents=True, exist_ok=True)
    cells = []
    for e in built.values():
        n = e["base"].height
        im = Image.new("RGBA", (n, n), (10, 42, 58, 255))
        im.alpha_composite(e["engine"].crop((0, 0, n, n)))
        im.alpha_composite(e["base"])
        im = im.rotate(180)
        cells.append(im)
    w = sum(c.width for c in cells)
    h = max(c.height for c in cells)
    sheet = Image.new("RGBA", (w, h), (10, 42, 58, 255))
    x = 0
    for cimg in cells:
        sheet.alpha_composite(cimg, (x, 0))
        x += cimg.width
    sheet.resize((w // TPU, h // TPU), Image.Resampling.LANCZOS).save(folder / "sea_ships_1x.png")
    sheet.resize((w * 2, h * 2), Image.Resampling.LANCZOS).save(folder / "sea_ships_4x.png")


def main() -> int:
    built = build()
    index = json.loads(INDEX.read_text(encoding="utf-8")) if INDEX.exists() else []
    index = [r for r in index if r.get("source") != SOURCE]
    rows = []
    for name, e in built.items():
        for label in ("base", "engine"):
            target = OUT / f"{name}_{label}.png"
            target.parent.mkdir(parents=True, exist_ok=True)
            e[label].save(target, optimize=True)
            mipmaps_on(target)
            rows.append({"file": target.relative_to(ROOT).as_posix(), "source": SOURCE, "license_id": LICENSE_ID,
                         "sha256": hashlib.sha256(target.read_bytes()).hexdigest()})
        print(f"sea_{name:10s} {e['base'].height}px")
    target = OUT / "foam.png"
    foam_strip().save(target, optimize=True)
    mipmaps_on(target)
    rows.append({"file": target.relative_to(ROOT).as_posix(), "source": SOURCE, "license_id": LICENSE_ID,
                 "sha256": hashlib.sha256(target.read_bytes()).hexdigest()})
    index = sorted(index + rows, key=lambda item: item["file"])
    INDEX.write_text(json.dumps(index, indent=1, ensure_ascii=False) + "\n", encoding="utf-8", newline="\n")
    if "--preview" in sys.argv:
        preview(built, pathlib.Path(sys.argv[sys.argv.index("--preview") + 1]))
    return 0


if __name__ == "__main__":
    sys.exit(main())
