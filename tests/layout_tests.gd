extends RefCounted
## Layout das telas em cada caso de tests/device_profiles.gd (sem recorte em todos os idiomas; com o
## furo da câmera em cima e embaixo nos idiomas mais longos): todo controle inteiro na área segura,
## alvos de toque com a altura mínima, textos que cabem e nada encostando. Chamado por
## tests/integration_tests.gd.

const DeviceProfiles := preload("res://tests/device_profiles.gd")
const SCREENS: Array[StringName] = [&"boot", &"hub", &"map", &"results", &"credits", &"hangar", &"ships",
		&"options", &"logbook", &"story", &"events", &"shop", &"city", &"practice", &"season", &"records"]
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
				check_screen(app.screen(screen_name), safe, check, tag)
		app.queue_free()
		await host.get_tree().process_frame


## Depois dos casos: sem recorte simulado e de volta ao pt_BR.
static func finish() -> void:
	DeviceProfiles.clear_insets()
	Locale.set_language("pt_BR", false)


## HUD da partida num caso (idiomas mais longos): controles na área segura, campo inteiro e
## HUD cobrindo no máximo 6% do campo.
func run_hud_case(host: Node, check: Callable, c: Dictionary) -> void:
	var view: Vector2 = c["view"]
	var safe := DeviceProfiles.safe_rect(view, c["insets"])
	DeviceProfiles.simulate_insets(c["insets"])
	for lang: String in Languages.INSET_LANGS:
		Locale.set_language(lang, false)
		var game := GAME.instantiate() as Game
		game.configure(&"c1m1", &"falcon", 7, true)
		host.add_child(game)
		await host.get_tree().process_frame
		game.relayout_for(view)
		game.hud().size = view
		await host.get_tree().process_frame
		var tag := "Layout HUD %s [%s]" % [lang, c["label"]]
		var layout: Dictionary = game.hud().layout
		check.call(Playfield.fits(layout, safe), "%s: campo na área segura" % tag)
		check.call(Playfield.hud_coverage(layout) <= 0.06, "%s: HUD cobre ≤ 6%% do campo" % tag)
		check_screen_controls(game.hud().layout_controls(), safe, check, tag)
		game.sim.offer_blessings()
		game.hud().show_offer(game.sim)
		await host.get_tree().process_frame
		var panel := game.hud().offer_panel()
		check.call(layout["field"].encloses(panel.get_global_rect()), "%s: bênçãos dentro do campo" % tag)
		check_screen_controls([panel], safe, check, tag + " bênçãos")
		game.queue_free()
		await host.get_tree().process_frame


## O teste roda numa janela pequena (headless): a raiz das telas recebe o tamanho lógico do aparelho.
static func fit(app: App, view: Vector2) -> void:
	var root := app.root()
	root.set_anchors_preset(Control.PRESET_TOP_LEFT)
	root.position = Vector2.ZERO
	root.size = view


static func settle(host: Node) -> void:
	for i: int in range(3):
		await host.get_tree().process_frame


static func check_screen(screen: Screen, safe: Rect2, check: Callable, tag: String) -> void:
	check.call(screen != null and screen.visible, "%s: tela visível" % tag)
	if screen == null:
		return
	var controls: Array[Control] = screen.call("layout_controls")
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
