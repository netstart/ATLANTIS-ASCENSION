extends RefCounted
## Tela do ranking mundial de abates (tests/integration_tests.gd, com autoloads): os estados em run_view()
## e, em cada caso de tests/device_profiles.gd, o login e as 100 linhas com nomes longos em
## run_layout_case(). O PlayRanking é um autoload: o que o teste finge é devolvido no fim. As regras puras
## ficam em tests/ranking_tests.gd.

const DeviceProfiles := preload("res://tests/device_profiles.gd")
const LayoutTests := preload("res://tests/layout_tests.gd")
const NAMES: Array[String] = ["CapitãoDasMarésProfundasDeAtlântidaMMXXVI", "深海の長い名前を持つ撃墜王アトランティス",
		"КапитанГлубокихМорейАтлантиды", "심해의아주긴이름을가진격추왕", "x", "Rank One"]
const ME := "p4"


## Estados da tela (na tela de referência): só no Android, entrar, carregando, sem conexão, vazio e a lista;
## envio do total e os botões de entrada (Opções e Recordes).
func run_view(host: Node, check: Callable) -> void:
	var keep := _keep()
	Locale.set_language("pt_BR", false)
	var app := App.new()
	host.add_child(app)
	await host.get_tree().process_frame
	LayoutTests.fit(app, DeviceProfiles.main_view())
	for source: StringName in [&"options", &"records"]:
		app.go(source)
		await LayoutTests.settle(host)
		var entry := app.screen(source).find_child("Ranking", true, false) as Button
		check.call(entry != null and entry.is_visible_in_tree(), "Ranking: botão de entrada em %s" % source)
		if entry != null:
			entry.pressed.emit()
			await LayoutTests.settle(host)
		check.call(app.current == &"ranking", "Ranking: o botão de %s abre a tela" % source)
	var screen := app.screen(&"ranking") as RankingScreen
	check.call(not PlayRanking.available and _status(screen) == TranslationServer.translate("ranking.android_only"),
			"Ranking: no PC a tela avisa que é só no Android (%s)" % _status(screen))
	check.call(screen.find_child("SignIn", true, false) == null, "Ranking: sem botão de login fora do Android")
	# Sem login nada é enviado nem quebra (o resultado de uma partida chama isto sempre).
	PlayRanking.submit(SaveManager.data)
	PlayRanking.refresh()
	PlayRanking.sign_in_user()
	check.call(not PlayRanking.loading, "Ranking: sem o plugin, enviar, atualizar e entrar não fazem nada")
	PlayRanking.available = true
	for state: Array in [[false, false, false, "sign_in_hint"], [true, true, false, "loading"],
			[true, false, true, "offline"], [true, false, false, "empty"]]:
		PlayRanking.authenticated = state[0]
		PlayRanking.loading = state[1]
		PlayRanking.offline = state[2]
		PlayRanking.changed.emit()
		await LayoutTests.settle(host)
		check.call(_status(screen) == TranslationServer.translate("ranking." + String(state[3])),
				"Ranking: estado %s (%s)" % [state[3], _status(screen)])
		check.call((screen.find_child("SignIn", true, false) != null) == (state[3] == "sign_in_hint"),
				"Ranking: botão de login só quando falta entrar (%s)" % state[3])
	PlayRanking.scores = fake_scores(3)
	PlayRanking.player_id = ME
	PlayRanking.offline = true
	PlayRanking.changed.emit()
	await LayoutTests.settle(host)
	check.call(screen.find_child("Status", true, false) == null and screen.find_child("Rank_3", true, false) != null,
			"Ranking: sem conexão a lista já carregada continua à vista")
	_restore(keep)
	app.queue_free()
	await host.get_tree().process_frame


## Um caso de layout: pedindo login e com 100 linhas (nomes longos, CJK e cirílico, números grandes), em cada
## idioma do caso. Tudo na área segura; nenhuma linha passa da lista nem corta posição, abates ou tempo.
func run_layout_case(host: Node, check: Callable, c: Dictionary) -> void:
	var keep := _keep()
	var view: Vector2 = c["view"]
	var safe := DeviceProfiles.safe_rect(view, c["insets"])
	DeviceProfiles.simulate_insets(c["insets"])
	for lang: String in c["langs"]:
		Locale.set_language(lang, false)
		var tag := "Ranking %s [%s]" % [lang, c["label"]]
		var app := App.new()
		host.add_child(app)
		await host.get_tree().process_frame
		LayoutTests.fit(app, view)
		PlayRanking.available = true
		PlayRanking.authenticated = false
		PlayRanking.scores = []
		app.go(&"ranking")
		await LayoutTests.settle(host)
		var screen := app.screen(&"ranking") as RankingScreen
		var list := screen.find_child("List", true, false) as ScrollContainer
		var sign_in := screen.find_child("SignIn", true, false) as Button
		LayoutTests.check_screen(screen, safe, check, tag + " login", app.shell())
		check.call(sign_in != null and sign_in.is_visible_in_tree(), "%s: botão de login visível" % tag)
		if sign_in != null:
			LayoutTests.check_screen_controls([sign_in], safe, check, tag + " login")
		PlayRanking.authenticated = true
		PlayRanking.scores = fake_scores(RankingScreen.SHOWN + 5)
		PlayRanking.player_id = ME
		PlayRanking.changed.emit()
		await LayoutTests.settle(host)
		LayoutTests.check_screen(screen, safe, check, tag + " lista", app.shell())
		var rows := screen.find_children("Rank_*", "PanelContainer", true, false)
		check.call(rows.size() == RankingScreen.SHOWN, "%s: %d linhas (%d)" % [tag, RankingScreen.SHOWN, rows.size()])
		var span := list.get_global_rect()
		var fits := true
		for node: Node in rows:
			var row := node as Control
			var rect := row.get_global_rect()
			fits = fits and rect.position.x >= span.position.x - 0.5 and rect.end.x <= span.end.x + 0.5
			for cell: String in ["Rank", "Kills", "Time"]:
				var label := row.find_child(cell, true, false) as Label
				fits = fits and label.get_minimum_size().x <= label.size.x + 0.5 and row.get_global_rect().encloses(
						label.get_global_rect())
			fits = fits and (row.find_child("Name", true, false) as Label).size.x >= 24.0
		check.call(fits, "%s: toda linha cabe na lista, sem cortar posição, abates nem tempo" % tag)
		check.call(list.get_v_scroll_bar().max_value > list.size.y, "%s: a lista rola" % tag)
		# Teclado e controle: a linha recebe foco e a lista rola até ela.
		var last := rows[rows.size() - 1] as Control
		last.grab_focus()
		await LayoutTests.settle(host)
		check.call(span.grow(0.5).encloses(last.get_global_rect()), "%s: o foco leva a lista até a última linha" % tag)
		app.queue_free()
		await host.get_tree().process_frame
	DeviceProfiles.clear_insets()
	Locale.set_language("pt_BR", false)
	_restore(keep)


## `count` pontuações falsas, em ordem: nomes longos e curtos, abates e tempos grandes; a quarta é a do jogador.
static func fake_scores(count: int) -> Array:
	var out: Array = []
	for i: int in range(count):
		out.append(PlayGamesLeaderboardScore.new({
			"rank": i + 1,
			"rawScore": KillRanking.encode(987_654_321 - i * 9_000_000, float(KillRanking.TIME_CAP - i * 99_000)),
			"scoreHolderDisplayName": NAMES[i % NAMES.size()],
			"scoreHolder": {"playerId": "p%d" % (i + 1)},
		}))
	return out


func _status(screen: RankingScreen) -> String:
	var label := screen.find_child("Status", true, false) as Label
	return label.text if label != null else ""


func _keep() -> Array:
	return [PlayRanking.available, PlayRanking.authenticated, PlayRanking.loading, PlayRanking.offline,
			PlayRanking.scores, PlayRanking.player_id]


func _restore(keep: Array) -> void:
	PlayRanking.available = keep[0]
	PlayRanking.authenticated = keep[1]
	PlayRanking.loading = keep[2]
	PlayRanking.offline = keep[3]
	PlayRanking.scores = keep[4]
	PlayRanking.player_id = keep[5]
