class_name App
extends Node
## Raiz do jogo: monta a camada de interface com o tema, troca de tela (com histórico para o
## "voltar"), inicia e encerra missões e grava o progresso. As telas pedem navegação pelo sinal
## Screen.navigate e missões pelo Screen.play.
##
## Casca de navegação (NavShell, 1.15): as cinco telas-aba (Loja, Oficina, Campanha = hub, Naves e
## Eventos) ficam entre a barra de cima e a barra de abas, criadas uma vez acima das telas. Trocar de
## aba não empilha histórico; voltar numa aba que não é a Campanha leva à Campanha.
##
## Linha de comando (depois de "--"): --bot ou --mission=<id> começa direto na missão (sem menus),
## com --seed=N; o resto é lido pela própria cena Game.

const GAME_SCENE := preload("res://scenes/game/Game.tscn")
const SCREENS := {
	&"boot": preload("res://scripts/app/screens/boot_screen.gd"),
	&"hub": preload("res://scripts/app/screens/hub_screen.gd"),
	&"map": preload("res://scripts/app/screens/map_screen.gd"),
	&"results": preload("res://scripts/app/screens/results_screen.gd"),
	&"credits": preload("res://scripts/app/screens/credits_screen.gd"),
	&"hangar": preload("res://scripts/app/screens/hangar_screen.gd"),
	&"ships": preload("res://scripts/app/screens/ships_screen.gd"),
	&"options": preload("res://scripts/app/screens/options_screen.gd"),
	&"logbook": preload("res://scripts/app/screens/logbook_screen.gd"),
	&"story": preload("res://scripts/app/screens/story_screen.gd"),
	&"events": preload("res://scripts/app/screens/events_screen.gd"),
	&"shop": preload("res://scripts/app/screens/shop_screen.gd"),
	&"city": preload("res://scripts/app/screens/city_screen.gd"),
	&"practice": preload("res://scripts/app/screens/practice_screen.gd"),
	&"season": preload("res://scripts/app/screens/season_screen.gd"),
	&"records": preload("res://scripts/app/screens/records_screen.gd"),
	&"lan": preload("res://scripts/app/screens/lan_screen.gd"),
	&"ranking": preload("res://scripts/app/screens/ranking_screen.gd"),
}
const ROOT_SCREEN := &"boot"
## Música dos menus: o tema do Atlantis Ascension (Clayton K. N. Passos com Google Flow Music), em laço sem emenda
## (tools/prepare_menu_music.py). Começa calmo, cresce até o tema heroico e volta à calma.
const MENU_MUSIC := "flow_tide_rising"
## Humor do fundo por tela (AbyssBackdrop.MOODS); as que não estão aqui usam o padrão.
const MOODS := {
	&"boot": &"title", &"map": &"map", &"results": &"gold", &"shop": &"gold", &"story": &"calm",
	&"credits": &"calm", &"events": &"danger",
}

## Data de hoje "AAAA-MM-DD" (os testes fixam um calendário).
static var today_override: String = ""

var current: StringName = &""
var game: Game
var last_result: Dictionary = {}
## Corrida de um modo (Arcade, Boss Rush, Diário, Sobrevivência) ou &"" na campanha; &"practice" não paga.
var run_mode: StringName = &""
var run_queue: Array[Dictionary] = []
var run_score: int = 0
## Coop em rede local: a sala e o enlace (LanSession), criados na primeira visita à tela da sala.
var lan: LanSession
var _run_loadout: Dictionary = {}
## Carga da última missão iniciada (a revanche do chefe reusa a mesma do jogador).
var _last_loadout: Dictionary = {}
## Missão montada em memória (boss_only) em jogo como prática/revanche: o "Tentar de novo" repete o
## dicionário, pois não há arquivo em data/stages para carregar pelo id.
var _practice_mission: Dictionary = {}
var _pending_replay: Replay
var _replay_return: StringName = &""
## Coop em rede local: a semente que o anfitrião sorteou para a corrida.
var _lan_seed: int = 0

var _layer: CanvasLayer
var _root: Control
var _backdrop: AbyssBackdrop
var _shell: NavShell
var _screens: Dictionary = {}
var _history: Array[StringName] = []


func _ready() -> void:
	InputSetup.ensure_actions()
	TouchScroll.install(get_tree())
	UiFx.install(get_tree())
	FocusNav.install(get_tree())
	_layer = CanvasLayer.new()
	add_child(_layer)
	_root = Control.new()
	_root.name = "Root"
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UiTheme.text_scale = float(Settings.get_value("text_scale"))
	_root.theme = UiTheme.build(Locale.font)
	_layer.add_child(_root)
	_backdrop = AbyssBackdrop.new()
	_backdrop.name = "Backdrop"
	_backdrop.reduce_motion = bool(Settings.get_value("reduce_motion"))
	_root.add_child(_backdrop)
	_make_shell()
	SaveManager.saved.connect(func() -> void:
		if _shell.visible:
			_shell.refresh())
	Settings.changed.connect(_on_setting_changed)
	Locale.language_changed.connect(_on_language_changed)
	# Consentimento (UMP) e SDK do AdMob antes do primeiro pedido de anúncio; não espera nem trava a abertura.
	Ads.start(self)
	# Play Billing (só Android com o plugin): preços do catálogo (Iap) e restauração das compras (queryPurchases).
	Iap.start(self)
	var args := OS.get_cmdline_user_args()
	var mission := ""
	var seed := 7
	for arg: String in args:
		if arg.begins_with("--mission="):
			mission = arg.trim_prefix("--mission=")
		elif arg.begins_with("--seed="):
			seed = int(arg.trim_prefix("--seed="))
	if "--bot" in args or not mission.is_empty():
		# Carga padrão: a partida da linha de comando não depende do save (hash reproduzível).
		play(StringName(mission if not mission.is_empty() else "c1m1"), "--bot" in args, seed,
				Sim.default_loadout(&"falcon"))
		return
	go(ROOT_SCREEN)


func go(screen_name: StringName, remember: bool = true) -> void:
	if screen_name == &"back":
		go(_history.pop_back() if not _history.is_empty() else ROOT_SCREEN, false)
		return
	if not SCREENS.has(screen_name):
		Log.error("App: tela desconhecida " + String(screen_name))
		return
	# Entre abas não há histórico: a barra de baixo já é o caminho de volta.
	if NavShell.is_tab(current) and NavShell.is_tab(screen_name):
		remember = false
	# Resultado e história são de passagem: voltar nunca cai neles (senão Carta → voltar → resultado →
	# Continuar → Carta vira um laço sem saída para a Campanha e o hangar).
	if remember and not current.is_empty() and current != screen_name and current not in [&"results", &"story"]:
		_history.append(current)
		if screen_name == ROOT_SCREEN:
			_history.clear()
	# A tela pedida já está no topo do histórico (o resultado devolve à Carta de onde a missão saiu): tira.
	if not _history.is_empty() and _history.back() == screen_name:
		_history.pop_back()
	for key: StringName in _screens:
		(_screens[key] as Control).visible = key == screen_name
	if not _screens.has(screen_name):
		var screen := (SCREENS[screen_name] as GDScript).new() as Screen
		screen.name = String(screen_name).capitalize().replace(" ", "")
		screen.shell = NavShell.is_tab(screen_name)
		screen.navigate.connect(go)
		screen.play.connect(_play_from_screen)
		screen.play_mode.connect(func(mode: StringName) -> void: start_mode(mode))
		screen.play_practice.connect(practice)
		screen.rematch_boss.connect(_rematch_boss)
		if screen.has_signal("watch"):
			screen.connect("watch", func(key: String) -> void: watch_replay(key))
		_root.add_child(screen)
		_screens[screen_name] = screen
		# A casca fica sempre por cima das telas.
		_root.move_child(_shell, -1)
	var changed := current != screen_name
	current = screen_name
	_backdrop.set_mood(MOODS.get(screen_name, &"default"))
	_backdrop.scroll = 0.0
	_backdrop.drift = Vector2.ZERO
	_backdrop.ruins = 1.0
	if game == null:
		AudioManager.play_music(MENU_MUSIC)
	(_screens[screen_name] as Screen).present(self)
	_shell.visible = NavShell.is_tab(screen_name)
	if _shell.visible:
		_shell.select(screen_name)
		_shell.refresh()
	# Depois do present (on_show): a cascata de entrada respeita o que a tela acabou de esconder ou animar.
	if changed:
		UiFx.enter(_screens[screen_name] as CanvasItem)
	if FocusNav.pad:
		FocusNav.focus((_screens[screen_name] as Screen).default_focus())
	Events.screen_changed.emit(screen_name)


## Jogar pedido por uma tela: "Tentar de novo" no resultado de um modo recomeça o modo; o resto é campanha.
func _play_from_screen(mission_id: StringName) -> void:
	if current == &"results" and run_mode not in [&"", &"practice"]:
		start_mode(run_mode)
		return
	if current == &"results" and String(last_result.get("mode", "")) == "practice":
		if not _practice_mission.is_empty():
			# Revanche ou prática de uma missão montada (boss_only): repete o dicionário, não o id.
			run_mode = &"practice"
			run_queue = []
			run_score = 0
			play_mission(_practice_mission, false, -1, _last_loadout)
		else:
			practice(mission_id)
		return
	run_mode = &""
	play(mission_id)


static func today() -> String:
	return today_override if not today_override.is_empty() else Time.get_date_string_from_system()


## Começa um modo: monta a fila (Modes.run) e joga a primeira missão. Arcade, Boss Rush e Diário usam a
## aeronave escolhida sem o hangar (todos em pé de igualdade); a Sobrevivência usa o hangar.
func start_mode(mode: StringName, bot: bool = false) -> void:
	if mode == &"coop_lan":
		# A corrida em rede só começa da sala, com os dois aparelhos (também no "Tentar de novo" do resultado).
		go(&"lan")
		return
	run_mode = mode
	run_score = 0
	run_queue = Modes.run(mode, SaveManager.data, today(), Modes.date_seed(today()))
	_run_loadout = Modes.loadout_for(mode, SaveManager.data, today())
	_next_in_run(bot)


## Assiste a um replay gravado (recorde de uma missão ou modo); ao fim volta para a tela de onde veio.
func watch_replay(key: String) -> bool:
	var r := Replay.load_key(key)
	if r == null:
		return false
	_replay_return = current
	run_mode = &""
	_pending_replay = r
	play_mission(r.mission, false, r.seed, r.loadout)
	return true


## Prática: missão concluída sem recompensas (nem estrelas nem moedas).
func practice(mission_id: StringName) -> void:
	run_mode = &"practice"
	run_queue = []
	run_score = 0
	_practice_mission = {}
	play(mission_id)


## Revanche do chefe: cai direto no chefe de ato da derrota (Modes.boss_only), com a mesma carga da
## partida e sem recompensas nem estrelas (como a Prática).
func _rematch_boss(boss_id: StringName) -> void:
	run_mode = &"practice"
	run_queue = []
	run_score = 0
	_practice_mission = Modes.boss_only(boss_id, 0)
	play_mission(_practice_mission, false, -1, _last_loadout)


func _next_in_run(bot: bool = false) -> void:
	var mission: Dictionary = run_queue.pop_front()
	var seed := Modes.date_seed(today()) % 100000 if run_mode == &"daily" else -1
	if run_mode == &"coop_lan":
		# A mesma semente nos dois aparelhos, uma por missão da corrida.
		seed = _lan_seed + run_queue.size()
	play_mission(mission, bot, seed, _run_loadout)


## Sessão do coop em rede local (a tela da sala a opera; o _process a faz andar).
func lan_session() -> LanSession:
	if lan == null:
		lan = LanSession.new()
		lan.started.connect(_on_lan_started)
		lan.ended.connect(_on_lan_ended)
	return lan


## Anfitrião, com a parceira na sala: começa a corrida do coop (a do Arcade) nos dois aparelhos.
func lan_begin() -> void:
	var ids: Array = []
	for id: StringName in Modes.ARCADE:
		ids.append(String(id))
	lan.start(lan.pack_for(Modes.loadout_for(&"coop_lan", SaveManager.data, today()), ids,
			int(Time.get_unix_time_from_system()) % 100000))


## O pacote de início chegou (nos dois aparelhos): a fila, a semente e a carga vêm dele, nada deste aparelho.
func _on_lan_started(pack: Dictionary) -> void:
	run_mode = &"coop_lan"
	run_score = 0
	run_queue.clear()
	for id: Variant in pack["missions"]:
		run_queue.append(Sim.load_mission(StringName(String(id))))
	_run_loadout = pack["loadout"]
	_lan_seed = int(pack["seed"])
	_next_in_run()


## A parceira saiu, a conexão caiu ou as partidas divergiram no meio da missão: encerra sem resultado (nada é
## gravado) e volta à sala, que mostra o motivo. Com a missão já terminada o fim segue normal.
func _on_lan_ended(_reason: StringName) -> void:
	if game == null or game.sim.finished:
		return
	if lan.error == &"":
		lan.error = &"left"
	game.queue_free()
	game = null
	_layer.visible = true
	run_mode = &""
	AudioManager.play_music("")
	go(&"lan")


func _process(delta: float) -> void:
	if lan != null:
		lan.poll(delta)


## Inicia uma missão: esconde os menus e cria a cena Game.
func play(mission_id: StringName, bot: bool = false, seed: int = -1, loadout: Dictionary = {}) -> void:
	play_mission(Sim.load_mission(mission_id), bot, seed, loadout)


## Inicia uma missão a partir do dicionário (data/stages ou montada pelos Modes).
func play_mission(mission: Dictionary, bot: bool = false, seed: int = -1, loadout: Dictionary = {}) -> void:
	if game != null:
		game.queue_free()
	_layer.visible = false
	game = GAME_SCENE.instantiate() as Game
	var run_seed := seed if seed >= 0 else int(Time.get_unix_time_from_system()) % 100000
	var use_loadout := loadout if not loadout.is_empty() else Economy.loadout(SaveManager.data)
	_last_loadout = use_loadout
	game.configure(mission, use_loadout, run_seed, bot)
	if run_mode == &"coop_lan":
		lan.begin_round()
		game.lan = lan
	game.can_revive = not bot and run_mode in [&"", &"survival", &"abyss"]
	if not bot and bool(Settings.get_value("ghost")) and run_mode in [&"", &"practice"]:
		game.ghost = Replay.load_key(Replay.key_for(String(mission.get("id", "")), ""))
	if _pending_replay != null:
		game.playback = _pending_replay
		_pending_replay = null
	game.finished.connect(_on_mission_finished)
	add_child(game)
	AudioManager.play_ui("kenney_ui_confirm")


func _on_mission_finished(result: Dictionary) -> void:
	var mission_id := StringName(String(result.get("mission", "")))
	var recording := game.recording
	game.queue_free()
	game = null
	_layer.visible = true
	if bool(result.get("replay", false)):
		AudioManager.play_music("")
		go(_replay_return if _replay_return != &"" else &"records")
		return
	if bool(result.get("restart", false)):
		if run_mode in [&"", &"practice"]:
			play(mission_id)
		else:
			start_mode(run_mode)
		return
	if bool(result.get("quit", false)):
		AudioManager.play_music("")
		var back_to := &"events" if run_mode not in [&"", &"practice"] else &"map"
		if run_mode == &"coop_lan":
			lan.leave()
		run_mode = &""
		go(back_to)
		return
	run_score += int(result.get("score", 0))
	if run_mode not in [&"", &"practice"] and bool(result.get("cleared", false)) and not run_queue.is_empty():
		if run_mode == &"coop_lan" and lan.state != LanSession.State.PLAYING:
			# A parceira caiu entre duas missões: a corrida acaba aqui, na sala.
			run_mode = &""
			go(&"lan")
			return
		_next_in_run()
		return
	if run_mode == &"coop_lan":
		# Fim da corrida: cada aparelho grava o próprio resultado e a sala fecha.
		lan.leave(&"done")
		lan.error = &""
	result["mode"] = String(run_mode)
	result["run_score"] = run_score
	last_result = record_result(result, run_mode)
	_save_record(result, recording)
	run_mode = &"" if run_mode == &"practice" else run_mode
	go(&"results")


## Grava o resultado no save (Economy.apply_result: estrelas, recorde, moedas, fragmentos, asas,
## missões abertas, registros) e as estatísticas; devolve o resultado com as recompensas.
static func record_result(result: Dictionary, mode: StringName = &"") -> Dictionary:
	var out := result.duplicate(true)
	if mode == &"":
		out = Economy.apply_result(SaveManager.data, result, DB.rows("ships"), DB.rows("wings"))
		# Nota da missão e Arca da Maré (só a campanha grava a melhor nota e abre a arca).
		out.merge(TideChest.settle(SaveManager.data, result), true)
	elif mode != &"practice":
		out = Modes.apply_result(SaveManager.data, mode, result)
	if mode != &"practice":
		LiveOps.refresh(SaveManager.data, today())
		LiveOps.track(SaveManager.data, out)
		out["season_xp"] = Season.add_result(SaveManager.data, today(), out)
		out["achievements"] = Achievements.check(SaveManager.data, out)
	SaveManager.add_stat("missions_played", 1)
	SaveManager.add_stat("kills", float(result.get("kills", 0)))
	SaveManager.add_stat("grazes", float(result.get("grazes", 0)))
	SaveManager.add_stat("bombs_used", float(result.get("bombs_used", 0)))
	SaveManager.add_stat("time_played", float(result.get("seconds", 0.0)))
	if bool(result.get("cleared", false)):
		SaveManager.add_stat("missions_cleared", 1)
	else:
		SaveManager.add_stat("deaths", 1)
	SaveManager.save_profile()
	# Ranking de abates (Play Games): manda o total novo da carreira; sem login não faz nada.
	PlayRanking.submit(SaveManager.data)
	for ship: Variant in out.get("new_ships", []):
		SaveManager.unlocked.emit("ships", StringName(String(ship)))
	return out


## Placar local e replay do recorde (missões avulsas: campanha, Diário, Correntes, Sobrevivência).
func _save_record(result: Dictionary, recording: Replay) -> void:
	if run_mode in [&"practice", &"arcade", &"boss_rush", &"second_tide", &"coop", &"coop_lan"] or recording == null:
		return
	var key := Replay.key_for(String(result.get("mission", "")), String(run_mode))
	var pos := Replay.submit(SaveManager.data, key, int(result.get("score", 0)), today(),
			String(SaveManager.data["selected"]["ship"]))
	last_result["board_pos"] = pos
	if pos == 0:
		recording.score = int(result.get("score", 0))
		recording.save(key)
	SaveManager.save_profile()


## Tela já criada (testes).
func screen(screen_name: StringName) -> Screen:
	return _screens.get(screen_name) as Screen


## Fundo vivo compartilhado (o mapa liga a rolagem nele).
func backdrop() -> AbyssBackdrop:
	return _backdrop


## Casca de navegação (barra de cima e abas) das telas-aba.
func shell() -> NavShell:
	return _shell


func _make_shell() -> void:
	_shell = NavShell.new()
	_shell.visible = false
	_shell.tab_selected.connect(func(tab: StringName) -> void: go(tab, false))
	_shell.options_requested.connect(func() -> void: go(&"options"))
	_root.add_child(_shell)


## Raiz das telas (testes ajustam o tamanho para simular cada aparelho).
func root() -> Control:
	return _root


func back() -> void:
	if game != null:
		game.set_paused(not game.paused)
		return
	# Numa aba, voltar leva à Campanha; da Campanha, a própria tela decide (volta ao título).
	if NavShell.is_tab(current) and current != NavShell.HOME:
		go(NavShell.HOME, false)
		return
	var screen := screen(current)
	if screen != null and screen.back():
		return
	if current != ROOT_SCREEN:
		go(&"back")
		return
	get_tree().quit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		back()


func _unhandled_input(event: InputEvent) -> void:
	if game != null:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		AudioManager.play_ui("kenney_ui_back")
		back()
	elif FocusNav.is_nav(event) and not FocusNav.has_focus(get_viewport()) and screen(current) != null:
		# Tela sem foco (aberta pelo toque, ou o foco sumiu com o painel): o primeiro movimento só acorda o foco.
		get_viewport().set_input_as_handled()
		FocusNav.focus(screen(current).default_focus())


## Escala de texto nova: recria as telas (os rótulos guardam o tamanho) e volta para a mesma tela.
func _on_setting_changed(key: String) -> void:
	if key == "reduce_motion":
		_backdrop.reduce_motion = bool(Settings.get_value("reduce_motion"))
		UiGlint.set_reduced(bool(Settings.get_value("reduce_motion")))
	if key != "text_scale":
		return
	UiTheme.text_scale = float(Settings.get_value("text_scale"))
	_root.theme = UiTheme.build(Locale.font)
	var here := current
	for screen: Node in _screens.values():
		screen.queue_free()
	_screens.clear()
	_shell.queue_free()
	_make_shell()
	current = &""
	go(here, false)


func _on_language_changed(_code: String) -> void:
	_root.theme = UiTheme.build(Locale.font)
