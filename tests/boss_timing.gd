extends SceneTree

const SimTests := preload("res://tests/sim_tests.gd")
## Ferramenta de balanceamento: o bot joga cada missão e imprime quanto dura cada luta de chefe e a fase toda,
## quantos segmentos de casco perdeu (danos), o menor casco a que chegou e os abates. Meta do bot na dificuldade
## normal: plano mestre 4.7 ("Meta de dificuldade medida pelo bot").
## Uso: Godot --headless --path . --script res://tests/boss_timing.gd [-- --only=c1m1,c9m3] [--hits] [--rev=1]
##        [--seeds=7,11,23] [--diff=brisa|normal|veteran|abyssal] [--hangar]
## --rev roda com as regras de uma revisão antiga da Sim (SimRevision), para comparar o balanceamento.
## --hangar dá à nave o nível típico do hangar no capítulo da missão (Economy.TYPICAL_LEVEL, arredondado para baixo).
## No fim imprime o resumo por capítulo (linhas "Capítulo").


func _init() -> void:
	var tables := Sim.load_tables()
	var args := OS.get_cmdline_user_args()
	var only := ""
	var seeds: Array[int] = [7]
	var hangar := "--hangar" in args
	var base := Sim.default_loadout(&"falcon")
	for arg: String in args:
		if arg.begins_with("--only="):
			only = arg.trim_prefix("--only=")
		elif arg.begins_with("--rev="):
			base["rev"] = int(arg.trim_prefix("--rev="))
		elif arg.begins_with("--diff="):
			base["difficulty"] = arg.trim_prefix("--diff=")
		elif arg.begins_with("--seeds="):
			seeds.clear()
			for s: String in arg.trim_prefix("--seeds=").split(","):
				seeds.append(int(s))
	var chapters := {}
	for id: StringName in SimTests.mission_ids():
		if not only.is_empty() and not String(id) in only.split(","):
			continue
		var mission := Sim.load_mission(id)
		var chapter := int(mission.get("chapter", 1))
		var load := base.duplicate()
		if hangar:
			var bonus := Economy.ship_bonus(int(Economy.TYPICAL_LEVEL[clampi(chapter, 1, 10) - 1]))
			load["damage"] = bonus["damage"]
			load["hull"] = bonus["hull"]
		for seed: int in seeds:
			var row := _run(mission, tables, load, seed, "--hits" in args)
			print("%s s%d %.0fs %s danos %d casco_min %d abates %d | %s" % [id, seed, row["seconds"],
					"ok" if row["cleared"] else "PERDEU", row["hits"], row["min_hull"], row["kills"], row["log"]])
			var c: Dictionary = chapters.get(chapter, {"runs": 0, "seconds": 0.0, "hits": 0, "lost": 0, "last": 0,
					"max_hits": 0})
			c["runs"] = int(c["runs"]) + 1
			c["seconds"] = float(c["seconds"]) + float(row["seconds"])
			c["hits"] = int(c["hits"]) + int(row["hits"])
			c["max_hits"] = maxi(int(c["max_hits"]), int(row["hits"]))
			c["lost"] = int(c["lost"]) + (0 if row["cleared"] else 1)
			c["last"] = int(c["last"]) + (1 if row["cleared"] and int(row["min_hull"]) <= 1 else 0)
			chapters[chapter] = c
	var keys := chapters.keys()
	keys.sort()
	for chapter: int in keys:
		var c: Dictionary = chapters[chapter]
		print("Capítulo %d: %d partidas, tempo médio %.0fs, danos %d (média %.1f, máx %d), perdidas %d, no último segmento %d"
				% [chapter, c["runs"], float(c["seconds"]) / int(c["runs"]), c["hits"],
				float(c["hits"]) / int(c["runs"]), c["max_hits"], c["lost"], c["last"]])
	quit()


func _run(mission: Dictionary, tables: Dictionary, load: Dictionary, seed: int, verbose: bool) -> Dictionary:
	var sim := Sim.new()
	sim.setup(mission, tables, load.duplicate(), seed)
	var bot := BotPilot.new()
	var start := {}
	var fights: Array[String] = []
	var hits := 0
	var min_hull := sim.player.hull
	while not sim.finished and sim.frame < 36000:
		sim.step(bot.decide(sim))
		min_hull = mini(min_hull, sim.player.hull)
		for ev: Dictionary in sim.take_events():
			if ev["type"] == &"boss_intro":
				start[String(ev["id"])] = sim.frame
				if verbose:
					fights.append("[%s nv%d casco%d bombas%d]" % [sim.player.weapon, sim.player.level,
							sim.player.hull, sim.player.bombs])
			elif ev["type"] == &"player_hit":
				hits += 1
				if verbose:
					fights.append("dano %s %.0fs (%s)" % [ev["cause"], sim.frame / 60.0,
							sim.boss.id if sim.boss != null else "-"])
			elif ev["type"] == &"boss_dead":
				fights.append("%s %.0fs" % [ev["id"], (sim.frame - int(start.get(String(ev["id"]), 0))) / 60.0])
	var r := sim.result()
	return {"seconds": float(r["seconds"]), "cleared": bool(r["cleared"]), "hits": hits, "min_hull": maxi(0, min_hull),
			"kills": int(r.get("kills", 0)), "log": ", ".join(fights)}
