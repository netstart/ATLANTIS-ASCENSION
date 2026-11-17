class_name EnergyStream
extends Node2D
## Fluxo de energia que sai do bico da nave, num quad só com shaders/energy_stream.gdshader (luz aditiva):
## o Laser (do bico até onde a Sim parou o feixe) e, com outra arma, a pluma curta do Mergulho Solar
## (overdrive de cadência 2x). Só desenho: lê a Sim, nunca escreve. Liga e desliga em rampa (o Laser abre em
## OPEN_IN s e fecha em OPEN_OUT s; o calor do sol segue PowerView.solar_heat), então nada acende seco.
## Os clarões do bico e da ponta ficam na camada aditiva do WorldView (open e heat dizem quanto).

const SHADER := preload("res://shaders/energy_stream.gdshader")
const OPEN_IN := 0.07
const OPEN_OUT := 0.12
## O bico fica NOSE unidades acima do centro da nave.
const NOSE := 15.0
## Largura total do quad do Laser em vezes a largura da Sim (o halo some antes da borda).
const LASER_SPAN := 4.6
const CYAN_CORE := Color(0.92, 1.0, 1.0)
const CYAN_BODY := Color(0.35, 0.92, 1.0)
const CYAN_HALO := Color(0.12, 0.5, 1.0)
const SUN_CORE := Color(1.0, 0.98, 0.9)
const SUN_BODY := Color(1.0, 0.82, 0.45)
const SUN_HALO := Color(1.0, 0.5, 0.2)
## Pluma do overdrive sem Laser: comprimento e largura (o tiro normal atravessa por cima, apagando).
const PLUME_LENGTH := 72.0
const PLUME_WIDTH := 30.0

var reduce_flashes := false
## 0..1: quanto o Laser está aberto e quanto o overdrive está aceso (lidos pelo WorldView para os clarões).
var open := 0.0
var heat := 0.0
## Onde o Laser parou da última vez (o feixe fecha ali depois que a Sim desliga).
var top := 0.0

var _sim: Sim
var _mat := ShaderMaterial.new()
var _tex: Texture2D
var _width := 0.0
var _drawn := false


func setup(sim: Sim) -> void:
	_sim = sim
	_mat.shader = SHADER
	material = _mat
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	_tex = ImageTexture.create_from_image(img)


func refresh(delta: float, time: float) -> void:
	var pl := _sim.player
	var on := _sim.laser_active and pl.alive
	if on:
		top = _sim.laser_to_y
		_width = _sim.laser_width
	open = move_toward(open, 1.0 if on else 0.0, delta / (OPEN_IN if on else OPEN_OUT))
	heat = PowerView.solar_heat(_sim) if pl.alive else 0.0
	_mat.set_shader_parameter(&"t", time)
	var busy := open > 0.0 or heat > 0.0
	if busy or _drawn:
		queue_redraw()
	_drawn = busy


func _draw() -> void:
	var pl := _sim.player
	if not pl.alive:
		return
	var nose := pl.pos.y - NOSE
	var shimmer := 0.35 if reduce_flashes else 1.0
	_mat.set_shader_parameter(&"shimmer", shimmer)
	var h := heat * heat * (3.0 - 2.0 * heat)
	if open > 0.0:
		# Laser: abre a partir do bico (a largura cresce com open) e esquenta com o overdrive.
		var w := _width * LASER_SPAN * (0.35 + 0.65 * open) * (1.0 + 0.2 * h)
		var length := maxf(4.0, nose - top)
		_params(length, w, 0.13 - 0.02 * h, 0.3, open * (1.0 - 0.15 * h), 0.26 * (0.7 if reduce_flashes else 1.0),
				12.0, 6.0, 420.0 + 260.0 * h, h)
		draw_texture_rect(_tex, Rect2(pl.pos.x - w * 0.5, top, w, length), false)
	elif h > 0.0:
		# Sem Laser: pluma curta de sol que sobe do bico e se desfaz (não esconde as balas).
		var length := PLUME_LENGTH * (0.5 + 0.5 * h)
		var w := PLUME_WIDTH * (0.6 + 0.4 * h)
		_params(length, w, 0.1, 0.3, 0.75 * h, 0.3 * (0.7 if reduce_flashes else 1.0), 8.0, length * 0.85, 300.0, 1.0)
		draw_texture_rect(_tex, Rect2(pl.pos.x - w * 0.5, nose - length, w, length), false)


func _params(length: float, width: float, core: float, body: float, intensity: float, halo: float, root: float,
		tip: float, speed: float, sun: float) -> void:
	_mat.set_shader_parameter(&"length_u", length)
	_mat.set_shader_parameter(&"width_u", width)
	_mat.set_shader_parameter(&"core_w", core)
	_mat.set_shader_parameter(&"body_w", body)
	_mat.set_shader_parameter(&"intensity", intensity)
	_mat.set_shader_parameter(&"halo", halo)
	_mat.set_shader_parameter(&"root_u", root)
	_mat.set_shader_parameter(&"tip_u", tip)
	_mat.set_shader_parameter(&"flow_speed", speed)
	_mat.set_shader_parameter(&"core_color", CYAN_CORE.lerp(SUN_CORE, sun))
	_mat.set_shader_parameter(&"body_color", CYAN_BODY.lerp(SUN_BODY, sun))
	_mat.set_shader_parameter(&"halo_color", CYAN_HALO.lerp(SUN_HALO, sun))
