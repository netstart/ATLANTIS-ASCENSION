extends SceneTree

const SimTests := preload("res://tests/sim_tests.gd")
## Ferramenta de balanceamento: o bot joga cada missão e imprime quanto dura cada luta de chefe e a fase toda.
## Uso: Godot --headless --path . --script res://tests/boss_timing.gd [-- --only=c1m1,c9m3]


func _init() -> void:
	var tables := Sim.load_tables()
	var only := ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			only = arg.trim_prefix("--only=")
	for id: StringName in SimTests.mission_ids():
		if not only.is_empty() and not String(id) in only.split(","):
			continue
		var sim := Sim.new()
		sim.setup(Sim.load_mission(id), tables, &"falcon", 7)
		var bot := BotPilot.new()
		var start := {}
		var fights: Array[String] = []
		while not sim.finished and sim.frame < 36000:
			sim.step(bot.decide(sim))
			for ev: Dictionary in sim.take_events():
				if ev["type"] == &"boss_intro":
					start[String(ev["id"])] = sim.frame
					if "--hits" in OS.get_cmdline_user_args():
						fights.append("[%s nv%d casco%d bombas%d]" % [sim.player.weapon, sim.player.level,
								sim.player.hull, sim.player.bombs])
				elif ev["type"] == &"player_hit" and "--hits" in OS.get_cmdline_user_args():
					fights.append("dano %s %.0fs (%s)" % [ev["cause"], sim.frame / 60.0,
							sim.boss.id if sim.boss != null else "-"])
				elif ev["type"] == &"boss_dead":
					fights.append("%s %.0fs" % [ev["id"], (sim.frame - int(start.get(String(ev["id"]), 0))) / 60.0])
		var r := sim.result()
		print("%s %.0fs %s | %s" % [id, float(r["seconds"]), "ok" if r["cleared"] else "PERDEU", ", ".join(fights)])
	quit()
