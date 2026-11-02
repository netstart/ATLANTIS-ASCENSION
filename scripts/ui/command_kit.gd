class_name CommandKit
extends RefCounted
## Kit visual dos menus de comando (1.15, inspirado na estrutura dos shmups mobile: tudo emoldurado,
## cor forte, hierarquia clara). Peças desenhadas em código, sem textura de terceiros: nítidas na
## resolução física de 270 a 1920 de largura e com o texto do tamanho da opção de acessibilidade
## (UiTheme.scaled). Usado pela casca de navegação (NavShell) e pelas telas da fase 2.
##
## - notice_dot(parent): bolinha coral com "!" no canto de cima à direita de `parent` (pulsa devagar).
## - ribbon(text): faixa de seção em chevron, ciano que se apaga para a direita.
## - item_tile(texture, level, rarity, notice): ladrilho de item com moldura da raridade (comum ciano,
##   rara azul, épica violeta, lendária ouro), nível no canto de baixo à esquerda e aviso em cima à
##   direita; estados `selected` e `locked`.
## - stat_chip(icon, label, value): pílula "Dano 1.240".
## - slot(texture): encaixe de equipamento (vazio: colmeia sutil e "+").
## - power_badge(value, recommended): Poder com raio; menta quando alcança o recomendado, coral quando não.
## Movimento respeita "reduzir movimento" (UiFx.reduced).

const COMMON := 0
const RARE := 1
const EPIC := 2
const LEGENDARY := 3
const RARITY_COLORS: Array[Color] = [Color("2ff3e0"), Color("4d8dff"), Color("b57bff"), Color("ffc94a")]
## Lado padrão dos ladrilhos e encaixes (pontos lógicos).
const TILE := 56.0
const RIBBON_HEIGHT := 26.0


static func rarity_color(rarity: int) -> Color:
	return RARITY_COLORS[clampi(rarity, COMMON, LEGENDARY)]


## Bolinha de aviso no canto de cima à direita de `parent` (acompanha o tamanho dele). Some com `visible`.
static func notice_dot(parent: Control) -> NoticeDot:
	var dot := NoticeDot.new()
	var side := float(UiTheme.scaled(12))
	dot.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	dot.offset_left = -side * 0.8
	dot.offset_right = side * 0.2
	dot.offset_top = -side * 0.2
	dot.offset_bottom = side * 0.8
	parent.add_child(dot)
	return dot


static func ribbon(text: String) -> Ribbon:
	var r := Ribbon.new()
	r.set_text(text)
	return r


static func item_tile(texture: Texture2D, level: int = 0, rarity: int = COMMON, notice: bool = false) -> ItemTile:
	var tile := ItemTile.new()
	tile.texture = texture
	tile.level = level
	tile.rarity = rarity
	tile.notice = notice
	return tile


## Pílula de atributo: ícone (ListScreen.icon), nome apagado e valor em negrito na cor.
static func stat_chip(icon_kind: StringName, label: String, value: String,
		color: Color = UiTheme.CYAN) -> PanelContainer:
	var pill := PanelContainer.new()
	var box := UiTheme.pill_box(color)
	box.bg_color = Color(UiTheme.ABYSS, 0.78)
	box.content_margin_left = 6
	box.content_margin_right = 8
	pill.add_theme_stylebox_override("panel", box)
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if icon_kind != &"":
		row.add_child(glyph(icon_kind, color, 11))
	var name := UiTheme.label(label, UiTheme.SMALL_SIZE, UiTheme.TEXT_DIM)
	name.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(name)
	var number := UiTheme.label(value, UiTheme.FONT_SIZE, UiTheme.WHITE)
	_bold(number)
	number.name = "Value"
	row.add_child(number)
	pill.add_child(row)
	return pill


static func slot(texture: Texture2D = null) -> Slot:
	var s := Slot.new()
	s.texture = texture
	return s


## Selo do Poder: raio, rótulo "PODER" e o número; com `recommended` ≥ 0, menta se alcança e coral
## se não, mais a linha "Recomendado 2.400".
static func power_badge(value: int, recommended: int = -1) -> PanelContainer:
	var ok := recommended < 0 or value >= recommended
	var color := UiTheme.GOLD if recommended < 0 else (UiTheme.MINT if ok else UiTheme.CORAL)
	var panel := PanelContainer.new()
	panel.name = "PowerBadge"
	var box := UiTheme.chamfer(Color(UiTheme.ABYSS, 0.82), Color(color, 0.6), 1, UiTheme.CUT)
	box.content_margin_top = 4
	box.content_margin_bottom = 4
	box.content_margin_left = 8
	box.content_margin_right = 10
	panel.add_theme_stylebox_override("panel", box)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bolt := glyph(&"bolt", color, 18)
	bolt.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(bolt)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var title := UiTheme.label(TranslationServer.translate("command.power").to_upper(), 9, UiTheme.TEXT_DIM)
	col.add_child(title)
	var number := UiTheme.label(Locale.format_number(value), 16, color)
	number.name = "Value"
	_bold(number)
	col.add_child(number)
	if recommended >= 0:
		var rec := UiTheme.label(TranslationServer.translate("command.recommended") % Locale.format_number(recommended),
				9, UiTheme.TEXT_DIM)
		rec.name = "Recommended"
		col.add_child(rec)
	row.add_child(col)
	panel.add_child(row)
	return panel


## Ícone desenhado (ListScreen.icon) num quadrado de `size` pontos, tingido de `color`.
static func glyph(kind: StringName, color: Color = UiTheme.WHITE, size: int = 12) -> TextureRect:
	var t := TextureRect.new()
	t.texture = ListScreen.icon(kind)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var side := float(UiTheme.scaled(size))
	t.custom_minimum_size = Vector2(side, side)
	t.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	t.self_modulate = color
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


## Maior tamanho de fonte (de `size` até `min_size`) em que `text` cabe em `width`.
static func fit_size(font: Font, text: String, width: float, size: int, min_size: int = 7) -> int:
	var s := size
	while s > min_size and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, s).x > width:
		s -= 1
	return s


## Fonte em negrito do idioma, ou a fonte do tema de `node`.
static func bold(node: Control) -> Font:
	var f := UiTheme.bold_font()
	return f if f != null else node.get_theme_font("font")


## Contorno chanfrado (cantos grandes em cima à esquerda e embaixo à direita) dentro de `rect`.
static func chamfer_points(rect: Rect2, cut: float, small: float = 2.0) -> PackedVector2Array:
	var a := rect.position
	var b := rect.end
	return PackedVector2Array([Vector2(a.x + cut, a.y), Vector2(b.x - small, a.y), Vector2(b.x, a.y + small),
			Vector2(b.x, b.y - cut), Vector2(b.x - cut, b.y), Vector2(a.x + small, b.y), Vector2(a.x, b.y - small),
			Vector2(a.x, a.y + cut)])


static func _bold(l: Label) -> void:
	var f := UiTheme.bold_font()
	if f != null:
		l.add_theme_font_override("font", f)


## Bolinha coral com "!" (aviso). Pulsa 1,0 → 1,15 a cada 1,6 s, parada em "reduzir movimento".
class NoticeDot:
	extends Control

	func _ready() -> void:
		name = "Notice"
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(func() -> void: pivot_offset = size * 0.5)
		pivot_offset = size * 0.5
		if UiFx.reduced():
			return
		var tween := create_tween().set_loops()
		tween.tween_property(self, "scale", Vector2.ONE * 1.15, 0.35).set_trans(Tween.TRANS_SINE)
		tween.tween_property(self, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_SINE)
		tween.tween_interval(0.8)

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5
		draw_circle(c, r, Color("7a0f22"), true, -1.0, true)
		draw_circle(c, r - 1.0, UiTheme.CORAL, true, -1.0, true)
		draw_circle(c + Vector2(-r * 0.25, -r * 0.3), r * 0.35, Color(1, 1, 1, 0.18), true, -1.0, true)
		var w := maxf(1.4, r * 0.28)
		draw_line(c + Vector2(0, -r * 0.5), c + Vector2(0, r * 0.12), UiTheme.WHITE, w, true)
		draw_circle(c + Vector2(0, r * 0.45), w * 0.55, UiTheme.WHITE, true, -1.0, true)


## Faixa de seção: chevron que começa ciano forte à esquerda (com um filete) e some para a direita,
## texto branco em negrito. Ocupa a largura que receber; a altura vem do texto.
class Ribbon:
	extends Control

	var _label: Label

	func _init() -> void:
		name = "Ribbon"
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_label = UiTheme.heading("", 13, UiTheme.WHITE)
		_label.name = "RibbonText"
		_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_label.add_theme_color_override("font_shadow_color", Color(UiTheme.ABYSS, 0.7))
		_label.add_theme_constant_override("shadow_outline_size", 4)
		add_child(_label)
		resized.connect(_place)

	func set_text(text: String) -> void:
		_label.text = text.to_upper()
		_place()

	func label() -> Label:
		return _label

	func _get_minimum_size() -> Vector2:
		var need := _label.get_minimum_size() if _label != null else Vector2.ZERO
		return Vector2(need.x + 34.0, maxf(RIBBON_HEIGHT, need.y + 4.0))

	func _place() -> void:
		var need := _label.get_minimum_size()
		_label.position = Vector2(14.0, floorf((size.y - need.y) * 0.5))
		_label.size = Vector2(maxf(need.x, size.x - 34.0), need.y)
		update_minimum_size()
		queue_redraw()

	func _draw() -> void:
		var h := size.y
		var w := size.x
		var tip := h * 0.5
		var pts := PackedVector2Array([Vector2(0, 0), Vector2(w - tip, 0), Vector2(w, h * 0.5), Vector2(w - tip, h),
				Vector2(0, h), Vector2(tip * 0.6, h * 0.5)])
		var strong := Color(UiTheme.CYAN, 0.42)
		var clear := Color(UiTheme.CYAN, 0.0)
		draw_polygon(pts, PackedColorArray([strong, clear, clear, clear, strong, strong]))
		# Filete forte à esquerda e linha fina embaixo que também se apaga.
		draw_colored_polygon(PackedVector2Array([Vector2(0, 0), Vector2(4, 0), Vector2(4 + tip * 0.6, h * 0.5),
				Vector2(4, h), Vector2(0, h), Vector2(tip * 0.6, h * 0.5)]), UiTheme.CYAN)
		draw_polyline_colors(PackedVector2Array([Vector2(0, h - 0.5), Vector2(w * 0.7, h - 0.5)]),
				PackedColorArray([Color(UiTheme.CYAN, 0.8), Color(UiTheme.CYAN, 0.0)]), 1.0, true)


## Ladrilho de item (nave, peça, cosmético): moldura chanfrada da raridade com brilho de cima para baixo,
## a figura no meio, o nível num selo escuro embaixo à esquerda e o aviso em cima à direita. É um botão
## (toque, foco do controle e o afundar do UiFx). `selected` acende a moldura em branco com halo;
## `locked` apaga a figura e põe o cadeado. `pixel_art` desenha a figura sem filtro.
class ItemTile:
	extends Button

	var texture: Texture2D:
		set(value):
			texture = value
			queue_redraw()
	var level: int = 0:
		set(value):
			level = value
			queue_redraw()
	var rarity: int = COMMON:
		set(value):
			rarity = value
			queue_redraw()
	var notice: bool = false:
		set(value):
			notice = value
			if _dot != null:
				_dot.visible = value
	var selected: bool = false:
		set(value):
			selected = value
			queue_redraw()
	var locked: bool = false:
		set(value):
			locked = value
			queue_redraw()
	var pixel_art: bool = true

	var _dot: NoticeDot

	func _init() -> void:
		name = "ItemTile"
		custom_minimum_size = Vector2(TILE, TILE)
		var empty := StyleBoxEmpty.new()
		for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
			add_theme_stylebox_override(state, empty)

	func _ready() -> void:
		_dot = CommandKit.notice_dot(self)
		_dot.visible = notice
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if pixel_art else CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		focus_entered.connect(queue_redraw)
		focus_exited.connect(queue_redraw)
		mouse_entered.connect(queue_redraw)
		mouse_exited.connect(queue_redraw)

	func _draw() -> void:
		var color := CommandKit.rarity_color(rarity)
		var rect := Rect2(Vector2.ONE, size - Vector2.ONE * 2.0)
		var cut := minf(9.0, size.x * 0.16)
		var outline := CommandKit.chamfer_points(rect, cut)
		var top := Color(UiTheme.DEEP_BLUE.lerp(color, 0.32), 0.95)
		var bottom := Color(UiTheme.ABYSS, 0.95)
		draw_polygon(outline, PackedColorArray([top, top, top, bottom, bottom, bottom, bottom, top]))
		var hot := selected or has_focus() or is_hovered()
		if selected:
			draw_polyline(_closed(CommandKit.chamfer_points(rect.grow(1.5), cut + 1.0)), Color(color, 0.45), 3.0, true)
		draw_polyline(_closed(outline), UiTheme.WHITE if hot else Color(color, 0.85), 2.0 if hot else 1.5, true)
		if texture != null:
			var inner := rect.grow(-7.0)
			var tex_size := Vector2(texture.get_size())
			var k := minf(inner.size.x / tex_size.x, inner.size.y / tex_size.y)
			if pixel_art and k >= 1.0:
				k = floorf(k)
			var draw_size := tex_size * k
			var at := (inner.position + (inner.size - draw_size) * 0.5).round()
			draw_texture_rect(texture, Rect2(at, draw_size), false,
					Color(0.2, 0.28, 0.38, 0.85) if locked else Color.WHITE)
		if locked:
			var lock := ListScreen.icon(&"lock")
			var side := size.x * 0.34
			draw_texture_rect(lock, Rect2((size - Vector2(side, side)) * 0.5, Vector2(side, side)), false,
					UiTheme.TEXT_DIM)
		if level > 0:
			var font := CommandKit.bold(self)
			var fs := UiTheme.scaled(10)
			var text := str(level)
			var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			var chip := Rect2(Vector2(1.0, size.y - fs - 5.0), Vector2(tw + 9.0, fs + 4.0))
			draw_colored_polygon(CommandKit.chamfer_points(chip, 3.0, 1.0), Color(UiTheme.ABYSS, 0.9))
			draw_polyline(_closed(CommandKit.chamfer_points(chip, 3.0, 1.0)), Color(color, 0.7), 1.0, true)
			draw_string(font, Vector2(chip.position.x + 4.5, chip.end.y - 3.5), text, HORIZONTAL_ALIGNMENT_LEFT, -1,
					fs, UiTheme.WHITE)

	static func _closed(points: PackedVector2Array) -> PackedVector2Array:
		var out := points.duplicate()
		out.append(points[0])
		return out


## Encaixe de equipamento: vazio mostra uma colmeia de hexágonos bem sutil e um "+" ciano; cheio mostra
## a figura. Botão (toque e foco).
class Slot:
	extends Button

	var texture: Texture2D:
		set(value):
			texture = value
			queue_redraw()

	func _init() -> void:
		name = "Slot"
		custom_minimum_size = Vector2(TILE, TILE)
		var empty := StyleBoxEmpty.new()
		for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
			add_theme_stylebox_override(state, empty)
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	func _ready() -> void:
		focus_entered.connect(queue_redraw)
		focus_exited.connect(queue_redraw)

	func _draw() -> void:
		var rect := Rect2(Vector2.ONE, size - Vector2.ONE * 2.0)
		var outline := CommandKit.chamfer_points(rect, minf(9.0, size.x * 0.16))
		draw_colored_polygon(outline, Color(UiTheme.ABYSS, 0.7))
		var hex_r := maxf(5.0, size.x * 0.11)
		var dx := hex_r * sqrt(3.0)
		var row := 0
		var y := rect.position.y + hex_r * 0.5
		while y < rect.end.y:
			var x := rect.position.x + (dx * 0.5 if row % 2 == 1 else 0.0)
			while x < rect.end.x + dx:
				var pts := PackedVector2Array()
				for i: int in range(7):
					var a := PI / 6.0 + TAU * float(i) / 6.0
					pts.append((Vector2(x, y) + Vector2(cos(a), sin(a)) * hex_r).clamp(rect.position, rect.end))
				draw_polyline(pts, Color(UiTheme.CYAN, 0.07), 1.0, true)
				x += dx
			y += hex_r * 1.5
			row += 1
		var hot := has_focus() or is_hovered()
		var closed := outline.duplicate()
		closed.append(outline[0])
		draw_polyline(closed, UiTheme.WHITE if hot else Color(UiTheme.CYAN, 0.45), 1.5, true)
		if texture != null:
			var inner := rect.grow(-7.0)
			var tex_size := Vector2(texture.get_size())
			var k := minf(inner.size.x / tex_size.x, inner.size.y / tex_size.y)
			var draw_size := tex_size * (floorf(k) if k >= 1.0 else k)
			draw_texture_rect(texture, Rect2((inner.position + (inner.size - draw_size) * 0.5).round(), draw_size), false)
		else:
			var plus := ListScreen.icon(&"plus")
			var side := size.x * 0.32
			draw_texture_rect(plus, Rect2((size - Vector2(side, side)) * 0.5, Vector2(side, side)), false,
					Color(UiTheme.CYAN, 0.75))
