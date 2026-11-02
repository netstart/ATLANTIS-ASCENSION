extends Node
## Testes com os autoloads carregados (docs/policies/testes.md): dados, idiomas e fontes, opções,
## save, áudio, licenças, PixelScaler, layout de todas as telas e créditos. Rodar:
##   godot --headless --path . --fixed-fps 60 res://tests/integration_tests.tscn [-- --shard=I/N --timing]
## Save e opções vão para arquivos próprios dos testes antes de qualquer verificação: nem um teste
## interrompido no meio mexe no perfil ou no settings.cfg do jogador.

const DeviceProfiles := preload("res://tests/device_profiles.gd")
const LayoutTests := preload("res://tests/layout_tests.gd")
const CreditsScreenTests := preload("res://tests/credits_screen_tests.gd")
const FlowTests := preload("res://tests/flow_tests.gd")
const EconomyTests := preload("res://tests/economy_tests.gd")
const BetaTests := preload("res://tests/beta_tests.gd")
const LaunchTests := preload("res://tests/launch_tests.gd")
const PostTests := preload("res://tests/post_tests.gd")
const LiveryTests := preload("res://tests/livery_tests.gd")
const GloryTests := preload("res://tests/glory_tests.gd")
const WeatherViewTests := preload("res://tests/weather_view_tests.gd")
const FocusNavTests := preload("res://tests/focus_nav_tests.gd")
const ScreenBuildTests := preload("res://tests/screen_build_tests.gd")
const TestShard := preload("res://tests/test_shard.gd")
const CommandTests := preload("res://tests/command_tests.gd")
const CampaignTests := preload("res://tests/campaign_tests.gd")
const HangarTests := preload("res://tests/hangar_tests.gd")
const StoreTests := preload("res://tests/store_tests.gd")

var _count: int = 0
var _failures: int = 0
var _real_files: Dictionary = {}
## Esta fatia conta as verificações do prefixo? (só a fatia 0; ver _ready)
var _owns_prefix: bool = true
## Falhas do prefixo nas fatias 1..N-1: reprovam a fatia, mas não entram na conta (a fatia 0 já conta).
var _uncounted_failures: int = 0


## Rodar em fatias (tools/run_checks.ps1): `-- --shard=I/N` (tests/test_shard.gd). As unidades pesadas
## (campanha da economia, Beta, pós-lançamento, cada caso de layout, cada HUD) se dividem entre os
## processos. O prefixo barato que mexe em estado global (opções, save, vibração, relógio) roda em toda
## fatia, na mesma ordem, para cada uma começar do mesmo estado do processo único; só a fatia 0 conta
## essas verificações (nas outras, uma falha ainda reprova). Sem `--shard`, tudo num processo só.
## Use `--fixed-fps 60`: cada quadro avança 1/60 s de jogo sem esperar o relógio (as esperas abaixo
## contam quadros, não milissegundos).
func _ready() -> void:
	var shard := TestShard.parse(OS.get_cmdline_user_args())
	if shard.y == 0:
		printerr("FALHOU: argumento --shard malformado (use --shard=I/N, com 0 <= I < N)")
		get_tree().quit(1)
		return
	_owns_prefix = shard.x == 0
	var prefix := _check if _owns_prefix else _check_uncounted
	for file: String in [SaveManager.PATH, SaveManager.BACKUP_PATH, Settings.PATH]:
		_real_files[file] = FileAccess.get_md5(file) if FileAccess.file_exists(file) else ""
	SaveManager.use_test_files()
	Settings.use_test_file()
	_test_data(prefix)
	_test_locale(prefix)
	_test_settings(prefix)
	_test_save(prefix)
	_test_audio(prefix)
	_test_licenses(prefix)
	var layout := LayoutTests.new()
	var cases := DeviceProfiles.layout_cases()
	var units: Array[Dictionary] = [
		{"name": "Economia", "weight": 100.0, "run": func() -> void: EconomyTests.new().run(_check)},
		{"name": "Beta", "weight": 24.0, "run": func() -> void: BetaTests.new().run(_check)},
		{"name": "Pós-lançamento", "weight": 24.0, "run": func() -> void: PostTests.new().run(_check)},
		{"name": "prefixo 2", "weight": 0.0, "prefix": true, "run": func() -> void:
			LiveryTests.new().run(prefix)
			GloryTests.new().run(prefix)
			DeviceProfiles.check_scaler(self, prefix)},
	]
	var first_layout := units.size()
	for c: Dictionary in cases:
		units.append({"name": "Layout [%s]" % c["label"], "weight": 0.8 * (c["langs"] as Array).size(),
				"run": func() -> void: await layout.run_case(self, _check, c)})
	for c: Dictionary in cases:
		units.append({"name": "Layout HUD [%s]" % c["label"], "weight": 0.4,
				"run": func() -> void: await layout.run_hud_case(self, _check, c)})
	units.append({"name": "fim do layout", "weight": 0.0, "prefix": true, "run": LayoutTests.finish})
	units.append({"name": "Telas e fluxo", "weight": 6.0, "run": func() -> void:
		await CreditsScreenTests.new().run(self, _check)
		await FlowTests.new().run(self, _check)
		await LiveryTests.new().run_view(self, _check)
		await GloryTests.new().run_view(self, _check)
		await WeatherViewTests.new().run_view(self, _check)
		await FocusNavTests.new().run(self, _check)
		await ScreenBuildTests.new().run(self, _check)})
	units.append({"name": "Menus de comando (regras)", "weight": 1.0, "run": func() -> void:
		CommandTests.new().run(_check)
		CampaignTests.new().run(_check)
		StoreTests.new().run(_check)})
	units.append({"name": "Casca de comando", "weight": 1.0, "run": func() -> void:
		await CommandTests.new().run_view(self, _check)})
	units.append({"name": "Campanha", "weight": 4.5, "run": func() -> void:
		await CampaignTests.new().run_view(self, _check)})
	# A Oficina em todas as resoluções custa mais que a economia inteira: um caso por unidade.
	var hangar := HangarTests.new()
	for c: Dictionary in cases:
		units.append({"name": "Oficina [%s]" % c["label"], "weight": 3.5,
				"run": func() -> void: await hangar.run_layout_case(self, _check, c)})
	units.append({"name": "Oficina (fluxo)", "weight": 2.0, "run": func() -> void: await hangar.run_flow(self, _check)})
	units.append({"name": "Loja, Naves e Eventos", "weight": 1.5, "run": func() -> void:
		await StoreTests.new().run_view(self, _check)})
	units.append({"name": "Lançamento", "weight": 10.0, "run": func() -> void: LaunchTests.new().run(_check)})
	# Unidades do prefixo ficam fora da divisão: rodam em toda fatia, no lugar de sempre.
	var shardable: Array[Dictionary] = units.filter(func(u: Dictionary) -> bool: return not u.has("prefix"))
	var mine := TestShard.mine(shardable, shard)
	var warmed := mine.has(units[first_layout])
	for i: int in range(units.size()):
		var unit := units[i]
		if not unit.has("prefix") and not mine.has(unit):
			continue
		if i >= first_layout and not warmed and not unit.has("prefix"):
			await layout.warm_up(self, cases[0])
			warmed = true
		var start := Time.get_ticks_msec()
		var before := _count
		await (unit["run"] as Callable).call()
		if TestShard.timing_enabled():
			print("tempo %6d ms  %5d verificações  %s" % [Time.get_ticks_msec() - start, _count - before, unit["name"]])
	for file: String in SaveManager.TEST_PATHS + [Settings.TEST_PATH]:
		if FileAccess.file_exists(file):
			DirAccess.remove_absolute(file)
	for file: String in _real_files:
		var now := FileAccess.get_md5(file) if FileAccess.file_exists(file) else ""
		prefix.call(now == _real_files[file], "testes não mexeram em %s do jogador" % file)
	print(TestShard.summary("integração", shard, mine.size(), shardable.size()))
	print("%d verificações, %d falhas" % [_count, _failures])
	get_tree().quit(1 if _failures > 0 or _uncounted_failures > 0 else 0)


## Verificação do prefixo nas fatias 1..N-1: não entra na conta (a fatia 0 já conta), mas reprova.
func _check_uncounted(condition: bool, label: String) -> void:
	if not condition:
		_uncounted_failures += 1
		printerr("FALHOU: " + label)


func _check(condition: bool, label: String) -> void:
	_count += 1
	if not condition:
		_failures += 1
		printerr("FALHOU: " + label)
	elif "--verbose" in OS.get_cmdline_user_args():
		print("ok: " + label)


func _test_data(check: Callable) -> void:
	check.call(DB.errors.is_empty(), "Dados: nenhum erro ao carregar (%s)" % [DB.errors])
	check.call(DB.ids("ships").size() == 12, "Dados: 12 aeronaves (6 da 1.0 e 6 do pós-lançamento)")
	check.call(not Sim.load_tables()["enemies"].is_empty(), "Dados: inimigos carregam")
	for id: StringName in DB.ids("ships"):
		var ship := DB.ship(id)
		check.call(not DB.weapon(StringName(String(ship.get("signature", "")))).is_empty(),
				"Dados: arma assinatura de %s existe" % id)
		check.call(Locale.keys.has(String(ship.get("name_key", ""))), "Dados: nome de %s traduzido" % id)
	for id: StringName in DB.ids("weapons"):
		var dps: Array = DB.weapon(id).get("dps", [])
		check.call(dps.size() == 4, "Dados: %s com 4 níveis de DPS" % id)
		for i: int in range(1, dps.size()):
			check.call(float(dps[i]) > float(dps[i - 1]), "Dados: DPS de %s cresce no nível %d" % [id, i + 1])


func _test_locale(check: Callable) -> void:
	check.call(not Locale.keys.is_empty(), "Idiomas: strings.csv carregou")
	for lang: String in Languages.SUPPORTED:
		var font := Locale.font_for(lang)
		var missing := PackedStringArray()
		for key: String in Locale.keys:
			var text := Locale.text(key, lang)
			check.call(not text.is_empty() and text != key, "Idiomas: %s [%s] traduzida" % [key, lang])
			for i: int in range(text.length()):
				var code := text.unicode_at(i)
				if code > 32 and not font.has_char(code) and not missing.has(text[i]):
					missing.append(text[i])
		check.call(missing.is_empty(), "Idiomas: fonte de %s cobre todos os glifos (faltam %s)" % [lang, missing])
	check.call(Locale.language_for("pt_PT") == "pt_BR", "Idiomas: pt_PT vira pt_BR")
	check.call(Locale.language_for("zh_HK") == "zh_TW", "Idiomas: zh_HK vira zh_TW")
	check.call(Locale.language_for("zh_SG") == "zh_CN", "Idiomas: zh_SG vira zh_CN")
	check.call(Locale.language_for("xx") == "en", "Idiomas: desconhecido vira en")
	check.call(Locale.group_digits(1234567, "pt_BR") == "1.234.567", "Idiomas: milhar em pt_BR")
	check.call(Locale.group_digits(-1234, "en") == "-1,234", "Idiomas: milhar em en")


func _test_settings(check: Callable) -> void:
	check.call(Settings.path == Settings.TEST_PATH, "Opções: arquivo dos testes")
	Settings.set_value("drag_sensitivity", 1.5)
	Settings.load_settings()
	check.call(is_equal_approx(float(Settings.get_value("drag_sensitivity")), 1.5), "Opções: grava e relê")
	for key: String in Settings.DEFAULTS:
		check.call(Settings.get_value(key) != null, "Opções: %s tem valor" % key)


func _test_save(check: Callable) -> void:
	check.call(SaveManager.path == SaveManager.TEST_PATHS[0], "Save: arquivo dos testes")
	SaveManager.reset_profile()
	SaveManager.add_currency("credits", 250)
	SaveManager.add_currency("credits", -1000)
	check.call(SaveManager.currency("credits") == 0, "Save: moeda nunca negativa")
	SaveManager.add_currency("pearls", 30)
	SaveManager.mission_record(&"c1m1")["best_score"] = 12345
	check.call(SaveManager.unlock("ships", &"manta"), "Save: desbloqueia aeronave")
	check.call(not SaveManager.unlock("ships", &"manta"), "Save: desbloqueio repetido não conta")
	SaveManager.save_profile()
	SaveManager.load_profile()
	check.call(SaveManager.currency("pearls") == 30 and SaveManager.is_unlocked("ships", &"manta"),
			"Save: grava e relê moedas e desbloqueios")
	check.call(int(SaveManager.mission_record(&"c1m1")["best_score"]) == 12345, "Save: grava e relê missões")
	var old := {"version": 0, "wallet": {"credits": 7}}
	var migrated := SaveManager.migrate(old)
	check.call(int(migrated["wallet"]["credits"]) == 7 and migrated.has("hangar")
			and (migrated["wallet"] as Dictionary).has("pearls"), "Save: migração completa campos e mantém valores")
	var file := FileAccess.open(SaveManager.path, FileAccess.WRITE)
	file.store_string("{corrompido")
	file.close()
	SaveManager.load_profile()
	check.call(SaveManager.recovered_from_backup, "Save: save corrompido volta pelo backup")
	SaveManager.reset_profile()


func _test_audio(check: Callable) -> void:
	for bus: String in AudioManager.BUSES:
		check.call(AudioServer.get_bus_index(bus) >= 0, "Áudio: bus %s existe" % bus)
	check.call(not AudioManager.play("som_que_nao_existe"), "Áudio: id sem arquivo é ignorado")
	check.call(AudioManager.missing.has("som_que_nao_existe"), "Áudio: id sem arquivo é registrado")
	check.call(AudioManager.variants("kenney_medal") == ["kenney_medal"],
			"Áudio: id com arquivo próprio não vira variante")
	# Coletas e acerto (1.14.3, tools/mix_pickup_audio.py): curtos, para não embolar na rajada.
	var limits := {"coin_medal": [1, 0.40], "coin_capsule": [1, 0.32], "coin_pearl": [3, 0.15], "hit": [5, 0.10]}
	for id: String in limits:
		var ids := AudioManager.variants(id)
		check.call(ids.size() == int(limits[id][0]), "Áudio: %s tem %d variante(s)" % [id, limits[id][0]])
		for variant: String in ids:
			var stream := load(AudioManager.SFX_DIR + variant + ".ogg") as AudioStream
			check.call(stream != null and stream.get_length() > 0.05 and stream.get_length() <= float(limits[id][1]),
					"Áudio: %s carrega e dura até %.2f s" % [variant, limits[id][1]])
	var last := -1
	var seen := {}
	var repeats := 0
	for roll: int in range(200):
		var pick := AudioManager.next_variant(5, last, roll * 7919 + 13)
		repeats += 1 if pick == last else 0
		seen[pick] = true
		last = pick
	check.call(repeats == 0 and seen.size() == 5, "Áudio: variantes alternam sem repetir a anterior e cobrem todas")
	check.call(AudioManager.next_variant(1, 0, 99) == 0, "Áudio: uma variante só sempre toca a mesma")


func _test_licenses(check: Callable) -> void:
	var index := CreditsScreen.load_index()
	var registry: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://licenses/registry.json"))
	check.call(typeof(registry) == TYPE_ARRAY and (registry as Array).size() == index.size(),
			"Licenças: índice com todas as entradas do registro")
	for row: Variant in index:
		var entry := row as Dictionary
		check.call(FileAccess.file_exists(String(entry.get("license_file", ""))),
				"Licenças: texto de %s no projeto" % entry.get("id"))
		if entry.has("notice_file"):
			check.call(FileAccess.file_exists(String(entry["notice_file"])),
					"Licenças: aviso de %s no projeto" % entry.get("id"))
