class_name CombatFx
extends RefCounted
## Receitas de efeito da partida (.ai/06-pesquisa-efeitos-visuais.md): o que cada acontecimento da Sim
## vira na tela. Explosão em camadas (clarão, bolas de fogo, faíscas, fumaça, estilhaços, onda de
## choque), impacto do tiro, boca do canhão, coleta, cancelamento de balas em ondas, números de pontos e
## as mortes dos inimigos (`blast`, e em `wrecks` a queda até o mar ou o chão e o derretimento no lugar).
## Duas camadas de partículas: `light`
## (aditiva, linear: tudo que brilha) e `matter` (normal, pixel art: fumaça e estilhaços).
## Só visual: a semente própria dá variedade; qualidade gráfica e "reduzir flashes" mudam a dose,
## nunca a partida.

## Uma morte terminou: a queda bateu no mar (`water`) ou no chão (`solid`), ou o derretimento estourou
## (`pop`). O WorldView põe o anel e a Game toca o som e treme a tela.
signal landed(at: Vector2, big: bool, kind: StringName)

# Texturas da camada de luz e da de matéria (índices de ParticleField.spawn).
const FLARE := 0
const STREAK := 1
const SPARKLE := 2
const SMOKE := 0
const DEBRIS := 1
const LIGHT_TEXTURES := ["fx/flare_64", "fx/streak", "fx/sparkle_9"]
const MATTER_TEXTURES := ["fx/smoke_16", "fx/debris_6"]
## Cores de fogo: núcleo, chama e brasa (do clarão ao apagar).
const FIRE_CORE := Color(1.0, 0.95, 0.8, 1.0)
const FIRE := Color(1.0, 0.62, 0.22, 0.9)
const EMBER := Color(0.85, 0.18, 0.06, 0.0)
const SMOKE_START := Color(0.2, 0.22, 0.26, 0.75)
const SMOKE_END := Color(0.12, 0.14, 0.18, 0.0)
const MAX_POPUPS := 14
const MAX_WRECKS := 24
## Morte que cai (pega fogo, gira e encolhe até a sombra, 2,5D) e morte que derrete no lugar (o sprite
## escorre com a borda em brasa: shaders/sprite_melt.gdshader). Durações em s, pequeno e grande.
const FALL := &"fall"
const MELT := &"melt"
const FALL_TIME := 1.0
const FALL_TIME_BIG := 1.3
const MELT_TIME := 0.8
const MELT_TIME_BIG := 1.1
## Intervalo (s) entre as levas de fogo da queda e de pingos do derretimento, por qualidade.
const TRAIL_STEP: Array[float] = [0.1, 0.05, 0.034]
const WATER := &"water"
const SOLID := &"solid"
const NONE := &"none"
const POP := &"pop"
## Estilos de morte (WorldView.kill_fx) e pesos (em 100) de explosão, derretimento e queda: os grandes
## preferem os mais vistosos.
const EXPLODE := &"explode"
const DEATH_WEIGHTS_SMALL: Array[int] = [40, 25, 35]
const DEATH_WEIGHTS_BIG: Array[int] = [45, 10, 45]
## Ondas de cancelamento: balas que somem por ordem de distância, até este atraso (s).
const CANCEL_SPREAD := 0.45

var light: ParticleField
var matter: ParticleField
## 0 = mínimo, 1 = normal, 2 = completo (GfxQuality "weapon_fx").
var level: int = 2
var reduce_flashes: bool = false
## Cenário com chão (há sombra); falso no espaço.
var ground: bool = true
## Bolhas de quem sobe do fundo.
var water: bool = true
## Onde cai o inimigo abatido: WATER, SOLID ou NONE (sem queda). OceanBackdrop "floor".
var surface: StringName = WATER
var foam := Color(0.7, 0.95, 1.0)
## Números de pontos: {pos, text, t, color}.
var popups: Array[Dictionary] = []
## Mortes em curso: {tex, size, pos, from, to, t, time, mode, big, spin, scale, emit}.
var wrecks: Array[Dictionary] = []

var _rng := RandomNumberGenerator.new()
## Efeitos agendados (cadeias de explosão do chefe, ondas de cancelamento): {t, call}.
var _pending: Array[Dictionary] = []


func setup(light_capacity: int, matter_capacity: int) -> void:
	_rng.seed = 0xA71A
	light = ParticleField.new()
	light.setup(_textures(LIGHT_TEXTURES), light_capacity, true, true)
	matter = ParticleField.new()
	matter.setup(_textures(MATTER_TEXTURES), matter_capacity, false, false)


## Avança tudo `delta` segundos. As partículas andam antes: o que nasce agora (cadeias, splash)
## aparece no próximo quadro, inteiro, mesmo depois de um quadro longo.
func advance(delta: float) -> void:
	light.advance(delta)
	matter.advance(delta)
	var i := _pending.size() - 1
	while i >= 0:
		var p := _pending[i]
		p["t"] = float(p["t"]) - delta
		if float(p["t"]) <= 0.0:
			_pending.remove_at(i)
			(p["call"] as Callable).call()
		i -= 1
	_age_popups(delta)
	_age_wrecks(delta)


## Apaga tudo de uma vez (fim da missão, SimOutro): partículas, agendados, números e destroços.
func clear() -> void:
	light.clear()
	matter.clear()
	_pending.clear()
	popups.clear()
	wrecks.clear()


func later(seconds: float, what: Callable) -> void:
	_pending.append({"t": seconds, "call": what})


## Efeitos agendados que ainda não dispararam.
func pending() -> int:
	return _pending.size()


# --- Receitas ------------------------------------------------------------------------------------

## Explosão em camadas. `tier`: 1 pequena, 2 grande, 3 chefe.
func explosion(at: Vector2, tier: float, tint: Color = FIRE) -> void:
	var flash := 0.6 if reduce_flashes else 1.0
	light.spawn(FLARE, at, Vector2.ZERO, 0.11, 0.9 * tier, 1.5 * tier, Color(FIRE_CORE, flash), Color(tint, 0.0))
	var balls := 2 + int(tier * (2 + level))
	for k: int in range(balls):
		var v := _dir() * _rng.randf_range(15.0, 55.0) * tier
		light.spawn(FLARE, at + _dir() * _rng.randf_range(0.0, 6.0) * tier, v, _rng.randf_range(0.3, 0.55),
				_rng.randf_range(0.25, 0.4) * tier, _rng.randf_range(0.6, 0.9) * tier, tint, EMBER, 4.0)
	var sparks := int(tier * (3 + level * 3))
	for k: int in range(sparks):
		light.spawn(STREAK, at, _dir() * _rng.randf_range(110.0, 260.0) * sqrt(tier), _rng.randf_range(0.25, 0.5),
				_rng.randf_range(0.7, 1.1), 0.3, Color(1.0, 0.9, 0.6), Color(1.0, 0.4, 0.1, 0.0), 4.5, Vector2.ZERO, 0.0,
				0.0, true)
	if level >= 1:
		for k: int in range(int(tier * (1 + level))):
			matter.spawn(SMOKE, at + _dir() * _rng.randf_range(0.0, 8.0) * tier, _dir() * _rng.randf_range(6.0, 22.0),
					_rng.randf_range(0.8, 1.3), 0.6 * tier, 1.5 * tier, SMOKE_START, SMOKE_END, 1.5, Vector2(0, 14),
					_rng.randf() * TAU, _rng.randf_range(-1.0, 1.0))
		for k: int in range(int(tier * (1 + level))):
			matter.spawn(DEBRIS, at, _dir() * _rng.randf_range(50.0, 140.0) * sqrt(tier), _rng.randf_range(0.5, 0.9),
					_rng.randf_range(0.8, 1.3), 0.4, Color(0.85, 0.85, 0.9), Color(0.35, 0.35, 0.4, 0.0), 2.5,
					Vector2(0, 30), _rng.randf() * TAU, _rng.randf_range(-10.0, 10.0))


## Chefe ou parte: cadeia de explosões em volta de `at` por `seconds`, e o estouro final.
func chain(at: Vector2, radius: Vector2, count: int, seconds: float, tier: float) -> void:
	for k: int in range(count):
		var off := Vector2(_rng.randf_range(-radius.x, radius.x), _rng.randf_range(-radius.y, radius.y))
		later(seconds * k / maxf(1.0, count - 1.0), explosion.bind(at + off, tier * _rng.randf_range(0.7, 1.1)))


## Tiro acertando: ponto branco e faíscas voltando contra o tiro.
func impact(at: Vector2, tint: Color) -> void:
	light.spawn(FLARE, at, Vector2.ZERO, 0.09, 0.32, 0.1, Color(1, 1, 1, 0.95), Color(tint, 0.0))
	if level == 0:
		return
	for k: int in range(1 + level):
		var v := Vector2.from_angle(PI * 0.5 + _rng.randf_range(-1.1, 1.1)) * _rng.randf_range(80.0, 170.0)
		light.spawn(STREAK, at, v, _rng.randf_range(0.12, 0.22), 0.6, 0.25, tint, Color(tint, 0.0), 7.0,
				Vector2.ZERO, 0.0, 0.0, true)


## Clarão na boca do canhão.
func muzzle(at: Vector2, tint: Color) -> void:
	light.spawn(FLARE, at, Vector2(0, -30), 0.06, _rng.randf_range(0.22, 0.3), 0.1, Color(tint, 0.85),
			Color(tint, 0.0))


## Rastro do motor (luz que fica para trás e apaga).
func exhaust(at: Vector2, tint: Color, power: float) -> void:
	light.spawn(FLARE, at + Vector2(_rng.randf_range(-1.5, 1.5), 0), Vector2(_rng.randf_range(-6, 6), 70.0 + 60.0 * power),
			0.16 + 0.08 * power, 0.16 + 0.08 * power, 0.04, Color(tint, 0.6), Color(tint, 0.0), 2.0)


## Coleta: brilho e estrelinhas saindo da nave.
func collect(at: Vector2, tint: Color, big: bool) -> void:
	light.spawn(FLARE, at, Vector2.ZERO, 0.18, 0.3, 0.8 if big else 0.5, Color(tint, 0.9), Color(tint, 0.0))
	var n := (8 if big else 4) if level >= 1 else 2
	for k: int in range(n):
		var a := TAU * k / n + _rng.randf_range(-0.3, 0.3)
		light.spawn(SPARKLE, at, Vector2.from_angle(a) * _rng.randf_range(50.0, 90.0), _rng.randf_range(0.25, 0.4),
				1.4, 0.4, Color(1, 1, 1), Color(tint, 0.0), 5.0, Vector2.ZERO, 0.0, 3.0)


## Raspão: duas faíscas ciano.
func graze(at: Vector2) -> void:
	for k: int in range(2):
		light.spawn(STREAK, at, _dir() * _rng.randf_range(60.0, 120.0), 0.15, 0.5, 0.2, Color(0.5, 1.0, 1.0),
				Color(0.2, 0.8, 1.0, 0.0), 6.0, Vector2.ZERO, 0.0, 0.0, true)


## Fumaça de inimigo avariado (sai das naves com pouca vida).
func damage_smoke(at: Vector2) -> void:
	matter.spawn(SMOKE, at + _dir() * 3.0, Vector2(_rng.randf_range(-6, 6), 30.0), _rng.randf_range(0.5, 0.8), 0.35,
			0.9, Color(0.18, 0.18, 0.2, 0.6), SMOKE_END, 1.0, Vector2.ZERO, _rng.randf() * TAU, 1.0)
	if level >= 2 and _rng.randf() < 0.35:
		light.spawn(FLARE, at, Vector2(0, 20), 0.12, 0.12, 0.04, Color(1.0, 0.55, 0.2, 0.7), Color(1, 0.2, 0, 0))


## Bolhas de quem sobe do fundo do mar.
func bubbles(at: Vector2) -> void:
	light.spawn(SPARKLE, at + Vector2(_rng.randf_range(-8, 8), _rng.randf_range(-4, 4)),
			Vector2(_rng.randf_range(-5, 5), -18.0), 0.5, 0.8, 0.4, Color(foam, 0.5), Color(foam, 0.0))


## Bomba ou especial: as balas que estavam na tela viram brilho, em onda a partir de `center`.
func cancel_wave(center: Vector2, bullets: PackedVector2Array) -> void:
	var far := 1.0
	for p: Vector2 in bullets:
		far = maxf(far, p.distance_to(center))
	for p: Vector2 in bullets:
		later(CANCEL_SPREAD * p.distance_to(center) / far, _cancel_one.bind(p))


func _cancel_one(at: Vector2) -> void:
	light.spawn(FLARE, at, Vector2.ZERO, 0.16, 0.12, 0.3, Color(1.0, 0.9, 0.5, 0.9), Color(1.0, 0.6, 0.2, 0.0))
	light.spawn(SPARKLE, at, Vector2(0, -40), 0.4, 1.2, 0.5, Color(1, 1, 1), Color(1.0, 0.85, 0.3, 0.0), 2.0,
			Vector2.ZERO, 0.0, 4.0)


## Número de pontos subindo e sumindo.
func popup(at: Vector2, points: int, tint: Color) -> void:
	if points <= 0:
		return
	if popups.size() >= MAX_POPUPS:
		popups.pop_front()
	popups.append({"pos": at, "text": "+%d" % points, "t": 0.0, "color": tint})


## Explosão de morte reforçada: a explosão em camadas maior, brasas que ficam no ar, fumaça baixa que
## demora a sumir (alfa baixo: não esconde bala) e estouros secundários em volta.
func blast(at: Vector2, big: bool) -> void:
	var tier := 2.1 if big else 1.3
	explosion(at, tier)
	var embers := int((2 + level * 3) * (1.6 if big else 1.0))
	for k: int in range(embers):
		light.spawn(SPARKLE, at + _dir() * _rng.randf_range(0.0, 8.0) * tier,
				_dir() * _rng.randf_range(15.0, 45.0) * tier + Vector2(0, -10), _rng.randf_range(0.7, 1.3),
				_rng.randf_range(0.8, 1.2), 0.2, Color(1.0, 0.75, 0.35, 0.9), Color(1.0, 0.25, 0.05, 0.0), 1.8,
				Vector2(0, -12))
	if level >= 1:
		for k: int in range(1 + level):
			matter.spawn(SMOKE, at + _dir() * _rng.randf_range(0.0, 8.0) * tier, _dir() * _rng.randf_range(4.0, 12.0),
					_rng.randf_range(1.2, 1.8), 0.7 * tier, 1.8 * tier, Color(SMOKE_START, 0.35), SMOKE_END, 1.2,
					Vector2(0, 10), _rng.randf() * TAU, _rng.randf_range(-0.6, 0.6))
	if big or level >= 2:
		later(0.09, explosion.bind(at + _dir() * _rng.randf_range(6.0, 12.0) * tier, tier * 0.45))
	if big:
		later(0.2, explosion.bind(at + _dir() * _rng.randf_range(8.0, 16.0) * tier, tier * 0.4))


## Estilo de morte pelo sorteio `roll` (do lado do desenho): pesos por tamanho; sem chão nem mar a queda
## vira explosão (grandes) ou derretimento; os especiais (glifo) só explodem.
static func death_style(roll: int, big: bool, surface: StringName, special: bool) -> StringName:
	if special:
		return EXPLODE
	var w := DEATH_WEIGHTS_BIG if big else DEATH_WEIGHTS_SMALL
	var r := posmod(roll, 100)
	var style := EXPLODE if r < w[0] else (MELT if r < w[0] + w[1] else FALL)
	if style == FALL and surface == NONE:
		style = EXPLODE if big or posmod(roll / 100, 2) == 0 else MELT
	return style


## Morte que cai (FALL) ou derrete (MELT). A queda vai de `at` a `to` (a sombra, 2,5D) e só existe com
## chão ou mar embaixo; o derretimento fica em `at`. Devolve falso se não coube (teto, sem chão, sem
## textura): quem chamou explode no lugar.
func wreck(tex: Texture2D, size: int, at: Vector2, to: Vector2, scale: float, mode: StringName = FALL,
		big: bool = false) -> bool:
	if tex == null or wrecks.size() >= MAX_WRECKS or (mode == FALL and surface == NONE):
		return false
	var time := (FALL_TIME_BIG if big else FALL_TIME) if mode == FALL else (MELT_TIME_BIG if big else MELT_TIME)
	var spin := _rng.randf_range(3.0, 6.0) * (1.0 if _rng.randf() < 0.5 else -1.0) if mode == FALL else 0.0
	wrecks.append({"tex": tex, "size": size, "pos": at, "from": at, "to": to, "t": 0.0, "time": time,
			"mode": mode, "big": big, "scale": scale, "emit": 0.0, "spin": spin})
	if mode == FALL:
		# Pega fogo: um estouro curto onde foi atingido, antes de cair.
		explosion(at, 0.55 if big else 0.4)
	return true


## Fração (0..1) de uma morte em curso.
static func wreck_progress(w: Dictionary) -> float:
	return minf(1.0, float(w["t"]) / float(w["time"]))


## Raio visual (px) de uma morte em curso, já com o encolhimento da queda.
static func wreck_radius(w: Dictionary) -> float:
	var shrink := lerpf(1.0, 0.35, wreck_progress(w)) if StringName(w["mode"]) == FALL else 1.0
	return float(w["size"]) * float(w["scale"]) * 0.5 * shrink


func _age_popups(delta: float) -> void:
	var i := popups.size() - 1
	while i >= 0:
		var p := popups[i]
		p["t"] = float(p["t"]) + delta
		p["pos"] = (p["pos"] as Vector2) + Vector2(0, -22.0 * delta)
		if float(p["t"]) >= 0.75:
			popups.remove_at(i)
		i -= 1


func _age_wrecks(delta: float) -> void:
	var done: Array[Dictionary] = []
	var step := TRAIL_STEP[clampi(level, 0, 2)]
	var i := wrecks.size() - 1
	while i >= 0:
		var w := wrecks[i]
		w["t"] = float(w["t"]) + delta
		var u := wreck_progress(w)
		var fall := StringName(w["mode"]) == FALL
		if fall:
			w["pos"] = (w["from"] as Vector2).lerp(w["to"], u * u)
		w["emit"] = float(w["emit"]) + delta
		while float(w["emit"]) >= step:
			w["emit"] = float(w["emit"]) - step
			if fall:
				_burn(w, u)
			else:
				_drip(w, u)
		if u >= 1.0:
			done.append(w)
			wrecks.remove_at(i)
		i -= 1
	# O aviso sai depois do laço: quem ouve pode mexer nos efeitos sem atrapalhar a contagem.
	for w: Dictionary in done:
		var at: Vector2 = w["pos"]
		var big := bool(w["big"])
		if StringName(w["mode"]) == MELT:
			explosion(at, 0.9 if big else 0.55, Color(1.0, 0.7, 0.3, 0.9))
			landed.emit(at, big, POP)
		elif surface == WATER:
			_land_water(at, big)
			landed.emit(at, big, WATER)
		else:
			_land_ground(at, big)
			landed.emit(at, big, SOLID)


## Rastro da queda: fogo (luz) e fumaça (matéria, alfa baixo) que ficam para trás.
func _burn(w: Dictionary, u: float) -> void:
	var at: Vector2 = w["pos"]
	var r := wreck_radius(w)
	var k := r / 14.0
	for n: int in range(1 + mini(level, 1)):
		light.spawn(FLARE, at + _dir() * r * 0.35, Vector2(_rng.randf_range(-8, 8), _rng.randf_range(-20, -6)),
				_rng.randf_range(0.3, 0.45), _rng.randf_range(0.22, 0.32) * k, 0.06, FIRE, EMBER, 2.0)
	if level >= 1 and _rng.randf() < 0.6:
		matter.spawn(SMOKE, at + _dir() * r * 0.3, Vector2(_rng.randf_range(-6, 6), _rng.randf_range(-14, -4)),
				_rng.randf_range(0.6, 0.9), 0.35 * k + 0.2, 0.9 * k + 0.4, Color(SMOKE_START, 0.4 * (1.0 - u * 0.5)),
				SMOKE_END, 1.0, Vector2.ZERO, _rng.randf() * TAU, _rng.randf_range(-1.0, 1.0))
	if level >= 2 and _rng.randf() < 0.3:
		light.spawn(STREAK, at, _dir() * _rng.randf_range(40.0, 90.0), _rng.randf_range(0.15, 0.25), 0.6, 0.2,
				Color(1.0, 0.85, 0.5), Color(1.0, 0.4, 0.1, 0.0), 5.0, Vector2.ZERO, 0.0, 0.0, true)


## Derretimento: o calor sobre o sprite, pingos em brasa que caem da borda de baixo e brasas que sobem.
func _drip(w: Dictionary, u: float) -> void:
	var at: Vector2 = w["pos"]
	var r := wreck_radius(w)
	var flash := 0.6 if reduce_flashes else 1.0
	light.spawn(FLARE, at, Vector2.ZERO, 0.1, r / 26.0, r / 30.0, Color(1.0, 0.5, 0.2, 0.3 * u * flash),
			Color(1.0, 0.3, 0.1, 0.0))
	var x := _rng.randf_range(-0.7, 0.7) * r * (1.0 - u * 0.4)
	light.spawn(FLARE, at + Vector2(x, r * (0.5 + 0.3 * u)), Vector2(0, _rng.randf_range(10.0, 30.0)),
			_rng.randf_range(0.35, 0.55), _rng.randf_range(0.09, 0.13), 0.04, Color(1.0, 0.75, 0.35, 0.95),
			Color(0.9, 0.2, 0.05, 0.0), 0.5, Vector2(0, 220))
	if level >= 1 and _rng.randf() < 0.5:
		light.spawn(SPARKLE, at + Vector2(_rng.randf_range(-0.6, 0.6) * r, _rng.randf_range(-0.2, 0.4) * r),
				Vector2(_rng.randf_range(-10, 10), _rng.randf_range(-35, -15)), _rng.randf_range(0.5, 0.8), 0.8, 0.2,
				Color(1.0, 0.8, 0.4), Color(1.0, 0.3, 0.0, 0.0), 1.0)


## Queda no mar: coluna d'água, espuma e, logo depois, a explosão abafada lá embaixo com bolhas subindo.
func _land_water(at: Vector2, big: bool) -> void:
	var m := 1.5 if big else 1.0
	for k: int in range(int((5 + level * 4) * m)):
		light.spawn(SPARKLE, at + Vector2(_rng.randf_range(-4, 4), 0) * m,
				Vector2(_rng.randf_range(-30, 30), _rng.randf_range(-190, -90)) * sqrt(m), _rng.randf_range(0.5, 0.75),
				_rng.randf_range(1.4, 2.0), 0.5, Color(foam, 0.95), Color(foam, 0.0), 1.0, Vector2(0, 320))
	for k: int in range(int((4 + level * 2) * m)):
		var d := _dir()
		light.spawn(STREAK, at, Vector2(d.x, d.y * 0.5) * _rng.randf_range(40.0, 90.0) * m, _rng.randf_range(0.2, 0.35),
				0.6, 0.2, Color(foam, 0.8), Color(foam, 0.0), 4.0, Vector2.ZERO, 0.0, 0.0, true)
	light.spawn(FLARE, at, Vector2.ZERO, 0.5, 0.4 * m, 1.2 * m, Color(foam, 0.6 if reduce_flashes else 0.8),
			Color(foam, 0.0))
	later(0.12, _underwater.bind(at, m))


func _underwater(at: Vector2, m: float) -> void:
	light.spawn(FLARE, at, Vector2.ZERO, 0.35, 0.6 * m, 1.0 * m, Color(1.0, 0.55, 0.25, 0.35), Color(foam, 0.0))
	for k: int in range(int((4 + level * 3) * m)):
		light.spawn(SPARKLE, at + _dir() * _rng.randf_range(0.0, 8.0) * m,
				Vector2(_rng.randf_range(-12, 12), _rng.randf_range(-40, -15)), _rng.randf_range(0.6, 1.0), 0.7, 0.3,
				Color(foam, 0.6), Color(foam, 0.0), 0.5)


## Queda no chão: explosão, marca queimada, estilhaços e poeira em anel achatado (2,5D).
func _land_ground(at: Vector2, big: bool) -> void:
	var m := 1.5 if big else 1.0
	explosion(at, 1.6 if big else 1.0)
	matter.spawn(SMOKE, at, Vector2.ZERO, 1.0, 1.0 * m, 1.4 * m, Color(0.08, 0.06, 0.05, 0.35),
			Color(0.08, 0.06, 0.05, 0.0), 0.0, Vector2.ZERO, _rng.randf() * TAU)
	for k: int in range(int((3 + level * 2) * m)):
		matter.spawn(DEBRIS, at, _dir() * _rng.randf_range(40.0, 110.0) * m, _rng.randf_range(0.5, 0.8),
				_rng.randf_range(0.8, 1.3), 0.4, Color(0.6, 0.5, 0.45), Color(0.3, 0.25, 0.2, 0.0), 2.5,
				Vector2(0, 40), _rng.randf() * TAU, _rng.randf_range(-10.0, 10.0))
	for k: int in range(int((4 + level * 2) * m)):
		var d := _dir()
		matter.spawn(SMOKE, at, Vector2(d.x, d.y * 0.6) * _rng.randf_range(25.0, 45.0) * m, _rng.randf_range(0.5, 0.7),
				0.3, 0.8, Color(0.55, 0.5, 0.45, 0.4), Color(0.55, 0.5, 0.45, 0.0), 2.0)


func _dir() -> Vector2:
	return Vector2.from_angle(_rng.randf() * TAU)


static func _textures(names: Array) -> Array[Texture2D]:
	var out: Array[Texture2D] = []
	for n: Variant in names:
		out.append(SpriteBank.generated(String(n)))
	return out
