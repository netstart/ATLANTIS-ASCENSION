extends RefCounted
## Testes das caixas de colisão medidas na arte HD (Hitboxes, data/hitboxes.json, revisão 5 da Sim): o arquivo cobre
## toda nave, inimigo e chefe com arte HD e tem valores sãos; quem falta cai no valor antigo; a revisão 4 joga igual,
## passo a passo, ao que jogava sem o arquivo (replays antigos); e a colisão usa o centro deslocado (tiro da nave,
## contato, ponto da nave, corpo e partes do chefe). Chamado por tests/run_tests.gd (regras rápidas, sem autoloads).

const EMPTY := {"id": "hitbox_test", "chapter": 1, "events": []}

var _tables: Dictionary = {}


func run_unit(check: Callable) -> void:
	_tables = Sim.load_tables()
	_data(check)
	_fallback(check)
	_revision(check)
	_player_point(check)
	_enemy_offset(check)
	_boss_offset(check)


func _sim(rev: int = SimRevision.CURRENT, ship: StringName = &"falcon", tables: Dictionary = _tables) -> Sim:
	var sim := Sim.new()
	var load := Sim.default_loadout(ship)
	load["rev"] = rev
	sim.setup(EMPTY, tables, load, 7)
	return sim


static func _hd_exists(path: String) -> bool:
	return ResourceLoader.exists(path) or FileAccess.file_exists(path)


## Toda nave de data/ships.json com arte HD, todo inimigo e chefe com sprite HD têm caixa; valores sãos.
func _data(check: Callable) -> void:
	var box: Dictionary = _tables.get("hitboxes", {})
	check.call(box.has("ships") and box.has("enemies") and box.has("bosses"), "Hitboxes: data/hitboxes.json carrega")
	var bad: Array[String] = []
	for id: StringName in _tables["ships"]:
		var row: Dictionary = Hitboxes.find(_tables, {}, "ships", id)
		if not _hd_exists(SpriteBank.HD_PATH % ["player", id, "base"]):
			continue
		var off := Hitboxes.vec(row.get("offset"))
		if row.is_empty():
			bad.append("nave %s sem caixa" % id)
		elif not is_equal_approx(float(row["radius"]), float(_tables["ships"][id].get("hitbox", 3.0))) \
				or off.length() > 15.0 or off.x != 0.0:
			bad.append("nave %s: %s" % [id, row])
	for id: StringName in _tables["enemies"]:
		var sprite := String(_tables["enemies"][id].get("sprite", ""))
		var row: Dictionary = Hitboxes.find(_tables, {}, "enemies", id)
		if row.is_empty():
			if not SpriteBank.SPECIAL.has(StringName(sprite)):
				bad.append("inimigo %s sem caixa" % id)
			continue
		var r := float(row["radius"])
		var c := float(row.get("contact", 0.0))
		if r < 4.0 or r > 60.0 or c <= 0.0 or c >= r or Hitboxes.vec(row.get("offset")).length() >= r:
			bad.append("inimigo %s: %s" % [id, row])
	for id: StringName in _tables["bosses"]:
		var def: Dictionary = _tables["bosses"][id]
		var row: Dictionary = Hitboxes.find(_tables, {}, "bosses", id)
		if row.is_empty():
			bad.append("chefe %s sem caixa" % id)
			continue
		if float(row["contact"]) >= float(row["radius"]) or Hitboxes.vec(row.get("offset")).length() >= float(row["contact"]):
			bad.append("chefe %s: %s" % [id, row])
		var with_sprite := {}
		for part: Dictionary in def.get("parts", []):
			if part.has("sprite"):
				with_sprite[String(part["id"])] = true
		var parts: Dictionary = row.get("parts", {})
		if parts.keys().size() != with_sprite.size():
			bad.append("chefe %s: partes %s, com sprite %s" % [id, parts.keys(), with_sprite.keys()])
		for pid: String in parts:
			if not with_sprite.has(pid) or float(parts[pid]["radius"]) <= 0.0:
				bad.append("chefe %s.%s: %s" % [id, pid, parts[pid]])
	check.call(bad.is_empty(), "Hitboxes: caixa sã para toda nave, inimigo e chefe HD%s"
			% ("" if bad.is_empty() else ": " + "; ".join(bad)))


## Sem a caixa (id fora do arquivo ou arquivo vazio), a Sim fica com os valores das tabelas.
func _fallback(check: Callable) -> void:
	check.call(Hitboxes.find(_tables, {}, "enemies", &"nao_existe").is_empty()
			and Hitboxes.find({}, {}, "ships", &"falcon").is_empty() and Hitboxes.vec(null) == Vector2.ZERO,
			"Hitboxes: id ou tabela ausente dá caixa vazia")
	var bare := _tables.duplicate()
	bare["hitboxes"] = {}
	var sim := _sim(SimRevision.CURRENT, &"titan", bare)
	check.call(is_equal_approx(sim.player.hitbox, float(_tables["ships"][&"titan"]["hitbox"]))
			and sim.player.hit_offset == Vector2.ZERO, "Hitboxes: nave sem caixa usa a hitbox de data/ships.json no centro")
	sim.spawn_enemy({"enemy": "aegis", "x": 0.5, "y": 100.0}, 0)
	var e: SimEnemy = sim.enemies[0]
	check.call(e.hurt == e.radius and e.hit_offset == Vector2.ZERO
			and is_equal_approx(e.contact_radius, e.radius * Sim.CONTACT_FACTOR),
			"Hitboxes: inimigo sem caixa usa o raio de data/enemies.json (contato a 0,6)")
	sim.spawn_boss(&"kraken_engine", true)
	check.call(sim.boss.hurt_pos() == sim.boss.body_pos() and sim.boss.hurt_radius() == sim.boss.body_radius()
			and is_equal_approx(sim.boss.contact_radius(), sim.boss.body_radius() * Sim.CONTACT_FACTOR),
			"Hitboxes: chefe sem caixa usa body_radius e body_pos")
	# Inimigo fora do arquivo numa partida da revisão atual (nave premium nova, inimigo novo): valor antigo.
	var real := _sim()
	var def: Dictionary = (_tables["enemies"][&"aegis"] as Dictionary).duplicate()
	def["id"] = "inimigo_sem_caixa"
	var foe := SimEnemy.new()
	foe.setup(def, Vector2(100, 100), &"straight", {}, _tables["patterns"], false)
	foe.fit(Hitboxes.find(_tables, real.loadout, "enemies", foe.id))
	check.call(foe.hurt == foe.radius and foe.hit_offset == Vector2.ZERO,
			"Hitboxes: inimigo novo sem caixa fica com o raio da tabela")


## Revisão 4 (replays antigos): a mesma partida do bot com e sem data/hitboxes.json dá o mesmo hash a cada segundo;
## a revisão atual usa as caixas e muda a partida.
func _revision(check: Callable) -> void:
	var bare := _tables.duplicate()
	bare["hitboxes"] = {}
	var old := _sim(4)
	check.call(old.player.hit_offset == Vector2.ZERO and is_equal_approx(old.player.hitbox, 3.0),
			"Hitboxes: revisão 4 ignora as caixas (nave)")
	var mission := Sim.load_mission(&"c1m3")
	var a := _bot_hashes(mission, _tables, 4)
	var b := _bot_hashes(mission, bare, 4)
	var now := _bot_hashes(mission, _tables, SimRevision.CURRENT)
	check.call(a.size() > 30 and a == b, "Hitboxes: replay de revisão 4 igual, passo a passo, ao de antes das caixas")
	check.call(now != a, "Hitboxes: a revisão atual joga com as caixas medidas")
	check.call(SimRevision.CURRENT >= Hitboxes.REVISION, "Hitboxes: revisão das caixas ativa nas partidas novas")


func _bot_hashes(mission: Dictionary, tables: Dictionary, rev: int) -> PackedStringArray:
	var sim := Sim.new()
	var load := Sim.default_loadout(&"falcon")
	load["rev"] = rev
	sim.setup(mission, tables, load, 7)
	var bot := BotPilot.new()
	var hashes := PackedStringArray()
	while sim.frame < 60 * 45 and not sim.finished:
		sim.step(bot.decide(sim))
		sim.take_events()
		if sim.frame % 60 == 0:
			hashes.append(sim.state_hash())
	return hashes


## Ponto da nave na cabine: a bala no ponto deslocado acerta; a mesma bala no centro do desenho, fora do círculo do
## ponto, não acerta.
func _player_point(check: Callable) -> void:
	var sim := _sim()
	var row: Dictionary = Hitboxes.find(_tables, sim.loadout, "ships", &"falcon")
	check.call(sim.player.hit_offset == Hitboxes.vec(row["offset"]) and sim.player.hit_offset != Vector2.ZERO
			and sim.player.hit_pos() == sim.player.pos + sim.player.hit_offset, "Hitboxes: ponto da Falcon vem do arquivo")
	sim.player.invuln = 0
	var gap := sim.player.hit_offset.length()
	check.call(gap > sim.player.hitbox + 0.5, "Hitboxes: ponto da Falcon longe do centro do desenho (%.1f)" % gap)
	# Bala pequena no centro do desenho: fora do ponto, não fere.
	sim.enemy_bullets.spawn(sim.player.pos, Vector2.ZERO, 0.5, 0)
	var hull := sim.player.hull
	sim._collide_ship(sim.player)
	check.call(sim.player.hull == hull, "Hitboxes: bala no centro do desenho, fora da cabine, não fere")
	sim.enemy_bullets.clear()
	sim.enemy_bullets.spawn(sim.player.hit_pos(), Vector2.ZERO, 0.5, 0)
	sim._collide_ship(sim.player)
	check.call(sim.player.hull == hull - 1 and sim.last_cause == &"bullet", "Hitboxes: bala na cabine fere")


## Inimigo com o corpo fora do meio do quadro: o tiro acerta o círculo deslocado (onde o casco está) e o contato
## usa o raio medido.
func _enemy_offset(check: Callable) -> void:
	var sim := _sim()
	sim.spawn_enemy({"enemy": "aegis", "x": 0.5, "y": 100.0}, 0)
	var e: SimEnemy = sim.enemies[0]
	var row: Dictionary = Hitboxes.find(_tables, sim.loadout, "enemies", &"aegis")
	check.call(e.hurt == float(row["radius"]) and e.hit_offset == Hitboxes.vec(row["offset"])
			and e.contact_radius == float(row["contact"]) and e.hit_offset.y < -3.0, "Hitboxes: caixa do Aegis vem do arquivo")
	# Ponto dentro do círculo deslocado e fora de um círculo do mesmo raio no centro do desenho.
	var dir := e.hit_offset.normalized()
	var inside := e.hit_pos() + dir * (e.hurt - 0.5)
	check.call(inside.distance_to(e.pos) > e.hurt, "Hitboxes: ponto de teste fora do círculo centrado")
	check.call(sim.hit_at_id(inside, 0.1, 0.01) == e.get_instance_id(), "Hitboxes: tiro acerta o corpo deslocado")
	var opposite := e.pos - dir * (e.hurt - 0.5)
	check.call(sim.hit_at_id(opposite, 0.1, 0.01) == 0, "Hitboxes: tiro no vazio do outro lado não acerta")
	sim.player.invuln = 0
	sim.player.pos = e.hit_pos() + Vector2(e.contact_radius + sim.player.hitbox - 0.5, 0) - sim.player.hit_offset
	var hull := sim.player.hull
	sim._collide_ship(sim.player)
	check.call(sim.player.hull == hull - 1 and sim.last_cause == &"contact", "Hitboxes: contato no raio medido fere")
	sim.player.invuln = 0
	sim.player.pos = e.hit_pos() + Vector2(e.contact_radius + sim.player.hitbox + 0.5, 0) - sim.player.hit_offset
	hull = sim.player.hull
	sim._collide_ship(sim.player)
	check.call(sim.player.hull == hull, "Hitboxes: fora do contato medido não fere")


## Chefe: o corpo usa o círculo medido (deslocado do body_pos) e as partes com sprite o raio medido.
func _boss_offset(check: Callable) -> void:
	var sim := _sim()
	sim.spawn_boss(&"leviathan_protocol", true)
	var b := sim.boss
	b._set_state(SimBoss.State.FIGHT)
	var row: Dictionary = Hitboxes.find(_tables, sim.loadout, "bosses", &"leviathan_protocol")
	check.call(b.fighting() and b.hurt_radius() == float(row["radius"]) and b.contact_radius() == float(row["contact"])
			and b.hurt_pos() == b.pos + Hitboxes.vec(row["offset"]), "Hitboxes: corpo do chefe vem do arquivo")
	var parts_ok := true
	for part: Dictionary in b.parts:
		var pb: Dictionary = (row.get("parts", {}) as Dictionary).get(String(part["id"]), {})
		if part.has("sprite"):
			parts_ok = parts_ok and b.part_radius(part) == float(pb["radius"]) \
					and b.part_hit_pos(part) == b.part_pos(part) + Hitboxes.vec(pb["offset"])
		else:
			parts_ok = parts_ok and b.part_radius(part) == float(part.get("radius", 10.0)) \
					and b.part_hit_pos(part) == b.part_pos(part)
	check.call(parts_ok, "Hitboxes: partes com sprite medidas, as outras com o raio da tabela")
	# Longe das partes, dentro do corpo medido e fora do raio antigo: acerta o corpo.
	var at := b.hurt_pos() + Vector2(b.hurt_radius() - 1.0, 0)
	for part: Dictionary in b.parts:
		if b.part_active(part) and at.distance_to(b.part_hit_pos(part)) <= b.part_radius(part) + 0.1:
			at = b.hurt_pos() + Vector2(-(b.hurt_radius() - 1.0), 0)
	check.call(at.distance_to(b.body_pos()) > b.body_radius(), "Hitboxes: ponto de teste fora do raio antigo do chefe")
	check.call(sim.hit_at_id(at, 0.1, 0.01) == Sim.BOSS_BODY_ID, "Hitboxes: tiro na borda do casco medido acerta o chefe")
