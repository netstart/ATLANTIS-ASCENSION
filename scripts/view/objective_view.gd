class_name ObjectiveView
extends RefCounted
## Desenho dos objetivos de fase (SimObjectives) na camada das entidades do WorldView: a mira dourada em volta de cada
## alvo, os atlantes nas bolhas e a relíquia voando até a nave. Só lê a Sim; texturas e `draw_texture`, nada de
## polígono refeito por quadro (regra de desempenho de docs/policies/qualidade.md).
##
## Leitura: o atlante é uma bolha oca e clara com a silhueta dourada, maior e mais lenta que as balas, com halo ciano
## que pulsa devagar; a mira é feita de quatro cantos dourados que respiram em volta do alvo.

## Folga da mira além do raio do alvo e quanto ela respira (fração do tamanho).
const MARKER_PAD := 7.0
const MARKER_PULSE := 0.08
const SURVIVOR_GLOW := Color(0.45, 0.95, 1.0, 0.45)
const RELIC_GLOW := Color(1.0, 0.85, 0.4, 0.6)
## Quanto a bolha cresce até a superfície e em quantos passos finais ela pisca e apaga.
const RISE_GROW := 0.35
const FADE_FRAMES := 90.0

var _marker: Texture2D
var _survivor: Texture2D
var _relic: Texture2D
var _glow: Texture2D


func setup() -> void:
	_marker = SpriteBank.generated("fx/target_marker")
	_survivor = SpriteBank.generated("pickups/survivor")
	_relic = SpriteBank.generated("pickups/relic")
	_glow = SpriteBank.generated("fx/glow_32")


func draw(ci: CanvasItem, sim: Sim, time: float) -> void:
	var obj := sim.objectives
	if not obj.enabled:
		return
	for e: SimEnemy in sim.enemies:
		if e.objective != &"" and e.alive and e.depth >= 1.0:
			var side := (e.radius + MARKER_PAD) * 2.0 * (1.0 + MARKER_PULSE * sin(time * 6.0))
			var tint := Color(UiTheme.GOLD, 0.7 + 0.3 * sin(time * 6.0))
			ci.draw_texture_rect(_marker, Rect2(e.pos - Vector2(side, side) * 0.5, Vector2(side, side)), false, tint)
	for s: Dictionary in obj.survivors:
		var p: Vector2 = s["pos"]
		var bob := sin(time * 3.0 + float(s["phase"]))
		# Subindo para a superfície: a bolha cresce com a idade e some no último segundo e meio (vai se perder).
		var age := float(s["frames"]) / SimObjectives.SURVIVOR_LIFE
		var grow := 1.0 + RISE_GROW * age
		var fade := clampf((SimObjectives.SURVIVOR_LIFE - float(s["frames"])) / FADE_FRAMES, 0.25, 1.0)
		if fade < 1.0:
			fade *= 0.75 + 0.25 * sin(time * 18.0)
		_centered(ci, _glow, p, (0.9 + 0.12 * bob) * grow, Color(SURVIVOR_GLOW, SURVIVOR_GLOW.a * fade))
		_centered(ci, _survivor, p + Vector2(0, bob), grow, Color(1, 1, 1, fade))
	for r: Dictionary in obj.relics:
		_centered(ci, _glow, r["pos"], 0.8 + 0.2 * sin(time * 8.0), RELIC_GLOW)
		_centered(ci, _relic, r["pos"], 1.0, Color(1, 1, 1))


static func _centered(ci: CanvasItem, tex: Texture2D, at: Vector2, scale: float, color: Color) -> void:
	if tex == null:
		return
	var size := tex.get_size() * scale
	ci.draw_texture_rect(tex, Rect2(at - size * 0.5, size), false, color)
