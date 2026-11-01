class_name WeatherView
extends Node2D
## Clima na tela (1.13 "Céu e Mar Vivos"), só leitura da Sim (`sim.weather`). Três camadas:
##   céu baixo (shaders/weather_sky.gdshader, tela cheia, entre o chão e as naves): nuvens com sombra
##     no chão, relâmpago ramificado dentro delas, chuva, neve e cinzas ao longe; sob a água, neve
##     marinha, filetes da corrente, plâncton que brilha e a termoclina; no vácuo, a aurora;
##   frente (shaders/weather_front.gdshader, no WorldView acima das naves e abaixo das balas
##     inimigas): fiapos de nuvem passando pela nave, chuva e neve de perto, véu de nevasca e o
##     arco-íris quando a tempestade passa; some nos padrões densos;
##   marcas (por cima da frente): a biruta no canto do campo e os efeitos na própria nave (gotas no
##     casco e escorrendo das asas, rastro de vapor nas curvas dentro da nuvem, bolhas do motor sob a
##     água, gelo no casco na nevasca, brasas de cinza).
## O fundo (OceanBackdrop) recebe a cor da água ou do céu, o escurecimento e a luz do relâmpago, sempre
## sob o teto de brilho. Relâmpagos ao longe são sorteados pelo passo da Sim (o mesmo replay mostra os
## mesmos), e o trovão chega atrasado pela distância (sinal `thunder`). Os raios do roteiro (colunas com
## aviso) acendem tudo e trovejam na hora. Nada aqui volta para a partida.

## Trovão: distância 0 (em cima) a 1 (no horizonte); `strike` = raio que caiu no campo.
signal thunder(distance: float, strike: bool)

const FLASH_DECAY := 7.0
const BOLT_DECAY := 9.0
## Intervalo mínimo entre dois relâmpagos ao longe (passos) e a segunda piscada de cada um (s).
const FLASH_GAP := 36
const FLICKER := 0.09
## Arco-íris depois da tempestade: duração e quanto os raios de sol crescem nele.
const RAINBOW_TIME := 10.0
const RAINBOW_RAYS := 1.8
## Balas inimigas a partir das quais a frente começa a sumir, e onde some de vez.
const DENSE_FROM := 140.0
const DENSE_TO := 420.0
## Biruta: canto de baixo do campo (o alto é da barra do chefe e do rádio) e vento mínimo para aparecer.
const VANE_AT := Vector2(14, 436)
const VANE_MIN := 5.0
const MEDIUM_INDEX := {&"air": 0, &"water": 1, &"void": 2}

var sim: Sim
var world: WorldView
var backdrop: OceanBackdrop
var detail: int = 2
var reduce_flashes: bool = false
var reduce_motion: bool = false
var view_size := Vector2(305, 678)
var field := Rect2(17, 114, 270, 450)

var _sky: ColorRect
var _sky_mat: ShaderMaterial
var _front: ColorRect
var _front_mat: ShaderMaterial
var _marks: _Marks
var _noise: Texture2D
var _drift := Vector2.ZERO
var _flash: float = 0.0
var _flash_pos := Vector2.ZERO
var _bolt: float = 0.0
var _bolt_seed: float = 0.0
var _flicker: float = -1.0
var _last_frame: int = 0
var _last_flash: int = -1000
var _strikes: Dictionary = {}
var _label: StringName = &""
var _rainbow: float = -1.0
var _emit_clock: float = 0.0
var _ticks: int = 0
var _cap: float = 0.07


func setup(p_sim: Sim, p_world: WorldView, p_backdrop: OceanBackdrop) -> void:
	sim = p_sim
	world = p_world
	backdrop = p_backdrop
	_cap = backdrop.luma_cap()
	_label = sim.weather.label()
	_last_frame = sim.frame
	_noise = make_noise()
	var palette := OceanBackdrop.palette_of(backdrop.kind)
	var deep: Color = palette["deep"]
	var mid: Color = palette["mid"]
	var lit: Color = palette["lit"]
	var foam: Color = palette["foam"]
	_sky = ColorRect.new()
	_sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sky_mat = ShaderMaterial.new()
	_sky_mat.shader = load("res://shaders/weather_sky.gdshader") as Shader
	_sky.material = _sky_mat
	add_child(_sky)
	_front = ColorRect.new()
	_front.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_front.size = Playfield.FIELD
	_front_mat = ShaderMaterial.new()
	_front_mat.shader = load("res://shaders/weather_front.gdshader") as Shader
	_front.material = _front_mat
	_marks = _Marks.new()
	_marks.view = self
	world.weather_slot.add_child(_front)
	world.weather_slot.add_child(_marks)
	var medium := int(MEDIUM_INDEX.get(sim.weather.medium, 0))
	for m: ShaderMaterial in [_sky_mat, _front_mat]:
		m.set_shader_parameter("medium", medium)
		m.set_shader_parameter("detail", float(detail))
		m.set_shader_parameter("noise_tex", _noise)
		m.set_shader_parameter("luma_cap", _cap)
		m.set_shader_parameter("foam", foam)
	_sky_mat.set_shader_parameter("cloud_dark", deep.lerp(mid, 0.55))
	_sky_mat.set_shader_parameter("cloud_lit", lit.lightened(0.45))
	_front_mat.set_shader_parameter("cloud_tint", mid.lerp(lit, 0.75).lightened(0.2))
	_front_mat.set_shader_parameter("size", Playfield.FIELD)
	set_layout(view_size, field)


## Ruído contínuo e sem emenda (nuvens, aurora, zigue-zague do raio), gerado uma vez pela própria Godot.
static func make_noise() -> Texture2D:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.012
	noise.fractal_octaves = 3
	noise.seed = 1307
	var img := noise.get_seamless_image(256, 256)
	return ImageTexture.create_from_image(img)


func set_layout(view: Vector2, p_field: Rect2) -> void:
	view_size = view
	field = p_field
	if _sky == null:
		return
	_sky.size = view
	_sky_mat.set_shader_parameter("view_size", view)
	_sky_mat.set_shader_parameter("field", Vector4(field.position.x, field.position.y, field.size.x, field.size.y))


## Um quadro: lê o clima da Sim, sorteia relâmpagos pelos passos novos e atualiza as três camadas.
func refresh(delta: float) -> void:
	var w := sim.weather
	var wind_speed := w.wind.length()
	var wind_dir := w.wind / wind_speed if wind_speed > 0.01 else Vector2.DOWN
	if not reduce_motion:
		_drift += w.wind * delta
	_drift = Vector2(fposmod(_drift.x, 4096.0), fposmod(_drift.y, 4096.0))
	_lightning(w, delta)
	_track_label(w, delta)
	var flash := _flash * (0.3 if reduce_flashes else 1.0)
	var bolt := 0.0 if reduce_flashes else _bolt
	var cam := backdrop.cam()
	var clear := 1.0 - smoothstep(DENSE_FROM, DENSE_TO, float(sim.enemy_bullets.count))
	var rainbow := _rainbow_amount()
	var s := _sky_mat
	s.set_shader_parameter("scroll", fposmod(sim.scroll, 32768.0))
	s.set_shader_parameter("cam_x", cam)
	s.set_shader_parameter("drift", _drift)
	s.set_shader_parameter("wind_dir", wind_dir)
	s.set_shader_parameter("wind_speed", wind_speed)
	s.set_shader_parameter("clouds", w.fx("clouds_low"))
	s.set_shader_parameter("cloud_tone", w.fx("cloud_tone"))
	s.set_shader_parameter("eye", w.fx("eye"))
	s.set_shader_parameter("rain", w.fx("rain"))
	s.set_shader_parameter("snow", w.fx("snow"))
	s.set_shader_parameter("ash", w.fx("ash"))
	s.set_shader_parameter("streaks", w.fx("streaks"))
	s.set_shader_parameter("flow", w.fx("flow"))
	s.set_shader_parameter("glow", w.fx("glow"))
	s.set_shader_parameter("layer", w.fx("layer"))
	s.set_shader_parameter("aurora", w.fx("aurora"))
	s.set_shader_parameter("haze", w.fx("haze"))
	s.set_shader_parameter("haze_color", w.fx_color("haze_color", "haze"))
	s.set_shader_parameter("flash", flash)
	s.set_shader_parameter("flash_pos", _flash_pos)
	s.set_shader_parameter("bolt", bolt)
	s.set_shader_parameter("bolt_seed", _bolt_seed)
	_sky.visible = _sky_active(w) or flash > 0.0 or bolt > 0.0
	var f := _front_mat
	f.set_shader_parameter("scroll", fposmod(sim.scroll, 32768.0))
	f.set_shader_parameter("drift", _drift)
	f.set_shader_parameter("wind_dir", wind_dir)
	f.set_shader_parameter("wind_speed", wind_speed)
	f.set_shader_parameter("clouds", w.fx("clouds_high"))
	f.set_shader_parameter("rain", w.fx("rain"))
	f.set_shader_parameter("snow", w.fx("snow"))
	f.set_shader_parameter("ash", w.fx("ash"))
	f.set_shader_parameter("streaks", w.fx("streaks"))
	f.set_shader_parameter("haze", w.fx("haze"))
	f.set_shader_parameter("haze_color", w.fx_color("haze_color", "haze"))
	f.set_shader_parameter("flash", flash)
	f.set_shader_parameter("rainbow", rainbow)
	f.set_shader_parameter("clear_for_bullets", clear)
	_front.visible = detail >= 1 and (_front_active(w) or flash > 0.0 or rainbow > 0.0)
	var grade := w.fx_color("grade", "grade_amount")
	var water := w.medium == &"water"
	var rays := w.fx("rays") * (1.0 + (RAINBOW_RAYS - 1.0) * minf(1.0, rainbow * 2.0))
	backdrop.set_weather(grade, w.fx("dim"), w.fx("caustics") if water else 1.0, rays,
			flash, _flash_pos)
	backdrop.particles_on = w.fx("rain") <= 0.0 and w.fx("snow") <= 0.0 and not water
	_emit_clock = minf(_emit_clock + delta, WorldView.EMIT_STEP * 4.0)
	while _emit_clock >= WorldView.EMIT_STEP:
		_emit_clock -= WorldView.EMIT_STEP
		_emit_ship(w)
	_marks.queue_redraw()


func _sky_active(w: Weather) -> bool:
	for key: String in ["clouds_low", "rain", "snow", "ash", "streaks", "flow", "glow", "layer", "aurora", "haze"]:
		if w.fx(key) > 0.001:
			return true
	return false


func _front_active(w: Weather) -> bool:
	if w.medium == &"water":
		return true
	for key: String in ["clouds_high", "rain", "snow", "ash", "streaks", "haze"]:
		if w.fx(key) > 0.001:
			return true
	return false


# --- Relâmpago e trovão --------------------------------------------------------------------------

func _lightning(w: Weather, delta: float) -> void:
	_flash = maxf(0.0, _flash - FLASH_DECAY * delta)
	_bolt = maxf(0.0, _bolt - BOLT_DECAY * delta)
	if _flicker >= 0.0:
		_flicker -= delta
		if _flicker < 0.0:
			_flash = maxf(_flash, 0.7)
	var rate := w.fx("flashes")
	var from := maxi(_last_frame + 1, sim.frame - 8)
	for frame: int in range(from, sim.frame + 1):
		if rate > 0.0 and frame - _last_flash >= FLASH_GAP and absi(hash(frame * 92821 + 17)) % 3600 < int(rate):
			_far_flash(w, frame)
	_last_frame = sim.frame
	for b: Dictionary in sim.beams:
		if String(b.get("kind", "")) != "lightning" or int(b["age"]) < int(b["warn"]):
			continue
		var key := "%d:%.1f" % [sim.frame - int(b["age"]) + int(b["warn"]), float(b["x"])]
		if _strikes.has(key):
			continue
		_strikes[key] = sim.frame
		_flash = 1.0
		_flicker = FLICKER
		_flash_pos = field.position + Vector2(float(b["x"]), field.size.y * 0.3)
		thunder.emit(0.0, true)
	if _strikes.size() > 16:
		for key: String in _strikes.keys():
			if sim.frame - int(_strikes[key]) > 600:
				_strikes.erase(key)


## Relâmpago agora, no meio do campo (capturas e testes).
func flash_now() -> void:
	_far_flash(sim.weather, sim.frame)
	_flash = 1.0
	_flash_pos = field.get_center() - Vector2(0, field.size.y * 0.2)
	if sim.weather.medium == &"air":
		_bolt = 1.0


## Relâmpago ao longe: posição, distância e se mostra o raio, tudo pelo hash do passo.
func _far_flash(w: Weather, frame: int) -> void:
	_last_flash = frame
	var h := absi(hash(frame * 7919 + 5))
	var distance := 0.25 + float(h % 1000) / 1000.0 * 0.75
	_flash = maxf(_flash, 1.0 - distance * 0.55)
	_flicker = FLICKER if (h >> 10) % 2 == 0 else -1.0
	_flash_pos = Vector2(float((h >> 3) % int(maxf(1.0, view_size.x))), field.position.y
			+ float((h >> 12) % int(field.size.y * 0.6)))
	if w.medium == &"air" and (h >> 20) % 3 != 0:
		_bolt = 1.0
		_bolt_seed = float((h >> 7) % 997) / 997.0
	thunder.emit(distance, false)


# --- Arco-íris -----------------------------------------------------------------------------------

## A tempestade passou para céu limpo ou nublado: o sol abre e o arco-íris aparece.
func _track_label(w: Weather, delta: float) -> void:
	var now := w.label()
	if now != _label:
		var was_severe := bool(w.def_of(_label).get("severe", false))
		var sunny := float((w.def_of(now).get("fx", {}) as Dictionary).get("rays", 0.0)) >= 0.6
		if was_severe and sunny and w.medium == &"air" and not bool(w.def_of(now).get("severe", false)):
			_rainbow = 0.0
		_label = now
	if _rainbow >= 0.0:
		_rainbow += delta
		if _rainbow > RAINBOW_TIME:
			_rainbow = -1.0


func _rainbow_amount() -> float:
	if _rainbow < 0.0:
		return 0.0
	var fade_in := smoothstep(0.0, 2.0, _rainbow)
	var fade_out := 1.0 - smoothstep(RAINBOW_TIME - 2.5, RAINBOW_TIME, _rainbow)
	return fade_in * fade_out


## Arco-íris visível agora (testes e capturas).
func rainbow_visible() -> bool:
	return _rainbow >= 0.0


# --- Efeitos na nave -----------------------------------------------------------------------------

func _emit_ship(w: Weather) -> void:
	_ticks += 1
	var pl := sim.player
	if not pl.alive or world.fx_level < 1:
		return
	var fx := world.fx
	var h := absi(hash(_ticks * 2654435761))
	var r := float(h % 1000) / 1000.0
	var tips: Array[Vector2] = [pl.pos + Vector2(-12, 4), pl.pos + Vector2(12, 4)]
	var tip: Vector2 = tips[_ticks % 2]
	if w.medium == &"water":
		# Bolhas do motor, arrastadas pela corrente.
		if _ticks % 3 == 0:
			var nozzle: Vector2 = pl.pos + WorldView.NOZZLES[_ticks % 2]
			fx.light.spawn(CombatFx.SPARKLE, nozzle, Vector2(r * 8.0 - 4.0, 18.0) + w.wind * 0.6, 0.6,
					0.7, 1.2, Color(fx.foam, 0.55), Color(fx.foam, 0.0), 1.5)
		return
	var wet := w.fx("wet") * w.fx("rain")
	if wet > 0.0 and r < wet * 0.6:
		# Gota batendo no casco e outra escorrendo da ponta da asa.
		var hit := pl.pos + Vector2(float((h >> 4) % 17) - 8.0, float((h >> 9) % 15) - 7.0)
		fx.light.spawn(CombatFx.SPARKLE, hit, Vector2.ZERO, 0.14, 0.6, 0.2, Color(0.8, 0.9, 1.0, 0.7),
				Color(0.8, 0.9, 1.0, 0.0))
		fx.light.spawn(CombatFx.STREAK, tip, Vector2(w.wind.x * 0.6, 90.0), 0.22, 0.35, 0.2,
				Color(0.75, 0.85, 1.0, 0.5), Color(0.75, 0.85, 1.0, 0.0), 0.0, Vector2.ZERO, 0.0, 0.0, true)
	var humid := maxf(w.fx("clouds_high"), w.fx("rain"))
	if humid > 0.3 and absf(pl.last_move.x) > 1.4 and _ticks % 2 == 0:
		# Vapor das pontas das asas na curva fechada dentro da nuvem.
		for t: Vector2 in tips:
			fx.matter.spawn(CombatFx.SMOKE, t, Vector2(0, 50), 0.35, 0.25, 0.5, Color(0.85, 0.9, 1.0, 0.3),
					Color(0.85, 0.9, 1.0, 0.0))
	if w.fx("icing") > 0.0 and r < 0.06 * w.fx("icing"):
		fx.light.spawn(CombatFx.SPARKLE, tip, Vector2(0, 10), 0.5, 0.8, 0.3, Color(0.85, 1.0, 1.0, 0.8),
				Color(0.6, 0.9, 1.0, 0.0))
	if w.fx("ash") > 0.0 and r < 0.05 * w.fx("ash"):
		fx.light.spawn(CombatFx.SPARKLE, pl.pos + Vector2(r * 60.0 - 30.0, -20.0), Vector2(w.wind.x, 40.0), 0.7,
				0.6, 0.2, Color(1.0, 0.55, 0.2, 0.8), Color(1.0, 0.2, 0.0, 0.0))


## Biruta no canto do campo: seta do vento ou da corrente (comprimento pela força), traços de
## turbulência e o sinal de resistência do meio. Some quando o ar e a água estão parados.
class _Marks:
	extends Node2D

	const CHIP := Color(0.0, 0.03, 0.06, 0.45)
	const ARROW := Color(0.6, 0.95, 1.0, 0.85)
	const SLOW := Color(1.0, 0.75, 0.4, 0.85)

	var view: WeatherView

	func _draw() -> void:
		var w := view.sim.weather
		var speed := w.wind.length()
		var shaking := w.turbulence > 0.4
		var slow := w.drag < 0.97
		if speed < WeatherView.VANE_MIN and not shaking and not slow:
			return
		var at := WeatherView.VANE_AT
		draw_rect(Rect2(at - Vector2(10, 10), Vector2(20 + (8 if shaking else 0) + (8 if slow else 0), 20)), CHIP)
		if speed >= WeatherView.VANE_MIN:
			var length := clampf(speed / 30.0, 0.35, 1.0) * 8.0
			draw_set_transform(at, w.wind.angle())
			draw_rect(Rect2(-length, -0.5, length * 2.0, 1.0), ARROW)
			for k: int in range(3):
				draw_rect(Rect2(length - 1.0 - k, -k, 1.0, 1.0 + k * 2.0), ARROW)
			draw_set_transform(Vector2.ZERO)
		var x := at.x + 12.0
		if shaking:
			# Zigue-zague que treme com a turbulência.
			var jitter := sin(view.sim.frame * 0.9) * minf(1.5, w.turbulence)
			for k: int in range(5):
				draw_rect(Rect2(x + k, at.y - 2.0 + (2.0 if k % 2 == 0 else -1.0) + jitter, 1.0, 2.0), ARROW)
			x += 8.0
		if slow:
			# Resistência: duas ondas baixas (água pesada, gelo, cinzas).
			for row: int in range(2):
				for k: int in range(5):
					draw_rect(Rect2(x + k, at.y - 3.0 + row * 4.0 + (1.0 if k % 2 == 0 else 0.0), 1.0, 1.0), SLOW)
