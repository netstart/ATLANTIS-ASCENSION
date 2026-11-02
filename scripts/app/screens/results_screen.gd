class_name ResultsScreen
extends Screen
## Resultado da missão (plano mestre 7.5 e 19.4): pontuação, recorde, as 4 estrelas com o que
## faltou, números da partida, créditos ganhos e "Tentar de novo" sem anúncio.
##
## Redesenho 1.6 (docs/design/ui-style.md): um cartão de vidro sobre a água dourada do fundo e uma
## revelação em etapas (faixa → pontos contando → números → estrelas carimbadas uma a uma com som
## subindo → recorde → recompensas caindo). É o momento de pagamento da partida: cada etapa tem o
## próprio som e 250–350 ms de respiro. Um toque ou qualquer tecla pula para o estado final.
##
## O leiaute final é montado na hora (os testes de leiaute leem a tela 3 quadros depois de abrir):
## a revelação só mexe em `modulate` e `scale` dos filhos, nunca em posição ou tamanho.

## Intervalo entre etapas da revelação (s).
const STEP := 0.3
## Espera antes da primeira etapa: o fade de entrada da tela (UiFx.enter, 220 ms) e o 1º leiaute.
const LEAD := 0.18
const SCORE_COUNT := 1.0
const STAT_COUNT := 0.6
## Carimbo: entra grande e assenta com salto ("back").
const STAMP_FROM := 1.6
const STAMP_TIME := 0.32
## Depois de pular com um toque, o clique emulado do mesmo toque não pode apertar um botão.
const SWALLOW_MS := 180
const PRIMARY_HEIGHT := UiTheme.TOUCH_MIN + 12.0
const SECONDARY_HEIGHT := UiTheme.TOUCH_MIN + 6.0
const GAP := 8.0
## Vinheta de recompensa (Kenney, CC0): toca sobre a revelação de uma vitória e devolve a música
## dos menus quando acaba (a vitória do chefe já tocou na partida; a de derrota também).
const JINGLE := "kenney_jingle_reward"
## Tempo da Arca na revelação: o carretel (TideChestPanel) e o respiro do prêmio.
const CHEST_TIME := 1.75

var result: Dictionary = {}

var _scroll: ScrollContainer
var _card: PanelContainer
var _box: VBoxContainer
var _subtitle: Label
var _title: Label
var _score: Label
var _record: Label
var _rule: ColorRect
var _stars: Array[Label] = []
var _star_icons: Array[Control] = []
var _grid: GridContainer
var _stat_values: Array[Label] = []
var _stat_captions: Array[Label] = []
var _stat_tiles: Array[Control] = []
var _credits: Label
var _grade: GradeSeal
var _defeat: DefeatPanel
var _chest: TideChestPanel
var _credits_pill: PanelContainer
var _rewards: VBoxContainer
var _double: Button
var _retry: Button
var _continue: Button
var _revealing: bool = false
var _sequence: Tween
var _counters: Array[Tween] = []
var _swallow_until: int = 0


func _build() -> void:
	_scroll = ScrollContainer.new()
	_scroll.name = "Scroll"
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)
	_card = PanelContainer.new()
	_card.name = "Card"
	_scroll.add_child(_card)
	# Largura do cartão = largura da rolagem (menos a barra, só quando ela aparece).
	_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_card.resized.connect(_fit_scroll)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 8)
	_card.add_child(_box)
	_subtitle = _centered(UiTheme.label("", UiTheme.SMALL_SIZE, UiTheme.TEXT_DIM, true))
	_box.add_child(_subtitle)
	_title = _centered(UiTheme.heading("", UiTheme.TITLE_SIZE, UiTheme.MINT))
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_box.add_child(_title)
	_score = _centered(UiTheme.heading("", 32, UiTheme.WHITE))
	_box.add_child(_score)
	_record = _centered(UiTheme.heading("", UiTheme.FONT_SIZE, UiTheme.GOLD_DARK))
	_record.name = "Record"
	var stamp := UiTheme.chamfer(UiTheme.GOLD, Color("fff3c4"), 1, 5)
	stamp.content_margin_left = 10
	stamp.content_margin_right = 10
	stamp.content_margin_top = 2
	stamp.content_margin_bottom = 2
	stamp.shadow_color = Color(UiTheme.GOLD, 0.45)
	stamp.shadow_size = 8
	_record.add_theme_stylebox_override("normal", stamp)
	_record.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	_record.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_box.add_child(_record)
	_grade = GradeSeal.new()
	_box.add_child(_grade)
	_rule = ColorRect.new()
	_rule.custom_minimum_size = Vector2(0, 1)
	_rule.color = Color(UiTheme.CYAN, 0.18)
	_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(_rule)
	_defeat = DefeatPanel.new()
	_box.add_child(_defeat)
	var stars := VBoxContainer.new()
	stars.add_theme_constant_override("separation", 4)
	_box.add_child(stars)
	for i: int in range(4):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		stars.add_child(row)
		var icon := Control.new()
		icon.custom_minimum_size = Vector2(22, 22)
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.set_meta(&"on", false)
		icon.draw.connect(_draw_star.bind(icon))
		row.add_child(icon)
		_star_icons.append(icon)
		var text := UiTheme.label("", UiTheme.FONT_SIZE, UiTheme.TEXT, true)
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(text)
		_stars.append(text)
	_grid = GridContainer.new()
	_grid.columns = 2
	_grid.add_theme_constant_override("h_separation", 6)
	_grid.add_theme_constant_override("v_separation", 6)
	_box.add_child(_grid)
	for i: int in range(4):
		var tile := PanelContainer.new()
		var box := UiTheme.chamfer(Color(UiTheme.RAISED, 0.55), Color(UiTheme.CYAN, 0.16), 1, 5)
		box.content_margin_left = 4
		box.content_margin_right = 4
		box.content_margin_top = 4
		box.content_margin_bottom = 4
		tile.add_theme_stylebox_override("panel", box)
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_grid.add_child(tile)
		_stat_tiles.append(tile)
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 0)
		tile.add_child(col)
		var value := _centered(UiTheme.heading("0", UiTheme.HEADING_SIZE, UiTheme.WHITE))
		col.add_child(value)
		_stat_values.append(value)
		var caption := _centered(UiTheme.label("", UiTheme.SMALL_SIZE, UiTheme.TEXT_DIM, true))
		col.add_child(caption)
		_stat_captions.append(caption)
	_credits_pill = PanelContainer.new()
	var pill := UiTheme.pill_box(UiTheme.GOLD)
	pill.bg_color = Color(UiTheme.GOLD, 0.14)
	pill.border_color = Color(UiTheme.GOLD, 0.7)
	pill.content_margin_left = 14
	pill.content_margin_right = 14
	pill.content_margin_top = 3
	pill.content_margin_bottom = 3
	pill.shadow_color = Color(UiTheme.GOLD, 0.22)
	pill.shadow_size = 6
	_credits_pill.add_theme_stylebox_override("panel", pill)
	_credits_pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_box.add_child(_credits_pill)
	_credits = _centered(UiTheme.heading("", UiTheme.HEADING_SIZE, UiTheme.GOLD))
	_credits.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	_credits_pill.add_child(_credits)
	_double = Button.new()
	_double.name = "DoubleCredits"
	_double.custom_minimum_size = Vector2(0, UiTheme.TOUCH_MIN)
	_double.pressed.connect(_on_double)
	_box.add_child(_double)
	_chest = TideChestPanel.new()
	_box.add_child(_chest)
	_rewards = VBoxContainer.new()
	_rewards.add_theme_constant_override("separation", 4)
	_box.add_child(_rewards)
	_retry = Button.new()
	_retry.name = "Retry"
	_retry.custom_minimum_size = Vector2(0, SECONDARY_HEIGHT)
	_retry.pressed.connect(func() -> void: play.emit(StringName(String(result.get("mission", "c1m1")))))
	add_child(_retry)
	_continue = Button.new()
	_continue.name = "Continue"
	_continue.custom_minimum_size = Vector2(0, PRIMARY_HEIGHT)
	_continue.pressed.connect(func() -> void:
		var mode := String(result.get("mode", ""))
		if not mode.is_empty() and mode != "practice":
			navigate.emit(&"events")
		else:
			navigate.emit(&"story" if not StoryScreen.pending(SaveManager.data).is_empty() else &"map"))
	add_child(_continue)


## Pelo controle a tela abre no botão principal (Continuar na vitória, Tentar de novo na derrota).
func default_focus() -> Control:
	return _continue if bool(result.get("cleared", false)) else _retry


func on_show(app: Node) -> void:
	result = app.get("last_result") if app != null else {}
	refresh_texts()
	_play_jingle()
	_start_reveal()


func refreshes_on_show() -> bool:
	return true


func refresh_texts() -> void:
	var cleared := bool(result.get("cleared", false))
	var accent := UiTheme.MINT if cleared else UiTheme.CORAL
	var mode := String(result.get("mode", ""))
	var mission_id := String(result.get("mission", "c1m1"))
	_card.add_theme_stylebox_override("panel", _card_box(accent))
	_rule.color = Color(accent, 0.28)
	_subtitle.text = tr("stage." + mission_id) if mode.is_empty() else tr("mode." + mode)
	_title.text = tr("results.cleared" if cleared else "results.failed")
	_title.add_theme_color_override("font_color", accent)
	_title.add_theme_color_override("font_shadow_color", Color(accent, 0.35))
	var score := _score_value()
	if not _revealing:
		_score.text = Locale.format_number(score)
	_record.text = tr("results.record")
	_record.visible = bool(result.get("record", false))
	_grade.setup(result)
	_defeat.setup(result)
	if not _revealing or not _chest.spinning():
		_chest.setup(result.get("chest", {}))
	var mission := Sim.load_mission(StringName(mission_id))
	var objective := String((mission.get("objective", {}) as Dictionary).get("text_key", "star.all_marked"))
	var texts := [tr("star.clear"), tr("star.no_damage"), tr("star.all_marked"), tr(objective)]
	var got: Array = result.get("stars", [false, false, false, false])
	for i: int in range(4):
		var on := i < got.size() and bool(got[i])
		_star_icons[i].set_meta(&"on", on)
		_star_icons[i].queue_redraw()
		_stars[i].text = texts[i]
		_stars[i].add_theme_color_override("font_color", UiTheme.TEXT if on else UiTheme.TEXT_DIM)
	var captions := [tr("results.kills"), tr("results.grazes"), tr("results.chain"), tr("results.medals")]
	for i: int in range(4):
		_stat_captions[i].text = captions[i]
		if not _revealing:
			_stat_values[i].text = Locale.format_number(_stat(i))
	_credits.text = tr("results.credits") % Locale.format_number(int(result.get("credits", 0)))
	_double.visible = int(result.get("credits", 0)) > 0 and not bool(result.get("doubled", false))
	_double.text = tr("results.double_ad") if Store.ads_allowed(SaveManager.data) else tr("results.double_free")
	_fill_rewards()
	_retry.text = tr("results.retry")
	_continue.text = tr("results.continue")
	# A ação principal muda com o desfecho: na vitória, seguir; na derrota, tentar de novo.
	_style_button(_continue, cleared)
	_style_button(_retry, not cleared)
	# A fonte em negrito é do idioma: trocar de idioma troca a fonte dos títulos.
	var bolds: Array[Label] = [_title, _score, _record, _credits]
	bolds.append_array(_stat_values)
	for node: Label in bolds:
		_bold(node)
	relayout()


## Linhas das recompensas além dos créditos: oricalco, pérolas, fragmentos, aeronaves, asas,
## missões abertas e registro.
static func reward_lines(r: Dictionary) -> PackedStringArray:
	var lines := PackedStringArray()
	for item: Array in reward_items(r):
		lines.append(String(item[0]))
	return lines


## As mesmas linhas com a cor do que significam: moeda em ouro, raro (aeronave, asa, conquista,
## final) em violeta, progresso (placar, temporada, cidade, mapa, diário) em turquesa.
static func reward_items(r: Dictionary) -> Array[Array]:
	var items: Array[Array] = []
	if int(r.get("orichalcum_gain", 0)) > 0 or int(r.get("pearls_gain", 0)) > 0:
		items.append(["%s +%d   %s +%d" % [_t("currency.orichalcum"), int(r.get("orichalcum_gain", 0)),
				_t("currency.pearls"), int(r.get("pearls_gain", 0))], UiTheme.GOLD])
	var fragments: Dictionary = r.get("fragments", {})
	for ship: Variant in fragments:
		items.append([_t("results.fragments") % [int(fragments[ship]), _t("ship." + String(ship))], UiTheme.GOLD])
	for ship: Variant in r.get("new_ships", []):
		items.append([_t("results.new_ship") % _t("ship." + String(ship)), UiTheme.VIOLET])
	for wing: Variant in r.get("new_wings", []):
		items.append([_t("results.new_wing") % _t("wing." + String(wing)), UiTheme.VIOLET])
	for a: Variant in r.get("achievements", []):
		items.append([_t("results.achievement") % _t("achievement." + String(a)), UiTheme.VIOLET])
	if int(r.get("board_pos", -1)) >= 0:
		items.append([_t("results.board") % (int(r["board_pos"]) + 1), UiTheme.TURQUOISE])
	if int(r.get("season_xp", 0)) > 0:
		items.append([_t("results.season_xp") % int(r["season_xp"]), UiTheme.TURQUOISE])
	for d: Variant in r.get("new_districts", []):
		items.append([_t("results.new_district") % _t("district." + String(d)), UiTheme.TURQUOISE])
	if int(r.get("rescued", 0)) > 0:
		items.append([_t("results.rescued") % int(r["rescued"]), UiTheme.TURQUOISE])
	if int(r.get("depth", 0)) > 0:
		items.append([_t("results.depth") % int(r["depth"]), UiTheme.TURQUOISE])
	if not String(r.get("ending", "")).is_empty():
		items.append([_t("ending." + String(r["ending"])), UiTheme.VIOLET])
	for m: Variant in r.get("new_missions", []):
		items.append([_t("results.new_mission") % _t("stage." + String(m)), UiTheme.TURQUOISE])
	if bool(r.get("log", false)):
		items.append([_t("results.log"), UiTheme.TURQUOISE])
	return items


## Dobrar créditos: anúncio recompensado opcional (ou grátis na Steam e para quem apoiou), 1 vez.
func _on_double() -> void:
	Ads.show_rewarded(SaveManager.data, func(granted: bool) -> void:
		if granted and not bool(result.get("doubled", false)):
			result["doubled"] = true
			SaveManager.add_currency("credits", int(result.get("credits", 0)))
			result["credits"] = int(result.get("credits", 0)) * 2
			SaveManager.save_profile()
			refresh_texts()
			if is_inside_tree():
				_stamp(_credits_pill, 1.25)
				AudioManager.play_ui("kenney_weapon_up"))


static func _t(key: String) -> String:
	return TranslationServer.translate(key)


func _layout() -> void:
	if _scroll == null:
		return
	var width := minf(safe.size.x - 24.0, 340.0)
	var x := floorf(safe.position.x + (safe.size.x - width) * 0.5)
	var bottom := safe.end.y - 12.0
	# Botões na zona do polegar. Lado a lado quando os dois textos cabem; senão, um sobre o outro,
	# com a ação principal sempre embaixo (onde o polegar já está).
	var primary := _continue if bool(result.get("cleared", false)) else _retry
	var secondary := _retry if primary == _continue else _continue
	var side_w := maxf(secondary.get_combined_minimum_size().x, floorf(width * 0.4))
	var main_w := width - GAP - side_w
	var top: float
	if main_w >= primary.get_combined_minimum_size().x and main_w >= width * 0.5:
		primary.position = Vector2(x + side_w + GAP, bottom - PRIMARY_HEIGHT)
		primary.size = Vector2(main_w, PRIMARY_HEIGHT)
		secondary.size = Vector2(side_w, SECONDARY_HEIGHT)
		secondary.position = Vector2(x, bottom - PRIMARY_HEIGHT + (PRIMARY_HEIGHT - SECONDARY_HEIGHT) * 0.5)
		top = bottom - PRIMARY_HEIGHT
	else:
		primary.position = Vector2(x, bottom - PRIMARY_HEIGHT)
		primary.size = Vector2(width, PRIMARY_HEIGHT)
		secondary.position = Vector2(x, primary.position.y - GAP - SECONDARY_HEIGHT)
		secondary.size = Vector2(width, SECONDARY_HEIGHT)
		top = secondary.position.y
	_scroll.set_meta(&"area", Rect2(x, safe.position.y + 10.0, width, top - 14.0 - (safe.position.y + 10.0)))
	_scroll.position = Vector2(x, safe.position.y + 10.0)
	_scroll.size = Vector2(width, top - 14.0 - _scroll.position.y)
	# Números em 4 colunas quando o cartão é largo (paisagem, tablet); 2x2 no retrato estreito.
	_grid.columns = 4 if width >= 320.0 else 2
	_fit_scroll()


## Centraliza o cartão na sobra acima dos botões (um pouco acima do meio, onde o olho cai) quando
## ele é menor que a área; se for maior, a área inteira rola.
func _fit_scroll() -> void:
	if _scroll == null or not _scroll.has_meta(&"area"):
		return
	var area: Rect2 = _scroll.get_meta(&"area")
	var h := _card.get_combined_minimum_size().y
	if h <= 0.0 or h >= area.size.y:
		_scroll.position = area.position
		_scroll.size = area.size
		return
	_scroll.position = Vector2(area.position.x, floorf(area.position.y + (area.size.y - h) * 0.4))
	_scroll.size = Vector2(area.size.x, h)


func back() -> bool:
	if _revealing:
		_finish_reveal()
		return true
	navigate.emit(&"map")
	return true


func layout_controls() -> Array[Control]:
	return [_scroll, _retry, _continue]


# --- Revelação em etapas ----------------------------------------------------------------------


## Monta a sequência: tudo começa invisível (só cor/escala; o leiaute já está no lugar final).
func _start_reveal() -> void:
	_kill_reveal()
	if UiFx.reduced():
		_finish_reveal()
		if _earned() > 0:
			AudioManager.play_ui("kenney_medal")
		return
	_revealing = true
	for node: CanvasItem in _reveal_nodes():
		node.modulate = Color(1, 1, 1, 0)
	# As 4 vagas de estrela já aparecem apagadas: o jogador vê o que está em jogo antes do carimbo.
	for i: int in range(4):
		_stars[i].modulate.a = 0.35
		_star_icons[i].modulate.a = 0.18
	_score.text = Locale.format_number(0)
	for value: Label in _stat_values:
		value.text = "0"
	_sequence = create_tween()
	_sequence.tween_interval(LEAD)
	_sequence.tween_callback(_step_banner)
	_sequence.tween_interval(STEP)
	_sequence.tween_callback(_step_score)
	_sequence.tween_interval(STEP + 0.15)
	_sequence.tween_callback(_step_stats)
	_sequence.tween_interval(STEP)
	var got: Array = result.get("stars", [])
	var earned := 0
	for i: int in range(4):
		var on := i < got.size() and bool(got[i])
		_sequence.tween_callback(_step_star.bind(i, on, earned))
		if on:
			earned += 1
		_sequence.tween_interval(STEP if on else STEP * 0.5)
	if _record.visible:
		_sequence.tween_callback(_step_record)
		_sequence.tween_interval(STEP + 0.1)
	if _grade.visible:
		_sequence.tween_callback(_step_grade)
		_sequence.tween_interval(STEP + 0.25)
	_sequence.tween_callback(_step_rewards)
	_sequence.tween_interval(STEP)
	if _chest.visible:
		_sequence.tween_callback(_step_chest)
		_sequence.tween_interval(CHEST_TIME)
	_sequence.tween_callback(_finish_reveal)


## Pula para o estado final (toque, tecla, voltar) ou termina a sequência.
func _finish_reveal() -> void:
	_kill_reveal()
	_revealing = false
	for node: CanvasItem in _reveal_nodes():
		node.modulate = Color.WHITE
		if node is Control:
			(node as Control).scale = Vector2.ONE
	_score.text = Locale.format_number(_score_value())
	for i: int in range(4):
		_stat_values[i].text = Locale.format_number(_stat(i))
	_chest.finish()
	_defeat.finish()
	var primary := _continue if bool(result.get("cleared", false)) else _retry
	if is_visible_in_tree() and primary.is_visible_in_tree():
		primary.grab_focus.call_deferred()


func _kill_reveal() -> void:
	if _sequence != null and _sequence.is_valid():
		_sequence.kill()
	_sequence = null
	for t: Tween in _counters:
		if t != null and t.is_valid():
			t.kill()
	_counters.clear()


func _reveal_nodes() -> Array[CanvasItem]:
	var nodes: Array[CanvasItem] = [_subtitle, _title, _score, _record, _rule, _credits_pill, _double,
			_retry, _continue, _grade, _defeat, _chest]
	for icon: Control in _star_icons:
		nodes.append(icon)
	for text: Label in _stars:
		nodes.append(text)
	for tile: Control in _stat_tiles:
		nodes.append(tile)
	for row: Node in _rewards.get_children():
		nodes.append(row as CanvasItem)
	return nodes


func _step_banner() -> void:
	_fade(_subtitle, 0.25)
	_stamp(_title, 1.3)
	AudioManager.play_ui("kenney_ui_confirm" if bool(result.get("cleared", false)) else "kenney_ui_back")
	# Os botões chegam junto da faixa: quem quer tentar de novo logo não espera a festa acabar.
	for button: Control in [_retry, _continue]:
		_fade(button, 0.3)
	# Derrota: logo abaixo da faixa, a barra mostra até onde o jogador chegou.
	if _defeat.visible:
		_fade(_defeat, 0.3)
		_defeat.play()


func _step_score() -> void:
	_fade(_score, 0.2)
	_counters.append(UiFx.count_up(_score, _score_value(), SCORE_COUNT,
			func(v: int) -> String: return Locale.format_number(v)))


func _step_stats() -> void:
	_fade(_rule, 0.3)
	for i: int in range(4):
		var tile := _stat_tiles[i]
		tile.pivot_offset = tile.size * 0.5
		tile.scale = Vector2.ONE * 0.85
		var t := create_tween().set_parallel()
		t.tween_property(tile, "modulate:a", 1.0, 0.22).set_delay(0.06 * i)
		t.tween_property(tile, "scale", Vector2.ONE, 0.3).set_delay(0.06 * i) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_counters.append(t)
		_counters.append(UiFx.count_up(_stat_values[i], _stat(i), STAT_COUNT,
				func(v: int) -> String: return Locale.format_number(v)))
	AudioManager.play_ui("kenney_ui_tab")


## Estrela ganha: carimbo com som de medalha subindo um tom a cada uma. Estrela perdida: só aparece,
## apagada, sem som (o silêncio também comunica).
func _step_star(i: int, on: bool, nth: int) -> void:
	_fade(_stars[i], 0.25)
	if on:
		_stamp(_star_icons[i], STAMP_FROM)
		AudioManager.play("kenney_medal", 1.0 + 0.12 * nth, 0.0, 0.0, "UI")
	else:
		_fade(_star_icons[i], 0.25)


## Nota da missão: o selo é carimbado com o tom subindo com a letra.
func _step_grade() -> void:
	_fade(_grade, 0.2)
	_stamp(_grade.seal(), 2.0)
	_grade.celebrate()


## Arca da Maré: aparece e o carretel gira até parar no prêmio.
func _step_chest() -> void:
	_drop(_chest, 0.0)
	_chest.spin()


func _step_record() -> void:
	_stamp(_record, 1.8)
	AudioManager.play_ui("kenney_weapon_up")


## Recompensas caem uma a uma (crédito primeiro, em ouro), com o "confirm" subindo de tom.
func _step_rewards() -> void:
	var items: Array[CanvasItem] = []
	if _credits_pill.visible:
		items.append(_credits_pill)
	if _double.visible:
		items.append(_double)
	for row: Node in _rewards.get_children():
		items.append(row as CanvasItem)
	for k: int in range(items.size()):
		_drop(items[k] as Control, 0.09 * k)
	if not items.is_empty():
		AudioManager.play("kenney_pearl", 1.0, 0.0, 0.0, "UI")


func _fade(node: CanvasItem, seconds: float) -> void:
	var t := create_tween()
	t.tween_property(node, "modulate:a", 1.0, seconds).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_counters.append(t)


func _stamp(node: Control, from: float) -> void:
	node.pivot_offset = node.size * 0.5
	node.scale = Vector2.ONE * from
	node.modulate.a = 0.0
	var t := create_tween().set_parallel()
	t.tween_property(node, "modulate:a", 1.0, STAMP_TIME * 0.5)
	t.tween_property(node, "scale", Vector2.ONE, STAMP_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_counters.append(t)


## Cai de cima: escala vertical a partir do topo do item (sem mexer na posição, que é do contêiner).
func _drop(node: Control, delay: float) -> void:
	node.pivot_offset = Vector2(node.size.x * 0.5, 0.0)
	node.scale = Vector2(0.9, 0.4)
	var t := create_tween().set_parallel()
	t.tween_property(node, "modulate:a", 1.0, 0.2).set_delay(delay)
	t.tween_property(node, "scale", Vector2.ONE, 0.34).set_delay(delay) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_counters.append(t)


## Um toque, clique, tecla ou botão do controle pula a revelação inteira.
func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	var press := (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed) \
			or (event is InputEventMouseButton and (event as InputEventMouseButton).pressed) \
			or (event is InputEventKey and (event as InputEventKey).pressed and not event.is_echo()) \
			or (event is InputEventJoypadButton and (event as InputEventJoypadButton).pressed)
	if not press:
		return
	if _revealing:
		_finish_reveal()
		_swallow_until = Time.get_ticks_msec() + SWALLOW_MS
		get_viewport().set_input_as_handled()
	elif Time.get_ticks_msec() < _swallow_until and not (event is InputEventKey):
		# O mesmo toque chega de novo como clique emulado: não pode apertar o botão embaixo do dedo.
		get_viewport().set_input_as_handled()


# --- Música -----------------------------------------------------------------------------------


## Vitória: a vinheta de recompensa por cima da revelação e, quando acaba, a música dos menus de
## volta (o App já pediu a dos menus ao abrir a tela; se o jogador sair antes, o App a mantém).
func _play_jingle() -> void:
	if not bool(result.get("cleared", false)) or String(result.get("mode", "")) == "practice":
		return
	if not AudioManager.play_music(JINGLE, 0.25):
		return
	var stream := load(AudioManager.MUSIC_DIR + JINGLE + ".ogg") as AudioStream
	var seconds := stream.get_length() if stream != null else 3.0
	# Função estática: o temporizador sobrevive à tela (o App pode liberá-la antes de a vinheta acabar).
	get_tree().create_timer(seconds + 0.2).timeout.connect(_restore_menu_music)


static func _restore_menu_music() -> void:
	if AudioManager.music_id() == JINGLE:
		AudioManager.play_music(App.MENU_MUSIC, 1.5)


# --- Apoio ------------------------------------------------------------------------------------


func _score_value() -> int:
	if String(result.get("mode", "")).is_empty():
		return int(result.get("score", 0))
	return int(result.get("run_score", result.get("score", 0)))


func _stat(i: int) -> int:
	return int(result.get(["kills", "grazes", "max_chain", "medals"][i], 0))


func _earned() -> int:
	var n := 0
	for s: Variant in result.get("stars", []):
		n += 1 if bool(s) else 0
	return n


func _fill_rewards() -> void:
	for child: Node in _rewards.get_children():
		_rewards.remove_child(child)
		child.queue_free()
	for item: Array in reward_items(result):
		var color: Color = item[1]
		var row := PanelContainer.new()
		var box := UiTheme.pill_box(color)
		box.bg_color = Color(color, 0.1)
		box.border_color = Color(color, 0.5)
		box.content_margin_left = 10
		box.content_margin_right = 10
		box.content_margin_top = 3
		box.content_margin_bottom = 3
		row.add_theme_stylebox_override("panel", box)
		var text := _centered(UiTheme.label(String(item[0]), UiTheme.FONT_SIZE, color.lightened(0.25), true))
		row.add_child(text)
		_rewards.add_child(row)
		if _revealing:
			row.modulate.a = 0.0
	_rewards.visible = _rewards.get_child_count() > 0


func _card_box(accent: Color) -> StyleBoxFlat:
	var box := UiTheme.panel_box(accent, 0.86)
	box.border_width_top = 3
	box.shadow_color = Color(accent, 0.16)
	box.shadow_size = 14
	box.shadow_offset = Vector2.ZERO
	box.content_margin_left = 14
	box.content_margin_right = 14
	box.content_margin_top = 12
	box.content_margin_bottom = 14
	return box


static func _style_button(button: Button, primary: bool) -> void:
	if primary:
		UiTheme.style_primary(button)
		return
	button.material = null
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		button.remove_theme_stylebox_override(state)
	for key: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color",
			"font_hover_pressed_color", "font_disabled_color"]:
		button.remove_theme_color_override(key)
	button.remove_theme_font_size_override("font_size")
	button.remove_theme_font_override("font")


## Estrela em vetor (nítida em qualquer resolução): ganha = ouro cheio com halo; perdida = contorno.
static func _draw_star(icon: Control) -> void:
	var c := icon.size * 0.5
	var r := minf(icon.size.x, icon.size.y) * 0.5
	var on := bool(icon.get_meta(&"on", false))
	if on:
		icon.draw_colored_polygon(_star_points(c, r * 1.25), Color(UiTheme.GOLD, 0.18))
		icon.draw_colored_polygon(_star_points(c, r), UiTheme.GOLD)
		icon.draw_colored_polygon(_star_points(c + Vector2(0, -r * 0.08), r * 0.45), Color("fff3c4"))
	else:
		var points := _star_points(c, r * 0.92)
		points.append(points[0])
		icon.draw_polyline(points, Color(UiTheme.TEXT_DIM, 0.6), 1.2, true)


static func _star_points(c: Vector2, r: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for k: int in range(10):
		var a := -PI * 0.5 + k * PI / 5.0
		points.append(c + Vector2(cos(a), sin(a)) * (r if k % 2 == 0 else r * 0.45))
	return points


static func _bold(node: Label) -> void:
	var bold := UiTheme.bold_font()
	if bold != null:
		node.add_theme_font_override("font", bold)


static func _centered(node: Label) -> Label:
	node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return node
