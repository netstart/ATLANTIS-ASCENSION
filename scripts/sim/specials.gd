class_name Specials
extends RefCounted
## Especiais das aeronaves (plano mestre 4.1), uma por aeronave, com recarga por tempo e por graze:
## - area_bomb (Falcon): todas as balas viram pérolas, dano em todos os inimigos da tela.
## - tide_shield (Atlas): 4 s de invulnerabilidade; bala que toca o escudo vira pérola.
## - focused_burst (Manta): 3 s de feixe largo com dano x4 (mesmo com outra arma).
## - drone_swarm (Hydra): 6 drones por 8 s (SecondaryFire).
## - emp_pulse (Tempest): congela balas e padrões inimigos por 3 s e cancela os feixes.
## - gravity_rift (Tridente): por 3 s uma fenda acima da nave puxa as balas e as transforma em pérolas.

const DURATION := {
	&"area_bomb": 1, &"tide_shield": 240, &"focused_burst": 180, &"drone_swarm": 480, &"emp_pulse": 180,
	&"gravity_rift": 180,
}
const SHIELD_RADIUS := 28.0
const RIFT_OFFSET := Vector2(0, -120)
const RIFT_RADIUS := 130.0
const RIFT_PULL := 160.0
const BURST_WIDTH := 22.0
const BURST_MULT := 4.0


static func activate(sim: Sim, kind: StringName) -> void:
	sim.special_kind = kind
	sim.special_frames = int(DURATION.get(kind, 1))
	sim.special_point = sim.player.pos + RIFT_OFFSET
	sim.player.invuln = maxi(sim.player.invuln, SimPlayer.SPECIAL_INVULN)
	match kind:
		&"area_bomb":
			sim.area_blast(Sim.SPECIAL_DAMAGE)
		&"tide_shield":
			sim.player.invuln = maxi(sim.player.invuln, DURATION[kind])
		&"emp_pulse":
			sim.beams.clear()
	sim.emit(&"special", {"pos": sim.player.pos, "kind": String(kind)})


static func step(sim: Sim) -> void:
	if sim.special_frames <= 0:
		return
	sim.special_frames -= 1
	match sim.special_kind:
		&"tide_shield":
			sim.pearls_from(sim.enemy_bullets.cancel_near(sim.player.pos, SHIELD_RADIUS))
		&"gravity_rift":
			sim.pearls_from(sim.enemy_bullets.pull(sim.special_point, RIFT_RADIUS, RIFT_PULL, Sim.STEP))
		&"focused_burst":
			sim.burst_beam(BURST_WIDTH, BURST_MULT)


## Congela balas e padrões inimigos (Pulso EMP).
static func frozen(sim: Sim) -> bool:
	return sim.special_kind == &"emp_pulse" and sim.special_frames > 0
