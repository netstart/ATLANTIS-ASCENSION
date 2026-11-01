class_name MapScreen
extends Screen
## Mapa da campanha "Carta da Ascensão" (plano mestre 7.3, redesenho 1.6): uma coluna que SOBE do
## abismo à órbita, em profundidade 2,5D. Atrás de tudo, o fundo abissal compartilhado (três terraços de
## ruínas em shader) rola em velocidades próprias com a câmera; por cima, véus de cor por estrato,
## silhuetas distantes, a rota, os nós (faróis chanfrados) e bolhas de primeiro plano. Arrastar rola
## com inércia; ao abrir, a câmera desliza até a próxima missão. Tocar um nó abre o cartão (nome,
## 4 estrelas, recorde, Jogar). O humor da água (cores, ruínas, raios) muda com o estrato no centro.
##
## Coordenadas do mundo: y cresce PARA CIMA a partir do fundo do abismo. Uma camada de fator f
## desenha o ponto (x, y) em tela_y = altura - (y - câmera * f).
##
## Orçamento: com a câmera parada, o desenho do mapa só é refeito a IDLE_HZ (o brilho dos faróis pulsa
## devagar) e os nós não são reposicionados; rolando, tudo anda a cada quadro. O sonar do farol escolhido
## e as luzes que correm pela rota aberta (1.9) ficam numa camada aditiva leve à parte (_Beacon), que
## anda a 60 Hz sem refazer o mapa.

const STRATUM := 760.0
const STRATA := 11
const FACTORS: Array[float] = [0.1, 0.25, 0.5, 1.0, 1.35]
const FRICTION := 4.0
const HEADER := 52.0
const IDLE_HZ := 15.0
const NODE_SIZE := 50.0
## Sonar do farol escolhido: anéis que abrem a cada SONAR_PERIOD s; luz que corre na rota aberta.
const SONAR_PERIOD := 1.6
const SONAR_RINGS := 2
const COMET_SPEED := 0.55
const STRATUM_COLORS: Array[Color] = [Color("040b1a"), Color("0b2a4a"), Color("0f4652"), Color("26364a"),
		Color("3a1410"), Color("141c38"), Color("2c4a5e"), Color("2d5f8a"), Color("0a0f2a"), Color("2a0a26"),
		Color("05060f")]
## Véu de cor de cada estrato sobre o fundo compartilhado: mar quase transparente (as ruínas aparecem),
## céu e espaço quase opacos.
const STRATUM_ALPHA: Array[float] = [0.35, 0.08, 0.12, 0.45, 0.55, 0.5, 0.55, 0.82, 0.9, 0.92, 0.95]
## Humor do fundo (AbyssBackdrop.MOODS) e presença das ruínas por estrato.
const STRATUM_MOODS: Array[StringName] = [&"hadal", &"default", &"calm", &"danger", &"lava", &"calm", &"ice",
		&"sky", &"space", &"space", &"space"]
const STRATUM_RUINS: Array[float] = [1.0, 1.0, 1.0, 0.7, 0.6, 0.8, 0.4, 0.0, 0.0, 0.0, 0.0]
const STRATUM_KEYS: Array[String] = ["map.chapter10", "map.chapter1", "map.chapter2", "map.chapter3", "map.chapter4",
		"map.chapter5", "map.chapter6", "map.chapter7", "map.chapter8", "map.chapter9", ""]
## Rótulo curto do nó por tipo (o tipo também muda a cor do farol).
const KIND_MARK := {&"miniboss": " ◆", &"boss": " ♛", &"secret": " ◎", &"route": ""}

var camera: float = 600.0
var velocity: float = 0.0
var selected: StringName = &""

var _view: _MapView
var _beacon: _Beacon
var _ring: Texture2D
var _back: Button
var _title: Label
var _node_buttons: Dictionary = {}
var _card: PanelContainer
var _card_box: VBoxContainer
var _card_title: Label
var _card_stars: Array[Label] = []
var _card_best: Label
var _card_play: Button
var _target: float = -1.0
## Missão a centralizar assim que a tela tiver tamanho (o primeiro on_show vem antes do layout).
var _focus_y: float = -1.0
var _dragging: bool = false
var _planet: Texture2D
var _glow: Texture2D
var _bold: Font
var _app: App
var _stratum: int = -1
var _drawn_camera: float = -1.0
var _idle_wait: float = 0.0
var _clock: float = 0.0
## Missão que o controle escolheu e ainda está fora da tela: ganha o foco quando a câmera chegar.
var _pad_focus: StringName = &""


func _build() -> void:
	_planet = SpriteBank.texture("res://assets/art/void/environment/planet_earth.png")
	_glow = SpriteBank.generated("fx/glow_32")
	_bold = UiTheme.bold_font()
	_view = _MapView.new(self)
	_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_view)
	_ring = SpriteBank.generated("fx/ring_128")
	_beacon = _Beacon.new(self)
	_beacon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_beacon)
	for n: Dictionary in Economy.CAMPAIGN:
		var b := Button.new()
		b.name = "Node_" + String(n["id"])
		b.custom_minimum_size = Vector2(NODE_SIZE, NODE_SIZE)
		b.size = b.custom_minimum_size
		if _bold != null:
			b.add_theme_font_override("font", _bold)
		b.add_theme_font_size_override("font_size", UiTheme.scaled(UiTheme.FONT_SIZE))
		b.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		b.add_theme_constant_override("icon_max_width", 14)
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		_style_node(b, n, false)
		b.pressed.connect(_on_node.bind(n["id"]))
		b.focus_entered.connect(func() -> void:
			if FocusNav.pad and n["id"] != selected:
				_select(n["id"]))
		add_child(b)
		_node_buttons[n["id"]] = b
	_back = UiTheme.icon_button("arrowLeft", "Back")
	_back.pressed.connect(func() -> void:
		AudioManager.play_ui("kenney_ui_back")
		navigate.emit(&"back"))
	add_child(_back)
	_title = UiTheme.heading("", UiTheme.HEADING_SIZE, UiTheme.WHITE)
	_title.clip_text = true
	_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	add_child(_title)
	_build_card()


func _build_card() -> void:
	_card = PanelContainer.new()
	_card.add_theme_stylebox_override("panel", UiTheme.panel_box(UiTheme.GOLD, 0.92))
	_card_box = VBoxContainer.new()
	_card_box.add_theme_constant_override("separation", 5)
	_card.add_child(_card_box)
	_card_title = UiTheme.heading("", UiTheme.HEADING_SIZE, UiTheme.WHITE)
	_card_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_card_box.add_child(_card_title)
	var rule := ColorRect.new()
	rule.color = Color(UiTheme.GOLD, 0.35)
	rule.custom_minimum_size = Vector2(0, 1)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card_box.add_child(rule)
	for i: int in range(4):
		var star := UiTheme.label("", UiTheme.FONT_SIZE, UiTheme.TEXT, true)
		_card_box.add_child(star)
		_card_stars.append(star)
	_card_best = UiTheme.label("", UiTheme.FONT_SIZE, UiTheme.TEXT_DIM, true)
	_card_box.add_child(_card_best)
	_card_play = Button.new()
	_card_play.name = "PlayMission"
	_card_play.custom_minimum_size = Vector2(0, UiTheme.TOUCH_MIN + 10.0)
	UiTheme.style_primary(_card_play, UiTheme.HEADING_SIZE)
	_card_play.pressed.connect(func() -> void:
		AudioManager.play_ui("kenney_ui_confirm")
		play.emit(selected))
	_card_box.add_child(_card_play)
	_card.visible = false
	add_child(_card)


## Farol de missão: chanfro com cor por tipo (chefe coral, chefe médio dourado, segredo violeta, rota
## ciano); o selecionado ganha borda e halo dourados. Só troca as caixas quando o estado muda.
func _style_node(b: Button, n: Dictionary, chosen: bool) -> void:
	var accent := UiTheme.CYAN
	if n["kind"] == &"boss":
		accent = UiTheme.CORAL
	elif n["kind"] == &"miniboss":
		accent = UiTheme.GOLD
	elif n["kind"] == &"secret":
		accent = UiTheme.VIOLET
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		var box := UiTheme.chamfer(Color(UiTheme.ABYSS, 0.86), Color(accent, 0.8), 2, 12)
		box.set_content_margin_all(2)
		if chosen:
			box.border_color = UiTheme.GOLD
			box.bg_color = Color(UiTheme.RAISED, 0.96)
			box.shadow_color = Color(UiTheme.GOLD, 0.45)
			box.shadow_size = 10
		elif state in ["hover", "focus"]:
			box.shadow_color = Color(accent, 0.4)
			box.shadow_size = 8
		if state == "disabled":
			box.bg_color = Color(UiTheme.ABYSS, 0.72)
			box.border_color = Color(UiTheme.TEXT_DIM, 0.3)
			box.shadow_size = 0
		b.add_theme_stylebox_override(state, box)
	b.add_theme_color_override("font_color", UiTheme.GOLD if chosen else UiTheme.WHITE)
	b.add_theme_color_override("font_hover_color", UiTheme.GOLD if chosen else UiTheme.WHITE)
	b.add_theme_color_override("font_disabled_color", Color(UiTheme.TEXT_DIM, 0.6))
	b.add_theme_color_override("icon_disabled_color", Color(UiTheme.TEXT_DIM, 0.6))
	b.set_meta(&"chosen", chosen)


func on_show(app: Node) -> void:
	_app = app as App
	_stratum = -1
	_drawn_camera = -1.0
	# Câmera desliza até a próxima missão (primeira sem conclusão, ou a última aberta).
	var focus := Economy.node(Economy.next_mission(SaveManager.data))
	var lock := UiTheme.icon("locked")
	for n: Dictionary in Economy.CAMPAIGN:
		var b: Button = _node_buttons[n["id"]]
		b.disabled = not is_open(n["id"])
		b.icon = lock if b.disabled else null
	_focus_y = float(focus["y"])
	_select(focus["id"])
	refresh_texts()


func refresh_texts() -> void:
	_back.tooltip_text = tr("credits.back")
	_title.text = tr("map.title")
	for n: Dictionary in Economy.CAMPAIGN:
		var b: Button = _node_buttons[n["id"]]
		b.text = node_label(n)
		b.tooltip_text = "" if is_open(n["id"]) else tr("map.locked")
	_update_card()
	relayout()


func is_open(id: StringName) -> bool:
	return Economy.mission_unlocked(SaveManager.data, id)


## "1-2 ◆", "3-3 S", "◎": capítulo-missão e marca do tipo.
static func node_label(n: Dictionary) -> String:
	var id := String(n["id"])
	if n["kind"] == &"secret":
		return "◎"
	var text := "%s-%s" % [id.substr(1, 1), id.substr(3, 1)]
	if n.has("route"):
		text += " " + id.substr(4, 1).to_upper()
	return text + String(KIND_MARK.get(n["kind"], ""))


## Toque escolhe a missão; pelo controle, A na missão já escolhida joga (o cartão fica longe do foco).
func _on_node(id: StringName) -> void:
	if FocusNav.pad and id == selected and not _card_play.disabled:
		_card_play.pressed.emit()
		return
	_select(id)


## Pelo controle a tela abre na missão escolhida, assim que a câmera a mostrar.
func default_focus() -> Control:
	_pad_focus = selected
	if _focus_y < 0.0 and size.y > 0.0:
		_target = maxf(0.0, float(Economy.node(selected)["y"]) - size.y * 0.55)
	return null


## Controle e teclado: cima e baixo andam pelas missões abertas (de baixo para cima, como a subida no
## mapa) com a câmera indo junto; baixo na primeira leva ao Jogar do cartão. Esquerda e direita ficam com
## a navegação do Godot (rotas lado a lado).
func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	var step := 1 if event.is_action_pressed("ui_up") else -1 if event.is_action_pressed("ui_down") else 0
	if step == 0:
		return
	var focused := get_viewport().gui_get_focus_owner()
	if focused != null and focused.is_visible_in_tree() and not _node_buttons.values().has(focused):
		return
	get_viewport().set_input_as_handled()
	var order := pad_order()
	if order.is_empty():
		return
	var at := order.find(selected)
	var next := clampi(at + step, 0, order.size() - 1)
	if at >= 0 and next == at:
		if step < 0 and _card.visible:
			_pad_focus = &""
			_card_play.grab_focus()
		return
	_select(order[next])
	_target = maxf(0.0, float(Economy.node(order[next])["y"]) - size.y * 0.55)
	_pad_focus = order[next]


## Missões abertas na ordem da subida (de baixo para cima; empate da esquerda para a direita).
func pad_order() -> Array[StringName]:
	var nodes: Array[Dictionary] = []
	for n: Dictionary in Economy.CAMPAIGN:
		if is_open(n["id"]):
			nodes.append(n)
	nodes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["y"]) < float(b["y"]) or (float(a["y"]) == float(b["y"]) and float(a["x"]) < float(b["x"])))
	var out: Array[StringName] = []
	for n: Dictionary in nodes:
		out.append(StringName(n["id"]))
	return out


func _select(id: StringName) -> void:
	selected = id
	AudioManager.play_ui("kenney_ui_click")
	for n: Dictionary in Economy.CAMPAIGN:
		var b: Button = _node_buttons[n["id"]]
		if bool(b.get_meta(&"chosen", false)) != (n["id"] == id):
			_style_node(b, n, n["id"] == id)
	_drawn_camera = -1.0
	# Cima no Jogar volta para a missão escolhida, não para o farol mais perto.
	_card_play.focus_neighbor_top = _card_play.get_path_to(_node_buttons[id])
	_update_card()
	relayout()


func _update_card() -> void:
	if _card == null or selected == &"":
		return
	_card.visible = true
	var record := SaveManager.mission_record(selected)
	var stars: Array = record["stars"]
	_card_title.text = tr("stage." + String(selected))
	var mission := Sim.load_mission(selected)
	var objective := String((mission.get("objective", {}) as Dictionary).get("text_key", "star.all_marked"))
	var texts := [tr("star.clear"), tr("star.no_damage"), tr("star.all_marked"), tr(objective)]
	for i: int in range(4):
		var got := i < stars.size() and bool(stars[i])
		_card_stars[i].text = ("★  " if got else "☆  ") + texts[i]
		_card_stars[i].add_theme_color_override("font_color", UiTheme.GOLD if got else UiTheme.TEXT_DIM)
	_card_best.text = tr("map.best") % Locale.format_number(int(record["best_score"]))
	var grade := int(record.get("grade", Grade.NONE))
	if grade != Grade.NONE:
		_card_best.text += "   ·   " + tr("map.grade") % Grade.letter(grade)
	var n := Economy.node(selected)
	if n.has("route"):
		_card_best.text += "\n" + tr("map.route_" + String(n["route"]))
	elif n["kind"] == &"secret":
		_card_best.text += "\n" + tr("map.secret_hint")
	_card_play.disabled = not is_open(selected)
	_card_play.text = tr("boot.play").to_upper() if is_open(selected) else tr("map.locked")


func _layout() -> void:
	if _card == null:
		return
	_back.size = _back.custom_minimum_size
	_back.position = Vector2(safe.position.x + 8.0, safe.position.y + 8.0)
	_title.position = Vector2(_back.position.x + _back.size.x + 10.0, safe.position.y + 14.0)
	_title.size = Vector2(maxf(0.0, safe.end.x - 8.0 - _title.position.x), 0)
	var width := minf(safe.size.x - 16.0, 340.0)
	# Rótulos com quebra precisam da largura antes do cálculo da altura do cartão.
	var inner := width - 24.0
	for label: Label in [_card_title, _card_best] + _card_stars:
		label.custom_minimum_size.x = inner
	_card.size = Vector2(width, 0)
	_card.reset_size()
	_card.size.x = width
	_card.position = Vector2(floorf(safe.position.x + (safe.size.x - width) * 0.5), safe.end.y - _card.size.y - 8.0)
	_drawn_camera = -1.0
	_place_nodes()


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_clock += delta
	if _focus_y >= 0.0 and size.y > 0.0:
		_target = maxf(0.0, _focus_y - size.y * 0.55)
		camera = maxf(0.0, _target - 320.0)
		_focus_y = -1.0
	if _target >= 0.0 and not _dragging:
		camera = lerpf(camera, _target, minf(1.0, delta * 3.5))
		if absf(camera - _target) < 0.5:
			camera = _target
			_target = -1.0
	elif not _dragging and absf(velocity) > 1.0:
		camera += velocity * delta
		velocity = lerpf(velocity, 0.0, minf(1.0, delta * FRICTION))
	camera = clampf(camera, 0.0, maxf(0.0, STRATUM * STRATA - size.y))
	_sync_backdrop()
	_beacon.queue_redraw()
	# Foco do controle no farol assim que ele aparece; no caminho da câmera ele pode sumir de novo (e
	# sumir solta o foco), então o pedido só termina com a câmera parada.
	if _pad_focus != &"":
		var node := _node_buttons[_pad_focus] as Control
		if node.is_visible_in_tree() and not node.has_focus():
			node.grab_focus()
		if _target < 0.0 and _focus_y < 0.0 and node.has_focus():
			_pad_focus = &""
	# Câmera andando: nós e desenho a cada quadro. Parada: só o pulso dos faróis, a IDLE_HZ.
	if camera != _drawn_camera:
		_drawn_camera = camera
		_place_nodes()
		_view.queue_redraw()
		return
	_idle_wait -= delta
	if _idle_wait <= 0.0:
		_idle_wait = 1.0 / IDLE_HZ
		_view.queue_redraw()


## O fundo compartilhado anda com a câmera (ruínas em três profundidades) e muda de humor por estrato.
func _sync_backdrop() -> void:
	if _app == null:
		return
	var backdrop := _app.backdrop()
	backdrop.scroll = -camera
	var s := clampi(floori((camera + size.y * 0.5) / STRATUM), 0, STRATA - 1)
	if s == _stratum:
		return
	_stratum = s
	backdrop.set_mood(STRATUM_MOODS[s])
	var tween := create_tween()
	tween.tween_property(backdrop, "ruins", STRATUM_RUINS[s], 0.8).set_trans(Tween.TRANS_SINE)


## Rolagem pelo dedo (o _MapView repassa): arrastar para baixo revela o que está acima.
func drag(relative_y: float, pressed: bool) -> void:
	_dragging = pressed
	_target = -1.0
	if pressed:
		camera += relative_y
		velocity = relative_y * 60.0
	TouchScroll.mark_moving()


func screen_y(world_y: float, factor: float) -> float:
	return size.y - (world_y - camera * factor)


func _place_nodes() -> void:
	for n: Dictionary in Economy.CAMPAIGN:
		var b: Button = _node_buttons[n["id"]]
		var at := Vector2(size.x * float(n["x"]), screen_y(float(n["y"]), 1.0))
		b.position = (at - b.size * 0.5).floor()
		var on_screen := at.y - b.size.y * 0.5 > safe.position.y + HEADER and at.y < size.y + 40.0
		b.visible = on_screen and (n["kind"] != &"secret" or not b.disabled)


func layout_controls() -> Array[Control]:
	var list: Array[Control] = [_back, _title, _card]
	return list


func draw_map(ci: CanvasItem) -> void:
	var w := size.x
	var h := size.y
	# 0: véus de cor por estrato (fator 0,1) sobre o fundo compartilhado, com degradê na passagem.
	for s: int in range(STRATA):
		var y0 := screen_y((s + 1) * STRATUM, FACTORS[0])
		var y1 := screen_y(s * STRATUM, FACTORS[0])
		if y1 < 0.0 or y0 > h:
			continue
		ci.draw_rect(Rect2(0, y0, w, y1 - y0 + 1.0), Color(STRATUM_COLORS[s], STRATUM_ALPHA[s]))
	for s: int in range(1, STRATA):
		var by := screen_y(s * STRATUM, FACTORS[0])
		if by < -80.0 or by > h + 80.0:
			continue
		ci.draw_texture_rect(_glow, Rect2(-w * 0.2, by - 70.0, w * 1.4, 140.0), false, Color(0.4, 0.85, 1.0, 0.14))
	# 1: silhuetas distantes (montes submarinos, torres, ilhas) na neblina, e o planeta no alto.
	for i: int in range(24):
		var y := screen_y(120.0 + i * 160.0, FACTORS[1])
		if y < -120.0 or y > h + 120.0:
			continue
		var x := fmod(float(absi(hash(i * 13)) % 1000) / 1000.0 * w * 1.4, w)
		var tall := 40.0 + float(absi(hash(i * 17)) % 70)
		var wide := 30.0 + float(absi(hash(i * 23)) % 30)
		ci.draw_rect(Rect2(x - wide * 0.5, y - tall, wide, tall), Color(0.02, 0.07, 0.14, 0.55))
		ci.draw_rect(Rect2(x - wide * 0.5 - 4.0, y - tall - 3.0, wide + 8.0, 3.0), Color(0.02, 0.07, 0.14, 0.55))
		ci.draw_rect(Rect2(x - wide * 0.5, y - tall, wide, 1.0), Color(0.3, 0.8, 0.9, 0.22))
	if _planet != null:
		var py := screen_y(STRATUM * STRATA - 260.0, FACTORS[1])
		if py > -100.0 and py < h + 100.0:
			ci.draw_texture_rect(_glow, Rect2(w * 0.5 - 130.0, py - 130.0, 260.0, 260.0), false, Color(0.4, 0.7, 1.0, 0.3))
			ci.draw_texture_rect_region(_planet, Rect2(w * 0.5 - 72.0, py - 72.0, 144.0, 144.0), Rect2(0, 0, 96, 96))
	# 2: correntes de luz no meio (fator 0,5).
	for i: int in range(30):
		var y := screen_y(80.0 + i * 120.0, FACTORS[2])
		if y < -40.0 or y > h + 40.0:
			continue
		var x := fmod(float(absi(hash(i * 29)) % 1000) / 1000.0 * w + _clock * (6.0 + i % 4), w + 60.0) - 30.0
		ci.draw_rect(Rect2(x, y, 26.0 + float(i % 3) * 14.0, 2.0), Color(0.5, 0.9, 1.0, 0.07 + 0.04 * float(i % 2)))
	# Rótulos dos estratos (na camada da rota): chapéu ciano em negrito com um traço.
	var label_font := _bold if _bold != null else Locale.font
	for s: int in range(STRATA):
		if STRATUM_KEYS[s].is_empty():
			continue
		var ly := screen_y(s * STRATUM + 40.0, 1.0)
		if ly > safe.position.y + HEADER + 12.0 and ly < h:
			var text := tr(STRATUM_KEYS[s]).to_upper()
			ci.draw_rect(Rect2(safe.position.x + 12.0, ly + 5.0, 28.0, 2.0), UiTheme.CYAN)
			ci.draw_string(label_font, Vector2(safe.position.x + 12.0, ly), text, HORIZONTAL_ALIGNMENT_LEFT,
					safe.size.x - 24.0, UiTheme.scaled(UiTheme.SMALL_SIZE + 1), Color(UiTheme.CYAN, 0.85))
	# 3: rota (traços: dourado aberto, cinza fechado) e halos dos faróis (fator 1,0).
	for n: Dictionary in Economy.CAMPAIGN:
		var open := is_open(n["id"])
		for prev: Variant in [] if bool(n.get("bridge", false)) else n["after"]:
			var pn := Economy.node(prev)
			var a := Vector2(w * float(pn["x"]), screen_y(float(pn["y"]), 1.0))
			var b := Vector2(w * float(n["x"]), screen_y(float(n["y"]), 1.0))
			if maxf(a.y, b.y) < -20.0 or minf(a.y, b.y) > h + 20.0:
				continue
			var col := Color(UiTheme.GOLD, 0.85) if open else Color(0.45, 0.55, 0.65, 0.4)
			var steps := maxi(4, int(a.distance_to(b) / 9.0))
			for d: int in range(steps):
				var p := a.lerp(b, (d + 0.5) / steps)
				ci.draw_rect(Rect2(p - Vector2(1.5, 1.5), Vector2(3, 3)), col)
	var pulse := 0.6 + 0.4 * sin(_clock * 2.4)
	for n: Dictionary in Economy.CAMPAIGN:
		var open := is_open(n["id"])
		if n["kind"] == &"secret" and not open:
			continue
		var c := Vector2(w * float(n["x"]), screen_y(float(n["y"]), 1.0))
		if c.y < -60.0 or c.y > h + 60.0:
			continue
		var base := UiTheme.CYAN
		if n["kind"] == &"boss":
			base = UiTheme.CORAL
		elif n["kind"] == &"miniboss":
			base = UiTheme.GOLD
		elif n["kind"] == &"secret":
			base = UiTheme.VIOLET
		var col := Color(base, 0.45 * pulse) if open else Color(0.3, 0.4, 0.5, 0.18)
		var r := 46.0
		if n["id"] == selected:
			col = Color(UiTheme.GOLD, 0.75 * pulse)
			r = 58.0
		ci.draw_texture_rect(_glow, Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0), false, col)
	# 4: bolhas de primeiro plano (fator 1,35), redondas e suaves.
	for i: int in range(40):
		var y := screen_y(40.0 + i * 95.0, FACTORS[4])
		if y < -10.0 or y > h + 10.0:
			continue
		var x := fmod(float(absi(hash(i * 41)) % 1000) / 1000.0 * w + sin(_clock + i) * 3.0, w)
		var rr := 2.0 + float(i % 3)
		ci.draw_texture_rect(_glow, Rect2(x - rr, y - rr, rr * 2.0, rr * 2.0), false, Color(0.75, 0.95, 1.0, 0.35))
	# Cabeçalho: faixa escura com filete ciano para o título ler sobre qualquer estrato.
	var head := safe.position.y + HEADER
	ci.draw_rect(Rect2(0, 0, w, head), Color(UiTheme.ABYSS, 0.72))
	ci.draw_rect(Rect2(0, head, w, 1.0), Color(UiTheme.CYAN, 0.3))


## Camada aditiva por cima da rota: luzes que sobem pelos traços abertos até cada farol e o sonar do
## farol escolhido (dois anéis que abrem e somem).
func draw_beacon(ci: CanvasItem) -> void:
	var w := size.x
	var h := size.y
	for n: Dictionary in Economy.CAMPAIGN:
		if bool(n.get("bridge", false)) or not is_open(n["id"]):
			continue
		var b := Vector2(w * float(n["x"]), screen_y(float(n["y"]), 1.0))
		for prev: Variant in n["after"]:
			var pn := Economy.node(prev)
			var a := Vector2(w * float(pn["x"]), screen_y(float(pn["y"]), 1.0))
			if maxf(a.y, b.y) < -20.0 or minf(a.y, b.y) > h + 20.0:
				continue
			var u := fposmod(_clock * COMET_SPEED + float(absi(hash(String(n["id"]))) % 100) / 100.0, 1.0)
			var p := a.lerp(b, u)
			var fade := sin(u * PI)
			ci.draw_texture_rect(_glow, Rect2(p - Vector2(9, 9), Vector2(18, 18)), false, Color(UiTheme.GOLD, 0.55 * fade))
			ci.draw_texture_rect(_glow, Rect2(p - Vector2(3, 3), Vector2(6, 6)), false, Color(1.0, 0.97, 0.85, fade))
	if selected == &"":
		return
	var chosen := Economy.node(selected)
	var c := Vector2(w * float(chosen["x"]), screen_y(float(chosen["y"]), 1.0))
	if c.y < -80.0 or c.y > h + 80.0:
		return
	for k: int in range(SONAR_RINGS):
		var u := fposmod(_clock / SONAR_PERIOD + float(k) / SONAR_RINGS, 1.0)
		var r := NODE_SIZE * (0.55 + 0.9 * (1.0 - pow(1.0 - u, 2.0)))
		var flat := Vector2(r, r * 0.62)
		ci.draw_texture_rect(_ring, Rect2(c - flat, flat * 2.0), false, Color(UiTheme.GOLD, 0.7 * (1.0 - u)))


class _Beacon:
	extends Control

	var _map: MapScreen

	func _init(map: MapScreen) -> void:
		_map = map
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		var add := CanvasItemMaterial.new()
		add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = add

	func _draw() -> void:
		_map.draw_beacon(self)


## Área de desenho e arrasto do mapa.
class _MapView:
	extends Control

	var _map: MapScreen

	func _init(map: MapScreen) -> void:
		_map = map
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventScreenDrag:
			_map.drag((event as InputEventScreenDrag).relative.y, true)
			accept_event()
		elif event is InputEventScreenTouch and not (event as InputEventScreenTouch).pressed:
			_map.drag(0.0, false)
			accept_event()

	func _draw() -> void:
		_map.draw_map(self)
