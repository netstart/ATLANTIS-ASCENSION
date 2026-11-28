extends RefCounted
## Economia e progressão (Economy, plano mestre 4.9): regras do grafo da campanha, custos, fragmentos,
## asas, segredo e a simulação da economia — o bot joga a campanha inteira (9 capítulos) com a carga do
## hangar, gastando os créditos como um jogador faria, e o ritmo das recompensas tem de ficar na faixa
## planejada. Chamado por tests/integration_tests.gd (precisa do perfil padrão do SaveManager).

const SaveManagerScript := preload("res://scripts/autoload/save_manager.gd")
## Ordem em que o "jogador" joga a campanha (as secretas só entram se abertas).
const ORDER: Array[StringName] = [&"c1m1", &"c1m2", &"c1m3", &"c2m1", &"s1", &"c2m2", &"c2m3", &"c3m1", &"c3m2",
		&"c3m3a", &"c4m1", &"s2", &"c4m2", &"c4m3a", &"c5m1", &"c5m2", &"c5m3s", &"c6m1", &"s3", &"c6m2", &"c6m3a",
		&"c7m1", &"c7m2", &"c7m3s", &"c8m1", &"s4", &"c8m2", &"c8m3a", &"c9m1", &"c9m2", &"c9m3",
		&"c10m1", &"c10m2", &"c10m3"]

## Estado da campanha no fim do último trecho jogado neste processo (trecho seguinte na mesma fatia parte dele).
static var _handoff: Dictionary = {}


func run(check: Callable) -> void:
	run_rules(check)
	run_segment(check, 0, 1, "")


func run_rules(check: Callable) -> void:
	_rules(check)


func _rules(check: Callable) -> void:
	var p := SaveManagerScript.default_profile()
	var ships := DB.rows("ships")
	var wings := DB.rows("wings")
	check.call(Economy.mission_unlocked(p, &"c1m1") and not Economy.mission_unlocked(p, &"c1m2"),
			"Economia: só a 1-1 aberta no começo")
	check.call(not Economy.mission_unlocked(p, &"s1"), "Economia: missão secreta fechada no começo")
	check.call(Economy.next_mission(p) == &"c1m1", "Economia: próxima missão é a 1-1")
	var r := Economy.apply_result(p, {"mission": "c1m1", "cleared": true, "score": 20000,
			"stars": [true, true, true, true], "pearls": 25, "orichalcum": 2, "log_found": true}, ships, wings)
	check.call(int(r["credits"]) == 50 + 10 + 100, "Economia: créditos = base + pontos + estrelas (%d)" % r["credits"])
	check.call(int(r["new_stars"]) == 4 and bool(r["record"]), "Economia: 4 estrelas novas e recorde")
	check.call(&"c1m2" in r["new_missions"], "Economia: concluir a 1-1 abre a 1-2")
	check.call(bool(r["log"]) and (p["story"]["logs"] as Array).has("c1m1"), "Economia: registro vai para o diário")
	check.call(int(r["pearls_gain"]) == 2, "Economia: 25 pérolas recolhidas viram 2 na carteira")
	check.call(&"wing_magnet" in r["new_wings"], "Economia: 3 estrelas liberam a primeira asa")
	var again := Economy.apply_result(p, {"mission": "c1m1", "cleared": true, "score": 100,
			"stars": [true, true, true, true]}, ships, wings)
	check.call(int(again["new_stars"]) == 0 and not bool(again["record"]), "Economia: repetir não paga estrelas de novo")
	for m: String in ["c1m2", "c1m3"]:
		Economy.apply_result(p, {"mission": m, "cleared": true, "score": 1000, "stars": [true, false, false, false]},
				ships, wings)
	check.call((p["unlocked"]["ships"] as Array).has("manta"), "Economia: fragmentos da 1-2 e 1-3 abrem a Manta")
	check.call(Economy.next_mission(p) == &"c2m1", "Economia: próxima missão é a 2-1")
	Economy.apply_result(p, {"mission": "c2m1", "cleared": true, "score": 1000, "stars": [true, false, false, true],
			"secret": "s1"}, ships, wings)
	check.call(Economy.mission_unlocked(p, &"s1"), "Economia: glifos na ordem abrem a missão secreta")
	p["wallet"]["credits"] = 0
	check.call(not Economy.upgrade_ship(p, &"falcon"), "Economia: sem créditos não sobe nível")
	p["wallet"]["credits"] = Economy.ship_level_cost(1)
	check.call(Economy.upgrade_ship(p, &"falcon") and Economy.ship_level(p, &"falcon") == 2
			and int(p["wallet"]["credits"]) == 0, "Economia: subir nível cobra o custo exato")
	p["wallet"]["credits"] = 10000
	p["wallet"]["orichalcum"] = 100
	check.call(Economy.upgrade_secondary(p, &"missiles") and Economy.secondary_level(p, &"missiles") == 1,
			"Economia: comprar mísseis")
	p["selected"]["secondary"] = "missiles"
	check.call(Economy.toggle_wing(p, &"wing_magnet", wings), "Economia: equipar asa liberada")
	check.call(not Economy.toggle_wing(p, &"wing_tide", wings), "Economia: asa sem estrelas suficientes não equipa")
	var load := Economy.loadout(p)
	check.call(load["secondary"] == "missiles" and (load["wings"] as Array).has("wing_magnet")
			and is_equal_approx(float(load["damage"]), 0.03), "Economia: carga leva nível, secundária e asa")
	for i: int in range(Economy.SHIP_MAX_LEVEL + 2):
		p["wallet"]["credits"] = 100000
		Economy.upgrade_ship(p, &"falcon")
	check.call(Economy.ship_level(p, &"falcon") == Economy.SHIP_MAX_LEVEL, "Economia: nível para no máximo")


## Campanha inteira jogada pelo bot com a carga do hangar: depois de cada missão o "jogador" sobe a
## aeronave sempre que puder e entra nas secretas que abriu, com a Arca da Maré de cada vitória.
## Faixas planejadas (plano mestre 18.1): ao
## fim do Ato I (3-3) a aeronave está no nível 3 a 7; ao fim da campanha, no 6 ou mais, com as 6
## aeronaves abertas e um final escolhido.
##
## Em trechos (`part` de `parts`, ~1 min cada), para rodar em fatias paralelas sem perder nada: o trecho k
## precisa do estado (perfil e contadores) do fim do trecho k-1. Na mesma fatia ele vem da memória; em fatias
## separadas vem do estado guardado em `cache_dir` pela rodada anterior (tools/run_checks.ps1). Cada trecho
## imprime o hash do estado em que começou e em que terminou; o run_checks.ps1 confere que o começo de cada
## trecho é o fim do anterior e, se o guardado estava velho (balanceamento mudou), roda o trecho de novo a
## partir do estado certo. Sem estado nenhum, o trecho refaz os anteriores sem verificações antes de começar.
func run_segment(check: Callable, part: int, parts: int, cache_dir: String) -> void:
	var tables := Sim.load_tables()
	var state := _start_state(part, parts, cache_dir, tables)
	print("economia %d/%d: começo %s" % [part + 1, parts, state_hash(state)])
	_play(check, state, _slice(part, parts), tables)
	if part < parts - 1:
		_handoff = {"part": part + 1, "parts": parts, "state": state.duplicate(true)}
		print("economia %d/%d: fim %s" % [part + 1, parts, state_hash(state)])
		if not cache_dir.is_empty():
			_store(cache_dir, part + 1, parts, state)
		return
	_final_checks(check, state)


static func state_hash(state: Dictionary) -> String:
	return var_to_str(state).md5_text()


## Missões do trecho `part`. Em 3 trechos, cortes medidos (~55 s cada: as do fim custam mais); senão, pela contagem.
static func _slice(part: int, parts: int) -> Array[StringName]:
	var cuts: Array[int] = [0, 13, 22, ORDER.size()]
	if parts != 3:
		cuts.clear()
		for k: int in range(parts + 1):
			cuts.append(int(ORDER.size() * k / float(parts)))
	return ORDER.slice(cuts[part], cuts[part + 1])


static func _fresh_state() -> Dictionary:
	return {"p": SaveManagerScript.default_profile(), "act1_level": 0, "ending": "", "chapter": 0}


func _start_state(part: int, parts: int, cache_dir: String, tables: Dictionary) -> Dictionary:
	if part == 0:
		return _fresh_state()
	if int(_handoff.get("part", -1)) == part and int(_handoff.get("parts", -1)) == parts:
		return (_handoff["state"] as Dictionary).duplicate(true)
	if not cache_dir.is_empty():
		var path := _cache_path(cache_dir, part, parts)
		if FileAccess.file_exists(path):
			var stored: Variant = str_to_var(FileAccess.get_file_as_string(path))
			if stored is Dictionary and (stored as Dictionary).has("p"):
				return stored
	print("economia %d/%d: sem estado guardado; refaz os trechos anteriores" % [part + 1, parts])
	var state := _fresh_state()
	for k: int in range(part):
		_play(func(_ok: bool, _label: String) -> void: pass, state, _slice(k, parts), tables)
	return state


static func _cache_path(cache_dir: String, part: int, parts: int) -> String:
	return cache_dir.path_join("economia_%d_de_%d.txt" % [part + 1, parts])


static func _store(cache_dir: String, part: int, parts: int, state: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(cache_dir)
	var path := _cache_path(cache_dir, part, parts)
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		return
	file.store_string(var_to_str(state))
	file.close()
	DirAccess.rename_absolute(path + ".tmp", path)


func _play(check: Callable, state: Dictionary, missions: Array[StringName], tables: Dictionary) -> void:
	var p: Dictionary = state["p"]
	var act1_level: int = state["act1_level"]
	var ending: String = state["ending"]
	var chapter: int = state["chapter"]
	for id: StringName in missions:
		if Economy.node(id)["kind"] == &"secret" and not Economy.mission_unlocked(p, id):
			continue
		# Poder recomendado ancorado na curva do bot: ao chegar em cada capítulo ele alcança o recomendado,
		# sem passar demais (senão o número não diz nada a quem joga sem pressa).
		if int(Economy.node(id)["chapter"]) != chapter:
			chapter = int(Economy.node(id)["chapter"])
			var power := Economy.power(p)
			var rec := Economy.recommended_power(chapter)
			check.call(power >= rec and power <= rec * 1.6,
					"Economia: Poder do bot no capítulo %d perto do recomendado (%d para %d)" % [chapter, power, rec])
		check.call(Economy.mission_unlocked(p, id), "Economia: %s aberta na hora certa" % id)
		var sim := Sim.new()
		sim.setup(Sim.load_mission(id), tables, Economy.loadout(p), 7)
		var bot := BotPilot.new()
		while not sim.finished and sim.frame < 60 * 60 * 10:
			sim.step(bot.decide(sim))
		check.call(sim.cleared, "Economia: o bot vence %s com a carga do hangar" % id)
		var result := sim.result()
		result["seed"] = 7
		var r := Economy.apply_result(p, result, DB.rows("ships"), DB.rows("wings"))
		# A Arca da Maré entra na curva como no jogo (App.record_result): a faixa vale com ela.
		TideChest.settle(p, result)
		ending = String(r.get("ending", ending)) if not String(r.get("ending", "")).is_empty() else ending
		while Economy.upgrade_ship(p, &"falcon"):
			pass
		if id == &"c3m3a":
			act1_level = Economy.ship_level(p, &"falcon")
	state["act1_level"] = act1_level
	state["ending"] = ending
	state["chapter"] = chapter


func _final_checks(check: Callable, state: Dictionary) -> void:
	var p: Dictionary = state["p"]
	var act1_level: int = state["act1_level"]
	var ending: String = state["ending"]
	var level := Economy.ship_level(p, &"falcon")
	if "--verbose" in OS.get_cmdline_user_args():
		print("Economia: Ato I nível %d; fim nível %d, carteira %s, estrelas %d, resgatados %d, secretas %d" % [
				act1_level, level, p["wallet"], Economy.total_stars(p), p["rescued_total"], Economy.abyss_records(p)])
	check.call(act1_level >= 3 and act1_level <= 7, "Economia: aeronave no nível 3 a 7 ao fim do Ato I (%d)" % act1_level)
	check.call(level >= 6, "Economia: aeronave no nível 6+ ao fim da campanha (%d)" % level)
	check.call(Economy.total_stars(p) >= 60, "Economia: o bot junta ≥ 60 estrelas (%d)" % Economy.total_stars(p))
	# Toda aeronave com fontes só na campanha principal abre (as de missões secretas e de final dependem do jogador;
	# as premium só saem compradas).
	var expected := 0
	for row: Variant in DB.rows("ships"):
		var srcs: Array = (row as Dictionary).get("sources", [])
		var main := not (row as Dictionary).has("ending") and not (row as Dictionary).has("premium")
		for m: Variant in srcs:
			main = main and Economy.node(StringName(String(m)))["kind"] != &"secret"
		if main:
			expected += 1
	check.call((p["unlocked"]["ships"] as Array).size() >= expected,
			"Economia: as %d aeronaves da campanha principal abrem (%d)" % [expected, (p["unlocked"]["ships"] as Array).size()])
	check.call(int(p["rescued_total"]) >= 10, "Economia: resgates reerguem ao menos as Docas (%d)" % p["rescued_total"])
	check.call(not ending.is_empty(), "Economia: a campanha termina com um final (%s)" % ending)
