extends RefCounted
## Tela da sala do coop em rede local (LanScreen) e o caminho inteiro pelo App: layout de cada estado da sala em
## todas as resoluções e idiomas, o teclado numérico, e dois Apps no mesmo processo (127.0.0.1) abrindo a sala,
## entrando pelo código, jogando em lockstep pelo Game, pausando e saindo. Chamado por tests/integration_tests.gd.

const DeviceProfiles := preload("res://tests/device_profiles.gd")
const LayoutTests := preload("res://tests/layout_tests.gd")
## Portas desta suíte (LanRoom.test_shift): fora das do jogo e das de tests/lan_tests.gd.
const PORT_SHIFT := 20
## Estados da sala forjados na sessão (sem rede): [nome, estado, anfitrião, erro].
const STATES: Array[Array] = [
	["sem sala", LanSession.State.IDLE, false, &""],
	["falha", LanSession.State.IDLE, false, &"not_found"],
	["sala aberta", LanSession.State.HOSTING, true, &""],
	["procurando", LanSession.State.SEEKING, false, &""],
	["anfitrião com parceira", LanSession.State.LINKED, true, &""],
	["convidada na sala", LanSession.State.LINKED, false, &""],
	["entre missões", LanSession.State.PLAYING, false, &""],
]


## Um caso de tests/device_profiles.gd: cada idioma do caso, cada estado da sala.
func run_layout_case(host: Node, check: Callable, c: Dictionary) -> void:
	var view: Vector2 = c["view"]
	var safe := DeviceProfiles.safe_rect(view, c["insets"])
	DeviceProfiles.simulate_insets(c["insets"])
	for lang: String in c["langs"]:
		Locale.set_language(lang, false)
		var app := App.new()
		host.add_child(app)
		await host.get_tree().process_frame
		LayoutTests.fit(app, view)
		app.go(&"lan")
		var screen := app.screen(&"lan") as LanScreen
		var session := app.lan_session()
		for row: Array in STATES:
			session.state = row[1]
			session.is_host = row[2]
			session.error = row[3]
			session.code = "4821"
			session.partner = {"ship": "manta"}
			screen.refill()
			await LayoutTests.settle(host)
			var tag := "Layout sala LAN %s (%s) [%s]" % [lang, row[0], c["label"]]
			LayoutTests.check_screen(screen, safe, check, tag, app.shell())
			_check_inside(screen, safe, check, tag)
		session.state = LanSession.State.IDLE
		app.queue_free()
		await host.get_tree().process_frame
	LayoutTests.finish()


## Botões e o código da sala: na largura da área segura, com alvo de toque e sem texto cortado.
func _check_inside(screen: LanScreen, safe: Rect2, check: Callable, tag: String) -> void:
	var list := screen.get("_list") as Control
	var ok := true
	var why := ""
	for node: Node in list.find_children("*", "Control", true, false):
		var control := node as Control
		if not control.is_visible_in_tree() or not (control is Button or control is Label):
			continue
		var rect := control.get_global_rect()
		var fits := rect.position.x >= safe.position.x - 0.5 and rect.end.x <= safe.end.x + 0.5 \
				and control.get_minimum_size().x <= rect.size.x + 0.5
		if control is Button:
			fits = fits and rect.size.y >= UiTheme.TOUCH_MIN - 0.5
		if not fits:
			ok = false
			why = "%s %s" % [control.name, rect]
	check.call(ok, "%s: botões e textos da sala cabem (%s)" % [tag, why])


func run_flow(host: Node, check: Callable) -> void:
	SaveManager.reset_profile()
	Locale.set_language("pt_BR", false)
	DeviceProfiles.clear_insets()
	LanRoom.test_shift = PORT_SHIFT
	check.call(Modes.available(&"coop_lan") and not Modes.unlocked(SaveManager.data, &"coop_lan"),
			"Coop LAN: vale em todo aparelho e abre com a 1-3")
	SaveManager.data["missions"]["c1m3"] = {"cleared": true}
	check.call(Modes.unlocked(SaveManager.data, &"coop_lan"), "Coop LAN: aberto depois da 1-3")
	var a := App.new()
	var b := App.new()
	for app: App in [a, b]:
		host.add_child(app)
		await host.get_tree().process_frame
		LayoutTests.fit(app, Vector2(270, 600))
	# O banner do modo nos Eventos leva à sala.
	a.go(&"events")
	await LayoutTests.settle(host)
	var banner := a.screen(&"events").find_child("Mode_coop_lan", true, false) as Button
	check.call(banner != null, "Coop LAN: banner do modo nos Eventos")
	if banner != null:
		banner.pressed.emit()
	await LayoutTests.settle(host)
	check.call(a.current == &"lan", "Coop LAN: o banner abre a tela da sala")
	b.go(&"lan")
	await LayoutTests.settle(host)
	var screen_a := a.screen(&"lan") as LanScreen
	var screen_b := b.screen(&"lan") as LanScreen
	a.lan_session().loopback = true
	b.lan_session().loopback = true
	b.lan_session().seek_seconds = 2.0
	# Teclado numérico: digita, apaga e só libera "Entrar" com 4 dígitos.
	_press(screen_b, "Key_7")
	_press(screen_b, "Key_del")
	check.call(_code(screen_b) == "– – – –" and _button(screen_b, "Key_ok").disabled, "Sala: apagar limpa o dígito")
	_press(screen_a, "Host")
	await LayoutTests.settle(host)
	var code := a.lan.code
	check.call(a.lan.state == LanSession.State.HOSTING and _code(screen_a) == " ".join(code.split("")),
			"Sala: aberta mostra o código %s em algarismos grandes" % code)
	for digit: String in code.split(""):
		check.call(_button(screen_b, "Key_ok").disabled, "Sala: 'Entrar' espera os 4 dígitos")
		_press(screen_b, "Key_" + digit)
	check.call(_code(screen_b) == " ".join(code.split("")), "Sala: o teclado da tela digita o código")
	_press(screen_b, "Key_ok")
	check.call(await _wait(host, func() -> bool:
		return a.lan.state == LanSession.State.LINKED and b.lan.state == LanSession.State.LINKED),
			"Sala: a convidada entra pelo código")
	await LayoutTests.settle(host)
	check.call(_button(screen_a, "Start") != null and _button(screen_b, "Start") == null,
			"Sala: só o anfitrião começa a corrida")
	var played := _played()
	_press(screen_a, "Start")
	check.call(await _wait(host, func() -> bool: return a.game != null and b.game != null),
			"Partida: abre nos dois aparelhos")
	if a.game == null or b.game == null:
		LanRoom.test_shift = 0
		return
	check.call(a.run_mode == &"coop_lan" and b.run_mode == &"coop_lan" and a.run_queue.size() == b.run_queue.size()
			and a.game.seed_value == b.game.seed_value and a.game.sim.field == b.game.sim.field
			and a.game.sim.loadout == b.game.sim.loadout and not a.game.can_revive and not b.game.can_revive,
			"Partida: a mesma fila, semente, carga e campo nos dois; sem reviver por anúncio")
	check.call(b.game.sim.wing != null and b.game.hud().guest and not a.game.hud().guest
			and String(b.game.sim.wing.ship.get("id", "")) == String(SaveManager.data["selected"]["ship"]),
			"Partida: a convidada pilota a ala e o HUD dela segue a ala")
	check.call(not (a.game.hud().find_child("Restart", true, false) as Control).visible,
			"Partida: sem recomeçar sozinho no coop em rede")
	check.call(await _wait(host, func() -> bool: return a.game.sim.frame >= 240 and b.game.sim.frame >= 240, 1800),
			"Partida: os dois Games andam em lockstep (%d e %d passos)" % [a.game.sim.frame, b.game.sim.frame])
	check.call(a.lan.error == &"" and b.lan.error == &"" and absi(a.game.sim.frame - b.game.sim.frame) <= 4,
			"Partida: hashes trocados sem dessincronia")
	# Pausa de um lado: o outro é avisado na tela.
	a.game.set_paused(true)
	check.call(await _wait(host, func() -> bool: return b.lan.partner_paused), "Pausa: a parceira é avisada")
	await LayoutTests.settle(host)
	var note := b.game.find_child("LanNote", true, false) as Label
	check.call(note != null and note.visible and note.text == b.game.tr("lan.partner_paused"),
			"Pausa: 'Parceiro pausou' sobre o campo")
	a.game.set_paused(false)
	check.call(await _wait(host, func() -> bool: return not b.lan.partner_paused), "Pausa: a volta também")
	# O anfitrião sai pelo menu de pausa: a convidada volta à sala com o motivo, sem resultado gravado.
	a.game.hud().quit_pressed.emit()
	check.call(await _wait(host, func() -> bool: return b.game == null and b.current == &"lan"),
			"Saída: a convidada volta à tela da sala")
	await LayoutTests.settle(host)
	check.call(a.game == null and a.current == &"events" and a.lan.state == LanSession.State.IDLE,
			"Saída: quem saiu volta aos Eventos")
	check.call(b.lan.error == &"left" and screen_b.find_child("Error", true, false) != null
			and b.lan.state == LanSession.State.IDLE, "Saída: a sala diz que o parceiro saiu")
	check.call(_played() == played and b.run_mode == &"",
			"Saída: partida interrompida não grava resultado")
	# "Tentar de novo" de uma corrida em rede volta à sala (não começa sozinho).
	a.start_mode(&"coop_lan")
	check.call(a.current == &"lan" and a.game == null, "Coop LAN: recomeçar leva à sala")
	# Sala de novo e a corrida até o fim (o par cai no mesmo passo): cada aparelho grava o próprio resultado.
	_press(screen_a, "Host")
	for digit: String in a.lan.code.split(""):
		_press(screen_b, "Key_" + digit)
	_press(screen_b, "Key_ok")
	await _wait(host, func() -> bool: return a.lan.state == LanSession.State.LINKED and b.lan.state == a.lan.state)
	await LayoutTests.settle(host)
	_press(screen_a, "Start")
	await _wait(host, func() -> bool: return a.game != null and b.game != null)
	if a.game == null or b.game == null:
		check.call(false, "Fim: a segunda sala abre a partida")
		LanRoom.test_shift = 0
		return
	await _wait(host, func() -> bool: return a.game.sim.frame >= 30 and a.game.sim.frame == b.game.sim.frame)
	a.game.sim.player.alive = false
	b.game.sim.player.alive = false
	check.call(await _wait(host, func() -> bool: return a.current == &"results" and b.current == &"results", 900)
			and a.game == null and b.game == null, "Fim: os dois veem a tela de resultados")
	check.call(_played() == played + 2.0 and String(a.last_result.get("mode", "")) == "coop_lan"
			and int(b.last_result.get("credits", 0)) > 0 and a.last_result["score"] == b.last_result["score"]
			and not b.last_result.has("board_pos"),
			"Fim: cada aparelho grava o próprio resultado (sem placar nem replay, como o coop local)")
	check.call(await _wait(host, func() -> bool:
		return a.lan.state == LanSession.State.IDLE and b.lan.state == LanSession.State.IDLE)
			and a.lan.error == &"" and b.lan.error == &"", "Fim: a sala fecha nos dois sem aviso de erro")
	screen_a.back()
	for app: App in [a, b]:
		app.queue_free()
	await LayoutTests.settle(host)
	LanRoom.test_shift = 0


## Anda quadros até `done` valer (com um respiro para os pacotes em 127.0.0.1).
func _wait(host: Node, done: Callable, frames: int = 600) -> bool:
	for _i: int in range(frames):
		if done.call():
			return true
		OS.delay_msec(1)
		await host.get_tree().process_frame
	return done.call()


func _played() -> float:
	return float((SaveManager.data.get("stats", {}) as Dictionary).get("missions_played", 0))


func _button(screen: Control, name: String) -> Button:
	return screen.find_child(name, true, false) as Button


func _press(screen: Control, name: String) -> void:
	var b := _button(screen, name)
	if b != null and not b.disabled:
		b.pressed.emit()


func _code(screen: Control) -> String:
	var label := screen.find_child("Code", true, false) as Label
	return label.text if label != null else ""
