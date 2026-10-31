"""Gera a evolução visual da aeronave por nível do hangar (scripts/view/ship_livery.gd) em
assets/art/generated/livery/.

Cada peça é uma camada de 48x48 alinhada pixel a pixel à nave do jogador (Void main_ship/base_full),
lida aqui só para tirar a máscara: faixas, blindagem, runas e friso seguem o contorno real do casco,
e as peças novas (canards, sensor, propulsores, lâminas) encaixam nas juntas dele. A nave é simétrica
em torno de x = 23,5, então cada peça é desenhada no lado esquerdo e espelhada (x → 47 − x).

Três famílias de cor, para a peça funcionar com qualquer tinta ou pintura da loja:
  - estrutura (canards, propulsores): tons do casco original; o jogo tinge com a cor da nave;
  - acento (faixas, runas, lâminas): branco com alfa; o jogo tinge com o acento da nave;
  - metal (blindagem, friso, sensor): cores próprias (oricalco e cristal), nunca tingidas.

Também registra cada arquivo em assets/asset_index.json (licença "atlantis_generated", origem
tools/gen_livery.py), que o tools/sync_assets.py preserva.
Uso: python -I tools/gen_livery.py [--preview DIR]  (--preview grava a nave em cada nível, 8x)
"""
import hashlib
import importlib.util
import json
import pathlib
import struct
import sys
import zlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "art" / "generated" / "livery"
BASE = ROOT / "assets" / "art" / "void" / "main_ship" / "base_full.png"
LICENSE_ID = "atlantis_generated"
SOURCE = "tools/gen_livery.py"
N = 48

OUTLINE = (0, 0, 0, 255)
HULL = (199, 220, 208, 255)
HULL_LIGHT = (255, 255, 255, 255)
HULL_SHADE = (155, 171, 178, 255)
HULL_DARK = (72, 74, 119, 255)
GOLD_LIGHT = (255, 226, 140, 255)
GOLD = (232, 184, 74, 255)
GOLD_DARK = (150, 104, 36, 255)
CRYSTAL = (63, 243, 255, 255)
CRYSTAL_DARK = (22, 140, 170, 255)
WHITE = (255, 255, 255, 255)


def _gen_sprites():
    spec = importlib.util.spec_from_file_location("gen_sprites", ROOT / "tools" / "gen_sprites.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def read_png(path: pathlib.Path) -> list:
    """RGBA 8 bits sem entrelaçamento (o formato dos sprites Void): devolve a lista de pixels."""
    data = path.read_bytes()
    i = 8
    idat = b""
    width = height = 0
    while i < len(data):
        n = struct.unpack(">I", data[i:i + 4])[0]
        kind = data[i + 4:i + 8]
        body = data[i + 8:i + 8 + n]
        i += 12 + n
        if kind == b"IHDR":
            width, height, depth, color = struct.unpack(">IIBB", body[:10])
            assert depth == 8 and color == 6, "base da nave precisa ser RGBA 8 bits"
        elif kind == b"IDAT":
            idat += body
    raw = zlib.decompress(idat)
    stride = width * 4
    prev = bytearray(stride)
    pixels = []
    p = 0
    for _ in range(height):
        f = raw[p]
        line = bytearray(raw[p + 1:p + 1 + stride])
        p += 1 + stride
        for x in range(stride):
            a = line[x - 4] if x >= 4 else 0
            b = prev[x]
            c = prev[x - 4] if x >= 4 else 0
            if f == 1:
                line[x] = (line[x] + a) & 255
            elif f == 2:
                line[x] = (line[x] + b) & 255
            elif f == 3:
                line[x] = (line[x] + (a + b) // 2) & 255
            elif f == 4:
                pp = a + b - c
                pa, pb, pc = abs(pp - a), abs(pp - b), abs(pp - c)
                line[x] = (line[x] + (a if pa <= pb and pa <= pc else b if pb <= pc else c)) & 255
        pixels.extend(tuple(line[x:x + 4]) for x in range(0, stride, 4))
        prev = line
    return pixels


class Hull:
    """Máscara da nave: dentro (alfa), contorno (preto) e miolo (o resto)."""

    def __init__(self, pixels: list):
        self.px = pixels

    def inside(self, x: int, y: int) -> bool:
        return 0 <= x < N and 0 <= y < N and self.px[y * N + x][3] > 40

    def outline(self, x: int, y: int) -> bool:
        return self.inside(x, y) and sum(self.px[y * N + x][:3]) < 60

    def fill(self, x: int, y: int) -> bool:
        return self.inside(x, y) and not self.outline(x, y)

    def edge(self, x: int, y: int) -> bool:
        """Contorno que encosta no vazio (silhueta externa)."""
        return self.outline(x, y) and any(not self.inside(x + dx, y + dy)
                                          for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))


class Layer:
    def __init__(self):
        self.px = [(0, 0, 0, 0)] * (N * N)

    def put(self, x: int, y: int, c: tuple, mirror: bool = True) -> None:
        for xx in ((x, N - 1 - x) if mirror else (x,)):
            if 0 <= xx < N and 0 <= y < N:
                self.px[y * N + xx] = c

    def get(self, x: int, y: int) -> tuple:
        return self.px[y * N + x]

    def outlined(self) -> "Layer":
        """Contorno preto de 1 px em volta do que foi pintado (onde ainda está vazio)."""
        out = Layer()
        out.px = list(self.px)
        for y in range(N):
            for x in range(N):
                if self.px[y * N + x][3] > 0:
                    continue
                if any(0 <= x + dx < N and 0 <= y + dy < N and self.px[(y + dy) * N + x + dx][3] > 0
                       and self.px[(y + dy) * N + x + dx] != OUTLINE
                       for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                    out.px[y * N + x] = OUTLINE
        return out


def left_wing(hull: Hull, x: int, y: int) -> bool:
    return x <= 18 and 20 <= y and hull.fill(x, y)


# --- Peças, na ordem dos níveis ---------------------------------------------------------------

def stripes(hull: Hull) -> Layer:
    """Nível 2: faixa de esquadrão, larga e paralela ao bordo de ataque de cada asa."""
    out = Layer()
    for y in range(N):
        for x in range(24):
            if left_wing(hull, x, y) and (x + y) in (44, 45) and y <= 32:
                out.put(x, y, WHITE)
    return out


def nav_lights(_hull: Hull) -> Layer:
    """Nível 3: as luzes são desenhadas pelo jogo (piscam); a camada só marca as lentes nas pontas."""
    out = Layer()
    out.put(10, 30, (90, 96, 110, 255))
    return out


def canards(_hull: Hull) -> Layer:
    """Nível 4: aletas dianteiras junto ao nariz (estrutura, tingida com a nave; vai por baixo)."""
    out = Layer()
    shape = {14: (19, 19), 15: (17, 19), 16: (16, 19), 17: (15, 17)}
    for y, (x0, x1) in shape.items():
        for x in range(x0, x1 + 1):
            out.put(x, y, HULL_LIGHT if y == 15 and x < 19 else HULL)
    out.put(16, 17, HULL_SHADE)
    out.put(17, 17, HULL_SHADE)
    return out.outlined()


def sensor(_hull: Hull) -> Layer:
    """Nível 5: cristal sensor na ponta do nariz, numa haste curta."""
    out = Layer()
    out.put(23, 10, HULL_SHADE)
    out.put(23, 9, CRYSTAL_DARK)
    out.put(23, 8, CRYSTAL)
    out.put(23, 7, WHITE)
    out.put(23, 6, CRYSTAL)
    out.put(22, 8, CRYSTAL_DARK)
    return out.outlined()


def armor(hull: Hull) -> Layer:
    """Nível 6 (+1 de casco): placas de oricalco no bordo de ataque, com rebites."""
    out = Layer()
    for y in range(20, 31):
        for x in range(24):
            if not left_wing(hull, x, y):
                continue
            # Distância ao bordo de ataque (diagonal de cima, à esquerda): faixa de 2 px, sem tapar a asa.
            if not hull.fill(x - 1, y - 1):
                out.put(x, y, GOLD_LIGHT)
            elif not hull.fill(x - 2, y - 2):
                out.put(x, y, GOLD_DARK)
    for x, y in ((15, 24), (12, 27), (18, 21)):
        if out.get(x, y)[3] > 0:
            out.put(x, y, WHITE)
    return out


def thrusters(_hull: Hull) -> Layer:
    """Nível 7: naceles de propulsão sob as pontas das asas (estrutura; a chama é do jogo)."""
    out = Layer()
    rows = {31: (11, 12), 32: (10, 13), 33: (10, 13), 34: (10, 13), 35: (10, 13), 36: (10, 13), 37: (11, 12)}
    for y, (x0, x1) in rows.items():
        for x in range(x0, x1 + 1):
            if y == 37:
                c = HULL_DARK
            elif x == x0:
                c = HULL_LIGHT
            elif x == x1:
                c = HULL_SHADE
            else:
                c = HULL
            out.put(x, y, c)
    out.put(11, 33, HULL_DARK)
    out.put(12, 33, HULL_DARK)
    return out.outlined()


def runes(hull: Hull) -> Layer:
    """Nível 8: runas atlantes na espinha e um circuito que corre para as asas (acento, pulsa)."""
    out = Layer()
    spine = [21, 22, 24, 26, 27, 29, 31, 32]
    for y in spine:
        if hull.fill(23, y):
            out.put(23, y, WHITE)
    for y in (24, 29):
        out.put(22, y, WHITE)
    for x in range(14, 19):
        if hull.fill(x, 27) and x != 16:
            out.put(x, 27, (255, 255, 255, 200))
    out.put(14, 26, WHITE)
    out.put(14, 28, WHITE)
    return out


def blades(_hull: Hull) -> Layer:
    """Nível 9: lâminas de luz sólida que continuam o bordo de ataque além das pontas (por baixo)."""
    out = Layer()
    for y in range(27, 40):
        lead = 38 - y
        trail = 9 if y < 34 else 9 - (y - 33) // 2
        for x in range(max(1, lead), trail + 1):
            if x > 9:
                continue
            edge = x == max(1, lead) or y == 39
            alpha = 255 if edge else 110 + 10 * (x - lead)
            out.put(x, y, (255, 255, 255, max(60, min(255, alpha))))
    return out


def trim(hull: Hull) -> Layer:
    """Nível 10: friso de ouro na silhueta (o halo e o rastro são do jogo)."""
    out = Layer()
    for y in range(N):
        for x in range(24):
            if hull.edge(x, y):
                out.put(x, y, GOLD if y > 24 else GOLD_LIGHT)
    return out


PARTS = {
    "stripes": stripes, "nav_lights": nav_lights, "canards": canards, "sensor": sensor, "armor": armor,
    "thrusters": thrusters, "runes": runes, "blades": blades, "trim": trim,
}


def preview(layers: dict, base: list, out_dir: pathlib.Path, png) -> None:
    """Nave em cada nível (camadas por baixo e por cima, como o jogo desenha), ampliada 8x."""
    under = ("canards", "thrusters", "blades")
    order = ["stripes", "nav_lights", "canards", "sensor", "armor", "thrusters", "runes", "blades", "trim"]
    accent = (255, 120, 110)
    out_dir.mkdir(parents=True, exist_ok=True)
    strip = []
    for level in range(1, 11):
        parts = order[:level - 1]
        canvas = [(10, 22, 38, 255)] * (N * N)

        def blend(px, tint=None):
            for i, c in enumerate(px):
                if c[3] == 0:
                    continue
                r, g, b = c[:3]
                if tint:
                    r, g, b = r * tint[0] // 255, g * tint[1] // 255, b * tint[2] // 255
                a = c[3] / 255
                d = canvas[i]
                canvas[i] = (int(d[0] + (r - d[0]) * a), int(d[1] + (g - d[1]) * a), int(d[2] + (b - d[2]) * a), 255)
        for p in parts:
            if p in under:
                blend(layers[p], accent if p == "blades" else None)
        blend(base)
        for p in parts:
            if p not in under:
                blend(layers[p], accent if p in ("stripes", "runes") else None)
        strip.append(canvas)
    k = 8
    w = N * k * len(strip)
    rows = []
    for y in range(N * k):
        row = []
        for canvas in strip:
            for x in range(N * k):
                row.append(canvas[(y // k) * N + x // k])
        rows.extend(row)
    (out_dir / "livery_levels.png").write_bytes(png(w, N * k, rows))


def main() -> int:
    gs = _gen_sprites()
    base = read_png(BASE)
    hull = Hull(base)
    OUT.mkdir(parents=True, exist_ok=True)
    rows = []
    layers = {}
    for name, make in PARTS.items():
        layer = make(hull)
        layers[name] = layer.px
        target = OUT / f"{name}.png"
        target.write_bytes(gs.png(N, N, layer.px))
        rows.append({"file": target.relative_to(ROOT).as_posix(), "source": SOURCE, "license_id": LICENSE_ID,
                     "sha256": hashlib.sha256(target.read_bytes()).hexdigest()})
    index_path = ROOT / "assets" / "asset_index.json"
    index = json.loads(index_path.read_text(encoding="utf-8")) if index_path.exists() else []
    index = [r for r in index if r.get("source") != SOURCE] + rows
    index.sort(key=lambda item: item["file"])
    index_path.write_text(json.dumps(index, indent=1, ensure_ascii=False) + "\n", encoding="utf-8", newline="\n")
    if "--preview" in sys.argv:
        preview(layers, base, pathlib.Path(sys.argv[sys.argv.index("--preview") + 1]), gs.png)
    print(f"{len(rows)} peças da evolução geradas em {OUT.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
