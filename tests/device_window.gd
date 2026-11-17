extends RefCounted
## Janela dos runners com janela (AGENTS.md, "Como trabalhar", regra 7): o runner passa a viver num
## SubViewport do tamanho físico pedido, com a tela lógica do PixelScaler (stretch como o canvas_items
## da raiz), e a janela mostra esse quadro reduzido, na maior escala que cabe na área útil do monitor,
## centralizada. Layout, pixels e capturas (get_viewport().get_texture() do runner) ficam iguais aos
## de uma janela física do aparelho. Em headless nada muda (redimensiona a raiz como antes).

const Scaler := preload("res://scripts/autoload/pixel_scaler.gd")
const NAME := &"DeviceView"
## Ajustes de desenho da raiz (vindos do project.godot) que o SubViewport precisa repetir.
const COPY: Array[StringName] = [&"canvas_item_default_texture_filter", &"canvas_item_default_texture_repeat",
		&"snap_2d_transforms_to_pixel", &"snap_2d_vertices_to_pixel", &"gui_snap_controls_to_pixels", &"msaa_2d",
		&"msaa_3d", &"screen_space_aa", &"use_taa", &"use_debanding", &"use_occlusion_culling", &"use_hdr_2d",
		&"mesh_lod_threshold", &"scaling_3d_mode", &"scaling_3d_scale", &"texture_mipmap_bias",
		&"anisotropic_filtering_level", &"positional_shadow_atlas_size", &"positional_shadow_atlas_16_bits",
		&"sdf_oversize", &"sdf_scale"]


## Põe `node` (o runner) num quadro de `physical` pixels com a tela lógica `logical` (padrão: a do
## PixelScaler para esse físico) e ajusta a janela. Pode ser chamada de novo para trocar de aparelho.
## Devolve a tela lógica em uso.
static func fit(node: Node, physical: Vector2i, logical := Vector2i.ZERO) -> Vector2i:
	var tree := node.get_tree()
	var root := tree.root
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	if DisplayServer.get_name() == "headless":
		DisplayServer.window_set_size(physical)
		await tree.create_timer(0.3).timeout
		root.get_node(^"PixelScaler").call("_apply")
		return root.content_scale_size
	if logical == Vector2i.ZERO:
		logical = Scaler.logical_for(physical)
	var k := maxi(1, physical.x / logical.x)
	var view := node.get_viewport() as SubViewport
	if view == null or view.name != NAME:
		# No _ready do runner a raiz ainda monta os filhos e recusa add_child.
		await tree.process_frame
		view = _make_view(root)
		node.reparent(view, false)
	# shortcut: estica sem a tarja do aspect KEEP da raiz; igual só quando físico = k x lógico (todas as
	# resoluções e zooms dos runners hoje). Se um dia não for, calcular a tarja aqui.
	view.size = physical
	view.size_2d_override = logical
	view.size_2d_override_stretch = true
	# Janela: maior escala (até 1:1) que cabe na área útil com a moldura; largura múltipla de k para a raiz
	# manter físico/lógico = k (StoreBanner.physical_scale lê a raiz).
	var usable := DisplayServer.screen_get_usable_rect()
	var deco := DisplayServer.window_get_size_with_decorations() - DisplayServer.window_get_size()
	var room := usable.size - deco
	var s := minf(1.0, minf(float(room.x) / physical.x, float(room.y) / physical.y))
	var w := maxi(k, floori(physical.x * s / k) * k)
	var size := Vector2i(w, floori(float(w) * physical.y / physical.x))
	DisplayServer.window_set_size(size)
	# A posição é a da área cliente: desconta a borda esquerda e a barra de título.
	DisplayServer.window_set_position(usable.position + (usable.size - size - deco) / 2
			+ Vector2i(deco.x / 2, deco.y - deco.x / 2))
	await tree.create_timer(0.3).timeout
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = root.size / k
	root.get_node(^"PixelScaler").set("scale_factor", Scaler.factor_for(physical))
	print("device_window: aparelho %s (lógico %s), janela %s" % [physical, logical, root.size])
	await tree.process_frame
	return logical


static func _make_view(root: Window) -> SubViewport:
	# A raiz só mostra o quadro: o PixelScaler não deve reescalá-la quando a janela muda.
	var scaler := root.get_node(^"PixelScaler")
	var on_size := Callable(scaler, &"_on_size_changed")
	if root.size_changed.is_connected(on_size):
		root.size_changed.disconnect(on_size)
	var view := SubViewport.new()
	view.name = NAME
	for prop: StringName in COPY:
		view.set(prop, root.get(prop))
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var screen := TextureRect.new()
	screen.texture = view.get_texture()
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	screen.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	screen.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(screen)
	return view
