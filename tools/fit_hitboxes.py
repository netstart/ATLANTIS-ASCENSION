"""Mede a arte HD das naves e grava data/hitboxes.json (caixas de colisão da Sim a partir da revisão 5).

Desde a 1.25 as naves são HD pré-renderizadas (assets/art/hd, 2 texels por unidade lógica) e bem maiores que a pixel
art antiga; os raios de data/enemies.json, data/bosses.json e a hitbox de data/ships.json foram afinados para a arte
antiga. Esta ferramenta lê o alfa da base de cada nave do jeito que ela é desenhada (escala de data/enemies.json,
"scale" do chefe, "part_scale" da parte, inimigos e chefes girados em PI) e tira:

  - inimigos, corpo do chefe e partes com sprite: o círculo de dano ("radius") sobre o corpo sólido, generoso para o
    tiro do jogador (cobre HURT_COVER dos pixels do corpo), sem antenas, pernas e asas finas (abertura morfológica
    de THIN unidades) nem brilho (alfa < ALPHA; o corpo do chefe nunca abaixo do "body_radius" da tabela, com que a
    vida da luta foi balanceada); o centro ("offset", relativo à posição da Sim) quando o corpo não
    está no meio do quadro; e o raio de contato ("contact", a nave colide ao encostar) do miolo do casco, menor
    (CONTACT_COVER), na convenção do gênero de perdoar raspões na lateral;
  - naves do jogador: o ponto da hitbox ("offset") na cabine ou no núcleo de cada nave HD, posto de olho na folha
    de revisão (PLAYER_POINT, em unidades na tela; a arte é simétrica, então só a altura muda) e, numa nave nova
    ainda sem ponto, o centro da espinha do casco (pixels sólidos a até SPINE unidades da linha do meio); e o raio ("radius") igual ao de data/ships.json: a arte cresceu de ~48 para 52-60 unidades, mas a
    hitbox do gênero é o ponto do piloto, medido contra as balas, que não mudaram; ampliar o raio deixaria todo o
    jogo mais difícil. Ficam as diferenças entre as naves (pesadas maiores, ágeis menores).

Toda nave de data/ships.json com arte HD entra sozinha (as naves novas só pedem rodar de novo). O que faltar no
arquivo cai no valor antigo na Sim (Hitboxes). Partes sem sprite (tentáculos, olhos, anéis, núcleos) ficam fora.

Uso: python tools/fit_hitboxes.py [--preview DIR]   (numpy e Pillow; --preview grava as folhas com os círculos)
"""
from __future__ import annotations

import json
import math
import pathlib
import sys

import numpy as np
from PIL import Image, ImageDraw

ROOT = pathlib.Path(__file__).resolve().parent.parent
HD = ROOT / "assets" / "art" / "hd"
GENERATED = ROOT / "assets" / "art" / "generated"
OUT = ROOT / "data" / "hitboxes.json"
SPECIAL = {"glyph": "enemies/glyph", "prison_barge": "enemies/prison_barge", "prison_pod": "enemies/prison_pod",
           "protocol_beacon": "enemies/protocol_beacon"}
HD_TEXELS = 2.0
ALPHA = 0.5
# Partes mais finas que isto (unidades lógicas, na tela) não contam como corpo: antenas, pernas, pontas de asa.
THIN = 3.0
SPINE = 3.0
HURT_COVER = 0.85
CONTACT_COVER = 0.5
# Altura do ponto do piloto (unidades, tela, + para baixo), de olho na arte: a cabine quando ela é clara (canopla da
# Falcon, da Manta, do Hippocampus e da Nereid, domo do Atlas, disco do Trident e da Amphitrite, núcleo da Swarm),
# senão o meio do casco entre os reatores (Ram) ou o encontro da canopla com o casco (Ascension).
PLAYER_POINT: dict[str, float] = {
    "falcon": -4.0, "manta": -4.0, "hydra": 0.0, "tempest": 0.0, "trident": -1.0, "atlas": -12.0, "ram": -1.5,
    "swarm": -4.0, "eclipse": 0.0, "nova": 0.0, "titan": 0.0, "ascension": -6.0, "hippocampus": -11.0,
    "nereid": -11.0, "amphitrite": 0.0,
}


def load_list(name: str) -> list[dict]:
    return json.loads((ROOT / "data" / f"{name}.json").read_text(encoding="utf-8"))


def art(sprite: str, player: bool = False) -> tuple[np.ndarray, float] | None:
    """Alfa (0..1) da base e unidades por texel; None sem arte."""
    if player:
        path, texel = HD / "player" / f"{sprite}_base.png", 1.0 / HD_TEXELS
    elif sprite in SPECIAL:
        path, texel = GENERATED / f"{SPECIAL[sprite]}.png", 1.0
    else:
        fleet, _, kind = sprite.partition("_")
        path, texel = HD / fleet / f"{kind}_base.png", 1.0 / HD_TEXELS
    if not path.exists():
        return None
    img = Image.open(path).convert("RGBA")
    side = img.height
    return np.asarray(img, dtype=np.float32)[:side, :side, 3] / 255.0, texel


def erode(mask: np.ndarray, r: int) -> np.ndarray:
    if r <= 0:
        return mask
    pad = np.pad(mask, r)
    out = np.ones_like(mask)
    h, w = mask.shape
    for dy in range(-r, r + 1):
        for dx in range(-r, r + 1):
            if dx * dx + dy * dy <= r * r:
                out &= pad[r + dy:r + dy + h, r + dx:r + dx + w]
    return out


def dilate(mask: np.ndarray, r: int) -> np.ndarray:
    return ~erode(~mask, r)


def body(alpha: np.ndarray, unit: float, thin: float) -> np.ndarray:
    """Corpo sólido: alfa firme sem as partes mais finas que `thin` unidades (abertura com disco)."""
    solid = alpha >= ALPHA
    r = int(round(thin * 0.5 / unit))
    opened = dilate(erode(solid, r), r) & solid
    return opened if opened.sum() >= solid.sum() * 0.25 else solid


def measure(alpha: np.ndarray, texel: float, scale: float, rotate: bool, thin: float = THIN) -> dict:
    """Círculos na tela (unidades lógicas, origem no centro do quadro)."""
    unit = texel * scale
    mask = body(alpha, unit, thin)
    side = alpha.shape[0]
    ys, xs = np.nonzero(mask)
    px = (xs + 0.5 - side * 0.5) * unit
    py = (ys + 0.5 - side * 0.5) * unit
    if rotate:
        px, py = -px, -py
    cx, cy = float(px.mean()), float(py.mean())
    if abs(cx) < 0.75:  # naves simétricas: o centro fica na linha do meio
        cx = 0.0
    d = np.hypot(px - cx, py - cy)
    return {"center": (cx, cy), "hurt": float(np.quantile(d, HURT_COVER)), "contact": float(np.quantile(d, CONTACT_COVER)),
            "mask": mask, "unit": unit}


def spine(alpha: np.ndarray, texel: float) -> float:
    """Centro (altura, unidades) dos pixels sólidos perto da linha do meio: o casco central de uma nave nova."""
    side = alpha.shape[0]
    ys, xs = np.nonzero(alpha >= ALPHA)
    near = np.abs((xs + 0.5 - side * 0.5) * texel) <= SPINE
    return float(((ys[near] + 0.5 - side * 0.5) * texel).mean()) if near.any() else 0.0


def r1(v: float) -> float:
    return round(v * 2.0) / 2.0


def off(c: tuple[float, float]) -> list[float]:
    return [round(c[0], 1) + 0.0, round(c[1], 1) + 0.0]


def fit() -> tuple[dict, list[tuple[str, np.ndarray, float, bool, dict, dict]]]:
    out: dict = {"ships": {}, "enemies": {}, "bosses": {}}
    shots: list = []
    for ship in load_list("ships"):
        sid = ship["id"]
        a = art(sid, player=True)
        if a is None:
            continue
        y = PLAYER_POINT[sid] if sid in PLAYER_POINT else spine(a[0], a[1])
        entry = {"radius": float(ship.get("hitbox", 3.0)), "offset": off((0.0, y))}
        out["ships"][sid] = entry
        shots.append((f"ship {sid}", a[0], a[1], False, entry, {"old": float(ship.get("hitbox", 3.0))}))
    for enemy in load_list("enemies"):
        a = art(enemy["sprite"])
        if a is None:
            continue
        scale = float(enemy.get("scale", 1.0))
        m = measure(a[0], a[1], scale, True)
        entry = {"radius": r1(m["hurt"]), "offset": off(m["center"]), "contact": r1(m["contact"])}
        out["enemies"][enemy["id"]] = entry
        shots.append((f"enemy {enemy['id']}", a[0], a[1] * scale, True, entry,
                      {"old": float(enemy.get("radius", 12.0)), "old_contact": float(enemy.get("radius", 12.0)) * 0.6}))
    for boss in load_list("bosses"):
        a = art(boss.get("sprite", ""))
        if a is None:
            continue
        scale = float(boss.get("scale", 1.0))
        m = measure(a[0], a[1], scale, True)
        # Corpo do chefe nunca menor que o "body_radius" da tabela: a vida de cada luta foi balanceada com ele, e nas
        # fragatas a 1,5x (Rainha do Gelo, Albatroz de Aço, Pescador Abissal) a arte HD é mais estreita que ele.
        hurt = max(r1(m["hurt"]), float(boss.get("body_radius", 30.0)))
        entry = {"radius": hurt, "offset": off(m["center"]), "contact": r1(m["contact"]), "parts": {}}
        shots.append((f"boss {boss['id']}", a[0], a[1] * scale, True, entry,
                      {"old": float(boss.get("body_radius", 30.0)), "old_contact": float(boss.get("body_radius", 30.0)) * 0.6}))
        for part in boss.get("parts", []):
            if "sprite" not in part:
                continue
            pa = art(part["sprite"])
            if pa is None:
                continue
            ps = float(part.get("part_scale", 1.0))
            pm = measure(pa[0], pa[1], ps, True)
            pe = {"radius": r1(pm["hurt"]), "offset": off(pm["center"])}
            entry["parts"][part["id"]] = pe
            shots.append((f"part {boss['id']}.{part['id']}", pa[0], pa[1] * ps, True, pe,
                          {"old": float(part.get("radius", 10.0))}))
        if not entry["parts"]:
            del entry["parts"]
        out["bosses"][boss["id"]] = entry
    return out, shots


def write(data: dict) -> None:
    lines = ["{", '\t"_doc": "Gerado por tools/fit_hitboxes.py (não edite à mão). Caixas de colisão medidas na arte HD, '
             'unidades lógicas na tela; offset relativo à posição da Sim. Lido por scripts/sim/hitboxes.gd na revisão 5+.",']
    groups = list(data.items())
    for gi, (group, rows) in enumerate(groups):
        lines.append(f'\t"{group}": {{')
        items = list(rows.items())
        for i, (key, row) in enumerate(items):
            comma = "," if i < len(items) - 1 else ""
            lines.append(f'\t\t"{key}": {json.dumps(row, ensure_ascii=False)}{comma}')
        lines.append("\t}" + ("," if gi < len(groups) - 1 else ""))
    lines.append("}")
    OUT.write_text("\n".join(lines) + "\n", encoding="utf-8", newline="\n")


def preview(shots: list, folder: pathlib.Path) -> None:
    """Folhas de revisão: cada nave como é desenhada (4 px por unidade), corpo medido em verde, círculo de dano em
    ciano, contato em laranja, antigo em vermelho tracejado e o ponto do piloto em branco."""
    folder.mkdir(parents=True, exist_ok=True)
    zoom = 4.0
    cell = 300
    cols = 6
    for page in range(0, len(shots), cols * 4):
        chunk = shots[page:page + cols * 4]
        rows = (len(chunk) + cols - 1) // cols
        sheet = Image.new("RGB", (cols * cell, rows * (cell + 16)), (18, 26, 40))
        draw = ImageDraw.Draw(sheet)
        for k, (name, alpha, unit, rotate, entry, old) in enumerate(chunk):
            ox, oy = (k % cols) * cell, (k // cols) * (cell + 16)
            side = alpha.shape[0]
            px = max(1, int(round(side * unit * zoom)))
            fit_zoom = min(1.0, (cell - 8) / px)
            z = zoom * fit_zoom
            a = Image.fromarray((alpha * 255).astype(np.uint8))
            if rotate:
                a = a.rotate(180)
            size = max(1, int(round(side * unit * z)))
            a = a.resize((size, size), Image.BILINEAR)
            gray = Image.new("RGB", (size, size), (150, 160, 175))
            cx0, cy0 = ox + cell // 2, oy + cell // 2
            sheet.paste(gray, (cx0 - size // 2, cy0 - size // 2), a)

            def ring(r: float, c: tuple[int, int, int], at: tuple[float, float] = (0.0, 0.0), w: int = 2) -> None:
                x, y = cx0 + at[0] * z, cy0 + at[1] * z
                draw.ellipse([x - r * z, y - r * z, x + r * z, y + r * z], outline=c, width=w)

            o = tuple(entry.get("offset", [0.0, 0.0]))
            ring(old["old"], (230, 70, 70), w=1)
            if name.startswith("ship"):
                x, y = cx0 + o[0] * z, cy0 + o[1] * z
                draw.rectangle([x - 2.5 * z, y - 2.5 * z, x + 2.5 * z, y + 2.5 * z], outline=(10, 10, 10), width=2)
                ring(entry["radius"], (255, 255, 255), o)
            else:
                ring(entry["radius"], (80, 240, 255), o)
                if "contact" in entry:
                    ring(entry["contact"], (255, 160, 60), o)
            label = f"{name}  {old['old']:g}->{entry['radius']:g}"
            draw.text((ox + 4, oy + cell + 2), label, fill=(230, 230, 230))
        sheet.save(folder / f"hitboxes_{page // (cols * 4) + 1:02d}.png")


def main() -> int:
    data, shots = fit()
    write(data)
    print(f"{OUT.relative_to(ROOT)}: {len(data['ships'])} naves, {len(data['enemies'])} inimigos, "
          f"{len(data['bosses'])} chefes")
    if "--preview" in sys.argv:
        i = sys.argv.index("--preview")
        preview(shots, pathlib.Path(sys.argv[i + 1]))
    return 0


if __name__ == "__main__":
    sys.exit(main())
