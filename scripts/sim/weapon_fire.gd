class_name WeaponFire
extends RefCounted
## Disparo das armas principais (plano mestre 4.1). O DPS de cada nível vem de data/weapons.json;
## o dano por bala sai do DPS dividido pela cadência e pelo número de balas, então trocar a forma do
## leque nunca muda o equilíbrio.
##
## Pulsar: leque de 3/5/7 tiros (o nível 3 soma 2 traseiros; Ressonância ondula).
## Laser: feixe contínuo de largura 6/9/12/14, resolvido pelo Sim (alvo mais próximo acima).

const SHOT_SPEED := 430.0
const PULSAR_INTERVAL := 6
const PULSAR_COUNT: Array[int] = [3, 5, 7, 7]
const PULSAR_SPREAD: Array[float] = [12.0, 24.0, 36.0, 40.0]
const LASER_WIDTH: Array[float] = [6.0, 9.0, 12.0, 14.0]


static func dps(weapon_def: Dictionary, level: int) -> float:
	var table: Array = weapon_def.get("dps", [60, 90, 130, 175])
	return float(table[clampi(level - 1, 0, table.size() - 1)])


static func laser_width(level: int) -> float:
	return LASER_WIDTH[clampi(level - 1, 0, LASER_WIDTH.size() - 1)]


## Dispara o Pulsar neste passo, se a recarga deixar. Devolve quantas balas saíram.
static func fire_pulsar(player: SimPlayer, pool: BulletPool, weapon_def: Dictionary, frame: int) -> int:
	if player.fire_timer > 0:
		player.fire_timer -= 1
		return 0
	player.fire_timer = PULSAR_INTERVAL - 1
	var i := clampi(player.level - 1, 0, 3)
	var count := PULSAR_COUNT[i]
	var backs := 2 if player.level >= 3 else 0
	var per_bullet := dps(weapon_def, player.level) / (60.0 / PULSAR_INTERVAL) / (count + backs * 0.5)
	var spread := PULSAR_SPREAD[i]
	var wobble := 0.0
	if player.level >= 4:
		wobble = sin(frame * 0.25) * 6.0
	var origin := player.pos + Vector2(0, -14)
	var shot := BulletKinds.player_index(&"shot_pulsar")
	var fired := 0
	for k: int in range(count):
		var u := float(k) / (count - 1) if count > 1 else 0.5
		var deg := -90.0 - spread * 0.5 + spread * u + wobble
		if pool.spawn(origin, Vector2.from_angle(deg_to_rad(deg)) * SHOT_SPEED, 4.0, shot, per_bullet) >= 0:
			fired += 1
	if backs > 0:
		var back := BulletKinds.player_index(&"shot_back")
		for deg: float in [75.0, 105.0]:
			pool.spawn(player.pos + Vector2(0, 8), Vector2.from_angle(deg_to_rad(deg)) * SHOT_SPEED * 0.8, 4.0,
					back, per_bullet * 0.5)
	return fired
