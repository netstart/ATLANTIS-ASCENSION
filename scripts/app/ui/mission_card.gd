class_name MissionCard
extends PanelContainer
## Cartão da missão na aba Campanha (1.15): o nome, os 4 objetivos com as estrelas ganhas, o recorde e a
## nota, o selo do Poder contra o recomendado da missão (só informa, nunca bloqueia) e JOGAR. Abre por
## cima da trilha; o fundo escurecido, o X e o voltar fecham.

signal play_pressed(id: StringName)
signal closed

var mission: StringName = &""

var _title: Label
var _kind: Label
var _stars: Array[Label] = []
var _best: Label
var _badge_slot: HBoxContainer
var _play: Button
var _close: Button


func _init() -> void:
	name = "MissionCard"
	add_theme_stylebox_override("panel", UiTheme.panel_box(UiTheme.GOLD, 0.95))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	add_child(box)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	box.add_child(head)
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.add_theme_constant_override("separation", 0)
	head.add_child(titles)
	_kind = UiTheme.label("", UiTheme.SMALL_SIZE, UiTheme.CYAN)
	_kind.clip_text = true
	_kind.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	titles.add_child(_kind)
	_title = UiTheme.heading("", UiTheme.HEADING_SIZE, UiTheme.WHITE)
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title.custom_minimum_size.x = 60.0
	titles.add_child(_title)
	_close = UiTheme.icon_button("cross", "CloseCard")
	_close.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_close.pressed.connect(func() -> void:
		AudioManager.play_ui("kenney_ui_back")
		closed.emit())
	head.add_child(_close)
	var rule := ColorRect.new()
	rule.color = Color(UiTheme.GOLD, 0.35)
	rule.custom_minimum_size = Vector2(0, 1)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(rule)
	for i: int in range(4):
		var star := UiTheme.label("", UiTheme.FONT_SIZE, UiTheme.TEXT, true)
		box.add_child(star)
		_stars.append(star)
	_best = UiTheme.label("", UiTheme.FONT_SIZE, UiTheme.TEXT_DIM, true)
	box.add_child(_best)
	_badge_slot = HBoxContainer.new()
	_badge_slot.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(_badge_slot)
	_play = Button.new()
	_play.name = "PlayMission"
	_play.custom_minimum_size = Vector2(0, UiTheme.TOUCH_MIN + 10.0)
	UiTheme.style_primary(_play, UiTheme.HEADING_SIZE)
	_play.clip_text = true
	_play.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_play.pressed.connect(func() -> void:
		AudioManager.play_ui("kenney_ui_confirm")
		play_pressed.emit(mission))
	box.add_child(_play)


func play_button() -> Button:
	return _play


## Preenche o cartão da missão `id` com o perfil atual.
func show_mission(id: StringName, power: int) -> void:
	mission = id
	var record := SaveManager.mission_record(id)
	var got: Array = record["stars"]
	var n := Economy.node(id)
	_title.text = tr("stage." + String(id))
	var kind := CampaignParts.short_label(id)
	if n.has("route"):
		kind += " · " + tr("map.route_" + String(n["route"]))
	_kind.text = kind.to_upper()
	var mission_def := Sim.load_mission(id)
	var objective := String((mission_def.get("objective", {}) as Dictionary).get("text_key", "star.all_marked"))
	var texts := [tr("star.clear"), tr("star.no_damage"), tr("star.all_marked"), tr(objective)]
	for i: int in range(4):
		var on := i < got.size() and bool(got[i])
		_stars[i].text = ("★  " if on else "☆  ") + texts[i]
		_stars[i].add_theme_color_override("font_color", UiTheme.GOLD if on else UiTheme.TEXT_DIM)
	_best.text = tr("map.best") % Locale.format_number(int(record["best_score"]))
	var grade := int(record.get("grade", Grade.NONE))
	if grade != Grade.NONE:
		_best.text += "   ·   " + tr("map.grade") % Grade.letter(grade)
	for child: Node in _badge_slot.get_children():
		child.queue_free()
	_badge_slot.add_child(CommandKit.power_badge(power, Economy.mission_recommended_power(id)))
	_play.text = tr("boot.play").to_upper()
	_close.tooltip_text = tr("campaign.close")


## Largura do cartão: os rótulos com quebra precisam dela antes de medir a altura.
func fit_width(width: float) -> void:
	var inner := width - 24.0
	_title.custom_minimum_size.x = maxf(60.0, inner - UiTheme.TOUCH_MIN - 6.0)
	for label: Label in _stars + [_best]:
		label.custom_minimum_size.x = inner
	size = Vector2(width, 0)
	reset_size()
	size.x = width
