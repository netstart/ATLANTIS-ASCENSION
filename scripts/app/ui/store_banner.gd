class_name StoreBanner
extends PanelContainer
## Cartão-destaque das telas de comando (1.15: Loja; peças reaproveitadas pelos banners de modo dos
## Eventos): fundo em degradê na cor do destaque, raios bem sutis atrás do retrato, a faixa do título em
## chevron, o retrato pixel art de um personagem (Portraits) ampliado em escala inteira de pixel físico
## com filtro nearest à esquerda, o texto da oferta à direita (`body`) e as ações em largura inteira
## (`actions`). Nada pisca nem gira: o destaque é a cor e o tamanho.

## Fração máxima da largura interna que o retrato ocupa, e o teto em pontos lógicos.
const PORTRAIT_SHARE := 0.42
const PORTRAIT_MAX := 128.0
const PORTRAIT_SOURCE := 64
## Largura interna a partir da qual as ações vão para o lado do retrato.
const WIDE := 400.0

var accent := UiTheme.GOLD
var body: VBoxContainer
var actions: VBoxContainer
var _strip: Strip
var _frame: PanelContainer
var _portrait: TextureRect
var _side: float = -1.0


func _init(p_accent: Color, title: String, speaker: String, mood: String = "smile") -> void:
	accent = p_accent
	name = "Banner"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var back := Backdrop.new()
	back.accent = accent
	back.rays = true
	add_child(back)
	var pad := MarginContainer.new()
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: String in ["left", "right"]:
		pad.add_theme_constant_override("margin_" + side, 12)
	pad.add_theme_constant_override("margin_top", 10)
	pad.add_theme_constant_override("margin_bottom", 12)
	add_child(pad)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.add_child(col)
	_strip = Strip.new()
	_strip.accent = accent
	_strip.set_text(title)
	col.add_child(_strip)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(row)
	_frame = PanelContainer.new()
	var frame := UiTheme.chamfer(Color(UiTheme.ABYSS, 0.55), Color(accent, 0.85), 1, 6)
	for side: String in ["left", "right", "top", "bottom"]:
		frame.set("content_margin_" + side, 3)
	frame.shadow_color = Color(accent, 0.25)
	frame.shadow_size = 6
	_frame.add_theme_stylebox_override("panel", frame)
	_frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait = Portraits.make_rect(PORTRAIT_SOURCE)
	_portrait.texture = Portraits.texture(speaker, mood)
	_frame.add_child(_portrait)
	row.add_child(_frame)
	body = VBoxContainer.new()
	body.name = "Body"
	body.add_theme_constant_override("separation", 5)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.alignment = BoxContainer.ALIGNMENT_CENTER
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(body)
	actions = VBoxContainer.new()
	actions.name = "Actions"
	actions.add_theme_constant_override("separation", 6)
	actions.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(actions)
	resized.connect(_fit)


func portrait() -> TextureRect:
	return _portrait


## Lado do retrato: o maior múltiplo de 64 pixels FÍSICOS que cabe na fatia da largura (nítido em
## qualquer escala do PixelScaler, também nas que não são inteiras em pontos lógicos).
## Largo (desktop): as ações sobem para a coluna do texto, ao lado do retrato, e o cartão fica baixo.
func _fit() -> void:
	var inner := size.x - 24.0
	var wide := inner >= WIDE
	var home: Container = body if wide else _strip.get_parent() as Container
	if actions.get_parent() != home:
		actions.reparent(home, false)
	var target := minf(inner * PORTRAIT_SHARE, PORTRAIT_MAX)
	var side := pixel_side(target, physical_scale(self))
	if is_equal_approx(side, _side):
		return
	_side = side
	_portrait.custom_minimum_size = Vector2(side, side)


## Pixels físicos por ponto lógico (o stretch canvas_items do PixelScaler); 1 fora da árvore.
static func physical_scale(node: Node) -> float:
	if node == null or not node.is_inside_tree():
		return 1.0
	var root := node.get_tree().root
	return float(root.size.x) / float(root.content_scale_size.x) if root.content_scale_size.x > 0 else 1.0


## Maior lado em pontos lógicos, até `target`, que mostra o retrato de 64 px em escala inteira física.
static func pixel_side(target: float, scale: float) -> float:
	var n := maxi(1, floori(target * scale / float(PORTRAIT_SOURCE)))
	return float(PORTRAIT_SOURCE * n) / scale


## Fundo dos destaques: chanfro grande, degradê de cima (cor do destaque) para baixo (abismo), brilho
## diagonal, filete claro em cima e borda na cor. `rays`: leque de raios atrás do retrato; `emblem`:
## ícone grande à direita com halo (banners de modo); `dim` apaga tudo (modo fechado).
class Backdrop:
	extends Control

	var accent := UiTheme.GOLD
	var rays: bool = false
	var emblem: Texture2D = null
	var dim: bool = false

	func _init() -> void:
		name = "Backdrop"
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		clip_contents = true
		resized.connect(queue_redraw)

	func _draw() -> void:
		var rect := Rect2(Vector2.ONE, size - Vector2.ONE * 2.0)
		if rect.size.x <= 4.0 or rect.size.y <= 4.0:
			return
		var cut := minf(14.0, size.x * 0.08)
		var pts := CommandKit.chamfer_points(rect, cut)
		var strength := 0.16 if dim else 0.42
		var top := Color(UiTheme.DEEP_BLUE.lerp(accent, strength), 0.96)
		var low := Color(UiTheme.ABYSS, 0.95)
		var cols := PackedColorArray()
		for p: Vector2 in pts:
			cols.append(top.lerp(low, clampf(p.y / size.y, 0.0, 1.0) * 0.9))
		draw_polygon(pts, cols)
		if rays and not dim:
			_draw_rays(Vector2(size.x * 0.24, size.y * 0.55), minf(size.x, size.y) * 0.75)
		# Brilho diagonal (duas faixas finas) no lado direito.
		for i: int in range(2):
			var x := size.x * (0.62 + 0.1 * float(i))
			draw_colored_polygon(PackedVector2Array([Vector2(x, 0), Vector2(x + 18.0, 0),
					Vector2(x - size.y * 0.5 + 18.0, size.y), Vector2(x - size.y * 0.5, size.y)]),
					Color(1, 1, 1, 0.035 if not dim else 0.015))
		if emblem != null:
			_draw_emblem()
		var closed := pts.duplicate()
		closed.append(pts[0])
		draw_polyline(closed, Color(accent, 0.35 if dim else 0.9), 1.5, true)
		draw_line(Vector2(cut + 2.0, 2.0), Vector2(size.x * 0.6, 2.0), Color(1, 1, 1, 0.1 if dim else 0.35), 1.0, true)

	func _draw_rays(center: Vector2, radius: float) -> void:
		for i: int in range(12):
			var a := TAU * float(i) / 12.0
			var b := a + TAU / 32.0
			draw_colored_polygon(PackedVector2Array([center, center + Vector2(cos(a), sin(a)) * radius,
					center + Vector2(cos(b), sin(b)) * radius]), Color(accent, 0.07))
		for i: int in range(10):
			draw_circle(center, radius * 0.5 * (1.0 - float(i) * 0.09), Color(accent, 0.025), true, -1.0, true)

	func _draw_emblem() -> void:
		var side := minf(size.y * 0.62, 64.0)
		var center := Vector2(size.x - side * 0.5 - 14.0, size.y * 0.5)
		for i: int in range(10):
			draw_circle(center, side * 0.8 * (1.0 - float(i) * 0.08), Color(accent, 0.03 if not dim else 0.012),
					true, -1.0, true)
		draw_arc(center, side * 0.62, 0.0, TAU, 48, Color(accent, 0.45 if not dim else 0.15), 1.5, true)
		draw_texture_rect(emblem, Rect2(center - Vector2(side, side) * 0.32, Vector2(side, side) * 0.64), false,
				Color(accent.lightened(0.2), 0.95 if not dim else 0.3))


## Faixa do título em chevron cheio na cor do destaque, texto escuro em negrito (encolhe a fonte até
## caber; nunca alarga o cartão).
class Strip:
	extends Control

	const HEIGHT := 24.0
	const SIZE := 13

	var accent := UiTheme.GOLD
	var _label: Label

	func _init() -> void:
		name = "Strip"
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_label = UiTheme.heading("", SIZE, UiTheme.GOLD_DARK)
		_label.name = "StripText"
		_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
		_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_label.clip_text = true
		add_child(_label)
		resized.connect(_place)

	func set_text(text: String) -> void:
		_label.text = text.to_upper()
		_place()

	func text() -> String:
		return _label.text

	func _get_minimum_size() -> Vector2:
		var h := _label.get_theme_font("font").get_height(_label.get_theme_font_size("font_size")) \
				if _label != null and _label.get_theme_font("font") != null else 16.0
		return Vector2(48.0, maxf(HEIGHT, h + 6.0))

	func _place() -> void:
		var font := CommandKit.bold(_label)
		var room := maxf(10.0, size.x - 34.0)
		if font != null:
			_label.add_theme_font_size_override("font_size",
					CommandKit.fit_size(font, _label.text, room, UiTheme.scaled(SIZE), 8))
		_label.position = Vector2(12.0, 0.0)
		_label.size = Vector2(room, size.y)
		update_minimum_size()
		queue_redraw()

	func _draw() -> void:
		var h := size.y
		var w := minf(size.x, _label_width() + 34.0)
		var tip := h * 0.5
		var light := accent.lightened(0.25)
		draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w - tip, 0), Vector2(w, h * 0.5), Vector2(w - tip, h),
				Vector2(0, h), Vector2(tip * 0.5, h * 0.5)]),
				PackedColorArray([light, light, accent, accent.darkened(0.15), accent.darkened(0.15), accent]))
		draw_line(Vector2(w - tip + 4.0, 0), Vector2(w + 4.0, h * 0.5), Color(accent, 0.5), 2.0, true)
		draw_line(Vector2(w + 4.0, h * 0.5), Vector2(w - tip + 4.0, h), Color(accent, 0.5), 2.0, true)
		draw_line(Vector2(w, h - 0.5), Vector2(size.x, h - 0.5), Color(accent, 0.35), 1.0, true)

	func _label_width() -> float:
		var font := _label.get_theme_font("font")
		return font.get_string_size(_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1,
				_label.get_theme_font_size("font_size")).x if font != null else 60.0
