extends RefCounted
## Evolução da nave pelo nível do hangar (ShipLivery, data/livery.json): uma peça física nova por nível, cumulativa,
## montada na arte HD de toda nave (tools/gen_livery.py: cada quadro muda o casco, nada cobre o ponto de acerto,
## âncoras dentro da caixa), chama e brilho crescendo, acento legível em toda pintura, nível levado à partida em todo
## modo, partida igual em qualquer nível (só desenho) e a nave montada desenhada na partida em cada nível.
## Chamado por tests/integration_tests.gd (precisa dos autoloads).

const SaveManagerScript := preload("res://scripts/autoload/save_manager.gd")


func run(check: Callable) -> void:
	_parts(check)
	_art(check)
	_assembled(check)
	_accent(check)
	_loadout(check)
	_determinism(check)


func _parts(check: Callable) -> void:
	check.call(ShipLivery.parts_at(1).is_empty(), "Evolução: nível 1 é a nave de fábrica")
	check.call(ShipLivery.parts().size() == Economy.SHIP_MAX_LEVEL - 1, "Evolução: um marco por nível do 2 ao máximo")
	var seen: Array[StringName] = []
	for level: int in range(2, Economy.SHIP_MAX_LEVEL + 1):
		var now := ShipLivery.parts_at(level)
		var fresh := ShipLivery.part_at(level)
		check.call(now.size() == level - 1 and now.back() == fresh and not fresh in seen,
				"Evolução: o nível %d acrescenta só %s e guarda os anteriores" % [level, fresh])
		check.call(ShipLivery.next_part(level - 1).get("id") == fresh, "Evolução: o nível %d anuncia %s" % [level - 1, fresh])
		check.call(ShipLivery.icon(fresh) != null, "Evolução: emblema de %s (tools/gen_livery.py)" % fresh)
		seen.append(fresh)
	check.call(ShipLivery.next_part(Economy.SHIP_MAX_LEVEL).is_empty(), "Evolução: nada depois do nível máximo")
	check.call(ShipLivery.part_at(1) == &"", "Evolução: nível 1 sem marco")
	# As peças pedidas, nos níveis pedidos, e as luzes que as reforçam.
	for want: Array in [[&"armor", 2], [&"wing_guns", 3], [&"boosters", 4], [&"fins", 5], [&"missile_pods", 7],
			[&"crown", 10], [&"accent_glow", 3], [&"afterburner", 4], [&"nav_lights", 6], [&"aura", 7],
			[&"ascended", 10]]:
		check.call(ShipLivery.level_of(want[0]) == int(want[1]), "Evolução: %s chega no nível %d" % want)
	# Chama: 1,0 no nível 1, cresce a cada nível e chega a 1,3 no máximo; brilho de acento só a partir do marco.
	var last := 0.0
	for level: int in range(1, Economy.SHIP_MAX_LEVEL + 1):
		var f := ShipLivery.flame(level)
		check.call(f.x > last and f.y >= 1.0, "Evolução: chama maior e mais clara no nível %d (%.2f)" % [level, f.x])
		last = f.x
	check.call(is_equal_approx(ShipLivery.flame(1).x, 1.0) and is_equal_approx(last, 1.3),
			"Evolução: chama de 1,0x a 1,3x")
	check.call(ShipLivery.glow_alpha(2) == 0.0 and ShipLivery.glow_alpha(3) > 0.0
			and ShipLivery.glow_alpha(10) > ShipLivery.glow_alpha(5), "Evolução: brilho de acento sobe com o nível")


## Cada nave do hangar tem arte HD, brilho da silhueta e uma âncora por peça dentro da caixa opaca.
func _art(check: Callable) -> void:
	for row: Variant in DB.rows("ships"):
		var id := StringName(String((row as Dictionary)["id"]))
		var art := SpriteBank.player(id)
		check.call(bool(art["hd"]) and art["glow"] != null and art["engine_boost"] != null,
				"Evolução: %s tem base, motor, pós-combustão e brilho HD" % id)
		var a := ShipLivery.anchors(id)
		var ok := a.has("accent") and a.has("spine")
		for p: Dictionary in ShipLivery.parts():
			var f: Array = a.get(String(p["id"]), [-1.0, -1.0])
			ok = ok and float(f[0]) >= 0.0 and float(f[0]) <= 1.0 and float(f[1]) >= 0.0 and float(f[1]) <= 1.0
		for f: Variant in a.get("spine", []):
			ok = ok and float((f as Array)[0]) >= 0.0 and float((f as Array)[1]) <= 1.0
		check.call(ok, "Evolução: âncora de cada peça de %s em data/livery.json, em fração da caixa (0..1)" % id)
		# Boca dos canhões, jatos e pontas das aletas: em par, espelhados, dentro do quadro desenhado.
		var frame := Rect2(-Vector2.ONE * float(art["size"]) * 0.5, Vector2.ONE * float(art["size"]))
		var mid := (art["used"] as Rect2).get_center().x
		var inside := true
		for spec: Array in [[&"wing_guns", "muzzle"], [&"boosters", "jet"], [&"fins", "fin_tip"]]:
			var pts := ShipLivery.part_points(art, spec[0], spec[1])
			inside = inside and pts.size() == 2 and absf(pts[0].x + pts[1].x - 2.0 * mid) < 0.01
			inside = inside and is_equal_approx(pts[0].y, pts[1].y) and frame.has_point(pts[0]) and frame.has_point(pts[1])
		check.call(inside, "Evolução: canhões, jatos e aletas de %s em par, dentro do quadro" % id)


## A arte montada (tools/gen_livery.py): um quadro por nível do 2 ao 10 do tamanho da base, cada um com algo novo
## desenhado no casco (cumulativo), o brilho de cada quadro, o jato dos propulsores, e o ponto de acerto (a cabine,
## data/hitboxes.json) sem peça nem sombra por cima.
func _assembled(check: Callable) -> void:
	var ships: Dictionary = Hitboxes.load_table().get("ships", {})
	for row: Variant in DB.rows("ships"):
		var id := StringName(String((row as Dictionary)["id"]))
		var art := SpriteBank.player(id)
		var evo := ShipLivery.evo(art)
		var tex: Texture2D = evo["evo"]
		var side: int = art["tex_size"]
		var frames := Economy.SHIP_MAX_LEVEL - 1
		check.call(tex != null and tex.get_width() == side * frames and tex.get_height() == side
				and evo["glow"] != null and evo["jet"] != null,
				"Evolução: %s tem os %d quadros montados, o brilho deles e o jato" % [id, frames])
		if tex == null:
			continue
		var strip := tex.get_image()
		var base := (art["base"] as Texture2D).get_image()
		for img: Image in [strip, base]:
			if img.is_compressed():
				img.decompress()
		var prev := base
		var grows := true
		for level: int in range(2, Economy.SHIP_MAX_LEVEL + 1):
			var now := strip.get_region(SpriteBank.frame_rect(level - 2, side))
			var diff: Dictionary = now.compute_image_metrics(prev, false)
			grows = grows and float(diff.get("mean", 0.0)) > 0.2
			prev = now
		check.call(grows, "Evolução: cada nível do 2 ao 10 desenha peça nova no casco de %s" % id)
		var hit: Dictionary = (ships.get(String(id), {}) as Dictionary)
		var at := Vector2.ONE * float(side) * 0.5 + Hitboxes.vec(hit.get("offset")) * 2.0
		var top := strip.get_region(SpriteBank.frame_rect(frames - 1, side))
		var clean := true
		for y: int in range(-4, 5):
			for x: int in range(-4, 5):
				var px := Vector2i(at) + Vector2i(x, y)
				var a := top.get_pixelv(px)
				var b := base.get_pixelv(px)
				clean = clean and absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) + absf(a.a - b.a) < 0.1
		check.call(clean, "Evolução: nenhuma peça cobre o ponto de acerto de %s no nível 10" % id)


## O acento da pintura tem de destacar do casco: claro e saturado em toda pintura da loja.
func _accent(check: Callable) -> void:
	for c: Variant in Store.cosmetics():
		var color := String((c as Dictionary).get("color", ""))
		if color.is_empty():
			continue
		var a := ShipLivery.accent_of(Color(color))
		check.call(a.v >= 0.95 and (a.s >= 0.5 or Color(color).s < 0.15), "Evolução: acento claro para a pintura %s" % color)


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
	var hd_layers := true
	for layer: String in ["_entities", "_player", "_shadows", "_wrecks"]:
		hd_layers = hd_layers and (view.get(layer) as CanvasItem).texture_filter == SpriteBank.HD_FILTER
	check.call(hd_layers and (view.get("_items") as CanvasItem).texture_filter != SpriteBank.HD_FILTER,
			"Naves HD em camadas lineares com mipmaps; pixel art na camada sem filtro")
	check.call((view.get("_art") as Dictionary).get("id") == &"falcon" and (view.get("_wing_art") as Dictionary).get("id")
			== &"manta", "Evolução: a partida desenha a nave e a ala de cada um (SpriteBank.player)")
	view.queue_free()
	await host.get_tree().process_frame
	# Cada nível e cada estágio de avaria desenha sem erro (a chama nunca passa da tela do quadro).
	var canvas := _Probe.new()
	host.add_child(canvas)
	for level: int in range(1, Economy.SHIP_MAX_LEVEL + 1):
		canvas.level = level
		canvas.damage = level % 3
		canvas.queue_redraw()
		await host.get_tree().process_frame
	check.call(canvas.drawn == Economy.SHIP_MAX_LEVEL, "Evolução: a nave desenha em todos os níveis e avarias")
	canvas.queue_free()
	await host.get_tree().process_frame


## Avaria: estágios a 2/3 e 1/3 do casco e pontos de rachadura dentro da parte opaca de toda nave.
func run_damage(check: Callable) -> void:
	check.call(ShipArt.damage_stage(3, 3) == 0 and ShipArt.damage_stage(2, 3) == 1 and ShipArt.damage_stage(1, 3) == 2
			and ShipArt.damage_stage(4, 4) == 0 and ShipArt.damage_stage(2, 4) == 1, "Avaria: estágios a 2/3 e 1/3")
	for row: Variant in DB.rows("ships"):
		var id := StringName(String((row as Dictionary)["id"]))
		var art := SpriteBank.player(id)
		var spots := ShipArt.damage_spots(art)
		var inside := spots.size() >= ShipArt.DAMAGE_CRACKS[2] - 1
		for at: Vector2 in spots:
			inside = inside and (art["used"] as Rect2).has_point(at)
		check.call(inside, "Avaria: %s tem %d pontos de rachadura dentro do casco" % [id, spots.size()])
		check.call(ShipArt.damage_spots(art) == spots, "Avaria: pontos de %s fixos (determinísticos)" % id)


class _Probe:
	extends Node2D

	var level: int = 1
	var damage: int = 0
	var drawn: int = 0

	func _ready() -> void:
		texture_filter = SpriteBank.HD_FILTER
		material = ShipArt.material()

	func _draw() -> void:
		draw_set_transform(Vector2(80, 80))
		ShipArt.draw(self, SpriteBank.player(&"ascension"), float(level), level, 1.0, level % 2 == 0,
				Color(1.0, 0.4, 0.5) if level == 6 else Color(0, 0, 0, 0), false, damage)
		drawn += 1
