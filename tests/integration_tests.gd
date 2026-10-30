extends Node
## Testes com os autoloads carregados (docs/policies/testes.md): dados, idiomas e fontes, opções,
## save, áudio, licenças, PixelScaler, layout de todas as telas e créditos. Rodar:
##   godot --headless --path . res://tests/integration_tests.tscn
## Save e opções vão para arquivos próprios dos testes antes de qualquer verificação: nem um teste
## interrompido no meio mexe no perfil ou no settings.cfg do jogador.

const DeviceProfiles := preload("res://tests/device_profiles.gd")
const LayoutTests := preload("res://tests/layout_tests.gd")
const CreditsScreenTests := preload("res://tests/credits_screen_tests.gd")

var _count: int = 0
var _failures: int = 0
var _real_files: Dictionary = {}


func _ready() -> void:
	for file: String in [SaveManager.PATH, SaveManager.BACKUP_PATH, Settings.PATH]:
		_real_files[file] = FileAccess.get_md5(file) if FileAccess.file_exists(file) else ""
	SaveManager.use_test_files()
	Settings.use_test_file()
	_test_data()
	_test_locale()
	_test_settings()
	_test_save()
	_test_audio()
	_test_licenses()
	DeviceProfiles.check_scaler(self, _check)
	await LayoutTests.new().run(self, _check)
	await CreditsScreenTests.new().run(self, _check)
	for file: String in SaveManager.TEST_PATHS + [Settings.TEST_PATH]:
		if FileAccess.file_exists(file):
			DirAccess.remove_absolute(file)
	for file: String in _real_files:
		var now := FileAccess.get_md5(file) if FileAccess.file_exists(file) else ""
		_check(now == _real_files[file], "testes não mexeram em %s do jogador" % file)
	print("%d verificações, %d falhas" % [_count, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func _check(condition: bool, label: String) -> void:
	_count += 1
	if not condition:
		_failures += 1
		printerr("FALHOU: " + label)
	elif "--verbose" in OS.get_cmdline_user_args():
		print("ok: " + label)


func _test_data() -> void:
	_check(DB.errors.is_empty(), "Dados: nenhum erro ao carregar (%s)" % [DB.errors])
	_check(DB.ids("ships").size() == 6, "Dados: 6 aeronaves da 1.0")
	for id: StringName in DB.ids("ships"):
		var ship := DB.ship(id)
		_check(not DB.weapon(StringName(String(ship.get("signature", "")))).is_empty(),
				"Dados: arma assinatura de %s existe" % id)
		_check(Locale.keys.has(String(ship.get("name_key", ""))), "Dados: nome de %s traduzido" % id)
	for id: StringName in DB.ids("weapons"):
		var dps: Array = DB.weapon(id).get("dps", [])
		_check(dps.size() == 4, "Dados: %s com 4 níveis de DPS" % id)
		for i: int in range(1, dps.size()):
			_check(float(dps[i]) > float(dps[i - 1]), "Dados: DPS de %s cresce no nível %d" % [id, i + 1])


func _test_locale() -> void:
	_check(not Locale.keys.is_empty(), "Idiomas: strings.csv carregou")
	for lang: String in Languages.SUPPORTED:
		var font := Locale.font_for(lang)
		var missing := PackedStringArray()
		for key: String in Locale.keys:
			var text := Locale.text(key, lang)
			_check(not text.is_empty() and text != key, "Idiomas: %s [%s] traduzida" % [key, lang])
			for i: int in range(text.length()):
				var code := text.unicode_at(i)
				if code > 32 and not font.has_char(code) and not missing.has(text[i]):
					missing.append(text[i])
		_check(missing.is_empty(), "Idiomas: fonte de %s cobre todos os glifos (faltam %s)" % [lang, missing])
	_check(Locale.language_for("pt_PT") == "pt_BR", "Idiomas: pt_PT vira pt_BR")
	_check(Locale.language_for("zh_HK") == "zh_TW", "Idiomas: zh_HK vira zh_TW")
	_check(Locale.language_for("zh_SG") == "zh_CN", "Idiomas: zh_SG vira zh_CN")
	_check(Locale.language_for("xx") == "en", "Idiomas: desconhecido vira en")
	_check(Locale.group_digits(1234567, "pt_BR") == "1.234.567", "Idiomas: milhar em pt_BR")
	_check(Locale.group_digits(-1234, "en") == "-1,234", "Idiomas: milhar em en")


func _test_settings() -> void:
	_check(Settings.path == Settings.TEST_PATH, "Opções: arquivo dos testes")
	Settings.set_value("drag_sensitivity", 1.5)
	Settings.load_settings()
	_check(is_equal_approx(float(Settings.get_value("drag_sensitivity")), 1.5), "Opções: grava e relê")
	for key: String in Settings.DEFAULTS:
		_check(Settings.get_value(key) != null, "Opções: %s tem valor" % key)


func _test_save() -> void:
	_check(SaveManager.path == SaveManager.TEST_PATHS[0], "Save: arquivo dos testes")
	SaveManager.reset_profile()
	SaveManager.add_currency("credits", 250)
	SaveManager.add_currency("credits", -1000)
	_check(SaveManager.currency("credits") == 0, "Save: moeda nunca negativa")
	SaveManager.add_currency("pearls", 30)
	SaveManager.mission_record(&"c1m1")["best_score"] = 12345
	_check(SaveManager.unlock("ships", &"manta"), "Save: desbloqueia aeronave")
	_check(not SaveManager.unlock("ships", &"manta"), "Save: desbloqueio repetido não conta")
	SaveManager.save_profile()
	SaveManager.load_profile()
	_check(SaveManager.currency("pearls") == 30 and SaveManager.is_unlocked("ships", &"manta"),
			"Save: grava e relê moedas e desbloqueios")
	_check(int(SaveManager.mission_record(&"c1m1")["best_score"]) == 12345, "Save: grava e relê missões")
	var old := {"version": 0, "wallet": {"credits": 7}}
	var migrated := SaveManager.migrate(old)
	_check(int(migrated["wallet"]["credits"]) == 7 and migrated.has("hangar")
			and (migrated["wallet"] as Dictionary).has("pearls"), "Save: migração completa campos e mantém valores")
	var file := FileAccess.open(SaveManager.path, FileAccess.WRITE)
	file.store_string("{corrompido")
	file.close()
	SaveManager.load_profile()
	_check(SaveManager.recovered_from_backup, "Save: save corrompido volta pelo backup")
	SaveManager.reset_profile()


func _test_audio() -> void:
	for bus: String in AudioManager.BUSES:
		_check(AudioServer.get_bus_index(bus) >= 0, "Áudio: bus %s existe" % bus)
	_check(not AudioManager.play("som_que_nao_existe"), "Áudio: id sem arquivo é ignorado")
	_check(AudioManager.missing.has("som_que_nao_existe"), "Áudio: id sem arquivo é registrado")


func _test_licenses() -> void:
	var index := CreditsScreen.load_index()
	var registry: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://licenses/registry.json"))
	_check(typeof(registry) == TYPE_ARRAY and (registry as Array).size() == index.size(),
			"Licenças: índice com todas as entradas do registro")
	for row: Variant in index:
		var entry := row as Dictionary
		_check(FileAccess.file_exists(String(entry.get("license_file", ""))),
				"Licenças: texto de %s no projeto" % entry.get("id"))
		if entry.has("notice_file"):
			_check(FileAccess.file_exists(String(entry["notice_file"])), "Licenças: aviso de %s no projeto" % entry.get("id"))
