extends RefCounted
## Mortes dos inimigos desenhadas pelo WorldView (precisa dos autoloads). Chamado por tests/integration_tests.gd.

## Mortes na tela: cada estilo pelo WorldView, no mar (c1m1), no chão (c4m1) e no espaço (c8m1), desenhado
## quadro a quadro até acabar. Nada sobra (mortes, explosões, anéis), a Sim não muda e a queda no espaço vira
## outro estilo.
func run_view(host: Node, check: Callable) -> void:
	for case: Array in [[&"c1m1", CombatFx.WATER], [&"c4m1", CombatFx.SOLID], [&"c8m1", CombatFx.NONE]]:
		var sim := Sim.new()
		sim.setup(Sim.load_mission(case[0]), Sim.load_tables(), Sim.default_loadout(&"falcon"), 7)
		var view := WorldView.new()
		host.add_child(view)
		view.setup(sim)
		check.call(view.fx.surface == case[1], "Mortes na tela %s: chão %s (%s)" % [case[0], case[1], view.fx.surface])
		var before := sim.state_hash()
		for style: StringName in [CombatFx.EXPLODE, CombatFx.MELT, CombatFx.FALL]:
			for big: bool in [false, true]:
				var label := "Mortes na tela %s: %s%s" % [case[0], style, " grande" if big else ""]
				view.kill_fx(Vector2(135, 160), &"klaed_scout", big, 100, style, 1.0, 3)
				var want := style if not (style == CombatFx.FALL and case[1] == CombatFx.NONE) else CombatFx.EXPLODE
				check.call(view.last_death == want, label + " no estilo %s (%s)" % [want, view.last_death])
				var frames := 0
				while (not view.fx.wrecks.is_empty() or not view.explosions.is_empty() or not view.rings.is_empty()
						or view.fx.pending() > 0) and frames < 240:
					view.refresh(1.0 / 60.0)
					await host.get_tree().process_frame
					frames += 1
				check.call(frames < 240, label + " acaba e solta tudo (%d quadros)" % frames)
		check.call(sim.state_hash() == before, "Mortes na tela %s: a Sim não muda" % case[0])
		view.queue_free()
		await host.get_tree().process_frame
