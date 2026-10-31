class_name Game
extends Node2D
## Uma missão em andamento (plano mestre 10.3): liga a entrada (dedo, teclado, controle ou bot), a
## Sim em passo fixo (GameClock), o desenho (cenário, mundo, HUD), o áudio e a vibração.
##
## Linha de comando (testes, depois de "--"): --bot, --seed=N, --speed=N, --quit-at=S (segundos de
## jogo; imprime "FIM ... hash=..." e sai), --stress=N (mantém N balas inimigas vivas), --mission=id.

signal finished(result: Dictionary)

const FINISH_DELAY := 1.6
const DOUBLE_TAP_MS := 280
const SHAKE_DECAY := 18.0

var sim := Sim.new()
var mission_id: StringName = &"c1m1"
## Missão montada em tempo de execução (modos); vazia = ler data/stages/<mission_id>.json.
var mission_data: Dictionary = {}
## O jogador ainda pode reviver nesta missão (campanha e sobrevivência; desligado nos testes do bot).
var can_revive: bool = false
## Carga do hangar (Economy.loadout) ou só o id da aeronave.
var loadout: Variant = &"falcon"
var seed_value: int = 7
var use_bot: bool = false
var quit_at: float = -1.0
var stress: int = 0
var paused: bool = false

var _bot: BotPilot
var _backdrop: OceanBackdrop
var _clip: Control
var _world: WorldView
var _layer: CanvasLayer
var _hud: GameHud
var _drag := Vector2.ZERO
var _taps: int = 0
var _want_special: bool = false
var _want_bomb: bool = false
var _want_tide: bool = false
var _choice: int = -1
var _touch_ids: Dictionary = {}
var _last_tap_ms: int = -10000
var _shake: float = 0.0
var _emerge: float = 0.0
var _emerge_from: float = 0.0
var _emerge_to: float = 0.0
var _emerge_t: float = 1.0
var _emerge_duration: float = 1.0
var _done: float = -1.0
var _reported: bool = false


## Configura antes de entrar na árvore.
func configure(p_mission: Variant, p_loadout: Variant, p_seed: int, bot: bool) -> void:
	if typeof(p_mission) == TYPE_DICTIONARY:
		mission_data = p_mission
		mission_id = StringName(String(mission_data.get("id", "")))
	else:
		mission_id = StringName(String(p_mission))
	loadout = p_loadout
	seed_value = p_seed
	use_bot = bot


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--quit-at="):
			quit_at = float(arg.trim_prefix("--quit-at="))
		elif arg.begins_with("--stress="):
			stress = int(arg.trim_prefix("--stress="))
	sim.setup(mission_data if not mission_data.is_empty() else Sim.load_mission(mission_id), Sim.load_tables(),
			loadout, seed_value,
			float(Settings.get_value("drag_sensitivity")))
	if use_bot:
		_bot = BotPilot.new()
	_backdrop = OceanBackdrop.new()
	_backdrop.detail = GfxQuality.level()
	_backdrop.kind = StringName(String(sim.mission.get("backdrop", "ocean")))
	add_child(_backdrop)
	_clip = Control.new()
	_clip.clip_contents = true
	_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_clip)
	_world = WorldView.new()
	_world.reduce_flashes = bool(Settings.get_value("reduce_flashes"))
	_world.colorblind = String(Settings.get_value("colorblind"))
	_world.fx_level = GfxQuality.level()
	_world.setup(sim)
	_clip.add_child(_world)
	_layer = CanvasLayer.new()
	add_child(_layer)
	_hud = GameHud.new()
	_hud.theme = UiTheme.build(Locale.font)
	_layer.add_child(_hud)
	_hud.pause_pressed.connect(func() -> void: set_paused(true))
	_hud.resume_pressed.connect(func() -> void: set_paused(false))
	_hud.restart_pressed.connect(_restart)
	_hud.quit_pressed.connect(func() -> void: _finish(true))
	_hud.special_pressed.connect(func() -> void: _want_special = true)
	_hud.bomb_pressed.connect(func() -> void: _want_bomb = true)
	_hud.tide_pressed.connect(func() -> void: _want_tide = true)
	_hud.revive_chosen.connect(_on_revive_choice)
	_hud.blessing_chosen.connect(func(index: int) -> void: _choice = index)
	_hud.setup_mission(sim)
	get_viewport().size_changed.connect(relayout)
	MenuKit.on_insets_change(self, relayout)
	relayout.call_deferred()
	GameClock.reset()
	GameClock.ticked.connect(_on_tick)
	AudioManager.play_music(String(sim.mission.get("music", "")))


func _exit_tree() -> void:
	if GameClock.ticked.is_connected(_on_tick):
		GameClock.ticked.disconnect(_on_tick)
	GameClock.paused = true


func relayout() -> void:
	relayout_for(get_viewport().get_visible_rect().size)


## Layout para uma tela lógica (os testes simulam cada aparelho com isto).
func relayout_for(view: Vector2) -> void:
	var safe := MenuKit.safe_rect(view, MenuKit.safe_margins(_hud))
	var layout := Playfield.layout(view, safe)
	var field: Rect2 = layout["field"]
	_backdrop.set_view(view)
	_clip.position = field.position
	_clip.size = field.size
	_hud.size = view
	_hud.apply_layout(layout, safe)


## Raiz do HUD (testes de layout).
func hud() -> GameHud:
	return _hud


func set_paused(value: bool) -> void:
	if sim.finished:
		return
	paused = value
	GameClock.paused = value
	_hud.set_paused(value)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and not use_bot and not sim.finished:
		set_paused(true)


# --- Entrada ---------------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		set_paused(not paused)
		get_viewport().set_input_as_handled()
		return
	if paused:
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_touch_ids[touch.index] = true
			_taps += 1
			var now := Time.get_ticks_msec()
			var dueling := sim.boss != null and sim.boss.state == SimBoss.State.DUEL
			# Toque duplo = bomba (menos no duelo, onde tocar rápido é a mecânica).
			if now - _last_tap_ms < DOUBLE_TAP_MS and not dueling:
				_want_bomb = true
			_last_tap_ms = now
		else:
			_touch_ids.erase(touch.index)
	elif event is InputEventScreenDrag:
		_drag += (event as InputEventScreenDrag).relative
	elif event.is_action_pressed("special"):
		_want_special = true
	elif event.is_action_pressed("bomb"):
		_want_bomb = true
	elif event.is_action_pressed("tide"):
		_want_tide = true
	elif event.is_action_pressed("fire"):
		_taps += 1


func _human_input() -> SimInput:
	var input := SimInput.new()
	input.move = _drag
	_drag = Vector2.ZERO
	input.axis = Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	input.precise = Input.is_action_pressed(&"precise") or _touch_ids.size() >= 2
	input.fire = bool(Settings.get_value("auto_fire")) or Input.is_action_pressed(&"fire") or not _touch_ids.is_empty()
	input.special = _want_special
	input.bomb = _want_bomb
	input.tide = _want_tide
	input.taps = _taps
	input.choice = _choice
	_want_special = false
	_want_bomb = false
	_want_tide = false
	_choice = -1
	_taps = 0
	return input


func _on_tick(_dt: float) -> void:
	if paused or sim.finished:
		return
	var input := _bot.decide(sim) if _bot != null else _human_input()
	if stress > 0:
		_stress()
	sim.step(input)


## Estresse (benchmark): mantém `stress` balas inimigas vivas, em anéis lentos do topo.
func _stress() -> void:
	var missing := stress - sim.enemy_bullets.count
	var k := 0
	while missing > 0 and k < 64:
		var a := float((sim.frame * 7 + k * 13) % 360)
		sim.fire_enemy(Vector2(135, 40), a, 30.0 + float(k % 5) * 6.0, k % BulletKinds.ENEMY.size(), 0.0, 0.0)
		missing -= 1
		k += 1


# --- Quadro ------------------------------------------------------------------------------------

func _process(delta: float) -> void:
	for ev: Dictionary in sim.take_events():
		_on_event(ev)
	if _emerge_t < 1.0:
		_emerge_t = minf(1.0, _emerge_t + delta / maxf(0.01, _emerge_duration))
		var u := _emerge_t * _emerge_t * (3.0 - 2.0 * _emerge_t)
		_emerge = lerpf(_emerge_from, _emerge_to, u)
	_shake = maxf(0.0, _shake - SHAKE_DECAY * delta)
	var amount := _shake * float(Settings.get_value("screen_shake")) * float(GfxQuality.budget("screen_shake"))
	var jitter := Vector2(sin(Time.get_ticks_msec() * 0.09), cos(Time.get_ticks_msec() * 0.11)) * amount
	_world.position = jitter.round()
	_world.touching = not _touch_ids.is_empty() or Input.is_action_pressed(&"precise")
	_backdrop.apply(sim.scroll, _emerge, Vector2.ZERO, bool(Settings.get_value("reduce_motion")))
	_backdrop.set_drift(sim.gravity if sim.drift_frames > 0 else Vector2.ZERO)
	_world.refresh(delta)
	_hud.refresh(sim, delta)
	if quit_at > 0.0 and sim.frame >= int(quit_at * 60.0):
		_report_and_quit()
	if sim.finished:
		if use_bot and quit_at > 0.0:
			_report_and_quit()
		if can_revive and not sim.cleared and not use_bot:
			can_revive = false
			_hud.show_revive()
			return
		if _hud.revive_visible():
			return
		if _done < 0.0:
			_done = FINISH_DELAY
		_done -= delta
		if _done <= 0.0:
			_finish(false)


func _on_event(ev: Dictionary) -> void:
	_world.on_event(ev)
	match StringName(ev["type"]):
		&"shot":
			AudioManager.play("kenney_shot_pulsar", 1.0, 0.05, -14.0)
		&"kill":
			AudioManager.play("kenney_explosion_medium" if bool(ev.get("big", false)) else "kenney_explosion_small",
					1.0, 0.08, -6.0)
			_shake = maxf(_shake, 3.0 if bool(ev.get("big", false)) else 0.0)
		&"hit":
			AudioManager.play("kenney_hit", 1.0, 0.1, -16.0)
		&"graze":
			AudioManager.play("kenney_graze", 1.0, 0.05, -12.0)
		&"orb":
			AudioManager.play("kenney_weapon_up" if bool(ev.get("up", false)) else "kenney_orb")
		&"medal":
			AudioManager.play("kenney_medal", 1.0 + minf(0.6, float(ev.get("value", 100)) / 20000.0))
		&"pearl":
			AudioManager.play("kenney_pearl", 1.0, 0.1, -10.0)
		&"player_hit":
			AudioManager.play("kenney_player_hit")
			Settings.vibrate(80)
			_shake = 7.0
		&"bomb", &"special":
			AudioManager.play("kenney_bomb")
			Settings.vibrate(50)
			_shake = 6.0
		&"beam_warn":
			AudioManager.play("kenney_beam_warn", 1.0, 0.0, -6.0)
		&"boss_intro":
			AudioManager.play("kenney_boss_alert")
			_hud.show_banner(tr(String(ev.get("name_key", ""))))
			if bool(ev.get("final", false)):
				var boss_def: Dictionary = (sim.tables["bosses"] as Dictionary).get(StringName(ev["id"]), {})
				AudioManager.play_music(String(boss_def.get("music", "")))
		&"boss_phase":
			if not String(ev.get("dialogue", "")).is_empty():
				_hud.show_radio(String(ev["dialogue"]))
		&"boss_part":
			AudioManager.play("kenney_explosion_medium")
			_shake = maxf(_shake, 4.0)
		&"duel_start":
			AudioManager.play("kenney_beam")
			_hud.show_banner(tr("hud.duel"))
		&"boss_dead":
			AudioManager.play("kenney_explosion_big")
			Settings.vibrate(150)
			_shake = 10.0
			if bool(ev.get("final", false)):
				AudioManager.play_music("kenney_jingle_victory", 0.3)
		&"dialogue":
			_hud.show_radio(String(ev.get("id", "")))
		&"blessing_offer":
			AudioManager.play("kenney_weapon_up", 0.8)
			_hud.show_offer(sim)
		&"blessing":
			AudioManager.play("kenney_ui_confirm")
			_hud.hide_offer()
			var def: Dictionary = (sim.tables["blessings"] as Dictionary).get(StringName(ev["id"]), {})
			_hud.show_banner(tr(String(def.get("name_key", ""))))
			if not String(ev.get("synergy", "")).is_empty():
				_hud.show_radio_text(tr("hud.synergy") % tr("deity." + String(ev["synergy"])), UiTheme.GOLD)
		&"tide":
			AudioManager.play("kenney_ocean_shift", 1.3)
			Settings.vibrate(60)
			_shake = 5.0
			_hud.show_banner(tr("hud.tide"))
		&"current", &"wind":
			AudioManager.play("kenney_ocean_shift", 0.7, 0.0, -8.0)
			_hud.show_banner(tr("hud." + String(ev["type"])))
		&"log":
			AudioManager.play("kenney_medal", 0.8)
			_hud.show_radio_text(tr("hud.log_found"), UiTheme.CYAN)
		&"glyph":
			AudioManager.play("kenney_orb", 0.7 + 0.15 * float(ev.get("index", 0)))
			_hud.show_radio_text(tr("hud.glyph") % [int(ev["index"]) + 1, int(ev["of"])], UiTheme.GOLD)
		&"glyph_reset":
			AudioManager.play("kenney_hit", 0.6)
			_hud.show_radio_text(tr("hud.glyph_reset"), UiTheme.CORAL)
		&"secret":
			AudioManager.play("kenney_jingle_victory")
			_hud.show_banner(tr("hud.secret"))
		&"gravity_breach":
			AudioManager.play("kenney_ocean_shift", 0.6, 0.0, -4.0)
			_hud.show_banner(tr("hud.gravity_breach"))
		&"capsule":
			AudioManager.play("kenney_medal", 1.0 + 0.08 * float(ev.get("combo", 1)))
			if int(ev.get("combo", 1)) >= 2:
				_hud.show_radio_text(tr("hud.capsule_combo") % int(ev["combo"]), UiTheme.GOLD)
		&"cover":
			AudioManager.play("kenney_ocean_shift", 1.4, 0.0, -10.0)
		&"boss_remember":
			_hud.show_radio_text(tr("hud.boss_remember"), UiTheme.CORAL)
		&"boss_learn":
			_hud.show_radio_text(tr("hud.boss_learn"), UiTheme.CORAL)
		&"ocean_shift":
			AudioManager.play("kenney_ocean_shift")
			_emerge_from = _emerge
			_emerge_to = 0.0 if String(ev.get("to", "")) == "flood" else 1.0
			_emerge_duration = float(ev.get("duration", 8.0))
			_emerge_t = 0.0
			if float(ev.get("warn", 0.0)) > 0.0:
				_hud.show_banner(tr("hud.ocean_shift"))
		&"finished":
			if not bool(ev.get("cleared", false)):
				AudioManager.play_music("kenney_jingle_defeat", 0.3)


func _on_revive_choice(accept: bool) -> void:
	_hud.hide_revive()
	if not accept:
		return
	Ads.show_rewarded(SaveManager.data, func(granted: bool) -> void:
		if granted:
			sim.revive()
			AudioManager.play("kenney_weapon_up")
			_hud.show_banner(tr("hud.revived")))


func _finish(quit: bool) -> void:
	if _reported and not quit:
		return
	_reported = true
	GameClock.paused = true
	var result := sim.result()
	result["quit"] = quit
	result["seed"] = seed_value
	finished.emit(result)


func _restart() -> void:
	var result := sim.result()
	result["restart"] = true
	_reported = true
	GameClock.paused = true
	finished.emit(result)


func _report_and_quit() -> void:
	if _reported:
		return
	_reported = true
	print("FIM frame=%d score=%d cleared=%s hash=%s" % [sim.frame, sim.scoring.score, sim.cleared, sim.state_hash()])
	SpriteBank.clear()
	get_tree().quit(0)
