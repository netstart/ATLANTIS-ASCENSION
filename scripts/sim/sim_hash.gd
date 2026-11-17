class_name SimHash
extends RefCounted
## Hash do estado da Sim (teste de determinismo em 1x, 2x, 3x e em qualquer qualidade gráfica): frame, placar,
## nave, balas, inimigos, chefe e clima num md5. Fora da Sim só para ela caber no limite de linhas.


static func of(sim: Sim) -> String:
	var parts := PackedStringArray([str(sim.frame), str(sim.scoring.score), str(sim.scoring.grazes),
			str(sim.player.hull), "%.3f,%.3f" % [sim.player.pos.x, sim.player.pos.y], str(sim.enemy_bullets.count),
			str(sim.player_bullets.count), str(sim.enemies.size()), str(sim.pickups.size()), "%.4f" % sim.rank,
			str(sim.missiles.size()), ",".join(sim.mods.taken), str(sim.rescued), str(sim.breach_frames), str(sim.captured),
			"%.4f" % sim.player.power_charge, str(sim.power_fx.size()), str(sim.powers.casts)])
	if sim.wing != null:
		parts.append("w%.3f,%.3f:%d" % [sim.wing.pos.x, sim.wing.pos.y, sim.wing.level])
	parts.append("%s:%.3f:%d" % [sim.weather.state, sim.weather.blend, sim.weather.mastered])
	for e: SimEnemy in sim.enemies:
		parts.append("%s:%.2f,%.2f:%.2f" % [e.id, e.pos.x, e.pos.y, e.hp])
	var sum := Vector2.ZERO
	for i: int in range(sim.enemy_bullets.count):
		sum += sim.enemy_bullets.pos[i]
	parts.append("%.2f,%.2f" % [sum.x, sum.y])
	if sim.boss != null:
		parts.append("%s:%d:%.2f" % [sim.boss.id, sim.boss.phase_index, sim.boss.hp])
	return ",".join(parts).md5_text()
