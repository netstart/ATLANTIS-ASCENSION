extends Node
## Capturas da Oficina (HangarScreen) para revisão visual, uma por sub-aba e por estado do jogador, e
## atalho para rodar só os testes dela. Sem --headless para as capturas:
##   godot --path . res://tests/hangar_shots_runner.tscn -- --shots=<pasta> [--res=270x480,960x540]
##   [--langs=pt_BR,de] [--profiles=start,mid,max] [--zoom=2]
##   godot --headless --path . res://tests/hangar_shots_runner.tscn -- --test
## Grava <pasta>/hangar_<perfil>_<sub-aba>_<resolução>_<idioma>.png; a sub-aba aparece com o primeiro
## ladrilho que tem ação aberto no cartão de detalhe (a "nave" sem cartão, como o jogador a encontra).

const DeviceProfiles := preload("res://tests/device_profiles.gd")
const LayoutTests := preload("res://tests/layout_tests.gd")
const HangarTests := preload("res://tests/hangar_tests.gd")
## Ladrilho aberto em cada sub-aba nas capturas.
const OPEN := {&"weapons": "Item_missiles", &"wings": "Item_wing_rear", &"paints": "Item_tint_kelp",
		&"mode": "Item_abyssal"}

var _count: int = 0
var _failures: int = 0


func _ready() -> void:
	SaveManager.use_test_files()
	Settings.use_test_file()
	var args := OS.get_cmdline_user_args()
	if "--test" in args:
		await HangarTests.new().run_view(self, _check)
		print("%d verificações, %d falhas" % [_count, _failures])
		get_tree().quit(1 if _failures > 0 else 0)
		return
	var out := ""
	var wanted := PackedStringArray(["270x480", "360x800", "453x544", "960x540"])
	var langs := PackedStringArray(["pt_BR"])
	var profiles := PackedStringArray(["start", "mid", "max"])
	var zoom := 2
	for arg: String in args:
		if arg.begins_with("--shots="):
			out = arg.trim_prefix("--shots=")
		elif arg.begins_with("--res="):
			wanted = arg.trim_prefix("--res=").split(",", false)
		elif arg.begins_with("--langs="):
			langs = arg.trim_prefix("--langs=").split(",", false)
		elif arg.begins_with("--profiles="):
			profiles = arg.trim_prefix("--profiles=").split(",", false)
		elif arg.begins_with("--zoom="):
			zoom = int(arg.trim_prefix("--zoom="))
	if out.is_empty():
		Log.error("hangar_shots_runner: falta -- --shots=<pasta> ou --test")
		get_tree().quit(1)
		return
	DirAccess.make_dir_recursive_absolute(out)
	for r: Dictionary in DeviceProfiles.RESOLUTIONS:
		if not String(r["label"]) in wanted:
			continue
		var view: Vector2 = r["view"]
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(Vector2i(view) * zoom)
		await get_tree().create_timer(0.3).timeout
		get_tree().root.get_node(^"PixelScaler").call("_apply")
		await get_tree().process_frame
		for lang: String in langs:
			Locale.set_language(lang, false)
			for profile: String in profiles:
				_profile(profile)
				var app := App.new()
				add_child(app)
				await get_tree().process_frame
				app.go(&"hangar")
				var hangar := app.screen(&"hangar") as HangarScreen
				for tab: StringName in HangarScreen.TABS:
					(hangar.find_child("Tab_" + String(tab), true, false) as Button).pressed.emit()
					if OPEN.has(tab):
						var tile := hangar.find_child(String(OPEN[tab]), true, false) as Button
						if tile != null:
							tile.pressed.emit()
					for i: int in range(40):
						await get_tree().process_frame
					await RenderingServer.frame_post_draw
					get_viewport().get_texture().get_image().save_png("%s/hangar_%s_%s_%s_%s.png" % [out, profile, tab,
							r["label"], lang])
				app.queue_free()
				await get_tree().process_frame
	get_tree().quit(0)


## start: perfil novo com algum crédito; mid: HangarTests.mid_profile; max: tudo no máximo.
func _profile(kind: String) -> void:
	SaveManager.reset_profile()
	var p := SaveManager.data
	match kind:
		"start":
			p["wallet"]["credits"] = 420
		"mid":
			HangarTests.mid_profile(p)
		"max":
			HangarTests.mid_profile(p)
			p["hangar"]["ship_levels"]["falcon"] = Economy.SHIP_MAX_LEVEL
			p["hangar"]["modules"] = {"missiles": Economy.SECONDARY_MAX_LEVEL, "drones": 2}
			p["selected"]["cosmetic"] = "tint_coral"
			p["selected"]["difficulty"] = "abyssal"


func _check(condition: bool, label: String) -> void:
	_count += 1
	if not condition:
		_failures += 1
		printerr("FALHOU: " + label)
