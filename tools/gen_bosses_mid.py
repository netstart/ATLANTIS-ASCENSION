"""Chefes intermediários e mini-chefes de elite (1.10): toda fase tem um chefe no meio e mini-chefes ao longo dela.

- Chefe intermediário (`mid_*`): um por capítulo, no meio de toda missão do capítulo. Três etapas, peças que dá para
  destruir (torres, cabeças, tentáculos) e um padrão assinatura por etapa. Mais curto que o chefe de ato, mais
  encorpado que o mini-chefe do fim da 2ª missão.
- Mini-chefe de elite (`elite_*`): dez desenhos, cada capítulo usa dois (um a 1/4 e outro a 3/4 da missão). Cada
  desenho ganha uma variante por capítulo (`elite_<nome>_c<N>`) com o casco escalado pela curva do capítulo; o nome
  na tela é o mesmo (`boss.elite_<nome>`).

Os padrões usam só a DSL existente (fan, ring, aimed, aimed_fan, line, beam, rotate, repeat, wait) e as balas do
jogo. Feixes avisam ≥ 0,5 s antes (teste de leitura). Idempotente: troca as entradas de mesmo id em
data/patterns.json e data/bosses.json (mesmo merge do Beta).

Uso: python -I tools/gen_bosses_mid.py
"""
import importlib.util
import pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent

# Casco de referência por capítulo (o do mini-chefe da 2ª missão); chefe intermediário = 0,3x, elite = 0,15x.
# Medido com o bot (tests/boss_timing.gd): elite ~15-25 s, chefe intermediário ~30-45 s.
CHAPTER_HP = {1: 2100, 2: 2300, 3: 4600, 4: 5200, 5: 5600, 6: 6000, 7: 6400, 8: 7000, 9: 7200, 10: 6800}
MID_HP = 0.3
ELITE_HP = 0.15


def wait(frames):
    return {"op": "wait", "frames": frames}


PATTERNS = [
    # --- Chefes intermediários ------------------------------------------------------------------
    # 1 Arrastão Arpoador: arpões mirados das torres e rede em leque.
    {"id": "mid_harpoon_shot", "bullet": "needle_gold", "steps": [
        {"op": "aimed", "speed": 105}, wait(16), {"op": "repeat", "from": 0, "times": 2}, wait(110)]},
    {"id": "mid_harpoon_net", "bullet": "orb_cyan_m", "steps": [
        {"op": "fan", "count": 9, "spread_deg": 100, "speed": 48}, wait(30),
        {"op": "fan", "count": 8, "spread_deg": 90, "speed": 56}, wait(110)]},
    {"id": "mid_harpoon_reel", "bullet": "orb_cyan_s", "steps": [
        {"op": "ring", "count": 8, "speed": 46, "turn": 20}, {"op": "rotate", "deg": 14}, wait(16),
        {"op": "repeat", "from": 0, "times": 5}, wait(90)]},
    # 2 Oráculo de Pérola: pérolas em órbita, anéis que se abrem, olhar mirado.
    {"id": "mid_oracle_pearls", "bullet": "orb_gold_m", "steps": [
        {"op": "ring", "count": 6, "speed": 40, "accel": 12}, wait(130)]},
    {"id": "mid_oracle_bloom", "bullet": "orb_violet_m", "steps": [
        {"op": "ring", "count": 12, "speed": 34, "accel": 22}, wait(40),
        {"op": "ring", "count": 12, "speed": 34, "accel": 22, "offset_deg": 15}, wait(120)]},
    {"id": "mid_oracle_gaze", "bullet": "needle_gold", "steps": [
        {"op": "aimed_fan", "count": 5, "spread_deg": 36, "speed": 90}, wait(26),
        {"op": "repeat", "from": 0, "times": 1}, wait(110)]},
    # 3 Raia-Trovão: feixes das asas, chuva elétrica, giro de faíscas.
    {"id": "mid_manta_wings", "steps": [
        {"op": "beam", "warn_frames": 50, "frames": 36, "width": 16, "ox": -64, "oy": 16},
        {"op": "beam", "warn_frames": 50, "frames": 36, "width": 16, "ox": 64, "oy": 16}, wait(170)]},
    {"id": "mid_manta_rain", "bullet": "orb_cyan_s", "steps": [
        {"op": "fan", "count": 7, "spread_deg": 150, "speed": 64, "angle_deg": -90, "turn": 40}, wait(26),
        {"op": "repeat", "from": 0, "times": 2}, wait(100)]},
    {"id": "mid_manta_spin", "bullet": "orb_violet_m", "steps": [
        {"op": "ring", "count": 4, "speed": 58}, {"op": "rotate", "deg": 17}, wait(9),
        {"op": "repeat", "from": 0, "times": 14}, wait(90)]},
    # 4 Caranguejo de Magma: pinças em leque, bolhas que sobem e caem, jato de lava.
    {"id": "mid_crab_claws", "bullet": "orb_coral_l", "steps": [
        {"op": "aimed_fan", "count": 3, "spread_deg": 20, "speed": 70, "ox": -46},
        {"op": "aimed_fan", "count": 3, "spread_deg": 20, "speed": 70, "ox": 46}, wait(100)]},
    {"id": "mid_crab_bubbles", "bullet": "orb_gold_m", "steps": [
        {"op": "fan", "count": 6, "spread_deg": 120, "speed": 60, "angle_deg": -90, "turn": 30}, wait(140)]},
    {"id": "mid_crab_jet", "steps": [
        {"op": "beam", "warn_frames": 55, "frames": 40, "width": 26, "oy": 26}, wait(60),
        {"op": "fan", "count": 10, "spread_deg": 110, "speed": 50, "bullet": "orb_coral_l"}, wait(120)]},
    # 5 Guardião da Torre: grade de agulhas, paredes com fresta, holofotes.
    {"id": "mid_spire_grid", "bullet": "needle_gold", "steps": [
        {"op": "line", "count": 5, "speed": 70, "speed_step": 16, "aim": True}, wait(24),
        {"op": "repeat", "from": 0, "times": 1}, wait(110)]},
    {"id": "mid_spire_wall", "bullet": "orb_gold_m", "steps": [
        {"op": "fan", "count": 11, "spread_deg": 150, "speed": 42}, wait(150)]},
    {"id": "mid_spire_lights", "steps": [
        {"op": "beam", "warn_frames": 50, "frames": 40, "width": 18, "ox": -40, "oy": 20}, wait(50),
        {"op": "beam", "warn_frames": 50, "frames": 40, "width": 18, "ox": 40, "oy": 20}, wait(160)]},
    # 6 Serpente de Gelo: flocos dos segmentos, sopro gelado, nevasca em espiral.
    {"id": "mid_serpent_flakes", "bullet": "orb_cyan_m", "steps": [
        {"op": "aimed_fan", "count": 2, "spread_deg": 26, "speed": 66}, wait(170)]},
    {"id": "mid_serpent_breath", "bullet": "orb_cyan_s", "steps": [
        {"op": "fan", "count": 11, "spread_deg": 70, "speed": 60, "accel": 18}, wait(140)]},
    {"id": "mid_serpent_blizzard", "bullet": "orb_cyan_s", "steps": [
        {"op": "ring", "count": 5, "speed": 50, "turn": 26}, {"op": "rotate", "deg": 12}, wait(10),
        {"op": "repeat", "from": 0, "times": 12}, wait(90)]},
    # 7 Porta-Tempestade: drones dos hangares, rajada cruzada, olho do furacão.
    {"id": "mid_carrier_drones", "bullet": "orb_violet_m", "steps": [
        {"op": "aimed_fan", "count": 3, "spread_deg": 30, "speed": 80}, wait(140)]},
    {"id": "mid_carrier_cross", "bullet": "orb_gold_m", "steps": [
        {"op": "fan", "count": 6, "spread_deg": 60, "speed": 70, "angle_deg": 60}, wait(20),
        {"op": "fan", "count": 6, "spread_deg": 60, "speed": 70, "angle_deg": 120}, wait(110)]},
    {"id": "mid_carrier_eye", "bullet": "orb_violet_m", "steps": [
        {"op": "ring", "count": 16, "speed": 44}, wait(30),
        {"op": "aimed_fan", "count": 5, "spread_deg": 30, "speed": 96, "bullet": "needle_gold"}, wait(110)]},
    # 8 Hidra Satélite: três cabeças miradas, anéis defasados, raio do núcleo.
    {"id": "mid_hydra_head", "bullet": "needle_gold", "steps": [
        {"op": "aimed", "speed": 92}, wait(18), {"op": "repeat", "from": 0, "times": 1}, wait(170)]},
    {"id": "mid_hydra_rings", "bullet": "orb_violet_m", "steps": [
        {"op": "ring", "count": 10, "speed": 50}, wait(24),
        {"op": "ring", "count": 10, "speed": 50, "offset_deg": 18}, wait(120)]},
    {"id": "mid_hydra_core", "steps": [
        {"op": "beam", "warn_frames": 60, "frames": 46, "width": 24, "oy": 24}, wait(40),
        {"op": "ring", "count": 12, "speed": 46, "bullet": "orb_cyan_m"}, wait(130)]},
    # 9 Sentinela do Protocolo: colagem das facções em pequena escala.
    {"id": "mid_sentinel_scan", "bullet": "orb_cyan_m", "steps": [
        {"op": "aimed_fan", "count": 5, "spread_deg": 44, "speed": 84}, wait(100)]},
    {"id": "mid_sentinel_lattice", "bullet": "orb_gold_m", "steps": [
        {"op": "fan", "count": 12, "spread_deg": 150, "speed": 46}, {"op": "rotate", "deg": 7}, wait(40),
        {"op": "repeat", "from": 0, "times": 1}, wait(110)]},
    {"id": "mid_sentinel_purge", "bullet": "orb_violet_m", "steps": [
        {"op": "ring", "count": 6, "speed": 52}, {"op": "rotate", "deg": 11}, wait(12),
        {"op": "repeat", "from": 0, "times": 9}, wait(50),
        {"op": "aimed_fan", "count": 3, "spread_deg": 20, "speed": 100, "bullet": "needle_gold"}, wait(80)]},
    # 10 Água-viva Abissal: tentáculos pulsam, sino de luz, nuvem de esporos.
    {"id": "mid_jelly_pulse", "bullet": "orb_cyan_s", "steps": [
        {"op": "fan", "count": 3, "spread_deg": 30, "speed": 44, "accel": 14}, wait(180)]},
    {"id": "mid_jelly_bell", "bullet": "orb_violet_m", "steps": [
        {"op": "ring", "count": 14, "speed": 30, "accel": 24}, wait(150)]},
    {"id": "mid_jelly_spores", "bullet": "orb_cyan_m", "steps": [
        {"op": "ring", "count": 7, "speed": 46, "turn": -22}, {"op": "rotate", "deg": 16}, wait(14),
        {"op": "repeat", "from": 0, "times": 8}, wait(100)]},
    # --- Mini-chefes de elite (dois padrões cada) ------------------------------------------------
    {"id": "elite_lancer_thrust", "bullet": "needle_gold", "steps": [
        {"op": "aimed_fan", "count": 3, "spread_deg": 16, "speed": 110}, wait(80)]},
    {"id": "elite_lancer_sweep", "bullet": "orb_cyan_m", "steps": [
        {"op": "fan", "count": 7, "spread_deg": 90, "speed": 56}, wait(100)]},
    {"id": "elite_bomber_drop", "bullet": "orb_coral_l", "steps": [
        {"op": "fan", "count": 4, "spread_deg": 60, "speed": 40, "accel": 20}, wait(110)]},
    {"id": "elite_bomber_burst", "bullet": "orb_gold_m", "steps": [
        {"op": "ring", "count": 10, "speed": 48}, wait(120)]},
    {"id": "elite_siren_song", "bullet": "orb_violet_m", "steps": [
        {"op": "ring", "count": 5, "speed": 50, "turn": 24}, {"op": "rotate", "deg": 20}, wait(14),
        {"op": "repeat", "from": 0, "times": 4}, wait(100)]},
    {"id": "elite_siren_call", "bullet": "needle_gold", "steps": [
        {"op": "line", "count": 3, "speed": 70, "speed_step": 18, "aim": True}, wait(100)]},
    {"id": "elite_ram_charge", "steps": [
        {"op": "beam", "warn_frames": 45, "frames": 30, "width": 20, "oy": 20}, wait(120)]},
    {"id": "elite_ram_shards", "bullet": "orb_coral_l", "steps": [
        {"op": "fan", "count": 8, "spread_deg": 130, "speed": 52}, wait(100)]},
    {"id": "elite_ink_cloud", "bullet": "orb_violet_m", "steps": [
        {"op": "fan", "count": 9, "spread_deg": 80, "speed": 36, "accel": 16}, wait(120)]},
    {"id": "elite_ink_torpedo", "bullet": "needle_gold", "steps": [
        {"op": "aimed", "speed": 120}, wait(20), {"op": "repeat", "from": 0, "times": 2}, wait(90)]},
    {"id": "elite_shell_spin", "bullet": "orb_gold_m", "steps": [
        {"op": "ring", "count": 3, "speed": 54}, {"op": "rotate", "deg": 24}, wait(10),
        {"op": "repeat", "from": 0, "times": 8}, wait(100)]},
    {"id": "elite_shell_snap", "bullet": "orb_cyan_m", "steps": [
        {"op": "aimed_fan", "count": 5, "spread_deg": 50, "speed": 80}, wait(100)]},
    {"id": "elite_eel_arc", "bullet": "orb_cyan_s", "steps": [
        {"op": "fan", "count": 6, "spread_deg": 140, "speed": 62, "turn": 36}, wait(26),
        {"op": "fan", "count": 6, "spread_deg": 140, "speed": 62, "turn": -36}, wait(100)]},
    {"id": "elite_eel_bolt", "steps": [
        {"op": "beam", "warn_frames": 45, "frames": 30, "width": 14, "ox": -30, "oy": 14},
        {"op": "beam", "warn_frames": 45, "frames": 30, "width": 14, "ox": 30, "oy": 14}, wait(130)]},
    {"id": "elite_glass_prism", "bullet": "orb_violet_m", "steps": [
        {"op": "ring", "count": 9, "speed": 40, "accel": 18}, wait(110)]},
    {"id": "elite_glass_shard", "bullet": "needle_gold", "steps": [
        {"op": "aimed_fan", "count": 4, "spread_deg": 28, "speed": 96}, wait(90)]},
    {"id": "elite_charge_mines", "bullet": "orb_coral_l", "steps": [
        {"op": "fan", "count": 5, "spread_deg": 100, "speed": 30, "accel": 22}, wait(130)]},
    {"id": "elite_charge_blast", "bullet": "orb_gold_m", "steps": [
        {"op": "ring", "count": 12, "speed": 44}, wait(14), {"op": "ring", "count": 12, "speed": 44, "offset_deg": 15},
        wait(120)]},
    {"id": "elite_echo_mirror", "bullet": "orb_cyan_m", "steps": [
        {"op": "aimed_fan", "count": 2, "spread_deg": 30, "speed": 90, "ox": -24},
        {"op": "aimed_fan", "count": 2, "spread_deg": 30, "speed": 90, "ox": 24}, wait(90)]},
    {"id": "elite_echo_ring", "bullet": "orb_violet_m", "steps": [
        {"op": "ring", "count": 8, "speed": 50}, {"op": "rotate", "deg": 22}, wait(20),
        {"op": "repeat", "from": 0, "times": 2}, wait(100)]},
]


def turret(id_, sprite, x, y, hp, phases, scale=0.7, radius=11):
    """Peça fixa (torre, pinça, cabeça) que balança de leve e atira enquanto existe."""
    return {"id": id_, "sprite": sprite, "part_scale": scale, "x": x, "y": y, "hp": hp, "radius": radius,
            "share": 0.05, "leak": 0.25, "sway": 6, "freq": 0.2, "phase": 0.25 * (x > 0), "points": 1500,
            "active_in": phases}


def mid(ch, id_, sprite, tint, scale, radius, phases, parts=None, chain=None, hp_scale=1.0):
    """Chefe intermediário: 3 etapas (55% / 25% / 0%), cada uma com par de 18 s."""
    # hp_scale: ajuste fino medido com o bot (capítulos em que o padrão já cobra muita esquiva).
    hp = int(round(CHAPTER_HP[ch] * MID_HP * hp_scale, -2))
    marks = [0.55, 0.25, 0.0]
    moves = [{"amp": 30, "freq": 0.1}, {"amp": 22, "freq": 0.09}, {"amp": 14, "freq": 0.12}]
    out = {"id": f"mid_{id_}", "name_key": f"boss.mid_{id_}", "sprite": sprite, "scale": scale, "tint": tint,
           "hp": hp, "home_y": 92, "body_radius": radius, "points": 20000 + 2000 * ch, "medals": 8, "duel": False,
           "music": "", "enter_from": 120, "tier": "mid", "drops": ["power", "power", "bomb"], "phases": []}
    names = ["open", "press", "fury"]
    for k, pats in enumerate(phases):
        ph = {"id": names[k], "until_hp": marks[k], "armor": 0.7 if k == 0 and parts else 1.0, "par_s": 18,
              "move": moves[k], "patterns": [{"pattern": p, "anchor": a, "delay": 40 + 30 * j}
                                             for j, (p, a) in enumerate(pats)]}
        if k:
            ph["intro"] = {"hitstop": 6 + 2 * k}
        out["phases"].append(ph)
    if chain:
        parts = (parts or []) + chain
    if parts:
        out["parts"] = parts
    return out


def mids(beta):
    seg = lambda n, sprite, spacing, sway, hp: [dict(s, hp=hp, active_in=["open", "press"])
                                               for s in beta.chain(n, sprite, spacing, sway)]
    return [
        mid(1, "harpoon_trawler", "klaed_bomber", "#9fe8ff", 1.6, 26,
            [[("mid_harpoon_shot", "gun_l"), ("mid_harpoon_shot", "gun_r")], [("mid_harpoon_net", "body")],
             [("mid_harpoon_reel", "body"), ("mid_harpoon_shot", "body")]],
            parts=[turret("gun_l", "klaed_scout", -40, 20, 180, ["open", "press"]),
                   turret("gun_r", "klaed_scout", 40, 20, 180, ["open", "press"])]),
        mid(2, "pearl_oracle", "nairan_support", "#ffe9b0", 1.7, 26,
            [[("mid_oracle_pearls", "orb_l"), ("mid_oracle_pearls", "orb_r")], [("mid_oracle_bloom", "body")],
             [("mid_oracle_gaze", "body"), ("mid_oracle_bloom", "body")]],
            parts=[dict(turret("orb_l", "nairan_scout", -48, 30, 200, ["open", "press"]), ring=True),
                   dict(turret("orb_r", "nairan_scout", 48, 30, 200, ["open", "press"]), ring=True)]),
        mid(3, "thunder_manta", "nautolan_bomber", "#c9f0ff", 1.9, 30,
            [[("mid_manta_rain", "body")], [("mid_manta_wings", "body"), ("mid_manta_rain", "body")],
             [("mid_manta_spin", "body"), ("mid_manta_wings", "body")]]),
        mid(4, "magma_crab", "klaed_support", "#ffb08a", 1.8, 28,
            [[("mid_crab_claws", "body")], [("mid_crab_bubbles", "claw_l"), ("mid_crab_bubbles", "claw_r")],
             [("mid_crab_jet", "body"), ("mid_crab_claws", "body")]],
            parts=[turret("claw_l", "klaed_fighter", -50, 26, 320, ["open", "press"], 0.8, 13),
                   turret("claw_r", "klaed_fighter", 50, 26, 320, ["open", "press"], 0.8, 13)]),
        mid(5, "spire_warden", "nairan_battlecruiser", "#e0e8ff", 1.4, 32,
            [[("mid_spire_grid", "body")], [("mid_spire_wall", "body"), ("mid_spire_lights", "body")],
             [("mid_spire_grid", "body"), ("mid_spire_wall", "body")]], hp_scale=0.7),
        mid(6, "frost_serpent", "nautolan_torpedo", "#bff4ff", 1.8, 24,
            [[("mid_serpent_flakes", f"seg{k}") for k in (2, 4, 6)], [("mid_serpent_breath", "body")],
             [("mid_serpent_blizzard", "body"), ("mid_serpent_breath", "body")]],
            chain=seg(6, "nautolan_scout", 20, 14, 180)),
        mid(7, "storm_carrier", "nairan_bomber", "#d8d8f0", 1.9, 30,
            [[("mid_carrier_drones", "bay_l"), ("mid_carrier_drones", "bay_r")], [("mid_carrier_cross", "body")],
             [("mid_carrier_eye", "body"), ("mid_carrier_drones", "body")]], hp_scale=0.8,
            parts=[turret("bay_l", "nairan_fighter", -46, 22, 380, ["open", "press"]),
                   turret("bay_r", "nairan_fighter", 46, 22, 380, ["open", "press"])]),
        mid(8, "satellite_hydra", "klaed_battlecruiser", "#a0ffd0", 1.4, 30,
            [[("mid_hydra_head", "head_l"), ("mid_hydra_head", "head_c"), ("mid_hydra_head", "head_r")],
             [("mid_hydra_rings", "body")], [("mid_hydra_core", "body"), ("mid_hydra_rings", "body")]],
            parts=[turret("head_l", "klaed_fighter", -54, 34, 360, ["open", "press"]),
                   turret("head_c", "klaed_fighter", 0, 52, 360, ["open", "press"]),
                   turret("head_r", "klaed_fighter", 54, 34, 360, ["open", "press"])]),
        mid(9, "protocol_sentinel", "nairan_torpedo", "#ff9da0", 1.9, 26,
            [[("mid_sentinel_scan", "body")], [("mid_sentinel_lattice", "body")],
             [("mid_sentinel_purge", "body")]], hp_scale=0.8),
        mid(10, "abyss_jelly", "nautolan_support", "#7affd8", 1.8, 28,
            [[("mid_jelly_pulse", f"seg{k}") for k in (1, 3, 5)], [("mid_jelly_bell", "body")],
             [("mid_jelly_spores", "body"), ("mid_jelly_bell", "body")]],
            chain=seg(6, "nautolan_scout", 18, 10, 200)),
    ]


# Desenhos de elite: id, sprite, tint, escala, raio, (padrão 1, padrão 2).
ELITES = [
    ("reef_lancer", "klaed_fighter", "#9fe8ff", 2.2, 20, ("elite_lancer_thrust", "elite_lancer_sweep")),
    ("brine_bomber", "klaed_bomber", "#c0ffd0", 2.0, 22, ("elite_bomber_drop", "elite_bomber_burst")),
    ("siren_drone", "nairan_scout", "#f0c0ff", 2.4, 18, ("elite_siren_song", "elite_siren_call")),
    ("coral_ram", "nairan_fighter", "#ffb0a0", 2.2, 20, ("elite_ram_charge", "elite_ram_shards")),
    ("ink_torpedo", "klaed_torpedo", "#c8b0ff", 2.2, 20, ("elite_ink_cloud", "elite_ink_torpedo")),
    ("shell_turret", "nautolan_fighter", "#ffe08a", 2.2, 20, ("elite_shell_spin", "elite_shell_snap")),
    ("volt_eel", "nautolan_scout", "#a8ecff", 2.4, 18, ("elite_eel_arc", "elite_eel_bolt")),
    ("glass_wing", "nairan_bomber", "#e8f8ff", 2.0, 22, ("elite_glass_prism", "elite_glass_shard")),
    ("depth_charger", "nautolan_torpedo", "#ff9da0", 2.0, 22, ("elite_charge_mines", "elite_charge_blast")),
    ("echo_twin", "klaed_scout", "#a0ffd0", 2.4, 18, ("elite_echo_mirror", "elite_echo_ring")),
]


def elites_of(ch):
    """Os dois desenhos de elite do capítulo: o do capítulo e o do seguinte (o 10 volta ao 1)."""
    return ELITES[ch - 1][0], ELITES[ch % len(ELITES)][0]


def elite(ch, design):
    id_, sprite, tint, scale, radius, (p1, p2) = design
    hp = int(round(CHAPTER_HP[ch] * ELITE_HP, -2))
    return {"id": f"elite_{id_}_c{ch}", "name_key": f"boss.elite_{id_}", "sprite": sprite, "scale": scale,
            "tint": tint, "hp": hp, "home_y": 100, "body_radius": radius, "points": 6000 + 800 * ch, "medals": 4,
            "duel": False, "music": "", "enter_from": 100, "tier": "elite", "drops": ["power"],
            "phases": [
                {"id": "first", "until_hp": 0.5, "armor": 1.0, "par_s": 10, "move": {"amp": 30, "freq": 0.12},
                 "patterns": [{"pattern": p1, "anchor": "body", "delay": 40}]},
                {"id": "second", "until_hp": 0.0, "armor": 1.0, "par_s": 10, "move": {"amp": 24, "freq": 0.14},
                 "intro": {"hitstop": 6},
                 "patterns": [{"pattern": p2, "anchor": "body", "delay": 40},
                              {"pattern": p1, "anchor": "body", "delay": 90}]}]}


def elites():
    by_id = {d[0]: d for d in ELITES}
    out = []
    for ch in CHAPTER_HP:
        for name in elites_of(ch):
            out.append(elite(ch, by_id[name]))
    return out


def _beta():
    spec = importlib.util.spec_from_file_location("gen_bosses_beta", ROOT / "tools" / "gen_bosses_beta.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


if __name__ == "__main__":
    beta = _beta()
    print(beta.merge(ROOT / "data" / "patterns.json", PATTERNS), "padrões")
    print(beta.merge(ROOT / "data" / "bosses.json", mids(beta) + elites()), "chefes")
