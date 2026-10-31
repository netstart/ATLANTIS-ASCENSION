"""Retratos dos personagens (plano mestre 3.2): 64x64 com 3 expressões, arte própria do projeto (MIT).

Desenho em grade de 32 ampliada x2 sem filtro, no mesmo pixel grosso das naves. Cada personagem tem moldura e
fundo na cor da sua fala (data/dialogue.json), para o jogador saber quem fala antes de ler:
- mare (Iara "Maré" Vasconcelos): pilota, cabelo preto longo, faixa coral, macacão dourado.
- farol (Dr. Tomás "Farol" Okafor): óculos com reflexo ciano, jaleco branco.
- duarte (Almirante Hélène Duarte): quepe naval, coque grisalho, dragonas douradas.
- thalassa: consciência atlante, rosto de luz violeta, cabelo de água e glifo na testa.
- protocol (Leviathan Protocol): máscara hexagonal com uma lente vermelha e linhas de varredura.
Expressões: calm, alert, smile. Registra cada arquivo em assets/asset_index.json (licença atlantis_generated).
Uso: python -I tools/gen_portraits.py
"""
import hashlib
import importlib.util
import json
import math
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "art" / "generated" / "portraits"
SOURCE = "tools/gen_portraits.py"
LICENSE_ID = "atlantis_generated"
N = 32
CLEAR = (0, 0, 0, 0)
INK = (18, 14, 22, 255)
MOODS = ("calm", "alert", "smile")


def _sprites_module():
    spec = importlib.util.spec_from_file_location("gen_sprites", ROOT / "tools" / "gen_sprites.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class Grid:
    def __init__(self):
        self.px = [CLEAR] * (N * N)

    def put(self, x, y, c):
        if 0 <= x < N and 0 <= y < N:
            self.px[y * N + x] = c if len(c) == 4 else (*c, 255)

    def get(self, x, y):
        return self.px[y * N + x] if 0 <= x < N and 0 <= y < N else CLEAR

    def rect(self, x0, y0, x1, y1, c):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.put(x, y, c)

    def ellipse(self, cx, cy, rx, ry, c, shade=None, light_dir=-1):
        for y in range(N):
            for x in range(N):
                u = (x - cx) / rx
                v = (y - cy) / ry
                if u * u + v * v <= 1.0:
                    # Sombra no lado oposto à luz (luz do alto à esquerda).
                    edge = shade is not None and u * -light_dir > 0.45 and u * u + v * v > 0.5
                    self.put(x, y, shade if edge else c)

    def outline(self, inside):
        """Contorno escuro de 1 px em volta da figura (o que não é fundo)."""
        marks = []
        for y in range(N):
            for x in range(N):
                if self.get(x, y) == CLEAR or not inside(x, y):
                    continue
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    if self.get(x + dx, y + dy) == CLEAR and inside(x + dx, y + dy):
                        marks.append((x + dx, y + dy))
        for x, y in marks:
            self.put(x, y, INK)


def frame(g, bg_top, bg_bottom, border):
    """Painel com cantos chanfrados, gradiente em faixas e borda na cor do personagem."""
    for y in range(N):
        k = round(y / (N - 1) * 4) / 4
        c = tuple(round(bg_top[i] + (bg_bottom[i] - bg_top[i]) * k) for i in range(3))
        for x in range(N):
            corner = min(x, N - 1 - x) + min(y, N - 1 - y)
            if corner >= 2:
                g.put(x, y, (*c, 255))
    for y in range(N):
        for x in range(N):
            corner = min(x, N - 1 - x) + min(y, N - 1 - y)
            edge = x in (0, N - 1) or y in (0, N - 1) or corner == 2
            if edge and corner >= 2:
                g.put(x, y, border)


def figure(draw):
    """Desenha a figura numa camada transparente e devolve a grade (para contornar só a figura)."""
    g = Grid()
    draw(g)
    g.outline(lambda x, y: 1 <= x < N - 1 and 1 <= y < N - 1)
    return g


def paste(base, top):
    for i, c in enumerate(top.px):
        if c[3] > 0:
            base.px[i] = c


def human_face(g, skin, shade, mood, eye=(250, 250, 255), iris=INK, brow=INK, lips=(120, 50, 50)):
    g.rect(13, 20, 18, 24, shade)
    g.ellipse(15.5, 13.5, 7.0, 8.2, skin, shade)
    # Olhos: alerta abre mais e baixa as sobrancelhas; sorriso aperta os olhos.
    for ex in (12, 18):
        if mood == "smile":
            g.put(ex, 13, iris)
            g.put(ex + 1, 13, iris)
            g.put(ex - 1, 14, shade)
            g.put(ex + 2, 14, shade)
        else:
            g.put(ex, 13, eye)
            g.put(ex + 1, 13, iris)
            if mood == "alert":
                g.put(ex, 12, eye)
                g.put(ex + 1, 12, eye)
    by = 10 if mood == "alert" else 11
    g.rect(11, by, 13, by, brow)
    g.rect(18, by, 20, by, brow)
    if mood == "alert":
        g.put(13, by + 1, brow)
        g.put(18, by + 1, brow)
    g.put(15, 15, shade)
    g.put(15, 16, shade)
    if mood == "calm":
        g.rect(14, 18, 16, 18, lips)
    elif mood == "alert":
        g.rect(14, 18, 16, 19, INK)
        g.rect(15, 18, 15, 18, lips)
    else:
        g.rect(14, 18, 16, 18, lips)
        g.put(13, 17, lips)
        g.put(17, 17, lips)
    g.put(9, 14, shade)
    g.put(22, 14, shade)


def mare(mood):
    def draw(g):
        hair, hair_hi = (32, 24, 34), (70, 52, 74)
        suit, suit_dark = (222, 160, 64), (160, 104, 30)
        g.rect(4, 25, 27, 31, suit)
        g.rect(4, 25, 7, 31, suit_dark)
        g.rect(12, 24, 19, 26, (240, 236, 220))
        g.rect(15, 26, 16, 31, suit_dark)
        g.rect(7, 13, 10, 27, hair)
        g.rect(21, 13, 24, 27, hair)
        human_face(g, (184, 122, 84), (142, 88, 60), mood)
        g.ellipse(15.5, 8.0, 8.4, 4.6, hair)
        g.rect(8, 7, 23, 9, hair)
        for x in range(10, 21, 3):
            g.put(x, 10, hair)
            g.put(x + 1, 10, hair)
        g.rect(9, 6, 22, 6, (255, 96, 100))
        g.put(12, 5, hair_hi)
        g.put(13, 5, hair_hi)
    g = Grid()
    frame(g, (30, 64, 96), (12, 26, 46), (255, 224, 138, 255))
    paste(g, figure(draw))
    return g.px


def farol(mood):
    def draw(g):
        coat, coat_dark = (232, 238, 244), (170, 184, 198)
        g.rect(4, 25, 27, 31, coat)
        g.rect(4, 25, 6, 31, coat_dark)
        g.rect(13, 24, 18, 31, (40, 70, 96))
        g.rect(20, 27, 22, 28, (63, 243, 255))
        human_face(g, (110, 72, 52), (82, 52, 38), mood, lips=(80, 40, 36))
        g.ellipse(15.5, 7.5, 7.6, 3.6, (26, 22, 26))
        g.rect(9, 7, 22, 8, (26, 22, 26))
        # Óculos: aro escuro e lente com reflexo ciano.
        for ex in (11, 17):
            g.rect(ex, 12, ex + 3, 12, INK)
            g.rect(ex, 14, ex + 3, 14, INK)
            g.put(ex, 13, INK)
            g.put(ex + 3, 13, INK)
        g.put(15, 13, INK)
        g.put(16, 13, INK)
        g.put(12, 13, (120, 240, 255))
        g.put(18, 13, (120, 240, 255))
    g = Grid()
    frame(g, (16, 70, 84), (8, 30, 40), (143, 232, 255, 255))
    paste(g, figure(draw))
    return g.px


def duarte(mood):
    def draw(g):
        navy, navy_dark = (34, 44, 86), (20, 26, 54)
        gold = (232, 184, 74)
        g.rect(4, 25, 27, 31, navy)
        g.rect(4, 25, 6, 31, navy_dark)
        g.rect(4, 25, 9, 26, gold)
        g.rect(22, 25, 27, 26, gold)
        g.rect(14, 24, 17, 31, (236, 236, 240))
        g.rect(15, 26, 16, 31, navy_dark)
        human_face(g, (236, 204, 182), (202, 164, 142), mood, brow=(150, 152, 164), lips=(170, 90, 90))
        g.rect(8, 10, 9, 17, (184, 188, 200))
        g.rect(22, 10, 23, 17, (184, 188, 200))
        g.ellipse(25.0, 13.0, 2.6, 2.6, (170, 174, 188))
        # Quepe: copa azul, faixa e emblema dourados, pala escura.
        g.ellipse(15.5, 5.5, 9.0, 3.4, navy)
        g.rect(7, 6, 24, 8, navy)
        g.rect(7, 8, 24, 8, gold)
        g.put(15, 5, gold)
        g.put(16, 5, gold)
        g.rect(8, 9, 23, 9, (14, 16, 26))
    g = Grid()
    frame(g, (70, 30, 40), (30, 12, 20), (255, 176, 138, 255))
    paste(g, figure(draw))
    return g.px


def thalassa(mood):
    def draw(g):
        glow, mid, deep = (226, 206, 255), (168, 128, 246), (104, 66, 196)
        # Corpo de luz: ombros em faixas que escurecem para baixo, com fagulhas.
        for y in range(23, 32):
            half = min(11, 5 + (y - 23) * 2)
            for x in range(16 - half, 16 + half):
                g.put(x, y, mid if y < 27 else deep)
        for x, y in ((9, 28), (13, 30), (20, 27), (23, 30), (17, 29)):
            g.put(x, y, glow)
        for k, x0 in enumerate((6, 8, 22, 24)):
            for y in range(6, 24):
                g.put(x0 + round(math.sin(y * 0.6 + k) * 1.2), y, (110, 220, 255) if y % 4 else (63, 243, 255))
        g.ellipse(15.5, 13.5, 6.8, 8.2, mid, deep)
        g.ellipse(14.5, 12.5, 3.6, 4.4, glow)
        eye = (255, 255, 255) if mood == "alert" else (170, 250, 255)
        for ex in (12, 18):
            g.rect(ex, 13, ex + 1, 13, eye)
            if mood == "alert":
                g.rect(ex, 12, ex + 1, 12, eye)
            if mood == "smile":
                g.put(ex, 12, deep)
                g.put(ex + 1, 12, deep)
        if mood == "smile":
            g.rect(14, 18, 16, 18, glow)
            g.put(13, 17, glow)
            g.put(17, 17, glow)
        elif mood == "alert":
            g.rect(15, 18, 16, 19, deep)
        for x, y in ((15, 7), (16, 7), (15, 8), (14, 9), (17, 9)):
            g.put(x, y, (255, 214, 92))
    g = Grid()
    frame(g, (40, 24, 80), (12, 8, 34), (199, 155, 255, 255))
    paste(g, figure(draw))
    return g.px


def protocol(mood):
    def draw(g):
        shell, shell_dark, steel = (52, 52, 64), (30, 30, 40), (96, 98, 112)
        g.rect(5, 25, 26, 31, shell_dark)
        for x in range(6, 26, 4):
            g.rect(x, 26, x + 1, 31, steel)
        for y in range(4, 25):
            half = 9 - max(0, abs(y - 14) - 5)
            g.rect(16 - half, y, 15 + half, y, shell)
        g.rect(7, 13, 24, 15, shell_dark)
        g.rect(15, 1, 16, 4, steel)
        g.put(15, 1, (255, 90, 95))
        red, hot = (220, 30, 50), (255, 150, 140)
        radius = {"calm": 2.4, "alert": 4.2, "smile": 3.0}[mood]
        for y in range(N):
            for x in range(N):
                d = math.hypot(x - 15.5, y - 14.0)
                if mood == "smile" and abs(y - 14) > 1:
                    continue
                if d <= radius:
                    g.put(x, y, hot if d < radius * 0.45 else red)
        if mood == "alert":
            for dx, dy in ((-6, 0), (6, 0), (0, -6), (0, 6)):
                g.put(round(15.5 + dx), 14 + dy, (255, 90, 95))
        for y in (7, 19, 21):
            g.rect(9, y, 22, y, shell_dark)
    g = Grid()
    frame(g, (54, 14, 20), (18, 6, 10), (255, 122, 126, 255))
    paste(g, figure(draw))
    # Linhas de varredura sobre tudo (a voz do Protocolo chega por interferência).
    for y in range(2, N - 2, 3):
        for x in range(2, N - 2):
            r, gr, b, a = g.px[y * N + x]
            g.px[y * N + x] = (max(0, r - 18), max(0, gr - 18), max(0, b - 18), a)
    if mood == "smile":
        for y in (16, 17):
            row = g.px[y * N + 2:y * N + N - 2]
            g.px[y * N + 2:y * N + N - 2] = row[2:] + row[:2]
    return g.px


CHARACTERS = {"mare": mare, "farol": farol, "duarte": duarte, "thalassa": thalassa, "protocol": protocol}


def scale2(px):
    out = []
    for y in range(N * 2):
        row = px[(y // 2) * N:(y // 2) * N + N]
        for c in row:
            out.extend([c, c])
    return out


def main() -> int:
    sprites = _sprites_module()
    rows = []
    OUT.mkdir(parents=True, exist_ok=True)
    for name, make in CHARACTERS.items():
        for mood in MOODS:
            target = OUT / f"{name}_{mood}.png"
            pixels = scale2(make(mood))
            assert len(pixels) == 64 * 64
            target.write_bytes(sprites.png(64, 64, pixels))
            rows.append({"file": target.relative_to(ROOT).as_posix(), "source": SOURCE, "license_id": LICENSE_ID,
                         "sha256": hashlib.sha256(target.read_bytes()).hexdigest()})
    index_path = ROOT / "assets" / "asset_index.json"
    index = json.loads(index_path.read_text(encoding="utf-8")) if index_path.exists() else []
    index = [r for r in index if r.get("source") != SOURCE] + rows
    index.sort(key=lambda item: item["file"])
    index_path.write_text(json.dumps(index, indent=1, ensure_ascii=False) + "\n", encoding="utf-8", newline="\n")
    print(f"{len(rows)} retratos gerados em {OUT.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
