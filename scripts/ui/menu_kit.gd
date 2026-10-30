class_name MenuKit
extends RefCounted
## Utilidades das telas: área segura (recorte da câmera), avisos de troca e de qualidade gráfica.
##
## Margens em pontos lógicos como Vector4(esquerda, cima, direita, baixo). Em retrato o furo da
## câmera fica em cima, e embaixo com o aparelho girado 180°. O modo imersivo esconde a barra de
## navegação, então só o recorte conta.
##
## Origem: parte de área segura do menu_kit.gd do projeto hyakki (mesmo autor, MIT), generalizada
## para os quatro lados.

## Só para testes: área segura simulada (pontos lógicos). Troque por set_test_insets.
static var test_insets := Vector4.ZERO
static var test_insets_enabled := false


## Área segura do Android em pontos lógicos (esquerda, cima, direita, baixo). Zero no desktop (ou
## test_insets, quando os testes simulam o recorte).
static func safe_margins(node: Node) -> Vector4:
	if test_insets_enabled:
		return test_insets
	if not OS.has_feature("mobile") or node == null or not node.is_inside_tree():
		return Vector4.ZERO
	var safe := Rect2(DisplayServer.get_display_safe_area())
	var screen := Vector2(DisplayServer.screen_get_size())
	var scale := node.get_viewport().get_final_transform().x.x
	if safe.size.x <= 0.0 or scale <= 0.0:
		return Vector4.ZERO
	return Vector4(maxf(safe.position.x, 0.0), maxf(safe.position.y, 0.0),
			maxf(screen.x - safe.end.x, 0.0), maxf(screen.y - safe.end.y, 0.0)) / scale


## Retângulo seguro dentro de uma tela lógica.
static func safe_rect(view: Vector2, margins: Vector4) -> Rect2:
	return Rect2(margins.x, margins.y, view.x - margins.x - margins.z, view.y - margins.y - margins.w)


## Só para testes: liga (ou desliga, com Vector4.ZERO) o recorte simulado e avisa na hora quem
## escuta on_insets_change, como o giro de 180° do celular.
static func set_test_insets(insets: Vector4) -> void:
	test_insets = insets
	test_insets_enabled = insets != Vector4.ZERO
	var scaler := _pixel_scaler(null)
	if scaler != null:
		scaler.call("check_safe_insets")


## Liga `on_change` à troca da área segura; desliga sozinho quando o nó sai da árvore.
static func on_insets_change(node: Node, on_change: Callable) -> void:
	var scaler := _pixel_scaler(node)
	if scaler == null:
		return
	var handler := func() -> void:
		if is_instance_valid(node) and node.is_inside_tree():
			on_change.call()
	var link := func() -> void:
		if is_instance_valid(scaler) and not scaler.is_connected("safe_insets_changed", handler):
			scaler.connect("safe_insets_changed", handler)
	var unlink := func() -> void:
		if is_instance_valid(scaler) and scaler.is_connected("safe_insets_changed", handler):
			scaler.disconnect("safe_insets_changed", handler)
	if node.is_inside_tree():
		link.call()
	node.tree_entered.connect(link)
	node.tree_exiting.connect(unlink)


static func _pixel_scaler(node: Node) -> Node:
	if node != null and node.is_inside_tree():
		return node.get_tree().root.get_node_or_null(^"PixelScaler")
	var loop := Engine.get_main_loop() as SceneTree
	return loop.root.get_node_or_null(^"PixelScaler") if loop != null else null


## Liga `on_change` à troca de qualidade gráfica (ao vivo); desliga sozinho com o nó.
static func on_quality_change(node: Node, on_change: Callable) -> void:
	var loop := Engine.get_main_loop() as SceneTree
	var settings := loop.root.get_node_or_null(^"Settings") if loop != null else null
	if settings == null:
		return
	var handler := func(key: String) -> void:
		if key == GfxQuality.changed_signal_key() and is_instance_valid(node):
			on_change.call()
	settings.connect("changed", handler)
	node.tree_exiting.connect(func() -> void:
		if settings.is_connected("changed", handler):
			settings.disconnect("changed", handler), CONNECT_ONE_SHOT)
