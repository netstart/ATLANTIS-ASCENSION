class_name WorldView
extends Node2D
## Desenho do campo de jogo a partir da Sim (só leitura). Camadas, de baixo para cima:
##   sombras no chão → destroços caindo → entidades (inimigos, chefe, coletáveis) → fumaça e estilhaços →
##   tiros do jogador (com halo) → nave e laser → efeitos de baixo (feixes, explosões, duelo) →
##   luz aditiva (laser, motores, clarões, anéis de choque) → faíscas e brilhos (CombatFx) →
##   balas inimigas (sempre por cima: leitura) → efeitos de cima (escuridão, números de pontos).
## Só texturas e retângulos por quadro (docs/policies/qualidade.md); partículas em MultiMesh
## (ParticleField). Efeitos vivem aqui, não na Sim: qualidade gráfica e "reduzir flashes" nunca
## mudam a partida.
## 2,5D: cada nave tem uma sombra (cópia escura do sprite, 80%, deslocada (+6, +10)) desenhada no chão,
## abaixo de tudo; inimigos que sobem do fundo (SimEnemy.depth < 1, ainda sem colisão na Sim) crescem
## de 35% a 100% saindo da neblina, e a sombra se separa deles conforme sobem. A nave inclina nas
## curvas (some com "reduzir movimento") e o dano pisca em branco (shaders/sprite_flash.gdshader).
## A nave veste as peças do nível do hangar (ShipLivery, carga "ship_level"); na Ascendida (nível 10)
## deixa um rastro de centelhas de ouro.

const ANIM_FPS := 12.0
const EXPLOSION_TIME := 0.6
const SHADOW_OFFSET := Vector2(6, 10)
const SHADOW_SCALE := 0.8
const SHADOW_COLOR := Color(0.0, 0.02, 0.05, 0.35)
## Escala visual de quem sobe do fundo (0,35 → 1,0 enquanto a Sim leva depth de DEPTH_START a 1).
const RISE_SCALE := 0.35
## Inclinação da nave nas curvas: rotação máxima (rad) e quanto a largura encolhe.
const BANK_ROT := 0.1
const BANK_SQUEEZE := 0.22
const LASER_COLOR := Color(0.55, 0.97, 1.0, 0.95)
const BEAM_COLOR := Color(1.0, 0.42, 0.45, 0.95)
const WARN_COLOR := Color(1.0, 0.42, 0.45, 0.7)
## Luz do motor da nave (bocais em ±7, +17 do centro) e do laser.
const EXHAUST_COLOR := Color(1.0, 0.55, 0.22)
const NOZZLES: Array[Vector2] = [Vector2(-7, 17), Vector2(7, 17)]
## Cor da luz de cada arma (impactos, boca do canhão) e dos orbes de arma.
const WEAPON_TINTS := {&"pulsar": Color(0.55, 0.8, 1.0), &"laser": Color(0.55, 0.97, 1.0),
		&"plasma": Color(0.8, 0.55, 1.0), &"railgun": Color(1.0, 0.6, 0.45)}
const ORB_TINTS := {&"pulsar": Color(0.4, 0.65, 1.0), &"laser": Color(1.0, 0.82, 0.35),
		&"plasma": Color(0.78, 0.5, 1.0), &"railgun": Color(1.0, 0.45, 0.45)}
## Emissores contínuos (motor, fumaça de avaria, bolhas) rodam a 60 Hz, em qualquer taxa de quadros.
const EMIT_STEP := 1.0 / 60.0
const LIGHTNING_COLOR := Color(0.85, 0.92, 1.0, 0.95)
const TIDE_COLOR := Color(0.45, 1.0, 0.95, 0.55)
## Colunas de perigo por tipo (lava do cap. 4, gelo do 6, detritos do 8).
const HAZARD_COLORS := {"lava": Color(1.0, 0.45, 0.15, 0.95), "icefall": Color(0.75, 0.95, 1.0, 0.9),
		"debris": Color(0.7, 0.7, 0.75, 0.9)}
const COVER_COLOR := Color(0.16, 0.2, 0.3, 0.95)
const COVER_TRIM := Color(0.45, 0.85, 1.0, 0.8)
const BREACH_COLOR := Color(0.75, 0.55, 1.0, 0.22)
## Rastro da nave Ascendida: uma centelha a cada WAKE_STEP s, WAKE_LEN delas.
const WAKE_STEP := 0.05
const WAKE_LEN := 9
var dark: bool = false
## Paleta de daltonismo das balas inimigas (Settings "colorblind").
var colorblind: String = "off"
## Fantasma do Abismo: a Sim do recorde (só a nave dele é desenhada, translúcida).
var ghost_sim: Sim
## Encaixe do clima de perto (WeatherView): acima das naves e dos efeitos, abaixo das balas inimigas.
var weather_slot := Node2D.new()

var sim: Sim
var time: float = 0.0
var touching: bool = false
var reduce_flashes: bool = false
## "Reduzir movimento": sem inclinação da nave nas curvas.
var reduce_motion: bool = false
var fx_level: int = 2
var explosions: Array[Dictionary] = []
## Anéis de choque: {pos, t, duration, radius, color}.
var rings: Array[Dictionary] = []
## Receitas e partículas (explosões, faíscas, fumaça, destroços, números de pontos).
var fx := CombatFx.new()
## Poderes das naves (PowerView): projéteis, feixes, raios, ondas e a escuridão do eclipse.
var powers := PowerView.new()

var _shadows: _Layer
var _entities: _Layer
var _player: _Layer
var _fx_below: _Layer
var _fx_add: _Layer
var _fx_above: _Layer
var _power_below: _Layer
var _power_add: _Layer
var _wrecks: _Layer
var _player_bullets: BulletRenderer
var _enemy_bullets: BulletRenderer
var _glow: Texture2D
var _ring: Texture2D
var _flare: Texture2D
## Explosões em pixel art (ansimuz, CC0) para peças e quedas de chefe: 80, 128 e 192 px.
var _blasts: Dictionary = {}
var _shock: Texture2D
var _sparkle: Texture2D
var _beam: Texture2D
var _seg: Texture2D
var _tip: Texture2D
var _orbs: Dictionary = {}
var _medal: Texture2D
var _pearl: Texture2D
var _ship_bases: Array[Texture2D] = []
var _engine_idle: Texture2D
var _engine_power: Texture2D
var _shield: Texture2D
var _log: Texture2D
var _capsule: Texture2D
var _drone: Texture2D
var _rocket: Texture2D
var _ship_tint := Color(1, 1, 1)
## Cor da neblina do cenário (inimigos que sobem do fundo saem dela).
var _depth_tint := Color(0.45, 0.72, 0.92, 0.6)
var _bank: float = 0.0
var _wing_bank: float = 0.0
## Nível do hangar da nave e da ala (peças da ShipLivery).
var _livery: int = 1
var _wing_livery: int = 1
var _wake: Array[Vector2] = []
var _wake_clock: float = 0.0
var _emit_clock: float = 0.0
var _ticks: int = 0
var _nozzle: int = 0
## Clarão da boca do canhão (s restantes).
var _muzzle: float = 0.0
## As camadas dos poderes desenharam algo no último quadro (redesenha uma vez a mais para limpar).
var _power_drawn := false


func setup(p_sim: Sim) -> void:
	sim = p_sim
	_glow = SpriteBank.generated("fx/glow_32")
	_ring = SpriteBank.generated("fx/ring_32")
	_flare = SpriteBank.generated("fx/flare_64")
	for size: int in [80, 128, 192]:
		_blasts[size] = SpriteBank.texture("res://assets/art/oga/explosions/ansimuz_explosion_%d.png" % size)
	_shock = SpriteBank.generated("fx/shock_64")
	_sparkle = SpriteBank.generated("fx/sparkle_9")
	_beam = SpriteBank.generated("fx/beam")
	_seg = SpriteBank.generated("boss/tentacle_segment")
	_tip = SpriteBank.generated("boss/tentacle_tip")
	for weapon: StringName in Sim.ORB_WEAPONS:
		_orbs[weapon] = SpriteBank.generated("pickups/orb_" + String(weapon))
	_medal = SpriteBank.generated("pickups/medal")
	_pearl = SpriteBank.generated("pickups/pearl")
	_log = SpriteBank.generated("pickups/log")
	_capsule = SpriteBank.generated("pickups/capsule")
	dark = bool(sim.mission.get("dark", false))
	_drone = SpriteBank.generated("fx/drone")
	_rocket = SpriteBank.texture("res://assets/art/void/main_ship/proj_rocket.png")
	_ship_tint = Color(String(sim.player.ship.get("tint", "#ffffff")))
	var paint := Store.tint_of(String(sim.loadout.get("cosmetic", "")))
	if not paint.is_empty():
		_ship_tint = Color(paint)
	_livery = clampi(int(sim.loadout.get("ship_level", 1)), 1, Economy.SHIP_MAX_LEVEL)
	_wing_livery = clampi(int(sim.loadout.get("coop_level", 1)), 1, Economy.SHIP_MAX_LEVEL)
	for name: String in ["base_very_damaged", "base_damaged", "base_slight", "base_full"]:
		_ship_bases.append(SpriteBank.texture("res://assets/art/void/main_ship/%s.png" % name))
	_engine_idle = SpriteBank.texture("res://assets/art/void/main_ship/engine_base_idle.png")
	_engine_power = SpriteBank.texture("res://assets/art/void/main_ship/engine_base_powering.png")
	_shield = SpriteBank.texture("res://assets/art/void/main_ship/shield_invincibility.png")
	var scenery := OceanBackdrop.palette_of(StringName(String(sim.mission.get("backdrop", "ocean"))))
	var mid: Color = scenery["mid"]
	_depth_tint = Color(mid.lightened(0.35), 0.55)
	var flash := ShaderMaterial.new()
	flash.shader = load("res://shaders/sprite_flash.gdshader") as Shader
	var budget := int(GfxQuality.budget_at("particles_max", fx_level))
	fx.level = fx_level
	fx.reduce_flashes = reduce_flashes
	fx.ground = bool(scenery.get("shadows", true))
	fx.water = bool(scenery.get("bubbles", true)) and fx.ground
	fx.foam = scenery["foam"]
	fx.setup(int(budget * 0.7), int(budget * 0.3))
	_shadows = _Layer.new(self, _draw_shadows)
	# No espaço não há chão para receber sombra.
	_shadows.visible = fx.ground
	add_child(_shadows)
	_wrecks = _Layer.new(self, _draw_wrecks)
	add_child(_wrecks)
	_entities = _Layer.new(self, _draw_entities)
	_entities.material = flash
	add_child(_entities)
	add_child(fx.matter)
	_player_bullets = BulletRenderer.new()
	_player_bullets.halo_alpha = [0.0, 0.6, 0.85][clampi(fx_level, 0, 2)]
	_player_bullets.halo_scale = 3.6
	_player_bullets.setup(BulletKinds.PLAYER, sim.player_bullets.capacity)
	add_child(_player_bullets)
	_player = _Layer.new(self, _draw_player)
	_player.material = flash
	add_child(_player)
	_fx_below = _Layer.new(self, _draw_fx_below)
	add_child(_fx_below)
	powers.reduce_flashes = reduce_flashes
	powers.fx_level = fx_level
	powers.ship_texture = _ship_bases[3]
	powers.setup()
	# Onda e muralha repetem a textura na horizontal (rolagem da espuma e das runas).
	_power_below = _Layer.new(self, _draw_power_below)
	_power_below.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	add_child(_power_below)
	_fx_add = _Layer.new(self, _draw_fx_add)
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_fx_add.material = add
	_fx_add.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(_fx_add)
	_power_add = _Layer.new(self, _draw_power_add)
	_power_add.material = add
	_power_add.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_power_add.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	add_child(_power_add)
	add_child(fx.light)
	add_child(weather_slot)
	_enemy_bullets = BulletRenderer.new()
	_enemy_bullets.palette = colorblind
	# Halo discreto e só em Alta: centenas de balas somando luz não podem lavar o campo.
	_enemy_bullets.halo_alpha = 0.22 if fx_level >= 2 else 0.0
	_enemy_bullets.halo_scale = 2.4
	_enemy_bullets.setup(BulletKinds.ENEMY, sim.enemy_bullets.capacity)
	add_child(_enemy_bullets)
	_fx_above = _Layer.new(self, _draw_fx_above)
	add_child(_fx_above)


## Um quadro: avança os efeitos e redesenha tudo.
func refresh(delta: float) -> void:
	time += delta
	_age(explosions, delta)
	_age(rings, delta)
	_muzzle = maxf(0.0, _muzzle - delta)
	_emit_clock = minf(_emit_clock + delta, EMIT_STEP * 4.0)
	while _emit_clock >= EMIT_STEP:
		_emit_clock -= EMIT_STEP
		_emit()
	fx.advance(delta)
	powers.advance(sim, delta)
	_player_bullets.render(sim.player_bullets)
	_enemy_bullets.render(sim.enemy_bullets)
	var ease := 1.0 - exp(-delta * 12.0)
	_bank = lerpf(_bank, _bank_target(sim.player), ease)
	if sim.wing != null:
		_wing_bank = lerpf(_wing_bank, _bank_target(sim.wing), ease)
	_trail(delta)
	_shadows.queue_redraw()
	_wrecks.queue_redraw()
	_entities.queue_redraw()
	_player.queue_redraw()
	_fx_below.queue_redraw()
	_fx_add.queue_redraw()
	_fx_above.queue_redraw()
	# Sem poder vivo as camadas dos poderes ficam vazias (não custam desenho).
	var busy := powers.busy(sim)
	if busy or _power_drawn:
		_power_below.queue_redraw()
		_power_add.queue_redraw()
	_power_drawn = busy


func on_event(ev: Dictionary) -> void:
	var at: Vector2 = ev.get("pos", Vector2.ZERO)
	match StringName(ev["type"]):
		&"kill":
			var ship := SpriteBank.ship(StringName(ev.get("sprite", "")))
			var big := bool(ev.get("big", false))
			explosions.append({"tex": ship["destruction"], "frames": ship["destruction_frames"],
					"size": ship["destruction_size"], "pos": at, "t": 0.0, "scale": 1.0, "duration": EXPLOSION_TIME})
			fx.explosion(at, 1.7 if big else 1.0)
			fx.wreck(ship["base"], ship["size"], at, at + SHADOW_OFFSET * 1.4, 1.0)
			fx.popup(at, int(ev.get("points", 0)), UiTheme.GOLD if big else Color(1.0, 0.95, 0.82))
			_ring_at(at, 0.35, 46.0 if big else 28.0, Color(1.0, 0.7, 0.4))
		&"hit":
			fx.impact(at, _weapon_tint())
		&"graze":
			fx.graze(at)
		&"shot":
			_muzzle = 0.06
		&"player_hit":
			_ring_at(at, 0.5, 70.0, Color(1.0, 0.4, 0.4))
			fx.explosion(at, 0.8, Color(1.0, 0.4, 0.35, 0.9))
		&"capture":
			_ring_at(at, 0.45, 50.0, Color(0.4, 1.0, 1.0))
			fx.collect(at, Color(0.4, 1.0, 1.0), true)
		&"bomb", &"special":
			_ring_at(at, 0.7, 340.0, Color(0.6, 1.0, 1.0))
			_ring_at(at, 0.45, 160.0, Color(1.0, 1.0, 1.0))
			# Balas que estavam na tela e a Sim apagou neste passo viram brilho, em onda.
			var seen := _enemy_bullets.last_positions(180)
			if sim.enemy_bullets.count * 2 < seen.size():
				fx.cancel_wave(at, seen)
		&"boss_part":
			_blast(at, 80, 0.0, 1.0)
			fx.explosion(at, 2.0, Color(0.85, 0.55, 1.0, 0.9))
			fx.chain(at, Vector2(18, 14), 3, 0.3, 1.0)
			_ring_at(at, 0.4, 60.0, Color(0.85, 0.6, 1.0))
		&"boss_dead":
			var ship := SpriteBank.ship(StringName((sim.tables["bosses"] as Dictionary).get(StringName(ev["id"]), {})
					.get("sprite", "")))
			for k: int in range(5):
				var off := Vector2(cos(k * 2.4) * 40.0, sin(k * 1.7) * 28.0)
				explosions.append({"tex": ship["destruction"], "frames": ship["destruction_frames"],
						"size": ship["destruction_size"], "pos": at + off, "t": -k * 0.18, "scale": 1.6,
						"duration": 0.9})
			# Chefe de ato: a explosão grande (192 px) depois da cadeia; meio de fase: a de 128 px na hora.
			if bool(ev.get("final", false)):
				_blast(at, 192, -0.9, 1.2)
			else:
				_blast(at, 128, 0.0, 1.0)
			fx.explosion(at, 2.5)
			fx.chain(at, Vector2(60, 36), 6 + fx_level * 3, 1.3, 1.5)
			fx.later(1.35, fx.explosion.bind(at, 3.5, CombatFx.FIRE))
			_ring_at(at, 1.0, 400.0, Color(1, 1, 1))
			fx.later(1.35, _ring_at.bind(at, 0.9, 300.0, Color(1.0, 0.85, 0.5)))
		&"orb":
			var up := bool(ev.get("up", false))
			fx.collect(at, ORB_TINTS.get(StringName(ev.get("weapon", "")), Color(1, 1, 1)), up)
			if up:
				_ring_at(at, 0.4, 44.0, Color(1.0, 0.9, 0.5))
		&"medal":
			fx.collect(at, UiTheme.GOLD, false)
			fx.popup(at + Vector2(0, -12), int(ev.get("value", 0)), UiTheme.GOLD)
		&"pearl":
			fx.light.spawn(CombatFx.FLARE, at, Vector2.ZERO, 0.12, 0.15, 0.35, Color(0.6, 1.0, 1.0, 0.6),
					Color(0.6, 1.0, 1.0, 0.0))
		&"bomb_pickup", &"capsule", &"log", &"heal", &"revive":
			fx.collect(at, Color(0.5, 1.0, 0.9), true)
			_ring_at(at, 0.4, 40.0, Color(0.5, 1.0, 0.9))
			if StringName(ev["type"]) == &"heal":
				powers.heal_burst(fx, at)
		&"splash":
			_ring_at(at, 0.25, float(ev.get("radius", 20.0)), Color(0.8, 0.55, 1.0))
		&"power":
			_on_power(ev, at)
		&"power_blast":
			_on_power_blast(ev, at)


## Poder lançado: clarão e anel na cor da nave, maiores a cada nível.
func _on_power(ev: Dictionary, at: Vector2) -> void:
	var tier := int(ev.get("tier", 1))
	var def: Dictionary = (sim.tables.get("powers", {}) as Dictionary).get(StringName(String(ev.get("id", ""))), {})
	var col := Color(String(def.get("color", "#ffffff")))
	fx.collect(at, col, true)
	_ring_at(at, 0.3 + 0.12 * tier, 30.0 + 28.0 * tier, col)
	if tier >= 3:
		_ring_at(at, 0.7, 260.0, Color(1, 1, 1))
		fx.light.spawn(CombatFx.FLARE, at, Vector2.ZERO, 0.35, 1.0, 4.0, Color(1, 1, 1, 0.6 if reduce_flashes else 1.0),
				Color(col, 0.0))


## Explosão de um poder (artilharia, granada, supernova, eclipse): fogo do tamanho do raio, anel e, nas
## grandes, as balas apagadas viram brilho em onda.
func _on_power_blast(ev: Dictionary, at: Vector2) -> void:
	var radius := float(ev.get("radius", 40.0))
	var def: Dictionary = (sim.tables.get("powers", {}) as Dictionary).get(StringName(String(ev.get("id", ""))), {})
	var col := Color(String(def.get("color", "#ffffff")))
	if radius < 120.0:
		fx.explosion(at, clampf(radius / 30.0, 0.8, 2.4))
		_ring_at(at, 0.35, radius * 1.15, col.lerp(Color(1.0, 0.7, 0.4), 0.5))
		return
	_ring_at(at, 0.9, radius, Color(1, 1, 1))
	_ring_at(at, 0.6, radius * 0.55, col)
	fx.explosion(at, 2.5, col.lerp(CombatFx.FIRE, 0.4))
	var seen := _enemy_bullets.last_positions(180)
	if sim.enemy_bullets.count * 2 < seen.size():
		fx.cancel_wave(at, seen)


func _ring_at(at: Vector2, duration: float, radius: float, color: Color) -> void:
	rings.append({"pos": at, "t": 0.0, "duration": duration, "radius": radius, "color": color})


func _weapon_tint() -> Color:
	return WEAPON_TINTS.get(sim.player.weapon, Color(0.7, 0.9, 1.0))


## Emissores contínuos a 60 Hz: motor da nave, faíscas do laser, fumaça de quem está avariado e
## bolhas de quem sobe do fundo do mar.
func _emit() -> void:
	_ticks += 1
	var pl := sim.player
	powers.emit(sim, fx, _ticks)
	if pl.alive and fx_level >= 1:
		var thrust := 1.0 if pl.last_move.y < -0.3 else 0.0
		_nozzle = 1 - _nozzle
		fx.exhaust(pl.pos + NOZZLES[_nozzle], EXHAUST_COLOR, thrust)
		if sim.laser_active and _ticks % 2 == 0:
			fx.impact(Vector2(pl.pos.x, sim.laser_to_y), WEAPON_TINTS[&"laser"])
	if fx_level < 1:
		return
	for e: SimEnemy in sim.enemies:
		if e.depth < 1.0:
			if fx.water and (_ticks + e.frames) % 5 == 0:
				fx.bubbles(e.pos)
		elif e.hp < e.max_hp * 0.4 and (_ticks + e.frames) % 6 == 0:
			fx.damage_smoke(e.pos)
	if sim.boss != null and sim.boss.state == SimBoss.State.DYING and _ticks % 7 == 0:
		var body := sim.boss.body_pos()
		fx.explosion(body + Vector2(sin(time * 13.0) * 60.0, cos(time * 7.0) * 30.0), 0.8)


func _age(list: Array[Dictionary], delta: float) -> void:
	var i := list.size() - 1
	while i >= 0:
		var e := list[i]
		e["t"] = float(e["t"]) + delta
		if float(e["t"]) >= float(e["duration"]):
			list.remove_at(i)
		i -= 1


# --- Sombras no chão (2,5D) ------------------------------------------------------------------

## Inclinação desejada da nave: o passo lateral da Sim (unidades/passo), limitado a -1..1.
func _bank_target(pl: SimPlayer) -> float:
	if reduce_motion or not pl.alive:
		return 0.0
	# A turbulência (Weather) balança as asas da nave 1 junto com o tranco.
	var wobble := sim.weather.shake.x * 0.35 if pl == sim.player else 0.0
	return clampf(pl.last_move.x / 2.5 + wobble, -1.0, 1.0)


## Quanto um inimigo já subiu do fundo (0 = no chão, 1 = no campo de jogo), suavizado.
static func rise_of(depth: float) -> float:
	var u := clampf((depth - SimEnemy.DEPTH_START) / (1.0 - SimEnemy.DEPTH_START), 0.0, 1.0)
	return u * u * (3.0 - 2.0 * u)


func _draw_shadows(ci: CanvasItem) -> void:
	for e: SimEnemy in sim.enemies:
		var rise := rise_of(e.depth)
		var s := float(e.def.get("scale", 1.0)) * lerpf(RISE_SCALE, 1.0, rise)
		_shadow(ci, SpriteBank.ship(e.sprite), e.pos, s, rise, PI)
	for esc: Dictionary in sim.escorts:
		_shadow(ci, SpriteBank.ship(StringName(String(esc["sprite"]))), esc["pos"], 0.6, 1.0, 0.0)
	if sim.boss != null:
		var b := sim.boss
		var scale := float(b.def.get("scale", 1.0))
		_shadow(ci, SpriteBank.ship(StringName(String(b.def.get("sprite", "")))), b.pos, scale, 1.6, PI)
		for part: Dictionary in b.parts:
			if part.has("sprite") and bool(part["alive"]):
				_shadow(ci, SpriteBank.ship(StringName(String(part["sprite"]))), b.part_pos(part),
						float(part.get("part_scale", 1.0)), 1.6, PI)
	var pl := sim.player
	if pl.alive:
		_shadow_tex(ci, _ship_bases[3], pl.pos, Vector2(1.0 - BANK_SQUEEZE * absf(_bank), 1.0), 1.0, _bank * BANK_ROT)
	if sim.wing != null and sim.wing.alive:
		_shadow_tex(ci, _ship_bases[3], sim.wing.pos, Vector2(1.0 - BANK_SQUEEZE * absf(_wing_bank), 1.0), 1.0,
				_wing_bank * BANK_ROT)


func _shadow(ci: CanvasItem, ship: Dictionary, pos: Vector2, scale: float, height: float, angle: float) -> void:
	var base: Texture2D = ship.get("base")
	if base == null:
		return
	var size: int = ship["size"]
	var s := scale * SHADOW_SCALE
	ci.draw_set_transform(pos + SHADOW_OFFSET * height, angle, Vector2(s, s))
	ci.draw_texture_rect_region(base, Rect2(-size * 0.5, -size * 0.5, size, size), Rect2(0, 0, size, size),
			Color(SHADOW_COLOR, SHADOW_COLOR.a * clampf(height, 0.25, 1.0)))
	ci.draw_set_transform(Vector2.ZERO)


func _shadow_tex(ci: CanvasItem, tex: Texture2D, pos: Vector2, squeeze: Vector2, height: float, angle: float) -> void:
	if tex == null:
		return
	ci.draw_set_transform(pos + SHADOW_OFFSET * height, angle, squeeze * SHADOW_SCALE)
	ci.draw_texture(tex, -tex.get_size() * 0.5, SHADOW_COLOR)
	ci.draw_set_transform(Vector2.ZERO)


# --- Entidades -------------------------------------------------------------------------------

func _draw_entities(ci: CanvasItem) -> void:
	for e: SimEnemy in sim.enemies:
		var tint := Color(String(e.def.get("tint", "#ffffff")))
		_draw_ship(ci, SpriteBank.ship(e.sprite), e.pos, e.depth, e.flash > 0, float(e.def.get("scale", 1.0)), tint)
		if e.marked and sim.mods.chart and e.depth >= 1.0:
			# Carta de Nereu: losango dourado sobre os marcados.
			var m := e.pos + Vector2(0, -e.radius - 8.0)
			ci.draw_rect(Rect2(m - Vector2(1, 3), Vector2(2, 6)), UiTheme.GOLD)
			ci.draw_rect(Rect2(m - Vector2(3, 1), Vector2(6, 2)), UiTheme.GOLD)
	if sim.boss != null:
		_draw_boss(ci, sim.boss)
	for pk: Dictionary in sim.pickups:
		var p: Vector2 = pk["pos"]
		match StringName(pk["kind"]):
			&"orb":
				var tex: Texture2D = _orbs[Sim.orb_weapon(int(pk["frames"]))]
				var pulse := 1.0 + 0.12 * sin(time * 8.0)
				_tex_centered(ci, tex, p, pulse)
			&"power":
				# Núcleo de força: o orbe da arma atual, maior, num halo dourado.
				_tex_centered(ci, _glow, p, 1.0 + 0.25 * sin(time * 7.0), Color(UiTheme.GOLD, 0.6))
				_tex_centered(ci, _orbs[sim.player.weapon] if _orbs.has(sim.player.weapon) else _pearl, p,
						1.3 + 0.12 * sin(time * 8.0))
			&"medal":
				var squash := absf(cos(time * 5.0 + p.x))
				ci.draw_set_transform(p, 0.0, Vector2(maxf(0.2, squash), 1.0))
				ci.draw_texture(_medal, -_medal.get_size() * 0.5)
				ci.draw_set_transform(Vector2.ZERO)
			&"log":
				_tex_centered(ci, _glow, p, 0.9 + 0.2 * sin(time * 6.0), Color(0.4, 1.0, 0.9, 0.5))
				_tex_centered(ci, _log, p, 1.0)
			&"capsule":
				_tex_centered(ci, _glow, p, 0.8 + 0.2 * sin(time * 8.0), Color(1.0, 0.85, 0.4, 0.55))
				_tex_centered(ci, _capsule, p, 1.0)
			_:
				_tex_centered(ci, _pearl, p, 1.0)
	for m: Dictionary in sim.missiles:
		var mp: Vector2 = m["pos"]
		var angle := (m["vel"] as Vector2).angle() + PI * 0.5
		if _rocket != null:
			var rh := _rocket.get_height()
			ci.draw_set_transform(mp, angle)
			ci.draw_texture_rect_region(_rocket, Rect2(-rh * 0.5, -rh * 0.5, rh, rh),
					SpriteBank.frame_rect(int(time * ANIM_FPS) % maxi(1, _rocket.get_width() / rh), rh))
			ci.draw_set_transform(Vector2.ZERO)
	for d: Vector2 in sim.drones:
		_tex_centered(ci, _drone, d, 1.0)
	for esc: Dictionary in sim.escorts:
		# Escolta capturada: o inimigo dominado, menor e em ciano; pisca no último segundo.
		var fading := int(esc["frames"]) < 60 and int(time * 10.0) % 2 == 0
		var col := Color(0.55, 1.0, 1.0, 0.45 if fading else 0.95)
		_draw_ship(ci, SpriteBank.ship(StringName(String(esc["sprite"]))), esc["pos"], 1.0, false, 0.6, col, true)


func _draw_ship(ci: CanvasItem, ship: Dictionary, pos: Vector2, depth: float, flash: bool, scale: float,
		tint: Color = Color(1, 1, 1), up: bool = false) -> void:
	var size: int = ship["size"]
	var base: Texture2D = ship["base"]
	if base == null:
		return
	var s := scale
	var modulate := tint
	if depth < 1.0:
		# Subindo do fundo: pequeno e na cor da neblina; a Sim só liga a colisão em depth 1.
		var rise := rise_of(depth)
		s *= lerpf(RISE_SCALE, 1.0, rise)
		modulate = _depth_tint.lerp(tint, rise)
	if flash:
		modulate = Color(1.8, 1.8, 1.8)
	ci.draw_set_transform(pos, 0.0 if up else PI, Vector2(s, s))
	var half := Vector2(size, size) * 0.5
	var engine: Texture2D = ship["engine"]
	if engine != null:
		var f := int(time * ANIM_FPS) % int(ship["engine_frames"])
		ci.draw_texture_rect_region(engine, Rect2(-half, half * 2.0), SpriteBank.frame_rect(f, size), modulate)
	ci.draw_texture_rect_region(base, Rect2(-half, half * 2.0), Rect2(0, 0, size, size), modulate)
	ci.draw_set_transform(Vector2.ZERO)


func _draw_boss(ci: CanvasItem, b: SimBoss) -> void:
	var ship := SpriteBank.ship(StringName(String(b.def.get("sprite", ""))))
	var scale := float(b.def.get("scale", 1.0))
	var body := b.body_pos()
	# Tentáculos atrás do corpo: segmentos numa curva da base até a ponta (a ponta é a parte da Sim).
	for part: Dictionary in b.parts:
		var tid := String(part["id"])
		if not tid.begins_with("t") or not tid.substr(1).is_valid_int():
			continue
		var tip := b.part_pos(part)
		var root := body + Vector2((part["base"] as Vector2).x * 0.32, 18.0)
		var alive := bool(part["alive"])
		var segments := 11 if alive else 3
		var color := Color(1, 1, 1) if alive else Color(0.45, 0.4, 0.5)
		if int(part["flash"]) > 0:
			color = Color(1.8, 1.8, 1.8)
		var ctrl := root + Vector2(0, 56)
		for k: int in range(segments):
			var u := float(k) / 11.0
			var p := root.lerp(ctrl, u).lerp(ctrl.lerp(tip, u), u)
			_tex_centered(ci, _seg, p, 1.0 - u * 0.25, color)
		if alive:
			_tex_centered(ci, _tip, tip, 1.0, color)
	_draw_boss_parts(ci, b, body)
	_draw_ship(ci, ship, b.pos, 1.0, b.flash > 0, scale, Color(String(b.def.get("tint", "#ffffff"))))
	var pulse := 0.6 + 0.4 * sin(time * 9.0)
	for part: Dictionary in b.parts:
		var pid := String(part["id"])
		if (pid.begins_with("eye") or pid == "core") and b.part_active(part):
			var col := Color(1.0, 0.35, 0.4, pulse) if pid.begins_with("eye") else Color(0.4, 1.0, 1.0, pulse)
			_tex_centered(ci, _glow, b.part_pos(part), 0.6 + float(part.get("radius", 10.0)) / 20.0, col)


## Partes genéricas dos chefes do Beta: corrente de segmentos (Sky Leviathan) ligada do corpo à
## cauda, anéis de escudo girando (Poseidon Prime) e núcleos com sprite próprio (Leviathan Protocol).
func _draw_boss_parts(ci: CanvasItem, b: SimBoss, body: Vector2) -> void:
	var prev := body
	for part: Dictionary in b.parts:
		var at := b.part_pos(part)
		var alive := bool(part["alive"])
		var color := Color(1.8, 1.8, 1.8) if int(part["flash"]) > 0 else Color(String(b.def.get("tint", "#ffffff")))
		if not alive:
			color = Color(0.4, 0.38, 0.45)
		if bool(part.get("chain", false)):
			for k: int in range(1, 4):
				_tex_centered(ci, _seg, prev.lerp(at, k / 4.0), 0.8, Color(color, 0.9))
			prev = at
		if part.has("sprite") and (alive or bool(part.get("chain", false))):
			var s := float(part.get("part_scale", 1.0))
			_draw_ship(ci, SpriteBank.ship(StringName(String(part["sprite"]))), at, 1.0, int(part["flash"]) > 0, s, color)
		elif bool(part.get("ring", false)) and alive:
			ci.draw_set_transform(at, time * (2.0 if b.part_active(part) else 0.4), Vector2(0.5, 0.5))
			ci.draw_texture(_ring, -_ring.get_size() * 0.5, Color(1.0, 0.85, 0.4, 0.9 if b.part_active(part) else 0.35))
			ci.draw_set_transform(Vector2.ZERO)


# --- Jogador -----------------------------------------------------------------------------------

## Ala do co-op: a mesma nave com a cor dela e, perto da nave 1, o Elo de Maré (linha que apaga balas).
func _draw_wing(ci: CanvasItem, w: SimPlayer, blink: bool) -> void:
	if sim.linked:
		var a := sim.player.pos
		var flick := 0.55 + 0.25 * sin(time * 18.0)
		ci.draw_line(a, w.pos, Color(TIDE_COLOR, flick), 2.0)
		_tex_centered(ci, _glow, (a + w.pos) * 0.5, 0.6, Color(TIDE_COLOR, 0.6))
	var col := Color(Color(String(w.ship.get("tint", "#9fe8ff"))), 0.45 if blink else 1.0)
	var engine := _engine_power if w.last_move.y < -0.3 else _engine_idle
	var frames := maxi(1, engine.get_width() / 48)
	var tint := Color(col, 1.0)
	_bank_transform(ci, w.pos, _wing_bank)
	ci.draw_texture_rect_region(engine, Rect2(-24, -24, 48, 48),
			SpriteBank.frame_rect(int(time * ANIM_FPS) % frames, 48), col)
	ShipLivery.draw_under(ci, _wing_livery, tint, time, col.a, w.last_move.y < -0.3, reduce_flashes)
	ci.draw_texture(_ship_bases[3], Vector2(-24, -24), col)
	ShipLivery.draw_over(ci, _wing_livery, tint, time, col.a, reduce_flashes)
	ci.draw_set_transform(Vector2.ZERO)
	ci.draw_string(Locale.font, w.pos + Vector2(-4, 30), "2", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, col)

func _draw_player(ci: CanvasItem) -> void:
	var pl := sim.player
	if not pl.alive:
		return
	var p := pl.pos
	if sim.laser_active:
		var w := sim.laser_width * 1.6
		var top := sim.laser_to_y
		var flicker := 0.85 + 0.15 * sin(time * 50.0)
		# Só o núcleo; o brilho largo e os pulsos vêm da camada aditiva (_draw_fx_add).
		ci.draw_texture_rect(_beam, Rect2(p.x - w * 0.5, top, w, p.y - 14.0 - top), false,
				Color(LASER_COLOR, LASER_COLOR.a * flicker))
		ci.draw_texture_rect(_beam, Rect2(p.x - w * 0.18, top, w * 0.36, p.y - 14.0 - top), false, Color(1, 1, 1, 0.9))
	var hull_frac := float(pl.hull) / maxf(1.0, float(pl.max_hull))
	var base := _ship_bases[clampi(int(ceil(hull_frac * 3.0)), 0, 3)]
	# Durante um poder a invulnerabilidade é do poder: o escudo aparece, a nave não pisca.
	var blink := pl.invuln > 0 and int(time * 20.0) % 2 == 0 and sim.power_fx.is_empty()
	var col := Color(_ship_tint, 0.45 if blink else 1.0)
	if PowerView.has_active(sim, &"cloak"):
		# Manto (Umbra, Ascensão): a nave fica translúcida e tremeluz.
		col.a = 0.38 + 0.14 * sin(time * 23.0)
	if sim.tide_frames > 0:
		var pulse := 1.0 + 0.15 * sin(time * 12.0)
		_tex_centered(ci, _ring, p, Sim.TIDE_RADIUS / 14.0 * pulse, TIDE_COLOR)
	if sim.mods.bubbles > 0:
		_tex_centered(ci, _ring, p, 1.2, Color(0.7, 0.95, 1.0, 0.45))
	if sim.wing != null:
		_draw_wing(ci, sim.wing, blink)
	if ghost_sim != null and ghost_sim.player.alive:
		ci.draw_texture(_ship_bases[3], ghost_sim.player.pos - Vector2(24, 24), Color(0.5, 1.0, 1.0, 0.3))
	_draw_wake(ci, col.a)
	var thrust := pl.last_move.y < -0.3
	var engine := _engine_power if thrust else _engine_idle
	var frames := maxi(1, engine.get_width() / 48)
	_bank_transform(ci, p, _bank)
	ci.draw_texture_rect_region(engine, Rect2(-24, -24, 48, 48),
			SpriteBank.frame_rect(int(time * ANIM_FPS) % frames, 48), col)
	ShipLivery.draw_under(ci, _livery, _ship_tint, time, col.a, thrust, reduce_flashes)
	ci.draw_texture(base, Vector2(-24, -24), col)
	ShipLivery.draw_over(ci, _livery, _ship_tint, time, col.a, reduce_flashes)
	ci.draw_set_transform(Vector2.ZERO)
	if pl.invuln > 0 and _shield != null:
		var sf := int(time * ANIM_FPS) % maxi(1, _shield.get_width() / 64)
		ci.draw_texture_rect_region(_shield, Rect2(p - Vector2(32, 32), Vector2(64, 64)), SpriteBank.frame_rect(sf, 64),
				Color(1, 1, 1, 0.7))
	if touching:
		ci.draw_rect(Rect2(p - Vector2(2.5, 2.5), Vector2(5, 5)), Color(0.08, 0.07, 0.09))
		ci.draw_rect(Rect2(p - Vector2(1.5, 1.5), Vector2(3, 3)), Color(1, 1, 1))


## Rastro da Ascendida: guarda a posição da nave a cada WAKE_STEP s (só desenho; qualidade Baixa não tem).
func _trail(delta: float) -> void:
	if _livery < Economy.SHIP_MAX_LEVEL or fx_level < 1 or not sim.player.alive:
		_wake.clear()
		return
	_wake_clock += delta
	if _wake_clock < WAKE_STEP:
		return
	_wake_clock = 0.0
	_wake.push_front(sim.player.pos + Vector2(0, 12))
	if _wake.size() > WAKE_LEN:
		_wake.pop_back()


## Centelhas de ouro que ficam para trás, menores e mais apagadas quanto mais velhas.
func _draw_wake(ci: CanvasItem, alpha: float) -> void:
	for i: int in range(_wake.size()):
		var k := 1.0 - float(i) / float(WAKE_LEN)
		var drift := Vector2(sin(time * 3.0 + float(i)) * 1.5, float(i) * 1.2)
		_tex_centered(ci, _glow, _wake[i] + drift, 0.22 * k, Color(ShipLivery.GOLD, 0.45 * k * alpha))
		ci.draw_rect(Rect2(_wake[i] + drift - Vector2(0.5, 0.5), Vector2(1, 1)), Color(1, 0.95, 0.75, 0.8 * k * alpha))


## Nave inclinada na curva: gira um pouco e estreita (a asa de dentro "abaixa").
func _bank_transform(ci: CanvasItem, at: Vector2, bank: float) -> void:
	ci.draw_set_transform(at, bank * BANK_ROT, Vector2(1.0 - BANK_SQUEEZE * absf(bank), 1.0))


# --- Efeitos -------------------------------------------------------------------------------------

func _draw_fx_below(ci: CanvasItem) -> void:
	for c: Dictionary in sim.covers:
		var r := Hazards.cover_rect(c)
		ci.draw_rect(r, COVER_COLOR)
		ci.draw_rect(Rect2(r.position, Vector2(r.size.x, 2.0)), COVER_TRIM)
		for wy: int in range(int(r.position.y) + 8, int(r.end.y) - 4, 12):
			ci.draw_rect(Rect2(r.position.x + 5.0, wy, r.size.x - 10.0, 2.0), Color(1.0, 0.85, 0.5, 0.35))
	if sim.breach_frames > 0:
		_draw_breach(ci)
	for b: Dictionary in sim.beams:
		var x := float(b["x"])
		var y := float(b["y"])
		var w := float(b["width"])
		var length := Playfield.FIELD.y + 40.0 - y
		if int(b["age"]) < int(b["warn"]):
			var on := floori(int(b["age"]) / 4.0) % 2 == 0
			var a := WARN_COLOR.a * (1.0 if on else 0.35)
			ci.draw_rect(Rect2(x - w * 0.5, y, 1.0, length), Color(WARN_COLOR, a))
			ci.draw_rect(Rect2(x + w * 0.5 - 1.0, y, 1.0, length), Color(WARN_COLOR, a))
			ci.draw_rect(Rect2(x - 0.5, y, 1.0, length), Color(WARN_COLOR, a * 0.5))
		elif String(b.get("kind", "")) == "lightning":
			_draw_lightning(ci, x, y, w, length, int(b["age"]))
		elif HAZARD_COLORS.has(String(b.get("kind", ""))):
			var hc: Color = HAZARD_COLORS[String(b["kind"])]
			var wob := 0.85 + 0.15 * sin(time * 30.0 + x)
			ci.draw_texture_rect(_beam, Rect2(x - w * 0.6, y, w * 1.2, length), false, Color(hc, hc.a * wob))
		else:
			ci.draw_texture_rect(_beam, Rect2(x - w * 0.6, y, w * 1.2, length), false, BEAM_COLOR)
	if sim.boss != null and sim.boss.state == SimBoss.State.DUEL:
		_draw_duel(ci, sim.boss)
	for e: Dictionary in explosions:
		var t := float(e["t"])
		if t < 0.0 or e["tex"] == null:
			continue
		var frames: int = e["frames"]
		var size: int = e["size"]
		var f := mini(frames - 1, int(t / float(e["duration"]) * frames))
		var s := float(e["scale"])
		ci.draw_set_transform(e["pos"], float(e.get("rot", PI)), Vector2(s, s))
		ci.draw_texture_rect_region(e["tex"], Rect2(-size * 0.5, -size * 0.5, size, size), SpriteBank.frame_rect(f, size))
		ci.draw_set_transform(Vector2.ZERO)


## Explosão de chefe em pixel art: a folha toca uma vez, de pé, a partir de `delay` segundos.
func _blast(at: Vector2, size: int, delay: float, zoom: float) -> void:
	var tex: Texture2D = _blasts.get(size)
	if tex == null:
		return
	explosions.append({"tex": tex, "frames": maxi(1, tex.get_width() / size), "size": size, "pos": at, "t": delay,
			"scale": zoom, "duration": 0.05 * tex.get_width() / size, "rot": 0.0})


## Gravity Breach: grade que escorre na direção da força e uma seta no centro (aviso de leitura).
func _draw_breach(ci: CanvasItem) -> void:
	var dir := sim.breach_dir.normalized()
	var shift := fposmod(time * 40.0, 24.0)
	for k: int in range(-1, int(Playfield.FIELD.x / 24.0) + 2):
		var gx := k * 24.0 + dir.x * shift
		ci.draw_rect(Rect2(gx, 0, 1.0, Playfield.FIELD.y), BREACH_COLOR)
	for k: int in range(-1, int(Playfield.FIELD.y / 24.0) + 2):
		var gy := k * 24.0 + dir.y * shift
		ci.draw_rect(Rect2(0, gy, Playfield.FIELD.x, 1.0), BREACH_COLOR)
	var c := Playfield.FIELD * 0.5
	for k: int in range(5):
		var p := c + dir * (k * 6.0 - 12.0)
		ci.draw_rect(Rect2(p - Vector2(2, 2), Vector2(4, 4)), Color(0.85, 0.7, 1.0, 0.25 + 0.12 * k))


## Raio da tempestade: zigue-zague de segmentos (retângulos) com brilho, sorteado por passo.
func _draw_lightning(ci: CanvasItem, x: float, y: float, w: float, length: float, age: int) -> void:
	var seed := age / 3
	var steps := 14
	var prev := Vector2(x, y)
	if not reduce_flashes and age % 6 < 3:
		ci.draw_rect(Rect2(x - w, y, w * 2.0, length), Color(LIGHTNING_COLOR, 0.12))
	for i: int in range(1, steps + 1):
		var jitter := float(absi(hash(seed * 31 + i * 7)) % 100) / 100.0 - 0.5
		var next := Vector2(x + jitter * w * 0.9, y + length * i / steps)
		var top := minf(prev.y, next.y)
		ci.draw_rect(Rect2(minf(prev.x, next.x) - 1.5, top, absf(next.x - prev.x) + 3.0, 3.0), LIGHTNING_COLOR)
		ci.draw_rect(Rect2(next.x - 1.5, top, 3.0, next.y - top), LIGHTNING_COLOR)
		prev = next
	_tex_centered(ci, _glow, Vector2(x, y + 8.0), 1.0, Color(LIGHTNING_COLOR, 0.6))


func _draw_duel(ci: CanvasItem, b: SimBoss) -> void:
	var top := b.body_pos()
	var bottom := sim.player.pos
	var meet := top.lerp(bottom, 1.0 - b.duel_power)
	var shake := sin(time * 60.0) * 2.0
	ci.draw_texture_rect(_beam, Rect2(top.x - 16.0 + shake, top.y, 32.0, meet.y - top.y), false, BEAM_COLOR)
	ci.draw_texture_rect(_beam, Rect2(bottom.x - 18.0 - shake, meet.y, 36.0, bottom.y - meet.y), false, LASER_COLOR)
	_tex_centered(ci, _glow, meet, 1.4 + 0.3 * sin(time * 30.0), Color(1, 1, 1, 0.95))
	if int(time * 30.0) % 3 == 0:
		fx.impact(meet, Color(1.0, 0.9, 0.6))


## Luz aditiva, abaixo das balas inimigas: laser, motores, boca do canhão, halos dos coletáveis, luz
## das explosões, brilho dos feixes e anéis de choque. Soma luz, nunca escurece; o filtro linear deixa
## os clarões macios por cima da pixel art.
func _draw_fx_add(ci: CanvasItem) -> void:
	var pl := sim.player
	var flicker := 0.85 + 0.15 * sin(time * 50.0)
	if pl.alive:
		var p := pl.pos
		if sim.laser_active:
			var w := sim.laser_width * 1.6
			var top := sim.laser_to_y
			var length := p.y - 14.0 - top
			ci.draw_texture_rect(_beam, Rect2(p.x - w * 2.2, top, w * 4.4, length), false,
					Color(0.25, 0.75, 1.0, 0.4 * flicker))
			ci.draw_texture_rect(_beam, Rect2(p.x - w * 0.9, top, w * 1.8, length), false, Color(0.6, 1.0, 1.0, 0.6))
			# Pulsos correndo para cima ao longo do feixe.
			if fx_level >= 1:
				for k: int in range(8):
					var y := p.y - 14.0 - fposmod(time * 520.0 + k * 41.0, maxf(1.0, length))
					_tex_centered(ci, _flare, Vector2(p.x, y), w / 40.0, Color(0.6, 1.0, 1.0, 0.45))
			_tex_centered(ci, _flare, Vector2(p.x, top), (w / 20.0) * (0.9 + 0.2 * sin(time * 40.0)),
					Color(0.6, 1.0, 1.0, 0.9))
			_tex_centered(ci, _flare, Vector2(p.x, p.y - 16.0), w / 24.0, Color(0.8, 1.0, 1.0, 0.8))
		var thrust := 1.0 if pl.last_move.y < -0.3 else 0.0
		for n: Vector2 in NOZZLES:
			_tex_centered(ci, _flare, p + n, (0.28 + 0.12 * thrust) * (0.85 + 0.15 * sin(time * 37.0 + n.x)),
					Color(EXHAUST_COLOR, 0.75))
		if _muzzle > 0.0:
			var tint := _weapon_tint()
			_tex_centered(ci, _flare, p + Vector2(0, -21), 0.42, Color(tint, 0.9 * _muzzle / 0.06))
			_tex_centered(ci, _sparkle, p + Vector2(0, -21), 1.6, Color(1, 1, 1, _muzzle / 0.06))
	if fx_level >= 1:
		for e: SimEnemy in sim.enemies:
			if e.depth >= 1.0:
				var size := float(SpriteBank.ship(e.sprite)["size"]) * float(e.def.get("scale", 1.0))
				_tex_centered(ci, _flare, e.pos + Vector2(0, -size * 0.36), size / 150.0,
						Color(1.0, 0.45, 0.3, 0.35 * flicker))
	for pk: Dictionary in sim.pickups:
		var at: Vector2 = pk["pos"]
		match StringName(pk["kind"]):
			&"orb":
				var tint: Color = ORB_TINTS.get(Sim.orb_weapon(int(pk["frames"])), Color(1, 1, 1))
				_tex_centered(ci, _flare, at, 0.55 + 0.08 * sin(time * 8.0), Color(tint, 0.6))
			&"power":
				_tex_centered(ci, _flare, at, 0.8 + 0.1 * sin(time * 8.0), Color(UiTheme.GOLD, 0.7))
			&"medal":
				_tex_centered(ci, _flare, at, 0.35, Color(UiTheme.GOLD, 0.45))
				var glint := fposmod(time * 1.6 + at.x * 0.05, 1.0)
				if glint < 0.25:
					_tex_centered(ci, _sparkle, at + Vector2(-3, -3), 1.5 * sin(glint / 0.25 * PI), Color(1, 1, 1, 0.9))
			&"pearl":
				_tex_centered(ci, _flare, at, 0.18, Color(0.6, 1.0, 1.0, 0.45))
	for e: Dictionary in explosions:
		var t := float(e["t"])
		if t >= 0.0:
			var u := t / float(e["duration"])
			_tex_centered(ci, _flare, e["pos"], float(e["scale"]) * (1.2 + u), Color(1.0, 0.55, 0.2, 0.5 * (1.0 - u)))
	for b: Dictionary in sim.beams:
		if int(b["age"]) >= int(b["warn"]) and String(b.get("kind", "")) != "lightning":
			var hc: Color = HAZARD_COLORS.get(String(b.get("kind", "")), BEAM_COLOR)
			var bw := float(b["width"])
			var by := float(b["y"])
			ci.draw_texture_rect(_beam, Rect2(float(b["x"]) - bw * 1.4, by, bw * 2.8, Playfield.FIELD.y + 40.0 - by),
					false, Color(hc, 0.3 * flicker))
	for r: Dictionary in rings:
		var u := float(r["t"]) / float(r["duration"])
		var radius := float(r["radius"]) * (1.0 - (1.0 - u) * (1.0 - u))
		var alpha := (1.0 - u) * (0.5 if reduce_flashes else 0.95)
		ci.draw_texture_rect(_shock, Rect2((r["pos"] as Vector2) - Vector2(radius, radius), Vector2(radius, radius) * 2.0),
				false, Color(r["color"] as Color, alpha))


func _draw_power_below(ci: CanvasItem) -> void:
	powers.draw_below(ci, sim)


func _draw_power_add(ci: CanvasItem) -> void:
	powers.draw_add(ci, sim)


## Destroços caindo: a nave abatida gira, encolhe e escurece até a sombra no chão (CombatFx.wreck).
func _draw_wrecks(ci: CanvasItem) -> void:
	for w: Dictionary in fx.wrecks:
		var u := minf(1.0, float(w["t"]) / CombatFx.WRECK_TIME)
		var size: int = w["size"]
		var s := float(w["scale"]) * lerpf(0.9, 0.4, u)
		var shade := lerpf(0.55, 0.12, u)
		ci.draw_set_transform(w["pos"], PI + float(w["spin"]) * float(w["t"]), Vector2(s, s))
		ci.draw_texture_rect_region(w["tex"], Rect2(-size * 0.5, -size * 0.5, size, size), Rect2(0, 0, size, size),
				Color(shade, shade * 1.05, shade * 1.15, 1.0 - u * 0.6))
	ci.draw_set_transform(Vector2.ZERO)


## Por cima das balas só o que não atrapalha a leitura: a escuridão do Registro Abissal e os números
## de pontos (pequenos, sobem e somem em 0,75 s).
func _draw_fx_above(ci: CanvasItem) -> void:
	if dark and sim.player.alive:
		_draw_dark(ci)
	if not sim.power_fx.is_empty():
		powers.draw_above(ci, sim)
	for pop: Dictionary in fx.popups:
		var u := float(pop["t"]) / 0.75
		var pop_scale := 1.0 + 0.5 * maxf(0.0, 1.0 - u * 6.0)
		var col: Color = pop["color"]
		var alpha := 1.0 - maxf(0.0, u - 0.55) / 0.45
		var text := String(pop["text"])
		var size := int(round(8.0 * pop_scale))
		var at := (pop["pos"] as Vector2) + Vector2(-40, 3)
		ci.draw_string_outline(Locale.font, at, text, HORIZONTAL_ALIGNMENT_CENTER, 80, size, 3,
				Color(0.02, 0.04, 0.08, 0.8 * alpha))
		ci.draw_string(Locale.font, at, text, HORIZONTAL_ALIGNMENT_CENTER, 80, size, Color(col, alpha))


## Escuridão do Registro Abissal: só um halo em volta da nave e o pulso do sonar a cada 2 s.
func _draw_dark(ci: CanvasItem) -> void:
	var p := sim.player.pos
	var halo := 70.0
	var shade := Color(0.0, 0.01, 0.03, 0.86)
	var f := Playfield.FIELD
	ci.draw_rect(Rect2(0, 0, f.x, maxf(0.0, p.y - halo)), shade)
	ci.draw_rect(Rect2(0, p.y + halo, f.x, maxf(0.0, f.y - p.y - halo)), shade)
	ci.draw_rect(Rect2(0, p.y - halo, maxf(0.0, p.x - halo), halo * 2.0), shade)
	ci.draw_rect(Rect2(p.x + halo, p.y - halo, maxf(0.0, f.x - p.x - halo), halo * 2.0), shade)
	var ping := fmod(time, 2.0) / 2.0
	_tex_centered(ci, _ring, p, 1.0 + ping * 9.0, Color(0.4, 1.0, 0.9, 0.5 * (1.0 - ping)))


func _tex_centered(ci: CanvasItem, tex: Texture2D, at: Vector2, scale: float, color: Color = Color(1, 1, 1)) -> void:
	if tex == null:
		return
	var size := tex.get_size() * scale
	ci.draw_texture_rect(tex, Rect2(at - size * 0.5, size), false, color)


## Camada desenhada por um Callable do WorldView (mantém a ordem de desenho em nós separados).
class _Layer:
	extends Node2D

	var _painter: Callable

	func _init(_owner: Node, painter: Callable) -> void:
		_painter = painter

	func _draw() -> void:
		_painter.call(self)
