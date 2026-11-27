"""Ícones dos pacotes de Créditos (moedas de ouro) da Loja (scripts/core/iap.gd; shop_screen.gd, aba Créditos).

Quatro pilhas que crescem com o pacote, para o jogador ler o tamanho antes do número:
  shop/coins_1.png  três moedas soltas (uma de frente com o tridente, duas inclinadas);
  shop/coins_2.png  um montinho de seis moedas;
  shop/coins_3.png  uma pilha maior de ~dez moedas, com uma faísca;
  shop/coins_4.png  um baú de Atlântida transbordando de ouro, com faíscas.
Moeda igual à do jogo: borda chanfrada, volume (gradiente vertical + oclusão de ambiente), brilho especular nítido e o
TRIDENTE de Atlântida em relevo na face; luz vinda de cima à esquerda. Tudo procedural (numpy, superamostrado SS vezes e
reduzido), sem arte de terceiros: licença do projeto ("atlantis_generated", MIT), registrada em assets/asset_index.json
(origem tools/gen_credit_packs.py), que o tools/sync_assets.py preserva. Determinístico: mesmos bytes a cada rodada.

Mipmaps: na primeira vez rode o Godot com --import para criar os .import e rode este gerador de novo, que liga
mipmaps/generate=true nos .import recém-criados (igual ao tools/gen_pearl_packs.py).

Uso (sem -I: o numpy fica no site do usuário): python tools/gen_credit_packs.py [--preview DIR]
"""
from __future__ import annotations

import hashlib
import json
import math
import pathlib
import sys

import numpy as np
from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "art" / "generated" / "shop"
INDEX = ROOT / "assets" / "asset_index.json"
LICENSE_ID = "atlantis_generated"
SOURCE = "tools/gen_credit_packs.py"
SIDE = 160
SS = 4
N = SIDE * SS


def _rgb(h: str) -> np.ndarray:
    s = h.lstrip("#")
    return np.array([int(s[0:2], 16) / 255.0, int(s[2:4], 16) / 255.0, int(s[4:6], 16) / 255.0], np.float32)


# Paleta da moeda de ouro (idêntica ao protótipo validado coin_proto.py).
GOLD = _rgb("ffc94a")
TOP = _rgb("fff0b0")
MID = _rgb("ffce54")
LOW = _rgb("c07f12")
RIM_HI = _rgb("ffe9a6")
RIM_LO = _rgb("6e4406")
RIM_MID = _rgb("b9790f")
SPEC = _rgb("fffdf2")
EMB_HI = _rgb("fff3cc")
EMB_LO = _rgb("9a6208")
OUTLINE = np.array([0.09, 0.07, 0.05], np.float32)
LDIR = np.array([-0.60, -0.80], np.float32)  # luz de cima à esquerda

_y, _x = np.mgrid[0:N, 0:N].astype(np.float32)
X = (_x + 0.5) / N
Y = (_y + 0.5) / N


def blank() -> np.ndarray:
    return np.zeros((N, N, 4), np.float32)


def over(dst: np.ndarray, rgb, alpha: np.ndarray) -> None:
    """Pinta `rgb` (cor única ou imagem HxWx3) com cobertura `alpha` sobre `dst` (alfa pré-multiplicado não)."""
    a = np.clip(alpha, 0.0, 1.0)[..., None]
    src = np.broadcast_to(np.asarray(rgb, np.float32), dst[..., :3].shape)
    da = dst[..., 3:4]
    oa = a + da * (1.0 - a)
    safe = np.where(oa > 0, oa, 1.0)
    dst[..., :3] = (src * a + dst[..., :3] * da * (1.0 - a)) / safe
    dst[..., 3:4] = oa


def cov(d: np.ndarray, soft: float = 1.0) -> np.ndarray:
    """Cobertura pela distância com sinal (em unidades de 0 a 1), com borda de `soft` pixels finais."""
    return np.clip(0.5 - d * SIDE / soft, 0.0, 1.0)


def cmix(a, b, t):
    """Interpola cores: `a` e `b` podem ser vetor RGB (3,) ou imagem HxWx3; `t` escalar ou HxW."""
    t = np.clip(t, 0.0, 1.0)
    if np.ndim(t) == 2:
        t = t[..., None]
    a = _as_rgb(a)
    b = _as_rgb(b)
    return a * (1.0 - t) + b * t


def _as_rgb(c):
    c = np.asarray(c, np.float32)
    if c.ndim == 1:
        return c[:3][None, None, :]
    return c[..., :3]


def poly_sd(pts: list) -> np.ndarray:
    """Distância com sinal a um polígono em coordenadas globais (negativa dentro)."""
    d = np.full(X.shape, 1e9, np.float32)
    inside = np.zeros(X.shape, bool)
    n = len(pts)
    for i in range(n):
        ax, ay = pts[i]
        bx, by = pts[(i + 1) % n]
        ex, ey = bx - ax, by - ay
        wx, wy = X - ax, Y - ay
        t = np.clip((wx * ex + wy * ey) / (ex * ex + ey * ey), 0.0, 1.0)
        d = np.minimum(d, np.hypot(wx - ex * t, wy - ey * t))
        cross = ((ay > Y) != (by > Y)) & (X < (bx - ax) * (Y - ay) / (by - ay + 1e-9) + ax)
        inside ^= cross
    return np.where(inside, -d, d)


def seg_l(px: np.ndarray, py: np.ndarray, a, b) -> np.ndarray:
    """Distância ao segmento a->b, em coordenadas locais (arrays px, py)."""
    ex, ey = b[0] - a[0], b[1] - a[1]
    l2 = ex * ex + ey * ey
    t = np.clip(((px - a[0]) * ex + (py - a[1]) * ey) / l2, 0.0, 1.0)
    return np.hypot(px - (a[0] + ex * t), py - (a[1] + ey * t))


def poly_l(px: np.ndarray, py: np.ndarray, pts: list) -> np.ndarray:
    """Distância com sinal a um polígono em coordenadas locais (arrays px, py)."""
    d = np.full(px.shape, 1e9, np.float32)
    inside = np.zeros(px.shape, bool)
    n = len(pts)
    for i in range(n):
        ax, ay = pts[i]
        bx, by = pts[(i + 1) % n]
        ex, ey = bx - ax, by - ay
        wx, wy = px - ax, py - ay
        t = np.clip((wx * ex + wy * ey) / (ex * ex + ey * ey), 0.0, 1.0)
        d = np.minimum(d, np.hypot(wx - ex * t, wy - ey * t))
        cross = ((ay > py) != (by > py)) & (px < (bx - ax) * (py - ay) / (by - ay + 1e-9) + ax)
        inside ^= cross
    return np.where(inside, -d, d)


def trident(px: np.ndarray, py: np.ndarray) -> np.ndarray:
    """Tridente de Atlântida (haste + barra + 3 pontas + pé), em coordenadas locais 0..1. Portado do coin_proto.py."""
    shaft = seg_l(px, py, (0.5, 0.30), (0.5, 0.78)) - 0.027
    cross = seg_l(px, py, (0.31, 0.43), (0.69, 0.43)) - 0.025
    pl = seg_l(px, py, (0.31, 0.27), (0.31, 0.45)) - 0.023
    pm = seg_l(px, py, (0.5, 0.25), (0.5, 0.45)) - 0.023
    pr = seg_l(px, py, (0.69, 0.27), (0.69, 0.45)) - 0.023
    foot = seg_l(px, py, (0.40, 0.78), (0.60, 0.78)) - 0.022
    return np.minimum.reduce([shaft, cross, pl, pm, pr, foot])


def coin(img: np.ndarray, cx: float, cy: float, r: float, glint: bool = True) -> None:
    """Moeda de ouro de frente: borda chanfrada, volume, tridente em relevo e brilho especular.

    Porta o coin_pixel do coin_proto.py: o frame local 0..1 (raio externo 0.47) é mapeado para uma moeda centrada em
    (cx, cy) com raio externo `r`. A escala s converte distâncias locais em globais para a antisserrilha ficar certa.
    """
    s = r / 0.47
    px = (X - cx) / s + 0.5
    py = (Y - cy) / s + 0.5
    dc = np.hypot(px - 0.5, py - 0.5)
    nx, ny = px - 0.5, py - 0.5
    nl = np.hypot(nx, ny)
    nls = np.where(nl > 1e-5, nl, 1.0)
    lit = np.where(nl > 1e-5, (nx / nls) * LDIR[0] + (ny / nls) * LDIR[1], 0.0)

    def lc(dl: np.ndarray, soft: float = 1.0) -> np.ndarray:
        return cov(dl * s, soft)

    # 1) Anel da borda chanfrada.
    rim = cmix(RIM_MID, RIM_HI, lit * 0.5 + 0.5)
    rim = cmix(RIM_LO, rim, lit * 0.5 + 0.62)
    ring_d = np.abs(dc - 0.425) - 0.045
    over(img, rim, lc(ring_d))

    # 2) Face com gradiente vertical + volume radial (oclusão de ambiente perto da borda).
    t = np.clip((py - 0.14) / 0.72, 0.0, 1.0)
    fa = cmix(TOP, MID, t / 0.5)
    fb = cmix(MID, LOW, (t - 0.5) / 0.5)
    face = np.where((t < 0.5)[..., None], fa, fb)
    edge = np.clip(dc / 0.385, 0.0, 1.0)
    face = cmix(face, LOW, 0.35 * edge * edge)
    face = np.clip(face + lit[..., None] * np.array([0.10, 0.10, 0.08], np.float32), 0.0, 1.0)
    over(img, face, lc(dc - 0.385))

    # 3) Tridente em relevo (sombra deslocada para baixo-direita, depois o realce).
    face_mask = lc(dc - 0.36)
    sh = trident(px - 0.012, py - 0.014)
    over(img, EMB_LO, lc(sh) * 0.75 * face_mask)
    em = trident(px, py)
    over(img, EMB_HI, lc(em) * 0.95 * face_mask)

    # 4) Brilho especular nítido (cima-esquerda), preso à face.
    sp = np.hypot(px - 0.35, (py - 0.32) * 1.7) - 0.066
    over(img, SPEC, lc(sp) * 0.85 * lc(dc - 0.37))

    # 5) Faísca (estrela fina de quatro pontas) sobre o realce.
    if glint:
        star = poly_l(px, py, [(0.345, 0.205), (0.365, 0.285), (0.44, 0.31), (0.365, 0.335),
                               (0.345, 0.415), (0.325, 0.335), (0.25, 0.31), (0.325, 0.285)])
        over(img, SPEC, lc(star))


def edisc(cx: float, cy: float, rx: float, ry: float) -> np.ndarray:
    """Distância aproximada (com sinal) a uma elipse, em unidades globais."""
    dn = np.hypot((X - cx) / rx, (Y - cy) / ry)
    return (dn - 1.0) * min(rx, ry)


def coin_disc(img: np.ndarray, cx: float, cy: float, rx: float, ry: float, thick: float = 0.03) -> None:
    """Moeda inclinada/de lado: elipse de ouro com espessura (borda do cilindro) e sem tridente, para empilhar."""
    # Lado do cilindro: elipse deslocada para baixo, em ouro escuro com sombreado vertical.
    de = edisc(cx, cy + thick, rx, ry)
    over(img, OUTLINE, cov(de - 0.006))
    sv = np.clip((Y - cy) / (ry + thick + 1e-6), 0.0, 1.0)
    side = cmix(LOW, RIM_LO, 0.45 * sv)
    over(img, side, cov(de))
    # Face de cima: disco elíptico com gradiente vertical.
    df = edisc(cx, cy, rx, ry)
    over(img, OUTLINE, cov(df - 0.006))
    t = np.clip((Y - (cy - ry)) / (2.0 * ry), 0.0, 1.0)
    fa = cmix(TOP, MID, t / 0.5)
    fb = cmix(MID, LOW, (t - 0.5) / 0.5)
    face = np.where((t < 0.5)[..., None], fa, fb)
    over(img, face, cov(df))
    # Anel de borda realçado na face (lado de cima-esquerda).
    nx, ny = (X - cx) / rx, (Y - cy) / ry
    dn = np.hypot(nx, ny)
    ring = np.clip((dn - 0.72) / 0.28, 0.0, 1.0)
    litdir = np.clip(-nx * 0.6 - ny * 0.8, 0.0, 1.0)
    over(img, RIM_HI, cov(df) * ring * litdir * 0.8)
    # Brilho especular suave em cima-esquerda.
    spn = np.hypot(nx + 0.4, ny + 0.5)
    over(img, SPEC, np.clip(1.0 - spn / 0.5, 0.0, 1.0) ** 2 * cov(df) * 0.7)


def shadow(img: np.ndarray, cx: float, cy: float, rx: float, ry: float, strength: float = 0.45) -> None:
    d = np.hypot((X - cx) / rx, (Y - cy) / ry)
    over(img, OUTLINE, np.clip(1.0 - d, 0.0, 1.0) ** 1.5 * strength)


def sparkle(img: np.ndarray, cx: float, cy: float, s: float) -> None:
    """Faísca de quatro pontas (estrela fina)."""
    dx, dy = np.abs(X - cx), np.abs(Y - cy)
    star = np.minimum(dx * 6.0 + dy, dy * 6.0 + dx) - s
    over(img, np.array([1.0, 0.97, 0.88], np.float32), cov(star, 1.2))


def tier1() -> np.ndarray:
    """Três moedas soltas: uma de frente com o tridente, duas inclinadas atrás."""
    img = blank()
    shadow(img, 0.5, 0.74, 0.37, 0.08)
    coin_disc(img, 0.33, 0.6, 0.17, 0.085, 0.04)
    coin_disc(img, 0.67, 0.6, 0.17, 0.085, 0.04)
    coin(img, 0.5, 0.46, 0.18)
    return img


def tier2() -> np.ndarray:
    """Montinho de seis moedas em pirâmide, coroado por uma moeda de frente com o tridente."""
    img = blank()
    shadow(img, 0.5, 0.82, 0.44, 0.09)
    coin_disc(img, 0.3, 0.72, 0.17, 0.07, 0.045)
    coin_disc(img, 0.5, 0.74, 0.17, 0.07, 0.045)
    coin_disc(img, 0.7, 0.72, 0.17, 0.07, 0.045)
    coin_disc(img, 0.4, 0.62, 0.17, 0.07, 0.045)
    coin_disc(img, 0.6, 0.62, 0.17, 0.07, 0.045)
    coin(img, 0.5, 0.47, 0.17)
    return img


def tier3() -> np.ndarray:
    """Pilha maior de ~dez moedas, duas de frente com o tridente, e uma faísca."""
    img = blank()
    shadow(img, 0.5, 0.87, 0.48, 0.08)
    for cx in (0.27, 0.44, 0.62, 0.79):
        coin_disc(img, cx, 0.77, 0.14, 0.062, 0.042)
    for cx in (0.35, 0.53, 0.71):
        coin_disc(img, cx, 0.68, 0.14, 0.062, 0.042)
    coin_disc(img, 0.45, 0.59, 0.14, 0.062, 0.042)
    coin_disc(img, 0.63, 0.59, 0.14, 0.062, 0.042)
    coin(img, 0.68, 0.55, 0.12, glint=False)
    coin(img, 0.47, 0.46, 0.16)
    sparkle(img, 0.82, 0.22, 0.032)
    return img


def tier4() -> np.ndarray:
    """Baú de Atlântida transbordando de moedas de ouro, com faíscas (mesma marcenaria do pacote de Pérolas)."""
    img = blank()
    shadow(img, 0.5, 0.92, 0.5, 0.07, 0.5)
    wood_hi, wood_lo = np.array([0.36, 0.5, 0.78]), np.array([0.12, 0.18, 0.4])
    gold, gold_lo = np.array([1.0, 0.84, 0.42]), np.array([0.72, 0.48, 0.14])
    # Tampa aberta (atrás): trapézio inclinado para trás.
    lid = [(0.16, 0.42), (0.84, 0.42), (0.78, 0.12), (0.22, 0.12)]
    d = poly_sd(lid)
    over(img, OUTLINE, cov(d - 0.01))
    shade = np.clip((Y - 0.12) / 0.3, 0, 1)[..., None]
    over(img, wood_lo + (wood_hi - wood_lo) * (1 - shade) * 0.7, cov(d))
    for bx in (0.33, 0.67):
        band = poly_sd([(bx - 0.035, 0.42), (bx + 0.035, 0.42), (bx + 0.03 - (bx - 0.5) * 0.1, 0.12),
                        (bx - 0.03 - (bx - 0.5) * 0.1, 0.12)])
        over(img, gold_lo, cov(band) * cov(d))
    # Moedas transbordando por cima da borda (a maioria de lado, duas de frente para reconhecer a moeda).
    coin_disc(img, 0.24, 0.62, 0.12, 0.055, 0.04)
    coin_disc(img, 0.42, 0.63, 0.12, 0.055, 0.04)
    coin_disc(img, 0.6, 0.62, 0.12, 0.055, 0.04)
    coin_disc(img, 0.78, 0.62, 0.12, 0.055, 0.04)
    coin_disc(img, 0.33, 0.52, 0.12, 0.055, 0.04)
    coin_disc(img, 0.69, 0.52, 0.12, 0.055, 0.04)
    coin(img, 0.51, 0.52, 0.13, glint=False)
    coin(img, 0.5, 0.37, 0.14)
    # Caixa (frente).
    box = [(0.12, 0.58), (0.88, 0.58), (0.84, 0.9), (0.16, 0.9)]
    d = poly_sd(box)
    over(img, OUTLINE, cov(d - 0.012))
    shade = np.clip((Y - 0.58) / 0.32, 0, 1)[..., None]
    planks = 0.06 * (np.cos((Y - 0.58) / 0.32 * math.pi * 3.0) > 0.92)[..., None]
    over(img, wood_hi - (wood_hi - wood_lo) * shade - planks, cov(d))
    rim = poly_sd([(0.1, 0.56), (0.9, 0.56), (0.89, 0.64), (0.11, 0.64)])
    over(img, OUTLINE, cov(rim - 0.008))
    over(img, gold_lo + (gold - gold_lo) * np.clip(1 - (Y - 0.56) / 0.08, 0, 1)[..., None], cov(rim))
    for bx in (0.3, 0.7):
        band = poly_sd([(bx - 0.04, 0.6), (bx + 0.04, 0.6), (bx + 0.035, 0.9), (bx - 0.035, 0.9)])
        over(img, OUTLINE, cov(band - 0.006) * cov(d))
        over(img, gold_lo + (gold - gold_lo) * np.clip(1 - np.abs(X - bx + 0.015) / 0.04, 0, 1)[..., None],
             cov(band) * cov(d))
    lock = poly_sd([(0.44, 0.62), (0.56, 0.62), (0.56, 0.75), (0.5, 0.79), (0.44, 0.75)])
    over(img, OUTLINE, cov(lock - 0.008))
    over(img, gold, cov(lock))
    over(img, OUTLINE, cov(np.hypot(X - 0.5, Y - 0.69) - 0.018))
    # Moedas que rolaram para fora e as faíscas.
    coin_disc(img, 0.1, 0.86, 0.08, 0.04, 0.03)
    coin(img, 0.9, 0.83, 0.075, glint=False)
    for sx, sy, s in ((0.18, 0.2, 0.035), (0.84, 0.3, 0.03), (0.66, 0.1, 0.022)):
        sparkle(img, sx, sy, s)
    return img


def finish(img: np.ndarray) -> Image.Image:
    """Reduz a superamostragem (média de SS x SS, com o alfa pesando a cor) e devolve o PNG RGBA."""
    a = img[..., 3:4]
    rgb = img[..., :3] * a
    small_rgb = rgb.reshape(SIDE, SS, SIDE, SS, 3).mean(axis=(1, 3))
    small_a = a.reshape(SIDE, SS, SIDE, SS, 1).mean(axis=(1, 3))
    out = np.where(small_a > 0, small_rgb / np.where(small_a > 0, small_a, 1), 0)
    data = np.concatenate([out, small_a], axis=2)
    return Image.fromarray(np.clip(data * 255.0 + 0.5, 0, 255).astype(np.uint8), "RGBA")


def build() -> dict:
    return {f"coins_{i + 1}": finish(make()) for i, make in enumerate((tier1, tier2, tier3, tier4))}


def main() -> int:
    built = build()
    OUT.mkdir(parents=True, exist_ok=True)
    index = json.loads(INDEX.read_text(encoding="utf-8")) if INDEX.exists() else []
    index = [r for r in index if r.get("source") != SOURCE]
    rows = []
    for name, image in built.items():
        target = OUT / f"{name}.png"
        image.save(target, optimize=True)
        imp = target.with_name(target.name + ".import")
        if imp.exists():
            text = imp.read_text(encoding="utf-8")
            if "mipmaps/generate=false" in text:
                imp.write_text(text.replace("mipmaps/generate=false", "mipmaps/generate=true"), encoding="utf-8",
                               newline="\n")
        rows.append({"file": target.relative_to(ROOT).as_posix(), "source": SOURCE, "license_id": LICENSE_ID,
                     "sha256": hashlib.sha256(target.read_bytes()).hexdigest()})
    index = sorted(index + rows, key=lambda item: item["file"])
    INDEX.write_text(json.dumps(index, indent=1, ensure_ascii=False) + "\n", encoding="utf-8", newline="\n")
    print(f"{len(rows)} ícones de pacote de Créditos em {OUT.relative_to(ROOT)}")
    if "--preview" in sys.argv:
        target = pathlib.Path(sys.argv[sys.argv.index("--preview") + 1])
        target.mkdir(parents=True, exist_ok=True)
        sheet = Image.new("RGBA", (SIDE * 4 + 50, SIDE + 20), (12, 22, 48, 255))
        for i, image in enumerate(built.values()):
            sheet.alpha_composite(image, (10 + i * (SIDE + 10), 10))
        sheet.resize((sheet.width * 2, sheet.height * 2), Image.NEAREST).save(target / "credit_packs.png")
    return 0


if __name__ == "__main__":
    sys.exit(main())
