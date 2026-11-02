"""Retratos dos personagens (plano mestre 3.2): 96x96 com 3 expressões, derivados do "Cyberpunk Portraits" (CC0).

Fonte: "Cyberpunk Portraits" de Hyptosis (OpenGameArt, CC0), três folhas 4x2 de rostos ilustrados 96x96,
baixadas em c:\\src\\downloads\\assets\\opengameart\\hyptosis-cyberpunk-portraits\\extracted (fora do repositório;
$ATLANTIS_DOWNLOADS troca a raiz). Cada personagem do jogo nasce de um rosto do pacote, refeito por código:

- mare (Iara "Maré" Vasconcelos), folha 1, linha 2, coluna 3: cabelo vermelho vira preto azulado com brilho,
  faixa coral na testa, jaqueta vira o macacão dourado de pilota, gola de pele vira azul-marinho.
- farol (Dr. Tomás "Farol" Okafor), folha 1, linha 1, coluna 2: pele escurecida, tranças quase pretas, óculos
  com reflexo ciano, roupa vira jaleco branco e a mochila verde vira um equipamento de aço.
- duarte (Almirante Hélène Duarte), folha 1, linha 2, coluna 4: cachos grisalhos, quepe naval branco com
  fita escura, pala preta, bordado e emblema dourados, uniforme azul-marinho com dragona dourada.
- thalassa (consciência atlante), folha 1, linha 1, coluna 1: pele de luz violeta, cabelo de água, olhos
  acesos, roupa índigo e o glifo atlante brilhando na testa.
- protocol (Leviathan Protocol), folha 1, linha 2, coluna 2: capacete verde vira grafite com malha hexagonal,
  as lentes azuis e as luzes laranja viram vermelho, uma lente única vermelha no centro do rosto, manto carmim.

Expressões (o rosto muda de verdade, por deformação local suave em volta de boca, sobrancelhas e bochechas):
- calm: o rosto base, com luz de contorno fria na cor da fala.
- alert: sobrancelhas descem e se juntam, cantos da boca caem, luz de alerta vermelho-âmbar e mais contraste.
- smile: cantos da boca sobem, bochechas sobem e apertam os olhos, luz quente.
No Protocolo (máscara sem boca) a lente fala por ele: pequena e fria (calm), aberta e ardendo (alert) e uma
meia-lua virada para cima (smile, o sorriso de uma máquina).

Fundo em gradiente na cor do personagem (a mesma de data/dialogue.json), brilho atrás da cabeça, halo da cor da
fala em volta da silhueta e vinheta; sem moldura (a interface desenha a dela). O contorno escuro da arte fica.
Registra cada arquivo em assets/asset_index.json com a licença hyptosis_cyberpunk_portraits.

Requer numpy (python -m pip install numpy); rode com o Python que o tem:
  python tools/gen_portraits.py [--preview DIR]
--preview grava em DIR uma folha 5x3 (personagem x expressão) ampliada 2x, para revisão visual.
"""
import argparse
import hashlib
import json
import os
import pathlib
import struct
import sys
import zlib

import numpy as np

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "art" / "generated" / "portraits"
DOWNLOADS = pathlib.Path(os.environ.get("ATLANTIS_DOWNLOADS", "C:/src/downloads/assets"))
PACK = DOWNLOADS / "opengameart" / "hyptosis-cyberpunk-portraits" / "extracted"
SOURCE = "tools/gen_portraits.py"
LICENSE_ID = "hyptosis_cyberpunk_portraits"
SIZE = 96
MOODS = ("calm", "alert", "smile")
INK = (20, 14, 24)
YY, XX = np.mgrid[0:SIZE, 0:SIZE].astype(np.float64)


# --- PNG (RGBA 8 bits, sem entrelaçamento: o formato das folhas do pacote) -------------------------------------

def load_png(path: pathlib.Path) -> np.ndarray:
    data = path.read_bytes()
    pos, idat, width, height = 8, b"", 0, 0
    while pos < len(data):
        length = struct.unpack(">I", data[pos:pos + 4])[0]
        kind, body = data[pos + 4:pos + 8], data[pos + 8:pos + 8 + length]
        if kind == b"IHDR":
            width, height, depth, color, _, _, interlace = struct.unpack(">IIBBBBB", body)
            if depth != 8 or color != 6 or interlace != 0:
                raise ValueError(f"{path.name}: só RGBA 8 bits sem entrelaçamento")
        elif kind == b"IDAT":
            idat += body
        pos += 12 + length
    raw = zlib.decompress(idat)
    stride = width * 4
    rows = np.zeros((height, stride), np.int32)
    prev = np.zeros(stride, np.int32)
    for y in range(height):
        kind = raw[y * (stride + 1)]
        line = np.frombuffer(raw, np.uint8, stride, y * (stride + 1) + 1).astype(np.int32)
        if kind == 0:
            cur = line
        elif kind == 2:
            cur = (line + prev) & 255
        else:
            cur = np.zeros(stride, np.int32)
            for i in range(stride):
                a = cur[i - 4] if i >= 4 else 0
                b = prev[i]
                c = prev[i - 4] if i >= 4 else 0
                if kind == 1:
                    p = a
                elif kind == 3:
                    p = (a + b) >> 1
                else:
                    pa, pb, pc = abs(b - c), abs(a - c), abs(a + b - 2 * c)
                    p = a if pa <= pb and pa <= pc else (b if pb <= pc else c)
                cur[i] = (line[i] + p) & 255
        rows[y] = cur
        prev = cur
    return rows.reshape(height, width, 4).astype(np.float64) / 255.0


def png_bytes(img: np.ndarray) -> bytes:
    pixels = np.clip(np.round(img * 255.0), 0, 255).astype(np.uint8)
    height, width = pixels.shape[:2]
    raw = b"".join(b"\x00" + pixels[y].tobytes() for y in range(height))

    def chunk(kind: bytes, body: bytes) -> bytes:
        return struct.pack(">I", len(body)) + kind + body + struct.pack(">I", zlib.crc32(kind + body) & 0xFFFFFFFF)

    header = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    return b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", header) + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")


# --- Máscaras, cor e desenho -------------------------------------------------------------------------------------

def rgb(color) -> np.ndarray:
    return np.array(color[:3], np.float64) / 255.0


def hsv(img: np.ndarray):
    r, g, b = img[..., 0], img[..., 1], img[..., 2]
    hi = img[..., :3].max(-1)
    lo = img[..., :3].min(-1)
    delta = hi - lo
    safe = np.where(delta > 1e-6, delta, 1.0)
    hue = np.where(hi == r, ((g - b) / safe) % 6.0, np.where(hi == g, (b - r) / safe + 2.0, (r - g) / safe + 4.0))
    hue = np.where(delta > 1e-6, hue * 60.0, 0.0)
    sat = np.where(hi > 1e-6, delta / np.where(hi > 1e-6, hi, 1.0), 0.0)
    return hue, sat, hi


def luma(img: np.ndarray) -> np.ndarray:
    return img[..., 0] * 0.299 + img[..., 1] * 0.587 + img[..., 2] * 0.114


def poly(points) -> np.ndarray:
    """Polígono (lista de (x, y)) como máscara booleana, regra par-ímpar pelo centro do pixel."""
    inside = np.zeros((SIZE, SIZE), bool)
    px, py = XX + 0.5, YY + 0.5
    n = len(points)
    for i in range(n):
        x0, y0 = points[i]
        x1, y1 = points[(i + 1) % n]
        if y0 == y1:
            continue
        cross = ((y0 > py) != (y1 > py)) & (px < (x1 - x0) * (py - y0) / (y1 - y0) + x0)
        inside ^= cross
    return inside


def ellipse(cx, cy, rx, ry, angle=0.0) -> np.ndarray:
    """Cobertura suave (0..1) de uma elipse girada, com 1 px de antisserrilhado."""
    c, s = np.cos(angle), np.sin(angle)
    dx, dy = XX + 0.5 - cx, YY + 0.5 - cy
    u, v = (dx * c + dy * s) / rx, (-dx * s + dy * c) / ry
    dist = (np.sqrt(u * u + v * v) - 1.0) * min(rx, ry)
    return np.clip(0.5 - dist, 0.0, 1.0)


def box(cx, cy, hw, hh, angle=0.0) -> np.ndarray:
    c, s = np.cos(angle), np.sin(angle)
    dx, dy = XX + 0.5 - cx, YY + 0.5 - cy
    u, v = dx * c + dy * s, -dx * s + dy * c
    dist = np.maximum(np.abs(u) - hw, np.abs(v) - hh)
    return np.clip(0.5 - dist, 0.0, 1.0)


def capsule(x0, y0, x1, y1, radius) -> np.ndarray:
    px, py = XX + 0.5 - x0, YY + 0.5 - y0
    bx, by = x1 - x0, y1 - y0
    t = np.clip((px * bx + py * by) / max(bx * bx + by * by, 1e-9), 0.0, 1.0)
    dist = np.hypot(px - bx * t, py - by * t) - radius
    return np.clip(0.5 - dist, 0.0, 1.0)


def ring(cx, cy, r, width) -> np.ndarray:
    dist = np.abs(np.hypot(XX + 0.5 - cx, YY + 0.5 - cy) - r) - width * 0.5
    return np.clip(0.5 - dist, 0.0, 1.0)


def blur(a: np.ndarray, passes: int = 3) -> np.ndarray:
    """Desfoque de caixa 3x3 repetido (aproxima um gaussiano), com borda replicada."""
    for _ in range(passes):
        p = np.pad(a, 1, mode="edge")
        a = sum(p[1 + dy:1 + dy + SIZE, 1 + dx:1 + dx + SIZE] for dy in (-1, 0, 1) for dx in (-1, 0, 1)) / 9.0
    return a


def ramp(t: np.ndarray, stops) -> np.ndarray:
    keys = np.linspace(0.0, 1.0, len(stops))
    cols = np.array([rgb(c) for c in stops])
    return np.stack([np.interp(t, keys, cols[:, k]) for k in range(3)], -1)


def recolor(img: np.ndarray, mask: np.ndarray, stops, keep_ink: float = 0.07, spread=(2, 98)) -> None:
    """Troca a cor das áreas da máscara por uma rampa, guiada pela luminância original (mantém volume e traço)."""
    weight = mask.astype(np.float64) * img[..., 3]
    if weight.max() <= 0.0:
        return
    light = luma(img)
    lo, hi = np.percentile(light[weight > 0.5], spread)
    t = np.clip((light - lo) / max(hi - lo, 1e-6), 0.0, 1.0)
    # Tinta (escura e sem cor) fica como está; vermelho escuro, por exemplo, ainda é cor e muda.
    weight = weight * np.clip((img[..., :3].max(-1) - keep_ink) / 0.06, 0.0, 1.0)
    new = ramp(t, stops)
    img[..., :3] = img[..., :3] * (1.0 - weight[..., None]) + new * weight[..., None]


def paint(img: np.ndarray, color, cover: np.ndarray, alpha: float = 1.0) -> None:
    """Pinta por cima (operador "over"), cobrindo também o fundo transparente."""
    a = np.clip(cover * alpha, 0.0, 1.0)[..., None]
    if isinstance(color, np.ndarray) and color.ndim == 3:
        src = color
    else:
        src = rgb(color)
    base_a = img[..., 3:4]
    out_a = a + base_a * (1.0 - a)
    img[..., :3] = (src * a + img[..., :3] * base_a * (1.0 - a)) / np.maximum(out_a, 1e-6)
    img[..., 3:4] = out_a


def glow(img: np.ndarray, color, cover: np.ndarray, strength: float) -> None:
    """Luz somada (modo tela) só onde já há figura."""
    a = np.clip(cover * strength, 0.0, 1.0)[..., None] * img[..., 3:4]
    img[..., :3] = 1.0 - (1.0 - img[..., :3]) * (1.0 - rgb(color) * a)


def shaped(img: np.ndarray, cover: np.ndarray, stops, outline: bool = True, shade=None) -> None:
    """Forma desenhada por código com contorno de tinta e sombreado em rampa (shade: 0..1 por pixel)."""
    if outline:
        paint(img, INK, np.clip(blur(cover, 1) * 2.2, 0.0, 1.0))
    t = shade if shade is not None else np.clip(1.0 - (YY - YY[cover > 0.5].min()) / 12.0, 0.0, 1.0) \
        if (cover > 0.5).any() else np.zeros_like(cover)
    paint(img, ramp(t, stops), cover)


def sample(img: np.ndarray, sx: np.ndarray, sy: np.ndarray) -> np.ndarray:
    """Leitura bilinear com alfa pré-multiplicado (sem halo escuro nas bordas)."""
    pre = img.copy()
    pre[..., :3] *= pre[..., 3:4]
    x0 = np.clip(np.floor(sx).astype(int), 0, SIZE - 1)
    y0 = np.clip(np.floor(sy).astype(int), 0, SIZE - 1)
    x1 = np.clip(x0 + 1, 0, SIZE - 1)
    y1 = np.clip(y0 + 1, 0, SIZE - 1)
    fx = np.clip(sx - np.floor(sx), 0.0, 1.0)[..., None]
    fy = np.clip(sy - np.floor(sy), 0.0, 1.0)[..., None]
    out = (pre[y0, x0] * (1 - fx) * (1 - fy) + pre[y0, x1] * fx * (1 - fy)
           + pre[y1, x0] * (1 - fx) * fy + pre[y1, x1] * fx * fy)
    out[..., :3] /= np.maximum(out[..., 3:4], 1e-6)
    return out


def warp(img: np.ndarray, bumps) -> np.ndarray:
    """Deformação local: cada (cx, cy, dx, dy, raio) empurra os pixels em volta de (cx, cy) por (dx, dy)."""
    if not bumps:
        return img
    dx = np.zeros((SIZE, SIZE))
    dy = np.zeros((SIZE, SIZE))
    for cx, cy, mx, my, radius in bumps:
        g = np.exp(-((XX - cx) ** 2 + (YY - cy) ** 2) / (2.0 * radius * radius))
        dx += mx * g
        dy += my * g
    return sample(img, XX - dx, YY - dy)


def shifted_alpha(img: np.ndarray, ox: float, oy: float) -> np.ndarray:
    return sample(img, XX + ox, YY + oy)[..., 3]


def rim(img: np.ndarray, direction, color, strength: float, width: int = 3) -> None:
    """Luz de contorno: acende a borda da silhueta voltada para a luz (a borda do quadro não conta)."""
    n = np.hypot(*direction)
    ux, uy = direction[0] / n, direction[1] / n
    edge = np.zeros((SIZE, SIZE))
    for k in range(1, width + 1):
        outside = 1.0 - shifted_alpha(img, ux * k, uy * k)
        edge = np.maximum(edge, outside * (1.0 - (k - 1) / width))
    glow(img, color, edge, strength)


def contrast(img: np.ndarray, amount: float, pivot: float = 0.45) -> None:
    img[..., :3] = np.clip((img[..., :3] - pivot) * amount + pivot, 0.0, 1.0)


def tint(img: np.ndarray, color, amount: float, cover=None) -> None:
    cover = np.ones((SIZE, SIZE)) if cover is None else cover
    a = (cover * amount)[..., None]
    img[..., :3] = img[..., :3] * (1.0 - a) + img[..., :3] * rgb(color) * 1.25 * a


# --- Rosto e expressões --------------------------------------------------------------------------------------------

def express(img: np.ndarray, face: dict, mood: str) -> np.ndarray:
    """Muda o rosto: cantos da boca, sobrancelhas e bochechas (face: coordenadas no recorte de 96 px)."""
    (lx, ly), (rx, ry) = face["mouth"]
    mid_x = (lx + rx) * 0.5
    span = abs(rx - lx)
    bumps = []
    base = face.get("base", 0.0)  # o desenho original já sorri um pouco (Farol): a calma desfaz isso.
    lift = {"calm": -base, "smile": 2.4 - base, "alert": -1.2 - base}[mood]
    if abs(lift) > 1e-3:
        out = 0.35 if lift > 0 else -0.15
        r = max(1.8, span * 0.22)
        bumps += [(lx, ly, -out, -lift, r), (rx, ry, out, -lift, r)]
        # O lábio de baixo acompanha um pouco: sorriso alarga, alerta aperta.
        bumps.append((mid_x, (ly + ry) * 0.5 + 1.5, 0.0, -lift * 0.25, r * 1.2))
    if mood == "smile":
        for ex, ey in face["eyes"]:
            bumps.append((ex, ey + 3.5, 0.0, -1.2, 2.8))  # bochecha sobe e aperta o olho
    if mood == "alert":
        for inner, outer in face["brows"]:
            toward = 0.8 if inner[0] < outer[0] else -0.8  # sobrancelha interna vai para o centro do rosto
            bumps.append((inner[0], inner[1], -toward, 2.0, 2.4))
            bumps.append((outer[0], outer[1], 0.0, -0.7, 2.4))
    return warp(img, bumps)


def light(img: np.ndarray, mood: str, accent, key=(-1.0, -0.6)) -> None:
    """Luz por expressão: fria e calma, vermelho-âmbar no alerta, quente no sorriso."""
    if mood == "calm":
        rim(img, key, accent, 0.45)
    elif mood == "alert":
        contrast(img, 1.14)
        tint(img, (255, 150, 120), 0.10)
        rim(img, (1.0, -0.25), (255, 96, 52), 0.9, 3)
        rim(img, key, (255, 190, 90), 0.35, 2)
    else:
        warm = np.clip(1.0 - (XX + YY) / 150.0, 0.0, 1.0)
        glow(img, (255, 196, 128), warm, 0.22)
        rim(img, key, (255, 214, 140), 0.65)
        rim(img, (1.0, -0.2), accent, 0.25, 2)


# --- Fundo -------------------------------------------------------------------------------------------------------

def backdrop(top, bottom, accent, mood: str) -> np.ndarray:
    t = YY / (SIZE - 1)
    img = np.ones((SIZE, SIZE, 4))
    img[..., :3] = rgb(top) * (1.0 - t[..., None]) + rgb(bottom) * t[..., None]
    if mood == "alert":
        img[..., :3] = img[..., :3] * 0.78 + rgb((96, 22, 18)) * 0.22 * (1.0 - t[..., None] * 0.6)
    # Raios de luz vindos de cima, como luz do sol atravessando a água.
    for x0, w, k in ((22.0, 7.0, 0.10), (52.0, 11.0, 0.08), (78.0, 6.0, 0.07)):
        d = np.abs((XX - x0) + (YY * 0.35)) - w
        img[..., :3] += rgb(accent) * (np.clip(-d / 4.0, 0.0, 1.0) * k * (1.0 - t))[..., None]
    halo = np.exp(-((XX - 52.0) ** 2 + (YY - 36.0) ** 2) / (2.0 * 26.0 ** 2))
    img[..., :3] += rgb(accent) * (halo * 0.30)[..., None]
    img[..., :3] = np.clip(img[..., :3], 0.0, 1.0)
    return img


def compose(figure: np.ndarray, top, bottom, accent, mood: str) -> np.ndarray:
    out = backdrop(top, bottom, accent, mood)
    a = figure[..., 3]
    # Halo na cor da fala em volta da silhueta: separa a figura do fundo em qualquer tamanho.
    halo = np.clip(blur(a, 4) * 1.6, 0.0, 1.0) * (1.0 - a)
    out[..., :3] += rgb(accent) * (halo * 0.42)[..., None]
    out[..., :3] = figure[..., :3] * a[..., None] + out[..., :3] * (1.0 - a[..., None])
    # Vinheta suave nos cantos.
    r2 = ((XX - 47.5) ** 2 + (YY - 44.0) ** 2) / (58.0 ** 2)
    out[..., :3] *= (1.0 - np.clip(r2 - 0.35, 0.0, 1.0) * 0.55)[..., None]
    out[..., :3] = np.clip(out[..., :3], 0.0, 1.0)
    out[..., 3] = 1.0
    return out


# --- Personagens --------------------------------------------------------------------------------------------------

def tile(sheets: dict, sheet: int, row: int, col: int) -> np.ndarray:
    return sheets[sheet][row * SIZE:(row + 1) * SIZE, col * SIZE:(col + 1) * SIZE].copy()


def mare(src: np.ndarray):
    img = src.copy()
    hue, sat, val = hsv(img)
    mouth = ellipse(48, 51, 7, 4.5) > 0.5
    hair = (((hue < 16) | (hue > 340)) & (sat > 0.55) & (val > 0.18)) & ~mouth
    hair |= (hue < 26) & (sat > 0.7) & (val > 0.5) & (YY < 46)  # mechas alaranjadas sobre o rosto
    recolor(img, hair, [(6, 8, 16), (16, 20, 36), (34, 44, 74), (70, 96, 142), (150, 186, 226)])
    # Faixa coral sobre o cabelo, curvada com a cabeça.
    curve = 14.5 + 0.0045 * (XX - 46.0) ** 2
    band_area = (np.abs(YY - curve) < 2.4) & (XX > 7) & (XX < 82)
    band = hair & band_area
    recolor(img, band, [(120, 30, 30), (220, 78, 66), (255, 128, 104), (255, 196, 170)], keep_ink=0.0)
    edge = band_area & ~(np.abs(YY - curve) < 1.6) & hair
    img[edge, :3] = img[edge, :3] * 0.45 + rgb((90, 20, 26)) * 0.55
    hue, sat, val = hsv(img)
    neck = poly([(30, 56), (56, 56), (58, 72), (46, 80), (30, 74)])
    jacket = (hue > 12) & (hue < 42) & (sat > 0.42) & (YY > 56) & ~neck & ~hair
    recolor(img, jacket, [(64, 40, 8), (150, 104, 24), (226, 178, 62), (255, 228, 140)])
    gear = (hue > 160) & (hue < 210) & (sat > 0.2) & (XX > 62)  # equipamento no ombro: aço frio, sem roubar a cena
    recolor(img, gear, [(10, 14, 22), (34, 44, 58), (76, 92, 110), (150, 170, 188)])
    fur = (hue > 44) & (hue < 90) & (sat > 0.3) & (YY > 55)
    recolor(img, fur, [(8, 14, 30), (22, 36, 66), (44, 70, 112), (96, 132, 176)])
    face = {"mouth": ((43.0, 50.5), (53.0, 50.0)), "eyes": ((38.0, 34.0), (57.5, 36.0)),
            "brows": (((44.0, 30.0), (33.0, 29.5)), ((52.0, 31.5), (62.0, 31.0)))}
    return img, face


def farol(src: np.ndarray):
    img = src.copy()
    hue, sat, val = hsv(img)
    skin = (hue > 14) & (hue < 42) & (sat > 0.25) & (val > 0.55) & (YY < 86) & (XX > 26)
    recolor(img, skin, [(34, 18, 12), (70, 38, 24), (112, 66, 42), (156, 104, 70), (196, 146, 108)], spread=(1, 99))
    hair = (hue < 40) & (sat > 0.35) & (val <= 0.55) & (val > 0.12) & (YY < 84) & ~skin
    recolor(img, hair, [(8, 6, 6), (26, 18, 16), (54, 38, 30), (92, 70, 56)])
    coat = poly([(0, 74), (34, 66), (44, 80), (62, 86), (78, 84), (96, 78), (96, 96), (0, 96)])
    beard = ellipse(67, 80, 7, 5) > 0.3
    cloth = coat & ~skin & ~beard & ~hair | (coat & (YY > 84) & ~beard)
    cloth &= ~((hue > 80) & (hue < 180) & (sat > 0.2))
    recolor(img, cloth, [(58, 66, 82), (140, 150, 166), (210, 218, 228), (246, 248, 252)], keep_ink=0.05)
    pack = (hue > 80) & (hue < 180) & (sat > 0.15)
    recolor(img, pack, [(16, 22, 30), (46, 60, 74), (92, 114, 132), (170, 196, 212)])
    # Óculos: aros finos, lentes com reflexo ciano e a haste até a orelha.
    lenses = [(61.0, 48.5, 7.0, 4.6, 0.04), (82.5, 49.0, 5.6, 4.4, 0.04)]
    for cx, cy, hw, hh, ang in lenses:
        paint(img, INK, ellipse(cx, cy, hw + 1.1, hh + 1.1, ang))
    for cx, cy, hw, hh, ang in lenses:
        lens = ellipse(cx, cy, hw, hh, ang)
        img[..., :3] = img[..., :3] * (1.0 - lens[..., None] * 0.45) + rgb((70, 190, 230)) * lens[..., None] * 0.45
        streak = np.clip(1.0 - np.abs((XX - cx) + (YY - cy) * 0.9 + 1.0) / 1.6, 0.0, 1.0) * lens
        paint(img, (220, 252, 255), streak, 0.85)
        streak2 = np.clip(1.0 - np.abs((XX - cx) + (YY - cy) * 0.9 - 2.6) / 0.8, 0.0, 1.0) * lens
        paint(img, (190, 246, 255), streak2, 0.55)
    paint(img, INK, capsule(68.2, 48.0, 76.6, 48.4, 0.7))
    paint(img, INK, capsule(36.0, 46.5, 53.8, 47.8, 0.6))
    face = {"mouth": ((57.5, 73.0), (76.0, 74.0)), "eyes": ((60.0, 48.0), (82.0, 49.0)),
            "brows": (((67.0, 45.5), (55.0, 44.0)), ((78.0, 44.5), (87.0, 44.0))), "base": 1.2}
    return img, face


def duarte(src: np.ndarray):
    img = src.copy()
    hue, sat, val = hsv(img)
    eyes = (ellipse(43, 45, 5, 3.5) > 0.3) | (ellipse(62, 50, 5, 3.5) > 0.3) | (ellipse(50, 68, 7, 4) > 0.3)
    hair = (((hue < 18) | (hue > 340) | ((hue > 38) & (hue < 70) & (val > 0.6))) & (sat > 0.55) & (val > 0.14)) & ~eyes
    recolor(img, hair, [(26, 26, 32), (84, 86, 96), (150, 152, 162), (206, 208, 214), (244, 244, 248)])
    hue, sat, val = hsv(img)
    shirt = (hue > 165) & (hue < 215) & (sat > 0.3) & (YY > 62)
    recolor(img, shirt, [(6, 10, 24), (16, 26, 54), (32, 50, 92), (66, 94, 146)])
    # Dragona dourada no ombro e galão na gola.
    gold = [(110, 70, 10), (214, 160, 48), (255, 218, 120), (255, 246, 206)]
    pad = box(12.0, 86.5, 11.0, 3.4, -0.32)
    shaped(img, pad, gold, shade=np.clip(1.0 - (YY - 82.0) / 8.0, 0.0, 1.0))
    for k in range(5):
        fx = 3.5 + k * 4.0
        paint(img, (214, 160, 48), capsule(fx, 90.5 + k * 1.3, fx - 0.6, 95.0 + k * 1.3, 0.6))
    paint(img, (230, 182, 70), capsule(24.0, 79.0, 34.0, 73.0, 0.7))
    # Quepe naval: copa branca, fita escura, pala preta com bordado dourado e emblema.
    ang = 0.25
    c, s = np.cos(ang), np.sin(ang)
    up = np.array([s, -c])
    side = np.array([c, s])
    brow_mid = np.array([52.5, 43.0])
    band_c = brow_mid + up * 13.5
    crown_c = band_c + up * 6.0
    visor_c = band_c - up * 3.2 + side * 1.0
    crown = ellipse(*crown_c, 21.0, 7.5, ang)
    band = box(*band_c, 16.5, 3.2, ang)
    visor = ellipse(*visor_c, 17.5, 4.6, ang) * (((XX + 0.5 - band_c[0]) * -up[0] + (YY + 0.5 - band_c[1]) * -up[1]) > 1.0)
    whole = np.maximum(np.maximum(crown, band), visor)
    paint(img, INK, np.clip(blur(whole, 1) * 2.4, 0.0, 1.0))
    crown_shade = np.clip(((XX - crown_c[0]) * up[0] + (YY - crown_c[1]) * up[1]) / 8.0 + 0.5, 0.0, 1.0)
    paint(img, ramp(crown_shade, [(150, 156, 170), (222, 226, 234), (250, 251, 254)]), crown * (1.0 - band))
    paint(img, ramp(crown_shade, [(8, 10, 18), (22, 26, 40)]), band)
    paint(img, (16, 16, 22), visor * (1.0 - band))
    lip = np.clip(1.0 - np.abs(np.hypot((XX + 0.5 - visor_c[0]) / 17.5, (YY + 0.5 - visor_c[1]) / 4.6) - 0.82) * 6.0, 0, 1)
    paint(img, (226, 176, 60), lip * visor * (1.0 - band), 0.9)
    gloss = capsule(*(visor_c + side * -6.0 - up * 1.2), *(visor_c + side * 2.0 - up * 1.6), 0.6) * visor
    paint(img, (120, 126, 150), gloss, 0.7)
    em = band_c + up * 1.2
    paint(img, INK, ellipse(*em, 4.6, 4.0, ang))
    paint(img, ramp(np.clip((YY - em[1] + 3) / 6.0, 0, 1), [(255, 238, 170), (224, 166, 50)]), ellipse(*em, 3.6, 3.0, ang))
    paint(img, (120, 70, 10), capsule(*(em - up * 1.6), *(em + up * 1.6), 0.45))
    paint(img, (120, 70, 10), capsule(*(em - side * 1.2 + up * 0.8), *(em + side * 1.2 + up * 0.8), 0.4))
    face = {"mouth": ((44.0, 67.0), (55.5, 70.0)), "eyes": ((43.0, 45.0), (62.0, 50.0)),
            "brows": (((48.0, 42.0), (39.0, 40.0)), ((57.0, 46.5), (67.0, 47.5)))}
    return img, face


def thalassa(src: np.ndarray):
    img = src.copy()
    hue, sat, val = hsv(img)
    hair = ((hue < 16) | (hue > 340)) & (sat > 0.6) & (val > 0.2)
    recolor(img, hair, [(8, 30, 70), (14, 82, 140), (40, 170, 214), (130, 236, 250), (226, 255, 255)])
    coat = (YY > 76) & (hue > 8) & (hue < 45) & (sat > 0.45) & (val > 0.3) & ~hair
    skin = (hue > 5) & (hue < 45) & ~hair & ~coat & (val > 0.12)
    recolor(img, skin, [(46, 20, 96), (104, 60, 186), (160, 116, 240), (214, 184, 255), (250, 236, 255)],
            keep_ink=0.04, spread=(1, 99.5))
    recolor(img, coat, [(14, 10, 40), (40, 30, 96), (84, 72, 172), (150, 140, 236)])
    # Olhos acesos e o glifo atlante na testa.
    for ex, ey in ((47.0, 45.0), (67.5, 45.0)):
        glow(img, (150, 250, 255), ellipse(ex, ey, 4.5, 2.4), 0.85)
        glow(img, (255, 255, 255), ellipse(ex, ey, 1.6, 1.2), 0.9)
    gx, gy = 57.0, 35.5
    glyph = np.maximum.reduce([
        ring(gx, gy, 2.4, 1.0), capsule(gx, gy - 6.0, gx, gy - 2.6, 0.5), capsule(gx, gy + 2.6, gx, gy + 5.0, 0.5),
        capsule(gx - 3.8, gy - 4.6, gx - 1.8, gy - 2.2, 0.45), capsule(gx + 3.8, gy - 4.6, gx + 1.8, gy - 2.2, 0.45)])
    glow(img, (200, 160, 255), np.clip(blur(glyph, 2) * 2.0, 0, 1), 0.9)
    paint(img, (255, 236, 255), glyph * img[..., 3])
    face = {"mouth": ((52.5, 66.0), (60.0, 67.5)), "eyes": ((47.0, 45.0), (67.5, 45.0)),
            "brows": (((52.0, 41.0), (42.0, 40.0)), ((62.0, 41.0), (72.0, 40.5)))}
    return img, face


def hex_lines(scale: float) -> np.ndarray:
    """Malha hexagonal procedural: 1 nas arestas, 0 no meio das células."""
    px, py = (XX + 0.5) / scale, (YY + 0.5) / scale
    rx, ry = 1.0, 1.7320508
    ax, ay = np.mod(px, rx) - rx * 0.5, np.mod(py, ry) - ry * 0.5
    bx, by = np.mod(px - rx * 0.5, rx) - rx * 0.5, np.mod(py - ry * 0.5, ry) - ry * 0.5
    use_a = ax * ax + ay * ay < bx * bx + by * by
    gx, gy = np.where(use_a, ax, bx), np.where(use_a, ay, by)
    dist = np.maximum(np.abs(gx) * 0.5 + np.abs(gy) * 0.8660254, np.abs(gx))
    return np.clip(1.0 - np.abs(dist - 0.5) * scale / 0.8, 0.0, 1.0)


def protocol(src: np.ndarray):
    img = src.copy()
    hue, sat, val = hsv(img)
    lights = (((hue > 190) & (hue < 260) & (sat > 0.45)) | ((hue > 15) & (hue < 55) & (sat > 0.5) & (YY < 30) & (XX > 15))
              | ((hue > 15) & (hue < 55) & (sat > 0.5) & (ellipse(45, 66, 3, 3) > 0.2)))
    cloak = (hue > 8) & (hue < 45) & (sat > 0.4) & ~lights
    armor = (hue > 45) & (hue < 160) & ~lights
    recolor(img, armor, [(10, 11, 16), (30, 33, 42), (62, 67, 80), (112, 120, 136), (178, 186, 200)])
    recolor(img, cloak, [(18, 4, 8), (50, 10, 18), (98, 20, 30), (150, 40, 46)])
    recolor(img, lights, [(120, 10, 16), (230, 40, 50), (255, 140, 130), (255, 230, 220)], keep_ink=0.0)
    hexes = hex_lines(5.0) * armor
    glow(img, (110, 120, 140), hexes, 0.16)
    tint(img, (255, 80, 80), 0.10, hexes)
    face = {"lens": (70.5, 43.5)}
    return img, face


def protocol_mood(img: np.ndarray, mood: str) -> np.ndarray:
    img = img.copy()
    cx, cy = 70.5, 43.5
    paint(img, INK, ellipse(cx, cy, 7.6, 7.0))
    paint(img, (40, 8, 12), ellipse(cx, cy, 6.6, 6.0))
    if mood == "smile":
        # Meia-lua virada para cima: o sorriso de uma máquina.
        crescent = np.clip(ellipse(cx, cy + 0.5, 5.2, 4.2) - ellipse(cx, cy - 2.2, 5.6, 4.0), 0.0, 1.0)
        glow(img, (255, 60, 60), np.clip(blur(crescent, 3) * 2.5, 0, 1), 0.9)
        paint(img, (255, 120, 110), crescent)
        paint(img, (255, 236, 226), np.clip(ellipse(cx, cy + 2.6, 3.0, 1.0), 0, 1) * crescent)
        return img
    r = 3.0 if mood == "calm" else 5.2
    bloom = ellipse(cx, cy, r + 4.0, r + 4.0)
    glow(img, (255, 40, 50), blur(bloom, 3), 0.55 if mood == "calm" else 0.95)
    paint(img, (190, 20, 34), ellipse(cx, cy, r, r))
    paint(img, (255, 110, 100), ellipse(cx, cy, r * 0.62, r * 0.62))
    paint(img, (255, 240, 232), ellipse(cx - r * 0.18, cy - r * 0.2, r * 0.28, r * 0.28))
    if mood == "alert":
        paint(img, (255, 70, 70), ring(cx, cy, r + 2.6, 0.8), 0.8)
    return img


CHARACTERS = {
    # nome: (folha, linha, coluna, função, fundo em cima, fundo embaixo, cor da fala)
    "mare": (1, 1, 2, mare, (34, 70, 104), (10, 22, 42), (255, 224, 138)),
    "farol": (1, 0, 1, farol, (16, 74, 90), (6, 26, 38), (143, 232, 255)),
    "duarte": (1, 1, 3, duarte, (78, 34, 44), (24, 10, 18), (255, 176, 138)),
    "thalassa": (1, 0, 0, thalassa, (48, 26, 96), (10, 6, 30), (199, 155, 255)),
    "protocol": (1, 1, 1, protocol, (64, 14, 22), (14, 4, 8), (255, 122, 126)),
}


def build(sheets: dict) -> dict:
    out = {}
    for name, (sheet, row, col, dress, top, bottom, accent) in CHARACTERS.items():
        base, face = dress(tile(sheets, sheet, row, col))
        for mood in MOODS:
            if name == "protocol":
                fig = protocol_mood(base, mood)
            else:
                fig = express(base, face, mood)
            light(fig, mood, accent)
            out[(name, mood)] = compose(fig, top, bottom, accent, mood)
    return out


def preview(images: dict, target: pathlib.Path, zoom: int = 2) -> None:
    gap = 4
    cols, rows = len(MOODS), len(CHARACTERS)
    sheet = np.zeros(((SIZE * zoom + gap) * rows + gap, (SIZE * zoom + gap) * cols + gap, 4))
    sheet[..., :3] = rgb((12, 16, 24))
    sheet[..., 3] = 1.0
    for r, name in enumerate(CHARACTERS):
        for c, mood in enumerate(MOODS):
            big = np.repeat(np.repeat(images[(name, mood)], zoom, 0), zoom, 1)
            y = gap + r * (SIZE * zoom + gap)
            x = gap + c * (SIZE * zoom + gap)
            sheet[y:y + SIZE * zoom, x:x + SIZE * zoom] = big
    target.write_bytes(png_bytes(sheet))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--preview", type=pathlib.Path, help="pasta para a folha de revisão 5x3 (2x)")
    args = parser.parse_args()
    names = {1: "Cyber_Faces_001.png"}
    missing = [n for n in names.values() if not (PACK / n).exists()]
    if missing:
        print(f"ERRO: faltam {missing} em {PACK} (baixe o pacote, veja licenses/registry.json)")
        return 1
    sheets = {k: load_png(PACK / n) for k, n in names.items()}
    images = build(sheets)
    OUT.mkdir(parents=True, exist_ok=True)
    rows = []
    for (name, mood), img in images.items():
        target = OUT / f"{name}_{mood}.png"
        target.write_bytes(png_bytes(img))
        rows.append({"file": target.relative_to(ROOT).as_posix(), "source": SOURCE, "license_id": LICENSE_ID,
                     "sha256": hashlib.sha256(target.read_bytes()).hexdigest()})
    index_path = ROOT / "assets" / "asset_index.json"
    index = json.loads(index_path.read_text(encoding="utf-8")) if index_path.exists() else []
    index = [r for r in index if r.get("source") != SOURCE] + rows
    index.sort(key=lambda item: item["file"])
    index_path.write_text(json.dumps(index, indent=1, ensure_ascii=False) + "\n", encoding="utf-8", newline="\n")
    print(f"{len(rows)} retratos gerados em {OUT.relative_to(ROOT)}")
    if args.preview:
        args.preview.mkdir(parents=True, exist_ok=True)
        preview(images, args.preview / "portraits_sheet.png")
        print(f"prévia em {args.preview / 'portraits_sheet.png'}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
