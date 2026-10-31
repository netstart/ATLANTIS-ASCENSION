extends Node
## Capturas das telas para revisão visual (não é teste de aprovação). Sem --headless:
##   godot --path . res://tests/screens_runner.tscn -- --shots=<pasta> [--res=305x678,960x540] [--langs=pt_BR,ja]
## Grava <pasta>/<tela>_<resolução>_<idioma>.png com a janela em 2x da tela lógica (k = 2).
## Save e opções usam os arquivos dos testes.

const DeviceProfiles := preload("res://tests/device_profiles.gd")
const LayoutTests := preload("res://tests/layout_tests.gd")
const SCREENS: Array[StringName] = [&"boot", &"hub", &"map", &"results", &"credits"]


func _ready() -> void:
	SaveManager.use_test_files()
	Settings.use_test_file()
	var out := ""
	var wanted := PackedStringArray()
	var langs := PackedStringArray(["pt_BR", "ja"])
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			out = arg.trim_prefix("--shots=")
		elif arg.begins_with("--res="):
			wanted = arg.trim_prefix("--res=").split(",", false)
		elif arg.begins_with("--langs="):
			langs = arg.trim_prefix("--langs=").split(",", false)
	if out.is_empty():
		Log.error("screens_runner: falta -- --shots=<pasta>")
		get_tree().quit(1)
		return
	DirAccess.make_dir_recursive_absolute(out)
	for r: Dictionary in DeviceProfiles.RESOLUTIONS:
		if not wanted.is_empty() and not String(r["label"]) in wanted:
			continue
		var view: Vector2 = r["view"]
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(Vector2i(view) * 2)
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
					"credits": 125}
			for screen_name: StringName in SCREENS:
				app.go(screen_name)
				await LayoutTests.settle(self)
				for i: int in range(40):
					await get_tree().process_frame
				await RenderingServer.frame_post_draw
				var image := get_viewport().get_texture().get_image()
				image.save_png("%s/%s_%s_%s.png" % [out, screen_name, r["label"], lang])
			app.queue_free()
			await get_tree().process_frame
	get_tree().quit(0)
