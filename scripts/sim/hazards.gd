class_name Hazards
extends RefCounted
## Regras de capítulo do Beta (plano mestre 4.8, 5.2 e 6.4), fora da Sim para ela caber no limite de
## tamanho: Gravity Breach (com o bônus Redemoinho: raspões valem em dobro), prédios que sobem como
## cobertura e bloqueiam balas, cápsulas de resgate com combo, faixas que o Leviathan Protocol aprende
## e a escolha do final no voo.

const BREACH_PLAYER_SHARE := 0.4
const FLIP_FRAMES := 240
const COVER_RISE := 45
const CAPSULE_POINTS := 500
const CAPSULE_COMBO_MAX := 8
const LANES := 3
## Distância horizontal do feixe final que conta como "entrar no feixe".
const ENDING_BEAM := 34.0


## Eventos de roteiro deste módulo; devolve se tratou.
static func on_event(sim: Sim, ev: Dictionary) -> bool:
	match StringName(String(ev.get("op", ""))):
		&"gravity_breach":
			breach(sim, Vector2(float(ev.get("dx", 0.0)), float(ev.get("dy", 1.0))), float(ev.get("strength", 40.0)),
					float(ev.get("duration", 8.0)), bool(ev.get("flip", false)))
		&"cover":
			var w := float(ev.get("width", 40.0))
			sim.covers.append({"x": float(ev.get("x", 0.5)) * Playfield.FIELD.x, "w": w,
					"h": float(ev.get("height", 120.0)), "age": 0, "life": int(float(ev.get("duration", 8.0)) * 60.0)})
			sim.emit(&"cover", {"x": float(ev.get("x", 0.5)) * Playfield.FIELD.x})
		&"capsule":
			sim.pickups.append({"kind": &"capsule", "pos": Vector2(float(ev.get("x", 0.5)) * Playfield.FIELD.x, -12.0),
					"vel": Vector2(0, 40), "frames": 0})
		_:
			return false
	return true


## Liga a Gravity Breach: balas inimigas recebem o vetor inteiro, as do jogador 40%.
static func breach(sim: Sim, dir: Vector2, strength: float, seconds: float, flip: bool) -> void:
	sim.breach_dir = dir.normalized() * strength
	sim.breach_frames = int(seconds * 60.0)
	sim.breach_flip = flip
	sim.emit(&"gravity_breach", {"dir": sim.breach_dir.normalized(), "duration": seconds})


## Um passo: tempo da Breach (e a inversão a cada 4 s no núcleo), prédios e faixas do jogador.
static func step(sim: Sim) -> void:
	if sim.breach_frames > 0:
		sim.breach_frames -= 1
		if sim.breach_flip and sim.breach_frames % FLIP_FRAMES == 0 and sim.breach_frames > 0:
			sim.breach_dir = -sim.breach_dir
			sim.emit(&"gravity_breach", {"dir": sim.breach_dir.normalized(), "duration": sim.breach_frames / 60.0})
		if sim.breach_frames == 0:
			sim.breach_dir = Vector2.ZERO
			sim.emit(&"gravity_end", {})
	var i := sim.covers.size() - 1
	while i >= 0:
		var c: Dictionary = sim.covers[i]
		c["age"] = int(c["age"]) + 1
		if int(c["age"]) >= int(c["life"]):
			sim.covers.remove_at(i)
		i -= 1
	if not sim.covers.is_empty():
		_block(sim, sim.enemy_bullets)
		_block(sim, sim.player_bullets)
	if sim.player.alive:
		var lane := clampi(floori(sim.player.pos.x / (Playfield.FIELD.x / LANES)), 0, LANES - 1)
		sim.lanes[lane] += 1


## Retângulo atual de um prédio (sobe do fundo em COVER_RISE passos e desce no último segundo).
static func cover_rect(c: Dictionary) -> Rect2:
	var age := int(c["age"])
	var rise := minf(1.0, age / float(COVER_RISE))
	rise = minf(rise, maxf(0.0, (int(c["life"]) - age) / 60.0))
	var h := float(c["h"]) * rise
	return Rect2(float(c["x"]) - float(c["w"]) * 0.5, Playfield.FIELD.y - h, float(c["w"]), h)


static func _block(sim: Sim, pool: BulletPool) -> void:
	var rects: Array[Rect2] = []
	for c: Dictionary in sim.covers:
		rects.append(cover_rect(c))
	var i := pool.count - 1
	while i >= 0:
		var p: Vector2 = pool.pos[i]
		for r: Rect2 in rects:
			if r.has_point(p):
				pool.kill(i)
				break
		i -= 1


static func collect_capsule(sim: Sim) -> void:
	sim.rescued += 1
	sim.capsule_combo = mini(CAPSULE_COMBO_MAX, sim.capsule_combo + 1)
	sim.max_capsule_combo = maxi(sim.max_capsule_combo, sim.capsule_combo)
	sim.scoring.add_bonus(int(CAPSULE_POINTS * sim.capsule_combo * sim.scoring.point_mult))
	sim.emit(&"capsule", {"pos": sim.player.pos, "combo": sim.capsule_combo})


## Faixa (0, 1 ou 2) onde o jogador mais voou nesta missão.
static func favorite_lane(sim: Sim) -> int:
	var best := 1
	for k: int in range(LANES):
		if sim.lanes[k] > sim.lanes[best]:
			best = k
	return best


## Centro da faixa onde o jogador mais voou (o Leviathan Protocol se posiciona ali na etapa "learn").
static func favorite_lane_x(sim: Sim) -> float:
	return (favorite_lane(sim) + 0.5) * Playfield.FIELD.x / LANES


## Final escolhido no voo (plano mestre 3.4): com os 4 Registros Abissais, "Maré Alta"; senão entrar no
## feixe do núcleo devolve o Coração ("return") e desviar dele o destrói ("shattered").
static func ending_for(sim: Sim, boss: SimBoss) -> StringName:
	if int(sim.loadout.get("abyss_records", 0)) >= 4:
		return &"high_tide"
	return &"return" if absf(sim.player.pos.x - boss.body_pos().x) <= ENDING_BEAM else &"shattered"
