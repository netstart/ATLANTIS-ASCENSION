extends RefCounted
## Portão de scripts dos runners de teste (docs/policies/testes.md): um script quebrado nunca passa calado.
##  - check_all(): carrega todo .gd de res://scripts e res://tests e reprova o que não compila (load() nulo
##    ou script inválido, como um Parse Error ou uma dependência que não resolve).
##  - install()/take(): um Logger pega todo erro de script do processo (SCRIPT ERROR, Parse Error, Compile
##    Error, chamada inválida) enquanto os testes rodam; cada um vira uma falha no fim.
## Não depende de nenhum script do jogo: funciona mesmo quando o que ele vigia está quebrado.

const DIRS: Array[String] = ["res://scripts", "res://tests"]
## Textos que denunciam script quebrado também quando chegam como mensagem comum.
const MARKERS: Array[String] = ["SCRIPT ERROR", "Parse Error", "Compile Error", "Failed to load script"]

var _logger: _Gate


## Começa a vigiar os erros de script do processo (chame antes de qualquer teste).
func install() -> void:
	if _logger == null:
		_logger = _Gate.new()
		OS.add_logger(_logger)


## Para de vigiar e devolve os erros vistos desde install().
func take() -> PackedStringArray:
	if _logger == null:
		return PackedStringArray()
	OS.remove_logger(_logger)
	var out := _logger.errors()
	_logger = null
	return out


## Carrega todos os scripts e devolve os que não compilam ("caminho: motivo").
static func check_all(dirs: Array[String] = DIRS) -> PackedStringArray:
	var bad := PackedStringArray()
	var paths := PackedStringArray()
	for dir: String in dirs:
		_collect(dir, paths)
	paths.sort()
	for path: String in paths:
		var script := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REUSE) as GDScript
		if script == null:
			bad.append("%s: não carrega" % path)
		elif not script.can_instantiate() and not script.is_abstract():
			bad.append("%s: não compila" % path)
	return bad


static func _collect(dir: String, out: PackedStringArray) -> void:
	for file: String in DirAccess.get_files_at(dir):
		if file.ends_with(".gd"):
			out.append(dir.path_join(file))
	for sub: String in DirAccess.get_directories_at(dir):
		if not sub.begins_with("."):
			_collect(dir.path_join(sub), out)


class _Gate:
	extends Logger

	var _mutex := Mutex.new()
	var _errors := PackedStringArray()

	func _log_error(function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		var text := rationale if not rationale.is_empty() else code
		if error_type != ERROR_TYPE_SCRIPT and not _marked(text):
			return
		_add("%s:%d %s: %s" % [file, line, function, text])

	func _log_message(message: String, error: bool) -> void:
		if error and _marked(message):
			_add(message.strip_edges())

	func _marked(text: String) -> bool:
		for marker: String in MARKERS:
			if text.contains(marker):
				return true
		return false

	func _add(text: String) -> void:
		_mutex.lock()
		_errors.append(text)
		_mutex.unlock()

	func errors() -> PackedStringArray:
		_mutex.lock()
		var out := _errors.duplicate()
		_mutex.unlock()
		return out
