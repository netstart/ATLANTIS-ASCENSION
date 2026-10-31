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
    "results.cleared", "results.failed", "map.chapter1", "map.chapter2"]


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
