"""Chaves de tradução que o jogo usa (lidas por tools/build_i18n.py).

Coleta:
- tr("chave") e Locale.text("chave") nos scripts .gd;
- todo campo terminado em "_key" nos JSON de data/;
- EXTRA: chaves montadas em tempo de execução (ex.: "credits.section_" + seção).
"""
import json
import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parent.parent
CALL = re.compile(r"""(?:\btr|Locale\.text|TranslationServer\.translate)\(\s*"([a-z0-9_.]+)"\s*[,)]""")
EXTRA = [f"credits.section_{s}" for s in ("art", "music", "sfx", "fonts", "tech")] + [
    f"weapon.{w}" for w in ("pulsar", "laser", "plasma", "railgun")] + [
    f"speaker.{s}" for s in ("farol", "mare", "protocol", "thalassa")] + [
    "star.clear", "star.no_damage", "star.all_marked", "stage.c1m2", "stage.c1m3"] + [
    f"hub.tab_{t}" for t in ("hangar", "campaign", "ships", "events", "shop")] + [
    "results.cleared", "results.failed", "map.chapter1", "map.chapter2", "map.chapter3"] + [
    f"deity.{d}" for d in ("proteus", "tethys", "nereus", "avatar")] + [
    f"hud.{h}" for h in ("current", "wind")] + [
    f"hint.{h}" for h in ("move", "graze", "orbs", "special", "tide", "marked", "capture")] + [
    f"secondary.{s}{x}" for s in ("missiles", "drones") for x in ("", "_desc")] + [
    f"difficulty.{d}{x}" for d in ("brisa", "normal", "veteran", "abyssal") for x in ("", "_desc")] + [
    f"role.{r}" for r in ("balanced", "precision", "missiles", "speed", "area_control", "defense")] + [
    f"special.{s}" for s in ("area_bomb", "focused_burst", "drone_swarm", "emp_pulse", "gravity_rift", "tide_shield")] + [
    f"map.route_{r}" for r in ("surface", "abyss")] + [f"hub.banner_c{c}" for c in (1, 2, 3)] + [
    f"options.{o}" for o in ("music_volume", "sfx_volume", "ui_volume", "screen_shake", "drag_sensitivity", "auto_fire",
                             "vibration", "reduce_flashes", "reduce_motion", "tilt_parallax", "show_fps", "hand_left",
                             "hand_right", "cb_off", "cb_protanopia", "cb_deuteranopia", "cb_tritanopia")] + [
    f"log.{p.stem}_{x}" for p in sorted((ROOT / "data" / "stages").glob("*.json")) for x in ("title", "text")] + [
    f"map.chapter{c}" for c in range(4, 10)] + [f"hub.banner_c{c}" for c in range(4, 10)] + [
    f"mode.{m}{x}" for m in ("arcade", "daily", "survival", "boss_rush", "practice") for x in ("", "_desc")] + [
    f"task.{k}" for k in ("kills", "grazes", "medals", "clears", "rescued", "chain", "stars", "blessings")] + [
    "events.daily", "events.weekly", "speaker.duarte", "results.new_district", "results.rescued"] + [
    f"cosmetic.{c}" for c in ("tint_abyss", "tint_coral", "tint_kelp", "tint_orichalcum", "tint_pearl", "tint_storm",
                              "tint_supporter")] + [
    f"district.{d}" for d in ("docks", "gardens", "forge", "temple", "observatory")] + [
    f"city.bonus_{b}" for b in ("credits", "pearls", "discount", "bombs", "orichalcum")] + [
    f"ending.{e}" for e in ("shattered", "return", "high_tide")] + [
    f"mode.{m}{x}" for m in ("currents", "second_tide") for x in ("", "_desc")] + [
    f"mutator.{m}" for m in ("fast_bullets", "laser_only", "railgun_only", "dark", "gravity", "glass")] + [
    f"achievement.{a['id']}" for a in json.loads((ROOT / "data" / "achievements.json").read_text(encoding="utf-8"))] + [
    f"results.{r}" for r in ("achievement", "board", "season_xp")] + [
    f"cosmetic.tint_season_{s}" for s in ("a", "b", "c")] + ["season.title", "options.ghost"] + ["speaker.narrator", "hangar.title", "ships.title"] + [
    f"results.{r}" for r in ("fragments", "log", "new_mission", "new_ship", "new_wing")] + [
    f"role.{r}" for r in ("artillery", "drones", "piercing", "critical", "explosive", "hybrid")] + [
    f"trait.{t}" for t in ("artillery", "drones", "pierce", "crit", "blast", "hybrid")] + ["special.rotation"] + [
    "mode.abyss", "mode.abyss_desc", "deity.abyss", "hud.module_title", "results.depth"] + [
    f"options.window_{w}" for w in ("portrait", "landscape", "fullscreen")] + ["hub.banner_c10", "map.chapter10"]


def _json_keys(value, out: set) -> None:
    if isinstance(value, dict):
        for k, v in value.items():
            if k.endswith("_key") and isinstance(v, str):
                out.add(v)
            else:
                _json_keys(v, out)
    elif isinstance(value, list):
        for item in value:
            _json_keys(item, out)


def all_keys() -> list:
    keys: set = set(EXTRA)
    for path in (ROOT / "scripts").rglob("*.gd"):
        keys.update(CALL.findall(path.read_text(encoding="utf-8")))
    for path in (ROOT / "data").rglob("*.json"):
        _json_keys(json.loads(path.read_text(encoding="utf-8")), keys)
    return sorted(keys)


if __name__ == "__main__":
    for key in all_keys():
        print(key)
