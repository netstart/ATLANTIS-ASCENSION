class_name SimPlayer
extends RefCounted
## Aeronave do jogador (plano mestre 2.3, 4.1, 4.3): movimento relativo, casco em segmentos, arma
## com níveis, especial com recarga, bombas e invulnerabilidade depois do dano.

const START := Vector2(135, 390)
## Teclado e controle: unidades por passo (modo preciso pela metade).
const AXIS_SPEED := 3.2
## Arrasto: no máximo isto por passo, para o dedo nunca teleportar a nave.
const MAX_DRAG_STEP := 14.0
const MARGIN := Vector2(10, 14)
const HIT_INVULN := 90
const BOMB_INVULN := 90
const SPECIAL_INVULN := 30
const SPECIAL_FRAMES := 25 * 60
const GRAZE_CHARGE := 0.0025
const START_BOMBS := 2

var ship: Dictionary = {}
var pos := START
var hull: int = 3
var max_hull: int = 3
var hitbox: float = 3.0
var speed_mult: float = 1.0
var weapon: StringName = &"pulsar"
var level: int = 1
var signature: StringName = &"pulsar"
var fire_timer: int = 0
var invuln: int = 0
var special_charge: float = 0.0
var bombs: int = START_BOMBS
var alive: bool = true
## Modificadores do hangar e das bênçãos (SimMods).
var precise_mult: float = 0.5
var invuln_bonus: int = 0
var cap_bonus: int = 0
## Arma travada (missão secreta "só Railgun"): orbes não trocam a arma.
var weapon_lock: StringName = &""
## Velocidade do último passo (inclinação da nave no desenho).
var last_move := Vector2.ZERO


func setup(p_ship: Dictionary, sensitivity: float) -> void:
	ship = p_ship
	max_hull = int(ship.get("hull", 3))
	hull = max_hull
	hitbox = float(ship.get("hitbox", 3.0))
	speed_mult = float(ship.get("speed", 1.0)) * sensitivity
	signature = StringName(String(ship.get("signature", "pulsar")))
	weapon = signature


func max_level() -> int:
	return (4 if weapon == signature else 3) + cap_bonus


func move(input: SimInput) -> void:
	var before := pos
	var drag := input.move * speed_mult
	if drag.length() > MAX_DRAG_STEP:
		drag = drag.normalized() * MAX_DRAG_STEP
	var axis := input.axis.limit_length(1.0) * AXIS_SPEED * float(ship.get("speed", 1.0))
	if input.precise:
		axis *= precise_mult
	pos += drag + axis
	pos.x = clampf(pos.x, MARGIN.x, Playfield.FIELD.x - MARGIN.x)
	pos.y = clampf(pos.y, MARGIN.y, Playfield.FIELD.y - MARGIN.y)
	last_move = pos - before


func tick() -> void:
	if invuln > 0:
		invuln -= 1
	special_charge = minf(1.0, special_charge + 1.0 / SPECIAL_FRAMES)


func vulnerable() -> bool:
	return alive and invuln <= 0


## Dano: tira um segmento e um nível de arma. Devolve true se a aeronave caiu.
func take_hit() -> bool:
	hull -= 1
	level = maxi(1, level - 1)
	invuln = HIT_INVULN + invuln_bonus
	if hull <= 0:
		alive = false
	return not alive


## Orbe coletado: mesma cor sobe o nível; outra cor troca a arma e mantém o nível.
func collect_orb(orb_weapon: StringName) -> bool:
	if weapon_lock != &"":
		orb_weapon = weapon_lock
	if orb_weapon == weapon:
		var before := level
		level = mini(level + 1, max_level())
		return level != before
	weapon = orb_weapon
	level = mini(level, max_level())
	return true
