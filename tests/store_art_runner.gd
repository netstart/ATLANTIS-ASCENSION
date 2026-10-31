extends Node
## Imagem de destaque da Google Play (1024x500) feita com as peças do próprio jogo: o fundo abissal dos
## menus, o logo da tela de título e a Halcyon no halo. Sem --headless (precisa renderizar):
##   godot --path . res://tests/store_art_runner.tscn -- --out=<pasta> [--lang=pt_BR]
## Grava <pasta>/feature_graphic_<idioma>.png. Chamado por tools/build_store_art.ps1.

const SIZE := Vector2i(1024, 500)
## Nave em pixel inteiro: 48 px x 8.
const SHIP_SCALE := 8


func _ready() -> void:
	SaveManager.use_test_files()
	Settings.use_test_file()
	var out := ""
	var lang := "pt_BR"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
		elif arg.begins_with("--lang="):
			lang = arg.trim_prefix("--lang=")
	if out.is_empty():
		Log.error("store_art_runner: falta -- --out=<pasta>")
		get_tree().quit(1)
		return
	DirAccess.make_dir_recursive_absolute(out)
	Locale.set_language(lang, false)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(SIZE)
	await get_tree().create_timer(0.3).timeout
	# Arte na resolução física: sem a escala lógica do PixelScaler (texto e pixel art nítidos).
	get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var art := _compose()
	add_child(art)
	# O fundo é um shader animado: deixa a água andar um pouco para sair do primeiro quadro.
	await get_tree().create_timer(1.2).timeout
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	if image.get_size() != SIZE:
		Log.warn("store_art_runner: janela %s, ajustando para %s" % [image.get_size(), SIZE])
		image.resize(SIZE.x, SIZE.y, Image.INTERPOLATE_LANCZOS)
	image.convert(Image.FORMAT_RGB8)  # a Play recusa PNG com transparência na imagem de destaque
	image.save_png("%s/feature_graphic_%s.png" % [out, lang])
	get_tree().quit(0)


func _compose() -> Control:
	var art := Control.new()
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	var backdrop := AbyssBackdrop.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	art.add_child(backdrop)
	backdrop.set_mood(&"title")
	# Halcyon à direita, grande, num halo ciano; o motor no primeiro quadro da tira.
	var halo := TextureRect.new()
	halo.texture = SpriteBank.generated("fx/glow_32")
	halo.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	halo.modulate = Color(UiTheme.CYAN, 0.42)
	halo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	halo.stretch_mode = TextureRect.STRETCH_SCALE
	halo.position = Vector2(560, -10)
	halo.size = Vector2(500, 500)
	art.add_child(halo)
	var engine_strip := load(BootScreen.ENGINE_PATH) as Texture2D
	var engine_atlas := AtlasTexture.new()
	engine_atlas.atlas = engine_strip
	engine_atlas.region = SpriteBank.frame_rect(0, 48)
	for tex: Texture2D in [engine_atlas, load(BootScreen.SHIP_PATH) as Texture2D]:
		var ship := TextureRect.new()
		ship.texture = tex
		ship.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ship.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ship.stretch_mode = TextureRect.STRETCH_SCALE
		ship.size = Vector2(48, 48) * SHIP_SCALE
		ship.position = Vector2(618, 40)
		art.add_child(ship)
	# Logo à esquerda, como na tela de título (mesma fonte com espaço entre letras e o mesmo brilho).
	var column := VBoxContainer.new()
	column.position = Vector2(60, 0)
	column.size = Vector2(560, SIZE.y)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 2)
	art.add_child(column)
	var logo := UiTheme.heading("ATLANTIS", 92, UiTheme.WHITE)
	logo.add_theme_font_override("font", BootScreen._tracked(BootScreen.LOGO_SPACING * 2))
	logo.add_theme_color_override("font_shadow_color", Color(UiTheme.CYAN, 0.55))
	logo.add_theme_constant_override("shadow_outline_size", 28)
	column.add_child(logo)
	var sub := UiTheme.heading("ASCENSION", 40, UiTheme.GOLD)
	sub.add_theme_font_override("font", BootScreen._tracked(22))
	column.add_child(sub)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 18)
	column.add_child(gap)
	var tagline := UiTheme.label(tr("boot.tagline"), 26, UiTheme.TEXT, true)
	tagline.custom_minimum_size = Vector2(520, 0)
	column.add_child(tagline)
	return art
