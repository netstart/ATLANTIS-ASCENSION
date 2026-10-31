class_name WeaponFire
extends RefCounted
## Disparo das armas principais (plano mestre 4.1). O DPS de cada nível vem de data/weapons.json; o
## dano por bala sai do DPS dividido pela cadência e pelo número de balas, então trocar a forma do
## disparo nunca muda o equilíbrio. Modificadores (hangar, bênçãos, Maré Alta) multiplicam o dano.
##
## Pulsar: leque de 3/5/7 tiros (nível 3 soma 2 traseiros; Ressonância ondula).
## Laser: feixe contínuo de largura 6/9/12/14, resolvido pela Sim (alvo mais próximo acima).
## Plasma: esferas lentas que explodem em área (12/16/16/24 de raio); Ressonância junta numa grande.
## Railgun: agulhas que atravessam 2/3/4/6 alvos; 1, 2, 3 e 4 por disparo.

const SHOT_SPEED := 430.0
const PULSAR_INTERVAL := 6
const PULSAR_COUNT: Array[int] = [3, 5, 7, 7]
const PULSAR_SPREAD: Array[float] = [12.0, 24.0, 36.0, 40.0]
const LASER_WIDTH: Array[float] = [6.0, 9.0, 12.0, 14.0]
const PLASMA_INTERVAL := 14
const PLASMA_SPEED := 240.0
const PLASMA_COUNT: Array[int] = [1, 2, 3, 1]
const PLASMA_SPLASH: Array[float] = [12.0, 16.0, 16.0, 26.0]
const RAIL_INTERVAL: Array[int] = [18, 16, 14, 12]
const RAIL_COUNT: Array[int] = [1, 2, 3, 4]
const RAIL_PIERCE: Array[int] = [2, 3, 4, 6]
const RAIL_SPEED := 620.0


static func dps(weapon_def: Dictionary, level: int) -> float:
	var table: Array = weapon_def.get("dps", [60, 90, 130, 175])
	return float(table[clampi(level - 1, 0, table.size() - 1)])


static func laser_width(level: int) -> float:
	return LASER_WIDTH[clampi(level - 1, 0, LASER_WIDTH.size() - 1)]


## Dispara a arma principal (menos o Laser) se a recarga deixar. Devolve quantas balas saíram.
static func fire(player: SimPlayer, pool: BulletPool, weapon_def: Dictionary, frame: int, dmg_mult: float,
		rate: float) -> int:
	if player.fire_timer > 0:
		player.fire_timer -= 1
		return 0
	match player.weapon:
		&"plasma":
			return _plasma(player, pool, weapon_def, dmg_mult, rate)
		&"railgun":
			return _railgun(player, pool, weapon_def, dmg_mult, rate)
	return _pulsar(player, pool, weapon_def, frame, dmg_mult, rate)


static func _interval(base: int, rate: float) -> int:
	return maxi(2, roundi(base / maxf(rate, 0.1)))


static func _pulsar(player: SimPlayer, pool: BulletPool, weapon_def: Dictionary, frame: int, dmg_mult: float,
		rate: float) -> int:
	var interval := _interval(PULSAR_INTERVAL, rate)
	player.fire_timer = interval - 1
	var i := clampi(player.level - 1, 0, 3)
	var count := PULSAR_COUNT[i]
	var backs := 2 if player.level >= 3 else 0
	var per_bullet := dps(weapon_def, player.level) * dmg_mult / (60.0 / PULSAR_INTERVAL) / (count + backs * 0.5)
	var spread := PULSAR_SPREAD[i]
	var wobble := sin(frame * 0.25) * 6.0 if player.level >= 4 else 0.0
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


static func _plasma(player: SimPlayer, pool: BulletPool, weapon_def: Dictionary, dmg_mult: float, rate: float) -> int:
	player.fire_timer = _interval(PLASMA_INTERVAL, rate) - 1
	var i := clampi(player.level - 1, 0, 3)
	var count := PLASMA_COUNT[i]
	# Metade do dano no impacto e metade na explosão (que costuma pegar mais de um alvo).
	var per_bullet := dps(weapon_def, player.level) * dmg_mult / (60.0 / PLASMA_INTERVAL) / count
	var big := player.level >= 4
	var kind := BulletKinds.player_index(&"plasma_l" if big else &"plasma_s")
	var fired := 0
	for k: int in range(count):
		var deg := -90.0 + (k - (count - 1) * 0.5) * 9.0
		var idx := pool.spawn(player.pos + Vector2(0, -14), Vector2.from_angle(deg_to_rad(deg)) * PLASMA_SPEED,
				10.0 if big else 6.0, kind, per_bullet * 0.6)
		if idx >= 0:
			pool.splash[idx] = PLASMA_SPLASH[i]
			fired += 1
	return fired


static func _railgun(player: SimPlayer, pool: BulletPool, weapon_def: Dictionary, dmg_mult: float, rate: float) -> int:
	var i := clampi(player.level - 1, 0, 3)
	player.fire_timer = _interval(RAIL_INTERVAL[i], rate) - 1
	var count := RAIL_COUNT[i]
	var per_bullet := dps(weapon_def, player.level) * dmg_mult / (60.0 / RAIL_INTERVAL[i]) / count
	var kind := BulletKinds.player_index(&"rail")
	var fired := 0
	for k: int in range(count):
		var x := (k - (count - 1) * 0.5) * 7.0
		var idx := pool.spawn(player.pos + Vector2(x, -16), Vector2(0, -RAIL_SPEED), 3.0, kind, per_bullet)
		if idx >= 0:
			pool.pierce[idx] = RAIL_PIERCE[i]
			fired += 1
	return fired
