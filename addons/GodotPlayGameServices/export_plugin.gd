@tool
extends EditorPlugin

const PLUGIN_AUTOLOAD := &"GodotPlayGameServices"

var _export_plugin: AndroidExportPlugin

func _enter_tree() -> void:
	_add_plugin()
	_add_autoloads()

func _exit_tree() -> void:
	_remove_plugin()
	_remove_autoloads()

func _add_plugin() -> void:
	_export_plugin = AndroidExportPlugin.new()
	add_export_plugin(_export_plugin)

func _remove_plugin() -> void:
	remove_export_plugin(_export_plugin)
	_export_plugin = null

func _add_autoloads() -> void:
	add_autoload_singleton(PLUGIN_AUTOLOAD, "res://addons/GodotPlayGameServices/scripts/autoloads/godot_play_game_services.gd")

func _remove_autoloads() -> void:
	remove_autoload_singleton(PLUGIN_AUTOLOAD)

class AndroidExportPlugin extends EditorExportPlugin:
	var _plugin_name = &"GodotPlayGameServices"

	func _supports_platform(platform):
		if platform is EditorExportPlatformAndroid:
			return true
		return false


	## Atlantis Ascension: o ID do jogo vem de project.godot ([play_games] game_id), junto do ID do placar.
	## Sem ID nada do Play Games entra no build (nem AAR, nem dependência, nem manifest): o SDK v2 liga
	## sozinho pelo APP_ID do manifest e derrubaria o app sem ele.
	func _game_id() -> String:
		return str(ProjectSettings.get_setting("play_games/game_id", "")).strip_edges()

	func _export_begin(features: PackedStringArray, is_debug: bool, path: String, flags: int) -> void:
		var id := _game_id()
		if id == "":
			print("[{plugin_name}] play_games/game_id vazio em project.godot: build sem Play Games.".format({"plugin_name": _plugin_name}))
			return

		var res_dir_path = "android/build/dataLib/src/main/res/" if Engine.get_version_info().hex >= 0x040800 else "android/build/res/"
		var file := FileAccess.open(res_dir_path + "values/strings.xml", FileAccess.WRITE)
		file.store_string("<?xml version=\"1.0\" encoding=\"utf-8\"?><resources><string translatable=\"false\" name=\"game_services_project_id\">%s</string></resources>" % id)

		print("[{plugin_name}] added game-id {id} to [values/strings.xml]".format({"plugin_name": _plugin_name, "id": id}))

	func _get_android_libraries(platform, debug):
		if _game_id() == "":
			return PackedStringArray()
		if debug:
			return PackedStringArray([_plugin_name + "/bin/debug/" + _plugin_name + "-debug.aar"])
		else:
			return PackedStringArray([_plugin_name + "/bin/release/" + _plugin_name + "-release.aar"])

	func _get_android_dependencies(platform: EditorExportPlatform, debug: bool) -> PackedStringArray:
		if not _supports_platform(platform) or _game_id() == "":
			return PackedStringArray()

		return PackedStringArray([
			"com.google.code.gson:gson:2.11.0",
			"com.google.android.gms:play-services-games-v2:21.0.0"
			])

	func _get_android_manifest_application_element_contents(platform: EditorExportPlatform, debug: bool) -> String:
		if not _supports_platform(platform) or _game_id() == "":
			return ""

		return "<meta-data android:name=\"com.google.android.gms.games.APP_ID\" android:value=\"@string/game_services_project_id\"/>"

	func _get_name():
		return _plugin_name
