class_name HangarStage
extends Control
## Cena viva do hub (plano mestre 7.2, redesenho 1.6): a aeronave num pedestal holográfico em
## perspectiva, sobre o fundo abissal compartilhado (AbyssBackdrop), em 6 camadas de parallax. Arrastar
## inclina a nave e desloca as camadas; tocar a nave dá um pulso de motor; tocar o fundo solta uma onda
## de luz no pedestal. Sem fundo opaco: a água do App aparece atrás. Animação decorativa a 30 Hz, parada
## enquanto uma lista rola (TouchScroll.busy) e sem inclinação em "reduzir movimento".
##
## Só retângulos e texturas por quadro (docs/policies/qualidade.md).

signal ship_tapped

const FACTORS: Array[float] = [0.05, 0.15, 0.4, 1.0, 1.2, 1.5]
const REDRAW_HZ := 30.0
const SHIP_SIZE := 48.0

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
var _k: float = 2.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_ship = SpriteBank.texture("res://assets/art/void/main_ship/base_full.png")
	_engine = SpriteBank.texture("res://assets/art/void/main_ship/engine_base_powering.png")
	_glow = SpriteBank.generated("fx/glow_32")
	_ring = SpriteBank.generated("fx/ring_128")


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
		if at.distance_to(ship_center) < SHIP_SIZE * _k * 0.6:
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
	var k := clampf(floorf(minf(w * 0.85, h * 0.36) / 52.0), 2.0, 4.0)
	_k = k
	var floor_y := h * 0.6
	var cx := w * 0.5
	var pulse := 0.5 + 0.5 * sin(_time * 1.6)
	# 1: feixe de luz da superfície sobre o pedestal (some na água).
	var s1 := layer_shift(1)
	for i: int in range(3):
		var bw := (38.0 + 22.0 * i) * k * 0.5
		var alpha := 0.05 + 0.025 * sin(_time * 0.7 + i * 1.9)
		draw_texture_rect(_glow, Rect2(cx - bw * 0.5 + s1.x * (i + 1), -40.0, bw, floor_y + 40.0), false,
				Color(0.55, 0.95, 1.0, alpha))
	# 2: pedestal holográfico em perspectiva (anéis achatados = 2,5D) e onda de toque.
	var s2 := layer_shift(2)
	var base := Vector2(cx, floor_y) + s2
	var rx := 34.0 * k
	draw_texture_rect(_glow, Rect2(base - Vector2(rx * 1.6, rx * 0.5), Vector2(rx * 3.2, rx)), false,
			Color(0.18, 0.95, 0.88, 0.22 + 0.25 * _pulse))
	for ring: int in range(3):
		var r := rx * (1.0 + ring * 0.22)
		var col := Color(1.0, 0.79, 0.29, 0.75) if ring == 0 else Color(0.18, 0.95, 0.88, 0.45 - ring * 0.12)
		col.a *= 0.75 + 0.25 * sin(_time * 1.4 + ring)
		draw_texture_rect(_ring, Rect2(base - Vector2(r, r * 0.28), Vector2(r * 2.0, r * 0.56)), false, col)
	if _wave >= 0.0:
		var r := rx * (1.0 + _wave * 2.5)
		draw_texture_rect(_ring, Rect2(base - Vector2(r, r * 0.28), Vector2(r * 2.0, r * 0.56)), false,
				Color(0.18, 0.95, 0.88, maxf(0.0, 0.6 - _wave * 0.5)))
	# Coluna de holograma: faixas que sobem do pedestal até a nave.
	for i: int in range(6):
		var u := fmod(_time * 0.35 + i / 6.0, 1.0)
		var y := base.y - u * 64.0 * k * 0.5
		var hw := rx * (1.0 - u * 0.35)
		draw_rect(Rect2(base.x - hw, y, hw * 2.0, 1.0), Color(0.18, 0.95, 0.88, 0.22 * (1.0 - u)))
	# 3: sombra, nave e motor.
	var s3 := layer_shift(3)
	var bob := sin(_time * 1.8) * 2.0 * k * 0.5
	ship_center = Vector2(cx, floor_y - 30.0 * k + bob) + s3
	var lean := clampf((tilt + _drag_tilt).x, -1.0, 1.0) * 0.16
	var shadow_w := 26.0 * k * (1.0 - bob * 0.01)
	draw_texture_rect(_glow, Rect2(base + Vector2(-shadow_w, -shadow_w * 0.16), Vector2(shadow_w * 2.0, shadow_w * 0.32)),
			false, Color(0.0, 0.02, 0.05, 0.55))
	var frames := maxi(1, _engine.get_width() / 48)
	var frame := SpriteBank.frame_rect(int(_time * 12.0) % frames, 48)
	draw_set_transform(ship_center, lean, Vector2(k, k))
	draw_texture_rect_region(_engine, Rect2(-24, -24, 48, 48), frame, Color(1, 1, 1, 0.75 + 0.25 * _pulse))
	draw_texture(_ship, Vector2(-24, -24))
	draw_set_transform(Vector2.ZERO)
	# Varredura de scanner subindo pela nave (holograma do hangar).
	var scan := fmod(_time * 0.45, 1.6)
	if scan < 1.0:
		var sy := ship_center.y + 24.0 * k - scan * 48.0 * k
		draw_rect(Rect2(ship_center.x - 26.0 * k, sy, 52.0 * k, 1.0), Color(0.18, 0.95, 0.88, 0.35 * (1.0 - scan)))
	# 4: centelhas do pedestal subindo.
	var s4 := layer_shift(4)
	for i: int in range(10):
		var u := fmod(_time * 0.5 + i * 0.137, 1.0)
		var x := base.x + (float(absi(hash(i * 13)) % 200) / 100.0 - 1.0) * rx + s4.x
		draw_rect(Rect2(x, base.y - u * 50.0 * k * 0.5 + s4.y, 2.0, 2.0),
				Color(1.0, 0.85, 0.45, (1.0 - u) * (0.5 + 0.5 * pulse)))
	# 5: bolhas de primeiro plano, raras e nas bordas (não competem com a nave).
	var s5 := layer_shift(5)
	for i: int in range(10):
		var u := fmod(_time * (0.05 + 0.012 * (i % 4)) + i * 0.097, 1.0)
		var edge := float(absi(hash(i * 7)) % 1000) / 1000.0
		var x := (edge * 0.22 if i % 2 == 0 else 1.0 - edge * 0.22) * w + s5.x
		var r := 2.0 + float(i % 3)
		draw_texture_rect(_glow, Rect2(x - r, h * (1.0 - u) + s5.y - r, r * 2.0, r * 2.0), false,
				Color(0.6, 0.95, 1.0, 0.28))
