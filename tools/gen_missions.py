"""Gera data/stages/*.json (plano mestre 5): missões autorais montadas por "trechos".

Cada missão é uma lista de trechos com duração; o gerador soma os tempos. Trechos de ondas usam o
conjunto de inimigos do capítulo e um gerador pseudoaleatório com semente fixa por missão, então o
JSON gerado é sempre o mesmo. Os momentos de cada missão (Ocean Shift, corrente, vento, raios,
glifos, mini-chefe, chefe, bênçãos, registro) são escritos à mão em MISSIONS.

Uso: python -I tools/gen_missions.py   (escreve data/stages/ e imprime um resumo)
"""
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
}
XS = [0.25, 0.35, 0.5, 0.65, 0.75]
# Trechos de ondas esticados para cada missão durar de 2 a 5 min (plano mestre 5).
FILL_SCALE = 1.35


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
    step = 3.6 / density
    while t < seconds - 1.0:
        enemy, formation, count, path, params, extra = rng.choice(POOLS[chapter])
        kw = dict(extra)
        if depth and "from_depth" not in kw and formation != "single":
            kw["from_depth"] = True
        x = rng.choice(XS) if formation in ("single", "column") else 0.5
        if "spacing" not in kw and formation in ("line", "v"):
            kw["spacing"] = 36
        if enemy in ("sentinel_buoy", "trawler", "coral_turret", "herald", "volt_ray", "basilica"):
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


def build(mission_id: str, spec: dict) -> dict:
    global FILL_SCALE
    FILL_SCALE = 1.35 * spec.get("stretch", 1.0)
    rng = random.Random(f"atlantis:{mission_id}")
    events = []
    t = 0.0
    for seconds, items in spec["beats"](rng):
        for dt, ev in items:
            ev = dict(ev)
            ev["t"] = round(t + dt, 2)
            events.append(ev)
        t += seconds
    out = {"id": mission_id, "chapter": spec["chapter"], "name_key": spec["name"], "music": spec["music"],
           "scroll_speed": spec["scroll"], "backdrop": spec["backdrop"], "seed_salt": sum(map(ord, mission_id)),
           "objective": spec["objective"], "length_s": round(t, 1), "events": events}
    for key in ("secret", "route", "score_mult", "weapon_lock", "tutorial", "secret_mission"):
        if key in spec:
            out[key] = spec[key]
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
