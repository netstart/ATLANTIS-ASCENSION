class_name HitCircles
extends RefCounted
## Depuração das caixas de colisão (Hitboxes; WorldView.debug_hitboxes, galerias de tests/game_shots_runner.gd
## --hitboxes): os círculos que a Sim usa, por cima de tudo, no mesmo espaço do campo.


## Círculos de colisão (debug_hitboxes): dano em ciano, contato em laranja, partes do chefe em verde, nave em branco.
static func draw(ci: CanvasItem, sim: Sim) -> void:
	var hurt := Color(0.3, 0.95, 1.0, 0.9)
	var contact := Color(1.0, 0.6, 0.2, 0.9)
	for e: SimEnemy in sim.enemies:
		if e.alive:
			ci.draw_arc(e.hit_pos(), e.hurt, 0.0, TAU, 40, hurt, 1.0)
			if e.contact:
				ci.draw_arc(e.hit_pos(), e.contact_radius, 0.0, TAU, 32, contact, 1.0)
	var b := sim.boss
	if b != null and b.state != SimBoss.State.DEAD:
		ci.draw_arc(b.hurt_pos(), b.hurt_radius(), 0.0, TAU, 64, hurt, 1.0)
		ci.draw_arc(b.hurt_pos(), b.contact_radius(), 0.0, TAU, 48, contact, 1.0)
		for part: Dictionary in b.parts:
			if bool(part["alive"]):
				ci.draw_arc(b.part_hit_pos(part), b.part_radius(part), 0.0, TAU, 24, Color(0.4, 1.0, 0.5, 0.9), 1.0)
	for ship: SimPlayer in [sim.player, sim.wing]:
		if ship != null and ship.alive:
			ci.draw_arc(ship.hit_pos(), ship.hitbox, 0.0, TAU, 16, Color(1, 1, 1), 1.0)
			ci.draw_circle(ship.hit_pos(), 0.8, Color(1, 0.2, 0.3))
