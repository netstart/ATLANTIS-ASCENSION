class_name SimBeam
extends RefCounted
## Feixe vertical do Laser e da Rajada (Sim._beam_attack): acerta só o alvo mais próximo acima da nave (inimigo, parte
## ou corpo do chefe, pelo círculo de dano de cada um: Hitboxes) e guarda onde o feixe para (Sim.laser_to_y).


static func attack(sim: Sim, width: float, dps_value: float) -> void:
	if not sim.player.alive:
		return
	sim.laser_width = width
	var half := width * 0.5
	var me := sim.player.pos
	var dmg := dps_value * Sim.STEP
	var best_y := -Sim.BOUNDS.size.y
	var target: SimEnemy = null
	for e: SimEnemy in sim.enemies:
		var ep := e.hit_pos()
		if e.active() and absf(ep.x - me.x) <= half + e.hurt and ep.y < me.y and ep.y > best_y:
			best_y = ep.y
			target = e
	var boss_part: Dictionary = {}
	var boss_body := false
	var boss := sim.boss
	if boss != null and boss.fighting():
		for part: Dictionary in boss.parts:
			var pp := boss.part_hit_pos(part)
			if boss.part_active(part) and absf(pp.x - me.x) <= half + boss.part_radius(part) \
					and pp.y < me.y and pp.y > best_y:
				best_y = pp.y
				boss_part = part
				target = null
		var bp := boss.hurt_pos()
		if absf(bp.x - me.x) <= half + boss.hurt_radius() and bp.y < me.y and bp.y > best_y:
			best_y = bp.y
			boss_body = true
			boss_part = {}
			target = null
	sim.laser_to_y = best_y
	if target != null:
		if target.damage(dmg):
			sim.kill_enemy(target)
	elif not boss_part.is_empty():
		boss.damage_part(boss_part, dmg, sim)
	elif boss_body:
		boss.damage_body(dmg, sim)
