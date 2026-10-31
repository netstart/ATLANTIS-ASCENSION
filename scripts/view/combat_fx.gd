class_name CombatFx
extends RefCounted
## Receitas de efeito da partida (.ai/06-pesquisa-efeitos-visuais.md): o que cada acontecimento da Sim
## vira na tela. Explosão em camadas (clarão, bolas de fogo, faíscas, fumaça, estilhaços, onda de
## choque), impacto do tiro, boca do canhão, coleta, splash na água, destroços que caem até o chão
## (2,5D), cancelamento de balas em ondas e números de pontos. Duas camadas de partículas: `light`
## (aditiva, linear: tudo que brilha) e `matter` (normal, pixel art: fumaça e estilhaços).
## Só visual: a semente própria dá variedade; qualidade gráfica e "reduzir flashes" mudam a dose,
## nunca a partida.

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
const WRECK_TIME := 0.75
## Ondas de cancelamento: balas que somem por ordem de distância, até este atraso (s).
const CANCEL_SPREAD := 0.45

var light: ParticleField
var matter: ParticleField
## 0 = mínimo, 1 = normal, 2 = completo (GfxQuality "weapon_fx").
var level: int = 2
var reduce_flashes: bool = false
## Cenário com chão ou água (destroços caem e espirram); falso no espaço.
var ground: bool = true
var water: bool = true
var foam := Color(0.7, 0.95, 1.0)
## Números de pontos: {pos, text, t, color}.
var popups: Array[Dictionary] = []
## Destroços caindo para o chão: {tex, size, pos, to, t, spin, scale}.
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


## Espirro na água (ou poeira no chão) onde um destroço cai.
func splash(at: Vector2) -> void:
	var col := foam if water else Color(0.55, 0.5, 0.45)
	for k: int in range(3 + level * 2):
		var v := _dir() * _rng.randf_range(20.0, 60.0)
		if water:
			light.spawn(SPARKLE, at, v, _rng.randf_range(0.3, 0.5), 1.0, 0.3, Color(col, 0.8), Color(col, 0.0), 3.0)
		else:
			matter.spawn(SMOKE, at, v * 0.5, _rng.randf_range(0.4, 0.7), 0.3, 0.8, Color(col, 0.5), Color(col, 0.0), 2.0)


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


## Destroço: a nave abatida cai girando até a sombra, encolhendo e escurecendo; espirra no fim.
func wreck(tex: Texture2D, size: int, at: Vector2, to: Vector2, scale: float) -> void:
	if tex == null or not ground or wrecks.size() >= MAX_WRECKS:
		return
	wrecks.append({"tex": tex, "size": size, "pos": at, "from": at, "to": to, "t": 0.0, "scale": scale,
			"spin": _rng.randf_range(-3.0, 3.0)})


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
	var i := wrecks.size() - 1
	while i >= 0:
		var w := wrecks[i]
		w["t"] = float(w["t"]) + delta
		var u := minf(1.0, float(w["t"]) / WRECK_TIME)
		w["pos"] = (w["from"] as Vector2).lerp(w["to"], u * u)
		if u >= 1.0:
			splash(w["pos"])
			wrecks.remove_at(i)
		i -= 1


func _dir() -> Vector2:
	return Vector2.from_angle(_rng.randf() * TAU)


static func _textures(names: Array) -> Array[Texture2D]:
	var out: Array[Texture2D] = []
	for n: Variant in names:
		out.append(SpriteBank.generated(String(n)))
	return out
