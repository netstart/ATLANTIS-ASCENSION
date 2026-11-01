"""Gera data/stages/*.json (plano mestre 5): missões autorais montadas por "trechos".

Cada missão é uma lista de trechos com duração; o gerador soma os tempos. Trechos de ondas usam o
conjunto de inimigos do capítulo e um gerador pseudoaleatório com semente fixa por missão, então o
JSON gerado é sempre o mesmo. Os momentos de cada missão (Ocean Shift, corrente, vento, raios,
glifos, mini-chefe, chefe, bênçãos, registro) são escritos à mão em MISSIONS.

Uso: python -I tools/gen_missions.py   (escreve data/stages/ e imprime um resumo)
"""
import importlib.util
import json
import pathlib
import random
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "data" / "stages"

# Conjuntos de ondas por capítulo: (inimigo, formação, quantidade, trajetória, parâmetros, extras).
POOLS = {
    1: [
        ("skiff", "line", 5, "straight", {"speed": 74}, {}),
        ("skiff", "column", 6, "sine", {"amp": 34, "freq": 0.5, "speed": 80}, {"interval": 12}),
        ("tide_wasp", "v", 5, "dive", {"side": 1, "amp": 70, "speed": 62}, {"mirror": True, "drop_last": "orb"}),
        ("tide_wasp", "line", 4, "stop_go", {"speed": 70, "stop_y": 140, "hold": 2.5}, {"spacing": 52}),
        ("squid_probe", "line", 3, "stop_go", {"speed": 60, "stop_y": 170, "hold": 2.0}, {"from_depth": True, "spacing": 70}),
        ("sentinel_buoy", "single", 1, "stop_go", {"speed": 40, "stop_y": 100, "hold": 6}, {}),
        ("trawler", "single", 1, "straight", {"speed": 26}, {}),
    ],
    2: [
        ("gold_lance", "line", 4, "stop_go", {"speed": 80, "stop_y": 120, "hold": 2.0}, {"spacing": 54}),
        ("prism_jelly", "line", 3, "sine", {"amp": 40, "freq": 0.25, "speed": 34}, {"spacing": 80}),
        ("coral_turret", "single", 1, "scroll", {"speed": 22}, {"y": -20}),
        ("skiff", "v", 7, "straight", {"speed": 82}, {}),
        ("squid_probe", "column", 4, "sine", {"amp": 50, "freq": 0.3, "speed": 70}, {"interval": 14, "from_depth": True}),
        ("tide_wasp", "v", 5, "dive", {"side": -1, "amp": 80, "speed": 66}, {"mirror": True, "drop_last": "orb"}),
        ("trawler", "single", 1, "straight", {"speed": 28}, {}),
    ],
    3: [
        ("herald", "single", 1, "stop_go", {"speed": 60, "stop_y": 110, "hold": 4}, {}),
        ("phalanx", "v", 5, "straight", {"speed": 60}, {}),
        ("volt_ray", "line", 2, "dive", {"side": 1, "amp": 60, "speed": 50}, {"mirror": True, "spacing": 90}),
        ("spark_swarm", "column", 10, "sine", {"amp": 70, "freq": 0.6, "speed": 110}, {"interval": 6}),
        ("gold_lance", "line", 4, "stop_go", {"speed": 85, "stop_y": 130, "hold": 2.0}, {"spacing": 54, "drop_last": "orb"}),
        ("prism_jelly", "line", 2, "sine", {"amp": 50, "freq": 0.2, "speed": 36}, {"spacing": 100}),
    ],
    4: [
        ("magma_larva", "line", 3, "stop_go", {"speed": 70, "stop_y": 150, "hold": 2.5}, {"spacing": 70, "from_depth": True}),
        ("hunter", "line", 2, "sine", {"amp": 60, "freq": 0.2, "speed": 40}, {"spacing": 110}),
        ("bulwark", "single", 1, "stop_go", {"speed": 40, "stop_y": 90, "hold": 5}, {}),
        ("tide_wasp", "v", 5, "dive", {"side": 1, "amp": 70, "speed": 70}, {"mirror": True, "drop_last": "orb"}),
        ("herald", "single", 1, "stop_go", {"speed": 60, "stop_y": 120, "hold": 4}, {}),
        ("spark_swarm", "column", 10, "sine", {"amp": 70, "freq": 0.6, "speed": 110}, {"interval": 6, "drop_last": "capsule"}),
    ],
    5: [
        ("sower", "single", 1, "stop_go", {"speed": 50, "stop_y": 140, "hold": 5}, {}),
        ("basilica", "single", 1, "scroll", {"speed": 20}, {"y": -40}),
        ("gold_lance", "line", 4, "stop_go", {"speed": 85, "stop_y": 120, "hold": 2.0}, {"spacing": 54, "drop_last": "orb"}),
        ("phalanx", "v", 5, "straight", {"speed": 62}, {"drop_last": "capsule"}),
        ("hunter", "line", 2, "sine", {"amp": 60, "freq": 0.2, "speed": 42}, {"spacing": 110}),
        ("skiff", "v", 7, "straight", {"speed": 86}, {}),
    ],
    6: [
        ("ice_fan", "line", 3, "sine", {"amp": 80, "freq": 0.5, "speed": 60}, {"spacing": 80}),
        ("judge", "single", 1, "stop_go", {"speed": 60, "stop_y": 110, "hold": 4}, {}),
        ("glass_siren", "single", 1, "stop_go", {"speed": 40, "stop_y": 130, "hold": 5}, {"from_depth": True}),
        ("tide_wasp", "v", 5, "dive", {"side": -1, "amp": 80, "speed": 70}, {"mirror": True, "drop_last": "orb"}),
        ("prism_jelly", "line", 3, "sine", {"amp": 40, "freq": 0.25, "speed": 36}, {"spacing": 80, "drop_last": "capsule"}),
    ],
    7: [
        ("aegis", "single", 1, "stop_go", {"speed": 45, "stop_y": 100, "hold": 5}, {}),
        ("nautilus", "single", 1, "sine", {"amp": 50, "freq": 0.15, "speed": 26}, {}),
        ("gold_lance", "line", 4, "stop_go", {"speed": 85, "stop_y": 130, "hold": 2.0}, {"spacing": 54, "drop_last": "orb"}),
        ("volt_ray", "line", 2, "dive", {"side": 1, "amp": 60, "speed": 50}, {"mirror": True, "spacing": 90}),
        ("phalanx", "v", 5, "straight", {"speed": 64}, {"drop_last": "capsule"}),
    ],
    8: [
        ("trireme", "single", 1, "scroll", {"speed": 18}, {"y": -40}),
        ("bulwark", "single", 1, "stop_go", {"speed": 40, "stop_y": 90, "hold": 5}, {}),
        ("hunter", "line", 2, "sine", {"amp": 60, "freq": 0.2, "speed": 44}, {"spacing": 110}),
        ("spark_swarm", "column", 12, "sine", {"amp": 80, "freq": 0.6, "speed": 115}, {"interval": 6, "drop_last": "capsule"}),
        ("ice_fan", "line", 3, "sine", {"amp": 80, "freq": 0.5, "speed": 62}, {"spacing": 80, "drop_last": "orb"}),
        ("squid_probe", "column", 4, "sine", {"amp": 50, "freq": 0.3, "speed": 72}, {"interval": 14, "from_depth": True}),
    ],
    9: [
        ("protocol_shard", "single", 1, "stop_go", {"speed": 55, "stop_y": 120, "hold": 4}, {}),
        ("protocol_shard", "line", 2, "sine", {"amp": 50, "freq": 0.2, "speed": 34}, {"spacing": 120}),
        ("herald", "single", 1, "stop_go", {"speed": 60, "stop_y": 110, "hold": 4}, {}),
        ("glass_siren", "single", 1, "stop_go", {"speed": 40, "stop_y": 130, "hold": 5}, {}),
        ("tide_wasp", "v", 5, "dive", {"side": 1, "amp": 80, "speed": 72}, {"mirror": True, "drop_last": "orb"}),
        ("spark_swarm", "column", 10, "sine", {"amp": 70, "freq": 0.6, "speed": 115}, {"interval": 6, "drop_last": "capsule"}),
    ],
    # Capítulo bônus (pós-lançamento): Fossa Hadal, criaturas das três facções que o Protocolo deixou no fundo.
    10: [
        ("nautilus", "single", 1, "sine", {"amp": 50, "freq": 0.15, "speed": 28}, {}),
        ("squid_probe", "column", 4, "sine", {"amp": 50, "freq": 0.3, "speed": 72}, {"interval": 14, "from_depth": True}),
        ("glass_siren", "single", 1, "stop_go", {"speed": 40, "stop_y": 130, "hold": 5}, {"from_depth": True}),
        ("prism_jelly", "line", 3, "sine", {"amp": 40, "freq": 0.25, "speed": 36}, {"spacing": 80, "drop_last": "capsule"}),
        ("protocol_shard", "single", 1, "stop_go", {"speed": 55, "stop_y": 120, "hold": 4}, {}),
        ("tide_wasp", "v", 5, "dive", {"side": -1, "amp": 80, "speed": 72}, {"mirror": True, "drop_last": "orb"}),
        ("magma_larva", "line", 3, "stop_go", {"speed": 70, "stop_y": 150, "hold": 2.5}, {"spacing": 70, "from_depth": True}),
    ],
}
XS = [0.25, 0.35, 0.5, 0.65, 0.75]
# Trechos de ondas esticados para cada missão durar de 2 a 5 min (plano mestre 5), já contando os chefes de meio
# de fase (o roteiro pausa enquanto eles lutam).
FILL_BASE = 1.15
FILL_SCALE = FILL_BASE
# Nas missões que terminam em chefe os trechos são mais curtos, mas com as mesmas ondas (mais densos).
DENSITY_BOOST = 1.0


def wave(enemy, formation, count, path, params, x, **extra):
    ev = {"op": "wave", "enemy": enemy, "formation": formation, "count": count, "x": x, "path": path,
          "params": dict(params)}
    ev.update(extra)
    return ev


def fill(chapter: int, seconds: float, rng: random.Random, density: float = 1.0, depth: bool = False):
    """Trecho de ondas do capítulo: uma onda a cada ~3,5 s (menos com densidade maior)."""
    seconds *= FILL_SCALE
    out = []
    t = 0.0
    step = 3.6 / (density * DENSITY_BOOST)
    while t < seconds - 1.0:
        enemy, formation, count, path, params, extra = rng.choice(POOLS[chapter])
        kw = dict(extra)
        if depth and "from_depth" not in kw and formation != "single":
            kw["from_depth"] = True
        x = rng.choice(XS) if formation in ("single", "column") else 0.5
        if "spacing" not in kw and formation in ("line", "v"):
            kw["spacing"] = 36
        if enemy in ("sentinel_buoy", "trawler", "coral_turret", "herald", "volt_ray", "basilica", "bulwark", "sower",
                     "judge", "aegis", "nautilus", "trireme", "glass_siren"):
            kw.setdefault("marked", True)
        out.append((round(t, 2), wave(enemy, formation, count, path, params, x, **kw)))
        t += step * (1.3 if enemy in ("trawler", "herald", "coral_turret") else 1.0)
    return seconds, out


def beat(seconds, events):
    return seconds, [(round(t, 2), ev) for t, ev in events]


def dialogue(id_):
    return {"op": "dialogue", "id": id_}


MISSIONS = {
    "c1m1": dict(chapter=1, name="stage.c1m1", music="hydrogene_space_shooter", backdrop="ocean", scroll=22,
                 objective={"type": "log", "text_key": "objective.log"}, tutorial=True,
                 beats=lambda r: [beat(2, [(0.5, dialogue("c1m1_intro"))]), fill(1, 26, r, 0.8),
                                  beat(4, [(0.5, {"op": "blessing"})]), fill(1, 14, r, 0.9),
                                  beat(2, [(0.0, dialogue("c1m1_shift"))]),
                                  beat(10, [(0.0, {"op": "ocean_shift", "to": "ruins", "warn": 2.0, "duration": 8.0})]),
                                  fill(1, 18, r, 0.9, True), beat(3, [(0.0, {"op": "log", "x": 0.3})]),
                                  fill(1, 16, r, 1.0, True), beat(4, [(0.5, {"op": "blessing"})]),
                                  fill(1, 18, r, 1.1), beat(4, [(0.0, {"op": "end"})])]),
    "c1m2": dict(chapter=1, name="stage.c1m2", music="hydrogene_space_shooter", backdrop="ocean", scroll=24,
                 objective={"type": "miniboss_time", "seconds": 50, "text_key": "objective.miniboss_time"},
                 beats=lambda r: [fill(1, 24, r, 1.0), beat(4, [(0.5, {"op": "blessing"})]),
                                  beat(10, [(0.0, {"op": "ocean_shift", "to": "ruins", "warn": 2.0, "duration": 6.0})]),
                                  fill(1, 22, r, 1.1, True), beat(3, [(0.0, {"op": "log", "x": 0.7})]),
                                  fill(1, 18, r, 1.1), beat(4, [(0.5, {"op": "blessing"})]),
                                  beat(4, [(0.0, dialogue("c1m1_breath"))]),
                                  beat(3, [(0.0, {"op": "miniboss", "id": "tidebreaker"})]),
                                  fill(1, 10, r, 0.9), beat(4, [(0.0, {"op": "end"})])]),
    "c1m3": dict(chapter=1, name="stage.c1m3", music="hydrogene_space_shooter", backdrop="ocean", scroll=26,
                 objective={"type": "chain", "count": 40, "text_key": "objective.chain"},
                 beats=lambda r: [fill(1, 20, r, 1.1), beat(10, [(0.0, {"op": "ocean_shift", "to": "ruins", "warn": 2.0, "duration": 6.0})]),
                                  fill(1, 18, r, 1.2, True), beat(4, [(0.5, {"op": "blessing"})]),
                                  beat(8, [(0.0, {"op": "ocean_shift", "to": "flood", "warn": 2.0, "duration": 5.0})]),
                                  fill(1, 22, r, 1.25), beat(3, [(0.0, {"op": "log", "x": 0.5})]),
                                  beat(4, [(0.5, {"op": "blessing"})]), fill(1, 24, r, 1.3, True),
                                  beat(4, [(0.0, {"op": "end"})])]),
    "c2m1": dict(chapter=2, name="stage.c2m1", music="hydrogene_space_shooter", backdrop="atlantis", scroll=20,
                 objective={"type": "secret", "text_key": "objective.secret"},
                 secret={"glyphs": 3, "mission": "s1"},
                 beats=lambda r: [beat(2, [(0.5, dialogue("c2_intro"))]), fill(2, 20, r, 0.9),
                                  beat(8, [(0.0, {"op": "current", "dx": 1, "strength": 34, "duration": 8.0})]),
                                  fill(2, 14, r, 1.0), beat(4, [(0.5, {"op": "blessing"})]),
                                  beat(14, [(0.0, wave("glyph", "single", 1, "scroll", {"speed": 22}, 0.2, glyph=0, y=-20)),
                                            (4.0, wave("glyph", "single", 1, "scroll", {"speed": 22}, 0.8, glyph=1, y=-20)),
                                            (8.0, wave("glyph", "single", 1, "scroll", {"speed": 22}, 0.5, glyph=2, y=-20))]),
                                  fill(2, 18, r, 1.0), beat(8, [(0.0, {"op": "current", "dx": -1, "strength": 38, "duration": 8.0})]),
                                  beat(3, [(0.0, {"op": "log", "x": 0.4})]), beat(4, [(0.5, {"op": "blessing"})]),
                                  fill(2, 20, r, 1.1), beat(4, [(0.0, {"op": "end"})])]),
    "c2m2": dict(chapter=2, name="stage.c2m2", music="hydrogene_space_shooter", backdrop="atlantis", scroll=22,
                 objective={"type": "miniboss_time", "seconds": 55, "text_key": "objective.miniboss_time_coral"},
                 beats=lambda r: [fill(2, 26, r, 1.0), beat(4, [(0.5, {"op": "blessing"})]),
                                  beat(8, [(0.0, {"op": "current", "dx": 1, "strength": 40, "duration": 7.0})]),
                                  fill(2, 22, r, 1.15), beat(3, [(0.0, {"op": "log", "x": 0.6})]),
                                  beat(4, [(0.5, {"op": "blessing"})]), fill(2, 12, r, 1.0),
                                  beat(3, [(0.0, {"op": "miniboss", "id": "coral_guardian"})]),
                                  fill(2, 10, r, 1.0), beat(4, [(0.0, {"op": "end"})])]),
    "c2m3": dict(chapter=2, name="stage.c2m3", music="hydrogene_space_shooter", backdrop="atlantis", scroll=20,
                 objective={"type": "no_bomb", "text_key": "objective.no_bomb"},
                 beats=lambda r: [fill(2, 24, r, 1.1), beat(4, [(0.5, {"op": "blessing"})]),
                                  beat(10, [(0.0, {"op": "ocean_shift", "to": "ruins", "warn": 2.0, "duration": 6.0})]),
                                  fill(2, 22, r, 1.2, True), beat(3, [(0.0, {"op": "log", "x": 0.5})]),
                                  beat(4, [(0.5, {"op": "blessing"})]), beat(4, [(0.0, dialogue("c1m1_boss"))]),
                                  beat(2, [(0.0, {"op": "boss", "id": "kraken_engine"})]), beat(2, [(0.0, {"op": "end"})])]),
    "c3m1": dict(chapter=3, name="stage.c3m1", music="hydrogene_space_shooter", backdrop="storm", scroll=26,
                 objective={"type": "grazes", "count": 80, "text_key": "objective.grazes"},
                 beats=lambda r: [beat(2, [(0.5, dialogue("c3_intro"))]), fill(3, 20, r, 1.0),
                                  beat(10, [(0.0, {"op": "wind", "dx": 1, "strength": 30, "duration": 10.0}),
                                            (2.0, {"op": "lightning", "x": 0.3}), (5.0, {"op": "lightning", "x": 0.7})]),
                                  fill(3, 16, r, 1.1), beat(4, [(0.5, {"op": "blessing"})]),
                                  beat(10, [(0.0, {"op": "lightning", "x": 0.5}), (2.5, {"op": "lightning", "x": 0.2}),
                                            (2.5, {"op": "lightning", "x": 0.8}), (6.0, {"op": "lightning", "x": 0.5})]),
                                  fill(3, 18, r, 1.15), beat(3, [(0.0, {"op": "log", "x": 0.25})]),
                                  beat(4, [(0.5, {"op": "blessing"})]),
                                  beat(10, [(0.0, {"op": "wind", "dx": -1, "strength": 34, "duration": 10.0})]),
                                  fill(3, 16, r, 1.2), beat(4, [(0.0, {"op": "end"})])]),
    "c3m2": dict(chapter=3, name="stage.c3m2", music="hydrogene_space_shooter", backdrop="storm", scroll=26, stretch=1.1,
                 objective={"type": "miniboss_time", "seconds": 55, "text_key": "objective.miniboss_time_storm"},
                 beats=lambda r: [fill(3, 24, r, 1.1), beat(4, [(0.5, {"op": "blessing"})]),
                                  beat(10, [(0.0, {"op": "wind", "dx": 1, "strength": 34, "duration": 9.0}),
                                            (3.0, {"op": "lightning", "x": 0.4})]),
                                  fill(3, 20, r, 1.2), beat(3, [(0.0, {"op": "log", "x": 0.75})]),
                                  beat(4, [(0.5, {"op": "blessing"})]),
                                  beat(3, [(0.0, {"op": "miniboss", "id": "storm_eye"})]),
                                  fill(3, 10, r, 1.0), beat(4, [(0.0, {"op": "end"})])]),
    "c3m3s": dict(chapter=3, name="stage.c3m3s", music="hydrogene_space_shooter", backdrop="storm", scroll=28,
                  route="surface", objective={"type": "score", "count": 60000, "text_key": "objective.score"},
                  beats=lambda r: [fill(3, 26, r, 1.15), beat(4, [(0.5, {"op": "blessing"})]),
                                   beat(10, [(0.0, {"op": "wind", "dx": 1, "strength": 36, "duration": 10.0})]),
                                   fill(3, 24, r, 1.25), beat(3, [(0.0, {"op": "log", "x": 0.5})]),
                                   beat(4, [(0.5, {"op": "blessing"})]), fill(3, 22, r, 1.3),
                                   beat(4, [(0.0, {"op": "end"})])]),
    "c3m3a": dict(chapter=3, name="stage.c3m3a", music="hydrogene_space_shooter", backdrop="atlantis", scroll=24,
                  route="abyss", score_mult=1.5, stretch=1.15, objective={"type": "chain", "count": 50, "text_key": "objective.chain_50"},
                  beats=lambda r: [fill(2, 24, r, 1.3, True), beat(4, [(0.5, {"op": "blessing"})]),
                                   beat(8, [(0.0, {"op": "current", "dx": -1, "strength": 44, "duration": 8.0})]),
                                   fill(3, 24, r, 1.35, True), beat(3, [(0.0, {"op": "log", "x": 0.3})]),
                                   beat(4, [(0.5, {"op": "blessing"})]), fill(2, 22, r, 1.4, True),
                                   beat(4, [(0.0, {"op": "end"})])]),
    "s1": dict(chapter=2, name="stage.s1", music="hydrogene_space_shooter", backdrop="atlantis", scroll=18,
               weapon_lock="railgun", secret_mission=True, stretch=1.25, objective={"type": "log", "text_key": "objective.log"},
               beats=lambda r: [beat(2, [(0.5, dialogue("s1_intro"))]), fill(2, 34, r, 1.0, True),
                                beat(4, [(0.5, {"op": "blessing"})]), beat(3, [(0.0, {"op": "log", "x": 0.5})]),
                                fill(2, 34, r, 1.2, True), beat(4, [(0.0, {"op": "end"})])]),
}


def hazard(kind, xs, gap=2.5, width=26):
    """Colunas de perigo com aviso (raio, lava, gelo, detritos) em sequência."""
    return [(k * gap, {"op": "lightning", "kind": kind, "x": x, "width": width}) for k, x in enumerate(xs)]


def capsules(*xs):
    return [(k * 3.0, {"op": "capsule", "x": x}) for k, x in enumerate(xs)]


def glyphs(mission):
    return [(0.0, wave("glyph", "single", 1, "scroll", {"speed": 22}, 0.2, glyph=0, y=-20)),
            (4.0, wave("glyph", "single", 1, "scroll", {"speed": 22}, 0.8, glyph=1, y=-20)),
            (8.0, wave("glyph", "single", 1, "scroll", {"speed": 22}, 0.5, glyph=2, y=-20))]


def chapter_mission(ch, moment, extra=None, density=1.0, end=None, depth=False):
    """Missão comum: abertura, ondas, momento da fase, bênção, registro, ondas, (extra), bênção, fim."""
    def beats(r):
        out = [fill(ch, 20, r, density, depth), beat(4, [(0.5, {"op": "blessing"})]), beat(12, moment),
               fill(ch, 18, r, density * 1.1, depth), beat(3, [(0.0, {"op": "log", "x": 0.3 + 0.4 * r.random()})]),
               beat(6, capsules(0.3, 0.7)), fill(ch, 16, r, density * 1.15, depth)]
        if extra:
            out += extra(r)
        out += [beat(4, [(0.5, {"op": "blessing"})])]
        out += end(r) if end else [fill(ch, 14, r, density * 1.2, depth), beat(4, [(0.0, {"op": "end"})])]
        return out
    return beats


def boss_end(boss_id, line):
    return lambda r: [beat(4, [(0.0, dialogue(line))]), beat(2, [(0.0, {"op": "boss", "id": boss_id})]),
                      beat(2, [(0.0, {"op": "end"})])]


def mini_end(ch, boss_id):
    return lambda r: [beat(3, [(0.0, {"op": "miniboss", "id": boss_id})]), fill(ch, 10, r, 1.0),
                      beat(4, [(0.0, {"op": "end"})])]


## Trilha por capítulo (redesenho 1.6, .ai/05-pesquisa-redesign-ui-gameplay.md): cada mar com cara própria.
CHAPTER_MUSIC = {
    1: "mintodog_ocean_trance", 2: "prosensory_binary_village", 3: "ansimuz_cyber_runner",
    4: "magnesus_hostile_territory", 5: "hydrogene_space_shooter", 6: "mintodog_ocean_trance",
    7: "ansimuz_cyber_runner", 8: "magnesus_deadly_contracts", 9: "magnesus_deadly_contracts",
    10: "prosensory_binary_village",
}
BACKDROP = {4: "volcanic", 5: "city", 6: "ice", 7: "stratosphere", 8: "orbit", 9: "core"}
MOMENT = {
    4: hazard("lava", [0.2, 0.8, 0.5, 0.35, 0.65]),
    5: [(0.0, {"op": "cover", "x": 0.25, "height": 160, "duration": 10}),
        (1.0, {"op": "cover", "x": 0.75, "height": 140, "duration": 10})],
    6: hazard("icefall", [0.3, 0.7, 0.5, 0.15, 0.85], gap=2.0, width=20),
    7: [(0.0, {"op": "gravity_breach", "dx": 1, "dy": 0, "strength": 30, "duration": 10})],
    8: hazard("debris", [0.25, 0.75, 0.5, 0.4, 0.6], gap=2.0, width=22),
    9: [(0.0, {"op": "gravity_breach", "dx": 0, "dy": 1, "strength": 34, "duration": 10, "flip": True})],
}


def add_chapter(ch, mini_id, boss=None, boss_line="", glyph_secret=""):
    music = "hydrogene_space_shooter"
    obj_route = {"type": "rescue", "count": 6, "text_key": "objective.rescue"}
    m1 = dict(chapter=ch, name=f"stage.c{ch}m1", music=music, backdrop=BACKDROP[ch], scroll=24,
              objective={"type": "secret", "text_key": "objective.secret"} if glyph_secret else
              {"type": "capsule_combo", "count": 4, "text_key": "objective.capsule_combo"},
              beats=chapter_mission(ch, MOMENT[ch], extra=(lambda r: [beat(14, glyphs(""))]) if glyph_secret else None))
    if glyph_secret:
        m1["secret"] = {"glyphs": 3, "mission": glyph_secret}
    MISSIONS[f"c{ch}m1"] = m1
    MISSIONS[f"c{ch}m2"] = dict(chapter=ch, name=f"stage.c{ch}m2", music=music, backdrop=BACKDROP[ch], scroll=24,
                                objective={"type": "miniboss_time", "seconds": 60,
                                           "text_key": f"objective.miniboss_{mini_id}"},
                                beats=chapter_mission(ch, MOMENT[ch], density=1.1, end=mini_end(ch, mini_id)))
    if ch == 9:
        MISSIONS["c9m3"] = dict(chapter=9, name="stage.c9m3", music=music, backdrop="core", scroll=22,
                                objective={"type": "boss_time", "seconds": 150, "text_key": "objective.boss_time"},
                                beats=chapter_mission(9, MOMENT[9], density=1.2, end=boss_end(boss, boss_line)))
        return
    end = boss_end(boss, boss_line) if boss else None
    for route, mult, dens, depth in (("s", 1.0, 1.15, False), ("a", 1.5, 1.35, True)):
        spec = dict(chapter=ch, name=f"stage.c{ch}m3{route}", music=music,
                    backdrop=BACKDROP[ch] if route == "s" else "atlantis", scroll=26,
                    route="surface" if route == "s" else "abyss",
                    objective=obj_route if route == "s" else {"type": "chain", "count": 50,
                                                              "text_key": "objective.chain_50"},
                    beats=chapter_mission(ch, MOMENT[ch], density=dens, end=end, depth=depth))
        if mult != 1.0:
            spec["score_mult"] = mult
        MISSIONS[f"c{ch}m3{route}"] = spec


add_chapter(4, "forge", glyph_secret="s2")
add_chapter(5, "architect", boss="sky_leviathan", boss_line="sky_leviathan_intro")
add_chapter(6, "ice_queen", glyph_secret="s3")
add_chapter(7, "steel_albatross", boss="poseidon_prime", boss_line="poseidon_intro")
add_chapter(8, "orbital_gate", glyph_secret="s4")
add_chapter(9, "orbital_gate", boss="leviathan_protocol", boss_line="protocol_intro")
# O capítulo 9 não tem mini-chefe próprio: a 9-2 é a travessia do núcleo, com Gravity Breach alternada.
MISSIONS["c9m2"] = dict(chapter=9, name="stage.c9m2", music="hydrogene_space_shooter", backdrop="core", scroll=26,
                        objective={"type": "grazes", "count": 120, "text_key": "objective.grazes_120"},
                        beats=chapter_mission(9, MOMENT[9], density=1.25,
                                              extra=lambda r: [beat(12, [(0.0, {"op": "gravity_breach", "dx": 1, "dy": 0,
                                                                                 "strength": 36, "duration": 10,
                                                                                 "flip": True})])]))
MISSIONS["s2"] = dict(chapter=4, name="stage.s2", music="hydrogene_space_shooter", backdrop="volcanic", scroll=20,
                      dark=True, secret_mission=True, stretch=1.5, objective={"type": "log", "text_key": "objective.log"},
                      beats=lambda r: [beat(2, [(0.5, dialogue("s2_intro"))]), fill(4, 30, r, 0.9),
                                       beat(4, [(0.5, {"op": "blessing"})]), beat(3, [(0.0, {"op": "log", "x": 0.6})]),
                                       fill(4, 30, r, 1.0), beat(4, [(0.0, {"op": "end"})])])
MISSIONS["s3"] = dict(chapter=6, name="stage.s3", music="hydrogene_space_shooter", backdrop="ice", scroll=20,
                      secret_mission=True, stretch=1.5, objective={"type": "log", "text_key": "objective.log"},
                      beats=lambda r: [beat(2, [(0.5, dialogue("s3_intro"))]),
                                       beat(1, [(0.0, {"op": "gravity_breach", "dx": 0, "dy": -1, "strength": 24,
                                                       "duration": 150})]),
                                       fill(6, 30, r, 0.9), beat(4, [(0.5, {"op": "blessing"})]),
                                       beat(3, [(0.0, {"op": "log", "x": 0.4})]), fill(6, 30, r, 1.0),
                                       beat(4, [(0.0, {"op": "end"})])])
MISSIONS["s4"] = dict(chapter=8, name="stage.s4", music="hydrogene_space_shooter", backdrop="atlantis", scroll=20,
                      secret_mission=True, stretch=1.2, objective={"type": "log", "text_key": "objective.log"},
                      beats=lambda r: [beat(2, [(0.5, dialogue("s4_intro"))])] + [
                          beat(16, [(0.0, {"op": "ocean_shift", "to": "ruins" if k % 2 == 0 else "flood", "warn": 2.0,
                                           "duration": 6.0}), (8.0, {"op": "capsule", "x": 0.3 + 0.1 * k})])
                          for k in range(3)] + [fill(8, 24, r, 1.0), beat(3, [(0.0, {"op": "log", "x": 0.5})]),
                                                beat(4, [(0.5, {"op": "blessing"})]), fill(8, 20, r, 1.1),
                                                beat(4, [(0.0, {"op": "end"})])])

# Capítulo 10 (bônus): Fossa Hadal. Escuridão com sonar, correntes e fontes térmicas; Pescador Abissal e a
# Matriarca Hadal. Abre depois da 9-3, com qualquer final.
HADAL = [(0.0, {"op": "current", "dx": 1, "strength": 30, "duration": 8.0}), (2.0, {"op": "lightning", "x": 0.3}),
         (5.0, {"op": "lightning", "x": 0.7}), (8.0, {"op": "lightning", "x": 0.5})]
MISSIONS["c10m1"] = dict(chapter=10, name="stage.c10m1", music="hydrogene_space_shooter", backdrop="hadal", scroll=20,
                         dark=True, objective={"type": "log", "text_key": "objective.log"},
                         beats=lambda r: [beat(2, [(0.5, dialogue("c10_intro"))]), fill(10, 22, r, 0.9),
                                          beat(4, [(0.5, {"op": "blessing"})]),
                                          beat(8, [(0.0, {"op": "ocean_shift", "to": "flood", "warn": 2.0,
                                                          "duration": 6.0})]),
                                          fill(10, 18, r, 1.0, True), beat(3, [(0.0, {"op": "log", "x": 0.6})]),
                                          beat(6, capsules(0.3, 0.7)), fill(10, 16, r, 1.1),
                                          beat(4, [(0.5, {"op": "blessing"})]), fill(10, 16, r, 1.15),
                                          beat(4, [(0.0, {"op": "end"})])])
MISSIONS["c10m2"] = dict(chapter=10, name="stage.c10m2", music="hydrogene_space_shooter", backdrop="hadal", scroll=22,
                         objective={"type": "miniboss_time", "seconds": 60,
                                    "text_key": "objective.miniboss_hadal_angler"},
                         beats=chapter_mission(10, HADAL, density=1.1, end=mini_end(10, "hadal_angler")))
MISSIONS["c10m3"] = dict(chapter=10, name="stage.c10m3", music="hydrogene_space_shooter", backdrop="hadal", scroll=22,
                         objective={"type": "boss_time", "seconds": 150, "text_key": "objective.boss_time"},
                         beats=chapter_mission(10, HADAL, density=1.2, end=boss_end("hadal_matriarch", "hadal_intro")))


def _mid_module():
    spec = importlib.util.spec_from_file_location("gen_bosses_mid", ROOT / "tools" / "gen_bosses_mid.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


MID = _mid_module()
# Chefe intermediário do capítulo, na ordem de gen_bosses_mid.mids().
MID_OF = {1: "harpoon_trawler", 2: "pearl_oracle", 3: "thunder_manta", 4: "magma_crab", 5: "spire_warden",
          6: "frost_serpent", 7: "storm_carrier", 8: "satellite_hydra", 9: "protocol_sentinel", 10: "abyss_jelly"}
# Onde entram os chefes de meio de fase (fração do roteiro), na ordem de prioridade: o chefe intermediário
# primeiro (toda fase tem um), depois as duas elites.
BOSS_MARKS = ((0.5, "mid"), (0.25, "elite_a"), (0.75, "elite_b"))
# Distância mínima (fração do roteiro) entre dois chefes, e de um chefe ao fim da fase.
BOSS_GAP = 0.1
# Um corte entre trechos de ondas vale mais que o meio de um trecho (a onda em curso termina antes do chefe).
INSIDE_FILL_COST = 0.06


def place_bosses(chapter: int, events: list, cuts: list, length: float) -> None:
    """Põe o chefe intermediário perto de 1/2 do roteiro e as elites perto de 1/4 e 3/4, longe dos chefes que a
    missão já tem e do fim. Prefere os cortes entre trechos de ondas; se não houver um livre, entra entre duas
    ondas. O roteiro pausa enquanto o chefe luta, então o que vem depois só começa quando ele cai."""
    first, second = MID.elites_of(chapter)
    ids = {"mid": f"mid_{MID_OF[chapter]}", "elite_a": f"elite_{first}_c{chapter}",
           "elite_b": f"elite_{second}_c{chapter}"}
    taken = [e["t"] / length for e in events if e["op"] in ("boss", "miniboss")] + [1.0]
    # Ritmo de 2 a 5,5 min: com chefe de ato, só o chefe intermediário; com o mini-chefe do capítulo, ele e uma elite.
    own = {e["op"] for e in events if e["op"] in ("boss", "miniboss")}
    marks = BOSS_MARKS[:1] if "boss" in own else BOSS_MARKS[:2] if own else BOSS_MARKS
    inside = sorted({e["t"] for e in events if e["op"] == "wave" and e.get("enemy") != "glyph"} - set(cuts))
    for mark, kind in marks:
        options = [(c, 0.0) for c in cuts] + [(c, INSIDE_FILL_COST) for c in inside]
        options = [o for o in options if all(abs(o[0] / length - x) >= BOSS_GAP for x in taken)]
        if not options:
            continue
        cut = min(options, key=lambda o: abs(o[0] / length - mark) + o[1])[0]
        taken.append(cut / length)
        events.append({"op": "miniboss", "id": ids[kind], "t": round(cut - 0.05, 2)})
        for k in range(2 if kind == "mid" else 1):
            events.append(dict(escort(chapter, k), t=round(cut - 0.6 + 0.2 * k, 2)))
    events.sort(key=lambda e: e["t"])


def escort(chapter: int, k: int) -> dict:
    """Escolta que entra com o chefe: a primeira formação de 4+ naves do capítulo (o chefe intermediário traz
    duas, em lados opostos)."""
    enemy, formation, count, path, params, extra = [w for w in POOLS[chapter]
                                                    if w[1] in ("line", "v", "column") and w[2] >= 4][0]
    kw = {key: v for key, v in extra.items() if key not in ("drop_last",)}
    kw.setdefault("spacing", 36)
    x = (0.3, 0.7)[k] if formation == "column" else 0.5
    return wave(enemy, formation, count, path, params, x, escort=True, **kw)


# Missões que já terminam em chefe têm os trechos de ondas mais curtos (a luta do fim já é longa).
BOSS_MISSION_FILL = 0.85


def script(mission_id: str, spec: dict, scale: float) -> tuple:
    global FILL_SCALE, DENSITY_BOOST
    FILL_SCALE = FILL_BASE * spec.get("stretch", 1.0) * scale
    DENSITY_BOOST = 1.0 / scale
    rng = random.Random(f"atlantis:{mission_id}")
    events = []
    cuts = []
    t = 0.0
    for seconds, items in spec["beats"](rng):
        for dt, ev in items:
            ev = dict(ev)
            ev["t"] = round(t + dt, 2)
            events.append(ev)
        t += seconds
        if len(items) > 2 and all(ev["op"] == "wave" and ev.get("enemy") != "glyph" for _, ev in items):
            cuts.append(round(t, 2))
    return events, cuts, t


# Clima de cada missão (1.13 "Céu e Mar Vivos", scripts/sim/weather.gd): estado inicial e frentes. Cada frente é
# (âncora, estado): a âncora é a fração do roteiro ou "before:<chefe>" (6 s antes dele entrar). O estado precisa ser
# do meio do cenário (água, céu ou vácuo). Ordem de ensino: a primeira frente que mexe na nave (a ressaca da 1-2)
# vem depois de duas missões de clima só visual, e todo clima severo entra com 3 s de aviso.
WEATHER = {
    "c1m1": ("calm", [(0.3, "plankton"), (0.85, "calm")]),
    "c1m2": ("calm", [(0.35, "surge"), (0.62, "calm")]),
    "c1m3": ("plankton", [(0.4, "silt"), (0.72, "calm")]),
    "c2m1": ("calm", [(0.25, "thermocline"), (0.7, "plankton")]),
    "c2m2": ("plankton", [(0.3, "surge"), (0.6, "calm")]),
    "c2m3": ("calm", [(0.3, "storm_above"), ("before:kraken_engine", "calm")]),
    "c3m1": ("clouds", [(0.15, "rain"), (0.38, "storm"), (0.72, "clouds")]),
    "c3m2": ("rain", [(0.2, "storm"), ("before:storm_eye", "eye"), (0.88, "rain")]),
    "c3m3s": ("rain", [(0.12, "storm"), (0.6, "rain"), (0.75, "storm"), (0.93, "clear")]),
    "c3m3a": ("storm_above", [(0.45, "surge"), (0.8, "calm")]),
    "c4m1": ("clear", [(0.25, "ash"), (0.8, "clear")]),
    "c4m2": ("ash", [(0.55, "clouds")]),
    "c4m3s": ("clouds", [(0.3, "ash"), (0.75, "clouds")]),
    "c4m3a": ("calm", [(0.3, "vents"), (0.75, "calm")]),
    "c5m1": ("clouds", [(0.35, "rain"), (0.8, "clouds")]),
    "c5m2": ("rain", [(0.3, "storm"), (0.65, "clouds")]),
    "c5m3s": ("clouds", [(0.3, "storm"), ("before:sky_leviathan", "eye")]),
    "c5m3a": ("plankton", [(0.4, "thermocline"), (0.7, "plankton")]),
    "c6m1": ("snow", [(0.6, "clear")]),
    "c6m2": ("snow", [(0.3, "blizzard"), (0.62, "snow")]),
    "c6m3s": ("snow", [(0.2, "blizzard"), (0.55, "snow"), (0.7, "blizzard"), (0.9, "snow")]),
    "c6m3a": ("calm", [(0.3, "thermocline"), (0.75, "calm")]),
    "c7m1": ("clear", [(0.3, "jetstream"), (0.65, "clouds")]),
    "c7m2": ("clouds", [(0.25, "jetstream"), (0.7, "clear")]),
    "c7m3s": ("clouds", [(0.2, "jetstream"), (0.45, "clouds"), (0.62, "jetstream"), ("before:poseidon_prime", "clear")]),
    "c7m3a": ("calm", [(0.35, "abyssal"), (0.8, "calm")]),
    "c8m1": ("vacuum", [(0.35, "solar"), (0.7, "vacuum")]),
    "c8m2": ("vacuum", [(0.2, "solar"), (0.6, "vacuum")]),
    "c8m3s": ("vacuum", [(0.25, "solar"), (0.55, "vacuum"), (0.7, "solar"), (0.92, "vacuum")]),
    "c8m3a": ("calm", [(0.3, "abyssal"), (0.78, "calm")]),
    "c10m1": ("abyssal", [(0.5, "vents"), (0.85, "abyssal")]),
    "c10m2": ("abyssal", [(0.3, "vents"), (0.65, "abyssal")]),
    "c10m3": ("abyssal", [(0.3, "vents"), ("before:hadal_matriarch", "calm")]),
    "s1": ("abyssal", [(0.5, "calm")]),
    "s2": ("ash", []),
    "s3": ("snow", [(0.5, "blizzard"), (0.8, "snow")]),
    "s4": ("plankton", [(0.4, "surge"), (0.75, "plankton")]),
}
SEVERE = {"storm", "blizzard", "jetstream", "surge", "silt", "storm_above", "solar"}


def add_weather(mission_id: str, out: dict, length: float) -> None:
    """Estado inicial e eventos {"op": "weather"} da missão (aviso de 3 s no severo, 2 s nos outros)."""
    if mission_id not in WEATHER:
        return
    start, fronts = WEATHER[mission_id]
    out["weather"] = start
    for anchor, to in fronts:
        if isinstance(anchor, str):
            boss = anchor.split(":", 1)[1]
            t = next(e["t"] for e in out["events"] if e["op"] in ("boss", "miniboss") and e["id"] == boss) - 6.0
        else:
            t = anchor * length
        severe = to in SEVERE
        out["events"].append({"op": "weather", "to": to, "warn": 3.0 if severe else 2.0,
                              "ramp": 5.0 if severe else 4.0, "t": round(max(0.5, t), 2)})
    out["events"].sort(key=lambda e: e["t"])


def build(mission_id: str, spec: dict) -> dict:
    events, cuts, t = script(mission_id, spec, 1.0)
    if any(e["op"] in ("boss", "miniboss") for e in events):
        events, cuts, t = script(mission_id, spec, BOSS_MISSION_FILL)
    place_bosses(spec["chapter"], events, cuts, t)
    out = {"id": mission_id, "chapter": spec["chapter"], "name_key": spec["name"], "music": CHAPTER_MUSIC.get(spec["chapter"], spec["music"]),
           "scroll_speed": spec["scroll"], "backdrop": spec["backdrop"], "seed_salt": sum(map(ord, mission_id)),
           "objective": spec["objective"], "length_s": round(t, 1), "events": events}
    for key in ("secret", "route", "score_mult", "weapon_lock", "tutorial", "secret_mission", "dark"):
        if key in spec:
            out[key] = spec[key]
    add_weather(mission_id, out, t)
    return out


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    for mission_id, spec in MISSIONS.items():
        data = build(mission_id, spec)
        target = OUT / f"{mission_id}.json"
        target.write_text(json.dumps(data, ensure_ascii=False, indent="\t") + "\n", encoding="utf-8", newline="\n")
        waves = sum(1 for e in data["events"] if e["op"] == "wave")
        print(f"{mission_id}: {data['length_s']} s de fase, {waves} ondas, {len(data['events'])} eventos")
    return 0


if __name__ == "__main__":
    sys.exit(main())
