class_name CampaignParts
extends RefCounted
## Peças da aba Campanha (HubScreen, 1.15): desenhadas em código, nítidas na resolução física e baratas
## (cada peça só se redesenha quando o estado muda; o pulso da próxima missão e a nave que paira sobre
## ela só mexem em `scale`, `position` e `modulate`, sem redesenhar).
##
## - TrailNode: nó circular da missão (anel laranja e dourado com o número; chefe com moldura de
##   octógono coral e coroa; chefe médio com losango dourado; trancado = pino cinza com cadeado) e as
##   estrelas ganhas embaixo.
## - TrailView: linha pontilhada que liga os nós e o halo de cada nó aberto (arrastar para o lado troca
##   de capítulo).
## - Pulse: anel que abre e some em volta da próxima missão. Marker: a nave do jogador pairando.
## - ShortcutButton: atalho de ícone grande e rótulo curto (com a bolinha de aviso do CommandKit).
## - Chevron: seta de trocar capítulo. Milestone: o baú do marco do capítulo com a barra de progresso.

const NODE := 44.0
const STAR := 8.0
const ORANGE := Color("ff8a1f")


static func _closed(points: PackedVector2Array) -> PackedVector2Array:
	var out := points.duplicate()
	out.append(points[0])
	return out


static func _circle(c: Vector2, r: float, sides: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i: int in range(sides):
		var a := TAU * float(i) / float(sides) - PI * 0.5 + (PI / float(sides) if sides == 8 else 0.0)
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	return pts


## Estrela de 5 pontas centrada em `c`.
static func star_points(c: Vector2, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i: int in range(10):
		var a := -PI * 0.5 + PI * float(i) / 5.0
		pts.append(c + Vector2(cos(a), sin(a)) * (r if i % 2 == 0 else r * 0.45))
	return pts


## Fileira de 4 estrelas (as ganhas em ouro) centrada em `c`.
static func draw_stars(ci: CanvasItem, c: Vector2, got: int) -> void:
	var step := STAR + 1.0
	var x0 := c.x - step * 1.5
	for i: int in range(4):
		var p := Vector2(x0 + step * i, c.y)
		var pts := star_points(p, STAR * 0.5 + 0.5)
		ci.draw_colored_polygon(star_points(p, STAR * 0.5 + 1.5), Color(UiTheme.ABYSS, 0.85))
		ci.draw_colored_polygon(pts, UiTheme.GOLD if i < got else Color(UiTheme.TEXT_DIM, 0.35))


## "1-2" de "c1m2", "3-3" de "c3m3s", "10-1" de "c10m1".
static func short_label(id: StringName) -> String:
	var s := String(id)
	var m := s.find("m")
	return "%s-%s" % [s.substr(1, m - 1), s.substr(m + 1, 1)] if s.begins_with("c") and m > 1 else s


## Botão sem caixa do tema (as peças se desenham sozinhas).
static func _bare(b: Button) -> void:
	var empty := StyleBoxEmpty.new()
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(state, empty)
	b.focus_entered.connect(b.queue_redraw)
	b.focus_exited.connect(b.queue_redraw)
	b.mouse_entered.connect(b.queue_redraw)
	b.mouse_exited.connect(b.queue_redraw)


## Nó da missão na trilha.
class TrailNode:
	extends Button

	var id: StringName = &""
	var kind: StringName = &"mission"
	var route: StringName = &""
	var open: bool = false
	var cleared: bool = false
	var stars: int = 0
	var next: bool = false

	func _init() -> void:
		custom_minimum_size = Vector2(NODE, NODE)
		size = custom_minimum_size
		CampaignParts._bare(self)
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

	func setup(n: Dictionary) -> void:
		id = n["id"]
		name = "Node_" + String(id)
		kind = n["kind"]
		route = n.get("route", &"")
		open = n["open"]
		cleared = n["cleared"]
		stars = n["stars"]
		next = n["next"]
		disabled = not open
		focus_mode = Control.FOCUS_ALL if open else Control.FOCUS_NONE
		tooltip_text = TranslationServer.translate("stage." + String(id)) if open \
				else TranslationServer.translate("map.locked")
		queue_redraw()

	## "1-2" do id ("c1m2" e "c3m3s").
	func number() -> String:
		return CampaignParts.short_label(id)

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5
		var hot := has_focus() or is_hovered()
		var boss := kind == &"boss"
		var sides := 8 if boss else 40
		if not open:
			# Pino trancado: disco cinza, aro apagado e cadeado.
			CampaignParts._ring(self, c, r - 3.0, sides, Color(0.16, 0.2, 0.26, 0.92), Color(0.42, 0.5, 0.58, 0.7), 2.0)
			var lock := ListScreen.icon(&"lock")
			var side := r * 0.85
			draw_texture_rect(lock, Rect2(c - Vector2(side, side) * 0.5, Vector2(side, side)), false,
					Color(UiTheme.TEXT_DIM, 0.8))
			return
		var rim := UiTheme.CORAL if boss else ORANGE
		var face_top := UiTheme.RAISED.lerp(rim, 0.25) if not cleared else UiTheme.RAISED.lerp(UiTheme.GOLD, 0.18)
		# Aro externo (laranja ou coral), aro dourado e o disco.
		draw_colored_polygon(CampaignParts._circle(c, r, sides), Color(rim.darkened(0.45), 0.95))
		draw_colored_polygon(CampaignParts._circle(c, r - 1.5, sides), rim)
		draw_colored_polygon(CampaignParts._circle(c, r - 4.0, sides), UiTheme.GOLD)
		draw_colored_polygon(CampaignParts._circle(c, r - 6.0, sides), UiTheme.ABYSS)
		draw_colored_polygon(CampaignParts._circle(c + Vector2(0, -1.0), r - 7.0, sides), face_top)
		draw_colored_polygon(CampaignParts._circle(c + Vector2(0, 2.0), r - 9.0, sides), Color(UiTheme.ABYSS, 0.45))
		# Brilho de vidro em cima.
		draw_arc(c, r - 9.0, PI * 1.15, PI * 1.85, 12, Color(1, 1, 1, 0.28), 2.0, true)
		if hot:
			draw_polyline(CampaignParts._closed(CampaignParts._circle(c, r + 1.5, sides)), UiTheme.WHITE, 2.0, true)
		var font := CommandKit.bold(self)
		var text := number()
		var fs := CommandKit.fit_size(font, text, (r - 7.0) * 2.0 - 4.0, UiTheme.scaled(roundi(13.0 * r / 22.0)), 8)
		var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var base := c.y + fs * 0.36 - (3.0 if route != &"" else 0.0)
		draw_string_outline(font, Vector2(c.x - tw * 0.5, base), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 3,
				Color(UiTheme.ABYSS, 0.9))
		draw_string(font, Vector2(c.x - tw * 0.5, base), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs,
				UiTheme.GOLD if next else UiTheme.WHITE)
		if route != &"":
			var letter := TranslationServer.translate("map.route_" + String(route)).left(1).to_upper()
			var ls := UiTheme.scaled(8)
			var lw := font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, ls).x
			draw_string(font, Vector2(c.x - lw * 0.5, base + ls + 1.0), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, ls,
					UiTheme.CYAN)
		if boss:
			CampaignParts._crown(self, Vector2(c.x, c.y - r - 1.0), 7.0)
		elif kind == &"miniboss":
			var d := Vector2(c.x, c.y - r + 1.0)
			var diamond := PackedVector2Array([d + Vector2(0, -5), d + Vector2(4, 0), d + Vector2(0, 5), d + Vector2(-4, 0)])
			draw_colored_polygon(diamond, UiTheme.GOLD)
			draw_polyline(CampaignParts._closed(diamond), UiTheme.GOLD_DARK, 1.0, true)
		if cleared:
			CampaignParts.draw_stars(self, Vector2(c.x, size.y + STAR * 0.5 + 1.0), stars)


static func _ring(ci: CanvasItem, c: Vector2, r: float, sides: int, fill: Color, line: Color, width: float) -> void:
	ci.draw_colored_polygon(_circle(c, r, sides), fill)
	ci.draw_polyline(_closed(_circle(c, r, sides)), line, width, true)


## Coroa do chefe: três pontas douradas com contorno escuro.
static func _crown(ci: CanvasItem, base: Vector2, w: float) -> void:
	var pts := PackedVector2Array([base + Vector2(-w, 0), base + Vector2(-w, -w * 0.9),
			base + Vector2(-w * 0.45, -w * 0.4), base + Vector2(0, -w * 1.15), base + Vector2(w * 0.45, -w * 0.4),
			base + Vector2(w, -w * 0.9), base + Vector2(w, 0)])
	ci.draw_colored_polygon(pts, UiTheme.GOLD)
	ci.draw_polyline(_closed(pts), UiTheme.GOLD_DARK, 1.2, true)


## Linhas pontilhadas e halos da trilha. `links` = [[a, b, aberto], ...] e `halos` = [[centro, cor], ...]
## em coordenadas próprias; `entry` liga o primeiro nó à borda de baixo (capítulo anterior).
class TrailView:
	extends Control

	signal swiped(step: int)

	var links: Array = []
	var halos: Array = []
	## Raio dos nós (as linhas param na borda deles).
	var node_radius: float = NODE * 0.5
	var _glow: Texture2D
	var _drag: float = 0.0

	func _init() -> void:
		name = "Trail"
		mouse_filter = Control.MOUSE_FILTER_STOP
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		_glow = SpriteBank.generated("fx/glow_32")

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventScreenDrag:
			_drag += (event as InputEventScreenDrag).relative.x
			accept_event()
		elif event is InputEventScreenTouch:
			if not (event as InputEventScreenTouch).pressed and absf(_drag) > 40.0:
				swiped.emit(-1 if _drag > 0.0 else 1)
			_drag = 0.0

	func _draw() -> void:
		for h: Array in halos:
			var c: Vector2 = h[0]
			var r := node_radius * 2.1
			draw_texture_rect(_glow, Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0), false, h[1])
		for l: Array in links:
			var a: Vector2 = l[0]
			var b: Vector2 = l[1]
			var on := bool(l[2])
			var col := Color(UiTheme.GOLD, 0.9) if on else Color(0.45, 0.55, 0.65, 0.45)
			var from := a.move_toward(b, node_radius + 3.0)
			var to := b.move_toward(a, node_radius + 3.0)
			var steps := maxi(2, int(from.distance_to(to) / 8.0))
			for d: int in range(steps + 1):
				var p := from.lerp(to, float(d) / float(steps))
				if on:
					draw_circle(p, 2.6, Color(UiTheme.GOLD, 0.18), true, -1.0, true)
				draw_circle(p, 1.6, col, true, -1.0, true)


## Anel do sonar (desenhado uma vez; o HubScreen anima escala e transparência).
class Pulse:
	extends Control

	var _ring: Texture2D

	func _init() -> void:
		name = "Pulse"
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		var add := CanvasItemMaterial.new()
		add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = add
		_ring = SpriteBank.generated("fx/ring_128")
		size = Vector2(NODE, NODE) * 1.6
		pivot_offset = size * 0.5
		resized.connect(func() -> void:
			pivot_offset = size * 0.5
			queue_redraw())

	func _draw() -> void:
		draw_texture_rect(_ring, Rect2(Vector2.ZERO, size), false, UiTheme.GOLD)


## A nave do jogador, pequena, pairando sobre a próxima missão (marcador de posição).
class Marker:
	extends Control

	var tint := Color.WHITE:
		set(value):
			tint = value
			queue_redraw()
	var _ship: Texture2D
	var _glow: Texture2D

	func _init() -> void:
		name = "Marker"
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_ship = SpriteBank.texture("res://assets/art/void/main_ship/base_full.png")
		_glow = SpriteBank.generated("fx/glow_32")
		size = Vector2(28, 30)

	func _draw() -> void:
		draw_texture_rect(_glow, Rect2(Vector2(4, 16), Vector2(20, 16)), false, Color(UiTheme.CYAN, 0.5))
		if _ship != null:
			draw_texture_rect(_ship, Rect2(Vector2(2, 0), Vector2(24, 24)), false, tint)


## Atalho: ícone grande no alto e rótulo curto embaixo, num vidro chanfrado; bolinha de aviso no canto.
class ShortcutButton:
	extends Button

	var icon_tex: Texture2D
	var label: String = "":
		set(value):
			label = value
			tooltip_text = value
			queue_redraw()
	var accent := UiTheme.CYAN
	var dot: CommandKit.NoticeDot

	func _init(node_name: String, icon_name: String) -> void:
		name = node_name
		icon_tex = UiTheme.icon(icon_name)
		custom_minimum_size = Vector2(UiTheme.TOUCH_MIN, UiTheme.TOUCH_MIN)
		CampaignParts._bare(self)
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

	func _ready() -> void:
		dot = CommandKit.notice_dot(self)
		dot.visible = false

	func set_notice(on: bool) -> void:
		if dot != null:
			dot.visible = on

	func _draw() -> void:
		var hot := has_focus() or is_hovered()
		var rect := Rect2(Vector2.ONE, size - Vector2.ONE * 2.0)
		var outline := CommandKit.chamfer_points(rect, minf(8.0, size.x * 0.18))
		var top := Color(UiTheme.DEEP_BLUE.lerp(accent, 0.22), 0.92)
		var bottom := Color(UiTheme.ABYSS, 0.9)
		draw_polygon(outline, PackedColorArray([top, top, top, bottom, bottom, bottom, bottom, top]))
		draw_polyline(CampaignParts._closed(outline), UiTheme.WHITE if hot else Color(accent, 0.6), 1.5 if hot else 1.0, true)
		var font := CommandKit.bold(self)
		var has_label := not label.is_empty() and size.y >= 40.0
		var fs := CommandKit.fit_size(font, label, size.x - 6.0, UiTheme.scaled(9), 6) if has_label else 0
		var icon_side := minf(size.x - 16.0, size.y - (fs + 12.0 if has_label else 12.0))
		if icon_tex != null:
			var at := Vector2((size.x - icon_side) * 0.5, 5.0 if has_label else (size.y - icon_side) * 0.5)
			draw_texture_rect(icon_tex, Rect2(at.round(), Vector2(icon_side, icon_side)), false,
					UiTheme.WHITE if hot else accent)
		if has_label:
			var tw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			draw_string(font, Vector2((size.x - tw) * 0.5, size.y - 5.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs,
					UiTheme.WHITE if hot else UiTheme.TEXT)


## Seta de trocar capítulo (esquerda ou direita).
class Chevron:
	extends Button

	var right: bool = false

	func _init(node_name: String, to_right: bool) -> void:
		name = node_name
		right = to_right
		custom_minimum_size = Vector2(UiTheme.TOUCH_MIN, UiTheme.TOUCH_MIN)
		CampaignParts._bare(self)

	func _draw() -> void:
		var hot := has_focus() or is_hovered()
		var rect := Rect2(Vector2.ONE, size - Vector2.ONE * 2.0)
		var outline := CommandKit.chamfer_points(rect, 7.0)
		draw_colored_polygon(outline, Color(UiTheme.ABYSS, 0.78 if not disabled else 0.4))
		var col := UiTheme.WHITE if hot else (UiTheme.CYAN if not disabled else Color(UiTheme.TEXT_DIM, 0.35))
		draw_polyline(CampaignParts._closed(outline), Color(col, 0.7), 1.0, true)
		var c := size * 0.5
		var s := 6.0 * (1.0 if right else -1.0)
		draw_polyline(PackedVector2Array([c + Vector2(-s * 0.6, -8), c + Vector2(s * 0.6, 0), c + Vector2(-s * 0.6, 8)]),
				col, 3.0, true)


## Marco do capítulo: baú à esquerda, o prêmio em uma linha e a barra do progresso (fragmentos da
## aeronave ou estrelas da asa) com o número à direita.
class Milestone:
	extends Button

	var title: String = "":
		set(value):
			title = value
			tooltip_text = value
			queue_redraw()
	var have: int = 0
	var need: int = 1
	var done: bool = false

	func _init() -> void:
		name = "Milestone"
		custom_minimum_size = Vector2(UiTheme.TOUCH_MIN, UiTheme.TOUCH_MIN)
		CampaignParts._bare(self)
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

	func set_progress(value: int, goal: int, complete: bool) -> void:
		have = value
		need = maxi(1, goal)
		done = complete
		queue_redraw()

	func _draw() -> void:
		var hot := has_focus() or is_hovered()
		var rect := Rect2(Vector2.ONE, size - Vector2.ONE * 2.0)
		var outline := CommandKit.chamfer_points(rect, 8.0)
		var top := Color(UiTheme.DEEP_BLUE.lerp(UiTheme.GOLD, 0.16), 0.92)
		var bottom := Color(UiTheme.ABYSS, 0.92)
		draw_polygon(outline, PackedColorArray([top, top, top, bottom, bottom, bottom, bottom, top]))
		draw_polyline(CampaignParts._closed(outline), UiTheme.WHITE if hot else Color(UiTheme.GOLD, 0.65),
				1.5 if hot else 1.0, true)
		# Baú: caixa de madeira com faixas douradas e tampa; aberto (marco cumprido) solta luz.
		var h := size.y
		var chest := Rect2(Vector2(8.0, h * 0.5 - 7.0), Vector2(22.0, 15.0))
		if done:
			draw_circle(chest.get_center() + Vector2(0, -4), 14.0, Color(UiTheme.GOLD, 0.22), true, -1.0, true)
		draw_rect(chest, Color("6b3d1c"))
		draw_rect(Rect2(chest.position, Vector2(chest.size.x, 5.0)), Color("8c5426"))
		draw_rect(Rect2(chest.position + Vector2(0, 5.0), Vector2(chest.size.x, 1.5)), UiTheme.GOLD)
		draw_rect(Rect2(chest.position + Vector2(3.0, 0), Vector2(2.0, chest.size.y)), UiTheme.GOLD)
		draw_rect(Rect2(chest.end - Vector2(5.0, chest.size.y), Vector2(2.0, chest.size.y)), UiTheme.GOLD)
		draw_rect(Rect2(chest.get_center() + Vector2(-2.0, -1.0), Vector2(4.0, 5.0)), Color("fff0b8"))
		draw_rect(chest, Color(UiTheme.GOLD_DARK, 0.9), false, 1.0)
		var font := CommandKit.bold(self)
		var x := chest.end.x + 8.0
		var number := "%d/%d" % [mini(have, need), need]
		var ns := UiTheme.scaled(9)
		var nw := font.get_string_size(number, HORIZONTAL_ALIGNMENT_LEFT, -1, ns).x
		var room := size.x - x - 8.0
		var fs := CommandKit.fit_size(font, title, room, UiTheme.scaled(11), 7)
		draw_string(font, Vector2(x, h * 0.5 - 2.0), title, HORIZONTAL_ALIGNMENT_LEFT, room, fs,
				UiTheme.GOLD if done else UiTheme.WHITE)
		var bar := Rect2(Vector2(x, h * 0.5 + 4.0), Vector2(maxf(10.0, room - nw - 6.0), 5.0))
		draw_rect(bar, Color(UiTheme.ABYSS, 0.9))
		var k := clampf(float(have) / float(need), 0.0, 1.0)
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * k, bar.size.y)), UiTheme.MINT if done else UiTheme.GOLD)
		draw_rect(bar, Color(UiTheme.GOLD, 0.4), false, 1.0)
		draw_string(font, Vector2(bar.end.x + 6.0, bar.end.y + 1.0), number, HORIZONTAL_ALIGNMENT_LEFT, -1, ns,
				UiTheme.TEXT_DIM)
