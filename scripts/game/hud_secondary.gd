class_name HudSecondary
extends Control
## Nível da secundária na fase (SecondaryFire, revisão 10 da Sim) no HUD: logo abaixo dos degraus da arma principal
## (filho deles: herda posição e alfa da pilha), um glifo da secundária (foguete ou drone) e 5 degraus menores, os 3
## primeiros em ciano (quantidade) e os 2 últimos em ouro (Ogiva I e II). Some quando a nave não tem secundária (o
## lançador do mar não tem nível). Redesenha só na troca de nível; na subida pulsa e acende em ouro (o som é o
## "fx_power_up" do orbe, tocado pelo Game).

const PIP_W := 6.0
const PIP_H := 4.0
const PIP_GAP := 2.0
const ICON_W := 8.0
const ICON_H := 8.0
## Degraus que contam quantidade (ciano); os de cima são das ogivas (ouro).
const COUNT_PIPS := 3

var _level: int = -1
var _kind: StringName = &""
var _tween: Tween


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(ICON_W + 3.0 + SecondaryFire.MAX_LEVEL * (PIP_W + PIP_GAP), ICON_H)
	pivot_offset = size * 0.5


## `right_align`: o bloco da arma encosta na borda direita (mão esquerda); o nível acompanha.
func refresh(sim: Sim, right_align: bool) -> void:
	visible = SecondaryFire.shown(sim)
	if not visible:
		return
	var parent := get_parent() as Control
	position = Vector2(parent.size.x - size.x if right_align else 0.0, HudKit.PIP_H + 3.0)
	var kind := sim.secondary if sim.secondary != &"" else &"missiles"
	if sim.secondary_level == _level and kind == _kind:
		return
	if sim.secondary_level > _level and _level > 0 and kind == _kind and not UiFx.reduced():
		_tween = HudKit.pop(self, _tween, 1.4, Color(1.6, 1.4, 0.8), Color(1, 1, 1), 0.45)
	_level = sim.secondary_level
	_kind = kind
	queue_redraw()


func _draw() -> void:
	var gold := _level >= SecondaryFire.MAX_LEVEL
	var icon := UiTheme.GOLD if gold else UiTheme.TEXT
	var c := Vector2(ICON_W * 0.5, ICON_H * 0.5)
	if _kind == &"drones":
		draw_circle(c, 3.0, icon)
		draw_circle(c, 1.2, UiTheme.ABYSS)
	else:
		# Foguete de lado, bico para a direita (a fila de degraus segue a direção dele).
		draw_colored_polygon(PackedVector2Array([Vector2(0, c.y - 2.0), Vector2(5.0, c.y - 2.0), Vector2(ICON_W, c.y),
				Vector2(5.0, c.y + 2.0), Vector2(0, c.y + 2.0)]), icon)
		draw_rect(Rect2(0, c.y - 3.5, 2.0, 7.0), icon)
	var y := floorf((ICON_H - PIP_H) * 0.5)
	for i: int in range(SecondaryFire.MAX_LEVEL):
		var x := ICON_W + 3.0 + i * (PIP_W + PIP_GAP)
		var lit := UiTheme.GOLD if i >= COUNT_PIPS else UiTheme.CYAN
		var col := lit if i < _level else Color(UiTheme.TEXT_DIM, 0.28)
		draw_colored_polygon(PackedVector2Array([Vector2(x + 1.5, y), Vector2(x + PIP_W, y),
				Vector2(x + PIP_W - 1.5, y + PIP_H), Vector2(x, y + PIP_H)]), col)
