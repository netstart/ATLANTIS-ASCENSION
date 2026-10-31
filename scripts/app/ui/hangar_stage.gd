class_name HangarStage
extends Control
## Cena viva do hub (plano mestre 7.2): o hangar da Halcyon em 6 camadas de parallax, com a aeronave
## no centro. Arrastar gira a nave (inclinação) e desloca as camadas; tocar a nave dá um pulso de
## motor; tocar o fundo solta uma onda de luz nos cristais. Animação decorativa a 30 Hz, parada
## enquanto uma lista rola (TouchScroll.busy) e sem inclinação em "reduzir movimento".
##
## Só retângulos e texturas por quadro (docs/policies/qualidade.md).

signal ship_tapped

const FACTORS: Array[float] = [0.05, 0.15, 0.4, 1.0, 1.2, 1.5]
const REDRAW_HZ := 30.0
const SHIP_SIZE := 48.0
const SHIP_SCALE := 2.0

var tilt := Vector2.ZERO
var reduce_motion: bool = false
var ship_center := Vector2.ZERO

var _time: float = 0.0
var _redraw_wait: float = 0.0
var _drag_tilt := Vector2.ZERO
var _pulse: float = 0.0
var _wave: float = -1.0
var _wave_at := Vector2.ZERO
var _ship: Texture2D
var _engine: Texture2D
var _glow: Texture2D
var _ring: Texture2D
var _gradient: GradientTexture2D


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_ship = SpriteBank.texture("res://assets/art/void/main_ship/base_full.png")
	_engine = SpriteBank.texture("res://assets/art/void/main_ship/engine_base_powering.png")
	_glow = SpriteBank.generated("fx/glow_32")
	_ring = SpriteBank.generated("fx/ring_128")
	var g := Gradient.new()
	g.set_color(0, Color("06122a"))
	g.set_color(1, Color("0f3a52"))
	_gradient = GradientTexture2D.new()
	_gradient.gradient = g
	_gradient.fill_from = Vector2(0.5, 0.0)
	_gradient.fill_to = Vector2(0.5, 1.0)
	_gradient.width = 4
	_gradient.height = 128


func _process(delta: float) -> void:
	_time += delta
	_pulse = maxf(0.0, _pulse - delta * 2.0)
	if _wave >= 0.0:
		_wave += delta
		if _wave > 1.2:
			_wave = -1.0
	_drag_tilt = _drag_tilt.lerp(Vector2.ZERO, minf(1.0, delta * 2.5))
	_redraw_wait -= delta
	if _redraw_wait <= 0.0 and not TouchScroll.busy():
		_redraw_wait = 1.0 / REDRAW_HZ
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenDrag:
		_drag_tilt = (_drag_tilt + (event as InputEventScreenDrag).relative * 0.02).limit_length(1.0)
		accept_event()
	elif event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		var at := (event as InputEventScreenTouch).position
		if at.distance_to(ship_center) < SHIP_SIZE * SHIP_SCALE * 0.6:
			_pulse = 1.0
			ship_tapped.emit()
		else:
			_wave = 0.0
			_wave_at = at
		accept_event()


## Deslocamento de uma camada pela inclinação (arrasto + acelerômetro), via ParallaxRig.
func layer_shift(index: int) -> Vector2:
	var t := tilt + _drag_tilt
	return ParallaxRig.layer_offset(0.0, FACTORS[index], 0.0, t, FACTORS[index], reduce_motion)


func _draw() -> void:
	var w := size.x
	var h := size.y
	var floor_y := h * 0.62
	draw_texture_rect(_gradient, Rect2(Vector2.ZERO, size), false)
	# 1: cidade atlante distante pela abertura do hangar (torres com filete dourado).
	var s1 := layer_shift(1)
	for i: int in range(11):
		var x := w * (i + 0.5) / 11.0 + s1.x
		var th := 50.0 + float(absi(hash(i * 31)) % 80)
		draw_rect(Rect2(x - 6.0, floor_y - 90.0 - th + s1.y, 12.0, th), Color(0.06, 0.18, 0.28))
		draw_rect(Rect2(x - 7.0, floor_y - 92.0 - th + s1.y, 14.0, 2.0), Color(0.91, 0.72, 0.29, 0.45))
	# 2: portal atlante atrás da nave, feixes de luz e dois pilares.
	var s2 := layer_shift(2)
	var portal := Vector2(w * 0.5, floor_y - 70.0) + s2
	var ring_r := minf(w * 0.42, 150.0)
	var spin := 0.85 + 0.15 * sin(_time * 1.4)
	draw_texture_rect(_glow, Rect2(portal - Vector2(ring_r, ring_r) * 1.3, Vector2(ring_r, ring_r) * 2.6), false,
			Color(0.12, 0.6, 0.7, 0.25))
	draw_texture_rect(_ring, Rect2(portal - Vector2(ring_r, ring_r), Vector2(ring_r, ring_r) * 2.0), false,
			Color(0.91, 0.72, 0.29, 0.7 * spin))
	draw_texture_rect(_ring, Rect2(portal - Vector2(ring_r, ring_r) * 0.8, Vector2(ring_r, ring_r) * 1.6), false,
			Color(0.25, 0.95, 0.95, 0.35 + 0.25 * _pulse))
	for k: int in range(3):
		var bx := portal.x + (k - 1) * ring_r * 0.55
		var alpha := 0.06 + 0.04 * sin(_time * 0.8 + k * 1.7)
		draw_texture_rect(_glow, Rect2(bx - 18.0, 0.0, 36.0, floor_y + s2.y), false, Color(0.6, 0.95, 1.0, alpha))
	for side: float in [-1.0, 1.0]:
		var px := w * 0.5 + side * minf(w * 0.44, 190.0) + s2.x
		draw_rect(Rect2(px - 14.0, h * 0.1 + s2.y, 28.0, floor_y - h * 0.1), Color(0.07, 0.2, 0.3))
		draw_rect(Rect2(px - 14.0, h * 0.1 + s2.y, 3.0, floor_y - h * 0.1), Color(0.12, 0.32, 0.42))
		for c: int in range(4):
			var glow := 0.4 + 0.4 * sin(_time * 2.0 + c + side)
			if _wave >= 0.0:
				glow += maxf(0.0, 1.0 - absf(_wave * w - absf(px - _wave_at.x)) / 60.0)
			draw_texture_rect(_glow, Rect2(px - 8.0, h * 0.16 + c * 46.0 + s2.y, 16.0, 16.0), false,
					Color(0.25, 0.95, 0.95, clampf(glow, 0.0, 1.0)))
	# 3: plataforma (elipse de luz, filete dourado, reflexo) e a nave.
	var s3 := layer_shift(3)
	var deck := Rect2(w * 0.12 + s3.x, floor_y + s3.y, w * 0.76, h - floor_y)
	draw_rect(deck, Color(0.05, 0.14, 0.2))
	draw_rect(Rect2(deck.position, Vector2(deck.size.x, 2.0)), Color(0.91, 0.72, 0.29))
	draw_texture_rect(_glow, Rect2(w * 0.5 - 90.0 + s3.x, floor_y - 18.0 + s3.y, 180.0, 40.0), false,
			Color(0.3, 0.9, 1.0, 0.3 + 0.35 * _pulse))
	var bob := sin(_time * 2.2) * 2.0
	ship_center = Vector2(w * 0.5, floor_y - 44.0 + bob) + s3
	var lean := clampf((tilt + _drag_tilt).x, -1.0, 1.0) * 0.18
	var frames := maxi(1, _engine.get_width() / 48)
	var frame := SpriteBank.frame_rect(int(_time * 12.0) % frames, 48)
	# Reflexo no piso (espelhado, transparente).
	draw_set_transform(Vector2(ship_center.x, floor_y + 34.0 + s3.y), lean, Vector2(SHIP_SCALE, -SHIP_SCALE * 0.6))
	draw_texture(_ship, Vector2(-24, -24), Color(0.5, 0.8, 1.0, 0.18))
	draw_set_transform(ship_center, lean, Vector2(SHIP_SCALE, SHIP_SCALE))
	draw_texture_rect_region(_engine, Rect2(-24, -24, 48, 48), frame, Color(1, 1, 1, 0.6 + 0.4 * _pulse))
	draw_texture(_ship, Vector2(-24, -24))
	draw_set_transform(Vector2.ZERO)
	# 4: faíscas de manutenção subindo da plataforma.
	var s4 := layer_shift(4)
	for i: int in range(8):
		var u := fmod(_time * 0.6 + i * 0.29, 1.0)
		var x := w * (0.18 + 0.09 * i) + s4.x
		draw_rect(Rect2(x, floor_y - u * 40.0 + s4.y, 2.0, 2.0), Color(1.0, 0.85, 0.4, 1.0 - u))
	# 5: poeira de luz de primeiro plano.
	var s5 := layer_shift(5)
	for i: int in range(16):
		var u := fmod(_time * (0.04 + 0.01 * (i % 4)) + i * 0.063, 1.0)
		var x := fmod(float(absi(hash(i * 7)) % 1000) / 1000.0 * w + s5.x, w)
		draw_rect(Rect2(x, h * (1.0 - u) + s5.y, 2.0, 2.0), Color(0.6, 0.95, 1.0, 0.22))
