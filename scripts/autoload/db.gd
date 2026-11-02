extends Node
## Banco de dados do jogo: lê os JSON de res://data (plano mestre 10.1). Os dados ficam em JSON, e não
## em .tres, para diffs e validações automáticas serem simples e o balanceamento dispensar o editor.
##
## Origem: db.gd do projeto hyakki (mesmo autor, MIT). Tabelas novas entram em FILES conforme as
## fases do roadmap (enemies, stages, bosses, blessings...).

const FILES: Array[String] = ["ships", "weapons", "wings", "blessings", "enemies", "bosses", "powers"]

var tables: Dictionary = {}
## Listas na ordem do arquivo (a ordem importa para menus e sorteios determinísticos).
var order: Dictionary = {}
var errors: PackedStringArray = []


func _ready() -> void:
	load_all()


func load_all() -> void:
	errors.clear()
	tables.clear()
	order.clear()
	for name: String in FILES:
		var file_path := "res://data/%s.json" % name
		var text := FileAccess.get_file_as_string(file_path)
		if text.is_empty():
			errors.append("arquivo vazio ou ausente: " + file_path)
			continue
		var parsed: Variant = JSON.parse_string(text)
		if typeof(parsed) != TYPE_ARRAY:
			errors.append("não é uma lista JSON: " + file_path)
			continue
		var table: Dictionary = {}
		var ids: Array[StringName] = []
		for entry: Variant in parsed:
			if typeof(entry) != TYPE_DICTIONARY:
				errors.append("%s: entrada que não é objeto" % name)
				continue
			var row: Dictionary = entry
			var id := StringName(String(row.get("id", "")))
			if id == &"":
				errors.append("%s: entrada sem id" % name)
				continue
			if table.has(id):
				errors.append("%s: id repetido %s" % [name, id])
			row["id"] = id
			table[id] = row
			ids.append(id)
		tables[name] = table
		order[name] = ids
	errors.append_array(Powers.validate(table("powers"), table("ships")))
	for message: String in errors:
		Log.error("DB: " + message)


func table(name: String) -> Dictionary:
	return tables.get(name, {})


func ids(name: String) -> Array[StringName]:
	var list: Array[StringName] = []
	list.assign(order.get(name, []))
	return list


## Linhas na ordem do arquivo.
func rows(name: String) -> Array:
	var out: Array = []
	for id: StringName in ids(name):
		out.append(table(name)[id])
	return out


func row(name: String, id: StringName) -> Dictionary:
	return table(name).get(id, {})


func ship(id: StringName) -> Dictionary:
	return row("ships", id)


func weapon(id: StringName) -> Dictionary:
	return row("weapons", id)
