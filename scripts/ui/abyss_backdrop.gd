class_name AbyssBackdrop
extends Control
## Fundo vivo e compartilhado dos menus (redesenho 1.6): o shader abyss_backdrop num SubViewport na
## resolução lógica, ampliado com filtro linear (a água é macia; o texto e os botões continuam na
## resolução física). Fica atrás de todas as telas e sobrevive às trocas de tela, então a água nunca
## "pisca" entre um menu e outro.
##
## Orçamento (docs/policies/qualidade.md): o SubViewport só é redesenhado a REDRAW_HZ (30 Hz), um
## retângulo de ≈ 0,2 MP; parado em "reduzir movimento" (só o parallax do dedo) e enquanto oculto.
## O parallax segue o dedo ou o mouse (e o acelerômetro, se a opção estiver ligada) com mola suave.
## Por cima da água, o plâncton luminoso (AbyssMotes, 1.9) anda no mesmo relógio e no mesmo parallax.

const SHADER := preload("res://shaders/abyss_backdrop.gdshader")
const REDRAW_HZ := 30.0
const FOLLOW := 3.5
## Humor por tela: cor da água no alto, cor do abismo e destaque (janelas acesas, raios).
const MOODS := {
	&"default": [Color("0f3d55"), Color("050b1a"), Color("2ff3e0")],
	&"title": [Color("125a6e"), Color("040915"), Color("2ff3e0")],
	&"map": [Color("0b2c48"), Color("03060f"), Color("63b8ff")],
	&"gold": [Color("3a3a2a"), Color("080812"), Color("ffc94a")],
	&"danger": [Color("3a1426"), Color("08040c"), Color("ff4d6d")],
	&"calm": [Color("0c3346"), Color("040a16"), Color("5cf29b")],
	&"hadal": [Color("071a2c"), Color("010306"), Color("b57bff")],
	&"lava": [Color("4a1c12"), Color("0a0404"), Color("ff8a3d")],
	&"ice": [Color("3f7896"), Color("08182a"), Color("bff4ff")],
	&"sky": [Color("4f8fc0"), Color("10294a"), Color("ffc94a")],
	&"space": [Color("1a1840"), Color("020208"), Color("b57bff")],
}

## Rolagem vertical (o mapa liga a rolagem dele aqui para as camadas andarem em profundidade).
var scroll: float = 0.0
## Deslocamento extra pedido pela tela (-1..1), somado ao do dedo.
var drift := Vector2.ZERO
var reduce_motion: bool = false
## Presença das ruínas (0..1): o mapa apaga as ruínas quando a rota sobe para o céu e o espaço.
var ruins: float = 1.0:
	set(value):
		ruins = value
		if _material != null:
			_material.set_shader_parameter("ruins_strength", value)

var _viewport: SubViewport
var _rect: ColorRect
var _view: TextureRect
var _material: ShaderMaterial
var _motes: AbyssMotes
var _clock: float = 0.0
var _wait: float = 0.0
var _pointer := Vector2.ZERO
var _parallax := Vector2.ZERO
var _colors: Array = MOODS[&"default"].duplicate()
var _tween: Tween


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	_viewport = SubViewport.new()
	_viewport.disable_3d = true
	_viewport.transparent_bg = false
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(_viewport)
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_rect = ColorRect.new()
	_rect.material = _material
	_viewport.add_child(_rect)
	_view = TextureRect.new()
	_view.texture = _viewport.get_texture()
	_view.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_view.stretch_mode = TextureRect.STRETCH_SCALE
	_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_view)
	_motes = AbyssMotes.new()
	add_child(_motes)
	resized.connect(_fit)
	_fit()
	_apply_colors()


func _fit() -> void:
	var px := Vector2i(maxi(1, ceili(size.x)), maxi(1, ceili(size.y)))
	_viewport.size = px
	_rect.size = Vector2(px)
	_material.set_shader_parameter("view_size", Vector2(px))
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


## Troca o humor da água com transição de 0,6 s (título, mapa, recompensa, perigo...).
func set_mood(mood: StringName) -> void:
	var target: Array = MOODS.get(mood, MOODS[&"default"])
	if _tween != null:
		_tween.kill()
	var from: Array = _colors.duplicate()
	_tween = create_tween()
	_tween.tween_method(func(w: float) -> void:
		for i: int in range(3):
			_colors[i] = (from[i] as Color).lerp(target[i] as Color, w)
		_apply_colors(), 0.0, 1.0, 0.6).set_trans(Tween.TRANS_SINE)


func _apply_colors() -> void:
	if _material == null:
		return
	_material.set_shader_parameter("water_top", _colors[0])
	_material.set_shader_parameter("water_deep", _colors[1])
	_material.set_shader_parameter("accent", _colors[2])
	if _motes != null:
		_motes.accent = _colors[2]
		_motes.queue_redraw()
	if _viewport != null:
		_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	var at := Vector2.INF
	if event is InputEventMouseMotion:
		at = (event as InputEventMouseMotion).position
	elif event is InputEventScreenDrag:
		at = (event as InputEventScreenDrag).position
	if at != Vector2.INF and size.x > 0.0:
		var local := get_global_transform_with_canvas().affine_inverse() * at
		_pointer = ((local / size) - Vector2(0.5, 0.5)) * 2.0


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	var target := (_pointer + drift).limit_length(1.4)
	if OS.has_feature("mobile") and bool(Settings.get_value("tilt_parallax")):
		var acc := Input.get_accelerometer()
		target += Vector2(clampf(acc.x / 4.0, -1.0, 1.0), clampf((acc.y + 6.0) / 6.0, -1.0, 1.0)) * 0.6
	if reduce_motion:
		target *= 0.25
	_parallax = _parallax.lerp(target, minf(1.0, delta * FOLLOW))
	if not reduce_motion:
		_clock += delta
	_wait -= delta
	if _wait > 0.0:
		return
	_wait = 1.0 / REDRAW_HZ
	_material.set_shader_parameter("parallax", _parallax)
	_material.set_shader_parameter("scroll", scroll)
	_material.set_shader_parameter("rays_strength", 0.55 * clampf(ruins + 0.3, 0.0, 1.0))
	_material.set_shader_parameter("clock", _clock)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	_motes.clock = _clock
	_motes.parallax = _parallax
	_motes.queue_redraw()


## Só para testes e capturas: deslocamento atual do parallax.
func parallax() -> Vector2:
	return _parallax
