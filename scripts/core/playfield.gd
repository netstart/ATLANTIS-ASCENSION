class_name Playfield
extends RefCounted
## Onde fica a área de jogo em cada tela (plano mestre 10.8; docs/policies/testes.md).
##
## A simulação usa um campo fixo de FIELD (270x450 unidades), desenhado 1:1 em pixels lógicos em
## todos os aparelhos: telas maiores nunca mostram mais área de jogo, então dificuldade, placar e
## determinismo são iguais em todo lugar. O que sobra vira:
## - retrato: HUD em cima do campo (se couber), zona do polegar embaixo, molduras nas laterais;
## - paisagem (Steam): campo no centro, painéis laterais com HUD e arte.
##
## Regra pura (sem nós): layout() recebe a tela lógica e a área segura e devolve os retângulos.

const FIELD := Vector2(270, 450)
## Faixa do HUD (pontuação, multiplicador, casco, arma). Em telas curtas fica sobre o campo.
const HUD_HEIGHT := 24.0
## Faixa mínima de zona do polegar para os botões saírem de cima do campo.
const THUMB_MIN := 56.0


## Retângulos da tela: field, hud, thumb, left, right (Rect2) e hud_overlay (bool).
## `safe` é a área segura (fora do recorte da câmera) dentro de `view`.
static func layout(view: Vector2, safe: Rect2) -> Dictionary:
	var field_pos := Vector2.ZERO
	var hud := Rect2()
	var thumb := Rect2()
	var overlay := false
	if view.y >= view.x:
		field_pos.x = floorf((view.x - FIELD.x) * 0.5)
		var top := ceilf(safe.position.y)
		var bottom := floorf(safe.end.y)
		if bottom - top >= FIELD.y + HUD_HEIGHT:
			hud = Rect2(field_pos.x, top, FIELD.x, HUD_HEIGHT)
			field_pos.y = top + HUD_HEIGHT
		else:
			overlay = true
			field_pos.y = top + floorf(maxf(0.0, bottom - top - FIELD.y) * 0.5)
			hud = Rect2(field_pos.x, field_pos.y, FIELD.x, HUD_HEIGHT)
		var field_end := field_pos.y + FIELD.y
		thumb = Rect2(field_pos.x, field_end, FIELD.x, maxf(0.0, bottom - field_end))
	else:
		field_pos = Vector2(floorf((view.x - FIELD.x) * 0.5),
				floorf(safe.position.y + (safe.size.y - FIELD.y) * 0.5))
		hud = Rect2(safe.position.x, safe.position.y, maxf(0.0, field_pos.x - safe.position.x), safe.size.y)
	var field := Rect2(field_pos, FIELD)
	return {
		"field": field,
		"hud": hud,
		"hud_overlay": overlay,
		"thumb": thumb,
		"thumb_separate": thumb.size.y >= THUMB_MIN,
		"left": Rect2(0.0, 0.0, field.position.x, view.y),
		"right": Rect2(field.end.x, 0.0, maxf(0.0, view.x - field.end.x), view.y),
	}


## Fração do campo coberta pelo HUD (0 quando o HUD fica fora do campo).
static func hud_coverage(result: Dictionary) -> float:
	if not bool(result["hud_overlay"]):
		return 0.0
	var field: Rect2 = result["field"]
	var hud: Rect2 = result["hud"]
	return field.intersection(hud).get_area() / field.get_area()


## O campo inteiro cabe na área segura?
static func fits(result: Dictionary, safe: Rect2) -> bool:
	var field: Rect2 = result["field"]
	return safe.grow(0.01).encloses(field)
