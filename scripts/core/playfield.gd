class_name Playfield
extends RefCounted
## Onde fica a área de jogo em cada tela (plano mestre 10.8; docs/policies/testes.md).
##
## A simulação usa um campo de FIELD.x (270) unidades de largura em todos os aparelhos e altura entre
## FIELD.y (450) e MAX_HEIGHT (640). A altura é decidida no começo da
## missão a partir da tela (height_for) e vai na carga da partida ("field_h"), então replay e Fantasma
## reproduzem a mesma partida; replays antigos, sem ela, rodam em 450. Os inimigos surgem pelo topo: a
## altura extra é espaço do jogador. O campo é ampliado (`scale`, fracionária quando precisa, que o Game desenha
## com filtro nítido) e o que sobra da tela vira:
## - retrato: o campo ocupa a largura inteira da área segura (`scale` = largura / 270, abaixo ou acima de 1),
##   encostado embaixo; a altura é a que preenche a tela nessa escala (height_for). Se a altura da partida não
##   couber (tablet, replay de 450 numa tela baixa), a escala vem da altura e o campo fica centralizado, com
##   molduras nas laterais. HUD numa faixa acima, se sobrar altura, senão sobre o topo do campo; os botões de ação
##   ficam empilhados no meio da borda esquerda do campo (GameHud);
## - paisagem (PC, Steam): o campo é ampliado até ocupar a altura inteira da área segura, centralizado;
##   as laterais viram painéis com o HUD e os botões, perto do campo. A altura é a maior em que a ampliação dá
##   pixels inteiros na tela física (1080 → 540 em 2x, 1440 → 480 em 3x); sem nenhuma, 640 com ampliação
##   fracionária, que o Game desenha com filtro nítido.
##
## Regra pura (sem nós): layout() recebe a tela lógica, a área segura e a altura do campo e devolve os retângulos.

const FIELD := Vector2(270, 450)
## Teto da altura: 9:21,3. Cobre, já sem o recorte da câmera, os celulares 9:19,5 a 9:22 da tabela de
## resoluções; acima disso a distância do surgimento até a nave deixaria balas miradas fáceis demais.
const MAX_HEIGHT := 640.0
## Faixa do HUD (pontuação, multiplicador, casco). Sobre o campo quando não sobra altura para ela.
const HUD_HEIGHT := 24.0


## Altura do campo para uma área segura (a partida guarda o valor; a tela pode mudar depois). `k` é a escala
## inteira da tela lógica para a física (PixelScaler), usada só em paisagem. Em retrato, a altura útil em unidades
## do campo com a largura inteira (305x678 → 600).
static func height_for(safe: Rect2, k: int = 1) -> float:
	var h := floorf(safe.end.y) - ceilf(safe.position.y)
	if safe.size.x <= safe.size.y:
		return clampf(floorf(h * FIELD.x / safe.size.x + 0.001), FIELD.y, MAX_HEIGHT)
	var p := h * maxi(1, k)
	for n: int in range(1, int(p / FIELD.y) + 1):
		if p / n <= MAX_HEIGHT:
			return floorf(p / n)
	return MAX_HEIGHT if p > MAX_HEIGHT else FIELD.y


## Retângulos da tela: field (na tela, já ampliado), hud, left, right (Rect2), hud_overlay (bool) e scale (ampliação do
## campo: pixels lógicos por unidade; o HUD, em retrato, mede HUD_HEIGHT unidades).
## `safe` é a área segura (fora do recorte da câmera) dentro de `view`.
static func layout(view: Vector2, safe: Rect2, height: float = FIELD.y) -> Dictionary:
	var size := Vector2(FIELD.x, height)
	var field_pos := Vector2.ZERO
	var hud := Rect2()
	var overlay := false
	var scale := 1.0
	if view.y >= view.x:
		var top := ceilf(safe.position.y)
		var bottom := floorf(safe.end.y)
		# Largura inteira da área segura; se a altura não couber nessa escala, a escala vem da altura.
		scale = safe.size.x / FIELD.x
		if height * scale > bottom - top + 0.01:
			scale = (bottom - top) / height
		size *= scale
		field_pos.x = safe.position.x + maxf(0.0, safe.size.x - size.x) * 0.5
		# O campo encosta embaixo da área segura (sem faixa reservada); o HUD vai acima se couber.
		field_pos.y = maxf(top, bottom - size.y)
		var band := HUD_HEIGHT * scale
		overlay = field_pos.y - top < band - 0.01
		hud = Rect2(field_pos.x, field_pos.y - (0.0 if overlay else band), size.x, band)
	else:
		scale = (floorf(safe.end.y) - ceilf(safe.position.y)) / height
		size *= scale
		field_pos = Vector2(floorf((view.x - size.x) * 0.5), ceilf(safe.position.y))
		hud = Rect2(safe.position.x, safe.position.y, maxf(0.0, field_pos.x - safe.position.x), safe.size.y)
	var field := Rect2(field_pos, size)
	return {
		"field": field,
		"hud": hud,
		"hud_overlay": overlay,
		"scale": scale,
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
