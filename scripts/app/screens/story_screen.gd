class_name StoryScreen
extends Screen
## Cenas da história entre missões (plano mestre 3.5): 2 a 5 quadros de fala sobre o cenário do
## capítulo em movimento lento. Tocar avança; "Pular" fecha. Cada cena aparece uma vez, quando uma
## das missões de `after_any` foi concluída (a de lista vazia é o prólogo). Dados: data/story.json.
##
## Redesenho 1.6 (docs/design/ui-style.md): linguagem de cinema e de visual novel. Faixas pretas
## (letterbox) entram de cima e de baixo; o retrato fica numa moldura chanfrada com brilho ciano,
## saltando para fora da caixa de fala, com a placa do nome ao lado; a fala é um painel de vidro com
## o texto datilografado (instantâneo em "reduzir movimento") e um "▼" pulsando quando acaba. Trocar
## de quadro funde o retrato e, se o capítulo muda, o cenário. Tocar fora dos botões completa o
## texto e, com o texto completo, avança. O botão "Next" sempre avança (os testes contam com isso).

const SCROLL_SPEED := 14.0
## Velocidade da datilografia (caracteres por segundo) e limites da duração de um quadro.
const TYPE_CPS := 52.0
const TYPE_MIN := 0.35
const TYPE_MAX := 3.2
## O cenário do capítulo fica translúcido: a água compartilhada do fundo respira por baixo.
const BACKDROP_ALPHA := 0.72
const CROSSFADE := 0.6
const PORTRAIT := 72.0
## Altura da linha do nome: a moldura do retrato desce até o fim dela, dentro da caixa.
const HEAD_HEIGHT := 28.0
const BARS_TIME := 0.55

var scene: Dictionary = {}
var index: int = 0

var _backdrop: OceanBackdrop
var _old_backdrop: OceanBackdrop
var _shade: ColorRect
var _bar_top: ColorRect
var _bar_bottom: ColorRect
var _tap: Control
var _panel: PanelContainer
var _head: HBoxContainer
var _plate_gap: Control
var _speaker: Label
var _frame: PanelContainer
var _portrait: TextureRect
var _text: Label
var _dots: HBoxContainer
var _cue: Control
var _next: Button
var _skip: Button
var _scroll: float = 0.0
var _bars: float = 1.0
var _shown: String = ""
var _speaker_id: String = ""
var _typing: Tween
var _pulse: Tween


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
	_backdrop = _make_backdrop(&"ocean")
	add_child(_backdrop)
	# Vinheta: escurece o cenário para a caixa de fala e o retrato saltarem à frente.
	_shade = ColorRect.new()
	_shade.color = Color(UiTheme.ABYSS, 0.38)
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_shade)
	_tap = Control.new()
	_tap.name = "Tap"
	_tap.mouse_filter = Control.MOUSE_FILTER_STOP
	_tap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_tap.gui_input.connect(_on_tap)
	add_child(_tap)
	_bar_top = _make_bar()
	add_child(_bar_top)
	_bar_bottom = _make_bar()
	add_child(_bar_bottom)
	_panel = PanelContainer.new()
	_panel.name = "Dialogue"
	var box := UiTheme.panel_box(UiTheme.CYAN, 0.9)
	box.shadow_color = Color(UiTheme.CYAN, 0.12)
	box.shadow_size = 12
	box.shadow_offset = Vector2.ZERO
	box.content_margin_left = 14
	box.content_margin_right = 14
	box.content_margin_top = 8
	box.content_margin_bottom = 12
	_panel.add_theme_stylebox_override("panel", box)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	_panel.add_child(col)
	_head = HBoxContainer.new()
	_head.custom_minimum_size = Vector2(0, HEAD_HEIGHT)
	_head.add_theme_constant_override("separation", 0)
	col.add_child(_head)
	_plate_gap = Control.new()
	_plate_gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_head.add_child(_plate_gap)
	_speaker = UiTheme.heading("", UiTheme.FONT_SIZE + 1, UiTheme.WHITE)
	_speaker.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_head.add_child(_speaker)
	_text = UiTheme.label("", UiTheme.FONT_SIZE, UiTheme.TEXT, true)
	# Molda o texto inteiro desde o início: a datilografia não muda o tamanho da caixa.
	_text.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	_text.add_theme_constant_override("line_spacing", 3)
	col.add_child(_text)
	var foot := HBoxContainer.new()
	foot.custom_minimum_size = Vector2(0, 10)
	col.add_child(foot)
	_dots = HBoxContainer.new()
	_dots.add_theme_constant_override("separation", 4)
	_dots.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dots.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	foot.add_child(_dots)
	_cue = Control.new()
	_cue.custom_minimum_size = Vector2(12, 10)
	_cue.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cue.draw.connect(_draw_cue)
	foot.add_child(_cue)
	_next = Button.new()
	_next.name = "Next"
	_next.custom_minimum_size = Vector2(0, UiTheme.TOUCH_MIN + 4.0)
	_next.pressed.connect(advance)
	col.add_child(_next)
	add_child(_panel)
	_frame = PanelContainer.new()
	_frame.name = "PortraitFrame"
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var frame := UiTheme.chamfer(Color(UiTheme.RAISED, 0.95), UiTheme.CYAN, 2, 9)
	frame.set_content_margin_all(3)
	frame.shadow_color = Color(UiTheme.CYAN, 0.38)
	frame.shadow_size = 10
	_frame.add_theme_stylebox_override("panel", frame)
	_portrait = Portraits.make_rect(PORTRAIT)
	_frame.add_child(_portrait)
	add_child(_frame)
	_skip = Button.new()
	_skip.name = "Skip"
	_skip.custom_minimum_size = Vector2(88, UiTheme.TOUCH_MIN)
	_skip.pressed.connect(finish)
	add_child(_skip)


func on_show(_app: Node) -> void:
	scene = pending(SaveManager.data)
	index = 0
	_shown = ""
	_speaker_id = ""
	if scene.is_empty():
		navigate.emit(&"map")
		return
	refresh_texts()
	_open_bars()
	_next.grab_focus.call_deferred()


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
	_stop_typing()
	navigate.emit(&"map")


func refresh_texts() -> void:
	if _skip == null:
		return
	_skip.text = tr("story.skip")
	var panels: Array = scene.get("panels", [])
	if index >= panels.size():
		return
	var p := panels[index] as Dictionary
	var who := String(p.get("speaker", ""))
	_speaker.text = tr("speaker." + who)
	_portrait.texture = Portraits.texture(who, String(p.get("mood", "calm")))
	_frame.visible = _portrait.texture != null
	_plate_gap.custom_minimum_size = Vector2(PORTRAIT + 18.0, 0) if _frame.visible else Vector2.ZERO
	_style_plate(_frame.visible)
	_text.text = tr(String(p.get("text_key", "")))
	# Narração em tom mais frio; fala de personagem em branco cheio.
	_text.add_theme_color_override("font_color", UiTheme.TEXT if _frame.visible else Color("b9d3e3"))
	var last := index >= panels.size() - 1
	_next.text = tr("story.continue") if last else tr("story.next")
	# O último quadro leva à missão: é a ação principal (ouro); os anteriores são secundários.
	_style_next(last)
	_fill_dots(panels.size())
	var bold := UiTheme.bold_font()
	if bold != null:
		_speaker.add_theme_font_override("font", bold)
	var kind := StringName(String(p.get("backdrop", "ocean")))
	if _backdrop.kind != kind:
		_swap_backdrop(kind)
	relayout()
	# Quadro novo (não troca de idioma): datilografa e funde o retrato se quem fala mudou.
	var key := "%s#%d" % [String(scene.get("id", "")), index]
	if key != _shown:
		_shown = key
		if who != _speaker_id:
			_speaker_id = who
			_fade_in_speaker()
		_type_text()
	else:
		_stop_typing()
		_text.visible_ratio = 1.0
		_show_cue(true)


func _process(delta: float) -> void:
	if _backdrop == null or not visible:
		return
	_scroll += SCROLL_SPEED * delta
	var reduce := bool(Settings.get_value("reduce_motion"))
	_backdrop.apply(_scroll, 0.4, Vector2.ZERO, reduce)
	if is_instance_valid(_old_backdrop):
		_old_backdrop.apply(_scroll, 0.4, Vector2.ZERO, reduce)


func _layout() -> void:
	if _panel == null:
		return
	_backdrop.set_view(size)
	if is_instance_valid(_old_backdrop):
		_old_backdrop.set_view(size)
	var width := minf(safe.size.x - 24.0, 340.0)
	_text.custom_minimum_size.x = width - 28.0
	_panel.size = Vector2(width, 0)
	_panel.reset_size()
	_panel.size.x = width
	_panel.position = Vector2(floorf(safe.position.x + (safe.size.x - width) * 0.5),
			safe.end.y - _panel.size.y - 20.0)
	_frame.reset_size()
	# A moldura salta para fora da caixa e desce até o fim da linha do nome.
	var box := _panel.get_theme_stylebox("panel")
	var reach := (box.content_margin_top if box != null else 8.0) + HEAD_HEIGHT
	_frame.position = Vector2(_panel.position.x + 12.0, _panel.position.y + reach - _frame.size.y)
	_skip.reset_size()
	_skip.position = Vector2(safe.end.x - _skip.size.x - 8.0, safe.position.y + 6.0)
	_place_bars()


func back() -> bool:
	finish()
	return true


func layout_controls() -> Array[Control]:
	return [_panel, _skip]


# --- Cinema: faixas, cenário, retrato ----------------------------------------------------------


func _make_bar() -> ColorRect:
	var bar := ColorRect.new()
	bar.color = Color("02050c")
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Fio de luz ciano na borda interna: a faixa parece a moldura do visor do batiscafo.
	var line := ColorRect.new()
	line.name = "Edge"
	line.color = Color(UiTheme.CYAN, 0.22)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(line)
	return bar


## Altura das faixas: a área fora do recorte da câmera mais ~7 % da tela, entrando pelo `_bars`.
func _place_bars() -> void:
	var band := clampf(size.y * 0.07, 22.0, 54.0)
	var top := (safe.position.y + band) * _bars
	var bottom := (size.y - safe.end.y + band) * _bars
	_bar_top.position = Vector2.ZERO
	_bar_top.size = Vector2(size.x, top)
	_bar_bottom.position = Vector2(0, size.y - bottom)
	_bar_bottom.size = Vector2(size.x, bottom)
	var edge_top := _bar_top.get_node(^"Edge") as ColorRect
	edge_top.position = Vector2(0, maxf(top - 1.0, 0.0))
	edge_top.size = Vector2(size.x, 1)
	var edge_bottom := _bar_bottom.get_node(^"Edge") as ColorRect
	edge_bottom.position = Vector2.ZERO
	edge_bottom.size = Vector2(size.x, 1)


func _open_bars() -> void:
	if UiFx.reduced():
		_bars = 1.0
		_place_bars()
		return
	_bars = 0.0
	_place_bars()
	var t := create_tween()
	t.tween_method(func(v: float) -> void:
		_bars = v
		_place_bars(), 0.0, 1.0, BARS_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _make_backdrop(kind: StringName) -> OceanBackdrop:
	var b := OceanBackdrop.new()
	b.kind = kind
	b.modulate.a = BACKDROP_ALPHA
	return b


## A paleta é lida no _ready do cenário: trocar de capítulo cria outra camada e funde as duas.
func _swap_backdrop(kind: StringName) -> void:
	if is_instance_valid(_old_backdrop):
		_old_backdrop.queue_free()
	_old_backdrop = _backdrop
	_backdrop = _make_backdrop(kind)
	add_child(_backdrop)
	move_child(_backdrop, _old_backdrop.get_index() + 1)
	_backdrop.set_view(size)
	if UiFx.reduced() or not is_visible_in_tree():
		_old_backdrop.queue_free()
		_old_backdrop = null
		return
	_backdrop.modulate.a = 0.0
	var old := _old_backdrop
	var t := create_tween().set_parallel()
	t.tween_property(_backdrop, "modulate:a", BACKDROP_ALPHA, CROSSFADE).set_trans(Tween.TRANS_SINE)
	t.tween_property(old, "modulate:a", 0.0, CROSSFADE).set_trans(Tween.TRANS_SINE)
	t.chain().tween_callback(old.queue_free)


## Quem fala mudou: o retrato surge da água (transparente, um pouco abaixo do tamanho) e a placa
## do nome acende junto.
func _fade_in_speaker() -> void:
	if UiFx.reduced():
		_frame.modulate = Color.WHITE
		_speaker.modulate = Color.WHITE
		return
	_frame.pivot_offset = Vector2(_frame.size.x * 0.5, _frame.size.y)
	_frame.modulate = Color(1, 1, 1, 0)
	_frame.scale = Vector2.ONE * 0.9
	_speaker.modulate = Color(1, 1, 1, 0)
	var t := create_tween().set_parallel()
	t.tween_property(_frame, "modulate:a", 1.0, 0.28).set_trans(Tween.TRANS_SINE)
	t.tween_property(_frame, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(_speaker, "modulate:a", 1.0, 0.3).set_delay(0.08)


func _style_plate(character: bool) -> void:
	var accent := UiTheme.CYAN if character else UiTheme.TEXT_DIM
	var plate := UiTheme.chamfer(Color(accent, 0.13), Color(accent, 0.6), 1, 5)
	plate.border_width_left = 3
	plate.content_margin_left = 8
	plate.content_margin_right = 10
	plate.content_margin_top = 2
	plate.content_margin_bottom = 2
	_speaker.add_theme_stylebox_override("normal", plate)
	_speaker.add_theme_color_override("font_color", UiTheme.WHITE if character else UiTheme.TEXT_DIM)
	_speaker.add_theme_color_override("font_shadow_color", Color(accent, 0.3))


func _style_next(primary: bool) -> void:
	if primary:
		UiTheme.style_primary(_next)
		return
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		_next.remove_theme_stylebox_override(state)
	for key: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color",
			"font_hover_pressed_color", "font_disabled_color"]:
		_next.remove_theme_color_override(key)
	_next.remove_theme_font_size_override("font_size")
	_next.remove_theme_font_override("font")


## Progresso da cena: um traço por quadro, os já vistos acesos.
func _fill_dots(total: int) -> void:
	for child: Node in _dots.get_children():
		_dots.remove_child(child)
		child.queue_free()
	for i: int in range(total):
		var dot := ColorRect.new()
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dot.custom_minimum_size = Vector2(14 if i == index else 6, 2)
		dot.color = UiTheme.CYAN if i == index else Color(UiTheme.CYAN, 0.6 if i < index else 0.2)
		_dots.add_child(dot)


# --- Datilografia -----------------------------------------------------------------------------


func _type_text() -> void:
	_stop_typing()
	var count := _text.get_total_character_count()
	if UiFx.reduced() or count <= 0:
		_text.visible_ratio = 1.0
		_show_cue(true)
		return
	_text.visible_ratio = 0.0
	_show_cue(false)
	var seconds := clampf(count / TYPE_CPS, TYPE_MIN, TYPE_MAX)
	_typing = create_tween()
	_typing.tween_property(_text, "visible_ratio", 1.0, seconds)
	_typing.tween_callback(_show_cue.bind(true))


func _stop_typing() -> void:
	if _typing != null and _typing.is_valid():
		_typing.kill()
	_typing = null


func _is_typing() -> bool:
	return _typing != null and _typing.is_valid() and _text.visible_ratio < 1.0


## Toque fora dos botões: completa o texto; com o texto completo, avança.
func _on_tap(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	accept_event()
	if _is_typing():
		_stop_typing()
		_text.visible_ratio = 1.0
		_show_cue(true)
		return
	advance()


func _show_cue(on: bool) -> void:
	if _pulse != null and _pulse.is_valid():
		_pulse.kill()
	_cue.visible = on
	_cue.modulate = Color.WHITE
	if not on or UiFx.reduced() or not is_inside_tree():
		return
	_pulse = create_tween().set_loops()
	_pulse.tween_property(_cue, "modulate:a", 0.25, 0.45).set_trans(Tween.TRANS_SINE)
	_pulse.tween_property(_cue, "modulate:a", 1.0, 0.45).set_trans(Tween.TRANS_SINE)


## "▼" desenhado em vetor (nítido em qualquer resolução e sem depender do glifo da fonte).
func _draw_cue() -> void:
	var s := _cue.size
	var w := 9.0
	var h := 6.0
	var o := Vector2((s.x - w) * 0.5, (s.y - h) * 0.5)
	_cue.draw_colored_polygon(PackedVector2Array([o, o + Vector2(w, 0), o + Vector2(w * 0.5, h)]), UiTheme.CYAN)
