class_name UiSpark
extends CanvasLayer
## Luz da interface por cima de tudo (1.9): onda e centelhas no ponto do toque de todo botão (dourado
## no botão principal, ciano nos outros) e a varredura de sonar que sobe pela tela quando uma tela
## nova entra. Uma camada só, instalada por UiFx.install; desenha em mistura aditiva com as texturas de
## efeito do projeto e só redesenha enquanto há algo vivo (parada, não custa nada).
## "Reduzir movimento" e "reduzir flashes" desligam tudo.

const LAYER := 90
const RIPPLE_TIME := 0.42
const RIPPLE_RADIUS := 30.0
const SPARKS := 6
const SPARK_TIME := 0.38
const SWEEP_TIME := 0.5
const MAX_RIPPLES := 6
const MAX_SPARKS := 48

static var instance: UiSpark

var _canvas: Node2D
var _ripples: Array[Dictionary] = []
var _sparks: Array[Dictionary] = []
var _sweep: float = -1.0
var _ring: Texture2D
var _glow: Texture2D
var _star: Texture2D
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	layer = LAYER
	name = "UiSpark"
	_rng.seed = 0x5EA


func _ready() -> void:
	instance = self
	_ring = SpriteBank.generated("fx/ring_128")
	_glow = SpriteBank.generated("fx/glow_32")
	_star = SpriteBank.generated("fx/sparkle_9")
	_canvas = Node2D.new()
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_canvas.material = add
	_canvas.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_canvas.draw.connect(_draw_fx)
	add_child(_canvas)
	set_process(false)


func _exit_tree() -> void:
	if instance == self:
		instance = null
		UiGlint.release()


## Toque num botão: onda que abre, clarão curto e centelhas para fora, no ponto em coordenadas de tela.
func ripple(at: Vector2, color: Color) -> void:
	if _quiet():
		return
	if _ripples.size() >= MAX_RIPPLES:
		_ripples.pop_front()
	_ripples.append({"at": at, "t": 0.0, "color": color})
	for k: int in range(SPARKS):
		if _sparks.size() >= MAX_SPARKS:
			break
		var angle := TAU * (k + _rng.randf_range(-0.3, 0.3)) / SPARKS
		var speed := _rng.randf_range(60.0, 110.0)
		_sparks.append({"at": at, "vel": Vector2.from_angle(angle) * speed, "t": 0.0,
				"life": SPARK_TIME * _rng.randf_range(0.7, 1.0), "color": color})
	_wake()


## Tela nova: uma faixa de luz sobe de baixo para cima (sonar), sem cobrir a leitura.
func sweep() -> void:
	if _quiet():
		return
	_sweep = 0.0
	_wake()


## Algo ainda está vivo (testes).
func busy() -> bool:
	return not _ripples.is_empty() or not _sparks.is_empty() or _sweep >= 0.0


func _quiet() -> bool:
	if UiFx.reduced():
		return true
	var settings := get_tree().root.get_node_or_null(^"Settings") if is_inside_tree() else null
	return settings != null and bool(settings.call("get_value", "reduce_flashes"))


func _wake() -> void:
	set_process(true)
	_canvas.queue_redraw()


func _process(delta: float) -> void:
	for r: Dictionary in _ripples:
		r["t"] = float(r["t"]) + delta
	_ripples = _ripples.filter(func(r: Dictionary) -> bool: return float(r["t"]) < RIPPLE_TIME)
	for s: Dictionary in _sparks:
		s["t"] = float(s["t"]) + delta
		s["vel"] = (s["vel"] as Vector2) * exp(-6.0 * delta)
		s["at"] = (s["at"] as Vector2) + (s["vel"] as Vector2) * delta
	_sparks = _sparks.filter(func(s: Dictionary) -> bool: return float(s["t"]) < float(s["life"]))
	if _sweep >= 0.0:
		_sweep += delta
		if _sweep > SWEEP_TIME:
			_sweep = -1.0
	_canvas.queue_redraw()
	if not busy():
		set_process(false)


func _draw_fx() -> void:
	if _sweep >= 0.0:
		var view := _canvas.get_viewport_rect().size
		var u := _sweep / SWEEP_TIME
		var y := lerpf(view.y + 40.0, -40.0, 1.0 - pow(1.0 - u, 2.0))
		var fade := sin(u * PI)
		_canvas.draw_texture_rect(_glow, Rect2(-view.x * 0.25, y - 48.0, view.x * 1.5, 96.0), false,
				Color(UiTheme.CYAN, 0.1 * fade))
		_canvas.draw_rect(Rect2(0.0, y, view.x, 1.0), Color(UiTheme.CYAN, 0.28 * fade))
	for r: Dictionary in _ripples:
		var u := float(r["t"]) / RIPPLE_TIME
		var at: Vector2 = r["at"]
		var color: Color = r["color"]
		var radius := RIPPLE_RADIUS * (1.0 - pow(1.0 - u, 3.0))
		_canvas.draw_texture_rect(_ring, Rect2(at - Vector2(radius, radius), Vector2(radius, radius) * 2.0), false,
				Color(color, 0.8 * (1.0 - u)))
		if u < 0.4:
			var g := 14.0 * (1.0 - u)
			_canvas.draw_texture_rect(_glow, Rect2(at - Vector2(g, g), Vector2(g, g) * 2.0), false,
					Color(color, 0.7 * (1.0 - u / 0.4)))
	for s: Dictionary in _sparks:
		var u := float(s["t"]) / float(s["life"])
		var size := 7.0 * (1.0 - u * 0.6)
		_canvas.draw_texture_rect(_star, Rect2((s["at"] as Vector2) - Vector2(size, size) * 0.5, Vector2(size, size)),
				false, Color(s["color"] as Color, 1.0 - u))
