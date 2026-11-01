class_name UiGlint
extends RefCounted
## Reflexo que corre nos botões principais (1.9): um único ShaderMaterial (shaders/ui_glint.gdshader)
## compartilhado por todos os botões dourados. A faixa de luz anda em coordenadas de tela, então os
## botões acendem em sequência, como uma luz passando pela água. "Reduzir movimento" apaga a faixa.

const SHADER := preload("res://shaders/ui_glint.gdshader")
const STRENGTH := 0.42

static var _material: ShaderMaterial


static func material() -> ShaderMaterial:
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = SHADER
		_material.set_shader_parameter("strength", 0.0 if UiFx.reduced() else STRENGTH)
	return _material


## Liga ou apaga a faixa (opção "reduzir movimento").
static func set_reduced(reduced: bool) -> void:
	material().set_shader_parameter("strength", 0.0 if reduced else STRENGTH)


## Solta o material ao sair do jogo (referência estática presa vira aviso de vazamento no Godot).
static func release() -> void:
	_material = null
