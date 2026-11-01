class_name TideChestPanel
extends PanelContainer
## Arca da Maré na tela de resultado (TideChest): o carretel passa os símbolos cada vez mais devagar,
## com um tique que desce de tom, e para no prêmio com carimbo e som; o Tesouro de Atlântida acende a
## arca em ouro com centelhas e vinheta. Um toque pula para o fim (finish).

## Intervalo do primeiro e do último tique do carretel (s): a desaceleração cria a expectativa.
const TICK_FIRST := 0.045
const TICK_LAST := 0.2

var chest: Dictionary = {}
var _title: Label
var _reel: Label
var _prize: Label
var _spin: Tween


func _init() -> void:
	name = "TideChest"
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(col)
	_title = _centered(UiTheme.label("", UiTheme.SMALL_SIZE, UiTheme.TEXT_DIM))
	col.add_child(_title)
	_reel = _centered(UiTheme.heading("", UiTheme.HEADING_SIZE, UiTheme.WHITE))
	_reel.custom_minimum_size = Vector2(200, 0)
	col.add_child(_reel)
	_prize = _centered(UiTheme.label("", UiTheme.FONT_SIZE, UiTheme.GOLD))
	_prize.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_prize)


func setup(p_chest: Dictionary) -> void:
	chest = p_chest
	visible = not chest.is_empty()
	if not visible:
		return
	var tier := int(chest.get("tier", 0))
	var tint := tier_color(tier)
	var box := UiTheme.chamfer(Color(tint, 0.12), Color(tint, 0.75), 1, 6)
	box.content_margin_left = 12
	box.content_margin_right = 12
	box.content_margin_top = 4
	box.content_margin_bottom = 6
	box.shadow_color = Color(tint, 0.25 if bool(chest.get("jackpot", false)) else 0.12)
	box.shadow_size = 10
	add_theme_stylebox_override("panel", box)
	_title.text = tr("chest.title") % tr("chest." + TideChest.TIERS[tier])
	_title.add_theme_color_override("font_color", tint.lightened(0.15))
	_prize.text = prize_text(chest)
	_show_final()


## Bronze, prata e ouro (as cores das notas C, B e S).
static func tier_color(tier: int) -> Color:
	return [Grade.color(Grade.C), Grade.color(Grade.B), Grade.color(Grade.S)][clampi(tier, 0, 2)]


static func symbol_text(symbol: StringName) -> String:
	match symbol:
		&"pearls":
			return TranslationServer.translate("currency.pearls")
		&"orichalcum":
			return TranslationServer.translate("currency.orichalcum")
		&"jackpot":
			return "★ " + TranslationServer.translate("chest.jackpot")
	return TranslationServer.translate("currency.credits")


static func prize_text(p_chest: Dictionary) -> String:
	var parts := PackedStringArray()
	for kind: String in ["credits", "pearls", "orichalcum"]:
		var amount := int(p_chest.get(kind, 0))
		if amount > 0:
			parts.append("%s +%s" % [TranslationServer.translate("currency." + kind), Locale.format_number(amount)])
	return "   ".join(parts)


## Começa invisível; o carretel gira e para no prêmio.
func spin() -> void:
	if not visible:
		return
	_kill()
	_prize.modulate.a = 0.0
	var reel: Array = chest.get("reel", [])
	_spin = create_tween()
	var n := reel.size()
	for i: int in range(n):
		var u := i / maxf(1.0, n - 1.0)
		_spin.tween_callback(_tick.bind(reel[i], i, n))
		_spin.tween_interval(lerpf(TICK_FIRST, TICK_LAST, u * u))
	_spin.tween_callback(_land)


## Estado final, sem animação (toque para pular, movimento reduzido).
func finish() -> void:
	_kill()
	_show_final()


func spinning() -> bool:
	return _spin != null and _spin.is_valid() and _spin.is_running()


func _tick(symbol: Variant, i: int, n: int) -> void:
	_reel.text = symbol_text(StringName(String(symbol)))
	_reel.add_theme_color_override("font_color", UiTheme.WHITE)
	AudioManager.play("kenney_ui_tab", 1.4 - 0.4 * i / maxf(1.0, n - 1.0), 0.0, -6.0, "UI")


func _land() -> void:
	_show_final()
	_reel.pivot_offset = _reel.size * 0.5
	_reel.scale = Vector2.ONE * 1.5
	var t := create_tween().set_parallel()
	t.tween_property(_reel, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_prize.modulate.a = 0.0
	t.tween_property(_prize, "modulate:a", 1.0, 0.25).set_delay(0.12)
	if bool(chest.get("jackpot", false)):
		AudioManager.play_ui("kenney_weapon_up")
		AudioManager.play("kenney_medal", 1.5, 0.0, 0.0, "UI")
		if UiSpark.instance != null and is_inside_tree():
			UiSpark.instance.ripple(get_global_transform_with_canvas() * (size * 0.5), UiTheme.GOLD)
	else:
		AudioManager.play("kenney_pearl", 1.0 + 0.15 * int(chest.get("tier", 0)), 0.0, 0.0, "UI")


func _show_final() -> void:
	var last: Array = chest.get("reel", [&"credits"])
	_reel.text = symbol_text(StringName(String(last[-1] if not last.is_empty() else &"credits")))
	var jackpot := bool(chest.get("jackpot", false))
	_reel.add_theme_color_override("font_color", UiTheme.GOLD if jackpot else tier_color(int(chest.get("tier", 0)))
			.lightened(0.3))
	_reel.scale = Vector2.ONE
	_prize.modulate.a = 1.0


func _kill() -> void:
	if _spin != null and _spin.is_valid():
		_spin.kill()
	_spin = null


static func _centered(node: Label) -> Label:
	node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return node
