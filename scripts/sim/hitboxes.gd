class_name Hitboxes
extends RefCounted
## Caixas de colisão medidas na arte HD (revisão 5 da Sim, SimRevision): data/hitboxes.json, gerado por
## tools/fit_hitboxes.py. Por nave do jogador ("ships": raio e ponto da hitbox na cabine), inimigo ("enemies": raio
## de dano, centro e raio de contato) e chefe ("bosses": o mesmo do corpo e "parts" com sprite). Unidades lógicas na
## tela, "offset" relativo à posição da Sim. Id fora do arquivo ou revisão < 5 = caixa vazia: a Sim fica com os
## valores de data/ships.json, enemies.json e bosses.json (replays antigos reproduzem igual).

const REVISION := 5
## A partir desta revisão a nave do jogador sai em SHIP_SCALE na tela (ShipArt.GAME_SCALE, o porte da nave original),
## e o ponto da hitbox ("offset" medido na arte HD em escala 1) encolhe junto para ficar na cabine. O raio não muda.
const SHIP_SCALE_REVISION := 7
const SHIP_SCALE := 0.5
const PATH := "res://data/hitboxes.json"


## Tabela inteira ({"ships", "enemies", "bosses"}); {} sem o arquivo.
static func load_table() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH)) if FileAccess.file_exists(PATH) else null
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


static func enabled(loadout: Dictionary) -> bool:
	return SimRevision.of(loadout) >= REVISION


## Caixa de `id` no grupo (&"ships", &"enemies", &"bosses") de tables["hitboxes"], ou {} (revisão antiga, sem dado).
static func find(tables: Dictionary, loadout: Dictionary, group: String, id: StringName) -> Dictionary:
	if not enabled(loadout):
		return {}
	var rows: Variant = (tables.get("hitboxes", {}) as Dictionary).get(group, {})
	if typeof(rows) != TYPE_DICTIONARY:
		return {}
	var row: Variant = (rows as Dictionary).get(String(id), {})
	return row if typeof(row) == TYPE_DICTIONARY else {}


## [x, y] do JSON em Vector2 (ZERO se faltar).
static func vec(raw: Variant) -> Vector2:
	if typeof(raw) == TYPE_ARRAY and (raw as Array).size() >= 2:
		return Vector2(float(raw[0]), float(raw[1]))
	return Vector2.ZERO


## Caixa da nave do jogador `id` (find "ships"), com o ponto na escala da tela da revisão (SHIP_SCALE na 7+).
static func ship(tables: Dictionary, loadout: Dictionary, id: StringName) -> Dictionary:
	var box := find(tables, loadout, "ships", id)
	if box.is_empty() or SimRevision.of(loadout) < SHIP_SCALE_REVISION:
		return box
	var out := box.duplicate()
	out["offset"] = [vec(box.get("offset")).x * SHIP_SCALE, vec(box.get("offset")).y * SHIP_SCALE]
	return out
