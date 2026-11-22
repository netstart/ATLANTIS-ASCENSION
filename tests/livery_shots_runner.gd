extends Node2D
## Folha de revisão da evolução do hangar (ShipLivery) e das avarias (ShipArt): as 12 aeronaves (colunas) nos
## níveis 1, 4, 7 e 10, com e sem pós-combustão, e a avaria a 2/3 e 1/3, sobre a cor do mar. Sem --headless:
##   godot --path . res://tests/livery_shots_runner.tscn -- --shots=<pasta> [--zoom=2]
## Grava <pasta>/livery_sheet.png (1 unidade lógica = `zoom` pixels). A janela cabe no monitor (só a leitura muda).

const CELL := 72.0
## Linhas: [nível, subindo, avaria, pintura].
const ROWS: Array = [[1, false, 0, false], [4, true, 0, false], [7, true, 0, false], [10, true, 0, false],
		[10, false, 0, true], [3, false, 1, false], [3, false, 2, false]]

var _ships: Array[StringName] = []
var _zoom: float = 2.0
var _time: float = 0.6


func _ready() -> void:
	var shots := "user://livery_shots"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			shots = arg.get_slice("=", 1)
		elif arg.begins_with("--zoom="):
			_zoom = float(arg.get_slice("=", 1))
	for row: Variant in DB.rows("ships"):
		_ships.append(StringName(String((row as Dictionary)["id"])))
	var size := Vector2i(Vector2(_ships.size(), ROWS.size()) * CELL * _zoom)
	get_viewport().size = size
	var screen := DisplayServer.screen_get_usable_rect()
	var fit := minf(1.0, minf(float(screen.size.x) / size.x, float(screen.size.y) / size.y) * 0.95)
	get_window().size = Vector2i(Vector2(size) * fit)
	get_window().content_scale_size = size
	texture_filter = SpriteBank.HD_FILTER
	material = ShipArt.material()
	for i: int in range(4):
		await get_tree().process_frame
	queue_redraw()
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(shots)
	var path := shots.path_join("livery_sheet.png")
	get_viewport().get_texture().get_image().save_png(path)
	print("gravada: ", path)
	SpriteBank.clear()
	get_tree().quit()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(_ships.size(), ROWS.size()) * CELL * _zoom), Color8(10, 42, 58))
	for r: int in range(ROWS.size()):
		var spec: Array = ROWS[r]
		for c: int in range(_ships.size()):
			var at := (Vector2(c, r) + Vector2(0.5, 0.45)) * CELL * _zoom
			draw_set_transform(at, 0.0, Vector2(_zoom, _zoom))
			ShipArt.draw(self, SpriteBank.player(_ships[c]), _time, int(spec[0]), 1.0, bool(spec[1]),
					Color(1.0, 0.45, 0.55) if bool(spec[3]) else Color(0, 0, 0, 0), true, int(spec[2]))
	draw_set_transform(Vector2.ZERO)
