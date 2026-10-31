class_name SimEnemy
extends RefCounted
## Um inimigo comum (plano mestre 6.2): definição de data/enemies.json + trajetória + padrão.
## Entrada "do fundo" (2.5D): nasce com profundidade 0,6, sem colidir nem atirar, e sobe a 1,0.

const DEPTH_START := 0.6
const DEPTH_FRAMES := 48
## Margem além do campo onde o inimigo some depois de ter entrado.
const EXIT_MARGIN := 48.0

var id: StringName
var def: Dictionary = {}
var sprite: StringName
var hp: float = 1.0
var max_hp: float = 1.0
var radius: float = 12.0
var points: int = 100
var marked: bool = false
var drop: StringName = &""
var origin := Vector2.ZERO
var path: StringName = &"straight"
var params: Dictionary = {}
var frames: int = 0
var pos := Vector2.ZERO
var depth: float = 1.0
var alive: bool = true
var entered: bool = false
## Passos de brilho branco depois de levar dano (só visual).
var flash: int = 0
var runner: PatternRunner


func setup(p_def: Dictionary, p_origin: Vector2, p_path: StringName, p_params: Dictionary, patterns: Dictionary,
		from_depth: bool) -> void:
	def = p_def
	id = StringName(String(def.get("id", "")))
	sprite = StringName(String(def.get("sprite", "")))
	max_hp = float(def.get("hp", 1.0))
	hp = max_hp
	radius = float(def.get("radius", 12.0))
	points = int(def.get("points", 100))
	origin = p_origin
	pos = p_origin
	path = p_path
	params = p_params
	depth = DEPTH_START if from_depth else 1.0
	var pattern_id := String(def.get("pattern", ""))
	if not pattern_id.is_empty() and patterns.has(StringName(pattern_id)):
		runner = PatternRunner.new(patterns[StringName(pattern_id)], int(def.get("pattern_delay", 30)))


func active() -> bool:
	return alive and depth >= 1.0


func step(sim: Sim) -> void:
	frames += 1
	pos = Paths.position(path, origin, frames * Sim.STEP, params)
	if depth < 1.0:
		depth = minf(1.0, depth + (1.0 - DEPTH_START) / DEPTH_FRAMES)
	if flash > 0:
		flash -= 1
	var inside := Rect2(Vector2.ZERO, Playfield.FIELD).has_point(pos)
	if inside:
		entered = true
	elif entered and not Rect2(Vector2.ZERO, Playfield.FIELD).grow(EXIT_MARGIN).has_point(pos):
		alive = false
		return
	elif frames > 60 * 20:
		alive = false
		return
	if runner != null and active() and inside:
		runner.step(sim, pos, sim.can_fire())


func damage(amount: float) -> bool:
	if not active():
		return false
	hp -= amount
	flash = 3
	return hp <= 0.0
