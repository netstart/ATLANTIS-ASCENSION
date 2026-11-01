extends Node
## Capturas das telas para revisão visual (não é teste de aprovação). Sem --headless:
##   godot --path . res://tests/screens_runner.tscn -- --shots=<pasta> [--res=305x678,960x540] [--langs=pt_BR,ja]
##   [--screens=hub,map] [--zoom=4] [--showcase]
## Grava <pasta>/<tela>_<resolução>_<idioma>.png com a janela em 2x da tela lógica (k = 2, ou --zoom).
## Save e opções usam os arquivos dos testes. --showcase troca o perfil novo por um jogador no meio da
## campanha (capturas da ficha da loja, tools/build_store_art.ps1).

const DeviceProfiles := preload("res://tests/device_profiles.gd")
const LayoutTests := preload("res://tests/layout_tests.gd")
const SCREENS: Array[StringName] = [&"boot", &"hub", &"map", &"results", &"credits", &"story", &"hangar",
		&"ships", &"options", &"shop", &"events", &"logbook", &"records", &"season", &"city", &"practice"]


func _ready() -> void:
	SaveManager.use_test_files()
	Settings.use_test_file()
	var out := ""
	var wanted := PackedStringArray()
	var langs := PackedStringArray(["pt_BR", "ja"])
	var only := PackedStringArray()
	var zoom := 2
	var showcase := false
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			out = arg.trim_prefix("--shots=")
		elif arg.begins_with("--res="):
			wanted = arg.trim_prefix("--res=").split(",", false)
		elif arg.begins_with("--screens="):
			only = arg.trim_prefix("--screens=").split(",", false)
		elif arg == "--showcase":
			showcase = true
		elif arg.begins_with("--zoom="):
			zoom = int(arg.trim_prefix("--zoom="))
		elif arg.begins_with("--langs="):
			langs = arg.trim_prefix("--langs=").split(",", false)
	if out.is_empty():
		Log.error("screens_runner: falta -- --shots=<pasta>")
		get_tree().quit(1)
		return
	DirAccess.make_dir_recursive_absolute(out)
	if showcase:
		_fill_showcase(SaveManager.data)
	for r: Dictionary in DeviceProfiles.RESOLUTIONS:
		if not wanted.is_empty() and not String(r["label"]) in wanted:
			continue
		var view: Vector2 = r["view"]
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(Vector2i(view) * zoom)
		await get_tree().create_timer(0.3).timeout
		get_tree().root.get_node(^"PixelScaler").call("_apply")
		await get_tree().process_frame
		var got := Vector2(get_tree().root.content_scale_size)
		if got != view:
			Log.warn("screens_runner: %s pedido, %s obtido (a janela não coube no monitor)" % [view, got])
		for lang: String in langs:
			Locale.set_language(lang, false)
			var app := App.new()
			add_child(app)
			await get_tree().process_frame
			app.last_result = {"mission": "c1m1", "cleared": true, "score": 123456, "record": true,
					"stars": [true, true, false, true], "kills": 92, "grazes": 41, "max_chain": 33, "medals": 8,
					"credits": 125, "grade": Grade.A, "grade_new": true, "chest": TideChest.roll("c1m1", 3, 9, Grade.A)}
			for screen_name: StringName in SCREENS:
				if not only.is_empty() and not String(screen_name) in only:
					continue
				app.go(screen_name)
				if screen_name == &"story":
					# Prólogo no 3º quadro: o primeiro com retrato (o narrador não tem rosto).
					var story := app.find_child("Story", true, false)
					for k: int in range(2):
						story.call("advance")
				await LayoutTests.settle(self)
				if screen_name == &"results":
					# Captura o estado final da revelação (nota carimbada, arca aberta).
					app.screen(&"results").call("_finish_reveal")
				for i: int in range(40):
					await get_tree().process_frame
				await RenderingServer.frame_post_draw
				var image := get_viewport().get_texture().get_image()
				image.save_png("%s/%s_%s_%s.png" % [out, screen_name, r["label"], lang])
			app.queue_free()
			await get_tree().process_frame
	get_tree().quit(0)


## Jogador no meio da campanha: capítulos 1 e 2 concluídos, três aeronaves, Docas e Jardins reerguidos.
func _fill_showcase(p: Dictionary) -> void:
	var cleared := ["c1m1", "c1m2", "c1m3", "c2m1", "c2m2", "c2m3", "c3m1"]
	for i: int in cleared.size():
		p["missions"][cleared[i]] = {"stars": [true, i % 3 != 1, i % 2 == 0, i < 4], "best_score": 48_000 + i * 21_350,
				"cleared": true, "route": ""}
	p["wallet"] = {"credits": 4_820, "orichalcum": 36, "pearls": 120}
	p["unlocked"]["ships"] = ["falcon", "manta", "hydra"]
	p["unlocked"]["wings"] = ["wing_magnet", "wing_bubble"]
	p["hangar"]["ship_levels"] = {"falcon": 6, "manta": 3, "hydra": 1}
	p["hangar"]["fragments"] = {"tempest": 14}
	p["rescued_total"] = 74
	p["story"]["prologue_seen"] = true
	p["tutorial_done"] = true
	p["stats"]["missions_cleared"] = cleared.size()
