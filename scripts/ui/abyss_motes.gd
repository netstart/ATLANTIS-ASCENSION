class_name AbyssMotes
extends Control
## Plâncton luminoso dos menus (1.9): pontos de luz que sobem devagar pela água do fundo compartilhado,
## balançam com a corrente e piscam, em três profundidades que seguem o parallax do dedo. A cor segue o
## destaque do humor da tela (AbyssBackdrop.MOODS), com alguns brancos e raros dourados.
##
## Desenhado em mistura aditiva com a textura de brilho do projeto, a 30 Hz junto com o fundo (quem
## chama queue_redraw é o AbyssBackdrop). Posições vêm de hash fixo: nada aleatório, nada global.

const COUNT := 42

var clock: float = 0.0
var parallax := Vector2.ZERO
var accent := Color("2ff3e0")

var _glow: Texture2D


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = add


func _ready() -> void:
	_glow = SpriteBank.generated("fx/glow_32")


## Posição e brilho de um ponto (testes): x, y, raio, alfa.
func mote(i: int) -> Vector4:
	var w := maxf(size.x, 1.0)
	var h := maxf(size.y, 1.0)
	var depth := 0.35 + 0.65 * _unit(i, 3)
	var speed := (6.0 + 10.0 * _unit(i, 5)) * depth
	var y := fposmod(_unit(i, 7) * (h + 40.0) - clock * speed, h + 40.0) - 20.0
	var sway := sin(clock * (0.3 + 0.3 * _unit(i, 11)) + i) * 7.0 * depth
	var x := _unit(i, 13) * w + sway + parallax.x * 14.0 * depth
	var twinkle := 0.6 + 0.4 * sin(clock * (1.2 + 1.6 * _unit(i, 17)) + i * 2.3)
	var radius := (1.2 + 2.2 * _unit(i, 19)) * (0.6 + depth * 0.6)
	return Vector4(x, y + parallax.y * 10.0 * depth, radius, (0.3 + 0.5 * depth) * twinkle)


func _draw() -> void:
	if _glow == null:
		return
	for i: int in range(COUNT):
		var m := mote(i)
		var color := accent
		if i % 10 == 3:
			color = UiTheme.GOLD
		elif i % 3 == 0:
			color = Color(0.85, 0.97, 1.0)
		var halo := m.z * 3.2
		draw_texture_rect(_glow, Rect2(m.x - halo, m.y - halo, halo * 2.0, halo * 2.0), false,
				Color(color, m.w * 0.45))
		draw_texture_rect(_glow, Rect2(m.x - m.z, m.y - m.z, m.z * 2.0, m.z * 2.0), false, Color(color, m.w))


static func _unit(i: int, salt: int) -> float:
	return float(absi(hash(i * 131 + salt * 7919)) % 10000) / 10000.0
