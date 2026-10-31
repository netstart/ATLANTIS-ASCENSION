class_name StoryScreen
extends Screen
## Cenas da história entre missões (plano mestre 3.5): 2 a 5 quadros de fala sobre o cenário do
## capítulo em movimento lento. Tocar avança; "Pular" fecha. Cada cena aparece uma vez, quando uma
## das missões de `after_any` foi concluída (a de lista vazia é o prólogo). Dados: data/story.json.

const SCROLL_SPEED := 14.0

var scene: Dictionary = {}
var index: int = 0

var _backdrop: OceanBackdrop
var _shade: ColorRect
var _panel: PanelContainer
var _speaker: Label
var _text: Label
var _next: Button
var _skip: Button
var _scroll: float = 0.0


## Próxima cena ainda não vista cujo gatilho já aconteceu (ou {}).
static func pending(profile: Dictionary) -> Dictionary:
	var seen: Array = profile["story"].get("seen", [])
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/story.json"))
	if typeof(parsed) != TYPE_ARRAY:
		return {}
	for row: Variant in parsed:
		var s := row as Dictionary
		if seen.has(String(s["id"])):
			continue
		if s.has("ending"):
			if (profile["story"]["endings"] as Array).has(String(s["ending"])):
				return s
			continue
		var after: Array = s.get("after_any", [])
		if after.is_empty():
			return s
		for m: Variant in after:
			if Economy.cleared(profile, StringName(String(m))):
				return s
	return {}


func _build() -> void:
	_backdrop = OceanBackdrop.new()
	add_child(_backdrop)
	_shade = ColorRect.new()
	_shade.color = Color(UiTheme.ABYSS, 0.45)
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_shade)
	_panel = PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(UiTheme.ABYSS, 0.92)
	box.border_color = UiTheme.TURQUOISE
	box.set_border_width_all(1)
	box.set_corner_radius_all(4)
	box.set_content_margin_all(14)
	_panel.add_theme_stylebox_override("panel", box)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	_panel.add_child(col)
	_speaker = UiTheme.label("", UiTheme.HEADING_SIZE, UiTheme.GOLD)
	col.add_child(_speaker)
	_text = UiTheme.label("", UiTheme.FONT_SIZE, UiTheme.TEXT, true)
	col.add_child(_text)
	_next = Button.new()
	_next.name = "Next"
	_next.custom_minimum_size = Vector2(0, UiTheme.TOUCH_MIN)
	_next.pressed.connect(advance)
	col.add_child(_next)
	add_child(_panel)
	_skip = Button.new()
	_skip.name = "Skip"
	_skip.custom_minimum_size = Vector2(88, UiTheme.TOUCH_MIN)
	_skip.pressed.connect(finish)
	add_child(_skip)


func on_show(_app: Node) -> void:
	scene = pending(SaveManager.data)
	index = 0
	if scene.is_empty():
		navigate.emit(&"map")
		return
	refresh_texts()


func advance() -> void:
	AudioManager.play_ui("kenney_ui_click")
	index += 1
	if index >= (scene.get("panels", []) as Array).size():
		finish()
		return
	refresh_texts()


## Marca a cena como vista e segue para o mapa (de onde a próxima missão começa).
func finish() -> void:
	if not scene.is_empty():
		var story: Dictionary = SaveManager.data["story"]
		if not story.has("seen"):
			story["seen"] = []
		(story["seen"] as Array).append(String(scene["id"]))
		if String(scene["id"]) == "prologue":
			story["prologue_seen"] = true
		SaveManager.save_profile()
	scene = {}
	navigate.emit(&"map")


func refresh_texts() -> void:
	if _skip == null:
		return
	_skip.text = tr("story.skip")
	var panels: Array = scene.get("panels", [])
	if index >= panels.size():
		return
	var p := panels[index] as Dictionary
	_speaker.text = tr("speaker." + String(p.get("speaker", "")))
	_text.text = tr(String(p.get("text_key", "")))
	_next.text = tr("story.next") if index < panels.size() - 1 else tr("story.continue")
	var kind := StringName(String(p.get("backdrop", "ocean")))
	if _backdrop.kind != kind:
		# A paleta é lida no _ready do cenário: trocar de capítulo recria a camada.
		_backdrop.queue_free()
		_backdrop = OceanBackdrop.new()
		_backdrop.kind = kind
		add_child(_backdrop)
		move_child(_backdrop, 0)
	relayout()


func _process(delta: float) -> void:
	if _backdrop == null or not visible:
		return
	_scroll += SCROLL_SPEED * delta
	_backdrop.apply(_scroll, 0.4, Vector2.ZERO, bool(Settings.get_value("reduce_motion")))


func _layout() -> void:
	if _panel == null:
		return
	_backdrop.set_view(size)
	var width := minf(safe.size.x - 24.0, 340.0)
	_text.custom_minimum_size.x = width - 28.0
	_panel.size = Vector2(width, 0)
	_panel.reset_size()
	_panel.size.x = width
	_panel.position = Vector2(floorf(safe.position.x + (safe.size.x - width) * 0.5),
			safe.end.y - _panel.size.y - 24.0)
	_skip.position = Vector2(safe.end.x - _skip.size.x - 8.0, safe.position.y + 6.0)


func back() -> bool:
	finish()
	return true


func layout_controls() -> Array[Control]:
	return [_panel, _skip]
