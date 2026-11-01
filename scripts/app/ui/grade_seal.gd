class_name GradeSeal
extends HBoxContainer
## Selo da nota da missão na tela de resultado: roseta vetorial na cor da letra (bronze, prata,
## turquesa, ouro, violeta), a letra no centro e, ao lado, "Nota da missão" e o aviso de nota nova.
## O carimbo (stamp) entra grande e assenta com salto; S e SS soltam centelhas na roseta.

const SIZE := 58.0
const PETALS := 12

var grade: int = Grade.NONE
var _seal: Control
var _caption: Label
var _tag: Label


func _init() -> void:
	name = "GradeSeal"
	alignment = BoxContainer.ALIGNMENT_CENTER
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	add_theme_constant_override("separation", 10)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_seal = Control.new()
	_seal.custom_minimum_size = Vector2(SIZE, SIZE)
	_seal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_seal.draw.connect(_draw_seal)
	add_child(_seal)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 0)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(col)
	_caption = UiTheme.label("", UiTheme.SMALL_SIZE, UiTheme.TEXT_DIM)
	col.add_child(_caption)
	_tag = UiTheme.heading("", UiTheme.FONT_SIZE, UiTheme.GOLD)
	col.add_child(_tag)


func setup(result: Dictionary) -> void:
	grade = int(result.get("grade", Grade.NONE))
	visible = grade != Grade.NONE
	_caption.text = tr("results.grade")
	if bool(result.get("grade_new", false)):
		_tag.text = tr("results.grade_new")
	elif bool(result.get("grade_first", false)):
		_tag.text = tr("results.grade_first")
	else:
		_tag.text = ""
	_tag.visible = not _tag.text.is_empty()
	_tag.add_theme_color_override("font_color", Grade.color(grade).lightened(0.2))
	_seal.queue_redraw()


## O nó que recebe o carimbo (a roseta).
func seal() -> Control:
	return _seal


## Som e centelhas do carimbo: o tom sobe com a nota; S e SS acendem a roseta.
func celebrate() -> void:
	AudioManager.play("kenney_medal", 0.9 + 0.12 * maxi(0, grade), 0.0, 0.0, "UI")
	if grade >= Grade.S:
		AudioManager.play_ui("kenney_weapon_up")
		if UiSpark.instance != null and is_inside_tree():
			UiSpark.instance.ripple(_seal.get_global_transform_with_canvas() * (_seal.size * 0.5), Grade.color(grade))


func _draw_seal() -> void:
	var c := _seal.size * 0.5
	var r := minf(_seal.size.x, _seal.size.y) * 0.5
	var tint := Grade.color(grade)
	_seal.draw_circle(c, r, Color(tint, 0.16))
	var rosette := PackedVector2Array()
	for k: int in range(PETALS * 2):
		var a := -PI * 0.5 + k * PI / PETALS
		rosette.append(c + Vector2(cos(a), sin(a)) * (r * 0.92 if k % 2 == 0 else r * 0.78))
	_seal.draw_colored_polygon(rosette, tint)
	_seal.draw_circle(c, r * 0.66, UiTheme.ABYSS)
	_seal.draw_arc(c, r * 0.6, 0.0, TAU, 40, Color(tint, 0.7), 1.5, true)
	var font := UiTheme.bold_font()
	if font == null:
		font = ThemeDB.fallback_font
	var text := Grade.letter(grade)
	var font_size := 26 if text.length() == 1 else 20
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var baseline := c.y + (font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5
	_seal.draw_string(font, Vector2(c.x - w * 0.5, baseline), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size,
			tint.lightened(0.35))
