"""Gera a arte própria do projeto (MIT) em assets/art/generated/ (plano mestre 8; catálogo, seção 4).

Balas inimigas com contorno escuro e núcleo claro (leitura em qualquer fundo), tiros do jogador,
coletáveis (orbes de arma, medalha, pérola), peças do Kraken Engine e efeitos (faísca, anel, brilho,
feixe). Tudo desenhado aqui pixel a pixel, offline (a regra "nada de laço por pixel em GDScript"
vale para o jogo em tempo de execução, não para esta ferramenta).

Também registra cada arquivo em assets/asset_index.json (licença "atlantis_generated", origem
tools/gen_sprites.py), que o tools/sync_assets.py preserva.
Uso: python -I tools/gen_sprites.py
"""
import hashlib
import json
import math
import pathlib
import struct
import sys
import zlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "art" / "generated"
LICENSE_ID = "atlantis_generated"
SOURCE = "tools/gen_sprites.py"

OUTLINE = (21, 18, 22, 255)
WHITE = (244, 251, 255, 255)
PALETTE = {
    "cyan": ((63, 243, 255), (22, 140, 170)),
    "gold": ((255, 214, 92), (196, 126, 24)),
    "violet": ((196, 120, 255), (112, 52, 190)),
    "coral": ((255, 104, 108), (178, 42, 58)),
    "blue": ((92, 156, 255), (36, 78, 196)),
}


def png(width: int, height: int, pixels: list) -> bytes:
    raw = b"".join(b"\x00" + bytes(c for px in pixels[y * width:(y + 1) * width] for c in px)
                   for y in range(height))

    def chunk(kind: bytes, data: bytes) -> bytes:
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)

    header = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    return b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", header) + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")


def canvas(w: int, h: int) -> list:
    return [(0, 0, 0, 0)] * (w * h)


def orb(size: int, color: str) -> list:
    """Bola com contorno de 1 px, corpo saturado, borda interna escura e núcleo branco."""
    light, dark = PALETTE[color]
    px = canvas(size, size)
    c = (size - 1) / 2.0
    r = size / 2.0
    for y in range(size):
        for x in range(size):
            d = math.hypot(x - c, y - c)
            if d > r - 0.2:
                continue
            if d > r - 1.2:
                px[y * size + x] = OUTLINE
            elif d > r - 2.2:
                px[y * size + x] = (*dark, 255)
            elif d < r * 0.38:
                px[y * size + x] = WHITE
            else:
                px[y * size + x] = (*light, 255)
    return px


def capsule(w: int, h: int, light: tuple, dark: tuple, outline: bool) -> list:
    px = canvas(w, h)
    cx = (w - 1) / 2.0
    for y in range(h):
        for x in range(w):
            # Elipse vertical.
            nx = (x - cx) / (w / 2.0)
            ny = (y - (h - 1) / 2.0) / (h / 2.0)
            d = nx * nx + ny * ny
            if d > 1.0:
                continue
            edge = d > 0.55
            if outline and d > 0.78:
                px[y * w + x] = OUTLINE
            elif edge:
                px[y * w + x] = (*dark, 255)
            elif abs(x - cx) < 0.8:
                px[y * w + x] = WHITE
            else:
                px[y * w + x] = (*light, 255)
    return px


def ring(size: int, thickness: float, color: tuple) -> list:
    px = canvas(size, size)
    c = (size - 1) / 2.0
    r = size / 2.0 - 0.5
    for y in range(size):
        for x in range(size):
            d = math.hypot(x - c, y - c)
            if r - thickness <= d <= r:
                px[y * size + x] = color
    return px


def glow(size: int) -> list:
    px = canvas(size, size)
    c = (size - 1) / 2.0
    for y in range(size):
        for x in range(size):
            d = math.hypot(x - c, y - c) / (size / 2.0)
            if d < 1.0:
                a = int(255 * (1.0 - d) ** 2)
                px[y * size + x] = (255, 255, 255, a)
    return px


def medal(size: int) -> list:
    light, dark = PALETTE["gold"]
    px = orb(size, "gold")
    c = (size - 1) / 2.0
    for y in range(size):
        for x in range(size):
            d = math.hypot(x - c, y - c)
            if size / 2.0 - 3.6 < d < size / 2.0 - 2.6:
                px[y * size + x] = (*dark, 255)
    return px


def pearl(size: int) -> list:
    px = canvas(size, size)
    c = (size - 1) / 2.0
    r = size / 2.0
    for y in range(size):
        for x in range(size):
            d = math.hypot(x - c, y - c)
            if d > r - 0.2:
                continue
            if d > r - 1.2:
                px[y * size + x] = (120, 220, 235, 255)
            elif math.hypot(x - c + 1.2, y - c + 1.2) < r * 0.35:
                px[y * size + x] = WHITE
            else:
                px[y * size + x] = (210, 248, 255, 230)
    return px


def weapon_orb(size: int, color: str, mark: str) -> list:
    """Orbe de arma: anel branco por fora (nunca parece bala) e marca da arma no corpo
    (leque = três pontas para cima, feixe = barra vertical)."""
    light, dark = PALETTE[color]
    px = ring(size, 1.0, WHITE)
    c = (size - 1) / 2.0
    body = size / 2.0 - 3.0
    for y in range(size):
        for x in range(size):
            d = math.hypot(x - c, y - c)
            if d <= body:
                px[y * size + x] = OUTLINE if d > body - 1.0 else (*light, 255)
    m = size // 2
    if mark == "laser":
        for y in range(m - 4, m + 4):
            px[y * size + m] = WHITE
            px[y * size + m - 1] = WHITE
    else:
        for dx, dy in ((-3, -1), (-3, 0), (0, -3), (0, -2), (0, -1), (0, 0), (3, -1), (3, 0),
                       (-2, 1), (-1, 2), (0, 2), (1, 2), (2, 1)):
            px[(m + dy) * size + m + dx] = (*dark, 255) if dy > 0 else WHITE
    return px


def beam(w: int, h: int) -> list:
    """Faixa horizontal com núcleo branco e bordas transparentes (esticada no comprimento do feixe)."""
    px = canvas(w, h)
    for x in range(w):
        t = abs(x - (w - 1) / 2.0) / (w / 2.0)
        a = int(255 * max(0.0, 1.0 - t * t))
        col = WHITE if t < 0.35 else (90, 240, 255)
        for y in range(h):
            px[y * w + x] = (*col[:3], a)
    return px


def glyph(size: int) -> list:
    """Pedra atlante com runa dourada: alvo do segredo de rota (nunca parece bala: quadrado)."""
    px = canvas(size, size)
    gold = (232, 184, 74, 255)
    for y in range(size):
        for x in range(size):
            edge = x in (0, size - 1) or y in (0, size - 1)
            px[y * size + x] = OUTLINE if edge else ((70, 92, 98, 255) if (x + y) % 7 else (58, 78, 84, 255))
    c = size // 2
    for d in range(-5, 6):
        px[(c + d) * size + c] = gold
    for d in range(-3, 4):
        px[(c - 3) * size + c + d] = gold
        px[(c + 3) * size + c + d] = gold
    return px


def capsule_log(size: int) -> list:
    """Cápsula de registro: cristal de dados ciano dentro de moldura dourada."""
    px = canvas(size, size)
    c = (size - 1) / 2.0
    for y in range(size):
        for x in range(size):
            d = abs(x - c) + abs(y - c)
            if d <= c:
                px[y * size + x] = OUTLINE if d > c - 1.2 else ((232, 184, 74, 255) if d > c - 2.6 else (120, 245, 255, 255))
    return px


def rescue_pod(w: int, h: int) -> list:
    """Cápsula de resgate atlante: casco claro em retângulo arredondado, janela ciano e faixa dourada."""
    px = canvas(w, h)
    for y in range(h):
        for x in range(w):
            corner = (x in (0, w - 1)) and (y in (0, 1, h - 2, h - 1))
            if corner:
                continue
            edge = x in (0, w - 1) or y in (0, h - 1)
            if edge:
                px[y * w + x] = OUTLINE
            elif 3 <= y <= 6 and 2 <= x <= w - 3:
                px[y * w + x] = (120, 245, 255, 255)
            elif y == h // 2 + 2:
                px[y * w + x] = (232, 184, 74, 255)
            else:
                px[y * w + x] = (214, 226, 236, 255)
    return px


def tentacle(size: int, tip: bool) -> list:
    """Segmento de tentáculo em metal escuro, sem núcleo claro: nunca se parece com bala."""
    px = canvas(size, size)
    c = (size - 1) / 2.0
    r = size / 2.0
    for y in range(size):
        for x in range(size):
            d = math.hypot(x - c, y - c)
            if d > r - 0.2:
                continue
            if d > r - 1.2:
                px[y * size + x] = OUTLINE
            elif y < c - r * 0.35 and d < r - 2.0:
                px[y * size + x] = (78, 96, 112, 255)
            else:
                px[y * size + x] = (44, 56, 70, 255)
    if tip:
        c = (size - 1) / 2.0
        for y in range(size):
            for x in range(size):
                if math.hypot(x - c, y - c + size * 0.12) < size * 0.16:
                    px[y * size + x] = (*PALETTE["coral"][1], 255)
    return px


# --- Ícone do jogo (plano mestre 11): pixel art em grade de 64, ampliada sem filtro -----------------
# A nave sobe pelo anel dourado do portal atlante, acima das ondas: a "Ascensão" num relance. Fundo em
# faixas do céu claro (alto) ao abismo (baixo). O ícone adaptativo do Android usa o mesmo desenho sem
# fundo, centralizado numa grade de 108 (a zona segura do Android é o círculo central de 66/108).

ICON_GRID = 64
GOLD = (232, 184, 74, 255)
GOLD_DARK = (150, 104, 36, 255)
CYAN = (63, 243, 255, 255)
CORAL = (255, 90, 95, 255)
HULL = (214, 230, 240, 255)
HULL_DARK = (120, 150, 176, 255)


def _blank(n: int) -> list:
    return [(0, 0, 0, 0)] * (n * n)


def icon_background(n: int, rounded: bool) -> list:
    """Faixas do céu ao abismo; cantos arredondados no ícone comum (o adaptativo é recortado pelo sistema)."""
    top, mid, bottom = (34, 98, 150), (11, 42, 77), (4, 11, 26)
    px = _blank(n)
    radius = n * 0.17
    for y in range(n):
        u = y / (n - 1)
        band = round(u * 9) / 9.0
        if band < 0.45:
            k = band / 0.45
            c = tuple(round(top[i] + (mid[i] - top[i]) * k) for i in range(3))
        else:
            k = (band - 0.45) / 0.55
            c = tuple(round(mid[i] + (bottom[i] - mid[i]) * k) for i in range(3))
        for x in range(n):
            if rounded:
                dx = max(radius - x, x - (n - 1 - radius), 0)
                dy = max(radius - y, y - (n - 1 - radius), 0)
                if dx * dx + dy * dy > radius * radius:
                    continue
            px[y * n + x] = (*c, 255)
    return px


def icon_emblem() -> list:
    """Anel do portal, nave subindo, rastro do motor e ondas, em grade de 64 com fundo transparente."""
    n = ICON_GRID
    px = _blank(n)

    def put(x, y, c):
        if 0 <= x < n and 0 <= y < n:
            px[y * n + x] = c

    cx, cy = 31.5, 29.5
    # Anel dourado com sombra interna e 8 marcas de glifo.
    for y in range(n):
        for x in range(n):
            d = math.hypot(x - cx, y - cy)
            if 18.2 <= d < 20.6:
                put(x, y, GOLD)
            elif 17.0 <= d < 18.2:
                put(x, y, GOLD_DARK)
            elif d < 17.0:
                put(x, y, (24, 74, 112, 255) if d < 12.5 else (17, 58, 94, 255))
    for k in range(8):
        a = k * math.pi / 4
        for r in (21.0, 22.0):
            put(round(cx + math.cos(a) * r), round(cy + math.sin(a) * r), GOLD)
    # Ondas na base: duas linhas de espuma em zigue-zague.
    for x in range(6, 58):
        y1 = 50 + (1 if (x // 3) % 2 else 0)
        put(x, y1, CYAN)
        if x % 2 == 0:
            put(x, y1 + 4 - (1 if (x // 4) % 2 else 0), (120, 200, 230, 255))
    # Rastro do motor (coral para dourado) atravessando o anel até as ondas.
    for y in range(41, 50):
        w = 2 if y < 45 else 1
        col = CORAL if y < 44 else (GOLD if y < 47 else (255, 236, 180, 255))
        for x in range(32 - w, 32 + w):
            put(x, y, col)
    # Nave em seta, apontando para cima, com contorno escuro.
    shape = {}
    for y in range(13, 41):
        if y < 22:
            half = (y - 13) // 3 + 1
        elif y < 33:
            half = 4 + (y - 22) // 2 + (2 if y >= 29 else 0)
        else:
            half = 4
        for x in range(32 - half, 32 + half):
            shape[(x, y)] = HULL if x < 32 else HULL_DARK
    for (x, y) in list(shape):
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            if (x + dx, y + dy) not in shape:
                put(x + dx, y + dy, OUTLINE)
    for (x, y), c in shape.items():
        put(x, y, c)
    for y in range(20, 26):
        put(31, y, CYAN)
        put(32, y, CYAN)
    for y in (37, 38, 39):
        put(29, y, CORAL)
        put(34, y, CORAL)
    # Brilhos.
    for x, y in ((12, 10), (52, 14), (9, 34), (55, 40), (46, 6)):
        put(x, y, WHITE)
    return px


def compose(base: list, top: list, n_base: int, n_top: int, ox: int, oy: int) -> list:
    out = list(base)
    for y in range(n_top):
        for x in range(n_top):
            c = top[y * n_top + x]
            if c[3] > 0:
                out[(y + oy) * n_base + x + ox] = c
    return out


def scale(px: list, n: int, k: int) -> list:
    out = []
    for y in range(n * k):
        row = px[(y // k) * n:(y // k) * n + n]
        for c in row:
            out.extend([c] * k)
    return out


def icon_full(size: int) -> list:
    n = ICON_GRID
    return scale(compose(icon_background(n, True), icon_emblem(), n, n, 0, 0), n, size // n)


def icon_adaptive(layer: str) -> list:
    n = 108
    if layer == "background":
        return scale(icon_background(n, False), n, 4)
    return scale(compose(_blank(n), icon_emblem(), n, ICON_GRID, 22, 22), n, 4)


SPRITES = {
    "bullets/orb_cyan_8.png": (8, 8, lambda: orb(8, "cyan")),
    "bullets/orb_cyan_12.png": (12, 12, lambda: orb(12, "cyan")),
    "bullets/orb_gold_12.png": (12, 12, lambda: orb(12, "gold")),
    "bullets/orb_violet_12.png": (12, 12, lambda: orb(12, "violet")),
    "bullets/orb_coral_16.png": (16, 16, lambda: orb(16, "coral")),
    "bullets/needle_gold.png": (5, 14, lambda: capsule(5, 14, PALETTE["gold"][0], PALETTE["gold"][1], True)),
    "bullets/shot_pulsar.png": (4, 12, lambda: capsule(4, 12, (226, 236, 255), (150, 170, 220), False)),
    "bullets/plasma_10.png": (10, 10, lambda: orb(10, "violet")),
    "bullets/plasma_18.png": (18, 18, lambda: orb(18, "violet")),
    "bullets/rail.png": (3, 16, lambda: capsule(3, 16, (255, 236, 220), (255, 140, 110), False)),
    "pickups/orb_plasma.png": (18, 18, lambda: weapon_orb(18, "violet", "pulsar")),
    "pickups/orb_railgun.png": (18, 18, lambda: weapon_orb(18, "coral", "laser")),
    "pickups/log.png": (14, 14, lambda: capsule_log(14)),
    "pickups/capsule.png": (12, 16, lambda: rescue_pod(12, 16)),
    "fx/drone.png": (10, 10, lambda: orb(10, "cyan")),
    "enemies/glyph.png": (20, 20, lambda: glyph(20)),
    "pickups/orb_pulsar.png": (18, 18, lambda: weapon_orb(18, "blue", "pulsar")),
    "pickups/orb_laser.png": (18, 18, lambda: weapon_orb(18, "gold", "laser")),
    "pickups/medal.png": (12, 12, lambda: medal(12)),
    "pickups/pearl.png": (7, 7, lambda: pearl(7)),
    "fx/spark.png": (3, 3, lambda: [WHITE] * 9),
    "fx/ring_32.png": (32, 32, lambda: ring(32, 2.0, WHITE)),
    "fx/ring_128.png": (128, 128, lambda: ring(128, 3.0, WHITE)),
    "fx/glow_32.png": (32, 32, lambda: glow(32)),
    "fx/beam.png": (16, 4, lambda: beam(16, 4)),
    "boss/tentacle_segment.png": (14, 14, lambda: tentacle(14, False)),
    "boss/tentacle_tip.png": (18, 18, lambda: tentacle(18, True)),
    "icon/icon_512.png": (512, 512, lambda: icon_full(512)),
    "icon/icon_192.png": (192, 192, lambda: icon_full(192)),
    "icon/adaptive_foreground_432.png": (432, 432, lambda: icon_adaptive("foreground")),
    "icon/adaptive_background_432.png": (432, 432, lambda: icon_adaptive("background")),
}


def main() -> int:
    rows = []
    for rel, (w, h, make) in SPRITES.items():
        target = OUT / rel
        target.parent.mkdir(parents=True, exist_ok=True)
        pixels = make()
        assert len(pixels) == w * h, rel
        target.write_bytes(png(w, h, pixels))
        rows.append({"file": target.relative_to(ROOT).as_posix(), "source": SOURCE, "license_id": LICENSE_ID,
                     "sha256": hashlib.sha256(target.read_bytes()).hexdigest()})
    index_path = ROOT / "assets" / "asset_index.json"
    index = json.loads(index_path.read_text(encoding="utf-8")) if index_path.exists() else []
    index = [r for r in index if r.get("source") != SOURCE] + rows
    index.sort(key=lambda item: item["file"])
    index_path.write_text(json.dumps(index, indent=1, ensure_ascii=False) + "\n", encoding="utf-8", newline="\n")
    print(f"{len(rows)} sprites gerados em {OUT.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
