class_name HubScreen
extends Screen
## Aba Campanha (plano mestre 7.2; menus de comando 1.15): a casa É o mapa do capítulo. A casca de
## navegação (NavShell) fica com o piloto, o Poder, as moedas, as Opções e as abas; aqui ficam:
##
## - Cabeçalho do capítulo: o número enorme em dourado com contorno ("01."), o nome do capítulo e a
##   chamada da história; embaixo (ou ao lado, em tela baixa) o Poder contra o recomendado do capítulo
##   (CommandKit.power_badge: menta quando alcança, coral quando falta; só informa, nunca bloqueia).
## - Trilha das missões do capítulo (CampaignTrail) ocupando o miolo: nós circulares ligados por linha
##   pontilhada em zigue-zague que sobe; concluídas com as estrelas embaixo; a próxima com o sonar e a
##   nave do jogador pairando em cima; trancadas = pino cinza com cadeado; chefe com octógono e coroa.
##   Tocar num nó aberto abre o cartão da missão (MissionCard). Deslizar para o lado ou as setas trocam
##   de capítulo (só os abertos).
## - Marco do capítulo: o baú com o prêmio que já existe no jogo (aeronave dos fragmentos ou próxima asa
##   pelas estrelas, CampaignTrail.milestone) e a barra do progresso; tocar leva a Naves ou à Oficina.
## - Atalhos dos dois lados da trilha (ícone grande e rótulo curto, bolinha de aviso pelo Notices):
##   Diário, Cidade e Passe à esquerda; Recordes, Prática e Créditos à direita. No desktop eles saem da
##   coluna e ficam nas laterais.
## - Rodapé: JOGAR dourado no meio ("JOGAR · 1-5": a cena de história pendente vem antes; senão a
##   próxima missão começa direto), a Carta da Ascensão à esquerda e o Desafio (Eventos) à direita.
## Ao abrir no dia, o login de 7 dias entrega a recompensa num aviso que some sozinho, sobre a trilha.
##
## Orçamento: nada se redesenha por quadro. O sonar da próxima missão e a nave que paira só mudam
## escala, posição e transparência; a trilha só se redesenha ao trocar de capítulo ou de tamanho.

const MARGIN := 8.0
const TOAST_SECONDS := 4.0
const PLAY_HEIGHT := 48.0
const SIDE_W := 46.0
const SIDE_H := 46.0
const FOOT_SIDE_W := 54.0
const ROW_H := 40.0
const NODE := CampaignParts.NODE
const NODE_MAX := 58.0
## Coluna central no desktop (trilha, cabeçalho e rodapé); os atalhos ficam fora dela.
const WIDE_COLUMN := 440.0
const WIDE_FROM := 600.0
## Altura útil abaixo da qual o selo do Poder sobe para o lado do nome.
const COMPACT_BELOW := 400.0
## Coluna abaixo da qual o selo grande do Poder vira a linha compacta sob o nome.
const NARROW_BELOW := 380.0
const PULSE_PERIOD := 1.6

## Capítulo à vista na trilha.
var chapter: int = 1

var _number: Label
var _name: Label
var _hook: Label
var _badge: Control
var _stars_chip: Control
var _power_line: HBoxContainer
var _trail: CampaignParts.TrailView
var _nodes: Array[CampaignParts.TrailNode] = []
var _pulse: CampaignParts.Pulse
var _marker: CampaignParts.Marker
var _prev: CampaignParts.Chevron
var _next: CampaignParts.Chevron
var _milestone: CampaignParts.Milestone
var _milestone_info: Dictionary = {}
var _shortcuts: Array[CampaignParts.ShortcutButton] = []
var _map_button: CampaignParts.ShortcutButton
var _daily_button: CampaignParts.ShortcutButton
var _play: Button
var _dim: ColorRect
var _card: MissionCard
var _toast: PanelContainer
var _toast_label: Label
var _toast_left: float = 0.0
var _clock: float = 0.0
## Centro da próxima missão na trilha (o sonar e a nave seguem); x < 0 quando ela não está à vista.
var _next_at := Vector2(-1, -1)
## Lado dos nós da trilha (cresce de NODE até NODE_MAX quando sobra espaço).
var _node_size: float = NODE


func _build() -> void:
	_trail = CampaignParts.TrailView.new()
	_trail.swiped.connect(func(step: int) -> void: show_chapter(CampaignTrail.neighbor(SaveManager.data, chapter, step)))
	add_child(_trail)
	_pulse = CampaignParts.Pulse.new()
	add_child(_pulse)
	_build_header()
	_marker = CampaignParts.Marker.new()
	add_child(_marker)
	_prev = CampaignParts.Chevron.new("PrevChapter", false)
	_prev.pressed.connect(_step_chapter.bind(-1))
	add_child(_prev)
	_next = CampaignParts.Chevron.new("NextChapter", true)
	_next.pressed.connect(_step_chapter.bind(1))
	add_child(_next)
	_milestone = CampaignParts.Milestone.new()
	_milestone.pressed.connect(_on_milestone)
	add_child(_milestone)
	var targets := [["Logbook", "menuList", &"logbook"], ["City", "home", &"city"], ["Season", "trophy", &"season"],
			["Records", "leaderboardsSimple", &"records"], ["Practice", "target", &"practice"],
			["Credits", "information", &"credits"]]
	for t: Array in targets:
		var s := CampaignParts.ShortcutButton.new(t[0], t[1])
		s.pressed.connect(_go.bind(t[2]))
		add_child(s)
		_shortcuts.append(s)
	_map_button = CampaignParts.ShortcutButton.new("FullMap", "medal1")
	_map_button.pressed.connect(_go.bind(&"map"))
	add_child(_map_button)
	_daily_button = CampaignParts.ShortcutButton.new("Daily", "star")
	_daily_button.accent = UiTheme.GOLD
	_daily_button.pressed.connect(_go.bind(&"events"))
	add_child(_daily_button)
	_play = Button.new()
	_play.name = "Play"
	UiTheme.style_primary(_play, 18)
	_play.clip_text = true
	_play.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_play.pressed.connect(_on_play)
	add_child(_play)
	_build_toast()
	_dim = ColorRect.new()
	_dim.name = "CardDim"
	_dim.color = Color(UiTheme.ABYSS, 0.62)
	_dim.visible = false
	_dim.gui_input.connect(func(event: InputEvent) -> void:
		if (event is InputEventMouseButton and (event as InputEventMouseButton).pressed) or \
				(event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed):
			close_card())
	add_child(_dim)
	_card = MissionCard.new()
	_card.visible = false
	_card.closed.connect(close_card)
	_card.play_pressed.connect(func(id: StringName) -> void:
		close_card()
		play.emit(id))
	add_child(_card)


func _build_header() -> void:
	_number = UiTheme.heading("", 34, UiTheme.GOLD)
	_number.name = "ChapterNumber"
	_number.add_theme_color_override("font_outline_color", Color("5a3100"))
	_number.add_theme_constant_override("outline_size", UiTheme.scaled(7))
	_number.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
	_number.add_theme_constant_override("shadow_offset_y", 2)
	_number.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_number)
	_name = UiTheme.heading("", UiTheme.HEADING_SIZE + 2, UiTheme.WHITE)
	_name.name = "ChapterName"
	_name.clip_text = true
	_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_name)
	_hook = UiTheme.label("", UiTheme.SMALL_SIZE, UiTheme.CYAN)
	_hook.name = "ChapterHook"
	_hook.clip_text = true
	_hook.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_hook.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hook)


func _build_toast() -> void:
	_toast = PanelContainer.new()
	_toast.name = "Toast"
	_toast.add_theme_stylebox_override("panel", UiTheme.panel_box(UiTheme.GOLD, 0.92))
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.visible = false
	_toast_label = UiTheme.label("", UiTheme.FONT_SIZE, UiTheme.GOLD, true)
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_child(_toast_label)
	add_child(_toast)


func _go(target: StringName) -> void:
	AudioManager.play_ui("kenney_ui_click")
	navigate.emit(target)


## Jogar: a cena de história pendente (prólogo, fim de ato) vem antes; senão começa a próxima missão.
func _on_play() -> void:
	AudioManager.play_ui("kenney_ui_confirm")
	if not StoryScreen.pending(SaveManager.data).is_empty():
		navigate.emit(&"story")
		return
	play.emit(Economy.next_mission(SaveManager.data))


func _on_milestone() -> void:
	match StringName(_milestone_info.get("kind", &"")):
		&"ship":
			_go(&"ships")
		&"wing":
			_go(&"hangar")
		_:
			_go(&"map")


func _step_chapter(step: int) -> void:
	AudioManager.play_ui("kenney_ui_click")
	show_chapter(CampaignTrail.neighbor(SaveManager.data, chapter, step))


## Pelo controle a tela abre no JOGAR (ou no Jogar do cartão aberto).
func default_focus() -> Control:
	return _card.play_button() if _card.visible else _play


func on_show(_app: Node) -> void:
	close_card()
	chapter = CampaignTrail.current_chapter(SaveManager.data)
	var reward := LiveOps.login(SaveManager.data, App.today())
	if not reward.is_empty():
		SaveManager.save_profile()
		AudioManager.play_ui("kenney_ui_confirm")
		show_toast(tr("hub.login_reward") % [int(SaveManager.data["login"]["streak"]), reward_text(reward)])
	refresh_texts()


## "+400 Créditos, +10 Pérolas".
static func reward_text(reward: Dictionary) -> String:
	var parts := PackedStringArray()
	for k: String in reward:
		if k != "core":
			parts.append("+%d %s" % [int(reward[k]), TranslationServer.translate("currency." + k)])
	return ", ".join(parts)


func show_toast(text: String) -> void:
	_toast_label.text = text
	_toast.visible = true
	_toast.modulate.a = 1.0
	_toast_left = TOAST_SECONDS
	relayout()


## Mostra a trilha de outro capítulo (só os abertos; o mesmo não faz nada).
func show_chapter(target: int) -> void:
	if target == chapter or not CampaignTrail.open_chapters(SaveManager.data).has(target):
		return
	chapter = target
	_rebuild()
	if not UiFx.reduced():
		for c: CanvasItem in [_trail, _number, _name, _hook] + _nodes:
			c.modulate.a = 0.0
			create_tween().tween_property(c, "modulate:a", 1.0, 0.18)


## Nós da trilha à vista (testes e foco).
func trail_nodes() -> Array[CampaignParts.TrailNode]:
	var out: Array[CampaignParts.TrailNode] = []
	for b: CampaignParts.TrailNode in _nodes:
		if b.visible:
			out.append(b)
	return out


func node_button(id: StringName) -> CampaignParts.TrailNode:
	for n: CampaignParts.TrailNode in trail_nodes():
		if n.id == id:
			return n
	return null


## Abre o cartão da missão (só as abertas).
func open_card(id: StringName) -> void:
	if not Economy.mission_unlocked(SaveManager.data, id):
		return
	AudioManager.play_ui("kenney_ui_click")
	_card.show_mission(id, Economy.power(SaveManager.data))
	_card.visible = true
	_dim.visible = true
	relayout()
	if FocusNav.pad:
		_card.play_button().grab_focus()


func close_card() -> void:
	if _card == null or not _card.visible:
		return
	var id := _card.mission
	_card.visible = false
	_dim.visible = false
	var node := node_button(id)
	if FocusNav.pad and node != null:
		node.grab_focus()


func card_open() -> bool:
	return _card.visible


func card() -> MissionCard:
	return _card


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	if _toast_left > 0.0:
		_toast_left -= delta
		_toast.modulate.a = clampf(_toast_left, 0.0, 1.0)
		_toast.visible = _toast_left > 0.0
	if _next_at.x < 0.0 or UiFx.reduced():
		return
	# Sonar e nave: só escala, posição e transparência (sem redesenho).
	_clock += delta
	var u := fposmod(_clock / PULSE_PERIOD, 1.0)
	_pulse.scale = Vector2.ONE * (0.62 + 0.55 * (1.0 - pow(1.0 - u, 2.0)))
	_pulse.modulate.a = 0.85 * (1.0 - u)
	_marker.position.y = _marker_y() + roundf(sin(_clock * 2.2) * 2.0)


func _marker_y() -> float:
	return _next_at.y - _node_size * 0.5 - _marker.size.y - 3.0


func refreshes_on_show() -> bool:
	return true


func refresh_texts() -> void:
	_play.text = tr("hub.play") % CampaignParts.short_label(Economy.next_mission(SaveManager.data))
	var labels := [tr("campaign.short_logbook"), tr("campaign.short_city"), tr("campaign.short_season"),
			tr("campaign.short_records"), tr("campaign.short_practice"), tr("campaign.short_credits")]
	# Dica com o nome inteiro (mouse e leitor de tela); o rótulo curto cabe no atalho.
	var tips := [tr("logbook.title"), tr("city.title"), tr("season.title"), tr("events.records"),
			tr("mode.practice"), tr("boot.credits")]
	for i: int in range(_shortcuts.size()):
		_shortcuts[i].label = labels[i]
		_shortcuts[i].tooltip_text = tips[i]
	_map_button.label = tr("campaign.full_map")
	_daily_button.label = tr("campaign.daily")
	_prev.tooltip_text = tr("campaign.prev_chapter")
	_next.tooltip_text = tr("campaign.next_chapter")
	_rebuild()


## Monta o capítulo à vista: cabeçalho, selo do Poder, nós, marco e avisos.
func _rebuild() -> void:
	var p := SaveManager.data
	_number.text = "%02d." % chapter
	_name.text = after_kicker(tr("map.chapter%d" % chapter))
	_hook.text = after_kicker(tr("hub.banner_c%d" % chapter))
	if _badge != null:
		_badge.queue_free()
	_badge = CommandKit.power_badge(Economy.power(p), Economy.recommended_power(chapter))
	add_child(_badge)
	move_child(_badge, _hook.get_index() + 1)
	if _power_line != null:
		_power_line.queue_free()
	_power_line = power_line(Economy.power(p), Economy.recommended_power(chapter))
	add_child(_power_line)
	move_child(_power_line, _badge.get_index() + 1)
	if _stars_chip != null:
		_stars_chip.queue_free()
	var got := CampaignTrail.chapter_stars(p, chapter)
	_stars_chip = CommandKit.stat_chip(&"star", tr("campaign.stars"), "%d/%d" % [got.x, got.y], UiTheme.GOLD)
	_stars_chip.name = "ChapterStars"
	add_child(_stars_chip)
	move_child(_stars_chip, _badge.get_index() + 1)
	var list := CampaignTrail.nodes(p, chapter)
	while _nodes.size() < list.size():
		var b := CampaignParts.TrailNode.new()
		b.pressed.connect(func() -> void: open_card(b.id))
		add_child(b)
		move_child(b, _pulse.get_index() + 1)
		_nodes.append(b)
	for i: int in range(_nodes.size()):
		_nodes[i].visible = i < list.size()
		if i < list.size():
			_nodes[i].setup(list[i])
	var chapters := CampaignTrail.open_chapters(p)
	_prev.disabled = chapters.find(chapter) <= 0
	_next.disabled = chapters.find(chapter) >= chapters.size() - 1
	_prev.focus_mode = Control.FOCUS_NONE if _prev.disabled else Control.FOCUS_ALL
	_next.focus_mode = Control.FOCUS_NONE if _next.disabled else Control.FOCUS_ALL
	_prev.queue_redraw()
	_next.queue_redraw()
	_milestone_info = CampaignTrail.milestone(p, chapter)
	_milestone.title = milestone_text(_milestone_info)
	_milestone.set_progress(int(_milestone_info["have"]), int(_milestone_info["need"]), bool(_milestone_info["done"]))
	var today := App.today()
	_shortcuts[2].set_notice(Notices.season_reward_ready(p, today))
	_daily_button.set_notice(Notices.daily_event_open(p, today))
	_marker.tint = ListScreen.ship_tint(String(p["selected"].get("ship", "falcon")),
			String(p["selected"].get("cosmetic", "")))
	relayout()


## Poder compacto das telas estreitas: raio e número em menta (alcança o recomendado) ou coral (falta)
## e "Rec. 3.400" pequeno ao lado. Só informa, nunca bloqueia.
static func power_line(value: int, recommended: int) -> HBoxContainer:
	var color := UiTheme.MINT if value >= recommended else UiTheme.CORAL
	var row := HBoxContainer.new()
	row.name = "PowerLine"
	row.add_theme_constant_override("separation", 3)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bolt := CommandKit.glyph(&"bolt", color, 12)
	bolt.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(bolt)
	var number := UiTheme.label(Locale.format_number(value), UiTheme.FONT_SIZE, color)
	var bold := UiTheme.bold_font()
	if bold != null:
		number.add_theme_font_override("font", bold)
	row.add_child(number)
	var rec := UiTheme.label(TranslationServer.translate("campaign.rec_short") % Locale.format_number(recommended),
			UiTheme.SMALL_SIZE - 1, UiTheme.TEXT_DIM)
	rec.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(rec)
	return row


## Maior fonte (de `max_size` até `min_size`) em que o texto do rótulo cabe em `width` com no máximo
## `lines` linhas e sem palavra cortada; o rótulo quebra linha só quando `lines` > 1.
static func _fit_label(label: Label, width: float, max_size: int, min_size: int, lines: int) -> void:
	label.clip_text = false
	label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if lines > 1 else TextServer.AUTOWRAP_OFF
	var font := label.get_theme_font("font")
	var words := label.text.split(" ", false)
	var fs := max_size
	while fs > min_size:
		var widest := 0.0
		for w: String in words:
			widest = maxf(widest, font.get_string_size(w, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x)
		var one := font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var tall := font.get_multiline_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, width, fs).y
		var line_h := font.get_height(fs)
		if (lines == 1 and one <= width) or (lines > 1 and widest <= width and tall <= line_h * lines + 0.5):
			break
		fs -= 1
	label.add_theme_font_size_override("font_size", fs)
	label.custom_minimum_size.x = width if lines > 1 else 0.0


## "Capítulo 1 · Oceano Atlântico" → "Oceano Atlântico" (o número já está grande ao lado); o CJK usa "・".
static func after_kicker(text: String) -> String:
	for sep: String in [" · ", "・", "·"]:
		var at := text.find(sep)
		if at >= 0:
			return text.substr(at + sep.length()).strip_edges()
	return text


## Texto do marco: "Conclua 1-3: Manta", "Próxima asa: Ala Ímã" ou "Capítulo completo".
static func milestone_text(info: Dictionary) -> String:
	match StringName(info.get("kind", &"")):
		&"ship":
			return TranslationServer.translate("campaign.milestone_ship") % [
					CampaignParts.short_label(info["mission"]), TranslationServer.translate("ship." + String(info["id"]))]
		&"wing":
			return TranslationServer.translate("campaign.milestone_wing") % TranslationServer.translate(
					"wing." + String(info["id"]))
	return TranslationServer.translate("campaign.milestone_done")


func _layout() -> void:
	if _play == null or _badge == null or _stars_chip == null or _power_line == null:
		return
	var wide := safe.size.x >= WIDE_FROM
	var col_w := minf(safe.size.x - MARGIN * 2.0, WIDE_COLUMN if wide else 9999.0)
	var col_x := floorf(safe.position.x + (safe.size.x - col_w) * 0.5)
	var col_end := col_x + col_w
	var compact := safe.size.y < COMPACT_BELOW
	# Tela estreita: o selo grande não cabe ao lado do nome; vira a linha compacta do Poder embaixo.
	var narrow := col_w < NARROW_BELOW
	# Cabeçalho: número, nome e chamada; o selo do Poder embaixo (ou à direita, em tela baixa).
	var top := safe.position.y + 6.0
	var num := _number.get_minimum_size()
	_number.position = Vector2(col_x, top - 4.0)
	_number.size = num
	var badge := _badge.get_combined_minimum_size()
	var name_x := col_x + num.x + 8.0
	var name_end := col_end
	var header_h := maxf(num.y - 4.0, 40.0)
	_badge.visible = not narrow
	_power_line.visible = narrow
	if narrow:
		header_h = 0.0
	elif compact:
		_badge.position = Vector2(col_end - badge.x, top)
		name_end = _badge.position.x - 6.0
		header_h = maxf(header_h, badge.y)
	else:
		_badge.position = Vector2(col_x, top + header_h + 4.0)
		header_h += 4.0 + badge.y
	_badge.size = badge
	# Estrelas do capítulo ao lado do selo (só quando o selo fica embaixo e sobra lugar).
	var chip := _stars_chip.get_combined_minimum_size()
	_stars_chip.visible = not narrow and not compact and _badge.position.x + badge.x + 8.0 + chip.x <= col_end
	_stars_chip.position = Vector2(_badge.position.x + badge.x + 8.0, floorf(_badge.position.y + (badge.y - chip.y) * 0.5))
	_stars_chip.size = chip
	# Nome e chamada: na estreita quebram em até 2 linhas antes de encolher; nas outras, 1 linha que
	# encolhe até caber. Nunca reticências.
	var name_room := maxf(0.0, name_end - name_x)
	# Em tela baixa o nome fica em 1 linha (encolhe): a altura vai para a trilha e os atalhos.
	var lines := 2 if narrow and not compact else 1
	_fit_label(_name, name_room, UiTheme.scaled(UiTheme.HEADING_SIZE + 2), UiTheme.scaled(9), lines)
	_fit_label(_hook, name_room, UiTheme.scaled(UiTheme.SMALL_SIZE), UiTheme.scaled(7), lines)
	_name.size = Vector2(name_room, 0.0)
	var name_h := _name.get_minimum_size().y
	_name.position = Vector2(name_x, top)
	_name.size = Vector2(name_room, name_h)
	_hook.size = Vector2(name_room, 0.0)
	var hook_h := _hook.get_minimum_size().y
	_hook.position = Vector2(name_x, _name.position.y + name_h)
	_hook.size = Vector2(name_room, hook_h)
	if narrow:
		var line := _power_line.get_combined_minimum_size()
		_power_line.position = Vector2(name_x, _hook.position.y + hook_h + 2.0)
		_power_line.size = line
		header_h = maxf(num.y - 4.0, name_h + hook_h + 2.0 + line.y)
	# Rodapé: Carta, JOGAR e Desafio, logo acima da barra de abas.
	var foot_y := safe.end.y - 6.0 - PLAY_HEIGHT
	var play_w := minf(col_w - (FOOT_SIDE_W + 6.0) * 2.0, 300.0)
	var play_x := floorf(col_x + (col_w - play_w) * 0.5)
	_play.position = Vector2(play_x, foot_y)
	_play.size = Vector2(play_w, PLAY_HEIGHT)
	_play.add_theme_font_size_override("font_size", CommandKit.fit_size(CommandKit.bold(_play), _play.text,
			play_w - 28.0, UiTheme.scaled(18), UiTheme.scaled(11)))
	_map_button.position = Vector2(play_x - 6.0 - FOOT_SIDE_W, foot_y)
	_map_button.size = Vector2(FOOT_SIDE_W, PLAY_HEIGHT)
	_daily_button.position = Vector2(play_x + play_w + 6.0, foot_y)
	_daily_button.size = Vector2(FOOT_SIDE_W, PLAY_HEIGHT)
	# Marco do capítulo entre as setas de trocar capítulo.
	var row_y := foot_y - 8.0 - ROW_H
	var ms_w := minf(col_w - (UiTheme.TOUCH_MIN + 6.0) * 2.0, 320.0)
	var ms_x := floorf(col_x + (col_w - ms_w) * 0.5)
	_milestone.position = Vector2(ms_x, row_y)
	_milestone.size = Vector2(ms_w, ROW_H)
	_prev.position = Vector2(ms_x - 6.0 - UiTheme.TOUCH_MIN, row_y)
	_prev.size = Vector2(UiTheme.TOUCH_MIN, ROW_H)
	_next.position = Vector2(ms_x + ms_w + 6.0, row_y)
	_next.size = Vector2(UiTheme.TOUCH_MIN, ROW_H)
	# Atalhos: três de cada lado entre o cabeçalho e o marco (no desktop, fora da coluna).
	var area_top := top + header_h + 8.0
	var area_end := row_y - 8.0
	var side_h := clampf((area_end - area_top - 8.0) / 3.0, UiTheme.TOUCH_MIN, SIDE_H)
	var gap := clampf((area_end - area_top - side_h * 3.0) / 2.0, 2.0, 12.0)
	var left_x := col_x
	var right_x := col_end - SIDE_W
	if wide:
		left_x = maxf(safe.position.x + MARGIN, col_x - 24.0 - SIDE_W)
		right_x = minf(safe.end.x - MARGIN - SIDE_W, col_end + 24.0)
	for i: int in range(_shortcuts.size()):
		var s := _shortcuts[i]
		s.size = Vector2(SIDE_W, side_h)
		s.position = Vector2(left_x if i < 3 else right_x, floorf(area_top + (i % 3) * (side_h + gap)))
	# Trilha entre os atalhos.
	var trail := Rect2(col_x, area_top, col_w, maxf(0.0, area_end - area_top))
	if not wide:
		trail.position.x = left_x + SIDE_W + 6.0
		trail.size.x = maxf(0.0, right_x - 6.0 - trail.position.x)
	_trail.position = Vector2(safe.position.x, area_top - 4.0)
	_trail.size = Vector2(safe.size.x, trail.size.y + 8.0)
	_place_nodes(trail)
	# Cartão da missão e aviso do login.
	_dim.position = Vector2.ZERO
	_dim.size = size
	var card_w := minf(col_w, 340.0)
	_card.fit_width(card_w)
	_card.position = Vector2(floorf(safe.position.x + (safe.size.x - card_w) * 0.5),
			floorf(clampf(safe.get_center().y - _card.size.y * 0.5, safe.position.y + 4.0,
			maxf(safe.position.y + 4.0, safe.end.y - _card.size.y - 4.0))))
	var text_w := card_w - 24.0
	var font_size := _toast_label.get_theme_font_size("font_size")
	var text_h := _toast_label.get_theme_font("font").get_multiline_string_size(_toast_label.text,
			HORIZONTAL_ALIGNMENT_CENTER, text_w, font_size).y
	_toast_label.custom_minimum_size = Vector2(text_w, text_h)
	_toast.size = Vector2(card_w, 0.0)
	_toast.reset_size()
	# Sobre o marco do capítulo (some em 4 s; a trilha e o JOGAR ficam à vista).
	_toast.position = Vector2(floorf(safe.position.x + (safe.size.x - card_w) * 0.5),
			floorf(row_y + ROW_H - _toast.size.y))


## Posição dos nós: linhas que sobem; o zigue-zague vai de um lado ao outro, a linha abaixo de duas
## rotas fica no meio e as rotas ficam nas pontas (nenhum nó encosta no da linha vizinha).
func _place_nodes(trail: Rect2) -> void:
	var shown := trail_nodes()
	var rows: Dictionary = {}
	for b: CampaignParts.TrailNode in shown:
		var r := CampaignTrail.row_of(b.id)
		if not rows.has(r):
			rows[r] = []
		(rows[r] as Array).append(b)
	var count := 0
	for r: int in rows:
		count = maxi(count, r + 1)
	var xs := row_positions(rows, count, chapter)
	# Folga em cima para a nave e embaixo para as estrelas. Nós maiores quando sobra espaço (o espaço
	# entre linhas fica ≥ 2 nós quando eles crescem; no aperto, o zigue-zague os afasta na horizontal).
	# Em tela baixa as folgas encolhem (a nave pode passar por cima do vão do cabeçalho).
	var low := trail.size.y < 160.0
	var pad_top := 14.0 if low else 24.0
	var pad_bottom := 8.0 if low else 12.0
	var usable := Rect2(trail.position.x, trail.position.y + pad_top, trail.size.x,
			maxf(0.0, trail.size.y - pad_top - pad_bottom))
	var rows_gap := maxf(1.0, float(count - 1))
	_node_size = floorf(clampf(minf((usable.size.y - NODE) / rows_gap * 0.5, usable.size.x / 4.0), NODE, NODE_MAX))
	var ns := _node_size
	var span_x := maxf(0.0, minf(usable.size.x - ns, 300.0))
	var x0 := usable.position.x + (usable.size.x - ns - span_x) * 0.5 + ns * 0.5
	# A trilha ocupa a altura toda: primeiro nó perto do marco, último perto do topo.
	var spacing := (usable.size.y - ns) / rows_gap
	var lift := (usable.size.y - ns - spacing * (count - 1)) * 0.5
	var bottom := usable.end.y - lift - ns * 0.5
	var centers: Dictionary = {}
	for r: int in rows:
		var list: Array = rows[r]
		for k: int in range(list.size()):
			var b: CampaignParts.TrailNode = list[k]
			var c := Vector2(x0 + span_x * float(xs[r][k]), bottom - spacing * r).floor()
			centers[b.id] = c
			b.size = Vector2(_node_size, _node_size)
			b.position = c - b.size * 0.5
	# Linhas e halos no espaço do TrailView.
	var o := _trail.position
	var links: Array = []
	var halos: Array = []
	_next_at = Vector2(-1, -1)
	for b: CampaignParts.TrailNode in shown:
		var c: Vector2 = centers[b.id]
		if b.open:
			halos.append([c - o, Color(UiTheme.GOLD if b.next else CampaignParts.ORANGE, 0.42 if b.next else 0.2)])
		if b.next:
			_next_at = c
		var after: Array = Economy.node(b.id)["after"]
		var linked := false
		for prev: Variant in after:
			if centers.has(StringName(prev)):
				links.append([centers[StringName(prev)] - o, c - o, b.open])
				linked = true
		if not linked and not after.is_empty():
			# Vem do capítulo anterior: a linha entra pela borda de baixo.
			links.append([Vector2(c.x, trail.end.y + 6.0) - o, c - o, b.open])
		if _leads_out(b.id):
			# Segue para o capítulo seguinte: a linha sai pela borda de cima.
			links.append([c - o, Vector2(c.x, trail.position.y - 4.0) - o, b.cleared])
	_trail.node_radius = _node_size * 0.5
	_trail.links = links
	_trail.halos = halos
	_trail.queue_redraw()
	_pulse.visible = _next_at.x >= 0.0
	_marker.visible = _next_at.x >= 0.0
	if _next_at.x >= 0.0:
		_pulse.size = Vector2.ONE * floorf(_node_size * 1.6)
		_pulse.position = (_next_at - _pulse.size * 0.5).floor()
		_marker.position = Vector2(floorf(_next_at.x - _marker.size.x * 0.5), _marker_y())
		if UiFx.reduced():
			_pulse.scale = Vector2.ONE
			_pulse.modulate.a = 0.6


## A missão abre alguma de outro capítulo (a linha da trilha continua para cima).
static func _leads_out(id: StringName) -> bool:
	var chapter_number := CampaignTrail.chapter_of(id)
	for n: Dictionary in Economy.CAMPAIGN:
		if int(n["chapter"]) != chapter_number and (n["after"] as Array).has(id):
			return true
	return false


## Posição horizontal (0 a 1) de cada nó por linha: {linha: [x, ...]}. Duas rotas lado a lado vão para
## as pontas; a linha logo abaixo delas fica no meio e a de baixo desta, na ponta; as demais alternam
## perto das bordas (o lado muda com o capítulo).
static func row_positions(rows: Dictionary, count: int, chapter_number: int) -> Dictionary:
	var out: Dictionary = {}
	var side := chapter_number % 2
	for r: int in range(count):
		var n := (rows.get(r, []) as Array).size()
		if n >= 2:
			var xs: Array = []
			for k: int in range(n):
				xs.append(float(k) / float(n - 1))
			out[r] = xs
		elif (rows.get(r + 1, []) as Array).size() >= 2:
			out[r] = [0.5]
		else:
			var left := (r + side) % 2 == 0
			var edge := (rows.get(r + 2, []) as Array).size() >= 2
			out[r] = [(0.0 if left else 1.0) if edge else (0.08 if left else 0.92)]
	return out


func layout_controls() -> Array[Control]:
	var list: Array[Control] = [_number, _name, _hook, _badge, _power_line, _stars_chip, _prev, _milestone, _next,
			_map_button, _play, _daily_button]
	for s: CampaignParts.ShortcutButton in _shortcuts:
		list.append(s)
	for b: CampaignParts.TrailNode in trail_nodes():
		list.append(b)
	return list


## Voltar fecha o cartão; sem cartão, volta para o título.
func back() -> bool:
	if _card.visible:
		close_card()
		return true
	navigate.emit(&"boot")
	return true
