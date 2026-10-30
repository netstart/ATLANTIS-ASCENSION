extends Node
## Idiomas (plano mestre 7.6): lê i18n/strings.csv em tempo de execução e registra uma Translation por
## idioma no TranslationServer. Também escolhe a variante regional da Fusion Pixel Font, porque os
## ideogramas têm desenho diferente em ja/ko/zh.
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

var current: String = "en"
var font: Font
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


func font_for(code: String) -> Font:
	var font_path: String = FONT_FILES.get(code, DEFAULT_FONT)
	if _fonts.has(font_path):
		return _fonts[font_path]
	# Pelo ResourceLoader: no APK só existe a fonte importada, não o .woff2 bruto.
	var file := load(font_path) as FontFile
	if file == null:
		Log.error("Locale: fonte não carregou: " + font_path)
		return ThemeDB.fallback_font
	file.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	file.hinting = TextServer.HINTING_NONE
	file.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	file.generate_mipmaps = false
	_fonts[font_path] = file
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
