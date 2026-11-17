extends RefCounted
## Clima na tela (1.13, tests/integration_tests.gd, com autoloads): camadas, ordem abaixo das balas,
## todas as resoluções, arco-íris, relâmpago e trovão, ambiente e abafamento. As regras puras ficam
## em tests/weather_tests.gd.

const DeviceProfiles := preload("res://tests/device_profiles.gd")


func run_view(host: Node, check: Callable) -> void:
	var game := (load("res://scenes/game/Game.tscn") as PackedScene).instantiate() as Game
	game.configure(&"c3m2", &"falcon", 7, true)
	host.add_child(game)
	await host.get_tree().process_frame
	var view := game.weather_view()
	var world := view.world
	check.call(view != null and view.get_index() < world.get_parent().get_index(),
			"Clima: o céu baixo fica entre o chão e o campo")
	var slot := world.weather_slot
	var bullets_index := -1
	for child: Node in world.get_children():
		if child is BulletRenderer and (child as BulletRenderer).get_index() > bullets_index:
			bullets_index = child.get_index()
	check.call(slot.get_index() < bullets_index, "Clima: a camada de perto fica abaixo das balas inimigas")
	var front := slot.get_child(0) as ColorRect
	check.call(front != null and front.size == game.sim.field,"Clima: a frente cobre o campo inteiro")
	var shader := (front.material as ShaderMaterial).shader.code
	check.call(shader.contains("const float MAX_ALPHA = 0.35"), "Clima: frente com opacidade ≤ 35%")
	for tall: float in [Playfield.FIELD.y, Playfield.MAX_HEIGHT]:
		var f := Vector2(Playfield.FIELD.x, tall)
		for left: bool in [false, true]:
			var at := WeatherView.vane_at(f, left)
			check.call(Rect2(Vector2.ZERO, f).encloses(Rect2(at - Vector2(10, 10), Vector2(36, 20))),
					"Clima: biruta dentro do campo de %.0f (canhoto: %s)" % [tall, left])
	for c: Dictionary in DeviceProfiles.layout_cases():
		var size: Vector2 = c["view"]
		game.relayout_for(size)
		var sky := view.get_child(0) as ColorRect
		# Em paisagem o palco é ampliado (Game.field_scale): o céu, em unidades do campo, cobre a tela ampliado.
		var covered := sky.size * game.field_scale()
		check.call(covered.x >= size.x - 1.0 and covered.y >= size.y - 1.0, "Clima [%s]: céu cobre a tela" % c["label"])
	game.relayout_for(Vector2(360, 640))
	var w := game.sim.weather
	w.state = &"storm"
	w.previous = &"storm"
	w.blend = 1.0
	await host.get_tree().process_frame
	check.call((view.get_child(0) as ColorRect).visible and front.visible, "Clima: tempestade acende as duas camadas")
	var heard: Array[float] = []
	view.thunder.connect(func(d: float, _strike: bool) -> void: heard.append(d))
	view.flash_now()
	check.call(heard.size() == 1, "Clima: relâmpago manda o trovão")
	w.start(game.sim, {"to": "clouds", "warn": 0.0, "ramp": 0.1})
	# Até 3 s de jogo, em quadros de 1/60 s (não em milissegundos do relógio).
	var frames := 0
	while not view.rainbow_visible() and frames < 3 * 60:
		await host.get_tree().process_frame
		frames += 1
	check.call(view.rainbow_visible(), "Clima: arco-íris quando a tempestade passa")
	await _audio_view(host, check, game)
	game.queue_free()
	await host.get_tree().process_frame
	check.call(AudioManager.muffle() == 0.0, "Som: sair da missão tira o abafamento")


func _audio_view(host: Node, check: Callable, game: Game) -> void:
	var w := game.sim.weather
	w.state = &"storm"
	w.previous = &"storm"
	w.blend = 1.0
	# Até 4 s de jogo, em quadros de 1/60 s.
	var frames := 0
	while AudioManager.ambience_level(WeatherAudio.STORM) < 0.3 and frames < 4 * 60:
		await host.get_tree().process_frame
		frames += 1
	check.call(AudioManager.ambience_level(WeatherAudio.STORM) >= 0.3, "Som: a chuva forte sobe na tempestade")
