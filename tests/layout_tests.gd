extends RefCounted
## Layout das telas em cada caso de tests/device_profiles.gd (sem recorte em todos os idiomas; com o
## furo da câmera em cima e embaixo nos idiomas mais longos): todo controle inteiro na área segura,
## alvos de toque com a altura mínima, textos que cabem e nada encostando. Chamado por
## tests/integration_tests.gd.

const DeviceProfiles := preload("res://tests/device_profiles.gd")
const SCREENS: Array[StringName] = [&"boot", &"hub", &"map", &"results", &"credits", &"hangar", &"ships",
		&"options", &"logbook", &"story", &"events", &"shop", &"city", &"practice", &"season", &"records", &"ranking",
		&"lan"]
const GAME := preload("res://scenes/game/Game.tscn")


func run(host: Node, check: Callable) -> void:
	for c: Dictionary in DeviceProfiles.layout_cases():
		await run_case(host, check, c)
	for c: Dictionary in DeviceProfiles.layout_cases():
		await run_hud_case(host, check, c)
	finish()


## Um caso de tests/device_profiles.gd: cada idioma do caso num App novo, todas as telas.
## Unidade das fatias de tests/integration_tests.gd.
func run_case(host: Node, check: Callable, c: Dictionary) -> void:
	await _visit_case(host, check, c)


## O primeiro App aberto ainda acha o perfil zerado (o hub paga o login do dia, por exemplo); do segundo
## em diante as telas já mostram o perfil depois dessa primeira visita. Uma fatia que não começa pelo
## primeiro caso abre antes um App igual ao dele, sem verificações, para cada caso ver o mesmo estado
## que veria no processo único.
func warm_up(host: Node, c: Dictionary) -> void:
	var first := c.duplicate()
	first["langs"] = [(c["langs"] as Array)[0]]
	await _visit_case(host, Callable(), first)


func _visit_case(host: Node, check: Callable, c: Dictionary) -> void:
	var view: Vector2 = c["view"]
	var safe := DeviceProfiles.safe_rect(view, c["insets"])
	DeviceProfiles.simulate_insets(c["insets"])
	for lang: String in c["langs"]:
		Locale.set_language(lang, false)
		var app := App.new()
		host.add_child(app)
		await host.get_tree().process_frame
		fit(app, view)
		for screen_name: StringName in SCREENS:
			app.go(screen_name)
			await settle(host)
			if check.is_valid():
				var tag := "Layout %s %s [%s]" % [screen_name, lang, c["label"]]
				check_screen(app.screen(screen_name), safe, check, tag, app.shell())
		app.queue_free()
		await host.get_tree().process_frame


## Depois dos casos: sem recorte simulado e de volta ao pt_BR.
static func finish() -> void:
	DeviceProfiles.clear_insets()
	Locale.set_language("pt_BR", false)


## HUD da partida num caso (idiomas mais longos): campo com a altura da tela e inteiro na área segura, HUD
## cobrindo no máximo 6% do campo, em retrato com a largura inteira da área segura (ou a altura inteira, quando a
## largura não cabe), controles na área segura sem encostar uns nos outros e a pilha de botões no meio da borda
## (esquerda; direita na mão esquerda), abaixo do HUD de cima.
func run_hud_case(host: Node, check: Callable, c: Dictionary) -> void:
	var view: Vector2 = c["view"]
	var safe := DeviceProfiles.safe_rect(view, c["insets"])
	DeviceProfiles.simulate_insets(c["insets"])
	for lang: String in Languages.INSET_LANGS:
		Locale.set_language(lang, false)
		var game := GAME.instantiate() as Game
		game.configure(&"c1m1", &"falcon", 7, true)
		game.screen = view
		host.add_child(game)
		await host.get_tree().process_frame
		game.relayout_for(view)
		# O HUD trabalha em unidades do campo ampliado (Game.hud_scale): a área segura também.
		var u := game.hud_scale()
		game.hud().size = view / u
		await host.get_tree().process_frame
		var tag := "Layout HUD %s [%s]" % [lang, c["label"]]
		var layout: Dictionary = game.hud().layout
		var hsafe := Rect2(safe.position / u, safe.size / u)
		var usable := floorf(safe.end.y) - ceilf(safe.position.y)
		var tall := (layout["field"] as Rect2).size.y
		var wide := (layout["field"] as Rect2).size.x
		check.call(absf(tall - game.sim.field.y) < 1.0 and (view.x > view.y or tall == Playfield.height_for(safe)),
				"%s: campo com a altura da tela (%.0f)" % [tag, tall])
		check.call(view.x <= view.y or absf(tall * u - usable) < 1.0,
				"%s: no PC deitado o campo ampliado ocupa a altura inteira" % tag)
		check.call(view.x > view.y or absf(wide * u - safe.size.x) < 0.5 or absf(tall * u - usable) < 0.5,
				"%s: em retrato o campo cobre a largura da área segura (%.1f de %.0f)" % [tag, wide * u, safe.size.x])
		check.call(absf(game.field_scale() - u) < 0.0001, "%s: HUD na mesma escala do campo (%.3f)" % [tag, u])
		check.call(Playfield.fits(layout, hsafe), "%s: campo na área segura" % tag)
		check_stack(game.hud(), layout, false, check, tag)
		check.call(Playfield.hud_coverage(layout) <= 0.06, "%s: HUD cobre ≤ 6%% do campo" % tag)
		check_screen_controls(game.hud().layout_controls(), hsafe, check, tag)
		# PODER com a Corrente cheia: o nome do poder aparece e também cabe, nas duas mãos.
		game.sim.player.power_charge = Powers.SEGMENTS
		game.hud().refresh(game.sim, 0.5)
		check.call(game.hud().power_button().name_label.visible, "%s: nome do poder visível com a Corrente cheia" % tag)
		check_screen_controls(game.hud().layout_controls(), hsafe, check, tag + " poder")
		Settings.set_value("handedness", "left")
		game.relayout_for(view)
		check_screen_controls(game.hud().layout_controls(), hsafe, check, tag + " poder canhoto")
		check_stack(game.hud(), layout, true, check, tag + " canhoto")
		# Vaga do Turbo ocupada (a compra é do outro teste): ainda cabe e não encosta em nada.
		game.hud().set_turbo(true, 1.5)
		check_screen_controls(game.hud().layout_controls(), hsafe, check, tag + " turbo canhoto")
		game.hud().set_turbo(false, 1.0)
		Settings.set_value("handedness", "right")
		game.relayout_for(view)
		# Aviso do objetivo no rádio (no alto do campo): fica só o aviso da Sim e sai antes de os alvos entrarem.
		var warn := SimObjectives.WARN_FRAMES / 60.0
		game.hud().show_radio_text(tr("mini.sabotage_warn") % 3, UiTheme.GOLD, warn)
		check.call(is_equal_approx(float(game.hud().get("_radio_left")), warn), "%s: aviso do objetivo dura o aviso" % tag)
		game.hud().refresh(game.sim, warn + 0.02)
		check.call(not (game.hud().get("_radio_panel") as Control).visible, "%s: o rádio sai quando os alvos entram" % tag)
		# Objetivo de fase em curso (SimObjectives): o marcador de cada tipo cabe e não encosta em nada.
		var goals := game.sim.objectives
		for kind: String in ["rescue", "sabotage", "intercept"]:
			goals.enabled = true
			goals.current = {}
			goals.schedule = [{"t": 0.0, "type": kind, "count": 6, "seconds": 12.0}]
			goals.next = 0
			goals.step(game.sim)
			game.hud().refresh(game.sim, 0.1)
			check.call(game.hud().layout_controls()[-1].is_visible_in_tree(), "%s: marcador do objetivo %s" % [tag, kind])
			check_screen_controls(game.hud().layout_controls(), hsafe, check, "%s objetivo %s" % [tag, kind])
		goals.current = {}
		game.sim.offer_blessings()
		game.hud().show_offer(game.sim)
		await host.get_tree().process_frame
		var panel := game.hud().offer_panel()
		check.call(layout["field"].encloses(panel.get_global_rect()), "%s: bênçãos dentro do campo" % tag)
		check_screen_controls([panel], hsafe, check, tag + " bênçãos")
		game.queue_free()
		await host.get_tree().process_frame
	if c["label"] == DeviceProfiles.RESOLUTIONS[0]["label"]:
		await run_turbo(host, check)


## Botão Turbo do HUD (na tela de referência): só aparece com a compra; tocar troca a velocidade da partida
## (GameClock.turbo: mais passos fixos por quadro), e sair da partida volta a 1x.
func run_turbo(host: Node, check: Callable) -> void:
	var profile := SaveManager.data
	var purchases: Dictionary = profile["purchases"]
	var selected: Dictionary = profile["selected"]
	var had: Variant = purchases.get("turbo", false)
	var rate: Variant = selected.get("turbo", 1.0)
	for own: bool in [false, true]:
		purchases["turbo"] = own
		selected["turbo"] = 1.0
		var game := GAME.instantiate() as Game
		game.configure(&"c1m1", &"falcon", 7, false)
		game.screen = DeviceProfiles.main_view()
		host.add_child(game)
		await host.get_tree().process_frame
		var button := game.hud().turbo_button()
		check.call(button.visible == Turbo.owned(profile) and (own or Store.is_steam() or not button.visible),
				"Turbo: botão só com a compra (comprado: %s, visível: %s)" % [own, button.visible])
		if own:
			check.call(is_equal_approx(GameClock.turbo, 1.0), "Turbo: a partida começa na velocidade guardada (1x)")
			button.pressed.emit()
			check.call(is_equal_approx(GameClock.turbo, 1.5) and is_equal_approx(Turbo.speed(profile), 1.5),
					"Turbo: tocar passa para 1,5x (relógio %.2f)" % GameClock.turbo)
			button.pressed.emit()
			button.pressed.emit()
			check.call(is_equal_approx(GameClock.turbo, 1.0), "Turbo: 2x e de volta a 1x")
			button.pressed.emit()
		game.queue_free()
		await host.get_tree().process_frame
		check.call(is_equal_approx(GameClock.turbo, 1.0), "Turbo: fora da partida o relógio volta a 1x")
	purchases["turbo"] = had
	selected["turbo"] = rate


## Pilha de botões (retrato): dentro do campo, centrada na vertical dele (a vaga do Turbo conta), colada na borda
## do lado da mão e abaixo da linha do HUD de cima; o toque que começa num botão não move a nave
## (Game.touches_button).
static func check_stack(hud: GameHud, layout: Dictionary, left_handed: bool, check: Callable, tag: String) -> void:
	var field: Rect2 = layout["field"]
	var top: Rect2 = layout["hud"]
	if hud.size.x > hud.size.y:
		return
	var stack := Rect2()
	var buttons: Array[Button] = [hud.get_node("Bomb") as Button, hud.power_button(), hud.get_node("Special") as Button,
			hud.turbo_button()]
	for i: int in range(buttons.size()):
		var b := buttons[i]
		var r := b.get_global_rect()
		stack = r if i == 0 else stack.merge(r)
		var edge := field.end.x - r.end.x if left_handed else r.position.x - field.position.x
		check.call(field.grow(0.01).encloses(r) and absf(edge) <= 0.5,
				"%s: botão %s encostado na borda do campo (%s)" % [tag, b.name, r])
		check.call(i == 0 or r.end.y <= buttons[i - 1].get_global_rect().position.y,
				"%s: botão %s acima do anterior (bomba embaixo)" % [tag, b.name])
		check.call(r.position.y >= top.end.y + 8.0, "%s: botão %s longe do HUD de cima" % [tag, b.name])
		check.call(hud.touches_button(r.get_center()) == b.visible, "%s: toque no %s é do botão" % [tag, b.name])
	check.call(absf(stack.get_center().y - field.get_center().y) <= 1.0,
			"%s: pilha centrada na vertical do campo (%.1f, campo %.1f)" % [tag, stack.get_center().y, field.get_center().y])
	check.call(not hud.touches_button(field.get_center()), "%s: toque no meio do campo move a nave" % tag)
	check.call(not hud.touches_button(Vector2(stack.get_center().x, field.end.y - 20.0)),
			"%s: toque no canto de baixo move a nave" % tag)


## O teste roda numa janela pequena (headless): a raiz das telas recebe o tamanho lógico do aparelho.
static func fit(app: App, view: Vector2) -> void:
	var root := app.root()
	root.set_anchors_preset(Control.PRESET_TOP_LEFT)
	root.position = Vector2.ZERO
	root.size = view


static func settle(host: Node) -> void:
	for i: int in range(3):
		await host.get_tree().process_frame


## Telas-aba (NavShell): a casca à vista e os controles dela entram junto, então nada da tela pode
## encostar nas barras; fora das abas a casca fica escondida.
static func check_screen(screen: Screen, safe: Rect2, check: Callable, tag: String, shell: NavShell = null) -> void:
	check.call(screen != null and screen.visible, "%s: tela visível" % tag)
	if screen == null:
		return
	var controls: Array[Control] = screen.call("layout_controls")
	if shell != null:
		var tab := screen.in_shell()
		check.call(shell.visible == tab, "%s: casca %s" % [tag, "à vista" if tab else "escondida"])
		if tab:
			controls.append_array(shell.layout_controls())
			var insets := screen.shell_insets()
			check.call(screen.safe.size.y > 0.0 and is_equal_approx(screen.safe.position.y, safe.position.y + insets.x),
					"%s: área útil entre as barras da casca" % tag)
	check_screen_controls(controls, safe, check, tag)


static func check_screen_controls(controls: Array[Control], safe: Rect2, check: Callable, tag: String) -> void:
	var rects: Array[Rect2] = []
	for control: Control in controls:
		if not control.is_visible_in_tree():
			continue
		var rect := control.get_global_rect()
		var name := "%s '%s'" % [control.get_class(), _text_of(control)]
		check.call(safe.grow(0.5).encloses(rect), "%s: %s inteiro na área segura (%s em %s)" % [tag, name, rect, safe])
		if control is Button:
			var button := control as Button
			check.call(rect.size.y >= UiTheme.TOUCH_MIN - 0.5,
					"%s: %s com alvo de toque ≥ %.0f (%.0f)" % [tag, name, UiTheme.TOUCH_MIN, rect.size.y])
			check.call(button.get_minimum_size().x <= rect.size.x + 0.5,
					"%s: texto de %s cabe no botão (%.0f > %.0f)" % [tag, name, button.get_minimum_size().x, rect.size.x])
		elif control is Label:
			var label := control as Label
			var need := label.get_minimum_size()
			check.call(need.x <= rect.size.x + 0.5 and need.y <= rect.size.y + 0.5,
					"%s: %s sem corte (%s > %s)" % [tag, name, need, rect.size])
		for other: Rect2 in rects:
			check.call(not other.intersects(rect), "%s: %s não encosta em outro controle" % [tag, name])
		rects.append(rect)


static func _text_of(control: Control) -> String:
	if control is Button:
		return (control as Button).text
	if control is Label:
		return (control as Label).text.replace("\n", " ")
	return control.name
