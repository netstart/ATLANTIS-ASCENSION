"""Gera a arte própria dos poderes das naves (MIT): projéteis, efeitos e os 36 ícones de poder.

Projéteis e efeitos dos poderes (pena do Falcão, torpedo da Hydra, onda do Trident, redemoinho,
corona do Eclipse, mira da Nova, muralha do Atlas, raio da Tempest, drone do Swarm, lança da
Ascension, morteiro do Ram, aviso de artilharia, rastro de investida, escudo frontal, supernova e
disco do eclipse) e um ícone 24x24 para cada poder (12 naves x 3 níveis).

Regras de arte:
- Ícones em pixel art nítida: placa escura com contorno de 1 px, símbolo na cor da nave
  (campo "tint" de data/ships.json) com contorno escuro e luz de cima; o nível 3 (supremo) ganha
  borda e brilho dourados para ser lido de relance.
- Efeitos com cor clara e intensidade no alfa (bons para mistura aditiva); a cor dos pixels
  transparentes é estendida a partir da borda, para o filtro linear não criar halo escuro.
- Determinístico: toda variação vem de geradores com semente fixa.

Reaproveita as constantes e primitivas de tools/gen_sprites.py (importar não tem efeito colateral).
Grava em assets/art/generated/powers/ e registra cada arquivo em assets/asset_index.json (licença
"atlantis_generated", origem tools/gen_power_sprites.py), que o tools/sync_assets.py preserva.
Com --preview DIR grava também DIR/preview_sheet.png (tudo a 3x, rotulado, em fundo escuro) para
revisão visual; a folha nunca vai para assets/.
Só usa numpy (o PNG é escrito aqui, como no gen_sprites.py).
Uso (sem -I: o numpy fica no site do usuário): python tools/gen_power_sprites.py [--preview DIR]
"""
import argparse
import hashlib
import json
import math
import pathlib
import struct
import sys
import zlib

import numpy as np

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import gen_sprites as gs  # noqa: E402

ROOT = gs.ROOT
OUT = gs.OUT / "powers"
LICENSE_ID = gs.LICENSE_ID
SOURCE = "tools/gen_power_sprites.py"

OUTLINE = np.array(gs.OUTLINE[:3]) / 255.0
WHITE = np.array(gs.WHITE[:3]) / 255.0
GOLD = np.array(gs.PALETTE["gold"][0]) / 255.0
GOLD_DARK = np.array(gs.GOLD_DARK[:3]) / 255.0
NAVY = np.array((14, 20, 36)) / 255.0

SHIP_ORDER = ("falcon", "manta", "hydra", "tempest", "trident", "atlas",
              "ram", "swarm", "eclipse", "nova", "titan", "ascension")
# Reserva caso data/ships.json não esteja ao alcance (mesmos valores do arquivo).
TINT_FALLBACK = {
    "falcon": "#ffffff", "manta": "#9fe8ff", "hydra": "#c7a0ff", "tempest": "#ffb08a",
    "trident": "#8affc8", "atlas": "#ffe08a", "ram": "#ff8a6a", "swarm": "#b8ff6a",
    "eclipse": "#a58aff", "nova": "#fff38a", "titan": "#ff6ad0", "ascension": "#8afff0",
}


def rgb(hex_or_tuple) -> np.ndarray:
    if isinstance(hex_or_tuple, str):
        h = hex_or_tuple.lstrip("#")
        return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)]) / 255.0
    return np.array(hex_or_tuple[:3], dtype=float) / 255.0


def load_tints() -> dict:
    tints = {k: rgb(v) for k, v in TINT_FALLBACK.items()}
    path = ROOT / "data" / "ships.json"
    if path.exists():
        for ship in json.loads(path.read_text(encoding="utf-8")):
            if ship.get("id") in tints and "tint" in ship:
                tints[ship["id"]] = rgb(ship["tint"])
    return tints


# ---------------------------------------------------------------- imagem RGBA (float, alfa reto)

def blank(w: int, h: int) -> np.ndarray:
    return np.zeros((h, w, 4))


def from_list(px: list, w: int, h: int) -> np.ndarray:
    """Converte uma primitiva do gen_sprites (lista de tuplas RGBA) em matriz float."""
    return np.array(px, dtype=float).reshape(h, w, 4) / 255.0


def paint(color, alpha: np.ndarray) -> np.ndarray:
    """Camada de cor única (ou campo de cor HxWx3) com o alfa dado."""
    h, w = alpha.shape
    out = np.zeros((h, w, 4))
    out[..., :3] = color
    out[..., 3] = np.clip(alpha, 0.0, 1.0)
    return out


def over(dst: np.ndarray, src: np.ndarray) -> np.ndarray:
    """Composição "sobre" com alfa reto (sem escurecer a borda)."""
    sa = src[..., 3:4]
    da = dst[..., 3:4]
    oa = sa + da * (1.0 - sa)
    rgb_ = np.where(oa > 1e-6, (src[..., :3] * sa + dst[..., :3] * da * (1.0 - sa)) / np.maximum(oa, 1e-6), 0.0)
    return np.concatenate([rgb_, oa], axis=-1)


def bleed(img: np.ndarray, steps: int = 6) -> np.ndarray:
    """Estende a cor da borda para os pixels transparentes (filtro linear sem halo escuro)."""
    out = img.copy()
    known = out[..., 3] > 0.0
    if not known.any():
        return out
    col = out[..., :3] * known[..., None]
    for _ in range(steps):
        if known.all():
            break
        acc = np.zeros_like(col)
        cnt = np.zeros(known.shape)
        for dy in (-1, 0, 1):
            for dx in (-1, 0, 1):
                if dx == 0 and dy == 0:
                    continue
                acc += np.roll(np.roll(col * known[..., None], dy, 0), dx, 1)
                cnt += np.roll(np.roll(known.astype(float), dy, 0), dx, 1)
        grow = (~known) & (cnt > 0)
        col[grow] = acc[grow] / cnt[grow][:, None]
        known = known | grow
    if not known.all():
        col[~known] = col[known].mean(axis=0)
    out[..., :3] = col
    return out


def to_u8(img: np.ndarray) -> np.ndarray:
    return np.clip(np.round(img * 255.0), 0, 255).astype(np.uint8)


def png_bytes(arr: np.ndarray) -> bytes:
    h, w = arr.shape[:2]
    raw = np.concatenate([np.zeros((h, 1), np.uint8), arr.reshape(h, w * 4)], axis=1).tobytes()

    def chunk(kind: bytes, data: bytes) -> bytes:
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)

    header = struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0)
    return b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", header) + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")


# ---------------------------------------------------------------- campos e utilidades

def grid(w: int, h: int, ss: int = 1):
    """Coordenadas dos centros dos (sub)pixels, em unidades de pixel."""
    xs = (np.arange(w * ss) + 0.5) / ss
    ys = (np.arange(h * ss) + 0.5) / ss
    return np.meshgrid(xs, ys)


def pool(a: np.ndarray, ss: int) -> np.ndarray:
    if ss == 1:
        return a
    h, w = a.shape[0] // ss, a.shape[1] // ss
    return a.reshape(h, ss, w, ss, *a.shape[2:]).mean(axis=(1, 3))


def smoothstep(e0: float, e1: float, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def ramp(t: np.ndarray, stops: list) -> np.ndarray:
    """Mapa de cor por intensidade: stops = [(t, (r,g,b)), ...] em ordem crescente."""
    t = np.clip(t, 0.0, 1.0)
    out = np.zeros((*t.shape, 3))
    for (t0, c0), (t1, c1) in zip(stops, stops[1:]):
        m = (t >= t0) & (t <= t1)
        k = ((t - t0) / max(t1 - t0, 1e-6))[..., None]
        out[m] = (np.array(c0) / 255.0 * (1 - k) + np.array(c1) / 255.0 * k)[m]
    return out


def seg_dist(X, Y, x0, y0, x1, y1):
    dx, dy = x1 - x0, y1 - y0
    L = dx * dx + dy * dy
    t = np.clip(((X - x0) * dx + (Y - y0) * dy) / max(L, 1e-9), 0.0, 1.0)
    return np.hypot(X - (x0 + t * dx), Y - (y0 + t * dy))


def polyline_dist(X, Y, pts):
    d = np.full(X.shape, 1e9)
    for (a, b) in zip(pts, pts[1:]):
        d = np.minimum(d, seg_dist(X, Y, *a, *b))
    return d


def inside_poly(X, Y, pts):
    inside = np.zeros(X.shape, bool)
    n = len(pts)
    for i in range(n):
        x0, y0 = pts[i]
        x1, y1 = pts[(i + 1) % n]
        cond = (y0 > Y) != (y1 > Y)
        xi = x0 + (Y - y0) * (x1 - x0) / ((y1 - y0) if y1 != y0 else 1e-9)
        inside ^= cond & (X < xi)
    return inside


def periodic_noise(w: int, h: int, cell_x: int, cell_y: int, seed: int) -> np.ndarray:
    """Ruído de valor suave, periódico na horizontal (w múltiplo de cell_x)."""
    rng = np.random.default_rng(seed)
    gx, gy = w // cell_x, h // cell_y + 2
    g = rng.random((gy, gx))
    X, Y = grid(w, h)
    fx, fy = X / cell_x, Y / cell_y
    ix, iy = np.floor(fx).astype(int), np.floor(fy).astype(int)
    tx, ty = smoothstep(0, 1, fx - ix), smoothstep(0, 1, fy - iy)
    x0, x1 = ix % gx, (ix + 1) % gx
    y0, y1 = np.clip(iy, 0, gy - 1), np.clip(iy + 1, 0, gy - 1)
    a = g[y0, x0] * (1 - tx) + g[y0, x1] * tx
    b = g[y1, x0] * (1 - tx) + g[y1, x1] * tx
    return a * (1 - ty) + b * ty


def angular_noise(theta: np.ndarray, harmonics: tuple, seed: int) -> np.ndarray:
    """Soma de senoides com frequências inteiras: contínua ao dar a volta no círculo. Faixa 0..1."""
    rng = np.random.default_rng(seed)
    acc = np.zeros(theta.shape)
    total = 0.0
    for k in harmonics:
        amp = 1.0 / math.sqrt(k)
        acc += amp * np.sin(k * theta + rng.random() * math.tau)
        total += amp
    return 0.5 + 0.5 * acc / total


def shift(m: np.ndarray, dy: int, dx: int) -> np.ndarray:
    """Desloca uma máscara sem dar a volta na borda."""
    out = np.zeros_like(m)
    h, w = m.shape
    ys, yd = (slice(0, h - dy), slice(dy, h)) if dy >= 0 else (slice(-dy, h), slice(0, h + dy))
    xs, xd = (slice(0, w - dx), slice(dx, w)) if dx >= 0 else (slice(-dx, w), slice(0, w + dx))
    out[yd, xd] = m[ys, xs]
    return out


def dilate(m: np.ndarray, diag: bool = True) -> np.ndarray:
    out = m.copy()
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            if (dx or dy) and (diag or dx == 0 or dy == 0):
                out |= shift(m, dy, dx)
    return out


def mix(a, b, t: float) -> np.ndarray:
    return np.asarray(a) * (1.0 - t) + np.asarray(b) * t


# ---------------------------------------------------------------- pixel art com máscaras

class Pix:
    """Desenho vetorial rasterizado com cobertura (4x4 subamostras) e corte em 50%: bordas limpas."""

    def __init__(self, w: int, h: int, ss: int = 4):
        self.w, self.h, self.ss = w, h, ss
        self.X, self.Y = grid(w, h, ss)

    def _m(self, fine: np.ndarray, cut: float = 0.5) -> np.ndarray:
        return pool(fine.astype(float), self.ss) >= cut

    def disc(self, cx, cy, r):
        return self._m(np.hypot(self.X - cx, self.Y - cy) <= r)

    def ellipse(self, cx, cy, rx, ry):
        return self._m(((self.X - cx) / rx) ** 2 + ((self.Y - cy) / ry) ** 2 <= 1.0)

    def ring(self, cx, cy, r, w):
        return self._m(np.abs(np.hypot(self.X - cx, self.Y - cy) - r) <= w / 2.0)

    def arc(self, cx, cy, r, w, a0, a1):
        """Arco de anel entre os ângulos a0..a1 em graus (0 = direita, -90 = cima)."""
        ang = np.degrees(np.arctan2(self.Y - cy, self.X - cx))
        lo, hi = a0, a1
        ang = np.where(ang < lo, ang + 360.0, ang)
        sel = (ang >= lo) & (ang <= hi)
        return self._m((np.abs(np.hypot(self.X - cx, self.Y - cy) - r) <= w / 2.0) & sel)

    def seg(self, x0, y0, x1, y1, w):
        return self._m(seg_dist(self.X, self.Y, x0, y0, x1, y1) <= w / 2.0)

    def line(self, pts, w):
        return self._m(polyline_dist(self.X, self.Y, pts) <= w / 2.0)

    def poly(self, pts):
        return self._m(inside_poly(self.X, self.Y, pts))

    def rect(self, x0, y0, x1, y1):
        return self._m((self.X >= x0) & (self.X <= x1) & (self.Y >= y0) & (self.Y <= y1))

    def star(self, cx, cy, ro, ri, n, rot=-90.0):
        pts = []
        for i in range(n * 2):
            a = math.radians(rot + i * 180.0 / n)
            r = ro if i % 2 == 0 else ri
            pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
        return self.poly(pts)

    def hexagon(self, cx, cy, r):
        return self.poly([(cx + r * math.cos(math.radians(30 + 60 * i)),
                           cy + r * math.sin(math.radians(30 + 60 * i))) for i in range(6)])

    def leaf(self, x0, y0, x1, y1, w):
        """Pena/lâmina: largura máxima w no terço de trás, pontas finas."""
        dx, dy = x1 - x0, y1 - y0
        L = math.hypot(dx, dy)
        ux, uy = dx / L, dy / L
        t = ((self.X - x0) * ux + (self.Y - y0) * uy) / L
        s = np.abs((self.X - x0) * -uy + (self.Y - y0) * ux)
        prof = np.clip(np.where(t < 0.35, t / 0.35, (1 - t) / 0.65), 0.0, 1.0) ** 0.7 * (w / 2.0)
        return self._m((t >= 0) & (t <= 1) & (s <= prof))


def render_layers(w: int, h: int, layers: list, outline_alpha: float = 1.0, base: np.ndarray = None) -> np.ndarray:
    """layers = [(máscara, cor rgb 0..1, sombrear?)]. Contorno escuro de 1 px em volta de tudo."""
    img = blank(w, h) if base is None else base.copy()
    union = np.zeros((h, w), bool)
    for m, _, _ in layers:
        union |= m
    ring_ = dilate(union) & ~union
    img = over(img, paint(OUTLINE, ring_ * outline_alpha))
    for m, col, shade in layers:
        col = np.asarray(col, dtype=float)
        lay = paint(col, m.astype(float))
        if shade:
            top = m & ~shift(m, 1, 0) & shift(m, -1, 0)
            bot = m & ~shift(m, -1, 0) & shift(m, 1, 0)
            lay[top, :3] = mix(col, WHITE, 0.55)
            lay[bot, :3] = col * 0.62
        img = over(img, lay)
    return img


# ---------------------------------------------------------------- projéteis e efeitos

def sprite_feather() -> np.ndarray:
    """Pena-lâmina do Falcão (8x16): branca com fio dourado, haste clara, farpas em diagonal."""
    p = Pix(8, 16)
    body = p.leaf(4.0, 15.6, 4.0, 0.3, 6.6)
    notch = p.seg(0.0, 9.5, 2.2, 8.6, 0.9) | p.seg(8.0, 11.5, 5.8, 10.6, 0.9)
    body &= ~notch
    edge = body & ~(shift(body, 0, 1) & shift(body, 0, -1) & shift(body, 1, 0))
    shaft = p.seg(4.0, 15.5, 4.0, 2.0, 1.0)
    img = blank(8, 16)
    X, Y = grid(8, 16)
    vane = ramp(Y / 16.0, [(0.0, (255, 252, 236)), (1.0, (255, 214, 120))])
    img = over(img, paint(vane, body.astype(float)))
    img = over(img, paint(GOLD, (edge & body).astype(float)))
    img = over(img, paint(WHITE, shaft & body))
    tip = body & (Y < 4.0)
    img = over(img, paint(WHITE, tip.astype(float)))
    glow = np.exp(-polyline_dist(X, Y, [(4, 1), (4, 15)]) ** 2 / 4.0) * 0.35
    halo = paint(GOLD, glow * ~body)
    return over(halo, img)


def sprite_torpedo() -> np.ndarray:
    """Torpedo violeta da Hydra (10x22): casco com contorno, nariz claro, aletas e chama embaixo."""
    p = Pix(10, 22)
    light, dark = rgb(gs.PALETTE["violet"][0]), rgb(gs.PALETTE["violet"][1])
    hull = p.ellipse(5.0, 8.5, 2.6, 8.2)
    fins = p.poly([(5.0, 11.0), (9.4, 17.4), (9.4, 18.6), (5.0, 16.2), (0.6, 18.6), (0.6, 17.4)])
    nose = hull & p.rect(0, 0, 10, 3.3)
    stripe = hull & p.rect(4.3, 3.0, 5.0, 14.0)
    band = hull & p.rect(0, 9.6, 10, 10.6)
    img = render_layers(10, 22, [(fins, dark, False), (hull, light, True), (band, dark, False),
                                  (stripe, WHITE, False), (nose, mix(light, WHITE, 0.7), False)])
    X, Y = grid(10, 22)
    flame = np.exp(-((X - 5.0) / 1.5) ** 2) * smoothstep(22.0, 17.0, Y) * smoothstep(16.0, 17.6, Y)
    col = ramp(smoothstep(21.5, 17.0, Y), [(0.0, (196, 120, 255)), (0.6, (240, 200, 255)), (1.0, (255, 255, 255))])
    return over(paint(col, flame), img)


def sprite_missile_mini() -> np.ndarray:
    """Mini míssil (6x12): corpo claro, ogiva violeta, chama laranja (cardume e sete cabeças)."""
    p = Pix(6, 12)
    body = p.ellipse(3.0, 4.6, 1.55, 4.5)
    fins = p.poly([(3.0, 6.0), (5.6, 9.2), (3.0, 8.4), (0.4, 9.2)])
    nose = body & p.rect(0, 0, 6, 2.2)
    img = render_layers(6, 12, [(fins, rgb((150, 110, 220)), False), (body, rgb((232, 226, 255)), True),
                                 (nose, rgb((196, 120, 255)), False)])
    X, Y = grid(6, 12)
    flame = np.exp(-((X - 3.0) / 1.0) ** 2) * smoothstep(12.0, 9.2, Y) * smoothstep(8.4, 9.4, Y)
    col = ramp(smoothstep(12.0, 9.0, Y), [(0.0, (255, 110, 40)), (1.0, (255, 240, 170))])
    return over(paint(col, flame), img)


def sprite_orb() -> np.ndarray:
    """Orbe dourado do Bastião (16x16): esfera de ouro com runa e halo suave."""
    X, Y = grid(16, 16)
    d = np.hypot(X - 8, Y - 8)
    halo = paint(GOLD, np.exp(-np.maximum(d - 5.0, 0) ** 2 / 2.2) * 0.6 * (d > 5.5))
    core = from_list(gs.orb(12, "gold"), 12, 12)
    img = halo.copy()
    sub = over(img[2:14, 2:14], core)
    img[2:14, 2:14] = sub
    p = Pix(16, 16)
    rune = p.seg(8, 5.4, 8, 10.6, 1.0) | p.seg(6.2, 6.6, 9.8, 6.6, 1.0)
    img = over(img, paint(rgb((196, 126, 24)), rune * 0.9))
    hi = p.disc(6.2, 5.8, 1.0)
    return over(img, paint(WHITE, hi.astype(float)))


def sprite_wave() -> np.ndarray:
    """Crista da onda do Trident (270x28), repetível na horizontal: espuma em cima, água que some embaixo."""
    w, h = 270, 28
    rng = np.random.default_rng(271)
    X, Y = grid(w, h)
    tau = math.tau
    ph = rng.random(4) * tau
    top = (7.0 + 2.2 * np.sin(tau * 3 * X / w + ph[0]) + 1.1 * np.sin(tau * 7 * X / w + ph[1])
           + 0.6 * np.sin(tau * 17 * X / w + ph[2]))
    n1 = periodic_noise(w, h, 6, 3, 11)
    n2 = periodic_noise(w, h, 15, 6, 12)
    depth = Y - top
    foam = smoothstep(-0.6, 0.4, depth) * smoothstep(5.5 + 2.0 * n2, 2.5, depth)
    foam *= np.where(depth > 2.0, smoothstep(0.35, 0.6, n1 + 0.25 * (1 - depth / 6)), 1.0)
    water_a = smoothstep(0.0, 1.0, depth) * (1.0 - smoothstep(0.0, h - top, depth)) ** 1.3 * 0.9
    water_col = ramp(np.clip(depth / 18.0, 0, 1),
                     [(0.0, (138, 255, 210)), (0.35, (40, 214, 200)), (1.0, (14, 120, 160))])
    ripple = smoothstep(0.62, 0.8, periodic_noise(w, h, 18, 2, 13)) * smoothstep(3.0, 6.0, depth) * 0.55
    img = paint(water_col, water_a)
    img = over(img, paint(rgb((200, 255, 240)), ripple * water_a))
    shadow = smoothstep(2.0, 4.0, depth) * smoothstep(7.5, 4.5, depth) * 0.45
    img = over(img, paint(rgb((10, 110, 130)), shadow * water_a))
    foam_col = ramp(np.clip(depth / 5.0, 0, 1), [(0.0, (255, 255, 255)), (1.0, (190, 255, 236))])
    img = over(img, paint(foam_col, foam))
    # Borrifos acima da crista (posição dá a volta: continua repetível).
    spray = np.zeros((h, w))
    for _ in range(70):
        sx = rng.random() * w
        lift = 1.0 + rng.random() * 5.0
        r = 0.5 + rng.random() * 0.7
        sy = 7.0 + 2.2 * math.sin(tau * 3 * sx / w + ph[0]) + 1.1 * math.sin(tau * 7 * sx / w + ph[1]) - lift
        for off in (-w, 0, w):
            spray = np.maximum(spray, (1 - lift / 7.0) * np.clip(1.6 - np.hypot(X - sx - off, Y - sy) / r, 0, 1))
    img = over(img, paint(WHITE, spray))
    return img


def sprite_vortex() -> np.ndarray:
    """Redemoinho do Trident (96x96): braços de espuma em espiral, olho escuro no centro (gira no jogo)."""
    ss, n = 2, 96
    X, Y = grid(n, n, ss)
    c = n / 2.0
    dx, dy = X - c, Y - c
    r = np.hypot(dx, dy) / c
    th = np.arctan2(dy, dx)
    wob = angular_noise(th * 1.0 + 3.0 * r, (2, 5, 9), 31)
    arms = 0.5 + 0.5 * np.cos(3 * th + 11.0 * r ** 0.8 + 1.2 * wob)
    env = smoothstep(1.0, 0.72, r) * smoothstep(0.1, 0.3, r)
    foam = smoothstep(0.62, 0.95, arms) * env
    fine = 0.5 + 0.5 * np.cos(7 * th + 24.0 * r ** 0.8)
    foam = np.clip(foam * (0.75 + 0.35 * fine), 0, 1)
    base_a = smoothstep(1.0, 0.55, r) * 0.55
    base_col = ramp(r, [(0.0, (4, 30, 60)), (0.3, (12, 90, 120)), (1.0, (30, 170, 170))])
    img = paint(base_col, base_a)
    eye = smoothstep(0.32, 0.08, r) * 0.85
    img = over(img, paint(rgb((4, 16, 36)), eye))
    foam_col = ramp(foam, [(0.0, (60, 220, 200)), (0.6, (150, 255, 220)), (1.0, (255, 255, 255))])
    img = over(img, paint(foam_col, foam))
    rim = np.exp(-((r - 0.18) / 0.03) ** 2) * 0.6
    img = over(img, paint(rgb((150, 255, 230)), rim))
    return pool(img, ss) if ss == 1 else _pool_rgba(img, ss)


def _pool_rgba(img: np.ndarray, ss: int) -> np.ndarray:
    """Reduz com média ponderada pelo alfa (sem escurecer a borda)."""
    a = img[..., 3:4]
    num = pool(img[..., :3] * a, ss)
    den = pool(a, ss)
    out = np.concatenate([np.where(den > 1e-6, num / np.maximum(den, 1e-6), 0.0), den], axis=-1)
    return out


def sprite_corona() -> np.ndarray:
    """Anel de plasma do Eclipse (72x72): borda interna branca, labaredas violeta para fora, centro vazio."""
    ss, n = 2, 72
    X, Y = grid(n, n, ss)
    c = n / 2.0
    r = np.hypot(X - c, Y - c) / c
    th = np.arctan2(Y - c, X - c)
    r0 = 0.6
    flame = angular_noise(th, (5, 8, 13, 21, 34), 41)
    reach = 0.12 + 0.3 * flame ** 1.3
    outer = np.clip(1.0 - (r - r0) / reach, 0, 1) ** 1.3 * (r >= r0)
    inner = np.exp(-((r - r0) / 0.07) ** 2) * (r < r0) * 0.8
    band = np.exp(-((r - r0 - 0.02) / 0.03) ** 2)
    streaks = angular_noise(th * 1.0, (23, 37, 51), 42)
    outer *= 0.7 + 0.3 * streaks
    inten = np.clip(np.maximum(outer, inner) + band * 0.9, 0, 1)
    inten *= smoothstep(0.98, 0.9, r)
    col = ramp(inten, [(0.0, (70, 20, 140)), (0.4, (150, 70, 240)), (0.75, (210, 150, 255)), (1.0, (255, 245, 255))])
    return _pool_rgba(paint(col, np.clip(inten * 1.3, 0, 1)), ss)


def sprite_reticle() -> np.ndarray:
    """Mira de crítico da Nova (32x32): anel, quatro cantos, marcas e ponto central amarelos."""
    p = Pix(32, 32)
    y_ = rgb((255, 243, 138))
    ring_ = p.ring(16, 16, 9.0, 1.0)
    gap = p.rect(14.5, 0, 17.5, 32) | p.rect(0, 14.5, 32, 17.5)
    ring_ &= ~gap
    br = np.zeros((32, 32), bool)
    for sx, sy in ((1, 1), (-1, 1), (1, -1), (-1, -1)):
        ox, oy = 16 + sx * 13.5, 16 + sy * 13.5
        br |= p.seg(ox, oy, ox - sx * 5, oy, 1.6) | p.seg(ox, oy, ox, oy - sy * 5, 1.6)
    ticks = (p.seg(16, 3.5, 16, 10.5, 1.0) | p.seg(16, 21.5, 16, 28.5, 1.0)
             | p.seg(3.5, 16, 10.5, 16, 1.0) | p.seg(21.5, 16, 28.5, 16, 1.0))
    dot = p.rect(15, 15, 17, 17)
    img = render_layers(32, 32, [(ring_, y_, False), (br, y_, False), (ticks, mix(y_, WHITE, 0.5), False),
                                  (dot, WHITE, False)], outline_alpha=0.75)
    return img


def sprite_barrier() -> np.ndarray:
    """Muralha de luz do Atlas (160x18), repetível na horizontal: bordas douradas e runas a cada 16 px."""
    w, h = 160, 18
    X, Y = grid(w, h)
    edge = np.exp(-((Y - 3.0) / 0.7) ** 2) + np.exp(-((Y - 15.0) / 0.7) ** 2)
    body = ((Y > 3.0) & (Y < 15.0)) * (0.36 + 0.22 * (np.abs(Y - 9.0) / 6.0) ** 2)
    glow = np.exp(-np.maximum(np.abs(Y - 9.0) - 6.0, 0) ** 2 / 2.5) * 0.5 * ((Y < 3) | (Y > 15))
    scan = 0.08 * (0.5 + 0.5 * np.cos(math.tau * X / 8.0))
    img = paint(GOLD, glow)
    img = over(img, paint(rgb((255, 224, 138)), np.clip(body + scan * body * 3, 0, 1)))
    img = over(img, paint(ramp(np.clip(edge, 0, 1), [(0.0, (255, 214, 92)), (1.0, (255, 252, 230))]),
                          np.clip(edge, 0, 1)))
    runes = [
        [".#.", "###", ".#.", ".#.", "#.#"],
        ["#.#", "###", "#.#", ".#.", ".#."],
        ["###", "#..", "###", "..#", "###"],
        [".#.", "#.#", "###", "#.#", ".#."],
        ["#..", "##.", "###", ".##", "..#"],
    ]
    mask = np.zeros((h, w))
    rng = np.random.default_rng(160)
    for i in range(w // 16):
        r_ = runes[int(rng.integers(len(runes)))]
        ox, oy = i * 16 + 6, 6
        for yy, row in enumerate(r_):
            for xx, ch in enumerate(row):
                if ch == "#":
                    mask[oy + yy * 1 + (1 if yy > 1 else 0), ox + xx * 1 + (1 if xx > 0 else 0)] = 1.0
        # Pontos de ligação entre runas (linha de circuito).
        mask[9, i * 16 + 1] = 0.6
        mask[9, i * 16 + 2] = 0.6
        mask[9, i * 16 + 13] = 0.6
        mask[9, i * 16 + 14] = 0.6
    img = over(img, paint(rgb((255, 250, 225)), mask * 0.95))
    return img


def sprite_bolt() -> np.ndarray:
    """Segmento de raio da Tempest (10x32), repetível na vertical: núcleo branco e brilho laranja."""
    w, h = 10, 32
    ss = 2
    X, Y = grid(w, h, ss)
    pts = [(5.0, 0.0), (3.2, 5.0), (6.8, 11.0), (2.6, 18.0), (6.4, 24.0), (4.2, 28.5), (5.0, 32.0)]
    d = np.full(X.shape, 1e9)
    for off in (-h, 0, h):
        d = np.minimum(d, polyline_dist(X, Y, [(x, y + off) for x, y in pts]))
    core = smoothstep(1.1, 0.5, d)
    inner = smoothstep(2.2, 0.9, d)
    glow = np.exp(-(d / 2.2) ** 2) * 0.75
    inten = np.clip(np.maximum.reduce([core, inner * 0.8, glow]), 0, 1)
    col = ramp(np.clip(core * 0.6 + inner * 0.4, 0, 1),
               [(0.0, (255, 120, 40)), (0.5, (255, 196, 120)), (1.0, (255, 255, 255))])
    return _pool_rgba(paint(col, inten), ss)


def sprite_kamikaze() -> np.ndarray:
    """Drone suicida do Swarm (12x12): ponta de flecha lima, olho claro e propulsor."""
    p = Pix(12, 12)
    lime = rgb((184, 255, 106))
    body = p.poly([(6.0, 0.6), (10.8, 9.4), (6.0, 7.6), (1.2, 9.4)])
    eye = p.disc(6.0, 5.2, 1.3)
    keel = p.seg(6.0, 2.0, 6.0, 7.2, 1.0) & ~eye
    img = render_layers(12, 12, [(body, lime, True), (keel, lime * 0.62, False), (eye, WHITE, False)])
    X, Y = grid(12, 12)
    flame = np.exp(-((X - 6.0) / 1.1) ** 2) * smoothstep(12.0, 9.0, Y) * smoothstep(7.6, 9.0, Y)
    return over(paint(rgb((230, 255, 150)), flame), img)


def sprite_lance() -> np.ndarray:
    """Lança de luz da Ascension (8x26): núcleo branco, ponta afiada, cauda que some (tingida no jogo)."""
    w, h, ss = 8, 26, 2
    X, Y = grid(w, h, ss)
    half = np.where(Y < 7.0, (Y / 7.0) * 2.2, 2.2 - (Y - 7.0) / 19.0 * 1.4)
    dx = np.abs(X - 4.0)
    core = smoothstep(half * 0.55 + 0.35, half * 0.55 - 0.15, dx) * (Y > 0.6)
    body = smoothstep(half + 0.4, half - 0.2, dx) * (Y > 0.3)
    glow = np.exp(-(np.maximum(dx - half, 0) / 1.2) ** 2) * 0.45 * (Y > 1.5)
    fade = smoothstep(26.0, 14.0, Y) * 0.7 + 0.3 * smoothstep(26.0, 20.0, Y)
    inten = np.maximum.reduce([core, body * 0.8, glow]) * fade
    col = ramp(core, [(0.0, (214, 228, 245)), (1.0, (255, 255, 255))])
    return _pool_rgba(paint(col, inten), ss)


def sprite_mortar() -> np.ndarray:
    """Granada de morteiro do Ram (12x12): esfera vermelho-laranja com contorno e brasa no topo."""
    X, Y = grid(12, 12)
    d = np.hypot(X - 6, Y - 6)
    img = blank(12, 12)
    out_ = (d <= 5.8) & (d > 4.8)
    dark = (d <= 4.8) & (d > 3.8)
    body = d <= 3.8
    img = over(img, paint(OUTLINE, out_.astype(float)))
    img = over(img, paint(rgb((168, 44, 22)), dark.astype(float)))
    img = over(img, paint(rgb((255, 120, 70)), body.astype(float)))
    hot = np.hypot(X - 5.0, Y - 4.8) <= 1.9
    img = over(img, paint(rgb((255, 214, 120)), hot.astype(float)))
    img = over(img, paint(WHITE, (np.hypot(X - 4.6, Y - 4.4) <= 0.8).astype(float)))
    return img


def sprite_warn_circle() -> np.ndarray:
    """Aviso de artilharia (64x64): anel vermelho tracejado, preenchimento leve e mira no centro."""
    ss, n = 2, 64
    X, Y = grid(n, n, ss)
    c = n / 2.0
    d = np.hypot(X - c, Y - c)
    th = np.arctan2(Y - c, X - c)
    red = rgb((255, 64, 56))
    dash = (np.mod(th / math.tau * 16.0 + 0.25, 1.0) < 0.62)
    ring_ = (np.abs(d - 29.0) <= 1.5) & dash
    rim = (np.abs(d - 29.0) <= 2.6) & dash & ~ring_
    fill = (d < 29.0) * (0.10 + 0.14 * (d / 29.0) ** 3)
    inner = (np.abs(d - 19.0) <= 0.6) * (np.mod(th / math.tau * 24.0, 1.0) < 0.5) * 0.55
    cross = ((np.abs(X - c) <= 0.6) & (np.abs(Y - c) <= 4.0)) | ((np.abs(Y - c) <= 0.6) & (np.abs(X - c) <= 4.0))
    img = paint(red, fill)
    img = over(img, paint(rgb((70, 8, 10)), rim * 0.6))
    img = over(img, paint(red, ring_.astype(float)))
    img = over(img, paint(rgb((255, 140, 120)), inner))
    img = over(img, paint(rgb((255, 120, 100)), cross * 0.8))
    return _pool_rgba(img, ss)


def sprite_dash_trail() -> np.ndarray:
    """Rastro de investida (16x48): faixa branca macia que some para trás, com dois fios laterais."""
    w, h = 16, 48
    X, Y = grid(w, h)
    fade = (1.0 - Y / h) ** 1.5
    core = np.exp(-((X - 8.0) / 2.0) ** 2) * fade * 0.95
    body = np.exp(-((X - 8.0) / 4.5) ** 2) * fade * 0.45
    wisp_fade = (1.0 - np.clip(Y / (h * 0.7), 0, 1)) ** 2
    wisps = (np.exp(-((X - 3.0) / 0.6) ** 2) + np.exp(-((X - 13.0) / 0.6) ** 2)) * wisp_fade * 0.5
    inten = np.clip(np.maximum.reduce([core, body, wisps]), 0, 1)
    return paint(WHITE, inten)


def sprite_shield_front() -> np.ndarray:
    """Escudo frontal da Égide (64x24): arco dourado convexo para a frente, colmeia leve, pontas somem."""
    w, h, ss = 64, 24, 2
    X, Y = grid(w, h, ss)
    e = np.hypot((X - 32.0) / 31.0, (Y - 30.0) / 27.0)
    band = np.abs(e - 0.86)
    edge = np.exp(-((e - 0.95) / 0.03) ** 2)
    body = smoothstep(0.1, 0.02, band) * (e <= 0.95)
    glow = np.exp(-(np.maximum(e - 0.95, 0) / 0.05) ** 2) * 0.6 * (e > 0.95)
    hexes = 0.5 + 0.5 * np.cos(X * 1.4) * np.cos((Y + X * 0.5) * 1.4)
    ends = smoothstep(31.5, 20.0, np.abs(X - 32.0)) * 0.6 + 0.4 * smoothstep(31.5, 27.0, np.abs(X - 32.0))
    inten = np.clip(np.maximum.reduce([edge, body * (0.55 + 0.3 * hexes), glow]), 0, 1) * ends
    col = ramp(np.clip(edge + body * 0.3, 0, 1), [(0.0, (232, 170, 60)), (0.5, (255, 224, 138)), (1.0, (255, 252, 232))])
    return _pool_rgba(paint(col, inten), ss)


def sprite_supernova() -> np.ndarray:
    """Supernova (128x128): halo largo, anel de choque, raios em camadas e núcleo branco (aditivo)."""
    n = 128
    X, Y = grid(n, n)
    c = n / 2.0
    dx, dy = X - c, Y - c
    r = np.hypot(dx, dy) / c
    th = np.arctan2(dy, dx)
    halo = np.exp(-(r / 0.55) ** 2) * 0.55
    flare = from_list(gs.flare(n), n, n)[..., 3]
    shock = from_list(gs.shock(n), n, n)[..., 3] * 0.45
    def spikes(k, width, length, rot=0.0):
        a = np.abs(np.sin((th - rot) * k / 2.0))
        return np.exp(-(a / width) ** 2) * np.exp(-(r / length) ** 2)
    rays = spikes(4, 0.035, 0.95) + 0.7 * spikes(4, 0.05, 0.6, math.pi / 4)
    rng = np.random.default_rng(128)
    thin = np.zeros_like(r)
    for _ in range(18):
        a0 = rng.random() * math.tau
        L = 0.35 + rng.random() * 0.45
        da = np.angle(np.exp(1j * (th - a0)))
        thin = np.maximum(thin, np.exp(-(da / 0.012) ** 2) * np.exp(-(r / L) ** 2) * (0.4 + 0.4 * rng.random()))
    inten = np.clip(halo + flare * 0.9 + shock + rays + thin, 0, 1)
    heat = np.clip(flare * 1.2 + rays * 0.5 + thin * 0.4, 0, 1)
    col = ramp(heat, [(0.0, (230, 70, 170)), (0.25, (255, 140, 70)), (0.55, (255, 230, 140)), (1.0, (255, 255, 255))])
    return paint(col, inten)


def sprite_eclipse_disc() -> np.ndarray:
    """Disco do eclipse total (128x128): disco negro, aro brilhante, coroa violeta e ponto de diamante."""
    ss, n = 2, 128
    X, Y = grid(n, n, ss)
    c = n / 2.0
    d = np.hypot(X - c, Y - c) / c
    th = np.arctan2(Y - c, X - c)
    R = 0.6
    flame = angular_noise(th, (4, 7, 11, 17, 29, 43), 77)
    reach = 0.12 + 0.28 * flame ** 2
    corona = np.clip(1.0 - (d - R) / reach, 0, 1) ** 2.2 * (d >= R)
    corona *= 0.75 + 0.25 * angular_noise(th, (31, 53, 71), 78)
    rim = np.exp(-((d - R - 0.01) / 0.018) ** 2)
    inten = np.clip(corona + rim, 0, 1) * smoothstep(1.0, 0.92, d)
    col = ramp(np.clip(rim + corona * 0.7, 0, 1),
               [(0.0, (80, 30, 160)), (0.45, (165, 138, 255)), (0.8, (225, 205, 255)), (1.0, (255, 255, 255))])
    img = paint(col, inten)
    disc_col = ramp(smoothstep(R * 0.6, R, d), [(0.0, (6, 4, 14)), (1.0, (24, 12, 46))])
    disc = smoothstep(R + 0.004, R - 0.012, d)
    img = over(img, paint(disc_col, disc))
    bx, by = c + R * c * math.cos(-0.8), c + R * c * math.sin(-0.8)
    bd = np.hypot(X - bx, Y - by) / c
    bead = np.exp(-(bd / 0.05) ** 2) + 0.8 * np.exp(-(np.abs(X - bx) / 0.6) ** 2) * np.exp(-(bd / 0.25) ** 2) \
        + 0.8 * np.exp(-(np.abs(Y - by) / 0.6) ** 2) * np.exp(-(bd / 0.25) ** 2)
    img = over(img, paint(WHITE, np.clip(bead, 0, 1)))
    return _pool_rgba(img, ss)


# ---------------------------------------------------------------- ícones 24x24

N = 24


def plate(tint: np.ndarray, tier: int) -> np.ndarray:
    """Placa do ícone: quadrado arredondado escuro, contorno de 1 px e aro (dourado no nível 3)."""
    X, Y = grid(N, N)
    q = np.maximum(np.abs(X - 12.0) - 8.0, 0.0), np.maximum(np.abs(Y - 12.0) - 8.0, 0.0)
    sd = np.hypot(*q) - 4.0  # 0 na borda externa (raio 12)
    inside = sd <= 0.0
    out_px = inside & (sd > -1.0)
    rim_px = (sd <= -1.0) & (sd > -2.0)
    face = sd <= -2.0
    top = mix(NAVY, tint, 0.2)
    bot = mix(NAVY * 0.7, tint, 0.06)
    face_col = mix(top, bot, 0.0)[None, None, :] * (1 - Y[..., None] / N) + bot[None, None, :] * (Y[..., None] / N)
    img = paint(face_col, face.astype(float))
    if tier == 3:
        d = np.hypot(X - 12.0, Y - 12.0)
        img = over(img, paint(GOLD, np.exp(-(d / 8.0) ** 2) * 0.28 * face))
        inner = (sd <= -2.0) & (sd > -3.0)
        img = over(img, paint(GOLD_DARK, inner * 0.8))
        rim_col = np.where(((X + Y) < 14)[..., None], mix(GOLD, WHITE, 0.45), GOLD)
        img = over(img, paint(rim_col, rim_px.astype(float)))
    else:
        rim_col = mix(tint * 0.5, NAVY, 0.2) if tier == 1 else tint * 0.8
        img = over(img, paint(rim_col, rim_px.astype(float)))
    img = over(img, paint(OUTLINE, out_px.astype(float)))
    if tier == 3:
        # Brilho de quatro pontas no canto: marca do supremo.
        for (x, y, a) in ((19, 4, 1.0), (18, 4, 0.7), (20, 4, 0.7), (19, 3, 0.7), (19, 5, 0.7)):
            img[y, x, :3] = WHITE
            img[y, x, 3] = 1.0
    return img


def icon(tint: np.ndarray, tier: int, layers: list) -> np.ndarray:
    # O símbolo (e o contorno dele) nunca invade o aro da placa.
    X, Y = grid(N, N)
    sd = np.hypot(np.maximum(np.abs(X - 12.0) - 8.0, 0.0), np.maximum(np.abs(Y - 12.0) - 8.0, 0.0)) - 4.0
    room = sd <= -3.0
    return render_layers(N, N, [(m & room, c, s) for m, c, s in layers], base=plate(tint, tier))


def _cols(t: np.ndarray):
    td = np.clip(t * 0.6 + np.array([0.0, 0.02, 0.08]), 0, 1)
    tl = mix(t, WHITE, 0.6)
    return t, td, tl


ORANGE = rgb((255, 150, 60))
CORAL = rgb((255, 90, 110))


def icons_falcon(t):
    T, TD, TL = _cols(t)
    p = Pix(N, N)
    T = rgb((236, 244, 255))
    TD = rgb((140, 165, 200))
    # 1 Investida: flecha para cima com linhas de velocidade.
    a = p.poly([(12, 3.5), (18.5, 14), (12, 10.8), (5.5, 14)])
    lines = p.seg(8, 15.5, 8, 19.5, 1.0) | p.seg(16, 15.5, 16, 19.5, 1.0) | p.seg(12, 13.5, 12, 20.5, 1.0)
    i1 = icon(t, 1, [(lines, TD, False), (a, T, True)])
    # 2 Asas Cruzadas: leque de cinco penas.
    fe = np.zeros((N, N), bool)
    sh = np.zeros((N, N), bool)
    for ang in (-56, -28, 0, 28, 56):
        r_ = math.radians(ang - 90)
        x1, y1 = 12 + 12.5 * math.cos(r_), 19.5 + 12.5 * math.sin(r_)
        fe |= p.leaf(12, 19.5, x1, y1, 4.2)
        sh |= p.seg(12 + 3.5 * math.cos(r_), 19.5 + 3.5 * math.sin(r_),
                    12 + 9.5 * math.cos(r_), 19.5 + 9.5 * math.sin(r_), 0.9)
    hub = p.disc(12, 20.0, 1.8)
    i2 = icon(t, 2, [(fe, T, False), (sh & fe, TD, False), (hub, GOLD, False)])
    # 3 Mergulho Solar: sol no alto, ave em mergulho saindo dele.
    sun = p.disc(12, 7.0, 3.6)
    rays = np.zeros((N, N), bool)
    for k in range(8):
        r_ = math.radians(k * 45)
        rays |= p.seg(12 + 4.8 * math.cos(r_), 7 + 4.8 * math.sin(r_), 12 + 6.3 * math.cos(r_), 7 + 6.3 * math.sin(r_), 1.0)
    dive = p.poly([(12, 20.5), (18.5, 11.5), (12, 14.5), (5.5, 11.5)])
    trail = p.seg(12, 11.5, 12, 13.0, 1.0)
    i3 = icon(t, 3, [(rays, GOLD, False), (sun, GOLD, True), (trail, TD, False), (dive, T, True)])
    return [i1, i2, i3]


def icons_manta(t):
    T, TD, TL = _cols(t)
    p = Pix(N, N)
    body = p.poly([(12, 14.5), (19.5, 20), (12, 18.2), (4.5, 20)])
    # 1 Lança de Coral: feixe fino.
    beam = p.rect(11, 3, 13, 15)
    core = p.rect(11.5, 3, 12.5, 15)
    i1 = icon(t, 1, [(beam, T, False), (core, WHITE, False), (body, T, True)])
    # 2 Prisma Abissal: um feixe entra, três saem.
    prism = p.poly([(12, 9), (17.5, 17.5), (6.5, 17.5)])
    inner = p.poly([(12, 12), (15, 16.5), (9, 16.5)])
    b_in = p.seg(12, 21, 12, 17, 1.4)
    outs = p.seg(10.2, 10.5, 4.5, 3.5, 1.4) | p.seg(12, 9, 12, 2.5, 1.4) | p.seg(13.8, 10.5, 19.5, 3.5, 1.4)
    i2 = icon(t, 2, [(b_in, WHITE, False), (outs, TL, False), (prism, T, True), (inner, TL, False)])
    # 3 Raio do Abismo: feixe enorme.
    big = p.rect(7.5, 3, 16.5, 17)
    mid = p.rect(9.5, 3, 14.5, 17)
    hot = p.rect(11, 3, 13, 17)
    base = p.disc(12, 17.5, 4.8)
    i3 = icon(t, 3, [(big, TD, False), (mid, T, False), (base, T, True), (hot, WHITE, False),
                     (p.disc(12, 17.5, 2.2), WHITE, False)])
    return [i1, i2, i3]


def icons_hydra(t):
    T, TD, TL = _cols(t)
    p = Pix(N, N)
    # 1 Cardume: oito mini mísseis.
    ms, tips, fl = (np.zeros((N, N), bool) for _ in range(3))
    for row, oy in ((0, 4), (1, 12)):
        for k in range(4):
            x = 5.0 + k * 4.66 + (1.2 if row else -0.4)
            ms |= p.rect(x - 1, oy + 1, x + 1, oy + 5)
            tips |= p.rect(x - 1, oy, x + 1, oy + 1.2)
            fl |= p.rect(x - 0.5, oy + 5, x + 0.5, oy + 7)
    i1 = icon(t, 1, [(fl, ORANGE, False), (ms, T, False), (tips, WHITE, False)])
    # 2 Mordida Tripla: três torpedos.
    tor, nose = np.zeros((N, N), bool), np.zeros((N, N), bool)
    for (x0, x1) in ((7.5, 5.0), (12, 12), (16.5, 19.0)):
        tor |= p.seg(x0, 19.5, x1, 6.5, 3.6)
        nose |= p.disc(x1, 6.0, 1.3)
    fl2 = p.disc(7.5, 20.5, 1.0) | p.disc(12, 20.5, 1.0) | p.disc(16.5, 20.5, 1.0)
    i2 = icon(t, 2, [(fl2, ORANGE, False), (tor, T, True), (nose, WHITE, False)])
    # 3 Sete Cabeças: leque de sete mísseis saindo do mesmo corpo.
    necks, heads = np.zeros((N, N), bool), np.zeros((N, N), bool)
    for k in range(7):
        r_ = math.radians(-90 + (k - 3) * 21)
        ca, sa = math.cos(r_), math.sin(r_)
        x1, y1 = 12 + 7.0 * ca, 18.5 + 7.0 * sa
        necks |= p.seg(12, 18.5, x1, y1, 1.2)
        tip = (12 + 10.6 * ca, 18.5 + 10.6 * sa)
        heads |= p.poly([tip, (x1 - 1.7 * sa, y1 + 1.7 * ca), (x1 + 1.7 * sa, y1 - 1.7 * ca)])
    hub = p.disc(12, 19.0, 2.6)
    i3 = icon(t, 3, [(necks, TL, False), (hub, T, True), (heads, T, False), (heads & shift(heads, 1, 0), TL, False)])
    return [i1, i2, i3]


def icons_tempest(t):
    T, TD, TL = _cols(t)
    p = Pix(N, N)
    # 1 Corrente de Jato: dupla divisa para cima e fios de vento.
    v1 = p.line([(5.5, 11), (12, 4.5), (18.5, 11)], 3.0)
    v2 = p.line([(5.5, 18), (12, 11.5), (18.5, 18)], 3.0)
    wind = p.seg(4, 21, 8, 21, 1.0) | p.seg(16, 21, 20, 21, 1.0)
    i1 = icon(t, 1, [(wind, TD, False), (v2, TD * 1.25, False), (v1, T, True)])
    # 2 Olho do Ciclone: anel com ganchos de ciclone e ponteiros de relógio.
    ring_ = p.ring(12, 12, 6.2, 1.8)
    hooks = p.arc(12, 12, 8.4, 1.6, -95, -20) | p.arc(12, 12, 8.4, 1.6, 85, 160)
    hands = p.seg(12, 12, 12, 7.8, 1.2) | p.seg(12, 12, 15.0, 13.4, 1.2)
    i2 = icon(t, 2, [(hooks, TD * 1.3, False), (ring_, T, False), (hands, WHITE, False),
                     (p.disc(12, 12, 1.1), WHITE, False)])
    # 3 Tempestade Elétrica: raio clássico com faíscas em cadeia.
    bolt = p.poly([(14.5, 2.5), (6.5, 13), (11, 13), (8.5, 21.5), (17.5, 9.5), (12.8, 9.5), (16.5, 2.5)])
    sparks = p.disc(4.5, 18.5, 1.4) | p.disc(19.5, 15.5, 1.4) | p.seg(5.2, 17.6, 8.6, 15.6, 1.0) \
        | p.seg(18.6, 14.8, 15.8, 13.4, 1.0)
    i3 = icon(t, 3, [(sparks, TL, False), (bolt, T, True)])
    return [i1, i2, i3]


def icons_trident(t):
    T, TD, TL = _cols(t)
    p = Pix(N, N)
    # 1 Onda Quebrante: onda que se enrola.
    wave = p.poly([(3, 20.5), (3, 15), (5.5, 10.5), (9, 6.5), (13, 4.5), (17, 5.0), (20, 7.5), (20.5, 10.5),
                   (18.5, 12.0), (17.0, 9.8), (14.5, 9.0), (12.5, 10.5), (12.5, 13.5), (15.5, 16.0),
                   (21, 16.0), (21, 20.5)])
    crest = wave & ~shift(wave, 1, 0) & ~shift(wave, 2, 0) & p.rect(0, 0, 24, 13)
    hollow = p.poly([(14.0, 11.0), (16.6, 10.6), (17.6, 12.4), (15.8, 14.4), (13.8, 13.2)]) & ~wave
    foam = p.disc(21.0, 4.0, 0.9) | p.disc(18.5, 2.6, 0.7) | p.disc(4.0, 8.0, 0.8)
    i1 = icon(t, 1, [(wave, T, True), (hollow, TD, False), (crest, WHITE, False), (foam, WHITE, False)])
    # 2 Redemoinho: espiral.
    pts = []
    for i in range(80):
        th = i / 79 * 3.6 * math.pi
        r_ = 0.9 + 0.75 * th
        pts.append((12 + r_ * math.cos(th), 12 + r_ * math.sin(th)))
    spiral = p.line(pts, 2.0)
    i2 = icon(t, 2, [(spiral, T, False), (p.disc(12, 12, 1.2), WHITE, False)])
    # 3 Maremoto: três ondas empilhadas.
    waves = np.zeros((N, N), bool)
    crests = np.zeros((N, N), bool)
    for k, y0 in enumerate((6.5, 12, 17.5)):
        pts = [(x, y0 + 1.8 * math.sin((x - 4) / 16 * 2 * math.pi + k * 0.6)) for x in np.linspace(3.5, 20.5, 40)]
        waves |= p.line(pts, 2.4)
        crests |= p.disc(pts[9][0], pts[9][1] - 0.4, 0.9)
    i3 = icon(t, 3, [(waves, T, False), (crests, WHITE, False)])
    return [i1, i2, i3]


def icons_atlas(t):
    T, TD, TL = _cols(t)
    p = Pix(N, N)
    # 1 Égide: escudo.
    sh = p.poly([(5, 4.5), (19, 4.5), (19, 11), (16.5, 16.5), (12, 20.5), (7.5, 16.5), (5, 11)])
    inner = p.poly([(7.5, 7), (16.5, 7), (16.5, 11), (14.8, 14.8), (12, 17.5), (9.2, 14.8), (7.5, 11)])
    mark = p.seg(12, 8.5, 12, 15.5, 1.4) | p.seg(9.5, 10.5, 14.5, 10.5, 1.4)
    i1 = icon(t, 1, [(sh, T, True), (inner, TD, False), (mark, WHITE, False)])
    # 2 Bastião: três orbes em órbita.
    orbit = p.ring(12, 12, 7.0, 1.0)
    orbs, hi = np.zeros((N, N), bool), np.zeros((N, N), bool)
    for k in range(3):
        r_ = math.radians(-90 + k * 120)
        ox, oy = 12 + 7 * math.cos(r_), 12 + 7 * math.sin(r_)
        orbs |= p.disc(ox, oy, 2.8)
        hi |= p.disc(ox - 0.8, oy - 0.8, 0.9)
    core = p.disc(12, 12, 2.2)
    i2 = icon(t, 2, [(orbit, TD, False), (core, TL, False), (orbs, T, True), (hi, WHITE, False)])
    # 3 Muralha de Atlântida: muro de luz e coração.
    wall = p.rect(3.5, 13.5, 20.5, 20.5)
    bricks = (p.rect(3.5, 16.5, 20.5, 17.4)
              | p.rect(8, 13.5, 8.9, 16.5) | p.rect(15, 13.5, 15.9, 16.5)
              | p.rect(11.5, 17.4, 12.4, 20.5) | p.rect(4.5, 17.4, 5.4, 20.5) | p.rect(18.5, 17.4, 19.4, 20.5))
    heart = p.disc(9.6, 6.6, 2.6) | p.disc(14.4, 6.6, 2.6) | p.poly([(7.1, 7.4), (16.9, 7.4), (12, 12.2)])
    i3 = icon(t, 3, [(wall, T, True), (bricks & wall, TD, False), (heart, CORAL, True)])
    return [i1, i2, i3]


def icons_ram(t):
    T, TD, TL = _cols(t)
    p = Pix(N, N)
    # 1 Salva de Morteiro: duas granadas em arco pontilhado.
    arc_pts = [(3.5 + 17 * u, 20.5 - 16 * 4 * u * (1 - u) * 0.95) for u in np.linspace(0, 1, 30)]
    dashes = np.zeros((N, N), bool)
    for k in range(0, 30, 2):
        dashes |= p.disc(*arc_pts[k], 0.75)
    shells, hot = np.zeros((N, N), bool), np.zeros((N, N), bool)
    for u, r_ in ((0.22, 2.2), (0.5, 2.7), (0.8, 2.2)):
        x, y = 3.5 + 17 * u, 20.5 - 16 * 4 * u * (1 - u) * 0.95
        shells |= p.disc(x, y, r_)
        hot |= p.disc(x - 0.7, y - 0.7, 0.8)
    i1 = icon(t, 1, [(dashes, TD * 1.4, False),
                     (shells, T, True), (hot, WHITE, False)])
    # 2 Carga do Ariete: cabeça de carneiro de frente, chifres enrolados.
    horns = p.arc(7.2, 9.5, 3.4, 2.4, -270, 0) | p.arc(16.8, 9.5, 3.4, 2.4, 180, 450)
    face = p.poly([(9, 6.5), (15, 6.5), (14.5, 15), (13, 19.5), (11, 19.5), (9.5, 15)])
    eyes = p.rect(10, 10, 11, 11) | p.rect(13, 10, 14, 11)
    snout = p.rect(10.8, 17, 13.2, 19)
    i2 = icon(t, 2, [(horns, TL, True), (face, T, True), (eyes, OUTLINE, False), (snout, TD, False)])
    # 3 Bombardeio Abissal: grade 3x3 de impactos.
    hits, cores = np.zeros((N, N), bool), np.zeros((N, N), bool)
    for gy in range(3):
        for gx in range(3):
            cx, cy = 6.2 + gx * 5.8, 6.2 + gy * 5.8
            hits |= p.star(cx, cy, 2.7, 1.2, 4, rot=-45 if (gx + gy) % 2 else -90)
            cores |= p.disc(cx, cy, 0.8)
    i3 = icon(t, 3, [(hits, T, True), (cores, WHITE, False)])
    return [i1, i2, i3]


def icons_swarm(t):
    T, TD, TL = _cols(t)
    p = Pix(N, N)
    # 1 Colmeia: favos.
    centers = ((12, 8.0), (8.1, 14.8), (15.9, 14.8))
    hx = np.zeros((N, N), bool)
    cells = np.zeros((N, N), bool)
    for cx, cy in centers:
        hx |= p.hexagon(cx, cy, 3.6)
        cells |= p.hexagon(cx, cy, 2.0)
    seams = np.zeros((N, N), bool)
    for (a, b) in ((0, 1), (0, 2), (1, 2)):
        (x0, y0), (x1, y1) = centers[a], centers[b]
        mx, my = (x0 + x1) / 2, (y0 + y1) / 2
        dx, dy = (y1 - y0) * 0.33, -(x1 - x0) * 0.33
        seams |= p.seg(mx - dx, my - dy, mx + dx, my + dy, 0.9)
    bees = p.ellipse(4.5, 5.5, 1.4, 1.0) | p.ellipse(19.5, 5.0, 1.4, 1.0)
    i1 = icon(t, 1, [(hx, T, True), (seams & hx, OUTLINE, False), (cells, TD, False), (bees, GOLD, False)])
    # 2 Rede Neural: nós ligados.
    nodes = [(6, 6), (18, 6.5), (12, 12), (5.5, 18), (18.5, 18)]
    links = np.zeros((N, N), bool)
    for a, b in ((0, 2), (1, 2), (3, 2), (4, 2), (0, 1), (3, 4), (0, 3)):
        links |= p.seg(*nodes[a], *nodes[b], 1.0)
    dots = np.zeros((N, N), bool)
    for k, (x, y) in enumerate(nodes):
        dots |= p.disc(x, y, 2.6 if k == 2 else 1.9)
    i2 = icon(t, 2, [(links, TD * 1.3, False), (dots, T, True), (p.disc(12, 12, 1.0), WHITE, False)])
    # 3 Rainha do Enxame: drone com coroa.
    crown = p.poly([(6.5, 10), (6.5, 4), (9.2, 6.8), (12, 3), (14.8, 6.8), (17.5, 4), (17.5, 10)])
    jewel = p.disc(12, 7.6, 1.0)
    wings = p.ellipse(6.5, 15.5, 3.2, 2.0) | p.ellipse(17.5, 15.5, 3.2, 2.0)
    body = p.ellipse(12, 16, 3.4, 4.2)
    eye = p.disc(12, 15.5, 1.3)
    i3 = icon(t, 3, [(wings, TL, False), (body, T, True), (eye, WHITE, False), (crown, GOLD, True),
                     (jewel, CORAL, False)])
    return [i1, i2, i3]


def icons_eclipse(t):
    T, TD, TL = _cols(t)
    p = Pix(N, N)
    ship = [(12, 3.5), (18.5, 17), (15, 15.5), (12, 20), (9, 15.5), (5.5, 17)]
    # 1 Umbra: silhueta escura com fio de luz e eco deslocado.
    ghost = p.poly([(x + 2.5, y + 1.5) for x, y in ship])
    sil = p.poly(ship)
    edge = sil & ~(shift(sil, 1, 0) & shift(sil, -1, 0) & shift(sil, 0, 1) & shift(sil, 0, -1))
    i1 = icon(t, 1, [(ghost & ~sil, TD, False), (sil, rgb((26, 16, 48)), False), (edge, T, False)])
    # 2 Corona: anel de plasma com labaredas.
    ring_ = p.ring(12, 12, 5.6, 2.4)
    fl = np.zeros((N, N), bool)
    for k in range(8):
        a = math.radians(k * 45 + 22.5)
        ln = 9.4 if k % 2 == 0 else 8.2
        fl |= p.poly([(12 + 6.2 * math.cos(a - 0.3), 12 + 6.2 * math.sin(a - 0.3)),
                      (12 + ln * math.cos(a), 12 + ln * math.sin(a)),
                      (12 + 6.2 * math.cos(a + 0.3), 12 + 6.2 * math.sin(a + 0.3))])
    inner = p.ring(12, 12, 4.4, 0.9)
    i2 = icon(t, 2, [(fl, TD * 1.35, False), (ring_, T, False), (inner, WHITE, False)])
    # 3 Eclipse Total: sol negro, aro claro, raios e ponto de diamante.
    rays = np.zeros((N, N), bool)
    for k in range(12):
        a = math.radians(k * 30)
        ln = 10.0 if k % 3 == 0 else 8.4
        rays |= p.seg(12 + 7.0 * math.cos(a), 12 + 7.0 * math.sin(a), 12 + ln * math.cos(a), 12 + ln * math.sin(a), 1.0)
    rim = p.disc(12, 12, 6.4)
    disc = p.disc(12, 12, 5.0)
    bead = p.disc(16.0, 8.0, 1.4)
    i3 = icon(t, 3, [(rays, T, False), (rim, TL, False), (disc, rgb((12, 6, 24)), False), (bead, WHITE, False)])
    return [i1, i2, i3]


def icons_nova(t):
    T, TD, TL = _cols(t)
    p = Pix(N, N)
    # 1 Mira Estelar: mira com estrela no centro.
    ring_ = p.ring(12, 12, 7.5, 1.2) & ~(p.rect(10.5, 0, 13.5, 24) | p.rect(0, 10.5, 24, 13.5))
    ticks = p.seg(12, 2.5, 12, 6.5, 1.2) | p.seg(12, 17.5, 12, 21.5, 1.2) | p.seg(2.5, 12, 6.5, 12, 1.2) \
        | p.seg(17.5, 12, 21.5, 12, 1.2)
    st = p.star(12, 12, 3.6, 1.3, 4)
    i1 = icon(t, 1, [(ring_, T, False), (ticks, TD * 1.3, False), (st, WHITE, False)])
    # 2 Estrela Cadente: estrela com rastro.
    trail = p.seg(4, 20, 12, 12, 2.6) | p.seg(4.5, 15, 10, 10.5, 1.2) | p.seg(9, 20.5, 13.5, 14, 1.2)
    star = p.star(15, 9, 5.6, 2.4, 5)
    i2 = icon(t, 2, [(trail, TD * 1.3, False), (star, T, True), (p.disc(15, 9.4, 1.0), WHITE, False)])
    # 3 Supernova: explosão de oito pontas.
    burst = p.star(12, 12, 10.0, 4.0, 8, rot=-90)
    burst2 = p.star(12, 12, 7.0, 3.2, 8, rot=-67.5)
    core = p.disc(12, 12, 2.6)
    i3 = icon(t, 3, [(burst, T, True), (burst2, TL, False), (core, WHITE, False)])
    return [i1, i2, i3]


def icons_titan(t):
    T, TD, TL = _cols(t)
    p = Pix(N, N)
    # 1 Granada Sísmica: granada com pino.
    body = p.ellipse(11, 14.5, 5.6, 6.0)
    grooves = (p.rect(5, 13.8, 17, 14.6) | p.rect(10.6, 9, 11.4, 21)) & body
    cap = p.rect(9, 6.5, 13.5, 9.3)
    lever = p.seg(13.5, 7, 17.5, 10.5, 1.4)
    pin = p.ring(16.5, 5.2, 2.0, 1.0)
    i1 = icon(t, 1, [(pin, TL, False), (lever, TD * 1.4, False), (cap, TD * 1.4, False), (body, T, True),
                     (grooves, TD, False), (p.disc(9, 12, 1.0), WHITE, False)])
    # 2 Reação em Cadeia: explosões crescentes ligadas.
    b1 = p.star(5.5, 18.5, 2.6, 1.2, 6)
    b2 = p.star(11, 12.5, 4.0, 1.8, 7)
    b3 = p.star(17, 6.5, 4.6, 2.2, 8)
    link = p.seg(5.5, 18.5, 17, 6.5, 1.0)
    cores = p.disc(5.5, 18.5, 0.8) | p.disc(11, 12.5, 1.2) | p.disc(17, 6.5, 1.6)
    i2 = icon(t, 2, [(link, TL, False), (b1 | b2 | b3, T, True), (cores, WHITE, False)])
    # 3 Cataclismo: coluna de explosões sobre base larga.
    s1 = p.star(12, 16.0, 6.4, 2.8, 8, rot=-90)
    s2 = p.star(12, 8.6, 4.6, 2.0, 7, rot=-90)
    s3 = p.star(12, 3.9, 2.6, 1.1, 5, rot=-90)
    ground = p.rect(3.5, 20.0, 20.5, 21.0)
    debris = p.disc(4.5, 12.0, 0.8) | p.disc(19.5, 10.5, 0.8) | p.disc(5.5, 5.5, 0.7) | p.disc(18.5, 4.5, 0.7)
    cores = p.disc(12, 16.0, 2.0) | p.disc(12, 8.6, 1.3) | p.disc(12, 3.9, 0.7)
    i3 = icon(t, 3, [(ground, TD * 1.3, False), (debris, TL, False), (s1, T, True), (s2, mix(t, ORANGE, 0.65), True),
                     (s3, GOLD, False), (cores, WHITE, False)])
    return [i1, i2, i3]


def icons_ascension(t):
    T, TD, TL = _cols(t)
    p = Pix(N, N)
    # 1 Eco de Atlântida: anéis de eco.
    rings = p.ring(12, 12, 9.0, 1.2) & ~p.rect(0, 10.5, 24, 13.5)
    rings |= p.ring(12, 12, 5.8, 1.2) & ~p.rect(10.5, 0, 13.5, 24)
    dot = p.disc(12, 12, 2.4)
    i1 = icon(t, 1, [(rings, T, False), (dot, TL, True)])
    # 2 Coro dos Doze: doze raios em arco-íris.
    layers = []
    for k in range(12):
        a = math.radians(-90 + k * 30)
        hue = k / 12.0
        col = np.array([0.5 + 0.5 * math.cos(math.tau * (hue + s)) for s in (0.0, -1 / 3, 1 / 3)])
        col = mix(col, WHITE, 0.25)
        layers.append((p.seg(12 + 3.6 * math.cos(a), 12 + 3.6 * math.sin(a),
                             12 + 9.2 * math.cos(a), 12 + 9.2 * math.sin(a), 1.6), col, False))
    layers.append((p.disc(12, 12, 2.8), T, True))
    i2 = icon(t, 2, layers)
    # 3 Ascensão: estrela com asas, subindo.
    wings = np.zeros((N, N), bool)
    for side in (-1, 1):
        for k, (ln, ang) in enumerate(((8.6, -20), (7.6, 5), (6.0, 30))):
            a = math.radians(ang)
            x0, y0 = 12 + side * 2.5, 11.5 + k * 1.0
            wings |= p.leaf(x0, y0, x0 + side * ln * math.cos(a), y0 - ln * math.sin(a) * -1 - 3.0, 3.0)
    star = p.star(12, 10, 4.8, 2.0, 5)
    rise = p.seg(12, 15, 12, 21, 1.2) | p.seg(9.5, 17, 9.5, 20, 1.0) | p.seg(14.5, 17, 14.5, 20, 1.0)
    i3 = icon(t, 3, [(rise, TD * 1.3, False), (wings, TL, False), (star, T, True),
                     (p.disc(12, 10.5, 1.0), WHITE, False)])
    return [i1, i2, i3]


ICONS = {
    "falcon": icons_falcon, "manta": icons_manta, "hydra": icons_hydra, "tempest": icons_tempest,
    "trident": icons_trident, "atlas": icons_atlas, "ram": icons_ram, "swarm": icons_swarm,
    "eclipse": icons_eclipse, "nova": icons_nova, "titan": icons_titan, "ascension": icons_ascension,
}

SPRITES = {
    "feather.png": (8, 16, sprite_feather),
    "torpedo.png": (10, 22, sprite_torpedo),
    "missile_mini.png": (6, 12, sprite_missile_mini),
    "orb.png": (16, 16, sprite_orb),
    "wave.png": (270, 28, sprite_wave),
    "vortex.png": (96, 96, sprite_vortex),
    "corona.png": (72, 72, sprite_corona),
    "reticle.png": (32, 32, sprite_reticle),
    "barrier.png": (160, 18, sprite_barrier),
    "bolt.png": (10, 32, sprite_bolt),
    "kamikaze.png": (12, 12, sprite_kamikaze),
    "lance.png": (8, 26, sprite_lance),
    "mortar.png": (12, 12, sprite_mortar),
    "warn_circle.png": (64, 64, sprite_warn_circle),
    "dash_trail.png": (16, 48, sprite_dash_trail),
    "shield_front.png": (64, 24, sprite_shield_front),
    "supernova.png": (128, 128, sprite_supernova),
    "eclipse_disc.png": (128, 128, sprite_eclipse_disc),
}


# ---------------------------------------------------------------- folha de revisão

FONT = {
    "A": "010101111101101", "B": "110101110101110", "C": "011100100100011", "D": "110101101101110",
    "E": "111100110100111", "F": "111100110100100", "G": "011100101101011", "H": "101101111101101",
    "I": "111010010010111", "J": "001001001101010", "K": "101101110101101", "L": "100100100100111",
    "M": "101111111101101", "N": "110101101101101", "O": "010101101101010", "P": "110101110100100",
    "Q": "010101101110011", "R": "110101110101101", "S": "011100010001110", "T": "111010010010010",
    "U": "101101101101111", "V": "101101101101010", "W": "101101111111101", "X": "101101010101101",
    "Y": "101101010010010", "Z": "111001010100111", "0": "111101101101111", "1": "010110010010111",
    "2": "110001010100111", "3": "110001010001110", "4": "101101111001001", "5": "111100110001110",
    "6": "011100111101111", "7": "111001010010010", "8": "111101111101111", "9": "111101111001110",
    "_": "000000000000111", ".": "000000000000010", "-": "000000111000000", " ": "000000000000000",
}


def draw_text(sheet: np.ndarray, x: int, y: int, text: str, k: int = 2, col=(190, 205, 225)):
    for ch in text.upper():
        g = FONT.get(ch, FONT[" "])
        for i, b in enumerate(g):
            if b == "1":
                gy, gx = divmod(i, 3)
                sheet[y + gy * k:y + gy * k + k, x + gx * k:x + gx * k + k, :3] = col
        x += 4 * k


def preview(items: list, path: pathlib.Path, k: int = 3) -> None:
    """Folha de revisão: cada imagem a k vezes, rotulada, sobre fundo escuro (e o ícone também sobre claro)."""
    width = 1240
    pad, label_h = 14, 16
    placed = []
    x = y = pad
    row_h = 0
    for name, img in items:
        h, w = img.shape[:2]
        cw = max(w * k, len(name) * 8) + pad
        ch = h * k + label_h + pad
        if x + cw > width:
            x = pad
            y += row_h
            row_h = 0
        placed.append((name, img, x, y))
        x += cw
        row_h = max(row_h, ch)
    height = y + row_h + pad
    sheet = np.zeros((height, width, 3))
    sheet[...] = (10, 14, 26)
    # Faixa de "oceano" atrás de tudo para conferir halos.
    for name, img, px_, py_ in placed:
        h, w = img.shape[:2]
        draw_text(sheet, px_, py_, name)
        big = np.repeat(np.repeat(img, k, 0), k, 1)
        y0 = py_ + label_h
        bg = sheet[y0:y0 + h * k, px_:px_ + w * k] / 255.0
        checker = ((np.indices((h * k, w * k)).sum(0) // (4 * k)) % 2)[..., None]
        bg = bg * 0.0 + np.where(checker, np.array((16, 26, 46)), np.array((12, 18, 34))) / 255.0
        a = big[..., 3:4]
        sheet[y0:y0 + h * k, px_:px_ + w * k] = (big[..., :3] * a + bg * (1 - a)) * 255.0
    out = np.concatenate([sheet, np.full((height, width, 1), 255.0)], axis=-1)
    path.write_bytes(png_bytes(np.clip(out, 0, 255).astype(np.uint8)))


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--preview", default="", help="pasta para preview_sheet.png (fora de assets/)")
    ap.add_argument("--scale", type=int, default=3, help="escala da folha de revisão")
    args = ap.parse_args()
    out = OUT
    (out / "icons").mkdir(parents=True, exist_ok=True)
    items = []
    for name, (w, h, make) in SPRITES.items():
        img = bleed(make())
        assert img.shape == (h, w, 4), (name, img.shape)
        u8 = to_u8(img)
        (out / name).write_bytes(png_bytes(u8))
        items.append((name[:-4], u8.astype(float) / 255.0))
    tints = load_tints()
    for ship in SHIP_ORDER:
        for n, img in enumerate(ICONS[ship](tints[ship]), start=1):
            assert img.shape == (N, N, 4), ship
            u8 = to_u8(img)
            (out / "icons" / f"power_{ship}_{n}.png").write_bytes(png_bytes(u8))
            items.append((f"{ship}_{n}", u8.astype(float) / 255.0))
    rows = [{"file": path.relative_to(ROOT).as_posix(), "source": SOURCE, "license_id": LICENSE_ID,
             "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}
            for path in sorted(out.rglob("*.png"))]
    index_path = ROOT / "assets" / "asset_index.json"
    index = json.loads(index_path.read_text(encoding="utf-8")) if index_path.exists() else []
    index = [r for r in index if r.get("source") != SOURCE] + rows
    index.sort(key=lambda item: item["file"])
    index_path.write_text(json.dumps(index, indent=1, ensure_ascii=False) + "\n", encoding="utf-8", newline="\n")
    if args.preview:
        sheet_dir = pathlib.Path(args.preview)
        sheet_dir.mkdir(parents=True, exist_ok=True)
        preview(items, sheet_dir / "preview_sheet.png", args.scale)
    print(f"{len(SPRITES)} sprites e {len(SHIP_ORDER) * 3} ícones gerados em {out.relative_to(ROOT).as_posix()}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
