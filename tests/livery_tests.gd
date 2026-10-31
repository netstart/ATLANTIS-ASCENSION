extends RefCounted
## Evolução visual da nave pelo nível do hangar (ShipLivery): uma peça nova por nível, arte alinhada
## à nave, acento legível em toda tinta e pintura, nível levado à partida em todo modo, partida igual
## em qualquer nível (só desenho) e a nave vestida desenhada na partida.
## Chamado por tests/integration_tests.gd (precisa dos autoloads).

const SaveManagerScript := preload("res://scripts/autoload/save_manager.gd")


func run(check: Callable) -> void:
	_parts(check)
	_art(check)
	_accent(check)
	_loadout(check)
	_determinism(check)


func _parts(check: Callable) -> void:
	check.call(ShipLivery.parts_at(1).is_empty(), "Evolução: nível 1 é a nave de fábrica")
	check.call(ShipLivery.PARTS.size() == Economy.SHIP_MAX_LEVEL - 1, "Evolução: uma peça por nível do 2 ao máximo")
	var seen: Array[StringName] = []
	for level: int in range(2, Economy.SHIP_MAX_LEVEL + 1):
		var now := ShipLivery.parts_at(level)
		var fresh := ShipLivery.part_at(level)
		check.call(now.size() == level - 1 and now.back() == fresh and not fresh in seen,
				"Evolução: o nível %d acrescenta só %s e guarda as anteriores" % [level, fresh])
		check.call(ShipLivery.next_part(level - 1).get("id") == fresh, "Evolução: o nível %d anuncia %s" % [level - 1, fresh])
		seen.append(fresh)
	check.call(ShipLivery.next_part(Economy.SHIP_MAX_LEVEL).is_empty(), "Evolução: nada depois do nível máximo")
	check.call(ShipLivery.part_at(1) == &"", "Evolução: nível 1 sem peça")


func _art(check: Callable) -> void:
	for p: Dictionary in ShipLivery.PARTS:
		var tex := ShipLivery.texture(p["id"])
		check.call(tex != null and tex.get_size() == Vector2(ShipLivery.SIZE, ShipLivery.SIZE),
				"Evolução: arte de %s em 48x48 (alinhada à nave)" % p["id"])
	# Peças por cima não podem tapar o miolo da nave (a caixa de colisão fica no centro).
	for p: Dictionary in ShipLivery.PARTS:
		if p["layer"] != ShipLivery.Layer.OVER:
			continue
		var img := ShipLivery.texture(p["id"]).get_image()
		var clear := true
		for y: int in range(22, 26):
			for x: int in range(22, 26):
				clear = clear and (img.get_pixel(x, y).a < 0.1 or p["id"] in [&"runes"])
		check.call(clear, "Evolução: %s deixa o centro da nave à vista" % p["id"])


## O acento (faixas, runas, lâminas) tem de destacar de toda tinta de nave e de toda pintura da loja.
func _accent(check: Callable) -> void:
	var tints: Array[Color] = []
	for row: Variant in DB.rows("ships"):
		tints.append(Color(String((row as Dictionary).get("tint", "#ffffff"))))
	for c: Variant in Store.cosmetics():
		var color := String((c as Dictionary).get("color", ""))
		if not color.is_empty():
			tints.append(Color(color))
	var worst := INF
	for t: Color in tints:
		var a := ShipLivery.accent_of(t)
		worst = minf(worst, Vector3(a.r - t.r, a.g - t.g, a.b - t.b).length())
	check.call(worst > 0.3, "Evolução: acento longe de toda tinta e pintura (menor distância %.2f)" % worst)


func _loadout(check: Callable) -> void:
	var p := SaveManagerScript.default_profile()
	p["hangar"]["ship_levels"]["falcon"] = 7
	check.call(int(Economy.loadout(p)["ship_level"]) == 7, "Evolução: a carga do hangar leva o nível")
	for mode: StringName in [&"arcade", &"daily", &"boss_rush", &"survival", &"abyss"]:
		check.call(int(Modes.loadout_for(mode, p, "2026-11-01").get("ship_level", 0)) == 7,
				"Evolução: o modo %s veste a nave do hangar" % mode)
	(p["unlocked"]["ships"] as Array).append("manta")
	p["hangar"]["ship_levels"]["manta"] = 4
	var coop := Modes.loadout_for(&"coop", p, "2026-11-01")
	check.call(int(coop["coop_level"]) == 4, "Evolução: a ala do co-op veste o nível dela")


## Só desenho: a mesma semente dá o mesmo hash com a nave de fábrica e com a Ascendida.
func _determinism(check: Callable) -> void:
	var tables := Sim.load_tables()
	var hashes: Array[String] = []
	for level: int in [1, Economy.SHIP_MAX_LEVEL]:
		var loadout := Sim.default_loadout(&"falcon")
		loadout["ship_level"] = level
		var sim := Sim.new()
		sim.setup(Sim.load_mission(&"c1m1"), tables, loadout, 7)
		var bot := BotPilot.new()
		while sim.frame < 60 * 20 and not sim.finished:
			sim.step(bot.decide(sim))
		hashes.append(sim.state_hash())
	check.call(hashes[0] == hashes[1], "Evolução: o nível visual não muda a partida")


## Nave Ascendida (e ala) desenhada na partida por alguns quadros: peças, rastro e luzes sem erro.
func run_view(host: Node, check: Callable) -> void:
	var loadout := Sim.default_loadout(&"falcon")
	loadout["ship_level"] = Economy.SHIP_MAX_LEVEL
	loadout["coop"] = true
	loadout["coop_ship"] = "manta"
	loadout["coop_level"] = 5
	var sim := Sim.new()
	sim.setup(Sim.load_mission(&"c1m1"), Sim.load_tables(), loadout, 7)
	var view := WorldView.new()
	host.add_child(view)
	view.setup(sim)
	var bot := BotPilot.new()
	for i: int in range(30):
		sim.step(bot.decide(sim))
		view.refresh(1.0 / 60.0)
		await host.get_tree().process_frame
	check.call(view.get("_livery") == Economy.SHIP_MAX_LEVEL and view.get("_wing_livery") == 5,
			"Evolução: a partida veste a nave e a ala com o nível de cada uma")
	check.call((view.get("_wake") as Array).size() > 0, "Evolução: a Ascendida deixa rastro de ouro")
	view.queue_free()
	await host.get_tree().process_frame
