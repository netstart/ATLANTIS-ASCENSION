class_name DefeatPanel
extends PanelContainer
## "Quase lá" na tela de resultado da derrota (DefeatInsight): barra da missão que enche até onde o
## jogador chegou (com a marca do chefe final), o casco que restou ao chefe e uma dica tirada da
## partida. Fica entre o título e as estrelas: é a primeira coisa que se lê depois de "Missão falhou".

const BAR_HEIGHT := 8.0
## Parte da barra que é do chefe final (os 10% finais, como em Sim.progress).
const BOSS_MARK := 0.9

var insight: Dictionary = {}
var fill: float = 0.0:
	set(value):
		fill = value
		if _bar != null:
			_bar.queue_redraw()
var _headline: Label
var _bar: Control
var _numbers: Label
var _tip: Label


func _init() -> void:
	name = "Defeat"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := UiTheme.chamfer(Color(UiTheme.CORAL, 0.08), Color(UiTheme.CORAL, 0.45), 1, 5)
	box.content_margin_left = 10
	box.content_margin_right = 10
	box.content_margin_top = 6
	box.content_margin_bottom = 8
	add_theme_stylebox_override("panel", box)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(col)
	_headline = UiTheme.heading("", UiTheme.HEADING_SIZE, UiTheme.GOLD)
	_headline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_headline)
	_bar = Control.new()
	_bar.custom_minimum_size = Vector2(0, BAR_HEIGHT)
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.draw.connect(_draw_bar)
	col.add_child(_bar)
	_numbers = UiTheme.label("", UiTheme.SMALL_SIZE, UiTheme.TEXT_DIM)
	_numbers.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_numbers)
	_tip = UiTheme.label("", UiTheme.FONT_SIZE, UiTheme.TEXT, true)
	_tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_tip)


## Mostra o painel para uma derrota fora da Prática e dos modos de corrida.
func setup(result: Dictionary) -> void:
	insight = DefeatInsight.analyze(result)
	var mode := String(result.get("mode", ""))
	visible = not insight.is_empty() and mode in ["", "daily", "currents"]
	if not visible:
		return
	var close := bool(insight["close"])
	_headline.text = tr("defeat.close") if close else tr("defeat.far")
	_headline.add_theme_color_override("font_color", UiTheme.GOLD if close else UiTheme.TEXT)
	var numbers := PackedStringArray([tr("defeat.progress") % int(insight["progress"])])
	if int(insight["boss"]) >= 0:
		numbers.append(tr("defeat.boss") % int(insight["boss"]))
	_numbers.text = "   ".join(numbers)
	var tip := tr(String(insight["tip"]))
	_tip.text = tip % int(insight["tip_arg"]) if tip.contains("%d") else tip
	fill = progress()


func progress() -> float:
	return float(insight.get("progress", 0)) / 100.0


## A barra enche do zero até onde o jogador chegou.
func play() -> void:
	if not visible:
		return
	fill = 0.0
	var t := create_tween()
	t.tween_property(self, "fill", progress(), 0.7).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func finish() -> void:
	fill = progress()


func _draw_bar() -> void:
	var w := _bar.size.x
	var h := _bar.size.y
	_bar.draw_rect(Rect2(0, 0, w, h), Color(UiTheme.ABYSS, 0.8))
	var tint := UiTheme.GOLD if bool(insight.get("close", false)) else UiTheme.CORAL
	_bar.draw_rect(Rect2(0, 0, w * clampf(fill, 0.0, 1.0), h), tint)
	# Marca do chefe final e a ponta acesa da barra.
	_bar.draw_rect(Rect2(floorf(w * BOSS_MARK), -2, 1, h + 4), Color(UiTheme.WHITE, 0.5))
	if fill > 0.0:
		_bar.draw_rect(Rect2(maxf(0.0, w * fill - 2.0), -1, 2, h + 2), UiTheme.WHITE)
	_bar.draw_rect(Rect2(0, 0, w, h), Color(tint, 0.6), false, 1.0)
