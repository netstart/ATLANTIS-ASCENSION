extends Node
## Idiomas (plano mestre 7.6): lê i18n/strings.csv em tempo de execução e registra uma Translation por
## idioma no TranslationServer. A fonte da interface é a Exo 2 (variável, latino e cirílico), com a
## variante regional da Fusion Pixel Font como reserva, porque os ideogramas têm desenho diferente em
## ja/ko/zh.
##
## Origem: locale.gd do projeto hyakki (mesmo autor, MIT).

signal language_changed(code: String)

const CSV_PATH := "res://i18n/strings.csv"
const FONT_FILES := {
	"ja": "res://assets/fonts/fusion_pixel_12_ja.woff2",
	"ko": "res://assets/fonts/fusion_pixel_12_ko.woff2",
	"zh_TW": "res://assets/fonts/fusion_pixel_12_zh_tw.woff2",
	"zh_CN": "res://assets/fonts/fusion_pixel_12_zh_hans.woff2",
}
const DEFAULT_FONT := "res://assets/fonts/fusion_pixel_12_latin.woff2"
const UI_FONT := "res://assets/fonts/exo2_variable.ttf"
## Pesos da Exo 2 (eixo wght): texto corrido e títulos.
const WEIGHT_BODY := 560
const WEIGHT_BOLD := 800

var current: String = "en"
var font: Font
## Mesma família em peso de título (botões principais, cabeçalhos, números grandes).
var font_bold: Font
var keys: PackedStringArray = []
## Texto por idioma: {"en": {chave: texto}}, usado pelos testes de cobertura.
var table: Dictionary = {}

var _translations: Dictionary = {}
var _fonts: Dictionary = {}


func _ready() -> void:
	_load_csv()
	var chosen := String(Settings.get_value("language"))
	if chosen.is_empty() or not Languages.SUPPORTED.has(chosen):
		chosen = detect_system_language()
	set_language(chosen, false)


## Primeira abertura: usa o idioma do aparelho; sem suporte, inglês.
func detect_system_language() -> String:
	return language_for(OS.get_locale())


## Regra pura da detecção (testável): "pt_PT" → "pt_BR", "zh_HK" → "zh_TW", "xx" → "en".
static func language_for(system: String) -> String:
	if Languages.SUPPORTED.has(system):
		return system
	var lang := system.get_slice("_", 0).get_slice("-", 0)
	if lang == "pt":
		return "pt_BR"
	if lang == "zh":
		var traditional := system.contains("TW") or system.contains("HK") or system.contains("Hant")
		return "zh_TW" if traditional else "zh_CN"
	if Languages.SUPPORTED.has(lang):
		return lang
	return "en"


func set_language(code: String, persist: bool = true) -> void:
	if not Languages.SUPPORTED.has(code):
		code = "en"
	current = code
	TranslationServer.set_locale(code)
	font = font_for(code)
	font_bold = font_for(code, true)
	if persist:
		Settings.set_value("language", code)
	language_changed.emit(code)


func text(key: String, lang: String = "") -> String:
	var lang_table: Dictionary = table.get(lang if not lang.is_empty() else current, {})
	return String(lang_table.get(key, key))


## Formata números com o separador de milhar do idioma.
func format_number(value: int) -> String:
	return group_digits(value, current)


static func group_digits(value: int, lang: String) -> String:
	var digits := str(absi(value))
	var sep := ","
	match lang:
		"pt_BR", "es", "de", "id":
			sep = "."
		"fr", "ru":
			sep = " "
	var out := ""
	var count := 0
	for i: int in range(digits.length() - 1, -1, -1):
		out = digits[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = sep + out
	return ("-" if value < 0 else "") + out


func font_for(code: String, bold: bool = false) -> Font:
	var key := "%s:%s" % [code, bold]
	if _fonts.has(key):
		return _fonts[key]
	var variation := FontVariation.new()
	var exo := _load_font(UI_FONT, false)
	var pixel := _load_font(FONT_FILES.get(code, DEFAULT_FONT), true)
	if exo == null:
		variation.base_font = pixel if pixel != null else ThemeDB.fallback_font
	else:
		variation.base_font = exo
		variation.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"):
				WEIGHT_BOLD if bold else WEIGHT_BODY}
		if pixel != null:
			variation.fallbacks = [pixel]
	_fonts[key] = variation
	return variation


## Fonte importada (no APK só existe a importada, não o arquivo bruto). Pixel: sem suavização.
func _load_font(path: String, pixel: bool) -> FontFile:
	if _fonts.has(path):
		return _fonts[path]
	var file := load(path) as FontFile
	if file == null:
		Log.error("Locale: fonte não carregou: " + path)
		return null
	if pixel:
		file.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		file.hinting = TextServer.HINTING_NONE
		file.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	else:
		file.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
		file.hinting = TextServer.HINTING_LIGHT
	file.generate_mipmaps = false
	_fonts[path] = file
	return file


func _load_csv() -> void:
	var file := FileAccess.open(CSV_PATH, FileAccess.READ)
	if file == null:
		Log.error("Locale: não abriu " + CSV_PATH)
		return
	var header := file.get_csv_line()
	var columns: Dictionary = {}
	for i: int in range(header.size()):
		columns[header[i]] = i
	for code: String in Languages.SUPPORTED:
		var translation := Translation.new()
		translation.locale = code
		_translations[code] = translation
		table[code] = {}
	while not file.eof_reached():
		var line := file.get_csv_line()
		if line.size() < 2 or line[0].is_empty() or line[0].begins_with("#"):
			continue
		var key := line[0]
		keys.append(key)
		for code: String in Languages.SUPPORTED:
			var index: int = columns.get(code, -1)
			var value := ""
			if index >= 0 and index < line.size():
				value = line[index]
			if value.is_empty() and columns.has("en") and int(columns["en"]) < line.size():
				value = line[int(columns["en"])]
			value = value.replace("\\n", "\n")
			(_translations[code] as Translation).add_message(key, value)
			(table[code] as Dictionary)[key] = value
	for code: String in Languages.SUPPORTED:
		TranslationServer.add_translation(_translations[code])
