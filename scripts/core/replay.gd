class_name Replay
extends RefCounted
## Replay e Fantasma do Abismo (plano mestre 10.3 e Fase 4): como a Sim é determinística, basta gravar a
## missão, a semente, a carga e a entrada de cada passo. A entrada é guardada em blocos de passos
## iguais (run-length), então uma missão de 3 min ocupa poucos KB. O mesmo arquivo serve para assistir
## ao recorde e para o fantasma que voa junto na próxima tentativa.
##
## Arquivos em user://replays/<chave>.json; os placares locais (top 10 por missão ou modo) ficam no
## perfil, em "boards", apontando para o replay do recorde.

const DIR := "user://replays"
## Versão 1 continua: o bit 32 (PODER) é novo e replays antigos, sem ele, reproduzem igual.
const VERSION := 1
const BOARD_SIZE := 10

var mission: Dictionary = {}
var seed: int = 0
var loadout: Dictionary = {}
var score: int = 0
## Blocos [repetições, mx, my, ax, ay, bits, toques, escolha].
var blocks: Array = []
var _last: Array = []
var _cursor: int = 0
var _left: int = 0


func _init(p_mission: Dictionary = {}, p_seed: int = 0, p_loadout: Dictionary = {}) -> void:
	mission = p_mission
	seed = p_seed
	loadout = p_loadout


## Grava a entrada de um passo (a mesma que foi para Sim.step).
func record(input: SimInput) -> void:
	var bits := (1 if input.precise else 0) | (2 if input.fire else 0) | (4 if input.special else 0) \
			| (8 if input.bomb else 0) | (16 if input.tide else 0) | (32 if input.power else 0)
	var row := [input.move.x, input.move.y, input.axis.x, input.axis.y, bits, input.taps, input.choice]
	if row == _last and not blocks.is_empty():
		blocks[-1][0] = int(blocks[-1][0]) + 1
		return
	_last = row
	blocks.append([1] + row)


func frames() -> int:
	var n := 0
	for b: Variant in blocks:
		n += int((b as Array)[0])
	return n


## Próxima entrada da reprodução (ou null no fim).
func next_input() -> SimInput:
	while _left <= 0:
		if _cursor >= blocks.size():
			return null
		_left = int((blocks[_cursor] as Array)[0])
		_cursor += 1
	_left -= 1
	var b: Array = blocks[_cursor - 1]
	var input := SimInput.new()
	input.move = Vector2(float(b[1]), float(b[2]))
	input.axis = Vector2(float(b[3]), float(b[4]))
	var bits := int(b[5])
	input.precise = bits & 1 != 0
	input.fire = bits & 2 != 0
	input.special = bits & 4 != 0
	input.bomb = bits & 8 != 0
	input.tide = bits & 16 != 0
	input.power = bits & 32 != 0
	input.taps = int(b[6])
	input.choice = int(b[7])
	return input


func rewind() -> void:
	_cursor = 0
	_left = 0


func to_dict() -> Dictionary:
	return {"v": VERSION, "mission": mission, "seed": seed, "loadout": loadout, "score": score, "blocks": blocks}


static func from_dict(d: Dictionary) -> Replay:
	if int(d.get("v", 0)) != VERSION:
		return null
	var r := Replay.new(d.get("mission", {}), int(d.get("seed", 0)), d.get("loadout", {}))
	r.score = int(d.get("score", 0))
	r.blocks = d.get("blocks", [])
	return r


## Nova Sim pronta para reproduzir este replay.
func make_sim() -> Sim:
	var sim := Sim.new()
	sim.setup(mission, Sim.load_tables(), loadout, seed, float(loadout.get("sensitivity", 1.0)))
	return sim


# --- Arquivos e placares -------------------------------------------------------------------------

static func key_for(mission_id: String, mode: String) -> String:
	var key := mission_id if mode.is_empty() or mode == "practice" else mode + "_" + mission_id
	return key.replace(":", "_").replace("/", "_")


func save(key: String) -> String:
	DirAccess.make_dir_recursive_absolute(DIR)
	var path := "%s/%s.json" % [DIR, key]
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return ""
	# Precisão total nos floats: a reprodução tem de dar o mesmo hash.
	file.store_string(JSON.stringify(to_dict(), "", false, true))
	return path


static func load_key(key: String) -> Replay:
	var path := "%s/%s.json" % [DIR, key]
	if not FileAccess.file_exists(path):
		return null
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK or typeof(json.data) != TYPE_DICTIONARY:
		return null
	return from_dict(json.data)


## Põe a pontuação no placar local da chave (top 10). Devolve a posição (0 = recorde) ou -1.
static func submit(profile: Dictionary, key: String, score: int, date: String, ship: String) -> int:
	if not profile.has("boards"):
		profile["boards"] = {}
	var board: Array = (profile["boards"] as Dictionary).get(key, [])
	var pos := 0
	while pos < board.size() and int((board[pos] as Dictionary)["score"]) >= score:
		pos += 1
	if pos >= BOARD_SIZE:
		return -1
	board.insert(pos, {"score": score, "date": date, "ship": ship})
	if board.size() > BOARD_SIZE:
		board.resize(BOARD_SIZE)
	profile["boards"][key] = board
	return pos
