extends Node
## Progresso do jogador (plano mestre 10.9): JSON em user://save.json, com backup e migração por
## versão. A gravação escreve primeiro num arquivo temporário e só então troca, para um app morto no
## meio da gravação não corromper o save.
##
## Origem: save_manager.gd do projeto hyakki (mesmo autor, MIT), com o perfil deste jogo.

signal saved
signal unlocked(kind: String, id: StringName)

const PATH := "user://save.json"
const BACKUP_PATH := "user://save.bak"
const TEMP_PATH := "user://save.tmp"
## Arquivos dos testes (use_test_files): o save do jogador nunca é tocado.
const TEST_PATHS := ["user://test_save.json", "user://test_save.bak", "user://test_save.tmp"]
const VERSION := 1
## Moedas do jogo (plano mestre 4.9). Pérolas de Maré só compram cosméticos.
const CURRENCIES: Array[String] = ["credits", "orichalcum", "pearls"]

var data: Dictionary = {}
var path: String = PATH
var backup_path: String = BACKUP_PATH
var temp_path: String = TEMP_PATH
## true quando o save principal estava corrompido e o backup foi usado.
var recovered_from_backup: bool = false


func _ready() -> void:
	load_profile()


static func default_profile() -> Dictionary:
	return {
		"version": VERSION,
		"wallet": {"credits": 0, "orichalcum": 0, "pearls": 0},
		"earned": {"credits": 0, "orichalcum": 0, "pearls": 0},
		"unlocked": {"ships": ["falcon"], "wings": [], "cosmetics": [], "modes": ["campaign"]},
		"selected": {"ship": "falcon", "secondary": "", "wings": [], "difficulty": "normal"},
		"hangar": {"ship_levels": {"falcon": 1}, "modules": {}, "fragments": {}},
		# Por missão: {"stars": [bool x4], "best_score": int, "cleared": bool, "route": ""}.
		"missions": {},
		"story": {"prologue_seen": false, "endings": [], "logs": [], "glyphs": [], "abyss_records": []},
		"rescued_total": 0,
		"achievements": {},
		"stats": {"missions_played": 0, "missions_cleared": 0, "deaths": 0, "kills": 0, "grazes": 0,
				"bombs_used": 0, "tide_used": 0, "time_played": 0.0, "bosses_defeated": {}},
		"daily": {"date": "", "best_score": 0, "attempted": false},
		"login": {"streak": 0, "last_date": "", "shields_left": 1},
		"purchases": {"supporter": false, "pending": false},
		"consent": {"asked": false, "personalized": false},
		"tutorial_done": false,
		"launches": 0,
	}


## Testes: passa a ler e gravar nos TEST_PATHS, começando de um perfil novo.
func use_test_files() -> void:
	path = TEST_PATHS[0]
	backup_path = TEST_PATHS[1]
	temp_path = TEST_PATHS[2]
	for file: String in TEST_PATHS:
		if FileAccess.file_exists(file):
			DirAccess.remove_absolute(file)
	load_profile()


func load_profile() -> void:
	recovered_from_backup = false
	var loaded := _read(path)
	if loaded.is_empty() and FileAccess.file_exists(path):
		loaded = _read(backup_path)
		recovered_from_backup = not loaded.is_empty()
	data = migrate(loaded) if not loaded.is_empty() else default_profile()


## Leva saves antigos para a versão atual e completa campos que faltam (idempotente).
static func migrate(old: Dictionary) -> Dictionary:
	_fill_missing(old, default_profile())
	old["version"] = VERSION
	return old


static func _fill_missing(target: Dictionary, defaults: Dictionary) -> void:
	for key: String in defaults:
		if not target.has(key):
			target[key] = defaults[key]
		elif typeof(defaults[key]) == TYPE_DICTIONARY and typeof(target[key]) == TYPE_DICTIONARY:
			_fill_missing(target[key], defaults[key])


func save_profile() -> void:
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		Log.error("SaveManager: não abriu " + temp_path)
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	var dir := DirAccess.open("user://")
	if FileAccess.file_exists(path):
		dir.copy(path, backup_path)
	dir.rename(temp_path, path)
	saved.emit()


func reset_profile() -> void:
	data = default_profile()
	save_profile()


func _read(file_path: String) -> Dictionary:
	if not FileAccess.file_exists(file_path):
		return {}
	# JSON.parse (e não parse_string): um save corrompido é caso previsto, sem erro no log.
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(file_path)) != OK:
		return {}
	return json.data if typeof(json.data) == TYPE_DICTIONARY else {}


# --- Atalhos -----------------------------------------------------------------

func currency(kind: String) -> int:
	return int((data["wallet"] as Dictionary).get(kind, 0))


## Soma (ou tira, com valor negativo) uma moeda; nunca fica abaixo de zero.
func add_currency(kind: String, amount: int) -> void:
	if not kind in CURRENCIES:
		Log.error("SaveManager: moeda desconhecida " + kind)
		return
	data["wallet"][kind] = maxi(0, currency(kind) + amount)
	if amount > 0:
		data["earned"][kind] = int(data["earned"][kind]) + amount


func is_unlocked(kind: String, id: StringName) -> bool:
	return (data["unlocked"][kind] as Array).has(String(id))


func unlock(kind: String, id: StringName) -> bool:
	var list: Array = data["unlocked"][kind]
	if list.has(String(id)):
		return false
	list.append(String(id))
	unlocked.emit(kind, id)
	return true


## Registro de uma missão, criado na primeira consulta.
func mission_record(mission_id: StringName) -> Dictionary:
	var all: Dictionary = data["missions"]
	if not all.has(String(mission_id)):
		all[String(mission_id)] = {"stars": [false, false, false, false], "best_score": 0,
				"cleared": false, "route": ""}
	return all[String(mission_id)]


func stat(key: String) -> Variant:
	return data["stats"][key]


func add_stat(key: String, amount: float) -> void:
	data["stats"][key] = float(data["stats"][key]) + amount
