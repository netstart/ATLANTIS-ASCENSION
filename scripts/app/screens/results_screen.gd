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
var _rewards: Label
var _double: Button
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
	_rewards = UiTheme.label("", UiTheme.FONT_SIZE, UiTheme.CYAN, true)
	_rewards.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(_rewards)
	_double = Button.new()
	_double.name = "DoubleCredits"
	_double.custom_minimum_size = Vector2(0, UiTheme.TOUCH_MIN)
	_double.pressed.connect(_on_double)
	_box.add_child(_double)
	_retry = Button.new()
	_retry.name = "Retry"
	_retry.custom_minimum_size = Vector2(0, UiTheme.TOUCH_MIN + 6.0)
	_retry.pressed.connect(func() -> void: play.emit(StringName(String(result.get("mission", "c1m1")))))
	_box.add_child(_retry)
	_continue = Button.new()
	_continue.name = "Continue"
	_continue.custom_minimum_size = Vector2(0, UiTheme.TOUCH_MIN + 6.0)
	_continue.pressed.connect(func() -> void:
		var mode := String(result.get("mode", ""))
		if not mode.is_empty() and mode != "practice":
			navigate.emit(&"events")
		else:
			navigate.emit(&"story" if not StoryScreen.pending(SaveManager.data).is_empty() else &"map"))
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
	_rewards.text = "\n".join(reward_lines(result))
	var mode := String(result.get("mode", ""))
	if not mode.is_empty():
		_title.text = "%s · %s" % [tr("mode." + mode), _title.text]
		_score.text = Locale.format_number(int(result.get("run_score", result.get("score", 0))))
	_double.visible = int(result.get("credits", 0)) > 0 and not bool(result.get("doubled", false))
	_double.text = tr("results.double_ad") if Store.ads_allowed(SaveManager.data) else tr("results.double_free")
	_retry.text = tr("results.retry")
	_continue.text = tr("results.continue")
	relayout()


## Linhas das recompensas além dos créditos: oricalco, pérolas, fragmentos, aeronaves, asas,
## missões abertas e registro.
static func reward_lines(r: Dictionary) -> PackedStringArray:
	var lines := PackedStringArray()
	if int(r.get("orichalcum_gain", 0)) > 0 or int(r.get("pearls_gain", 0)) > 0:
		lines.append("%s +%d   %s +%d" % [_t("currency.orichalcum"), int(r.get("orichalcum_gain", 0)),
				_t("currency.pearls"), int(r.get("pearls_gain", 0))])
	var fragments: Dictionary = r.get("fragments", {})
	for ship: Variant in fragments:
		lines.append(_t("results.fragments") % [int(fragments[ship]), _t("ship." + String(ship))])
	for ship: Variant in r.get("new_ships", []):
		lines.append(_t("results.new_ship") % _t("ship." + String(ship)))
	for wing: Variant in r.get("new_wings", []):
		lines.append(_t("results.new_wing") % _t("wing." + String(wing)))
	for d: Variant in r.get("new_districts", []):
		lines.append(_t("results.new_district") % _t("district." + String(d)))
	if int(r.get("rescued", 0)) > 0:
		lines.append(_t("results.rescued") % int(r["rescued"]))
	if not String(r.get("ending", "")).is_empty():
		lines.append(_t("ending." + String(r["ending"])))
	for m: Variant in r.get("new_missions", []):
		lines.append(_t("results.new_mission") % _t("stage." + String(m)))
	if bool(r.get("log", false)):
		lines.append(_t("results.log"))
	return lines


## Dobrar créditos: anúncio recompensado opcional (ou grátis na Steam e para quem apoiou), 1 vez.
func _on_double() -> void:
	Ads.show_rewarded(SaveManager.data, func(granted: bool) -> void:
		if granted and not bool(result.get("doubled", false)):
			result["doubled"] = true
			SaveManager.add_currency("credits", int(result.get("credits", 0)))
			result["credits"] = int(result.get("credits", 0)) * 2
			SaveManager.save_profile()
			refresh_texts())


static func _t(key: String) -> String:
	return TranslationServer.translate(key)


func _layout() -> void:
	if _scroll == null:
		return
	var width := minf(safe.size.x - 24.0, 340.0)
	_scroll.position = Vector2(floorf(safe.position.x + (safe.size.x - width) * 0.5), safe.position.y + 12.0)
	_scroll.size = Vector2(width, safe.size.y - 24.0)
	_box.custom_minimum_size = Vector2(width - 8.0, 0)
	_rewards.custom_minimum_size.x = width - 8.0


func back() -> bool:
	navigate.emit(&"map")
	return true


func layout_controls() -> Array[Control]:
	return [_scroll]
