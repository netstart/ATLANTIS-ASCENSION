class_name HudObjective
extends PanelContainer
## Marcador compacto do objetivo de fase em curso (SimObjectives) no HUD da partida (GameHud): ícone do alvo, título
## curto com a contagem ("Resgate 2/5") e, na sabotagem, a barra do prazo. Em retrato fica na borda do campo oposta
## à pilha de botões, abaixo do rádio; no desktop, no painel lateral, embaixo do placar.
## Só troca texto e ícone quando o valor muda; a cada quadro anda só o tamanho da barra do prazo.

const ICON := 14.0
const BAR_H := 2.0
## Altura em retrato (fração do campo): abaixo do rádio e acima da pilha de botões em todas as alturas de campo.
const PORTRAIT_Y := 0.22
const ICONS := {&"rescue": "pickups/survivor", &"sabotage": "enemies/protocol_beacon", &"intercept": "pickups/relic"}
const TITLES := {&"rescue": "mini.rescue", &"sabotage": "mini.sabotage", &"intercept": "mini.intercept"}

var label: Label
var _icon: TextureRect
var _track: ColorRect
var _fill: ColorRect
var _key := ""
## Canto de referência: borda direita (retrato destro) ou esquerda (canhoto e desktop) e o topo.
var _anchor := Vector2.ZERO
var _from_right := true


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	var box := UiTheme.panel_box(UiTheme.GOLD, 0.72)
	box.set_content_margin_all(4)
	box.content_margin_left = 5
	box.content_margin_right = 6
	add_theme_stylebox_override("panel", box)
	var row := HudKit.ignore(HBoxContainer.new()) as HBoxContainer
	row.add_theme_constant_override("separation", 4)
	add_child(row)
	_icon = HudKit.ignore(TextureRect.new()) as TextureRect
	_icon.custom_minimum_size = Vector2(ICON, ICON)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_icon)
	var col := HudKit.ignore(VBoxContainer.new()) as VBoxContainer
	col.add_theme_constant_override("separation", 1)
	row.add_child(col)
	label = UiTheme.heading("", UiTheme.SMALL_SIZE, UiTheme.GOLD)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(label)
	_track = HudKit.ignore(ColorRect.new()) as ColorRect
	_track.color = Color(UiTheme.ABYSS, 0.8)
	_track.custom_minimum_size = Vector2(0, BAR_H)
	col.add_child(_track)
	_fill = HudKit.ignore(ColorRect.new()) as ColorRect
	_fill.color = UiTheme.CORAL
	_track.add_child(_fill)


## Lugar do marcador. Retrato: na borda do campo oposta à pilha (`left_handed` põe a pilha à direita); desktop: no
## painel lateral à direita do campo, embaixo do placar (`panel_bottom`).
func place(field: Rect2, portrait: bool, left_handed: bool, panel_bottom: float) -> void:
	if portrait:
		_from_right = not left_handed
		_anchor = Vector2(field.end.x - 6.0 if _from_right else field.position.x + 6.0,
				field.position.y + floorf(field.size.y * PORTRAIT_Y))
	else:
		_from_right = false
		_anchor = Vector2(field.end.x + 12.0, panel_bottom + 8.0)
	_fit()


## Uma vez por quadro (GameHud.refresh): aparece com o aviso, troca o texto na mudança e anda a barra do prazo.
func refresh(sim: Sim) -> void:
	var p := sim.objectives.progress()
	visible = not p.is_empty()
	if not visible:
		_key = ""
		return
	var kind := StringName(p["type"])
	var key := "%s|%d|%d" % [kind, int(p["done"]), int(p["total"])]
	if key != _key:
		_key = key
		_icon.texture = SpriteBank.generated(String(ICONS.get(kind, "pickups/relic")))
		label.text = "%s %d/%d" % [tr(String(TITLES.get(kind, ""))), int(p["done"]), int(p["total"])]
		_track.visible = float(p["left"]) >= 0.0
		_fit()
	if _track.visible:
		_fill.size = Vector2(_track.size.x * clampf(float(p["left"]) / maxf(0.01, float(p["limit"])), 0.0, 1.0),
				BAR_H)
	# Durante o aviso pisca de leve: o alvo ainda vai entrar.
	modulate.a = 0.65 + 0.35 * absf(sin(sim.frame * 0.1)) if bool(p["warn"]) else 1.0


func _fit() -> void:
	reset_size()
	size = get_combined_minimum_size()
	position = Vector2(_anchor.x - size.x if _from_right else _anchor.x, _anchor.y).floor()
