class_name SecondaryArt
extends RefCounted
## Desenho da secundária (SecondaryFire): mísseis, drones e o rastro aceso deles. Só lê a Sim; o WorldView chama draw
## na camada dos coletáveis e draw_add na luz aditiva. Cada nível na fase (revisão 10) se lê à primeira vista:
## - Mísseis: 2, 4 e 6 foguetes (níveis 1 a 3, o foguete da série Void com a chama animada); Ogiva I (nível 4) maior,
##   em aço e ciano, com rastro ciano; Ogiva II (nível 5) dourada, mais larga, com rastro longo e halo dourados.
## - Drones: orbe ciano nos níveis 1 a 3 (1 a 3 drones); violeta com halo no 4 e dourado com halo no 5. O tiro deles
##   muda junto (BulletKinds shot_drone_heavy e shot_drone_gold).
## Arte das ogivas e drones em tools/gen_sprites.py (fx/warhead_*, fx/drone_*).

const ANIM_FPS := 12.0
## Rastro aditivo (fx/streak, ponta clara no míssil) por nível 4 e 5: largura, comprimento e cor.
const TRAIL_W: Array[float] = [4.0, 6.0]
const TRAIL_LEN: Array[float] = [20.0, 30.0]
const TRAIL_COLOR: Array[Color] = [Color(0.35, 0.95, 1.0, 0.9), Color(1.0, 0.78, 0.3, 0.95)]
const DRONE_HALO: Array[Color] = [Color(0.75, 0.45, 1.0, 0.55), Color(1.0, 0.78, 0.3, 0.6)]

static var _rocket: Texture2D
static var _warheads: Array[Texture2D] = []
static var _drones: Array[Texture2D] = []
static var _streak: Texture2D
static var _glow: Texture2D


static func _load() -> void:
	if _streak != null:
		return
	_rocket = SpriteBank.texture("res://assets/art/void/main_ship/proj_rocket.png")
	_warheads = [SpriteBank.generated("fx/warhead_heavy"), SpriteBank.generated("fx/warhead_gold")]
	_drones = [SpriteBank.generated("fx/drone"), SpriteBank.generated("fx/drone_heavy"),
			SpriteBank.generated("fx/drone_gold")]
	_streak = SpriteBank.generated("fx/streak")
	_glow = SpriteBank.generated("fx/glow_32")


## Nível de desenho dos drones da secundária: 0 = ciano (1 a 3), 1 = violeta (4), 2 = dourado (5).
static func drone_tier(sim: Sim) -> int:
	if sim.secondary != &"drones" or not SecondaryFire.phased(sim):
		return 0
	return clampi(sim.secondary_level - 3, 0, 2)


## Quantos drones da lista são da secundária (os primeiros; os do especial e do traço vêm depois).
static func own_drones(sim: Sim) -> int:
	return SecondaryFire.drones_at(sim) if sim.secondary == &"drones" else 0


static func draw(ci: CanvasItem, sim: Sim, time: float) -> void:
	_load()
	for m: Dictionary in sim.missiles:
		var mp: Vector2 = m["pos"]
		var angle := (m["vel"] as Vector2).angle() + PI * 0.5
		var tier := int(m.get("tier", 1))
		ci.draw_set_transform(mp, angle)
		if tier >= 4:
			var tex := _warheads[mini(tier - 4, 1)]
			ci.draw_texture(tex, -(tex.get_size() * 0.5).floor())
		elif _rocket != null:
			var rh := _rocket.get_height()
			ci.draw_texture_rect_region(_rocket, Rect2(-rh * 0.5, -rh * 0.5, rh, rh),
					SpriteBank.frame_rect(int(time * ANIM_FPS) % maxi(1, _rocket.get_width() / rh), rh))
		ci.draw_set_transform(Vector2.ZERO)
	var own := own_drones(sim)
	var tex_own := _drones[drone_tier(sim)]
	for k: int in range(sim.drones.size()):
		var tex := tex_own if k < own else _drones[0]
		ci.draw_texture(tex, sim.drones[k] - tex.get_size() * 0.5)


## Luz das ogivas (rastro e halo) e dos drones dos níveis 4 e 5.
static func draw_add(ci: CanvasItem, sim: Sim, time: float) -> void:
	_load()
	for m: Dictionary in sim.missiles:
		var tier := int(m.get("tier", 1))
		if tier < 4:
			continue
		var i := mini(tier - 4, 1)
		var mp: Vector2 = m["pos"]
		var w := TRAIL_W[i] * (0.9 + 0.2 * sin(time * 40.0 + mp.x))
		ci.draw_set_transform(mp, (m["vel"] as Vector2).angle() + PI * 0.5)
		ci.draw_texture_rect(_streak, Rect2(-w * 0.5, 7.0 + 2.0 * i, w, TRAIL_LEN[i]), false, TRAIL_COLOR[i])
		ci.draw_set_transform(Vector2.ZERO)
		if i == 1:
			var s := 0.6 + 0.1 * sin(time * 14.0 + mp.y)
			ci.draw_texture_rect(_glow, Rect2(mp - Vector2(16, 16) * s, Vector2(32, 32) * s), false,
					Color(TRAIL_COLOR[1], 0.6))
	var tier_d := drone_tier(sim)
	if tier_d == 0:
		return
	var s2 := 0.55 + 0.08 * sin(time * 9.0)
	for k: int in range(mini(own_drones(sim), sim.drones.size())):
		ci.draw_texture_rect(_glow, Rect2(sim.drones[k] - Vector2(16, 16) * s2, Vector2(32, 32) * s2), false,
				DRONE_HALO[tier_d - 1])
