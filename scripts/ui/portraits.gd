class_name Portraits
extends RefCounted
## Retratos dos personagens (plano mestre 3.2), gerados por tools/gen_portraits.py a partir do "Cyberpunk
## Portraits" de Hyptosis (CC0): arte ilustrada de 96x96, 3 expressões. O narrador não tem retrato. A
## expressão vem do campo "mood" da fala (calm quando falta).
##
## Transmissão (1.15.1): cada retrato passa por shaders/portrait_fx.gdshader no modo da voz de quem fala
## (FX): rádio para a tripulação, etéreo para Thalassa e glitch para o Protocolo. A cada fala nova,
## tune_in() faz a "sintonia" de 0,35 s. Reduzir movimento ou reduzir flashes congelam o efeito (só as
## linhas de varredura paradas e o brilho da borda).

const DIR := "res://assets/art/generated/portraits/%s_%s.png"
const MOODS: Array[String] = ["calm", "alert", "smile"]
## Lado da arte em pixels.
const SOURCE := 96
const FX_SHADER := preload("res://shaders/portrait_fx.gdshader")
## Modo de transmissão por personagem; quem não está aqui fala pelo rádio.
const FX := {"thalassa": "ethereal", "protocol": "glitch"}
const FX_MODES := {"radio": 0, "ethereal": 1, "glitch": 2}
## Cor da borda e da faixa de zumbido por modo (ciano do rádio, violeta atlante, vermelho do Protocolo).
const FX_TINTS := {"radio": Color("8fe8ff"), "ethereal": Color("c79bff"), "glitch": Color("ff7a7e")}
const TUNE_SECONDS := 0.35
## Altura em pontos de cada linha de varredura (32 pt: 8 linhas; 72 pt: 18).
const LINE_PITCH := 4.0


static func path(speaker: String, mood: String) -> String:
	return DIR % [speaker, mood if mood in MOODS else "calm"]


## Textura do retrato ou null (narrador, personagem sem retrato).
static func texture(speaker: String, mood: String = "calm") -> Texture2D:
	var p := path(speaker, mood)
	return load(p) as Texture2D if ResourceLoader.exists(p) else null


## Retrato pronto para a interface: arte ilustrada reduzida com filtro linear e mipmaps (sem serrilhar
## de 96 para 32 px) e no tamanho pedido.
static func make_rect(size: float) -> TextureRect:
	var r := TextureRect.new()
	r.name = "Portrait"
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	r.custom_minimum_size = Vector2(size, size)
	r.size = Vector2(size, size)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


## Modo de transmissão de quem fala: "radio", "ethereal" ou "glitch".
static func fx_mode(speaker: String) -> String:
	return String(FX.get(speaker, "radio"))


## Efeito parado: reduzir movimento ou reduzir flashes ligados.
static func fx_still() -> bool:
	var loop := Engine.get_main_loop() as SceneTree
	var settings := loop.root.get_node_or_null(^"Settings") if loop != null else null
	if settings == null:
		return false
	return bool(settings.call("get_value", "reduce_motion")) or bool(settings.call("get_value", "reduce_flashes"))


## Liga (ou troca) o efeito de transmissão do retrato para a voz de `speaker`. Sem textura, tira o efeito.
## O material é do próprio retrato (cada um tem sua sintonia), criado uma vez e reaproveitado.
static func apply_fx(rect: TextureRect, speaker: String) -> void:
	if rect == null:
		return
	if rect.texture == null:
		rect.material = null
		return
	var mat := rect.material as ShaderMaterial
	if mat == null or mat.shader != FX_SHADER:
		mat = ShaderMaterial.new()
		mat.shader = FX_SHADER
		mat.set_shader_parameter("seed", float(rect.get_instance_id() % 97))
		rect.material = mat
	var mode := fx_mode(speaker)
	var side := maxf(rect.custom_minimum_size.y, 8.0)
	mat.set_shader_parameter("mode", int(FX_MODES[mode]))
	mat.set_shader_parameter("tint", FX_TINTS[mode])
	mat.set_shader_parameter("lines", clampf(roundf(side / LINE_PITCH), 8.0, 32.0))
	mat.set_shader_parameter("still", fx_still())
	if not rect.has_meta(&"tuning"):
		mat.set_shader_parameter("tune", 0.0)


## Fala nova de `speaker` (o retrato já com a textura dela): efeito da voz e sintonia.
static func transmit(rect: TextureRect, speaker: String) -> void:
	apply_fx(rect, speaker)
	tune_in(rect)


## Sintonia de uma fala nova: aberração, faixas e a imagem entrando em pixels, estabilizando em 0,35 s.
## Parado (acessibilidade) ou fora da árvore, o retrato aparece direto.
static func tune_in(rect: TextureRect) -> void:
	var mat := rect.material as ShaderMaterial if rect != null else null
	if mat == null:
		return
	if fx_still() or not rect.is_inside_tree():
		mat.set_shader_parameter("tune", 0.0)
		return
	if rect.has_meta(&"tuning"):
		(rect.get_meta(&"tuning") as Tween).kill()
	mat.set_shader_parameter("tune", 1.0)
	var t := rect.create_tween()
	var fade := t.tween_method(func(v: float) -> void: mat.set_shader_parameter("tune", v), 1.0, 0.0, TUNE_SECONDS)
	fade.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_callback(func() -> void: rect.remove_meta(&"tuning"))
	rect.set_meta(&"tuning", t)
