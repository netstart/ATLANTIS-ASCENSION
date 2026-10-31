extends Node
## Áudio do jogo (plano mestre 9): buses, música com troca suave, pool de efeitos com limite por som
## e ducking. Os efeitos e músicas vêm de res://assets/audio (ainda vazios na Fase 0: tocar um id sem
## arquivo é ignorado em silêncio e contado em `missing`).
##
## Buses: Master → Music, SFX, UI. Volumes de Settings (linear 0..1).

const MUSIC_DIR := "res://assets/audio/music/"
const SFX_DIR := "res://assets/audio/sfx/"
const EXTENSIONS: Array[String] = ["ogg", "wav", "mp3"]
const BUSES: Array[String] = ["Music", "SFX", "UI"]
const POOL_SIZE := 24
const MAX_PER_SOUND := 4
const SOUND_COOLDOWN_MS := 30
const CROSSFADE := 1.2
const SILENT_DB := -40.0

## Ids pedidos sem arquivo (diagnóstico e testes).
var missing: Dictionary = {}

var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _active_music: AudioStreamPlayer
var _music_id: String = ""
var _pool: Array[AudioStreamPlayer] = []
var _playing: Dictionary = {}
var _last_play_ms: Dictionary = {}
var _streams: Dictionary = {}
var _duck_tween: Tween
var _fade_tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_buses()
	_music_a = _make_player("Music")
	_music_b = _make_player("Music")
	_active_music = _music_a
	for i: int in range(POOL_SIZE):
		_pool.append(_make_player("SFX"))
	apply_volumes()
	Settings.changed.connect(func(key: String) -> void:
		if key.ends_with("_volume"):
			apply_volumes())


func _setup_buses() -> void:
	for bus: String in BUSES:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			var index := AudioServer.bus_count - 1
			AudioServer.set_bus_name(index, bus)
			AudioServer.set_bus_send(index, "Master")


func _make_player(bus: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.bus = bus
	add_child(player)
	return player


func apply_volumes() -> void:
	_set_bus_volume("Music", float(Settings.get_value("music_volume")))
	_set_bus_volume("SFX", float(Settings.get_value("sfx_volume")))
	_set_bus_volume("UI", float(Settings.get_value("ui_volume")))


func _set_bus_volume(bus: String, linear: float) -> void:
	var index := AudioServer.get_bus_index(bus)
	if index < 0:
		return
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(linear, 0.0001)))
	AudioServer.set_bus_mute(index, linear <= 0.001)


## Troca a música com crossfade. Mesmo id: não reinicia.
func play_music(id: String, fade: float = CROSSFADE) -> bool:
	if id == _music_id:
		return true
	var stream := _stream(MUSIC_DIR, id)
	if stream == null:
		return false
	_music_id = id
	var old := _active_music
	var fresh := _music_b if old == _music_a else _music_a
	fresh.stream = stream
	fresh.volume_db = SILENT_DB
	fresh.play()
	_active_music = fresh
	if _fade_tween != null:
		_fade_tween.kill()
	_fade_tween = create_tween().set_parallel()
	_fade_tween.tween_property(fresh, "volume_db", 0.0, fade)
	_fade_tween.tween_property(old, "volume_db", SILENT_DB, fade)
	_fade_tween.chain().tween_callback(old.stop)
	return true


func stop_music(fade: float = 1.0) -> void:
	_music_id = ""
	var player := _active_music
	if _fade_tween != null:
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property(player, "volume_db", SILENT_DB, fade)
	_fade_tween.tween_callback(player.stop)


func music_id() -> String:
	return _music_id


## Toca um efeito. Devolve false se o arquivo não existe, o som passou do limite ou está em recarga.
func play(id: String, pitch: float = 1.0, pitch_jitter: float = 0.0, volume_db: float = 0.0,
		bus: String = "SFX") -> bool:
	var now := Time.get_ticks_msec()
	if now - int(_last_play_ms.get(id, -100000)) < SOUND_COOLDOWN_MS:
		return false
	if int(_playing.get(id, 0)) >= MAX_PER_SOUND:
		return false
	var stream := _stream(SFX_DIR, id)
	if stream == null:
		return false
	var player := _free_player()
	if player == null:
		return false
	_last_play_ms[id] = now
	player.stream = stream
	player.bus = bus
	player.volume_db = volume_db
	player.pitch_scale = pitch + randf_range(-pitch_jitter, pitch_jitter)
	player.play()
	_playing[id] = int(_playing.get(id, 0)) + 1
	player.finished.connect(func() -> void: _playing[id] = maxi(0, int(_playing.get(id, 1)) - 1),
			CONNECT_ONE_SHOT)
	return true


func play_ui(id: String) -> bool:
	return play(id, 1.0, 0.0, 0.0, "UI")


## Abaixa a música por `seconds` (falas, alertas de chefe).
func duck(db: float, seconds: float) -> void:
	if _duck_tween != null:
		_duck_tween.kill()
	var index := AudioServer.get_bus_index("Music")
	var base := linear_to_db(maxf(float(Settings.get_value("music_volume")), 0.0001))
	AudioServer.set_bus_volume_db(index, base + db)
	_duck_tween = create_tween()
	_duck_tween.tween_interval(seconds)
	_duck_tween.tween_callback(apply_volumes)


func _free_player() -> AudioStreamPlayer:
	for player: AudioStreamPlayer in _pool:
		if not player.playing:
			return player
	return null


## Trilhas de fase e de menu tocam em laço (o import padrão do Godot não repete); vinhetas não.
static func _make_loop(stream: AudioStream) -> void:
	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	elif stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	elif stream is AudioStreamWAV:
		var wav := stream as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = int(wav.get_length() * wav.mix_rate)


func _stream(dir: String, id: String) -> AudioStream:
	var key := dir + id
	if _streams.has(key):
		return _streams[key]
	for ext: String in EXTENSIONS:
		var file_path := "%s%s.%s" % [dir, id, ext]
		if ResourceLoader.exists(file_path):
			var stream := load(file_path) as AudioStream
			if dir == MUSIC_DIR and not id.begins_with("kenney_jingle"):
				_make_loop(stream)
			_streams[key] = stream
			return stream
	missing[id] = int(missing.get(id, 0)) + 1
	return null
