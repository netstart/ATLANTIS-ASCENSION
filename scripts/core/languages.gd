class_name Languages
extends RefCounted
## Idiomas do jogo (plano mestre 7.6). Fica fora do autoload Locale para os testes sem autoloads
## (tests/run_tests.gd) e o tests/device_profiles.gd poderem ler a lista.

const SUPPORTED: Array[String] = ["pt_BR", "en", "es", "de", "fr", "ru", "id", "ja", "ko", "zh_TW", "zh_CN"]
## Idiomas dos casos de layout com recorte da câmera (os mais longos e o de origem).
const INSET_LANGS: Array[String] = ["pt_BR", "de", "ru"]
const NATIVE_NAMES := {
	"pt_BR": "Português (Brasil)", "en": "English", "es": "Español", "de": "Deutsch",
	"fr": "Français", "ru": "Русский", "id": "Bahasa Indonesia", "ja": "日本語",
	"ko": "한국어", "zh_TW": "繁體中文", "zh_CN": "简体中文",
}
