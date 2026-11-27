class_name LanScreen
extends ListScreen
## Sala do coop em rede local (LanSession): um aparelho abre a sala e mostra o código de 4 dígitos, grande; o outro
## digita o código no teclado numérico da própria tela (toque, controle ou as teclas de número) e entra. Com os dois
## na sala o anfitrião começa a corrida. A tela é o estado da sessão: cada mudança dela remonta a lista, e o motivo
## da última falha (sem rede, sala não encontrada, sala cheia, versão diferente, parceiro saiu, conexão caiu,
## dessincronia) fica num cartão coral até a próxima tentativa.

const CODE_SIZE := 34
const KEYS: Array[String] = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "<", "0", "ok"]

var _session: LanSession
var _app: App
var _typed: String = ""


func title_key() -> String:
	return "mode.coop_lan"


func on_show(app: Node) -> void:
	_app = app as App
	if _session == null and _app != null:
		_session = _app.lan_session()
		_session.changed.connect(_on_session_changed)
	super(app)


func _on_session_changed() -> void:
	if _session.state == LanSession.State.LINKED:
		# Entrou: o código digitado já serviu (se a sala não foi achada ele fica, para corrigir um dígito).
		_typed = ""
	if is_visible_in_tree():
		AudioManager.play_ui("kenney_ui_back" if _session.error != &"" else "kenney_ui_confirm")
		refill()


func _fill() -> void:
	if _session == null:
		return
	if _session.error != &"":
		var failed := card(UiTheme.CORAL, null, 0.8)
		failed.get_parent().name = "Error"
		title_row(failed, tr("lan.err_" + String(_session.error)), UiTheme.CORAL, UiTheme.FONT_SIZE, &"lock", UiTheme.CORAL)
	match _session.state:
		LanSession.State.IDLE:
			_fill_lobby()
		LanSession.State.HOSTING:
			var box := card(UiTheme.GOLD)
			title_row(box, tr("lan.room_code"), UiTheme.WHITE, 13, &"plus", UiTheme.GOLD)
			_code_label(box, _session.code, UiTheme.GOLD)
			text(box, tr("lan.share_code"))
			text(box, tr("lan.waiting"), UiTheme.CYAN)
			add_button(tr("lan.close_room"), _leave, true, "Leave")
		LanSession.State.SEEKING:
			var box := card()
			title_row(box, tr("lan.seeking") % _session.code, UiTheme.WHITE, 13, &"ring")
			add_button(tr("lan.cancel"), _leave, true, "Leave")
		LanSession.State.LINKED:
			var box := card(UiTheme.MINT)
			title_row(box, tr("lan.partner_in") % tr("ship." + String(_session.partner.get("ship", "falcon"))),
					UiTheme.MINT, 13, &"check", UiTheme.MINT)
			if _session.is_host:
				add_button(tr("lan.start"), func() -> void: _app.lan_begin(), true, "Start", true)
			else:
				text(box, tr("lan.wait_host"), UiTheme.CYAN)
			add_button(tr("lan.leave"), _leave, true, "Leave")
		LanSession.State.PLAYING:
			# Entre duas missões da corrida, enquanto a partida seguinte não abre.
			text(card(), tr("lan.waiting"), UiTheme.CYAN)


## Sem sala: explicação, "Abrir sala" e o teclado numérico para entrar na sala do parceiro.
func _fill_lobby() -> void:
	text(card(UiTheme.TURQUOISE, null, 0.7), tr("lan.desc"))
	# Uma ação dourada por tela: "Abrir sala" até o código estar completo, e então "Entrar".
	var typed := _typed.length() == 4
	add_button(tr("lan.open_room"), func() -> void: _session.host(_info()), true, "Host", not typed)
	var box := card()
	title_row(box, tr("lan.join_title"), UiTheme.WHITE, 13, &"play")
	_code_label(box, _typed.rpad(4, "–"), UiTheme.CYAN)
	var keys := GridContainer.new()
	keys.name = "Keys"
	keys.columns = 3
	keys.add_theme_constant_override("h_separation", 6)
	keys.add_theme_constant_override("v_separation", 6)
	box.add_child(keys)
	for key: String in KEYS:
		var label := tr("lan.join") if key == "ok" else ("" if key == "<" else key)
		var b := button(keys, label, _on_key.bind(key), key != "ok" or typed, "Key_" + ("del" if key == "<" else key),
				key == "ok" and typed)
		b.custom_minimum_size.y = 40.0
		if key == "<":
			# Apagar: a seta de voltar desenhada (a fonte não garante um símbolo de apagar nos 11 idiomas).
			b.icon = icon(&"back")
			b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			b.add_theme_constant_override("icon_max_width", UiTheme.scaled(10))


## Código em algarismos grandes e espaçados (lido de longe, de um aparelho para o outro).
func _code_label(parent: Container, value: String, color: Color) -> void:
	var l := UiTheme.heading(" ".join(value.split("")), CODE_SIZE, color)
	l.name = "Code"
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(l)


func _on_key(key: String) -> void:
	if key == "<":
		_typed = _typed.left(-1)
	elif key != "ok":
		_typed = (_typed + key).left(4)
	elif _typed.length() == 4:
		_session.join(_typed, _info())


## O que este aparelho diz de si na sala: a nave escolhida, o nível dela e a altura de campo que cabe nesta tela.
func _info() -> Dictionary:
	var ship := String(SaveManager.data["selected"]["ship"])
	return {"ship": ship, "level": Economy.ship_level(SaveManager.data, StringName(ship)),
			"field_h": Game.field_height(self, size)}


func _leave() -> void:
	_session.leave()
	_session.error = &""


## Teclas de número, apagar e Enter digitam o código no teclado do PC.
func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or not is_visible_in_tree() or _session == null \
			or _session.state != LanSession.State.IDLE:
		return
	var typed := ""
	if key.keycode >= KEY_0 and key.keycode <= KEY_9:
		typed = str(key.keycode - KEY_0)
	elif key.keycode >= KEY_KP_0 and key.keycode <= KEY_KP_9:
		typed = str(key.keycode - KEY_KP_0)
	elif key.keycode == KEY_BACKSPACE:
		typed = "<"
	elif key.keycode in [KEY_ENTER, KEY_KP_ENTER] and not FocusNav.has_focus(get_viewport()):
		typed = "ok"
	if typed.is_empty():
		return
	get_viewport().set_input_as_handled()
	_on_key(typed)
	refill()


## Voltar fecha a sala (a parceira é avisada) antes de sair da tela.
func back() -> bool:
	if _session != null:
		_leave()
	return super()
