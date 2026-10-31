extends SceneTree
## Testes das regras puras (docs/policies/testes.md). Sem cena e sem autoloads.
## Rodar: godot --headless --path . --script res://tests/run_tests.gd [-- --verbose]

const DeviceProfiles := preload("res://tests/device_profiles.gd")
const PixelScalerScript := preload("res://scripts/autoload/pixel_scaler.gd")
const SimTests := preload("res://tests/sim_tests.gd")
const ParallaxTests := preload("res://tests/parallax_tests.gd")
const VfxTests := preload("res://tests/vfx_tests.gd")
const SEMVER := "^(0|[1-9]\\d*)\\.(0|[1-9]\\d*)\\.(0|[1-9]\\d*)$"

var _count: int = 0
var _failures: int = 0


func _initialize() -> void:
	_test_scaler()
	_test_playfield()
	_test_spatial_hash()
	_test_frame_stats()
	_test_frame_pacing()
	_test_gfx_quality()
	_test_languages()
	_test_version()
	SimTests.new().run_unit(_check)
	ParallaxTests.new().run_unit(_check)
	VfxTests.new().run_unit(_check)
	print("%d verificações, %d falhas" % [_count, _failures])
	quit(1 if _failures > 0 else 0)


func _check(condition: bool, label: String) -> void:
	_count += 1
	if not condition:
		_failures += 1
		printerr("FALHOU: " + label)
	elif "--verbose" in OS.get_cmdline_user_args():
		print("ok: " + label)


func _test_scaler() -> void:
	for r: Dictionary in DeviceProfiles.RESOLUTIONS:
		var physical: Vector2i = r["physical"]
		_check(PixelScalerScript.factor_for(physical) == int(r["scale"]),
				"PixelScaler: %s dá ×%d" % [physical, r["scale"]])
		_check(Vector2(PixelScalerScript.logical_for(physical)) == r["view"],
				"PixelScaler: %s dá %s" % [physical, r["label"]])
	for e: Array in DeviceProfiles.SCALER_EXTRA:
		_check(PixelScalerScript.factor_for(e[0]) == int(e[1]), "PixelScaler: %s dá ×%d" % [e[0], e[1]])
	_check(PixelScalerScript.factor_for(Vector2i(10, 10)) == 1, "PixelScaler: nunca abaixo de ×1")
	_check(PixelScalerScript.window_size_for("portrait", Vector2i(1920, 1040)) == Vector2i(540, 960),
			"Janela tate: 540x960 num 1080p")
	_check(PixelScalerScript.window_size_for("landscape", Vector2i(1920, 1040)) == Vector2i(1440, 810),
			"Janela deitada: 1440x810 num 1080p")
	_check(PixelScalerScript.window_size_for("portrait", Vector2i(100, 100)) == Vector2i(270, 480),
			"Janela: nunca abaixo de x1")


## Área de jogo: 270x450 inteira na área segura, alinhada ao pixel, HUD cobrindo no máximo 6%.
func _test_playfield() -> void:
	for c: Dictionary in DeviceProfiles.layout_cases():
		var view: Vector2 = c["view"]
		var safe := DeviceProfiles.safe_rect(view, c["insets"])
		var result := Playfield.layout(view, safe)
		var field: Rect2 = result["field"]
		var tag := "Campo [%s]" % c["label"]
		_check(field.size == Playfield.FIELD, "%s: tamanho %s" % [tag, field.size])
		_check(Playfield.fits(result, safe), "%s: %s dentro da área segura %s" % [tag, field, safe])
		_check(field.position == field.position.floor(), "%s: alinhado ao pixel %s" % [tag, field.position])
		_check(Playfield.hud_coverage(result) <= 0.06,
				"%s: HUD cobre %.1f%% do campo" % [tag, Playfield.hud_coverage(result) * 100.0])
		var hud: Rect2 = result["hud"]
		_check(safe.grow(0.01).encloses(hud), "%s: HUD %s na área segura" % [tag, hud])
		if not bool(result["hud_overlay"]):
			_check(not hud.intersects(field), "%s: HUD fora do campo" % tag)
		var thumb: Rect2 = result["thumb"]
		_check(thumb.size.y == 0.0 or safe.grow(0.01).encloses(thumb), "%s: zona do polegar na área segura" % tag)
	var tall := Playfield.layout(Vector2(270, 660), Rect2(0, 29.5, 270, 630.5))
	_check(bool(tall["thumb_separate"]), "Campo: tela 22:9 tem zona do polegar separada")
	var short := Playfield.layout(Vector2(270, 480), Rect2(0, 29.5, 270, 450.5))
	_check(bool(short["hud_overlay"]), "Campo: tela 9:16 com recorte põe o HUD sobre o campo")
	var desk := Playfield.layout(Vector2(960, 540), Rect2(0, 0, 960, 540))
	_check((desk["field"] as Rect2).position == Vector2(345, 45), "Campo: centralizado em 960x540")


func _test_spatial_hash() -> void:
	var grid := SpatialHash.new(24.0)
	grid.insert(1, Vector2(10.0, 10.0))
	grid.insert(2, Vector2(100.0, 100.0))
	grid.insert(3, Vector2(-30.0, 5.0))
	var found: Array[int] = []
	grid.query(Vector2.ZERO, 20.0, found)
	_check(found.has(1), "SpatialHash: acha o vizinho próximo")
	_check(not found.has(2), "SpatialHash: não acha o distante")
	grid.query(Vector2(-25.0, 0.0), 10.0, found)
	_check(found.has(3), "SpatialHash: coordenadas negativas")
	grid.clear()
	grid.query(Vector2.ZERO, 20.0, found)
	_check(found.is_empty(), "SpatialHash: clear esvazia a grade")
	var points := PackedVector2Array([Vector2(1, 1), Vector2(2, 2), Vector2(500, 500)])
	var alive := PackedByteArray([1, 0, 1])
	grid.rebuild(points, alive, 3)
	grid.query(Vector2.ZERO, 10.0, found)
	_check(found == [0], "SpatialHash: rebuild ignora os mortos (%s)" % [found])


func _test_frame_stats() -> void:
	var us := PackedInt64Array([16000, 16000, 17000, 40000])
	var s := FrameStats.summarize(us)
	_check(int(s["frames"]) == 4 and int(s["over_33"]) == 1, "FrameStats: conta quadros longos")
	_check(is_equal_approx(float(s["max_ms"]), 40.0), "FrameStats: pior quadro")
	var sorted := PackedInt64Array([1, 2, 3, 4, 5, 6, 7, 8, 9, 10])
	_check(FrameStats.percentile(sorted, 0.95) == 10.0, "FrameStats: p95 pelo posto mais próximo")
	var stalls := FrameStats.scroll_stalls(PackedInt64Array([16000, 16000, 16000, 16000]),
			PackedFloat32Array([0, 10, 10, 20, 30]))
	_check(stalls == 1, "FrameStats: travada no meio do movimento (%d)" % stalls)


func _test_frame_pacing() -> void:
	_check(FramePacing.max_fps_for(60, 60.0, true) == 0, "FramePacing: 60 em tela de 60 Hz deixa o VSync mandar")
	_check(FramePacing.max_fps_for(60, 120.0, true) == 60, "FramePacing: 60 em tela de 120 Hz limita")
	_check(FramePacing.max_fps_for(60, 60.0, false) == 60, "FramePacing: desktop usa a opção")


func _test_gfx_quality() -> void:
	_check(GfxQuality.resolve("low", GfxQuality.HIGH) == GfxQuality.LOW, "GfxQuality: opção manda")
	_check(GfxQuality.resolve("auto", GfxQuality.HIGH, 1) == GfxQuality.MEDIUM, "GfxQuality: auto rebaixado")
	_check(GfxQuality.classify(false, 4, 0, "") == GfxQuality.HIGH, "GfxQuality: desktop é Alta")
	_check(GfxQuality.classify(true, 8, 2 * 1024 * 1024 * 1024, "Mali-G52") == GfxQuality.MEDIUM,
			"GfxQuality: celular de entrada é Média")
	for key: String in GfxQuality.BUDGETS:
		_check((GfxQuality.BUDGETS[key] as Array).size() == 3, "GfxQuality: %s tem 3 níveis" % key)
	_check(int(GfxQuality.budget_at("parallax_layers", GfxQuality.HIGH)) == 7, "GfxQuality: 7 camadas na Alta")


func _test_languages() -> void:
	_check(Languages.SUPPORTED.size() == 11, "Idiomas: 11")
	for lang: String in Languages.INSET_LANGS:
		_check(lang in Languages.SUPPORTED, "Idiomas: %s dos casos com recorte é suportado" % lang)
	for lang: String in Languages.SUPPORTED:
		_check(Languages.NATIVE_NAMES.has(lang), "Idiomas: nome nativo de %s" % lang)


## SemVer (docs/policies/versionamento.md): a mesma versão em todos os lugares.
func _test_version() -> void:
	var version := String(ProjectSettings.get_setting("application/config/version"))
	var semver := RegEx.create_from_string(SEMVER)
	_check(semver.search(version) != null, "Versão: '%s' é SemVer" % version)
	var presets := ConfigFile.new()
	_check(presets.load("res://export_presets.cfg") == OK, "Versão: export_presets.cfg carrega")
	var platforms: Dictionary = {}
	for section: String in presets.get_sections():
		if not section.begins_with("preset.") or section.ends_with(".options"):
			continue
		var platform := String(presets.get_value(section, "platform"))
		platforms[platform] = true
		var options := section + ".options"
		match platform:
			"Android":
				_check(String(presets.get_value(options, "version/name")) == version,
						"Versão: %s version/name = %s" % [section, version])
				_check(int(presets.get_value(options, "version/code", 0)) >= 1, "Versão: %s version/code ≥ 1" % section)
			"Windows Desktop":
				for key: String in ["application/file_version", "application/product_version"]:
					_check(String(presets.get_value(options, key)) == version + ".0",
							"Versão: %s %s = %s.0" % [section, key, version])
			"Linux":
				_check(String(presets.get_value(section, "export_path")).contains(version),
						"Versão: %s export_path leva %s" % [section, version])
	for platform: String in ["Android", "Windows Desktop", "Linux"]:
		_check(platforms.has(platform), "Versão: preset %s existe" % platform)
