extends Node
## Benchmark de rolagem (docs/policies/testes.md). Sem --headless e sem VSync:
##   godot --path . res://tests/scroll_bench.tscn -- [--strict] [--res=305x678,960x540] [--out=bench.json]
## Em cada resolução: mapa (arrasto lento e piparote com inércia, parallax inteiro), Créditos e
## Resultado (rolagem da lista). Só os quadros em movimento contam (FrameStats.motion_summary).
## Critério com --strict: p95 ≤ 6 ms, nenhum quadro > 33 ms e nenhuma travada, por lista.

const DeviceProfiles := preload("res://tests/device_profiles.gd")
const LayoutTests := preload("res://tests/layout_tests.gd")
const WARMUP := 30
const P95_MAX := 6.0
const WORST_MAX := 33.4

var _report: Array[Dictionary] = []
var _failed: bool = false


func _ready() -> void:
	SaveManager.use_test_files()
	Settings.use_test_file()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var wanted := PackedStringArray()
	var out := ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--res="):
			wanted = arg.trim_prefix("--res=").split(",", false)
		elif arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
	var strict := "--strict" in OS.get_cmdline_user_args()
	for r: Dictionary in DeviceProfiles.RESOLUTIONS:
		if not wanted.is_empty() and not String(r["label"]) in wanted:
			continue
		await _resolution(r)
	for row: Dictionary in _report:
		var ok := float(row["p95_ms"]) <= P95_MAX and float(row["max_ms"]) <= WORST_MAX and int(row["stalls"]) == 0
		if not ok:
			_failed = true
		print("%s %-8s %-9s %s %s" % ["ok   " if ok else "FALHOU", row["res"], row["list"],
				FrameStats.describe(row), "" if ok else "(limite p95 %.0f ms, pior %.0f ms)" % [P95_MAX, WORST_MAX]])
	if not out.is_empty():
		var f := FileAccess.open(out, FileAccess.WRITE)
		f.store_string(JSON.stringify(_report, "\t"))
	SpriteBank.clear()
	get_tree().quit(1 if strict and _failed else 0)


func _resolution(r: Dictionary) -> void:
	var view: Vector2 = r["view"]
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(view) * 2)
	await get_tree().create_timer(0.3).timeout
	get_tree().root.get_node(^"PixelScaler").call("_apply")
	var app := App.new()
	add_child(app)
	await get_tree().process_frame
	LayoutTests.fit(app, view)
	app.go(&"map")
	await _settle()
	var map := app.screen(&"map") as MapScreen
	var stats := FrameStats.new()
	# Arrasto lento para cima e para baixo.
	for i: int in range(WARMUP + 180):
		map.drag(-3.0 if i < 90 + WARMUP else 3.0, true)
		await get_tree().process_frame
		if i >= WARMUP:
			stats.tick_scroll(map.camera)
	map.drag(0.0, false)
	_add(r, "map_drag", stats)
	# Piparote: impulso curto e inércia até parar.
	stats = FrameStats.new()
	for i: int in range(4):
		map.drag(-30.0, true)
		await get_tree().process_frame
	map.drag(0.0, false)
	for i: int in range(150):
		await get_tree().process_frame
		stats.tick_scroll(map.camera)
	_add(r, "map_fling", stats)
	app.last_result = {"mission": "c1m1", "cleared": true, "score": 123456, "stars": [true, true, false, true],
			"kills": 90, "grazes": 40, "max_chain": 30, "medals": 8, "credits": 120}
	for screen_name: StringName in [&"credits", &"results"]:
		app.go(screen_name)
		await _settle()
		var scroll := app.screen(screen_name).find_children("*", "ScrollContainer", true, false)[0] as ScrollContainer
		stats = FrameStats.new()
		var bar := scroll.get_v_scroll_bar()
		var span := maxf(1.0, bar.max_value - bar.page)
		# Vai e vem linear: a lista anda em todo quadro (um pico senoidal arredondaria para a mesma posição
		# e contaria como travada sem ser).
		var step := maxf(2.0, span / 60.0)
		for i: int in range(WARMUP + 120):
			scroll.scroll_vertical = int(pingpong(i * step, span))
			await get_tree().process_frame
			if i >= WARMUP:
				stats.tick_scroll(scroll.scroll_vertical)
		_add(r, String(screen_name), stats)
	app.queue_free()
	await get_tree().process_frame


func _settle() -> void:
	for i: int in range(5):
		await get_tree().process_frame


func _add(r: Dictionary, list: String, stats: FrameStats) -> void:
	var s := stats.motion_summary()
	if int(s["frames"]) == 0:
		s = stats.summary()
		s["stalls"] = 0
	s["res"] = r["label"]
	s["list"] = list
	_report.append(s)
