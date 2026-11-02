extends Control
## Galeria da transmissão dos retratos (Portraits + shaders/portrait_fx.gdshader) para revisão visual (não é
## teste de aprovação). Sem --headless:
##   godot --path . res://tests/portrait_shots_runner.tscn -- --shots=<pasta> [--zoom=3]
## Grava <pasta>/portrait_fx_stable.png (os 5 personagens nas 3 expressões, a 96 pt como na história e a 32 pt
## como na HUD), portrait_fx_tune.png (o mesmo no meio da sintonia de 0,35 s) e portrait_fx_still.png (com
## "reduzir movimento": só as linhas paradas).

const SPEAKERS: Array[String] = ["mare", "farol", "duarte", "thalassa", "protocol"]
const BIG := 96.0
const SMALL := 32.0
const GAP := 8.0

var _rects: Array[TextureRect] = []


func _ready() -> void:
	SaveManager.use_test_files()
	Settings.use_test_file()
	var out := ""
	var zoom := 3
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			out = arg.trim_prefix("--shots=")
		elif arg.begins_with("--zoom="):
			zoom = int(arg.trim_prefix("--zoom="))
	if out.is_empty():
		Log.error("portrait_shots_runner: falta -- --shots=<pasta>")
		get_tree().quit(1)
		return
	DirAccess.make_dir_recursive_absolute(out)
	var cell := BIG + GAP + SMALL + GAP
	var view := Vector2(GAP + cell * Portraits.MOODS.size(), GAP + (BIG + GAP) * SPEAKERS.size())
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(view) * zoom)
	get_tree().root.content_scale_size = Vector2i(view)
	get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	await get_tree().create_timer(0.3).timeout
	var bg := ColorRect.new()
	bg.color = UiTheme.ABYSS
	bg.size = view
	add_child(bg)
	for row: int in SPEAKERS.size():
		for col: int in Portraits.MOODS.size():
			var origin := Vector2(GAP + col * cell, GAP + row * (BIG + GAP))
			for side: float in [BIG, SMALL]:
				var r := Portraits.make_rect(side)
				r.position = origin + (Vector2(BIG + GAP, 0.0) if side == SMALL else Vector2.ZERO)
				r.texture = Portraits.texture(SPEAKERS[row], Portraits.MOODS[col])
				add_child(r)
				Portraits.apply_fx(r, SPEAKERS[row])
				_rects.append(r)
	await _wait(1.0)
	await _save(out + "/portrait_fx_stable.png")
	for r: TextureRect in _rects:
		Portraits.tune_in(r)
	await _wait(0.14)
	await _save(out + "/portrait_fx_tune.png")
	Settings.set_value("reduce_motion", true)
	for i: int in _rects.size():
		Portraits.apply_fx(_rects[i], SPEAKERS[floori(i / float(Portraits.MOODS.size() * 2))])
	await _wait(0.5)
	await _save(out + "/portrait_fx_still.png")
	Settings.set_value("reduce_motion", false)
	get_tree().quit(0)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _save(path: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
