class_name MapScreen
extends Screen
## Mapa da campanha "Carta da Ascensão" (plano mestre 7.3): uma coluna que SOBE do abismo à órbita,
## em 6 camadas de parallax. Arrastar rola com inércia; ao abrir, a câmera desliza até a próxima
## missão. Tocar um nó abre o cartão (nome, 4 estrelas, recorde, Jogar).
##
## Coordenadas do mundo: y cresce PARA CIMA a partir do fundo do abismo. Uma camada de fator f
## desenha o ponto (x, y) em tela_y = altura - (y - câmera * f). As camadas de fundo são retângulos e
## texturas por quadro, redesenhadas só quando a câmera anda (ou a 30 Hz para o brilho dos nós).

const STRATUM := 760.0
const STRATA := 11
const FACTORS: Array[float] = [0.1, 0.25, 0.5, 1.0, 1.35]
const FRICTION := 4.0
const HEADER := 48.0
const STRATUM_COLORS: Array[Color] = [Color("040b1a"), Color("0b2a4a"), Color("0f4652"), Color("26364a"),
		Color("3a1410"), Color("141c38"), Color("2c4a5e"), Color("2d5f8a"), Color("0a0f2a"), Color("2a0a26"),
		Color("05060f")]
const STRATUM_KEYS: Array[String] = ["", "map.chapter1", "map.chapter2", "map.chapter3", "map.chapter4",
		"map.chapter5", "map.chapter6", "map.chapter7", "map.chapter8", "map.chapter9", ""]
## Rótulo curto do nó por tipo (o tipo também muda a cor do brilho).
const KIND_MARK := {&"miniboss": " ◆", &"boss": " ♛", &"secret": " ◎", &"route": ""}

var camera: float = 600.0
var velocity: float = 0.0
var selected: StringName = &""
## Modo foto: esconde a interface e deixa só as camadas do mapa (arrastar continua rolando).
var photo_mode: bool = false

var _view: _MapView
var _back: Button
var _photo: Button
var _photo_bar: HBoxContainer
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


func _build() -> void:
	_planet = SpriteBank.texture("res://assets/art/void/environment/planet_earth.png")
	_glow = SpriteBank.generated("fx/glow_32")
	_view = _MapView.new(self)
	_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_view)
	for n: Dictionary in Economy.CAMPAIGN:
		var b := Button.new()
		b.name = "Node_" + String(n["id"])
		b.custom_minimum_size = Vector2(56, 56)
		b.pressed.connect(_select.bind(n["id"]))
		add_child(b)
		_node_buttons[n["id"]] = b
	_back = Button.new()
	_back.name = "Back"
	_back.custom_minimum_size = Vector2(72, UiTheme.TOUCH_MIN)
	_back.pressed.connect(func() -> void: navigate.emit(&"back"))
	add_child(_back)
	_photo = Button.new()
	_photo.name = "Photo"
	_photo.custom_minimum_size = Vector2(UiTheme.TOUCH_MIN + 20.0, UiTheme.TOUCH_MIN)
	_photo.pressed.connect(func() -> void: set_photo_mode(true))
	add_child(_photo)
	_photo_bar = HBoxContainer.new()
	_photo_bar.add_theme_constant_override("separation", 8)
	for entry: Array in [["Save", save_photo], ["Exit", func() -> void: set_photo_mode(false)]]:
		var b := Button.new()
		b.name = entry[0]
		b.custom_minimum_size = Vector2(96, UiTheme.TOUCH_MIN)
		b.pressed.connect(entry[1])
		_photo_bar.add_child(b)
	_photo_bar.visible = false
	add_child(_photo_bar)
	_title = UiTheme.label("", UiTheme.HEADING_SIZE, UiTheme.GOLD)
	_title.add_theme_color_override("font_outline_color", UiTheme.VOLCANIC)
	_title.add_theme_constant_override("outline_size", 4)
	_title.clip_text = true
	add_child(_title)
	_build_card()


func _build_card() -> void:
	_card = PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(UiTheme.ABYSS, 0.95)
	box.border_color = UiTheme.GOLD
	box.set_border_width_all(1)
	box.set_corner_radius_all(4)
	box.set_content_margin_all(12)
	_card.add_theme_stylebox_override("panel", box)
	_card_box = VBoxContainer.new()
	_card_box.add_theme_constant_override("separation", 6)
	_card.add_child(_card_box)
	_card_title = UiTheme.label("", UiTheme.HEADING_SIZE, UiTheme.GOLD, true)
	_card_box.add_child(_card_title)
	for i: int in range(4):
		var star := UiTheme.label("", UiTheme.FONT_SIZE, UiTheme.TEXT, true)
		_card_box.add_child(star)
		_card_stars.append(star)
	_card_best = UiTheme.label("", UiTheme.FONT_SIZE, UiTheme.TEXT_DIM)
	_card_box.add_child(_card_best)
	_card_play = Button.new()
	_card_play.name = "PlayMission"
	_card_play.custom_minimum_size = Vector2(0, UiTheme.TOUCH_MIN + 6.0)
	_card_play.pressed.connect(func() -> void: play.emit(selected))
	_card_box.add_child(_card_play)
	_card.visible = false
	add_child(_card)


func on_show(_app: Node) -> void:
	# Câmera desliza até a próxima missão (primeira sem conclusão, ou a última aberta).
	var focus := Economy.node(Economy.next_mission(SaveManager.data))
	for n: Dictionary in Economy.CAMPAIGN:
		var b: Button = _node_buttons[n["id"]]
		b.disabled = not is_open(n["id"])
	_focus_y = float(focus["y"])
	_select(focus["id"])
	refresh_texts()


func refresh_texts() -> void:
	_back.text = tr("credits.back")
	_title.text = tr("map.title")
	_photo.text = tr("map.photo")
	(_photo_bar.get_node("Save") as Button).text = tr("map.photo_save")
	(_photo_bar.get_node("Exit") as Button).text = tr("map.photo_exit")
	for n: Dictionary in Economy.CAMPAIGN:
		var b: Button = _node_buttons[n["id"]]
		b.text = node_label(n)
		b.tooltip_text = "" if is_open(n["id"]) else tr("map.locked")
	_card_play.text = tr("boot.play")
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


func _select(id: StringName) -> void:
	selected = id
	AudioManager.play_ui("kenney_ui_click")
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
		_card_stars[i].text = ("★ " if got else "☆ ") + texts[i]
		_card_stars[i].add_theme_color_override("font_color", UiTheme.GOLD if got else UiTheme.TEXT_DIM)
	_card_best.text = tr("map.best") % Locale.format_number(int(record["best_score"]))
	var n := Economy.node(selected)
	if n.has("route"):
		_card_best.text += "\n" + tr("map.route_" + String(n["route"]))
	elif n["kind"] == &"secret":
		_card_best.text += "\n" + tr("map.secret_hint")
	_card_play.disabled = not is_open(selected)
	_card_play.text = tr("boot.play") if is_open(selected) else tr("map.locked")


func _layout() -> void:
	if _card == null:
		return
	_back.position = Vector2(safe.position.x + 8.0, safe.position.y + 6.0)
	_photo.reset_size()
	_photo.position = Vector2(safe.end.x - _photo.size.x - 8.0, safe.position.y + 6.0)
	_title.position = Vector2(_back.position.x + 84.0, safe.position.y + 10.0)
	_title.size = Vector2(maxf(0.0, _photo.position.x - 8.0 - _title.position.x), 0)
	_photo_bar.reset_size()
	_photo_bar.position = Vector2(floorf(safe.position.x + (safe.size.x - _photo_bar.size.x) * 0.5),
			safe.end.y - _photo_bar.size.y - 10.0)
	var width := minf(safe.size.x - 16.0, 320.0)
	# Rótulos com quebra precisam da largura antes do cálculo da altura do cartão.
	var inner := width - 24.0
	_card_title.custom_minimum_size.x = inner
	for star: Label in _card_stars:
		star.custom_minimum_size.x = inner
	_card.size = Vector2(width, 0)
	_card.reset_size()
	_card.size.x = width
	_card.position = Vector2(floorf(safe.position.x + (safe.size.x - width) * 0.5), safe.end.y - _card.size.y - 8.0)
	_place_nodes()


func _process(delta: float) -> void:
	if _focus_y >= 0.0 and size.y > 0.0:
		_target = maxf(0.0, _focus_y - size.y * 0.55)
		camera = maxf(0.0, _target - 320.0)
		_focus_y = -1.0
	if _target >= 0.0 and not _dragging:
		camera = lerpf(camera, _target, minf(1.0, delta * 3.5))
		if absf(camera - _target) < 0.5:
			_target = -1.0
	elif not _dragging and absf(velocity) > 1.0:
		camera += velocity * delta
		velocity = lerpf(velocity, 0.0, minf(1.0, delta * FRICTION))
	camera = clampf(camera, 0.0, STRATUM * STRATA - size.y)
	_place_nodes()
	_view.queue_redraw()


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
		b.reset_size()
		var at := Vector2(size.x * float(n["x"]), screen_y(float(n["y"]), 1.0))
		b.position = (at - b.size * 0.5).floor()
		var on_screen := at.y - b.size.y * 0.5 > safe.position.y + HEADER and at.y < size.y + 40.0
		b.visible = on_screen and (n["kind"] != &"secret" or not b.disabled)


func layout_controls() -> Array[Control]:
	var list: Array[Control] = [_back, _title, _card, _photo]
	return list


## Liga ou desliga o modo foto (plano mestre Fase 4): só o mapa em parallax e os botões Salvar/Sair.
func set_photo_mode(on: bool) -> void:
	photo_mode = on
	for c: Control in [_back, _title, _card, _photo]:
		c.visible = not on if c != _card else (not on and selected != &"")
	for b: Button in _node_buttons.values():
		b.modulate.a = 0.0 if on else 1.0
	_photo_bar.visible = on
	AudioManager.play_ui("kenney_ui_click")


## Salva a tela (sem a barra do modo foto) em user://photos/ e devolve o caminho.
func save_photo() -> String:
	_photo_bar.visible = false
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	_photo_bar.visible = photo_mode
	DirAccess.make_dir_recursive_absolute("user://photos")
	var path := "user://photos/atlantis_%d.png" % Time.get_unix_time_from_system()
	image.save_png(path)
	AudioManager.play_ui("kenney_ui_confirm")
	return path


func draw_map(ci: CanvasItem) -> void:
	var w := size.x
	var h := size.y
	# 0: céu e mar em faixas por estrato (fator 0,1).
	for s: int in range(STRATA):
		var y0 := screen_y((s + 1) * STRATUM, FACTORS[0])
		var y1 := screen_y(s * STRATUM, FACTORS[0])
		ci.draw_rect(Rect2(0, y0, w, y1 - y0 + 1.0), STRATUM_COLORS[s])
	# Brilho de horizonte em cada passagem de estrato (onde o mar vira céu, o céu vira espaço).
	for s: int in range(1, STRATA):
		var by := screen_y(s * STRATUM, FACTORS[0])
		ci.draw_texture_rect(_glow, Rect2(-w * 0.2, by - 60.0, w * 1.4, 120.0), false, Color(0.4, 0.85, 1.0, 0.12))
	# 1: silhuetas distantes (montanhas submarinas, torres, ilhas) e o planeta no alto.
	for i: int in range(24):
		var wy := 120.0 + i * 160.0
		var y := screen_y(wy, FACTORS[1])
		if y < -120.0 or y > h + 120.0:
			continue
		var x := fmod(float(absi(hash(i * 13)) % 1000) / 1000.0 * w * 1.4, w)
		var tall := 40.0 + float(absi(hash(i * 17)) % 70)
		ci.draw_rect(Rect2(x - 22.0, y - tall, 44.0, tall), Color(0.02, 0.07, 0.14, 0.75))
		ci.draw_rect(Rect2(x - 22.0, y - tall, 44.0, 2.0), Color(0.3, 0.8, 0.9, 0.18))
	if _planet != null:
		var py := screen_y(STRATUM * STRATA - 260.0, FACTORS[1])
		ci.draw_texture_rect_region(_planet, Rect2(w * 0.5 - 72.0, py - 72.0, 144.0, 144.0), Rect2(0, 0, 96, 96))
	# 2: ruínas e nuvens no meio (fator 0,5).
	for i: int in range(30):
		var y := screen_y(80.0 + i * 120.0, FACTORS[2])
		if y < -40.0 or y > h + 40.0:
			continue
		var x := fmod(float(absi(hash(i * 29)) % 1000) / 1000.0 * w, w)
		ci.draw_rect(Rect2(x, y, 26.0 + float(i % 3) * 12.0, 6.0), Color(0.5, 0.8, 0.9, 0.08 + 0.04 * float(i % 2)))
	# Rótulos dos estratos (na camada da rota).
	for s: int in range(STRATA):
		if STRATUM_KEYS[s].is_empty():
			continue
		var ly := screen_y(s * STRATUM + 40.0, 1.0)
		if ly > safe.position.y + HEADER + 12.0 and ly < h:
			ci.draw_string(Locale.font, Vector2(safe.position.x + 12.0, ly), tr(STRATUM_KEYS[s]),
					HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.FONT_SIZE, Color(UiTheme.TEXT, 0.75))
	# 3: rota e nós (fator 1,0).
	for n: Dictionary in Economy.CAMPAIGN:
		var open := is_open(n["id"])
		for prev: Variant in n["after"]:
			var pn := Economy.node(prev)
			var a := Vector2(w * float(pn["x"]), screen_y(float(pn["y"]), 1.0))
			var b := Vector2(w * float(n["x"]), screen_y(float(n["y"]), 1.0))
			for d: int in range(12):
				var p := a.lerp(b, (d + 0.5) / 12.0)
				ci.draw_rect(Rect2(p - Vector2(1.5, 1.5), Vector2(3, 3)), UiTheme.GOLD if open else Color(0.4, 0.5, 0.6, 0.5))
	var pulse := 0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.004)
	for n: Dictionary in Economy.CAMPAIGN:
		var open := is_open(n["id"])
		if n["kind"] == &"secret" and not open:
			continue
		var c := Vector2(w * float(n["x"]), screen_y(float(n["y"]), 1.0))
		var base := Color(0.3, 0.95, 1.0)
		if n["kind"] == &"boss":
			base = UiTheme.CORAL
		elif n["kind"] == &"secret":
			base = Color(0.75, 0.55, 1.0)
		var col := Color(base, 0.5 * pulse) if open else Color(0.3, 0.4, 0.5, 0.25)
		if n["id"] == selected:
			col = Color(1.0, 0.85, 0.4, 0.7 * pulse)
		ci.draw_texture_rect(_glow, Rect2(c - Vector2(44, 44), Vector2(88, 88)), false, col)
	# 4: bolhas e nuvens rasantes de primeiro plano (fator 1,35).
	for i: int in range(40):
		var y := screen_y(40.0 + i * 95.0, FACTORS[4])
		if y < -10.0 or y > h + 10.0:
			continue
		var x := fmod(float(absi(hash(i * 41)) % 1000) / 1000.0 * w, w)
		ci.draw_rect(Rect2(x, y, 3.0, 3.0), Color(0.75, 0.95, 1.0, 0.2))
	# Cabeçalho escuro para o título ler sobre qualquer estrato.
	ci.draw_rect(Rect2(0, 0, w, safe.position.y + HEADER), Color(UiTheme.ABYSS, 0.75))


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
