class_name Weather
extends RefCounted
## Clima e mar da missão (1.13 "Céu e Mar Vivos"): frentes de chuva, tempestade, neve, cinzas e
## corrente de jato no céu; plâncton, ressaca, termoclina, sedimento, corrente abissal e fontes
## termais sob a água; tempestade solar na órbita. Os estados vivem em data/weather.json.
##
## Uma frente chega com aviso (`warn`, a nave tem tempo de se preparar) e entra aos poucos (`ramp`):
## todo efeito na pilotagem cresce junto com a mistura, nunca de uma vez. Na nave, cada estado tem:
##   vento ou corrente (unidades/s), com rajadas e uma direção que oscila devagar (a corrente muda);
##   turbulência (deslocamento limitado, de média zero; o modo preciso a corta pela metade: o piloto
##     segura o manche);
##   resistência do meio (água turva, termoclina, gelo no casco, cinzas): a nave responde na hora,
##     só anda menos (a latência de 1 passo continua);
##   empurrão nas balas inimigas, uma fração do vento (a chuva inclinada mostra para onde).
## Atravessar uma frente severa inteira sem dano vale o bônus "Navegador da Tormenta".
## Tudo é função do passo e de um fluxo próprio do SimRng: a mesma semente dá o mesmo clima.

## Meio de cada cenário: o clima de uma missão precisa ser coerente com ele (tests/weather_tests.gd).
const MEDIUM_OF := {&"ocean": &"water", &"atlantis": &"water", &"hadal": &"water", &"storm": &"air",
		&"volcanic": &"air", &"city": &"air", &"ice": &"air", &"stratosphere": &"air", &"orbit": &"void",
		&"core": &"void"}
const DEFAULT_OF := {&"air": &"clear", &"water": &"calm", &"void": &"vacuum"}
## Bônus por frente severa vencida sem dano, e quanto tempo dela (passos) precisa ser atravessado.
const MASTERY_POINTS := 3000
const MASTERY_FRAMES := 8 * 60
## Turbulência: no máximo isto por passo (a nave nunca dá tranco) e o corte do modo preciso.
const TURB_STEP := 0.6
const TURB_PRECISE := 0.5
## Frequências da turbulência (rad/s): incomensuráveis, o desenho nunca se repete na missão.
const TURB_FREQ: Array[float] = [5.3, 8.9, 13.7]
const TURB_WEIGHT: Array[float] = [0.5, 0.3, 0.2]
## Onde a frente começa a valer para a maestria (mistura) e para trocar o rótulo.
const HALF := 0.5

var table: Dictionary = {}
var medium: StringName = &"air"
## Estado de destino e o de onde vem; `blend` vai de 0 (anterior) a 1 (destino).
var state: StringName = &"clear"
var previous: StringName = &"clear"
var blend: float = 1.0
## Frente anunciada esperando o aviso acabar.
var pending: StringName = &""
## Vento ou corrente agora (unidades/s), já com rajada e direção do momento.
var wind := Vector2.ZERO
## Turbulência (amplitude em unidades) e o deslocamento dela aplicado até aqui na nave 1 (o desenho
## balança a nave com isto).
var turbulence: float = 0.0
var shake := Vector2.ZERO
## Resistência do meio (multiplica o movimento da nave) e fração do vento nas balas.
var drag: float = 1.0
var push: float = 0.0
## Frentes severas vencidas sem dano nesta missão.
var mastered: int = 0

var _wing_shake := Vector2.ZERO
var _warn: int = 0
var _ramp: int = 1
var _phase := PackedFloat32Array()
var _severe_from: int = -1
var _severe_hull: int = 0
var _severe_kind: StringName = &""


func setup(mission: Dictionary, p_table: Dictionary, rng: SimRng) -> void:
	table = p_table
	medium = MEDIUM_OF.get(StringName(String(mission.get("backdrop", "ocean"))), &"water")
	state = valid(StringName(String(mission.get("weather", ""))))
	previous = state
	blend = 1.0
	var stream := rng.stream(&"weather")
	_phase.clear()
	for k: int in range(8):
		_phase.append(stream.randf() * TAU)
	_refresh(0)


## O id se existe na tabela e é do meio da missão; senão o padrão do meio (céu limpo, água calma, vácuo).
func valid(id: StringName) -> StringName:
	var row: Dictionary = table.get(id, {})
	if not row.is_empty() and StringName(String(row.get("medium", ""))) == medium:
		return id
	return DEFAULT_OF.get(medium, &"clear")


func def_of(id: StringName) -> Dictionary:
	return table.get(id, {})


## Evento de roteiro {"op": "weather", "to", "warn" (s), "ramp" (s)}: anuncia e agenda a frente.
func start(sim: Sim, ev: Dictionary) -> void:
	var to := valid(StringName(String(ev.get("to", ""))))
	if to == state and pending == &"":
		return
	pending = to
	_warn = maxi(0, int(float(ev.get("warn", 2.0)) * 60.0))
	_ramp = maxi(1, int(float(ev.get("ramp", 4.0)) * 60.0))
	sim.emit(&"weather", {"to": String(to), "from": String(state), "warn": _warn / 60.0, "ramp": _ramp / 60.0,
			"severe": bool(def_of(to).get("severe", false)), "medium": String(medium)})


## Um passo: aviso, mistura, vento e turbulência nas naves, resistência e o placar da tormenta.
## `precise`/`precise2`: modo preciso da nave 1 e da ala neste passo.
func step(sim: Sim, precise: bool, precise2: bool) -> void:
	if pending != &"":
		if _warn > 0:
			_warn -= 1
		else:
			# A frente nova parte de onde a mistura está agora (troca no meio de outra, sem salto).
			previous = state if blend >= HALF else previous
			state = pending
			pending = &""
			blend = 0.0
	if blend < 1.0:
		blend = minf(1.0, blend + 1.0 / float(_ramp))
	_refresh(sim.frame)
	shake = _turbulence(sim, sim.player, shake, precise, 0)
	if sim.wing != null:
		_wing_shake = _turbulence(sim, sim.wing, _wing_shake, precise2, 4)
	for ship: SimPlayer in [sim.player, sim.wing]:
		if ship == null or not ship.alive:
			continue
		ship.resist = drag
		if wind != Vector2.ZERO:
			ship.pos = (ship.pos + wind * Sim.STEP).clamp(SimPlayer.MARGIN, Playfield.FIELD - SimPlayer.MARGIN)
	_mastery(sim)


## Aceleração nas balas inimigas (unidades/s²).
func bullet_accel() -> Vector2:
	return wind * push


## Valor visual misturado (chave de "fx" em data/weather.json), 0 se o estado não tem.
func fx(key: String) -> float:
	return lerpf(_fx_of(previous, key), _fx_of(state, key), mix())


## Cor visual misturada (grade, haze_color) com a quantidade dela já aplicada no alfa.
func fx_color(key: String, amount_key: String) -> Color:
	var a := _color_of(previous, key)
	var b := _color_of(state, key)
	a.a = _fx_of(previous, amount_key)
	b.a = _fx_of(state, amount_key)
	return a.lerp(b, mix())


## Mistura suavizada (smoothstep): a frente entra e sai sem quina.
func mix() -> float:
	return blend * blend * (3.0 - 2.0 * blend)


## Estado que dá nome ao momento (o destino depois da metade da mistura).
func label() -> StringName:
	return state if blend >= HALF else previous


func severe() -> bool:
	return bool(def_of(label()).get("severe", false))


func _fx_of(id: StringName, key: String) -> float:
	return float((def_of(id).get("fx", {}) as Dictionary).get(key, 0.0))


func _color_of(id: StringName, key: String) -> Color:
	return Color(String((def_of(id).get("fx", {}) as Dictionary).get(key, "#000000")))


func _mix(key: String, fallback: float) -> float:
	return lerpf(float(def_of(previous).get(key, fallback)), float(def_of(state).get(key, fallback)), mix())


func _refresh(frame: int) -> void:
	var t := frame * Sim.STEP
	var strength := _mix("wind", 0.0)
	var period := maxf(1.0, _mix("period", 10.0))
	# Rajada: duas senoides lentas; a direção oscila em `meander` rad em torno do ângulo do estado.
	var gust := 1.0 + _mix("gust", 0.0) * (0.6 * sin(TAU * t / (period * 0.53) + _phase[0])
			+ 0.4 * sin(TAU * t / (period * 0.21) + _phase[1]))
	var angle := deg_to_rad(_angle()) + _mix("meander", 0.0) * sin(TAU * t / period + _phase[2])
	wind = Vector2.from_angle(angle) * strength * maxf(0.0, gust)
	turbulence = _mix("turbulence", 0.0)
	drag = _mix("drag", 1.0)
	push = _mix("push", 0.0)


## Ângulo misturado pelo caminho mais curto (de 350° para 10° passa por 0°, não por 180°).
func _angle() -> float:
	var a := float(def_of(previous).get("angle", 0.0))
	var b := float(def_of(state).get("angle", 0.0))
	return a + wrapf(b - a, -180.0, 180.0) * mix()


## Turbulência: o alvo é uma soma de senoides vezes a amplitude; a nave anda até ele no máximo
## TURB_STEP por passo. O deslocamento total fica limitado (média zero), nunca acumula deriva.
func _turbulence(sim: Sim, ship: SimPlayer, offset: Vector2, precise: bool, salt: int) -> Vector2:
	if not ship.alive:
		return offset
	var t := sim.frame * Sim.STEP
	var amp := turbulence * (TURB_PRECISE if precise else 1.0)
	var n := Vector2.ZERO
	for k: int in range(TURB_FREQ.size()):
		n.x += TURB_WEIGHT[k] * sin(t * TURB_FREQ[k] + _phase[(k + salt) % 8])
		n.y += TURB_WEIGHT[k] * sin(t * TURB_FREQ[k] * 0.83 + _phase[(k + salt + 3) % 8])
	var target := Vector2(n.x, n.y * 0.6) * amp
	var delta := (target - offset).limit_length(TURB_STEP)
	ship.pos = (ship.pos + delta).clamp(SimPlayer.MARGIN, Playfield.FIELD - SimPlayer.MARGIN)
	return offset + delta


## Navegador da Tormenta: atravessar uma frente severa (da metade da entrada à metade da saída) sem dano.
func _mastery(sim: Sim) -> void:
	var now_severe := severe()
	if now_severe and _severe_from < 0:
		_severe_from = sim.frame
		_severe_hull = sim.scoring.hull_lost
		_severe_kind = label()
	elif not now_severe and _severe_from >= 0:
		var lasted := sim.frame - _severe_from
		if lasted >= MASTERY_FRAMES and sim.scoring.hull_lost == _severe_hull and sim.player.alive:
			mastered += 1
			var points := int(MASTERY_POINTS * sim.scoring.point_mult)
			sim.scoring.add_bonus(points)
			sim.emit(&"weather_mastered", {"kind": String(_severe_kind), "points": points, "pos": sim.player.pos})
		_severe_from = -1
