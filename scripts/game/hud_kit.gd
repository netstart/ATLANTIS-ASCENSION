class_name HudKit
extends RefCounted
## Peças do HUD da partida (GameHud): caixas de vidro dos botões, fontes e o desenho vetorial dos
## glifos (tridente, bomba, ondas, pausa, degraus da arma, barras da faixa). Funções puras e estáticas:
## o GameHud chama o desenho só quando o estado muda (queue_redraw), nunca a cada quadro
## (docs/policies/qualidade.md, "Desenho e desempenho").

const PIP_W := 9.0
const PIP_H := 4.0
const PIP_GAP := 3.0
## Corrente (PODER): vão entre os 3 segmentos do anel (rad), tremida do aperto sem carga (s) e amplitude (px).
const POWER_GAP := 0.34
const POWER_SHAKE := 0.32
const POWER_SHAKE_PX := 3.0


static func ignore(node: Control) -> Control:
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node


## Exo 2 em negrito com algarismos tabulares: o placar não "dança" enquanto conta.
static func tabular_font() -> Font:
	var bold := UiTheme.bold_font()
	if bold == null:
		return null
	var tab := FontVariation.new()
	var src := bold as FontVariation
	if src != null:
		tab.base_font = src.base_font
		tab.variation_opentype = src.variation_opentype
		tab.fallbacks = src.fallbacks
	else:
		tab.base_font = bold
	tab.opentype_features = {TextServerManager.get_primary_interface().name_to_tag("tnum"): 1}
	return tab


## Textura recortada no retângulo usado (sem a margem transparente da folha da nave).
static func trimmed_texture(path: String) -> Texture2D:
	var tex := SpriteBank.texture(path)
	if tex == null:
		return null
	var img := tex.get_image()
	var used := img.get_used_rect() if img != null else Rect2i()
	if used.size.x <= 0 or used.size.y <= 0:
		return tex
	var atlas := AtlasTexture.new()
	atlas.atlas = tex
	atlas.region = Rect2(used)
	return atlas


## Botão de vidro "quase redondo": chanfro grande nos quatro cantos (octógono), borda na cor do papel.
static func round_box(bg: Color, border: Color, width: int, cut: int, glow: float = 0.0) -> StyleBoxFlat:
	var box := UiTheme.chamfer(bg, border, width, cut)
	box.corner_radius_top_right = maxi(2, int(cut * 0.5))
	box.corner_radius_bottom_left = maxi(2, int(cut * 0.5))
	box.set_content_margin_all(0)
	if glow > 0.0:
		box.shadow_color = Color(border, glow)
		box.shadow_size = 6
	return box


## Caixas dos cinco estados do botão (chamado só na troca de estado do botão).
static func style_round(b: Button, accent: Color, alpha: float, lit: bool, cut: int, pad_left: int = 0) -> void:
	var bg := Color(UiTheme.DEEP_BLUE, 0.84 * alpha)
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		var box: StyleBoxFlat
		match state:
			"pressed":
				box = round_box(Color(accent, 0.3), accent, 2, cut)
			"hover":
				box = round_box(bg.lightened(0.08), accent, 2 if lit else 1, cut, 0.3)
			"disabled":
				box = round_box(Color(UiTheme.ABYSS, 0.55 * alpha), Color(UiTheme.TEXT_DIM, 0.25), 1, cut)
			_:
				box = round_box(bg, Color(accent, 0.95 if lit else 0.45 * alpha + 0.1), 2 if lit else 1, cut,
						0.35 if lit else 0.0)
		if pad_left > 0:
			box.content_margin_left = pad_left
			box.content_margin_right = 10
		b.add_theme_stylebox_override(state, box)


## Painel de vidro dos menus da partida (pausa, reviver, bênçãos), com sombra funda.
static func glass(accent: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	var box := UiTheme.panel_box(accent, 0.92)
	box.set_content_margin_all(14)
	box.shadow_size = 14
	box.shadow_color = Color(0, 0, 0, 0.5)
	panel.add_theme_stylebox_override("panel", box)
	panel.visible = false
	return panel


## Estilos da pílula do multiplicador por faixa: ciano (x1–3), menta (x4–7), ouro (x8–15), violeta (máximo).
static func mult_boxes() -> Array[StyleBoxFlat]:
	var list: Array[StyleBoxFlat] = []
	for color: Color in [UiTheme.CYAN, UiTheme.MINT, UiTheme.GOLD, UiTheme.VIOLET]:
		var box := UiTheme.pill_box(color)
		box.border_color = Color(color, 0.85)
		box.bg_color = Color(UiTheme.ABYSS, 0.78)
		box.shadow_color = Color(color, 0.3)
		box.shadow_size = 4
		box.content_margin_left = 7
		box.content_margin_right = 7
		list.append(box)
	return list


## Halo atrás de um botão (só sombra, sem fundo): o especial pronto pulsa com ele.
static func glow_box(color: Color) -> StyleBoxFlat:
	var glow := UiTheme.chamfer(Color(color, 0.0), Color(color, 0.0), 0, 14)
	glow.shadow_color = Color(color, 0.55)
	glow.shadow_size = 12
	return glow


## Legenda pequena embaixo do glifo de um botão.
static func caption(parent: Control) -> Label:
	var l := UiTheme.heading("", UiTheme.SMALL_SIZE - 1, UiTheme.TEXT_DIM)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.clip_text = true
	parent.add_child(l)
	return l


## Ícone de casco: a nave do jogador pequena, com filtro linear (reduzida, não ampliada).
static func life_icon(tex: Texture2D, height: float) -> TextureRect:
	var aspect := 1.0
	if tex != null and tex.get_height() > 0:
		aspect = float(tex.get_width()) / tex.get_height()
	var icon := TextureRect.new()
	icon.texture = tex
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	icon.custom_minimum_size = Vector2(roundf(height * aspect), height)
	icon.pivot_offset = icon.custom_minimum_size * 0.5
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon


## Ícone de casco que acabou de mudar: cresce, acende na cor do evento e assenta.
static func flash_icon(icon: TextureRect, from: Color, to: Color) -> void:
	icon.modulate = from
	icon.scale = Vector2(1.5, 1.5)
	var t := icon.create_tween().set_parallel()
	t.tween_property(icon, "modulate", to, 0.5)
	t.tween_property(icon, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Entrada da faixa: as barras varrem dos lados opostos, a faixa abre do centro e o texto assenta de
## 112 % para 100 %; no aviso de chefe o texto pisca três vezes (desligado por "reduzir flashes").
static func banner_in(owner: Node, band: Control, bars: Array[Control], text: Control, blink: bool) -> Tween:
	var tween := owner.create_tween().set_parallel()
	band.scale = Vector2(1.0, 0.0)
	tween.tween_property(band, "scale:y", 1.0, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	for i: int in range(bars.size()):
		bars[i].scale = Vector2(0.0, 1.0)
		tween.tween_property(bars[i], "scale:x", 1.0, 0.32).set_trans(Tween.TRANS_EXPO) \
				.set_ease(Tween.EASE_OUT).set_delay(0.05 * i)
	text.scale = Vector2(1.12, 1.12)
	text.modulate.a = 0.0
	tween.tween_property(text, "scale", Vector2.ONE, 0.26).set_trans(Tween.TRANS_BACK) \
			.set_ease(Tween.EASE_OUT).set_delay(0.08)
	tween.tween_property(text, "modulate:a", 1.0, 0.14).set_delay(0.08)
	if blink:
		for k: int in range(3):
			tween.chain().tween_property(text, "modulate:a", 0.35, 0.12)
			tween.chain().tween_property(text, "modulate:a", 1.0, 0.12)
	return tween


## Pulso: cresce e acende de uma vez, depois assenta (placar, multiplicador). Mata o pulso anterior.
static func pop(node: Control, old: Tween, grow: float, flash: Color, rest: Color, seconds: float) -> Tween:
	if old != null and old.is_valid():
		old.kill()
	node.scale = Vector2(grow, grow)
	node.modulate = flash
	var tween := node.create_tween().set_parallel()
	tween.tween_property(node, "scale", Vector2.ONE, seconds * 0.75).set_trans(Tween.TRANS_BACK) \
			.set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "modulate", rest, seconds)
	return tween


## Lista de um menu da partida: título ("Title") e um botão por [nome, sinal]; o primeiro é a ação
## principal (ouro), os outros são vidro.
static func menu_box(panel: PanelContainer, entries: Array) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var title := UiTheme.heading("", UiTheme.TITLE_SIZE, UiTheme.WHITE)
	title.name = "Title"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	for i: int in range(entries.size()):
		var b := Button.new()
		b.name = String(entries[i][0])
		b.custom_minimum_size = Vector2(190, UiTheme.TOUCH_MIN + (10.0 if i == 0 else 0.0))
		if i == 0:
			UiTheme.style_primary(b)
		var sig: Signal = entries[i][1]
		b.pressed.connect(func() -> void: sig.emit())
		box.add_child(b)
	return box


static func gauge_center(c: Control, big: bool) -> Vector2:
	return Vector2(c.size.x * 0.5, c.size.y * (0.4 if big else 0.5))


static func gauge_radius(c: Control, big: bool) -> float:
	return minf(c.size.x, c.size.y) * (0.28 if big else 0.34)


## Especial: anel de carga dourado (sentido horário, de cima) e tridente no centro.
static func draw_special(c: Control, big: bool, charge: float, ready: bool) -> void:
	var o := gauge_center(c, big)
	var r := gauge_radius(c, big)
	c.draw_arc(o, r, 0.0, TAU, 48, Color(UiTheme.ABYSS, 0.75), 4.5, true)
	c.draw_arc(o, r, 0.0, TAU, 48, Color(UiTheme.GOLD, 0.18), 2.5, true)
	if charge > 0.0:
		var col := UiTheme.GOLD if ready else Color(UiTheme.GOLD, 0.8)
		c.draw_arc(o, r, -PI * 0.5, -PI * 0.5 + TAU * charge, maxi(3, int(48 * charge)), col, 2.5, true)
	draw_trident(c, o, r * 0.68, UiTheme.WHITE if ready else Color(UiTheme.TEXT_DIM, 0.95))


## PODER: anel da Corrente em 3 segmentos (de cima, sentido horário) que enchem com `value` (0 a 3), na cor
## da nave; segmento cheio fica aceso e com um ponto de luz na ponta. No centro, o ícone do poder que sairia
## agora (apagado sem carga ou com um poder no ar). `shake` (s restantes) treme o medidor no aperto vazio.
static func draw_power(c: Control, big: bool, value: float, tint: Color, icon: Texture2D, live: bool,
		shake: float) -> void:
	var o := gauge_center(c, big)
	if shake > 0.0:
		o.x += sin(shake * 70.0) * POWER_SHAKE_PX * shake / POWER_SHAKE
	var r := gauge_radius(c, big)
	var span := TAU / Powers.SEGMENTS
	c.draw_arc(o, r, 0.0, TAU, 48, Color(UiTheme.ABYSS, 0.75), 4.5, true)
	var whole := Powers.whole(value)
	for i: int in range(int(Powers.SEGMENTS)):
		var a0 := -PI * 0.5 + i * span + POWER_GAP * 0.5
		var arc := span - POWER_GAP
		c.draw_arc(o, r, a0, a0 + arc, 16, Color(tint, 0.2), 2.5, true)
		var fill := clampf(value - i, 0.0, 1.0)
		if fill <= 0.0:
			continue
		var full := i < whole
		var col := tint.lerp(UiTheme.WHITE, 0.3) if full else Color(tint, 0.7)
		c.draw_arc(o, r, a0, a0 + arc * fill, maxi(3, int(16 * fill)), col, 3.0 if full else 2.5, true)
		if full and not live:
			c.draw_circle(o + Vector2.from_angle(a0 + arc) * r, 1.6, UiTheme.WHITE, true, -1.0, true)
	if icon == null:
		return
	var side := 24.0 if r >= 13.0 else 16.0
	var dim := whole < 1 or live
	c.draw_texture_rect(icon, Rect2((o - Vector2(side, side) * 0.5).round(), Vector2(side, side)), false,
			Color(0.55, 0.6, 0.7, 0.55) if dim else Color.WHITE)


## Tridente de Poseidon (especial): haste, travessa e três pontas.
static func draw_trident(c: Control, o: Vector2, k: float, col: Color) -> void:
	var w := maxf(1.5, k * 0.17)
	var bar_y := -k * 0.15
	var side := k * 0.6
	c.draw_line(o + Vector2(0, k), o + Vector2(0, -k * 0.6), col, w, true)
	c.draw_line(o + Vector2(-side, bar_y), o + Vector2(side, bar_y), col, w, true)
	for sx: float in [-1.0, 1.0]:
		c.draw_line(o + Vector2(sx * side, bar_y + w * 0.5), o + Vector2(sx * side, -k * 0.6), col, w, true)
		c.draw_colored_polygon(PackedVector2Array([o + Vector2(sx * side - w * 1.1, -k * 0.58),
				o + Vector2(sx * side + w * 1.1, -k * 0.58), o + Vector2(sx * side, -k * 0.95)]), col)
	c.draw_colored_polygon(PackedVector2Array([o + Vector2(-w * 1.3, -k * 0.55), o + Vector2(w * 1.3, -k * 0.55),
			o + Vector2(0, -k * 1.1)]), col)


## Bomba: um segmento do anel por bomba (a contagem se lê sem número) e a esfera com pavio aceso.
static func draw_bomb(c: Control, big: bool, n: int) -> void:
	var o := gauge_center(c, big)
	var r := gauge_radius(c, big)
	c.draw_arc(o, r, 0.0, TAU, 48, Color(UiTheme.ABYSS, 0.75), 4.5, true)
	if n <= 0:
		c.draw_arc(o, r, 0.0, TAU, 48, Color(UiTheme.TEXT_DIM, 0.2), 2.0, true)
	else:
		var gap := 0.32 if n > 1 else 0.0
		var span := TAU / n
		for i: int in range(n):
			var a := -PI * 0.5 + i * span + gap * 0.5
			c.draw_arc(o, r, a, a + span - gap, maxi(4, int(48.0 / n)), UiTheme.CYAN, 2.5, true)
	var k := r * 0.62
	var col := UiTheme.TEXT if n > 0 else Color(UiTheme.TEXT_DIM, 0.6)
	var body := o + Vector2(-k * 0.12, k * 0.18)
	var br := k * 0.66
	c.draw_circle(body, br, col, true, -1.0, true)
	c.draw_circle(body + Vector2(-br * 0.36, -br * 0.36), br * 0.24, Color(1, 1, 1, 0.7), true, -1.0, true)
	var tip := o + Vector2(k * 0.72, -k * 0.78)
	c.draw_line(body + Vector2(br * 0.55, -br * 0.6), tip, col, maxf(1.2, k * 0.14), true)
	if n > 0:
		var s := k * 0.32
		c.draw_colored_polygon(PackedVector2Array([tip + Vector2(0, -s), tip + Vector2(s * 0.3, -s * 0.3),
				tip + Vector2(s, 0), tip + Vector2(s * 0.3, s * 0.3), tip + Vector2(0, s),
				tip + Vector2(-s * 0.3, s * 0.3), tip + Vector2(-s, 0), tip + Vector2(-s * 0.3, -s * 0.3)]),
				UiTheme.GOLD)


## Ondas da Maré Alta (à esquerda do texto do botão).
static func draw_waves(c: Control) -> void:
	var cy := c.size.y * 0.5
	for row: int in range(2):
		var pts := PackedVector2Array()
		for i: int in range(9):
			pts.append(Vector2(i * 2.0, cy + (row - 0.5) * 6.0 + sin(i * 0.85) * 1.8))
		c.draw_polyline(pts, UiTheme.CYAN, 1.6, true)


static func draw_pause(c: Control) -> void:
	var w := maxf(3.0, c.size.x * 0.11)
	var h := c.size.y * 0.36
	var o := c.size * 0.5
	c.draw_rect(Rect2(o + Vector2(-w * 1.5, -h * 0.5), Vector2(w, h)), UiTheme.TEXT)
	c.draw_rect(Rect2(o + Vector2(w * 0.5, -h * 0.5), Vector2(w, h)), UiTheme.TEXT)


static func pips_size(max_level: int) -> Vector2:
	return Vector2(max_level * (PIP_W + PIP_GAP), PIP_H)


## Degraus da arma: paralelogramos; todos dourados no nível máximo.
static func draw_pips(c: Control, level: int, max_level: int) -> void:
	var maxed := level >= max_level
	for i: int in range(max_level):
		var x := i * (PIP_W + PIP_GAP)
		var col := (UiTheme.GOLD if maxed else UiTheme.CYAN) if i < level else Color(UiTheme.TEXT_DIM, 0.28)
		c.draw_colored_polygon(PackedVector2Array([Vector2(x + 2.0, 0), Vector2(x + PIP_W, 0),
				Vector2(x + PIP_W - 2.0, PIP_H), Vector2(x, PIP_H)]), col)


## Barras da faixa: tira chanfrada (a de cima entra pela esquerda, a de baixo pela direita), em ciano ou
## na cor da nave (poderes); no aviso de chefe fica larga, coral e com listras de perigo.
static func draw_banner_bar(c: Control, index: int, warning: bool, accent: Color = UiTheme.CYAN) -> void:
	var s := c.size
	var col := UiTheme.CORAL if warning else accent
	var cut := minf(s.y * 2.0, 10.0)
	var pts := PackedVector2Array([Vector2(cut, 0), Vector2(s.x, 0), Vector2(s.x - cut, s.y), Vector2(0, s.y)]) \
			if index == 0 else PackedVector2Array([Vector2(0, 0), Vector2(s.x - cut, 0), Vector2(s.x, s.y),
			Vector2(cut, s.y)])
	c.draw_colored_polygon(pts, Color(col, 0.95))
	if not warning:
		return
	var x := cut + 4.0
	while x < s.x - cut - 8.0:
		c.draw_colored_polygon(PackedVector2Array([Vector2(x, 0), Vector2(x + 5.0, 0), Vector2(x + 5.0 - s.y, s.y),
				Vector2(x - s.y, s.y)]), Color(UiTheme.ABYSS, 0.8))
		x += 11.0
