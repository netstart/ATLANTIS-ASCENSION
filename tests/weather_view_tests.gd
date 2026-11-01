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
	check.call(front != null and front.size == Playfield.FIELD, "Clima: a frente cobre o campo inteiro")
	var shader := (front.material as ShaderMaterial).shader.code
	check.call(shader.contains("const float MAX_ALPHA = 0.35"), "Clima: frente com opacidade ≤ 35%")
	check.call(Rect2(Vector2.ZERO, Playfield.FIELD).has_point(WeatherView.VANE_AT), "Clima: biruta dentro do campo")
	for c: Dictionary in DeviceProfiles.layout_cases():
		var size: Vector2 = c["view"]
		game.relayout_for(size)
		var sky := view.get_child(0) as ColorRect
		check.call(sky.size == size, "Clima [%s]: céu cobre a tela" % c["label"])
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
	var deadline := Time.get_ticks_msec() + 3000
	while not view.rainbow_visible() and Time.get_ticks_msec() < deadline:
		await host.get_tree().process_frame
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
	var deadline := Time.get_ticks_msec() + 4000
	while AudioManager.ambience_level(WeatherAudio.STORM) < 0.3 and Time.get_ticks_msec() < deadline:
		await host.get_tree().process_frame
	check.call(AudioManager.ambience_level(WeatherAudio.STORM) >= 0.3, "Som: a chuva forte sobe na tempestade")
