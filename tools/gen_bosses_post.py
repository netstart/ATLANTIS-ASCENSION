"""Chefes e padrões do capítulo bônus (pós-lançamento): Fossa Hadal, abaixo do primeiro mar.

- Pescador Abissal (mini-chefe da 10-2): isca de luz que puxa o olhar e leques que se fecham.
- Matriarca Hadal (chefe da 10-3): ninho biomecânico que o Protocolo deixou no fundo. Dois braços de 5 segmentos
  (cadeia), depois a pressão da fossa (Gravity Breach para baixo) e, no fim, o canto abissal em espiral dupla.
Idempotente: troca as entradas de mesmo id em data/patterns.json e data/bosses.json (mesmo merge do Beta).

Uso: python -I tools/gen_bosses_post.py
"""
import importlib.util
import pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent

PATTERNS = [
    # Pescador Abissal: a isca dispara uma linha mirada lenta; o corpo fecha um leque largo em duas ondas.
    {"id": "angler_lure", "bullet": "orb_cyan_m", "steps": [
        {"op": "line", "count": 4, "speed": 62, "speed_step": 14, "aim": True}, {"op": "wait", "frames": 120}]},
    {"id": "angler_jaws", "bullet": "orb_violet_m", "steps": [
        {"op": "fan", "count": 11, "spread_deg": 150, "speed": 48}, {"op": "wait", "frames": 36},
        {"op": "fan", "count": 10, "spread_deg": 135, "speed": 56}, {"op": "wait", "frames": 110}]},
    # Matriarca: ovos que caem dos braços, pressão em anéis curvos e o canto em espiral dupla.
    {"id": "matriarch_eggs", "bullet": "orb_coral_l", "steps": [
        {"op": "fan", "count": 3, "spread_deg": 40, "speed": 46, "accel": 10}, {"op": "wait", "frames": 190}]},
    {"id": "matriarch_pressure", "bullet": "orb_cyan_s", "steps": [
        {"op": "ring", "count": 10, "speed": 50, "turn": 14}, {"op": "wait", "frames": 40},
        {"op": "ring", "count": 10, "speed": 50, "turn": -14, "offset_deg": 18}, {"op": "wait", "frames": 110}]},
    {"id": "matriarch_song", "bullet": "orb_violet_m", "steps": [
        {"op": "ring", "count": 4, "speed": 48}, {"op": "rotate", "deg": 13}, {"op": "wait", "frames": 12},
        {"op": "repeat", "from": 0, "times": 12}, {"op": "wait", "frames": 50},
        {"op": "aimed_fan", "count": 3, "spread_deg": 24, "speed": 92, "bullet": "needle_gold"},
        {"op": "wait", "frames": 80}]},
]


def _beta():
    spec = importlib.util.spec_from_file_location("gen_bosses_beta", ROOT / "tools" / "gen_bosses_beta.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def arms(beta):
    """Dois braços de 5 segmentos, um de cada lado (a cadeia do Beta alterna lados; aqui cada braço é um lado)."""
    parts = []
    for side, tag in ((-1, "l"), (1, "r")):
        for k, seg in enumerate(beta.chain(5, "nautolan_scout", 20, 12)):
            seg = dict(seg)
            seg["id"] = f"arm_{tag}{k + 1}"
            seg["x"] = side * (34 + 14 * k)
            seg["y"] = 26 + 16 * k
            seg["hp"] = 220
            parts.append(seg)
    return parts


def bosses(beta):
    angler = beta.mini("hadal_angler", "nautolan_frigate", "#7affd8", 6800, ["angler_lure", "angler_jaws"],
                       ["angler_jaws", "angler_lure", "matriarch_eggs"])
    matriarch = {
        "id": "hadal_matriarch", "name_key": "boss.hadal_matriarch", "sprite": "nautolan_dreadnought", "scale": 1.9,
        "tint": "#7affd8", "hp": 7800, "home_y": 100, "body_radius": 40, "points": 60000, "medals": 14, "duel": True,
        "music": "killerfishred_boss_fight", "enter_from": 170, "parts": arms(beta) + [
            {"id": "core", "x": 0, "y": 6, "radius": 15, "weak": 1.6, "active_in": ["pressure", "song"]}],
        "phases": [
            {"id": "brood", "until_hp": 0.62, "armor": 0.35, "par_s": 45, "move": {"amp": 26, "freq": 0.08},
             "intro": {"dialogue": "hadal_brood"},
             "patterns": [{"pattern": "matriarch_eggs", "anchor": f"arm_{t}{k}", "delay": 50 + 30 * k + (15 if t == "r" else 0)}
                          for t in ("l", "r") for k in (2, 4)]
             + [{"pattern": "kraken_suction", "anchor": "body", "delay": 90}]},
            {"id": "pressure", "until_hp": 0.3, "armor": 0.8, "par_s": 40, "move": {"amp": 34, "freq": 0.1},
             "intro": {"hitstop": 8, "dialogue": "hadal_pressure", "event": "gravity_breach"},
             "patterns": [{"pattern": "matriarch_pressure", "anchor": "body", "delay": 60},
                          {"pattern": "matriarch_eggs", "anchor": "arm_l5", "delay": 120}]},
            {"id": "song", "until_hp": 0.0, "armor": 1.0, "par_s": 40, "move": {"amp": 18, "freq": 0.12},
             "desperation_after_s": 35, "intro": {"hitstop": 12, "dialogue": "hadal_song"},
             "patterns": [{"pattern": "matriarch_song", "anchor": "body", "delay": 70}]}]}
    return [angler, matriarch]


if __name__ == "__main__":
    beta = _beta()
    print(beta.merge(ROOT / "data" / "patterns.json", PATTERNS), "padrões")
    print(beta.merge(ROOT / "data" / "bosses.json", bosses(beta)), "chefes")
