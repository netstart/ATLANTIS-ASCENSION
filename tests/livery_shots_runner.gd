extends Node2D
## Folha de revisão da evolução do hangar (ShipLivery) e das avarias (ShipArt): as 15 aeronaves (linhas) nos
## níveis 1 a 10 (colunas), e mais quatro colunas: o nível 10 subindo (pós-combustão e jatos), atirando, com
## pintura e a avaria a 1/3, sobre a cor do mar. Sem --headless:
##   godot --path . res://tests/livery_shots_runner.tscn -- --shots=<pasta> [--zoom=2] [--ships=falcon,manta]
## Grava <pasta>/livery_sheet.png (1 unidade lógica = `zoom` pixels), desenhada numa SubViewport do tamanho da
## folha; a janela mostra a folha reduzida para caber no monitor (o PNG não muda).

const CELL := 72.0
## Colunas extras: [nível, subindo, avaria, pintura, atirando].
const EXTRA: Array = [[10, true, 0, false, false], [10, false, 0, false, true], [10, false, 0, true, false],
		[10, false, 2, false, false]]

var _ships: Array[StringName] = []
var _zoom: float = 2.0


func _ready() -> void:
	var shots := "user://livery_shots"
	var only := PackedStringArray()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			shots = arg.get_slice("=", 1)
		elif arg.begins_with("--zoom="):
			_zoom = float(arg.get_slice("=", 1))
		elif arg.begins_with("--ships="):
			only = arg.get_slice("=", 1).split(",", false)
	for row: Variant in DB.rows("ships"):
		var id := String((row as Dictionary)["id"])
		if only.is_empty() or id in only:
			_ships.append(StringName(id))
	var cols := Economy.SHIP_MAX_LEVEL + EXTRA.size()
	var size := Vector2i(Vector2(cols, _ships.size()) * CELL * _zoom)
	var port := SubViewport.new()
	port.size = size
	port.transparent_bg = false
	port.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(port)
	var sheet := _Sheet.new()
	sheet.ships = _ships
	sheet.zoom = _zoom
	sheet.cols = cols
	port.add_child(sheet)
	var screen := DisplayServer.screen_get_usable_rect()
	var fit := minf(1.0, minf(float(screen.size.x) / size.x, float(screen.size.y) / size.y) * 0.95)
	get_window().size = Vector2i(Vector2(size) * fit)
	var view := Sprite2D.new()
	view.texture = port.get_texture()
	view.centered = false
	view.scale = Vector2(fit, fit)
	view.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(view)
	for i: int in range(4):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(shots)
	var path := shots.path_join("livery_sheet.png")
	port.get_texture().get_image().save_png(path)
	print("gravada: ", path)
	SpriteBank.clear()
	get_tree().quit()


class _Sheet:
	extends Node2D

	var ships: Array[StringName] = []
	var zoom: float = 2.0
	var cols: int = 10

	func _ready() -> void:
		texture_filter = SpriteBank.HD_FILTER
		material = ShipArt.material()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, Vector2(cols, ships.size()) * CELL * zoom), Color8(10, 42, 58))
		for r: int in range(ships.size()):
			for c: int in range(cols):
				# [nível, subindo, avaria, pintura, atirando]
				var spec: Array = [c + 1, false, 0, false, false]
				if c >= Economy.SHIP_MAX_LEVEL:
					spec = EXTRA[c - Economy.SHIP_MAX_LEVEL]
				var at := (Vector2(c, r) + Vector2(0.5, 0.42)) * CELL * zoom
				draw_set_transform(at, 0.0, Vector2(zoom, zoom))
				ShipArt.draw(self, SpriteBank.player(ships[r]), 0.6, int(spec[0]), 1.0, bool(spec[1]),
						Color(1.0, 0.45, 0.55) if bool(spec[3]) else Color(0, 0, 0, 0), true, int(spec[2]), 1.0,
						bool(spec[4]))
		draw_set_transform(Vector2.ZERO)
