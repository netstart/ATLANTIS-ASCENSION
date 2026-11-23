class_name HostileBeams
extends Node2D
## Feixes inimigos dos padrões (op "beam": EnemyBeam na revisão 6 da Sim, verticais e parados nas antigas). Só
## desenho: lê Sim.beams, nunca escreve. Feixes do cenário (com "kind": raio, gêiser) ficam com o WorldView.
## - Corpo: um quad por feixe com shaders/hostile_beam.gdshader, girado no ângulo dele, da boca até além da borda do
##   campo: núcleo branco-quente, corpo vermelho-magenta, halo macio e pulsos correndo para fora. Abre em
##   OPEN_FRAMES e fecha em CLOSE_FRAMES passos (sem estalo; o feixe cortado pela morte do emissor fecha igual).
## - Luz (este nó, aditivo): carga crescendo na boca durante o aviso, clarão na boca e respingo onde o feixe bate na
##   borda do campo, com faíscas voltando contra ele.
## - Aviso (warning, chamado pelo WorldView na camada normal): linhas finas piscando ao longo da mira real, com
##   sombra escura por baixo para ler em fundo claro; piscam mais rápido quando a mira trava (EnemyBeam.LOCK_FRAMES).
## "Menos clarões" baixa cintilação, pulsos, faíscas e brilho.

const SHADER := preload("res://shaders/hostile_beam.gdshader")
const POOL := 8
const OPEN_FRAMES := 5.0
const CLOSE_FRAMES := 7.0
## Largura do quad em vezes a largura que fere (o corpo do shader, body_w = 1 / SPAN, é a faixa que fere).
const SPAN := 4.4
## Quanto o quad passa da borda do campo (a ponta apaga fora da tela).
const OVERSHOOT := 24.0
const CORE := Color(1.0, 0.97, 0.95)
const BODY := Color(1.0, 0.2, 0.42)
const HALO := Color(0.85, 0.05, 0.6)
const WARN := Color(1.0, 0.36, 0.5, 0.8)
const WARN_SHADOW := Color(0.12, 0.0, 0.04, 0.5)
## Faíscas no respingo: uma a cada SPARK_GAP s por feixe aceso.
const SPARK_GAP := 0.045

var reduce_flashes := false

var _sim: Sim
var _fx: CombatFx
var _flare: Texture2D
var _tex: Texture2D
var _quads: Array[_Quad] = []
var _time := 0.0
var _spark := 0.0
var _drawn := false
var _rng := RandomNumberGenerator.new()


func setup(sim: Sim, fx: CombatFx, flare: Texture2D) -> void:
	_sim = sim
	_fx = fx
	_flare = flare
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = add
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	_tex = ImageTexture.create_from_image(img)
	for k: int in range(POOL):
		var q := _Quad.new()
		var mat := ShaderMaterial.new()
		mat.shader = SHADER
		mat.set_shader_parameter(&"core_color", CORE)
		mat.set_shader_parameter(&"body_color", BODY)
		mat.set_shader_parameter(&"halo_color", HALO)
		mat.set_shader_parameter(&"body_w", 1.0 / SPAN)
		mat.set_shader_parameter(&"core_w", 0.4 / SPAN)
		mat.set_shader_parameter(&"seed", k * 1.7)
		q.material = mat
		q.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		q.tex = _tex
		q.visible = false
		# Luz da boca e do respingo (este nó) por cima do corpo.
		q.show_behind_parent = true
		_quads.append(q)
		add_child(q)


## Feixe de padrão (não do cenário).
static func pattern(b: Dictionary) -> bool:
	return not b.has("kind")


static func angle_of(b: Dictionary) -> float:
	return float(b.get("angle", PI * 0.5))


## 0..1: quanto o feixe aceso está aberto (rampa de abertura e de fechamento).
static func open_of(b: Dictionary) -> float:
	var lit := int(b["age"]) - int(b["warn"])
	if lit < 0:
		return 0.0
	var left := int(b["warn"]) + int(b["frames"]) - int(b["age"])
	var u := minf(clampf((lit + 1) / OPEN_FRAMES, 0.0, 1.0), clampf(left / CLOSE_FRAMES, 0.0, 1.0))
	return u * u * (3.0 - 2.0 * u)


## Linhas do aviso ao longo da mira. Feixe do cenário: vertical, até abaixo do campo, como sempre foi.
static func warning(ci: CanvasItem, b: Dictionary, field: Vector2, color: Color) -> void:
	var at := Vector2(float(b["x"]), float(b["y"]))
	var w := float(b["width"])
	var age := int(b["age"])
	var mine := pattern(b)
	var length := field.y + 40.0 - at.y
	var period := 4.0
	if mine:
		var dir := Vector2.from_angle(angle_of(b))
		length = EnemyBeam.reach(at, dir, field, OVERSHOOT)
		if bool(b.get("aim", false)) and age >= EnemyBeam.lock_at(int(b["warn"])):
			period = 2.0
	var on := floori(age / period) % 2 == 0
	var a := color.a * (1.0 if on else 0.35)
	ci.draw_set_transform(at, angle_of(b) - PI * 0.5)
	if mine:
		var sa := WARN_SHADOW.a * (1.0 if on else 0.5)
		ci.draw_rect(Rect2(-w * 0.5 - 1.0, 0.0, 3.0, length), Color(WARN_SHADOW, sa))
		ci.draw_rect(Rect2(w * 0.5 - 2.0, 0.0, 3.0, length), Color(WARN_SHADOW, sa))
	ci.draw_rect(Rect2(-w * 0.5, 0.0, 1.0, length), Color(color, a))
	ci.draw_rect(Rect2(w * 0.5 - 1.0, 0.0, 1.0, length), Color(color, a))
	ci.draw_rect(Rect2(-0.5, 0.0, 1.0, length), Color(color, a * 0.5))
	ci.draw_set_transform(Vector2.ZERO)


func refresh(delta: float, time: float) -> void:
	_time = time
	var used := 0
	var calm := 0.35 if reduce_flashes else 1.0
	var busy := false
	for b: Dictionary in _sim.beams:
		if not pattern(b):
			continue
		busy = true
		var k := open_of(b)
		if k <= 0.0 or used >= POOL:
			continue
		var q := _quads[used]
		used += 1
		var at := Vector2(float(b["x"]), float(b["y"]))
		var dir := Vector2.from_angle(angle_of(b))
		var w := float(b["width"]) * SPAN
		q.length = maxf(4.0, EnemyBeam.reach(at, dir, _sim.field, OVERSHOOT))
		q.width = w
		q.at = at
		q.rot = angle_of(b) - PI * 0.5
		var mat := q.material as ShaderMaterial
		mat.set_shader_parameter(&"length_u", q.length)
		mat.set_shader_parameter(&"width_u", w)
		mat.set_shader_parameter(&"intensity", k)
		mat.set_shader_parameter(&"shimmer", calm)
		mat.set_shader_parameter(&"halo", 0.42 * (0.75 if reduce_flashes else 1.0))
		mat.set_shader_parameter(&"t", time)
		q.visible = true
		q.queue_redraw()
	for i: int in range(used, POOL):
		_quads[i].visible = false
	_spark += delta
	if busy or _drawn:
		queue_redraw()
	_drawn = busy


func _draw() -> void:
	var calm := 0.6 if reduce_flashes else 1.0
	var sparks := _spark >= SPARK_GAP * (2.0 if reduce_flashes else 1.0)
	if sparks:
		_spark = 0.0
	for b: Dictionary in _sim.beams:
		if not pattern(b):
			continue
		var at := Vector2(float(b["x"]), float(b["y"]))
		var w := float(b["width"])
		var age := int(b["age"])
		var warn := int(b["warn"])
		if age < warn:
			# Carga na boca: cresce até o disparo e pisca junto com as linhas do aviso.
			var u := float(age) / maxf(1.0, warn)
			var beat := 0.8 + 0.2 * sin(_time * 40.0) * calm
			_glow(at, w / 30.0 * (0.4 + 0.9 * u) * beat, Color(HALO, (0.25 + 0.45 * u) * calm))
			_glow(at, w / 70.0 * (0.3 + 0.8 * u), Color(CORE, (0.3 + 0.5 * u) * calm))
			continue
		var k := open_of(b)
		if k <= 0.0:
			continue
		var dir := Vector2.from_angle(angle_of(b))
		var flick := 1.0 + 0.12 * sin(_time * 53.0 + at.x) * calm
		_glow(at, w / 14.0 * (0.8 + 0.25 * k) * flick, Color(BODY, 0.55 * k * calm))
		_glow(at, w / 28.0 * flick, Color(CORE, 0.85 * k))
		var hit := at + dir * EnemyBeam.reach(at, dir, _sim.field)
		_glow(hit, w / 12.0 * flick, Color(HALO, 0.6 * k * calm))
		_glow(hit, w / 26.0 * (1.0 + 0.2 * sin(_time * 70.0) * calm), Color(CORE, 0.8 * k))
		if sparks and k > 0.5:
			for n: int in range(2 if reduce_flashes else 3):
				var v := Vector2.from_angle(dir.angle() + PI + _rng.randf_range(-1.0, 1.0)) * _rng.randf_range(70.0, 160.0)
				_fx.light.spawn(CombatFx.STREAK, hit, v, _rng.randf_range(0.12, 0.24), 0.5, 0.2, Color(BODY, 0.9 * calm),
						Color(HALO, 0.0), 6.0, Vector2.ZERO, 0.0, 0.0, true)


func _glow(at: Vector2, scale: float, color: Color) -> void:
	var size := _flare.get_size() * scale
	draw_texture_rect(_flare, Rect2(at - size * 0.5, size), false, color)


## Um feixe: o quad girado na direção dele (UV.y da boca para fora).
class _Quad:
	extends Node2D

	var tex: Texture2D
	var at := Vector2.ZERO
	var rot := 0.0
	var length := 0.0
	var width := 0.0

	func _draw() -> void:
		draw_set_transform(at, rot)
		draw_texture_rect(tex, Rect2(-width * 0.5, 0.0, width, length), false)
