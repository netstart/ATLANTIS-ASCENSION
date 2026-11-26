class_name Game
extends Node2D
## Uma missão em andamento (plano mestre 10.3): liga a entrada (dedo, teclado, controle ou bot), a
## Sim em passo fixo (GameClock), o desenho (cenário, mundo, HUD), o áudio e a vibração.
##
## Linha de comando (testes, depois de "--"): --bot, --seed=N, --speed=N, --quit-at=S (segundos de
## jogo; imprime "FIM ... hash=..." e sai), --stress=N (mantém N balas inimigas vivas), --mission=id.

signal finished(result: Dictionary)

const FINISH_DELAY := 1.6
## Depois da saída da nave (SimOutro) a tela já está vazia: só um respiro antes do resultado.
const OUTRO_DELAY := 0.5
const DOUBLE_TAP_MS := 280
const SHAKE_DECAY := 18.0
## Hitstop (congelar a partida por um instante no golpe forte): parte do chefe e morte do chefe.
const HITSTOP_PART := 0.05
const HITSTOP_BOSS := 0.14
## Tema dos chefes intermediários (SketchyLogic, CC0); a trilha da fase volta quando ele cai.
const MID_BOSS_MUSIC := "mintodog_space_boss_battle"
## Câmera lenta quando o chefe final cai (pesquisa .ai/07, seção 3.5): segura SLOWMO_SCALE pela
## primeira metade e volta suave à velocidade normal. Tempo real; a partida não muda.
const SLOWMO_TIME := 1.1
const SLOWMO_SCALE := 0.22
## Poderes por nível (índice = nível): tremor da câmera, clarão, vibração (ms e força) e a música abaixada
## no supremo. A pausa de impacto do nível III é da Sim (Powers.SUPREME_HITSTOP).
const POWER_SHAKE: Array[float] = [0.0, 2.5, 4.5, 9.0]
const POWER_FLASH: Array[float] = [0.0, 0.12, 0.25, 0.55]
const POWER_BUZZ: Array[int] = [0, 25, 55, 140]
const POWER_BUZZ_AMP: Array[float] = [0.0, 0.35, 0.55, 1.0]
const POWER_DUCK_DB := -9.0
const POWER_DUCK_SECONDS := 1.8
## Atlante salvo: o sino quente sobe uma escala maior a partir de uma sexta abaixo (nada agudo; o último degrau é o
## tom original do sino).
const RESCUE_SCALE: Array[float] = [0.6, 0.675, 0.75, 0.8, 0.9, 1.0]

var sim := Sim.new()
var mission_id: StringName = &"c1m1"
## Missão montada em tempo de execução (modos); vazia = ler data/stages/<mission_id>.json.
var mission_data: Dictionary = {}
## O jogador ainda pode reviver nesta missão (campanha e sobrevivência; desligado nos testes do bot).
var can_revive: bool = false
## Gravação da partida (entrada de cada passo) e, quando houver, o replay a reproduzir no lugar do jogador.
var recording: Replay
var playback: Replay
## Fantasma do Abismo: o recorde voando junto, numa segunda Sim com a entrada gravada.
var ghost: Replay
## Carga do hangar (Economy.loadout) ou só o id da aeronave.
var loadout: Variant = &"falcon"
var seed_value: int = 7
var use_bot: bool = false
var quit_at: float = -1.0
var stress: int = 0
var paused: bool = false
## Tela lógica que decide a altura do campo no começo (testes simulam cada aparelho); zero = a da viewport.
var screen := Vector2.ZERO

var _bot: BotPilot
var _wing_bomb_held: bool = false
var _ghost_sim: Sim
var _backdrop: OceanBackdrop
var _weather: WeatherView
var _weather_audio := WeatherAudio.new()
## Monitor de FPS: só na partida de verdade, rebaixa a qualidade uma vez quando o aparelho não aguenta.
var _fps_guard := FpsGuard.new()
var _clip: Control
## Palco: cenário, clima e campo, em unidades do campo. Em paisagem é ampliado até a altura da tela (Playfield):
## por transformação quando a ampliação dá pixels inteiros; senão desenhado num SubViewport e mostrado com o
## filtro nítido (shaders/sharp_pixels.gdshader).
var _stage: Node2D
var _scale: float = 1.0
var _sub: SubViewport
var _sharp: TextureRect
var _world: WorldView
var _screen: ScreenFx
var _layer: CanvasLayer
var _hud: GameHud
var _callouts: StyleCallouts
var _drag := Vector2.ZERO
var _taps: int = 0
var _want_special: bool = false
var _want_power: bool = false
var _want_bomb: bool = false
var _want_tide: bool = false
var _choice: int = -1
var _touch_ids: Dictionary = {}
## Dedos que começaram num botão do HUD: não movem a nave nem contam como toque.
var _button_touches: Dictionary = {}
var _last_tap_ms: int = -10000
var _shake: float = 0.0
var _hitstop: float = 0.0
var _emerge: float = 0.0
var _emerge_from: float = 0.0
var _emerge_to: float = 0.0
var _emerge_t: float = 1.0
var _emerge_duration: float = 1.0
var _done: float = -1.0
var _style := StyleTracker.new()
var _slowmo: float = 0.0
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
	# Altura do campo pela tela, decidida uma vez e guardada na carga (vai para o replay e o Fantasma). Replay
	# reproduz a altura gravado nele (os antigos, sem ela, rodam em 450).
	loadout = (loadout as Dictionary).duplicate() if typeof(loadout) == TYPE_DICTIONARY \
			else Sim.default_loadout(StringName(String(loadout)))
	if playback == null:
		var view := screen if screen != Vector2.ZERO else get_viewport().get_visible_rect().size
		loadout["field_h"] = Playfield.height_for(MenuKit.safe_rect(view, MenuKit.safe_margins(self)), _pixel_k())
	sim.setup(mission_data if not mission_data.is_empty() else Sim.load_mission(mission_id), Sim.load_tables(),
			loadout, seed_value,
			float(Settings.get_value("drag_sensitivity")))
	if use_bot:
		_bot = BotPilot.new()
	recording = Replay.new(sim.mission, seed_value, loadout)
	recording.loadout["sensitivity"] = float(Settings.get_value("drag_sensitivity"))
	if ghost != null and playback == null:
		_ghost_sim = ghost.make_sim()
	_backdrop = OceanBackdrop.new()
	_backdrop.detail = GfxQuality.level()
	_backdrop.kind = StringName(String(sim.mission.get("backdrop", "ocean")))
	_backdrop.foreground_on_top = true
	_stage = Node2D.new()
	add_child(_stage)
	_stage.add_child(_backdrop)
	_clip = Control.new()
	_clip.clip_contents = true
	_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_clip)
	_world = WorldView.new()
	_world.reduce_flashes = bool(Settings.get_value("reduce_flashes"))
	_world.colorblind = String(Settings.get_value("colorblind"))
	_world.fx_level = GfxQuality.level()
	_world.reduce_motion = bool(Settings.get_value("reduce_motion"))
	_world.setup(sim)
	_world.fx.landed.connect(_on_death_landed)
	if _ghost_sim != null:
		_world.ghost_sim = _ghost_sim
	_clip.add_child(_world)
	# Clima entre o chão e o campo (nuvens baixas, chuva ao longe); o de perto entra no WorldView.
	_weather = WeatherView.new()
	_weather.detail = GfxQuality.level()
	_weather.reduce_flashes = _world.reduce_flashes
	_weather.reduce_motion = _world.reduce_motion
	_stage.add_child(_weather)
	_stage.move_child(_weather, _clip.get_index())
	_weather.setup(sim, _world, _backdrop)
	_weather.thunder.connect(_weather_audio.on_thunder)
	_screen = ScreenFx.new()
	_screen.reduce_flashes = _world.reduce_flashes
	_screen.fx_level = _world.fx_level
	_clip.add_child(_screen)
	_layer = CanvasLayer.new()
	add_child(_layer)
	# Ecos de Estilo: sobre o campo, por baixo dos painéis do HUD (pausa, bênçãos).
	_callouts = StyleCallouts.new()
	_callouts.reduced = UiFx.reduced()
	_layer.add_child(_callouts)
	_hud = GameHud.new()
	_hud.theme = UiTheme.build(Locale.font)
	_layer.add_child(_hud)
	_hud.pause_pressed.connect(func() -> void: set_paused(true))
	_hud.resume_pressed.connect(func() -> void: set_paused(false))
	_hud.restart_pressed.connect(_restart)
	_hud.quit_pressed.connect(func() -> void: _finish(true))
	_hud.special_pressed.connect(func() -> void: _want_special = true)
	_hud.bomb_pressed.connect(func() -> void: _want_bomb = true)
	_hud.power_pressed.connect(_on_power_pressed)
	_hud.tide_pressed.connect(func() -> void: _want_tide = true)
	_hud.turbo_pressed.connect(_on_turbo_pressed)
	_hud.revive_chosen.connect(_on_revive_choice)
	_hud.blessing_chosen.connect(func(index: int) -> void: _choice = index)
	_hud.setup_mission(sim)
	get_viewport().size_changed.connect(relayout)
	MenuKit.on_insets_change(self, relayout)
	relayout.call_deferred()
	GameClock.reset()
	# Turbo (compra): mais passos fixos por quadro, a mesma partida passo a passo; o bot dos testes não usa.
	var turbo := not use_bot and Turbo.owned(SaveManager.data)
	GameClock.turbo = Turbo.speed(SaveManager.data) if turbo else 1.0
	_hud.set_turbo(turbo, GameClock.turbo)
	GameClock.ticked.connect(_on_tick)
	AudioManager.play_music(String(sim.mission.get("music", "")))


func _exit_tree() -> void:
	if GameClock.ticked.is_connected(_on_tick):
		GameClock.ticked.disconnect(_on_tick)
	_weather_audio.stop()
	GameClock.paused = true
	GameClock.time_scale = 1.0
	GameClock.turbo = 1.0


func relayout() -> void:
	relayout_for(get_viewport().get_visible_rect().size)


## Layout para uma tela lógica (os testes simulam cada aparelho com isto).
func relayout_for(view: Vector2) -> void:
	var safe := MenuKit.safe_rect(view, MenuKit.safe_margins(_hud))
	var layout := Playfield.layout(view, safe, sim.field.y)
	var field: Rect2 = layout["field"]
	_scale = layout["scale"]
	# O palco trabalha em unidades do campo; ampliado, cobre a tela inteira com 1 unidade de folga em volta.
	var stage_view := view
	var at := field.position
	if _scale != 1.0:
		stage_view = (view / _scale).ceil() + Vector2(2, 2)
		at = ((stage_view - sim.field) * 0.5).floor()
	_place_stage(stage_view, field.position - at * _scale)
	var local := Rect2(at, sim.field)
	_backdrop.set_view(stage_view)
	_backdrop.set_field(local)
	_weather.set_layout(stage_view, local)
	_clip.position = at
	_clip.size = sim.field
	# O HUD cresce junto com o campo: a camada é ampliada e o HUD trabalha em unidades do campo. Em retrato os
	# retângulos são os mesmos, só divididos (refazer o layout arredondaria a área segura e mudaria a escala).
	var u := _scale
	_layer.scale = Vector2(u, u)
	var hud_safe := Rect2(safe.position / u, safe.size / u)
	var hud_layout := layout
	if u != 1.0 and view.x > view.y:
		hud_layout = Playfield.layout(view / u, hud_safe, sim.field.y)
	elif u != 1.0:
		hud_layout = layout.duplicate()
		for key: String in ["field", "hud", "left", "right"]:
			var r: Rect2 = layout[key]
			hud_layout[key] = Rect2(r.position / u, r.size / u)
		hud_layout["scale"] = 1.0
	_hud.size = view / u
	_hud.apply_layout(hud_layout, hud_safe)
	_callouts.position = (hud_layout["field"] as Rect2).position
	_callouts.size = (hud_layout["field"] as Rect2).size


## Escala inteira da tela lógica para a física (PixelScaler).
func _pixel_k() -> int:
	return maxi(1, roundi(get_viewport().get_final_transform().x.x))


## Palco na tela: `origin` é onde cai o canto dele. Ampliação que dá pixels físicos inteiros (1, por exemplo)
## é só escala no nó; fracionária desenha num SubViewport (`m` pixels por unidade) e amplia com o filtro nítido.
func _place_stage(stage_view: Vector2, origin: Vector2) -> void:
	var k := _pixel_k()
	if is_equal_approx(_scale * k, roundf(_scale * k)):
		if _stage.get_parent() != self:
			_stage.reparent(self, false)
			move_child(_stage, 0)
		if _sharp != null:
			_sharp.visible = false
		_stage.position = origin
		_stage.scale = Vector2.ONE * _scale
		return
	if _sub == null:
		_sharp = TextureRect.new()
		_sharp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_sharp.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_sharp.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		var mat := ShaderMaterial.new()
		mat.shader = load("res://shaders/sharp_pixels.gdshader") as Shader
		_sharp.material = mat
		_sub = SubViewport.new()
		_sub.size_2d_override_stretch = true
		_sub.canvas_item_default_texture_filter = get_viewport().canvas_item_default_texture_filter
		_sub.snap_2d_transforms_to_pixel = get_viewport().snap_2d_transforms_to_pixel
		_sharp.add_child(_sub)
		add_child(_sharp)
		move_child(_sharp, 0)
		_sharp.texture = _sub.get_texture()
	if _stage.get_parent() != _sub:
		_stage.reparent(_sub, false)
	_stage.position = Vector2.ZERO
	_stage.scale = Vector2.ONE
	var m := maxi(1, floori(_scale * k))
	_sub.size = Vector2i(stage_view * m)
	_sub.size_2d_override = Vector2i(stage_view)
	_sharp.position = origin
	_sharp.size = stage_view * _scale
	(_sharp.material as ShaderMaterial).set_shader_parameter("tex_size", Vector2(_sub.size))
	_sharp.visible = true


## Ampliação do campo na tela (pixels lógicos por unidade do campo).
func field_scale() -> float:
	return _scale


## Ampliação da camada do HUD (a mesma do campo).
func hud_scale() -> float:
	return _layer.scale.x


## Raiz do HUD (testes de layout).
func hud() -> GameHud:
	return _hud


## Camada dos Ecos de Estilo (testes).
func callouts() -> StyleCallouts:
	return _callouts


## Clima na tela (testes e capturas).
func weather_view() -> WeatherView:
	return _weather


func set_paused(value: bool) -> void:
	if sim.finished:
		return
	paused = value
	GameClock.paused = value
	_weather_audio.paused = value
	_hud.set_paused(value)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and not use_bot and not sim.finished:
		set_paused(true)


# --- Entrada ---------------------------------------------------------------------------------

## Antes da interface: marca o dedo que começa num botão do HUD (o botão recebe o toque normalmente; o
## _unhandled_input ignora esse dedo até ele voltar a tocar fora dos botões).
func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		var touch := event as InputEventScreenTouch
		if _hud.touches_button(touch.position / _layer.scale.x):
			_button_touches[touch.index] = true
		else:
			_button_touches.erase(touch.index)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		set_paused(not paused)
		get_viewport().set_input_as_handled()
		return
	if paused:
		return
	if sim.wing != null and (event is InputEventJoypadButton or event is InputEventJoypadMotion):
		# No co-op o controle é da nave 2 (lido em _wing_input).
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if _button_touches.has(touch.index):
			return
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
		if not _button_touches.has((event as InputEventScreenDrag).index):
			_drag += (event as InputEventScreenDrag).relative / _scale
	elif event.is_action_pressed("special"):
		_want_special = true
	elif event.is_action_pressed("power"):
		_want_power = true
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
	if sim.wing != null:
		# Co-op: a nave 1 fica com o teclado (e o toque); o controle move a ala.
		input.axis = Vector2(_key(KEY_D, KEY_RIGHT) - _key(KEY_A, KEY_LEFT), _key(KEY_S, KEY_DOWN) - _key(KEY_W, KEY_UP))
		input.axis = input.axis.limit_length(1.0)
	input.precise = Input.is_action_pressed(&"precise") or _touch_ids.size() >= 2
	input.fire = bool(Settings.get_value("auto_fire")) or Input.is_action_pressed(&"fire") or not _touch_ids.is_empty()
	input.special = _want_special
	input.power = _want_power
	input.bomb = _want_bomb
	input.tide = _want_tide
	input.taps = _taps
	input.choice = _choice
	_want_special = false
	_want_power = false
	_want_bomb = false
	_want_tide = false
	_choice = -1
	_taps = 0
	return input


func _on_tick(_dt: float) -> void:
	if paused or sim.finished:
		return
	var input: SimInput
	if playback != null:
		input = playback.next_input()
		if input == null:
			_finish(true)
			return
	else:
		input = _bot.decide(sim) if _bot != null else _human_input()
	recording.record(input)
	var input2: SimInput = null
	if sim.wing != null:
		input2 = _bot.decide_wing(sim) if _bot != null else _wing_input()
	if _ghost_sim != null and not _ghost_sim.finished:
		var g := ghost.next_input()
		if g != null:
			_ghost_sim.step(g)
			_ghost_sim.take_events()
	if stress > 0:
		_stress()
	sim.step(input, input2)
	_beam_fire_sound()


## O feixe acende no quadro em que o aviso acaba (idade == aviso): baque grave com rugido que fecha, o fim da carga
## de fx_beam_warn (tools/mix_alert_audio.py). O raio do clima não entra: o trovão dele vem do WeatherAudio. Só lê a
## Sim; vários feixes no mesmo quadro tocam um som só.
func _beam_fire_sound() -> void:
	if beam_lit_now(sim.beams):
		AudioManager.play("fx_beam_fire", 1.0, 0.03, 0.0)


## Algum feixe (fora o raio do clima) acendeu neste quadro.
static func beam_lit_now(beams: Array[Dictionary]) -> bool:
	for b: Dictionary in beams:
		if int(b["age"]) == int(b["warn"]) and String(b.get("kind", "")) != "lightning":
			return true
	return false


## Turbo do HUD: próxima velocidade (1x → 1,5x → 2x), guardada no perfil pelo Turbo e aplicada na hora.
func _on_turbo_pressed() -> void:
	GameClock.turbo = Turbo.cycle(SaveManager.data)
	_hud.set_turbo(true, GameClock.turbo)


## Botão PODER do HUD (pilha lateral): mesmo caminho da tecla, entra no próximo SimInput.
func _on_power_pressed() -> void:
	_want_power = true


func _key(a: Key, b: Key) -> float:
	return 1.0 if Input.is_physical_key_pressed(a) or Input.is_physical_key_pressed(b) else 0.0


## Co-op local: a nave 2 é o primeiro controle conectado (analógico ou direcional, B = bomba, tiro automático).
## Os eventos de controle não vão para a nave 1 enquanto houver ala (_unhandled_input).
func _wing_input() -> SimInput:
	var input := SimInput.new()
	input.fire = true
	var pads := Input.get_connected_joypads()
	if pads.is_empty():
		return input
	var dev: int = pads[0]
	var axis := Vector2(Input.get_joy_axis(dev, JOY_AXIS_LEFT_X), Input.get_joy_axis(dev, JOY_AXIS_LEFT_Y))
	if axis.length() < 0.2:
		axis = Vector2.ZERO
	axis += Vector2(float(Input.is_joy_button_pressed(dev, JOY_BUTTON_DPAD_RIGHT))
			- float(Input.is_joy_button_pressed(dev, JOY_BUTTON_DPAD_LEFT)),
			float(Input.is_joy_button_pressed(dev, JOY_BUTTON_DPAD_DOWN))
			- float(Input.is_joy_button_pressed(dev, JOY_BUTTON_DPAD_UP)))
	input.axis = axis.limit_length(1.0)
	input.precise = Input.get_joy_axis(dev, JOY_AXIS_TRIGGER_LEFT) > 0.5
	var bomb := Input.is_joy_button_pressed(dev, JOY_BUTTON_B)
	input.bomb = bomb and not _wing_bomb_held
	_wing_bomb_held = bomb
	return input


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
	for c: Dictionary in _style.tick(sim):
		_show_style(c)
	_tick_slowmo(delta)
	if _emerge_t < 1.0:
		_emerge_t = minf(1.0, _emerge_t + delta / maxf(0.01, _emerge_duration))
		var u := _emerge_t * _emerge_t * (3.0 - 2.0 * _emerge_t)
		_emerge = lerpf(_emerge_from, _emerge_to, u)
	_shake = maxf(0.0, _shake - SHAKE_DECAY * delta)
	_tick_hitstop(delta)
	_screen.set_danger(1.0 if sim.player.alive and sim.player.hull <= 1 and sim.player.max_hull > 1 else 0.0)
	_screen.advance(delta)
	var amount := _shake * float(Settings.get_value("screen_shake")) * float(GfxQuality.budget("screen_shake"))
	var jitter := Vector2(sin(Time.get_ticks_msec() * 0.09), cos(Time.get_ticks_msec() * 0.11)) * amount
	_world.position = jitter.round()
	_world.touching = not _touch_ids.is_empty() or Input.is_action_pressed(&"precise")
	# Câmera 2,5D: o chão acompanha a nave na horizontal (só visual; a Sim não lê nada daqui).
	var cam_tilt := Vector2(clampf(sim.player.pos.x / Playfield.FIELD.x * 2.0 - 1.0, -1.0, 1.0), 0.0)
	_backdrop.apply(sim.scroll, _emerge, cam_tilt, bool(Settings.get_value("reduce_motion")))
	_backdrop.set_drift((sim.gravity if sim.drift_frames > 0 else Vector2.ZERO) + sim.weather.wind)
	_weather.refresh(delta)
	_weather_audio.update(sim.weather, delta)
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
			_done = OUTRO_DELAY if sim.cleared and sim.outro.enabled else FINISH_DELAY
		_done -= delta
		if _done <= 0.0:
			_finish(false)
	# Rebaixamento adaptativo: só na partida de verdade (nem bot, nem captura, nem partida terminada).
	if not use_bot and quit_at <= 0.0 and not sim.finished and _fps_guard.tick(delta):
		GfxQuality.auto_downgrade()


## Parte do chefe quebrando: estalo metálico, explosão média e um corpo grave, por prioridade (a rajada de
## mortes comuns usa os mesmos arquivos e não pode calar o chefe), e a cauda de destroços logo depois.
func _boss_part_sound() -> void:
	AudioManager.play_priority("kenney_part_clamp", 0.6, 0.04, -8.0)
	AudioManager.play_priority("kenney_explosion_medium", 0.9, 0.05, -2.0)
	AudioManager.play_priority("kenney_explosion_big", 1.2, 0.05, -9.0)
	_world.fx.later(0.16, AudioManager.play_priority.bind("kenney_explosion_small", 0.65, 0.05, -12.0))


## Morte do chefe (de fase e de meio de fase): estrondo agora, estouros no tempo da cadeia de explosões do
## WorldView (CombatFx.chain em 1,3 s), o estouro final grande em 1,35 s e a cauda de destroços. Tudo pelo
## relógio dos efeitos (fx.later): som e imagem andam juntos, mesmo na câmera lenta.
func _boss_dead_sound() -> void:
	AudioManager.play_priority("kenney_explosion_big", 1.0, 0.0, -4.0)
	AudioManager.play_priority("faxcorp_deathboom", 1.0, 0.0, -6.0)
	for k: int in range(4):
		_world.fx.later(0.3 + 0.3 * k, AudioManager.play_priority.bind("kenney_explosion_medium", 0.95 - 0.06 * k,
				0.05, -9.0))
	_world.fx.later(1.35, AudioManager.play_priority.bind("kenney_explosion_big", 0.8, 0.0, -2.0))
	_world.fx.later(1.35, AudioManager.play_priority.bind("kenney_bomb", 0.7, 0.0, -7.0))
	_world.fx.later(1.6, AudioManager.play_priority.bind("kenney_explosion_small", 0.6, 0.05, -11.0))
	_world.fx.later(1.75, AudioManager.play_priority.bind("kenney_part_clamp", 0.5, 0.05, -14.0))


## Fim de uma morte em curso (CombatFx.landed): o som e o tranco do impacto. No mar a explosão sai
## abafada (tom grave); no chão, cheia; o derretimento acaba num estouro pequeno.
func _on_death_landed(_at: Vector2, big: bool, kind: StringName) -> void:
	match kind:
		CombatFx.WATER:
			AudioManager.play("kenney_explosion_medium", 0.6, 0.06, -7.0 if big else -11.0)
			_shake = maxf(_shake, 2.2 if big else 0.8)
		CombatFx.SOLID:
			AudioManager.play("kenney_explosion_medium" if big else "kenney_explosion_small", 0.9, 0.08, -6.0)
			if big:
				AudioManager.play("kenney_explosion_big", 1.15, 0.06, -14.0)
			_shake = maxf(_shake, 3.0 if big else 1.0)
		_:
			AudioManager.play("kenney_explosion_small", 1.2, 0.08, -9.0)
			_shake = maxf(_shake, 1.4 if big else 0.5)


func _on_event(ev: Dictionary) -> void:
	_world.on_event(ev)
	for c: Dictionary in _style.observe(ev, sim):
		_show_style(c)
	match StringName(ev["type"]):
		&"shot":
			AudioManager.play("kenney_shot_pulsar", 1.0, 0.05, -14.0)
		&"kill":
			var big := bool(ev.get("big", false))
			match _world.last_death:
				CombatFx.MELT:
					# Derrete: chiado agudo e baixo agora, o estouro no fim (_on_death_landed).
					AudioManager.play("kenney_explosion_small", 1.5, 0.08, -14.0)
					_shake = maxf(_shake, 1.0 if big else 0.3)
				CombatFx.FALL:
					# Pega fogo: estouro curto agora, o impacto quando bate no mar ou no chão.
					AudioManager.play("kenney_explosion_small", 1.25, 0.08, -10.0)
					_shake = maxf(_shake, 1.2 if big else 0.4)
				_:
					AudioManager.play("kenney_explosion_medium" if big else "kenney_explosion_small", 1.0, 0.08, -6.0)
					if big:
						# Grande: o corpo grave da explosão grande por baixo, baixo, para pesar sem embolar.
						AudioManager.play("kenney_explosion_big", 1.1, 0.06, -13.0)
					_shake = maxf(_shake, 3.6 if big else 1.1)
			if big:
				Settings.vibrate(18, 0.45, 0)
		&"hit":
			AudioManager.play("hit", 1.0, 0.1, -16.0)
		&"sea_contact":
			# Submarino ou navio no sonar: aviso grave e baixo antes de ele subir e atirar (só os mísseis o alcançam).
			AudioManager.play("fx_sonar", 0.8, 0.0, -10.0)
		&"graze":
			# Sopro de ar curto (o highUp em quadrada de 8 bits era agudo e repetitivo).
			AudioManager.play("fx_graze", 1.0, 0.06, -8.0)
			Settings.vibrate(8, 0.25, 0)
		&"orb":
			# Subiu a arma principal ou a secundária (revisão 10): o som de melhora; senão a coleta simples.
			var up := bool(ev.get("up", false)) or bool(ev.get("secondary_up", false))
			AudioManager.play("fx_power_up" if up else "fx_orb", 1.0, 0.0, 0.0 if up else -3.0)
		&"medal":
			# O tom sobe com o valor só até +30% (a +60% a moeda em quadrada chegava a ~4 kHz de centro) e mais baixo:
			# era a coleta mais alta da partida.
			AudioManager.play("coin_medal", 0.95 + minf(0.3, float(ev.get("value", 100)) / 20000.0), 0.0, -6.0)
		&"pearl":
			AudioManager.play("coin_pearl", 1.0, 0.1, -1.0)
		&"player_hit":
			AudioManager.play("kenney_player_hit")
			Settings.vibrate(80, -1.0, 2)
			_shake = 7.0
			_screen.flash(0.35, Color(1.0, 0.3, 0.3))
			_screen.shockwave(ev["pos"], 0.012)
		&"bomb", &"special":
			AudioManager.play("kenney_bomb")
			Settings.vibrate(50)
			_shake = 6.0
			_screen.flash(0.45, Color(0.75, 1.0, 1.0))
			_screen.shockwave(ev["pos"], 0.03)
		&"power":
			_on_power(ev)
		&"power_charge":
			var segments := clampi(int(ev.get("segments", 1)), 1, 3)
			# Uma quarta abaixo (o acorde maior continua, agora Sol-Si-Ré) e mais baixo: no meio dos glifos não fura.
			AudioManager.play("power_charge_%d" % segments, 0.75, 0.0, -7.0)
			_hud.power_button().charged(segments)
			if segments >= 3:
				Settings.vibrate(20, 0.4, 0)
		&"power_empty":
			AudioManager.play("power_empty", 1.0, 0.0, -6.0)
			_hud.power_button().empty()
		&"power_blast":
			var radius := float(ev.get("radius", 40.0))
			AudioManager.play("kenney_explosion_big" if radius >= 120.0 else "kenney_explosion_medium", 1.0, 0.08,
					-2.0 if radius >= 120.0 else -6.0)
			_shake = maxf(_shake, clampf(radius / 16.0, 2.0, 10.0))
			_screen.shockwave(ev["pos"], clampf(radius / 6000.0, 0.008, 0.045))
			if radius >= 120.0:
				_screen.flash(0.6, Color(1.0, 0.97, 0.9))
				Settings.vibrate(90, 0.8, 1)
		&"beam_warn":
			# Carga grave que sobe uma quinta no ritmo do pisca da faixa, 1 s (tools/mix_alert_audio.py). O antigo
			# (computerNoise do Kenney) era um zumbido de 1 kHz de 5 s que tocava por cima de si mesmo.
			AudioManager.play("fx_beam_warn")
		&"boss_intro":
			var boss_def: Dictionary = (sim.tables["bosses"] as Dictionary).get(StringName(ev["id"]), {})
			var tier := String(boss_def.get("tier", ""))
			# Chefes de meio de fase: alarme; criaturas (frota Nautolan) rugem; o intermediário tem tema próprio.
			# Meio de fase: sirene grave de dois tons (o alarme do rubberduck tinha 98% da energia acima de 4 kHz).
			if tier.is_empty():
				AudioManager.play("kenney_boss_alert")
			else:
				AudioManager.play("fx_alarm", 1.0, 0.0, -8.0)
			if String(boss_def.get("sprite", "")).begins_with("nautolan"):
				AudioManager.play("rubberduck_roar" if tier == "mid" else "rubberduck_growl", 1.0, 0.05, -4.0)
			_hud.show_banner(tr(String(ev.get("name_key", ""))))
			if bool(ev.get("final", false)):
				AudioManager.play_music(String(boss_def.get("music", "")))
			elif tier == "mid":
				AudioManager.play_music(MID_BOSS_MUSIC)
		&"boss_phase":
			if not String(ev.get("dialogue", "")).is_empty():
				_hud.show_radio(String(ev["dialogue"]))
		&"boss_part":
			_boss_part_sound()
			_shake = maxf(_shake, 4.0)
			_screen.shockwave(ev["pos"], 0.015)
			_hitstop_for(HITSTOP_PART)
		&"duel_start":
			AudioManager.play("fx_duel")
			_hud.show_banner(tr("hud.duel"))
		&"boss_dead":
			_boss_dead_sound()
			if not bool(ev.get("final", false)) and AudioManager.music_id() == MID_BOSS_MUSIC:
				AudioManager.play_music(String(sim.mission.get("music", "")))
			Settings.vibrate(150, -1.0, 2)
			_shake = 10.0
			_screen.flash(0.8)
			_screen.shockwave(ev["pos"], 0.045)
			_hitstop_for(HITSTOP_BOSS)
			if bool(ev.get("final", false)):
				AudioManager.play_music("kenney_jingle_victory", 0.3)
				_slowmo_start()
		&"dialogue":
			_hud.show_radio(String(ev.get("id", "")))
		&"blessing_offer":
			# Oferta de bênção: sino quente (o kenney_weapon_up a 0,8 era agudo demais, mesmo baixo por cima).
			AudioManager.play("kenney_ascend_bell", 1.0, 0.0, -3.0)
			_hud.show_offer(sim)
		&"blessing":
			AudioManager.play("kenney_ui_confirm", 0.9, 0.0, -3.0)
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
		&"weather":
			_on_weather(ev)
		&"weather_mastered":
			AudioManager.play("fx_power_up", 0.9)
			Settings.vibrate(40, 0.5, 1)
			_world.fx.popup(ev["pos"], int(ev.get("points", 0)), UiTheme.GOLD)
		&"log":
			AudioManager.play("kenney_medal", 0.8)
			_hud.show_radio_text(tr("hud.log_found"), UiTheme.CYAN)
		&"glyph":
			# Glifo: degrau curto que sobe sem passar do tom original, com o sino quente por baixo.
			var step := float(ev.get("index", 0))
			AudioManager.play("fx_orb", 0.75 + 0.05 * step, 0.0, -6.0)
			AudioManager.play("kenney_ascend_bell", 0.8 + 0.05 * step, 0.0, -9.0)
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
			AudioManager.play("coin_capsule", 1.0 + 0.08 * float(ev.get("combo", 1)), 0.0, -1.0)
			if int(ev.get("combo", 1)) >= 2:
				_hud.show_radio_text(tr("hud.capsule_combo") % int(ev["combo"]), UiTheme.GOLD)
		&"cover":
			AudioManager.play("kenney_ocean_shift", 1.4, 0.0, -10.0)
		&"abyss":
			AudioManager.play("kenney_ocean_shift", 0.5 + 0.01 * float(ev["depth"]), 0.0, -6.0)
			_hud.show_banner(tr("hud.depth") % int(ev["depth"]))
		&"capture":
			AudioManager.play("fx_power_up", 1.3)
			Settings.vibrate(30)
			_hud.show_radio_text(tr("hud.capture"), UiTheme.CYAN)
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
		&"objective_warn", &"objective_progress", &"objective_release", &"survivor", &"survivor_lost", &"relic", \
				&"objective_end", &"reinforcements":
			_on_objective(ev)
		&"outro":
			_hud.fade_actions()
		&"outro_rise":
			# Arrancada: o jato liga (turbina, ignição e pós-combustor, tools/mix_power_audio.py) e a mão sente o
			# empuxo crescer até a ignição.
			AudioManager.play_priority("outro_afterburner", 1.0, 0.0, -3.0)
			Settings.vibrate(30, 0.2, 1)
			_world.fx.later(0.15, Settings.vibrate.bind(40, 0.35, 1))
			_world.fx.later(0.3, Settings.vibrate.bind(90, 0.55, 1))
		&"finished":
			if not bool(ev.get("cleared", false)):
				AudioManager.play_music("kenney_jingle_defeat", 0.3)


## Objetivos de fase (SimObjectives): aviso no rádio, sinos baixos e quentes no progresso, fanfarra curta no acerto e
## um baque grave na falha (o dono pediu sons sem agudo: tudo transposto para baixo e mais baixo de volume).
func _on_objective(ev: Dictionary) -> void:
	var kind := StringName(String(ev.get("kind", "")))
	match StringName(ev["type"]):
		&"objective_warn":
			AudioManager.play("fx_sonar", 1.0, 0.0, -6.0)
			AudioManager.play("kenney_ascend_bell", 0.6, 0.0, -9.0)
			var text := tr("mini.intercept_warn")
			if kind == &"rescue":
				text = tr("mini.pod_warn") if bool(ev.get("pod", false)) else tr("mini.rescue_warn")
			elif kind == &"sabotage":
				text = tr("mini.sabotage_warn") % int(ev.get("total", 3))
			# O aviso sai do alto do campo quando os alvos entram (SimObjectives.WARN_FRAMES): não os cobre.
			_hud.show_radio_text(text, UiTheme.GOLD, SimObjectives.WARN_FRAMES / 60.0)
		&"objective_progress":
			AudioManager.play("fx_orb", 0.75 + 0.05 * float(ev.get("done", 0)), 0.0, -6.0)
		&"objective_release":
			AudioManager.play("kenney_ocean_shift", 1.2, 0.0, -9.0)
		&"survivor":
			AudioManager.play("kenney_ascend_bell", RESCUE_SCALE[clampi(int(ev.get("done", 1)) - 1, 0, 5)], 0.0, -6.0)
			Settings.vibrate(12, 0.3, 0)
		&"survivor_lost":
			AudioManager.play("kenney_hit", 0.5, 0.0, -14.0)
		&"relic":
			AudioManager.play("kenney_medal", 0.8, 0.0, -4.0)
		&"reinforcements":
			AudioManager.play("fx_horn", 1.0, 0.0, -2.0)
		&"objective_end":
			var ok := bool(ev.get("ok", false))
			var text := tr("mini.intercept_ok") if ok else tr("mini.intercept_fail")
			if kind == &"rescue":
				text = tr("mini.rescue_end") % [int(ev["done"]), int(ev["total"])] if bool(ev.get("released", false)) \
						else tr("mini.rescue_escaped")
			elif kind == &"sabotage":
				text = tr("mini.sabotage_ok") if ok else tr("mini.sabotage_fail")
			_hud.show_radio_text(text, UiTheme.GOLD if ok else UiTheme.CORAL)
			if ok:
				AudioManager.play("kenney_ui_confirm", 0.8, 0.0, -4.0)
				AudioManager.play("kenney_ascend_bell", 0.5, 0.0, -7.0)
				_world.fx.popup(ev["pos"], roundi(SimObjectives.SUCCESS_POINTS * sim.scoring.point_mult), UiTheme.GOLD)
				Settings.vibrate(30, 0.4, 1)
			else:
				AudioManager.play("kenney_hit", 0.5, 0.0, -8.0)
				AudioManager.play("kenney_ocean_shift", 0.5, 0.0, -10.0)


## Poder lançado: o som do poder, tremor, clarão e vibração que crescem com o nível e a faixa com o nome
## (no Eco de Atlântida, também o poder ecoado). No supremo a música abaixa enquanto o golpe soa.
func _on_power(ev: Dictionary) -> void:
	var id := StringName(String(ev.get("id", "")))
	var tier := clampi(int(ev.get("tier", 1)), 1, 3)
	var def: Dictionary = (sim.tables.get("powers", {}) as Dictionary).get(id, {})
	var tint := Color(String(def.get("color", "#ffffff")))
	AudioManager.play(String(def.get("sfx", "power_" + String(id))))
	_shake = maxf(_shake, POWER_SHAKE[tier])
	Settings.vibrate(POWER_BUZZ[tier], POWER_BUZZ_AMP[tier], 1 if tier < 3 else 2)
	_screen.flash(POWER_FLASH[tier], tint.lerp(Color.WHITE, 0.5))
	if tier >= 2:
		_screen.shockwave(ev.get("pos", sim.player.pos), 0.01 * tier)
	var title := tr(String(def.get("name_key", "")))
	var echo := String(ev.get("echo", ""))
	if not echo.is_empty():
		title = "%s: %s" % [title, tr("power." + echo)]
	_hud.show_power(title, tier, tint, SpriteBank.texture(String(def.get("icon", ""))))
	if tier >= 3:
		AudioManager.duck(POWER_DUCK_DB, POWER_DUCK_SECONDS)


## Frente de clima anunciada: aviso no rádio (coral se for severa) com o tempo que falta, e um som.
func _on_weather(ev: Dictionary) -> void:
	var def := sim.weather.def_of(StringName(String(ev.get("to", ""))))
	var label := tr(String(def.get("name_key", "")))
	var severe := bool(ev.get("severe", false))
	var key := "weather.front_severe" if severe else "weather.front"
	_hud.show_radio_text(tr(key) % label, UiTheme.CORAL if severe else UiTheme.CYAN)
	AudioManager.play("kenney_ocean_shift", 0.6 if severe else 0.9, 0.0, -6.0 if severe else -10.0)
	if severe:
		Settings.vibrate(25, 0.3, 0)


## Ecos de Estilo: frase no campo, som que sobe com o destaque e um toque leve na mão.
func _show_style(c: Dictionary) -> void:
	if not bool(Settings.get_value("style_callouts")):
		return
	var tier := int(c.get("tier", 0))
	var text := tr(String(c["key"]))
	if int(c.get("arg", 0)) > 0:
		text = text % int(c["arg"])
	_callouts.pop(text, tier)
	AudioManager.play("fx_power_up" if tier >= 3 else "kenney_medal", 1.15 + 0.12 * tier, 0.0, -9.0 + 2.0 * tier)
	Settings.vibrate(12 + 10 * tier, 0.3 + 0.2 * tier, 0 if tier < 3 else 1)


func _slowmo_start() -> void:
	if use_bot or playback != null:
		return
	_slowmo = SLOWMO_TIME


## Primeira metade em SLOWMO_SCALE; a segunda volta ao normal com curva suave.
func _tick_slowmo(delta: float) -> void:
	if _slowmo <= 0.0:
		return
	_slowmo = maxf(0.0, _slowmo - delta)
	var u := clampf(1.0 - _slowmo / SLOWMO_TIME, 0.0, 1.0)
	var back := clampf((u - 0.5) * 2.0, 0.0, 1.0)
	GameClock.time_scale = lerpf(SLOWMO_SCALE, 1.0, back * back * (3.0 - 2.0 * back))
	if _slowmo <= 0.0 or paused or _reported:
		GameClock.time_scale = 1.0
		_slowmo = 0.0


## Congela a Sim por `seconds` de tempo real (o desenho continua: faíscas e anéis seguem). A partida
## não muda, só atrasa; o bot e os replays não param.
func _hitstop_for(seconds: float) -> void:
	if use_bot or playback != null:
		return
	_hitstop = maxf(_hitstop, seconds)


func _tick_hitstop(delta: float) -> void:
	if _hitstop <= 0.0:
		return
	_hitstop -= delta
	if paused or sim.finished or _reported:
		_hitstop = 0.0
		return
	GameClock.paused = _hitstop > 0.0


func _on_revive_choice(accept: bool) -> void:
	_hud.hide_revive()
	if not accept:
		return
	# Carga do pacote de revives (Iap): troca só o anúncio; a vez continua 1 por missão (can_revive já caiu).
	if Iap.revive_path(SaveManager.data) == "charge" and Iap.spend_revive(SaveManager.data):
		SaveManager.save_profile()
		_revived()
		return
	# Anúncio que não abre (falha técnica) ou que não carregou devolve granted: o reviver só se perde se o
	# jogador fechar o anúncio antes do fim (Ads.rewarded_granted).
	Ads.show_rewarded(SaveManager.data, func(granted: bool) -> void:
		if granted:
			_revived())


func _revived() -> void:
	_done = -1.0
	sim.revive()
	AudioManager.play("fx_power_up")
	_hud.show_banner(tr("hud.revived"))


func _finish(quit: bool) -> void:
	if _reported and not quit:
		return
	_reported = true
	GameClock.paused = true
	GameClock.time_scale = 1.0
	var result := sim.result()
	result["quit"] = quit
	result["seed"] = seed_value
	result["replay"] = playback != null
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
