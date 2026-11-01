"""Chefes e padrões do Beta (plano mestre 6.3 e 6.4) acrescentados a data/patterns.json e data/bosses.json.

Mini-chefes dos capítulos 4 a 8 (2 etapas e 1 padrão assinatura cada) e os chefes de ato Sky Leviathan,
Poseidon Prime e Leviathan Protocol. Idempotente: troca as entradas de mesmo id.

Uso: python -I tools/gen_bosses_beta.py
"""
import json
import pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent

PATTERNS = [
    # Forja Viva (cap. 4): leque que acelera e brasas que caem com gravidade.
    {"id": "forge_fan", "bullet": "orb_coral_l", "steps": [
        {"op": "fan", "count": 9, "spread_deg": 90, "speed": 50, "accel": 26}, {"op": "wait", "frames": 80}]},
    {"id": "forge_embers", "bullet": "orb_gold_m", "steps": [
        {"op": "fan", "count": 5, "spread_deg": 140, "speed": 70, "angle_deg": -90, "turn": 35},
        {"op": "wait", "frames": 30}, {"op": "repeat", "from": 0, "times": 2}, {"op": "wait", "frames": 90}]},
    {"id": "forge_spiral", "bullet": "orb_coral_l", "steps": [
        {"op": "ring", "count": 5, "speed": 55}, {"op": "rotate", "deg": 15}, {"op": "wait", "frames": 12},
        {"op": "repeat", "from": 0, "times": 12}, {"op": "wait", "frames": 80}]},
    # Arquiteto (cap. 5): paredes com passagem e grade mirada.
    {"id": "architect_wall", "bullet": "orb_gold_m", "steps": [
        {"op": "fan", "count": 13, "spread_deg": 150, "speed": 46}, {"op": "wait", "frames": 70}]},
    {"id": "architect_pillars", "steps": [
        {"op": "beam", "warn_frames": 50, "frames": 40, "width": 18, "ox": -90, "oy": 20},
        {"op": "beam", "warn_frames": 50, "frames": 40, "width": 18, "ox": 90, "oy": 20}, {"op": "wait", "frames": 170}]},
    {"id": "architect_grid", "bullet": "needle_gold", "steps": [
        {"op": "line", "count": 4, "speed": 80, "speed_step": 18, "aim": True}, {"op": "wait", "frames": 20},
        {"op": "repeat", "from": 0, "times": 2}, {"op": "wait", "frames": 80}]},
    # Rainha do Gelo (cap. 6): cristais que crescem e neve que gira.
    {"id": "queen_crystal", "bullet": "orb_cyan_m", "steps": [
        {"op": "ring", "count": 12, "speed": 36, "accel": 26}, {"op": "wait", "frames": 40},
        {"op": "aimed_fan", "count": 3, "spread_deg": 20, "speed": 95, "bullet": "needle_gold"}, {"op": "wait", "frames": 70}]},
    {"id": "queen_snow", "bullet": "orb_cyan_s", "steps": [
        {"op": "ring", "count": 6, "speed": 54, "turn": 30}, {"op": "rotate", "deg": 11}, {"op": "wait", "frames": 10},
        {"op": "repeat", "from": 0, "times": 14}, {"op": "wait", "frames": 80}]},
    # Albatroz de Aço (cap. 7): asas que varrem e mergulho mirado.
    {"id": "albatross_wings", "bullet": "orb_gold_m", "steps": [
        {"op": "aimed_fan", "count": 3, "spread_deg": 18, "speed": 90, "ox": -60},
        {"op": "aimed_fan", "count": 3, "spread_deg": 18, "speed": 90, "ox": 60}, {"op": "wait", "frames": 60}]},
    {"id": "albatross_dive", "bullet": "needle_gold", "steps": [
        {"op": "aimed_fan", "count": 7, "spread_deg": 50, "speed": 120}, {"op": "wait", "frames": 90}]},
    # Portão Orbital (cap. 8): anéis defasados e feixes.
    {"id": "gate_rings", "bullet": "orb_violet_m", "steps": [
        {"op": "ring", "count": 14, "speed": 48}, {"op": "wait", "frames": 30},
        {"op": "ring", "count": 14, "speed": 48, "offset_deg": 12.857}, {"op": "wait", "frames": 100}]},
    {"id": "gate_beams", "steps": [
        {"op": "beam", "warn_frames": 55, "frames": 45, "width": 22, "ox": -60, "oy": 24},
        {"op": "wait", "frames": 60},
        {"op": "beam", "warn_frames": 55, "frames": 45, "width": 22, "ox": 60, "oy": 24}, {"op": "wait", "frames": 160}]},
    # Sky Leviathan (Ato II): segmentos soltam pares; investida; faixas.
    {"id": "leviathan_pellets", "bullet": "orb_cyan_m", "steps": [
        {"op": "aimed_fan", "count": 2, "spread_deg": 24, "speed": 70}, {"op": "wait", "frames": 150}]},
    {"id": "leviathan_lunge", "steps": [
        {"op": "beam", "warn_frames": 60, "frames": 40, "width": 30, "oy": 30}, {"op": "wait", "frames": 200}]},
    {"id": "leviathan_lanes", "steps": [
        {"op": "beam", "warn_frames": 60, "frames": 50, "width": 60, "ox": -95, "oy": 10},
        {"op": "beam", "warn_frames": 60, "frames": 50, "width": 60, "ox": 0, "oy": 10}, {"op": "wait", "frames": 140},
        {"op": "beam", "warn_frames": 60, "frames": 50, "width": 60, "ox": 0, "oy": 10},
        {"op": "beam", "warn_frames": 60, "frames": 50, "width": 60, "ox": 95, "oy": 10}, {"op": "wait", "frames": 140}]},
    {"id": "leviathan_head_fans", "bullet": "orb_violet_m", "steps": [
        {"op": "fan", "count": 7, "spread_deg": 80, "speed": 70}, {"op": "rotate", "deg": 9}, {"op": "wait", "frames": 24},
        {"op": "repeat", "from": 0, "times": 3}, {"op": "wait", "frames": 70}]},
    # Poseidon Prime (Ato III): anéis de escudo, balas curvas, tridente, dança final.
    {"id": "poseidon_ring", "bullet": "orb_gold_m", "steps": [
        {"op": "ring", "count": 10, "speed": 50}, {"op": "rotate", "deg": 18}, {"op": "wait", "frames": 120}]},
    {"id": "poseidon_curves", "bullet": "orb_cyan_m", "steps": [
        {"op": "ring", "count": 8, "speed": 62, "turn": 18}, {"op": "wait", "frames": 30},
        {"op": "ring", "count": 8, "speed": 62, "turn": -18, "offset_deg": 22.5}, {"op": "wait", "frames": 90}]},
    {"id": "poseidon_trident", "steps": [
        {"op": "beam", "warn_frames": 60, "frames": 45, "width": 20, "ox": -70, "oy": 30},
        {"op": "beam", "warn_frames": 60, "frames": 45, "width": 20, "oy": 30},
        {"op": "beam", "warn_frames": 60, "frames": 45, "width": 20, "ox": 70, "oy": 30}, {"op": "wait", "frames": 180}]},
    {"id": "poseidon_waves", "bullet": "orb_gold_m", "steps": [
        {"op": "fan", "count": 11, "spread_deg": 120, "speed": 52}, {"op": "wait", "frames": 45},
        {"op": "fan", "count": 10, "spread_deg": 110, "speed": 52}, {"op": "wait", "frames": 70}]},
    {"id": "poseidon_dance", "bullet": "needle_gold", "steps": [
        {"op": "aimed", "speed": 130}, {"op": "wait", "frames": 14}, {"op": "repeat", "from": 0, "times": 4},
        {"op": "line", "count": 3, "speed": 70, "speed_step": 20, "aim": True}, {"op": "wait", "frames": 60}]},
    # Leviathan Protocol (Ato IV): colagem das 3 facções, arquitetura com gravidade, núcleo.
    {"id": "protocol_drones", "bullet": "orb_cyan_m", "steps": [
        {"op": "aimed_fan", "count": 5, "spread_deg": 40, "speed": 85}, {"op": "wait", "frames": 90}]},
    {"id": "protocol_guard", "bullet": "orb_gold_m", "steps": [
        {"op": "ring", "count": 12, "speed": 52}, {"op": "rotate", "deg": 15}, {"op": "wait", "frames": 110}]},
    {"id": "protocol_bio", "bullet": "orb_violet_m", "steps": [
        {"op": "fan", "count": 6, "spread_deg": 100, "speed": 30, "accel": 30}, {"op": "wait", "frames": 120}]},
    {"id": "protocol_walls", "bullet": "orb_cyan_s", "steps": [
        {"op": "fan", "count": 16, "spread_deg": 170, "speed": 44}, {"op": "rotate", "deg": 6}, {"op": "wait", "frames": 60}]},
    {"id": "protocol_core", "bullet": "orb_coral_l", "steps": [
        {"op": "ring", "count": 6, "speed": 50}, {"op": "rotate", "deg": 10}, {"op": "wait", "frames": 14},
        {"op": "repeat", "from": 0, "times": 10}, {"op": "wait", "frames": 40},
        {"op": "aimed_fan", "count": 5, "spread_deg": 30, "speed": 100, "bullet": "needle_gold"}, {"op": "wait", "frames": 70}]},
]


def mini(id_, sprite, tint, hp, p1, p2, music=""):
    return {"id": id_, "name_key": f"boss.{id_}", "sprite": sprite, "scale": 1.5, "tint": tint, "hp": hp, "home_y": 96,
            "body_radius": 34, "points": 14000, "medals": 6, "duel": False, "music": music,
            "phases": [
                {"id": "first", "until_hp": 0.5, "armor": 1.0, "par_s": 25, "move": {"amp": 44, "freq": 0.12},
                 "patterns": [{"pattern": p, "anchor": "body", "delay": 50 + 30 * k} for k, p in enumerate(p1)]},
                {"id": "second", "until_hp": 0.0, "armor": 1.0, "par_s": 25, "move": {"amp": 22, "freq": 0.1},
                 "intro": {"hitstop": 8},
                 "patterns": [{"pattern": p, "anchor": "body", "delay": 60 + 40 * k} for k, p in enumerate(p2)]}]}


def chain(n, sprite, spacing, sway):
    parts = []
    for k in range(n):
        side = -1 if k % 2 == 0 else 1
        parts.append({"id": f"seg{k + 1}", "sprite": sprite, "part_scale": 0.9 - 0.04 * k, "chain": True,
                      "x": side * (18 + 4 * k), "y": 30 + spacing * k, "hp": 260, "radius": 10, "share": 0.04,
                      "leak": 0.25, "sway": sway + 3 * k, "freq": 0.22, "phase": 0.09 * k, "points": 1500})
    return parts


BOSSES = [
    mini("forge", "klaed_battlecruiser", "#ffb08a", 5200, ["forge_fan", "forge_embers"], ["forge_spiral", "forge_fan"]),
    mini("architect", "nairan_frigate", "#c8d6ff", 5600, ["architect_wall", "architect_pillars"],
         ["architect_grid", "architect_wall"]),
    mini("ice_queen", "nautolan_frigate", "#bff4ff", 6000, ["queen_crystal"], ["queen_snow", "queen_crystal"]),
    mini("steel_albatross", "klaed_frigate", "#d8d8e8", 6400, ["albatross_wings"], ["albatross_dive", "albatross_wings"]),
    mini("orbital_gate", "klaed_dreadnought", "#a0ffd0", 7000, ["gate_rings"], ["gate_beams", "gate_rings"]),
    {"id": "sky_leviathan", "name_key": "boss.sky_leviathan", "sprite": "nautolan_battlecruiser", "scale": 1.5,
     "tint": "#bfe6ff", "hp": 6800, "home_y": 84, "body_radius": 32, "points": 40000, "medals": 10, "duel": True,
     "music": "hydrogene_strong_boss", "enter_from": 160, "parts": chain(8, "nautolan_scout", 22, 16),
     "phases": [
         {"id": "crossing", "until_hp": 0.6, "armor": 0.4, "par_s": 45, "move": {"amp": 70, "freq": 0.09},
          "patterns": [{"pattern": "leviathan_pellets", "anchor": f"seg{k}", "delay": 40 + 25 * k} for k in range(1, 9)]
          + [{"pattern": "leviathan_lunge", "anchor": "body", "delay": 120}]},
         {"id": "storm", "until_hp": 0.3, "armor": 0.8, "par_s": 40, "move": {"amp": 30, "freq": 0.07},
          "intro": {"hitstop": 8, "dialogue": "sky_leviathan_storm"},
          "patterns": [{"pattern": "leviathan_lanes", "anchor": "body", "delay": 60},
                       {"pattern": "leviathan_pellets", "anchor": "seg8", "delay": 90}]},
         {"id": "tail", "until_hp": 0.0, "armor": 1.0, "par_s": 40, "move": {"amp": 50, "freq": 0.14},
          "desperation_after_s": 35, "intro": {"hitstop": 10},
          "patterns": [{"pattern": "leviathan_head_fans", "anchor": "body", "delay": 60},
                       {"pattern": "leviathan_lunge", "anchor": "body", "delay": 150}]}]},
    {"id": "poseidon_prime", "name_key": "boss.poseidon_prime", "sprite": "nairan_dreadnought", "scale": 1.7,
     "tint": "#ffe08a", "hp": 7400, "home_y": 100, "body_radius": 38, "points": 50000, "medals": 12, "duel": True,
     "music": "junkala_epic_boss_battle", "enter_from": 160,
     "parts": [
         {"id": "ring1", "ring": True, "x": -70, "y": 34, "hp": 520, "radius": 13, "share": 0.06, "leak": 0.2,
          "sway": 10, "freq": 0.2, "phase": 0.0, "points": 3000, "active_in": ["barriers", "gravity"]},
         {"id": "ring2", "ring": True, "x": 0, "y": 58, "hp": 520, "radius": 13, "share": 0.06, "leak": 0.2,
          "sway": 10, "freq": 0.2, "phase": 0.33, "points": 3000, "active_in": ["barriers", "gravity"]},
         {"id": "ring3", "ring": True, "x": 70, "y": 34, "hp": 520, "radius": 13, "share": 0.06, "leak": 0.2,
          "sway": 10, "freq": 0.2, "phase": 0.66, "points": 3000, "active_in": ["barriers", "gravity"]},
         {"id": "core", "x": 0, "y": 6, "radius": 14, "weak": 1.6, "active_in": ["trident", "guardian"]}],
     "phases": [
         {"id": "barriers", "until_hp": 0.72, "armor": 0.3, "par_s": 40, "move": {"amp": 26, "freq": 0.08},
          "patterns": [{"pattern": "poseidon_ring", "anchor": "ring1", "delay": 50},
                       {"pattern": "poseidon_ring", "anchor": "ring2", "delay": 90},
                       {"pattern": "poseidon_ring", "anchor": "ring3", "delay": 130}]},
         {"id": "gravity", "until_hp": 0.45, "armor": 0.6, "par_s": 40, "move": {"amp": 34, "freq": 0.1},
          "intro": {"hitstop": 8, "dialogue": "poseidon_gravity", "event": "gravity_breach"},
          "patterns": [{"pattern": "poseidon_curves", "anchor": "body", "delay": 60}]},
         {"id": "trident", "until_hp": 0.2, "armor": 1.0, "par_s": 40, "move": {"amp": 20, "freq": 0.1},
          "intro": {"hitstop": 8},
          "patterns": [{"pattern": "poseidon_trident", "anchor": "body", "delay": 60},
                       {"pattern": "poseidon_waves", "anchor": "body", "delay": 100}]},
         {"id": "guardian", "until_hp": 0.0, "armor": 1.0, "par_s": 35, "move": {"amp": 40, "freq": 0.15},
          "desperation_after_s": 30, "intro": {"hitstop": 10, "dialogue": "poseidon_guardian"},
          "patterns": [{"pattern": "poseidon_dance", "anchor": "body", "delay": 60}]}]},
    {"id": "leviathan_protocol", "name_key": "boss.leviathan_protocol", "sprite": "klaed_dreadnought", "scale": 2.0,
     "tint": "#ff9da0", "hp": 7600, "home_y": 100, "body_radius": 42, "points": 80000, "medals": 16, "duel": True,
     "ending": True, "music": "hydrogene_strong_boss", "enter_from": 180,
     "parts": [
         {"id": "drone_core", "sprite": "klaed_battlecruiser", "part_scale": 0.8, "x": -78, "y": 30, "hp": 600,
          "radius": 16, "share": 0.07, "leak": 0.2, "sway": 8, "freq": 0.2, "phase": 0.0, "points": 5000,
          "active_in": ["collage"]},
         {"id": "guard_core", "sprite": "nairan_battlecruiser", "part_scale": 0.8, "x": 0, "y": 64, "hp": 600,
          "radius": 16, "share": 0.07, "leak": 0.2, "sway": 8, "freq": 0.2, "phase": 0.33, "points": 5000,
          "active_in": ["collage"]},
         {"id": "bio_core", "sprite": "nautolan_battlecruiser", "part_scale": 0.8, "x": 78, "y": 30, "hp": 600,
          "radius": 16, "share": 0.07, "leak": 0.2, "sway": 8, "freq": 0.2, "phase": 0.66, "points": 5000,
          "active_in": ["collage"]},
         {"id": "core", "x": 0, "y": 4, "radius": 16, "weak": 1.5, "active_in": ["core"]}],
     "phases": [
         {"id": "collage", "until_hp": 0.66, "armor": 0.45, "par_s": 50, "move": {"amp": 24, "freq": 0.08},
          "intro": {"dialogue": "protocol_collage"},
          "patterns": [{"pattern": "protocol_drones", "anchor": "drone_core", "delay": 50},
                       {"pattern": "protocol_guard", "anchor": "guard_core", "delay": 90},
                       {"pattern": "protocol_bio", "anchor": "bio_core", "delay": 130}]},
         {"id": "architecture", "until_hp": 0.33, "armor": 1.0, "par_s": 45, "move": {"amp": 36, "freq": 0.1},
          "intro": {"hitstop": 10, "dialogue": "protocol_architecture", "event": "gravity_flip"},
          "patterns": [{"pattern": "protocol_walls", "anchor": "body", "delay": 60},
                       {"pattern": "protocol_drones", "anchor": "body", "delay": 110}]},
         {"id": "core", "until_hp": 0.0, "armor": 1.0, "par_s": 45, "move": {"amp": 14, "freq": 0.12}, "learn": True,
          "desperation_after_s": 40, "intro": {"hitstop": 12, "dialogue": "protocol_core"},
          "patterns": [{"pattern": "protocol_core", "anchor": "body", "delay": 70}]}]},
]


def merge(path: pathlib.Path, rows: list) -> int:
    data = json.loads(path.read_text(encoding="utf-8"))
    ids = {r["id"] for r in rows}
    data = [r for r in data if r["id"] not in ids] + rows
    text = "[\n" + ",\n".join("\t" + json.dumps(r, ensure_ascii=False) for r in data) + "\n]\n"
    path.write_text(text, encoding="utf-8", newline="\n")
    return len(data)


if __name__ == "__main__":
    print(merge(ROOT / "data" / "patterns.json", PATTERNS), "padrões")
    print(merge(ROOT / "data" / "bosses.json", BOSSES), "chefes")
