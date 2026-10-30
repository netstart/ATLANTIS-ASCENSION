extends Node
## Diagnóstico (docs/policies/qualidade.md): nada de print solto no jogo. Log.debug só imprime em
## build de debug com `-- --verbose` ou com `enabled` ligado (testes).

var enabled: bool = false


func _ready() -> void:
	enabled = OS.is_debug_build() and "--verbose" in OS.get_cmdline_user_args()


func debug(message: String) -> void:
	if enabled:
		print("[debug] " + message)


func warn(message: String) -> void:
	push_warning(message)


func error(message: String) -> void:
	push_error(message)
