"""Ícones dos pacotes de Pérolas da Loja (scripts/core/iap.gd PEARL_PACKS; shop_screen.gd, aba Pérolas).

Quatro pilhas que crescem com o pacote, para o jogador ler o tamanho antes do número:
  shop/pearls_1.png  três pérolas soltas;
  shop/pearls_2.png  um montinho de seis;
  shop/pearls_3.png  uma vieira aberta cheia de pérolas;
  shop/pearls_4.png  um baú de Atlântida transbordando, com faíscas.
Pérola na mesma cor do ícone da moeda (ListScreen.icon &"pearls": lavanda clara com borda violeta), esferas com luz de
cima à esquerda, brilho especular e sombra de contato. Tudo procedural (numpy, superamostrado SS vezes e reduzido),
sem arte de terceiros: licença do projeto ("atlantis_generated", MIT), registrada em assets/asset_index.json (origem
tools/gen_pearl_packs.py), que o tools/sync_assets.py preserva. Determinístico: mesmos bytes a cada rodada.

Uso (sem -I: o numpy fica no site do usuário): python tools/gen_pearl_packs.py [--preview DIR]
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
SOURCE = "tools/gen_pearl_packs.py"
SIDE = 160
SS = 4
N = SIDE * SS

PEARL = np.array([0.94, 0.91, 1.0])
PEARL_SHADE = np.array([0.55, 0.46, 0.86])
OUTLINE = np.array([0.09, 0.07, 0.16])
LIGHT = np.array([-0.45, -0.6, 0.66])
LIGHT /= np.linalg.norm(LIGHT)

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


def poly_sd(pts: list) -> np.ndarray:
    """Distância com sinal a um polígono (negativa dentro)."""
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


def shadow(img: np.ndarray, cx: float, cy: float, rx: float, ry: float, strength: float = 0.45) -> None:
    d = np.hypot((X - cx) / rx, (Y - cy) / ry)
    over(img, OUTLINE, np.clip(1.0 - d, 0.0, 1.0) ** 1.5 * strength)


def pearl(img: np.ndarray, cx: float, cy: float, r: float) -> None:
    """Esfera de pérola: lavanda clara, sombra violeta embaixo à direita, brilho especular e o contorno escuro."""
    dx, dy = (X - cx) / r, (Y - cy) / r
    rr = dx * dx + dy * dy
    inside = rr < 1.0
    dz = np.sqrt(np.clip(1.0 - rr, 0.0, 1.0))
    lam = np.clip(dx * LIGHT[0] + dy * LIGHT[1] + dz * LIGHT[2], 0.0, 1.0)
    # Nácar: um leve arco-íris rosado e ciano que corre com o ângulo.
    hue = 0.04 * np.sin(np.arctan2(dy, dx) * 2.0 + 1.0)
    base = PEARL_SHADE[None, None, :] + (PEARL - PEARL_SHADE)[None, None, :] * (0.25 + 0.75 * lam)[..., None]
    base[..., 0] += hue
    base[..., 2] -= hue * 0.5
    spec = np.clip(1.0 - np.hypot(dx + 0.38, dy + 0.42) / 0.26, 0.0, 1.0) ** 1.4
    rim = np.clip((np.sqrt(np.clip(rr, 0, 1)) - 0.78) / 0.22, 0.0, 1.0) * np.clip(dx + dy + 0.4, 0.0, 1.0)
    col = base * (1.0 - spec[..., None]) + spec[..., None]
    col = col * (1.0 - 0.3 * rim[..., None]) + np.array([0.75, 0.68, 1.0]) * 0.3 * rim[..., None]
    col = np.clip(col, 0.0, 1.0)
    edge = np.sqrt(rr) * r - r
    over(img, OUTLINE, cov(edge - 0.007))
    over(img, col, cov(edge + 0.003) * inside)


def sparkle(img: np.ndarray, cx: float, cy: float, s: float) -> None:
    """Faísca de quatro pontas (estrela fina)."""
    dx, dy = np.abs(X - cx), np.abs(Y - cy)
    star = np.minimum(dx * 6.0 + dy, dy * 6.0 + dx) - s
    over(img, np.array([1.0, 0.97, 0.88]), cov(star, 1.2))


def tier1() -> np.ndarray:
    img = blank()
    shadow(img, 0.5, 0.74, 0.36, 0.08)
    for cx, cy, r in ((0.36, 0.6, 0.15), (0.64, 0.6, 0.15), (0.5, 0.4, 0.16)):
        pearl(img, cx, cy, r)
    return img


def tier2() -> np.ndarray:
    img = blank()
    shadow(img, 0.5, 0.82, 0.44, 0.09)
    r = 0.115
    rows = [(0.73, [0.26, 0.5, 0.74]), (0.55, [0.38, 0.62]), (0.37, [0.5])]
    for cy, xs in rows:
        for cx in xs:
            pearl(img, cx, cy, r)
    pearl(img, 0.14, 0.79, 0.07)
    pearl(img, 0.87, 0.78, 0.075)
    return img


def scallop(img: np.ndarray, cx: float, cy: float, w: float, h: float, back: bool) -> None:
    """Vieira: leque de costelas rosa-coral com borda ondulada e a charneira embaixo."""
    ang = np.arctan2(cx - X, (cy - Y) if back else (Y - cy))
    dist = np.hypot((X - cx) / w, (Y - cy) / h)
    fan = (np.abs(ang) < 1.25) & ((Y < cy) if back else (Y > cy - 0.02))
    wave = 1.0 + 0.04 * np.cos(ang * 9.0)
    d = (dist - wave) * min(w, h)
    rib = 0.5 + 0.5 * np.cos(ang * 9.0)
    light = np.clip(1.0 - dist * 0.55, 0.0, 1.0)
    top = np.array([1.0, 0.72, 0.78]) if back else np.array([1.0, 0.8, 0.84])
    low = np.array([0.66, 0.3, 0.46]) if back else np.array([0.78, 0.38, 0.52])
    col = low[None, None, :] + (top - low)[None, None, :] * (light * (0.42 + 0.58 * rib ** 2))[..., None]
    if back:
        col *= 0.82
    over(img, OUTLINE, cov(d - 0.008) * fan)
    over(img, col, cov(d) * fan)


def tier3() -> np.ndarray:
    img = blank()
    shadow(img, 0.5, 0.88, 0.46, 0.08)
    scallop(img, 0.5, 0.7, 0.44, 0.52, True)
    for cy, xs, r in ((0.6, [0.3, 0.5, 0.7], 0.105), (0.45, [0.4, 0.6], 0.105), (0.32, [0.5], 0.1)):
        for cx in xs:
            pearl(img, cx, cy, r)
    scallop(img, 0.5, 0.66, 0.46, 0.22, False)
    pearl(img, 0.15, 0.82, 0.07)
    sparkle(img, 0.78, 0.22, 0.03)
    return img


def tier4() -> np.ndarray:
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
    # Pérolas por cima da borda.
    heap = [(0.62, [0.22, 0.4, 0.6, 0.78], 0.1), (0.47, [0.31, 0.5, 0.69], 0.105), (0.33, [0.42, 0.6], 0.1),
            (0.22, [0.5], 0.09)]
    for cy, xs, r in heap:
        for cx in xs:
            pearl(img, cx, cy, r)
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
    # Pérolas que rolaram para fora e as faíscas.
    pearl(img, 0.09, 0.86, 0.065)
    pearl(img, 0.92, 0.84, 0.07)
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
    return {f"pearls_{i + 1}": finish(make()) for i, make in enumerate((tier1, tier2, tier3, tier4))}


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
    print(f"{len(rows)} ícones de pacote de Pérolas em {OUT.relative_to(ROOT)}")
    if "--preview" in sys.argv:
        target = pathlib.Path(sys.argv[sys.argv.index("--preview") + 1])
        target.mkdir(parents=True, exist_ok=True)
        sheet = Image.new("RGBA", (SIDE * 4 + 50, SIDE + 20), (12, 22, 48, 255))
        for i, image in enumerate(built.values()):
            sheet.alpha_composite(image, (10 + i * (SIDE + 10), 10))
        sheet.resize((sheet.width * 2, sheet.height * 2), Image.NEAREST).save(target / "pearl_packs.png")
    return 0


if __name__ == "__main__":
    sys.exit(main())
