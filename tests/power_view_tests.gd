extends RefCounted
## Poderes na tela (.ai/08-poderes-das-naves.md): lança cada um dos 36 poderes numa partida de verdade e deixa
## o WorldView e o HUD desenharem do lançamento até o fim. Confere que nenhum desenho dá erro (um Logger pega
## os erros de script dos arquivos do desenho), que todo tipo de efeito vivo passou pelo PowerView, que os
## efeitos apagam e que o mundo não ganha nós por quadro. Chamado por tests/integration_tests.gd.

const GAME := preload("res://scenes/game/Game.tscn")
## Arquivos cujo erro reprova (o desenho dos poderes, o mundo, o HUD e o desenho do botão).
const WATCHED: Array[String] = ["power_view.gd", "world_view.gd", "game_hud.gd", "hud_kit.gd", "game.gd"]
## Passos de Sim entre um quadro desenhado e o próximo (o desenho vê o efeito em vários momentos).
const STRIDE := 9
## Tipos que nunca ficam vivos num quadro desenhado: o eco vira os efeitos do poder ecoado e o reparo dura um
## passo (ele se vê pelo evento "heal").
const INSTANT: Array[StringName] = [&"echo", &"heal"]


func run(host: Node, check: Callable) -> void:
	var catcher := _Catcher.new()
	OS.add_logger(catcher)
	var seen: Dictionary = {}
	var game: Game
	var view: WorldView
	var children := 0
	for id: StringName in DB.ids("powers"):
		var def := DB.row("powers", id)
		var tier := int(def.get("tier", 1))
		if tier == 1:
			# Uma partida por nave: a missão tem tempo e acabaria no meio das 36 rodadas.
			if game != null:
				check.call(view.get_child_count() == children, "Poderes na tela: o mundo não ganha nós (%d → %d)"
						% [children, view.get_child_count()])
				game.queue_free()
				await host.get_tree().process_frame
			game = await _open(host, StringName(String(def.get("ship", "falcon"))))
			view = _world(game)
			children = view.get_child_count()
		game.sim.power_fx.clear()
		game.sim.player.invuln = 1 << 24
		game.sim.powers.cast(game.sim, id, tier)
		var types: Dictionary = {}
		var guard := 0
		while not game.sim.power_fx.is_empty() and guard < 900:
			for e: Dictionary in game.sim.power_fx:
				if int(e["wait"]) <= 0:
					types[e["type"]] = true
					seen[e["type"]] = true
			await host.get_tree().process_frame
			for k: int in range(STRIDE):
				game.sim.step(SimInput.new())
				guard += 1
		check.call(game.sim.power_fx.is_empty(), "Poder %s na tela: acaba (%d passos)" % [id, guard])
		for type: Variant in types:
			check.call(int(view.powers.drawn.get(type, 0)) > 0, "Poder %s na tela: efeito %s desenhado" % [id, type])
	# Depois do último: os que apagavam somem e as camadas param de desenhar.
	for k: int in range(30):
		await host.get_tree().process_frame
	check.call(not view.powers.busy(game.sim), "Poderes na tela: nada apagando depois do fim")
	for type: StringName in Powers.TYPES:
		if not type in INSTANT:
			check.call(seen.has(type), "Poderes na tela: o tipo %s apareceu em algum poder" % type)
	# HUD: o botão PODER em cada nível da Corrente e o aperto vazio.
	var hud := game.hud()
	for charge: float in [0.0, 0.5, 1.0, 2.2, 3.0]:
		game.sim.player.power_charge = charge
		hud.refresh(game.sim, 0.5)
		await host.get_tree().process_frame
		check.call(hud.power_button().name_label.visible == (charge >= 1.0),
				"HUD PODER: nome do poder %s com %.1f segmentos" % ["visível" if charge >= 1.0 else "escondido", charge])
	hud.power_button().empty()
	hud.power_button().charged(3)
	await host.get_tree().process_frame
	game.queue_free()
	await host.get_tree().process_frame
	OS.remove_logger(catcher)
	var errors := catcher.take()
	check.call(errors.is_empty(), "Poderes na tela: nenhum erro de script no desenho (%s)" % ", ".join(errors))


## Partida da nave com alguns segundos voados (inimigos e balas na tela para os poderes acertarem). O relógio
## fica parado: o teste avança a Sim passo a passo e deixa o desenho correr entre um e outro.
func _open(host: Node, ship: StringName) -> Game:
	var game := GAME.instantiate() as Game
	game.configure(&"c1m2", ship, 7, true)
	host.add_child(game)
	await host.get_tree().process_frame
	game.relayout_for(Vector2(305, 678))
	GameClock.paused = true
	game.sim.player.invuln = 1 << 24
	for k: int in range(300):
		game.sim.step(SimInput.new())
	return game


static func _world(game: Game) -> WorldView:
	for node: Node in game.find_children("*", "WorldView", true, false):
		return node as WorldView
	return null


## Guarda os erros de script dos arquivos do desenho (o Logger pode ser chamado de outra thread).
class _Catcher:
	extends Logger

	var _mutex := Mutex.new()
	var _errors := PackedStringArray()

	func _log_error(function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, _error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		for name: String in WATCHED:
			if file.ends_with(name):
				_mutex.lock()
				_errors.append("%s:%d %s %s" % [file.get_file(), line, function, rationale if not rationale.is_empty() else code])
				_mutex.unlock()
				return

	func _log_message(_message: String, _error: bool) -> void:
		pass

	func take() -> PackedStringArray:
		_mutex.lock()
		var out := _errors.duplicate()
		_mutex.unlock()
		return out
