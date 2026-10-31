class_name ResultsScreen
extends Screen
## Resultado da missão (plano mestre 7.5 e 19.4): pontuação, recorde, as 4 estrelas com o que
## faltou, números da partida, créditos ganhos e "Tentar de novo" sem anúncio.

var result: Dictionary = {}

var _background: ColorRect
var _scroll: ScrollContainer
var _box: VBoxContainer
var _title: Label
var _score: Label
var _record: Label
var _stars: Array[Label] = []
var _stats: Label
var _credits: Label
var _retry: Button
var _continue: Button


func _build() -> void:
	_background = ColorRect.new()
	_background.color = Color(UiTheme.ABYSS, 0.97)
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_background)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 8)
	_scroll.add_child(_box)
	_title = UiTheme.label("", UiTheme.TITLE_SIZE, UiTheme.GOLD, true)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(_title)
	_score = UiTheme.label("", UiTheme.TITLE_SIZE, UiTheme.WHITE)
	_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(_score)
	_record = UiTheme.label("", UiTheme.FONT_SIZE, UiTheme.CORAL)
	_record.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(_record)
	for i: int in range(4):
		var star := UiTheme.label("", UiTheme.FONT_SIZE, UiTheme.TEXT, true)
		_box.add_child(star)
		_stars.append(star)
	_stats = UiTheme.label("", UiTheme.FONT_SIZE, UiTheme.TEXT_DIM, true)
	_box.add_child(_stats)
	_credits = UiTheme.label("", UiTheme.HEADING_SIZE, UiTheme.GOLD)
	_credits.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(_credits)
	_retry = Button.new()
	_retry.name = "Retry"
	_retry.custom_minimum_size = Vector2(0, UiTheme.TOUCH_MIN + 6.0)
	_retry.pressed.connect(func() -> void: play.emit(StringName(String(result.get("mission", "c1m1")))))
	_box.add_child(_retry)
	_continue = Button.new()
	_continue.name = "Continue"
	_continue.custom_minimum_size = Vector2(0, UiTheme.TOUCH_MIN + 6.0)
	_continue.pressed.connect(func() -> void: navigate.emit(&"map"))
	_box.add_child(_continue)


func on_show(app: Node) -> void:
	result = app.get("last_result") if app != null else {}
	AudioManager.play_music("")
	refresh_texts()


func refresh_texts() -> void:
	var cleared := bool(result.get("cleared", false))
	_title.text = tr("results.cleared" if cleared else "results.failed")
	_title.add_theme_color_override("font_color", UiTheme.GOLD if cleared else UiTheme.CORAL)
	_score.text = Locale.format_number(int(result.get("score", 0)))
	_record.text = tr("results.record") if bool(result.get("record", false)) else ""
	var mission := Sim.load_mission(StringName(String(result.get("mission", "c1m1"))))
	var objective := String((mission.get("objective", {}) as Dictionary).get("text_key", "star.all_marked"))
	var texts := [tr("star.clear"), tr("star.no_damage"), tr("star.all_marked"), tr(objective)]
	var got: Array = result.get("stars", [false, false, false, false])
	for i: int in range(4):
		var on := i < got.size() and bool(got[i])
		_stars[i].text = ("★ " if on else "☆ ") + texts[i]
		_stars[i].add_theme_color_override("font_color", UiTheme.GOLD if on else UiTheme.TEXT_DIM)
	_stats.text = "%s %d   %s %d\n%s %d   %s %d" % [tr("results.kills"), int(result.get("kills", 0)),
			tr("results.grazes"), int(result.get("grazes", 0)), tr("results.chain"), int(result.get("max_chain", 0)),
			tr("results.medals"), int(result.get("medals", 0))]
	_credits.text = tr("results.credits") % Locale.format_number(int(result.get("credits", 0)))
	_retry.text = tr("results.retry")
	_continue.text = tr("results.continue")
	relayout()


func _layout() -> void:
	if _scroll == null:
		return
	var width := minf(safe.size.x - 24.0, 340.0)
	_scroll.position = Vector2(floorf(safe.position.x + (safe.size.x - width) * 0.5), safe.position.y + 12.0)
	_scroll.size = Vector2(width, safe.size.y - 24.0)
	_box.custom_minimum_size = Vector2(width - 8.0, 0)


func back() -> bool:
	navigate.emit(&"map")
	return true


func layout_controls() -> Array[Control]:
	return [_scroll]
