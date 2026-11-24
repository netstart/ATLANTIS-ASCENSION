class_name SeaView
extends Node2D
## Camada dos inimigos na água (def "layer": "sea", data/enemies.json: submarino e navio de guerra do Protocolo, que
## só o míssil teleguiado atinge). O WorldView a põe acima do fundo do mar e abaixo das sombras, dos voadores e de
## todas as balas: o jogador lê na hora que estão lá embaixo, na superfície.
##
## Cada navio leva, de baixo para cima: a esteira (espuma granulada, sea/foam.png de tools/gen_sea_ships.py, em dois
## braços que abrem em V no ângulo de Kelvin atrás da popa e a água batida no meio, correndo para trás e sumindo), a
## espuma da hélice (tira "engine" da arte HD), o casco um pouco escurecido e azulado (está na água; sem sombra de voo)
## e a onda de proa. Quem emerge (SimEnemy.depth < 1) é uma silhueta escura e ondulada sob a água, com anéis na
## superfície, que ganha cor e esteira ao subir. Afundado pelo míssil (sink), vira jorro d'água (CombatFx.splash).
## Só texturas por quadro; a quantidade de espuma segue a qualidade gráfica (fx_level). Nada aqui muda a Sim.

## Cor de quem está na água: um pouco mais escuro e mais azul que o mesmo sprite no ar.
const WATER_TINT := Color(0.86, 0.93, 1.0)
## Cor da silhueta submersa (sombra azul-petróleo, um tom acima do mar escuro para ser lida) e o alfa mínimo dela.
const DEEP_COLOR := Color(0.05, 0.16, 0.22)
const DEEP_ALPHA := 0.75
## Escala de quem ainda está submerso (sobe de 85% a 100%: a água não encolhe tanto quanto a neblina do céu).
const DEEP_SCALE := 0.85
## Esteira: comprimento em múltiplos do comprimento do casco, abertura (tangente do ângulo de Kelvin, ~19,5°) e
## velocidade da espuma (fração da esteira por segundo).
const WAKE_LENGTH := 1.5
const WAKE_SPREAD := 0.35
const WAKE_SPEED := 0.55
## Flocos por braço da esteira em cada qualidade (0 mínima, 1 normal, 2 completa).
const WAKE_PUFFS: Array[int] = [6, 12, 20]
const FOAM_PATH := "res://assets/art/hd/sea/foam.png"

var level: int = 2
var foam := Color(0.7, 0.95, 1.0)
var _world: WorldView
var _pulses: EnemyPulses
var _glow: Texture2D
## Tira de quadros quadrados de espuma granulada (variações, sorteadas por floco).
var _foam: Texture2D
var _foam_frames: int = 1


## Liga a camada ao WorldView (Sim, tempo, efeitos) e ao retorno de dano dos inimigos; `flash` é o material do dano.
func setup(world: WorldView, pulses: EnemyPulses, flash: Material) -> void:
	_world = world
	_pulses = pulses
	level = clampi(world.fx_level, 0, 2)
	foam = world.fx.foam
	material = flash
	texture_filter = SpriteBank.HD_FILTER
	_glow = SpriteBank.generated("fx/glow_32")
	_foam = SpriteBank.texture(FOAM_PATH)
	if _foam == null:
		_foam = _glow
	_foam_frames = maxi(1, _foam.get_width() / _foam.get_height())


## O inimigo anda na água (def "layer" == "sea").
static func is_sea(e: SimEnemy) -> bool:
	return String(e.def.get("layer", "")) == "sea"


## Morte de um inimigo pelo evento "kill": se for do mar, faz o jorro d'água (estouro curto, coluna, espuma e
## explosão abafada), os anéis e os pontos no WorldView e devolve verdadeiro; senão não faz nada.
func sink(def: Dictionary, ev: Dictionary) -> bool:
	if String(def.get("layer", "")) != "sea":
		return false
	var at: Vector2 = ev.get("pos", Vector2.ZERO)
	var big := bool(ev.get("big", false))
	_world.last_death = CombatFx.EXPLODE
	_world.fx.splash(at, big)
	_world.rings.append({"pos": at, "t": 0.0, "duration": 0.3, "radius": 30.0 if big else 20.0,
			"color": Color(1.0, 0.8, 0.55)})
	_world.rings.append({"pos": at, "t": 0.0, "duration": 0.6, "radius": 70.0 if big else 46.0,
			"color": Color(foam, 0.85)})
	_world.fx.popup(at, int(ev.get("points", 0)), UiTheme.GOLD if big else Color(1.0, 0.95, 0.82))
	return true


func _draw() -> void:
	if _world == null or _world.sim == null:
		return
	for e: SimEnemy in _world.sim.enemies:
		if not is_sea(e):
			continue
		var pulse := _pulses.of(e)
		var tint := HitPulse.tint(Color(String(e.def.get("tint", "#ffffff"))), pulse.intensity(), false)
		var at := e.pos + pulse.offset() * WorldView.shake_scale(e.radius)
		draw_ship(self, SpriteBank.ship(e.sprite), e, at, tint, _world.time)


## Um navio: esteira, espuma da hélice, casco e onda de proa. `tint` é o modulate do dano (HitPulse, alfa 2..3 no
## acerto); `at` já vem com o tranco do acerto.
func draw_ship(ci: CanvasItem, ship: Dictionary, e: SimEnemy, at: Vector2, tint: Color, time: float) -> void:
	var base: Texture2D = ship["base"]
	if base == null:
		return
	var rise := WorldView.rise_of(e.depth)
	var s := float(e.def.get("scale", 1.0)) * lerpf(DEEP_SCALE, 1.0, rise)
	var used: Rect2 = ship["used"]
	var size: float = ship["size"]
	var tex_size: int = ship["tex_size"]
	var rect := Rect2(-size * 0.5, -size * 0.5, size, size)
	var src := Rect2(0, 0, tex_size, tex_size)
	# Fase própria de cada navio (o balanço e a espuma não andam em sincronia).
	var phase := float(e.frames % 997) * 0.37 + at.x * 0.05
	# Na textura a proa aponta para cima; girado em PI, a popa (+y local) fica para cima na tela.
	ci.draw_set_transform(at, PI, Vector2(s, s))
	if rise > 0.25:
		_wake(ci, used, time + phase, (rise - 0.25) / 0.75)
	if rise < 1.0:
		# Submerso: silhueta escura que ondula (cisalha e respira) e vai ganhando a cor do casco.
		var wave := 1.0 - rise
		var xf := Transform2D(PI, Vector2(s * (1.0 + 0.04 * wave * sin(time * 3.1 + phase)), s),
				0.07 * wave * sin(time * 2.3 + phase), at)
		ci.draw_set_transform_matrix(xf)
		ci.draw_texture_rect_region(base, rect, src, Color(DEEP_COLOR, lerpf(DEEP_ALPHA, 1.0, rise)))
		_ripples(ci, used, at, s, time + phase, wave)
		ci.draw_set_transform(at, PI, Vector2(s, s))
	var engine: Texture2D = ship["engine"]
	if engine != null and rise > 0.0:
		var f := int(time * WorldView.ANIM_FPS + phase) % int(ship["engine_frames"])
		ci.draw_texture_rect_region(engine, rect, SpriteBank.frame_rect(f, tex_size), Color(1, 1, 1, rise))
	var hull := Color(tint.r * WATER_TINT.r, tint.g * WATER_TINT.g, tint.b * WATER_TINT.b, tint.a)
	if rise < 1.0:
		# Ganhando cor: o alfa normal vai de 0 a 1 (o tinte de dano, alfa 2..3, só existe depois de emergir).
		hull.a = minf(tint.a, rise * rise)
	if rise > 0.5:
		_bow(ci, used, time + phase, (rise - 0.5) * 2.0)
	if hull.a > 0.01:
		ci.draw_texture_rect_region(base, rect, src, hull)
	ci.draw_set_transform(Vector2.ZERO)


## Esteira em coordenadas do navio (popa em +y): flocos de espuma granulada que nascem na popa e correm para trás
## crescendo e sumindo, em dois braços que abrem em V e a água batida no meio (curta). Cada floco novo tem o seu
## desvio e a sua variação de textura (hash do ciclo), para a borda sair quebrada como espuma, não lisa como luz.
func _wake(ci: CanvasItem, used: Rect2, clock: float, strength: float) -> void:
	var stern := used.end.y
	var beam := used.size.x * 0.5
	var length := used.size.y * WAKE_LENGTH
	var n := WAKE_PUFFS[level]
	var side_px := _foam.get_height()
	for k: int in range(n):
		var flow := float(k) / n + clock * WAKE_SPEED
		var t := fposmod(flow, 1.0)
		var cycle := floorf(flow)
		var fade := (1.0 - t) * minf(1.0, t * 10.0) * strength
		var along := stern - 1.0 + t * length
		for sgn: float in [-1.0, 1.0]:
			var h := fposmod(sin(k * 12.99 + cycle * 78.23 + sgn * 3.7) * 43758.55, 1.0)
			var side := beam * 0.5 + t * length * WAKE_SPREAD + (h - 0.5) * (1.0 + 3.0 * t)
			var r := lerpf(2.4, 6.5, t) * (0.8 + 0.4 * h)
			_flake(ci, Vector2(sgn * side, along + (h - 0.5) * 3.0), r, int(h * 97.0), side_px,
					Color(foam, 0.8 * fade))
		if t < 0.55:
			# Água batida atrás da hélice: flocos largos no eixo, balançando, que somem na metade da esteira.
			var hc := fposmod(sin(k * 4.13 + cycle * 19.7) * 24634.6, 1.0)
			var c := Vector2((hc - 0.5) * beam * (0.4 + t), along)
			_flake(ci, c, beam * lerpf(0.55, 1.1, t / 0.55), int(hc * 89.0), side_px,
					Color(foam, 0.6 * (1.0 - t / 0.55) * strength))


func _flake(ci: CanvasItem, at: Vector2, r: float, pick: int, side_px: int, col: Color) -> void:
	ci.draw_texture_rect_region(_foam, Rect2(at - Vector2(r, r), Vector2(r, r) * 2.0),
			SpriteBank.frame_rect(pick % _foam_frames, side_px), col)


## Anéis na superfície sobre quem emerge: dois ovais de espuma que abrem e somem, mais fortes perto de romper.
func _ripples(ci: CanvasItem, used: Rect2, at: Vector2, s: float, clock: float, wave: float) -> void:
	var length := used.size.y * 0.5
	ci.draw_set_transform(at, 0.0, Vector2(s * 0.5, s))
	for k: int in range(2):
		var u := fposmod(clock * 0.9 + k * 0.5, 1.0)
		var a := (1.0 - u) * minf(1.0, u * 6.0) * (1.0 - wave * 0.4) * 0.45
		ci.draw_arc(Vector2.ZERO, length * lerpf(0.75, 1.3, u), 0.0, TAU, 32, Color(foam, a), 1.6 / s)


## Onda de proa (por baixo do casco): espuma que abraça a ponta e pulsa devagar.
func _bow(ci: CanvasItem, used: Rect2, clock: float, strength: float) -> void:
	var bow := used.position.y
	var beam := used.size.x * 0.5
	var pulse := 0.85 + 0.15 * sin(clock * 4.0)
	var side_px := _foam.get_height()
	for sgn: float in [-1.0, 1.0]:
		_flake(ci, Vector2(sgn * beam * 0.7, bow + beam * 1.1), beam * 0.8 * pulse, 2 if sgn > 0 else 1, side_px,
				Color(foam, 0.5 * strength))
	_flake(ci, Vector2(0, bow), beam * 0.7 * pulse, 3, side_px, Color(foam, 0.6 * strength))
