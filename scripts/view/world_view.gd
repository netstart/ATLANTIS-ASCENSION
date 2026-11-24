class_name WorldView
extends Node2D
## Desenho do campo de jogo a partir da Sim (só leitura). Camadas, de baixo para cima:
##   navios na água (SeaView: def "layer" "sea", esteira, sem sombra) →
##   sombras no chão → destroços caindo → entidades (inimigos, chefe, coletáveis) → fumaça e estilhaços →
##   tiros do jogador (com halo) → nave → efeitos de baixo (avisos e feixes do cenário, explosões, duelo) →
##   luz aditiva (bocal do laser, motores, clarões, anéis de choque) → laser e fluxo solar (EnergyStream) →
##   feixes inimigos (HostileBeams) → poderes aditivos → faíscas e brilhos (CombatFx) →
##   balas inimigas (sempre por cima: leitura) → efeitos de cima (escuridão, números de pontos).
## Só texturas e retângulos por quadro (docs/policies/qualidade.md); partículas em MultiMesh
## (ParticleField). Efeitos vivem aqui, não na Sim: qualidade gráfica e "reduzir flashes" nunca
## mudam a partida.
## 2,5D: cada nave tem uma sombra (cópia escura do sprite, 80%, deslocada (+6, +10)) desenhada no chão,
## abaixo de tudo; inimigos que sobem do fundo (SimEnemy.depth < 1, ainda sem colisão na Sim) crescem
## de 35% a 100% saindo da neblina, e a sombra se separa deles conforme sobem. A nave inclina nas
## curvas (some com "reduzir movimento"). Dano, no chefe e em todo inimigo: nada de branco chapado, um tinte
## quente (shaders/sprite_flash.gdshader) que pulsa no máximo a cada 7 passos e um tranco curto (HitPulse; um
## por inimigo atingido em EnemyPulses, sem tranco nos pequenos), legível mesmo sob tiro contínuo.
## Naves HD (SpriteBank, 2 texels por unidade) em camadas com filtro linear com mipmaps; a pixel art (coletáveis,
## alvos dos objetivos, mísseis, arte Void de reserva) fica numa camada própria sem filtro (_items).
## A nave do jogador é a da carga (SpriteBank.player), desenhada por ShipArt: veste a evolução do nível do hangar
## (ShipLivery, carga "ship_level"), a pintura da loja e as avarias; na Ascendida (nível 10) deixa um rastro de
## centelhas de ouro. O ponto da hitbox vai por cima de tudo (_fx_above).
## Morte de inimigo em três estilos (kill_fx), sorteados aqui, nunca pela Sim: explosão reforçada,
## derretimento no lugar (shaders/sprite_melt.gdshader) e queda girando em chamas até o mar (coluna d'água,
## espuma, explosão abafada) ou o chão (explosão, marca, estilhaços). No espaço não há queda.

const ANIM_FPS := 12.0
const EXPLOSION_TIME := 0.6
const SHADOW_OFFSET := Vector2(6, 10)
const SHADOW_SCALE := 0.8
## Lado maior da nave Void original (nível 1), a régua do escudo e das bolhas em volta da nave.
const ORIGINAL_REACH := 30.0
const SHADOW_COLOR := Color(0.0, 0.02, 0.05, 0.35)
## Escala visual de quem sobe do fundo (0,35 → 1,0 enquanto a Sim leva depth de DEPTH_START a 1).
const RISE_SCALE := 0.35
## Inclinação da nave nas curvas: rotação máxima (rad) e quanto a largura encolhe.
const BANK_ROT := 0.1
const BANK_SQUEEZE := 0.22
const LASER_COLOR := Color(0.55, 0.97, 1.0, 0.95)
const BEAM_COLOR := Color(1.0, 0.42, 0.45, 0.95)
const WARN_COLOR := Color(1.0, 0.42, 0.45, 0.7)
## Luz do motor da nave (o azul da chama HD do jogador; a pintura troca) e do laser.
const EXHAUST_COLOR := Color(0.45, 0.85, 1.0)
## Cor da luz de cada arma (impactos, boca do canhão) e dos orbes de arma.
const WEAPON_TINTS := {&"pulsar": Color(0.55, 0.8, 1.0), &"laser": Color(0.55, 0.97, 1.0),
		&"plasma": Color(0.8, 0.55, 1.0), &"railgun": Color(1.0, 0.6, 0.45)}
const ORB_TINTS := {&"pulsar": Color(0.4, 0.65, 1.0), &"laser": Color(1.0, 0.82, 0.35),
		&"plasma": Color(0.78, 0.5, 1.0), &"railgun": Color(1.0, 0.45, 0.45)}
## Emissores contínuos (motor, fumaça de avaria, bolhas) rodam a 60 Hz, em qualquer taxa de quadros.
const EMIT_STEP := 1.0 / 60.0
const TIDE_COLOR := Color(0.45, 1.0, 0.95, 0.55)
## Colunas de perigo por tipo (lava do cap. 4, gelo do 6, detritos do 8).
const HAZARD_COLORS := {"lava": Color(1.0, 0.45, 0.15, 0.95), "icefall": Color(0.75, 0.95, 1.0, 0.9),
		"debris": Color(0.7, 0.7, 0.75, 0.9)}
const COVER_COLOR := Color(0.16, 0.2, 0.3, 0.95)
const COVER_TRIM := Color(0.45, 0.85, 1.0, 0.8)
## Rastro da nave Ascendida: uma centelha a cada WAKE_STEP s, WAKE_LEN delas.
const WAKE_STEP := 0.05
const WAKE_LEN := 9
## Chefe avariado (fumaça e brasas) abaixo desta fração do HP; ferimentos em raios do corpo.
const WOUNDED_HP := 0.3
const WOUNDS: Array[Vector2] = [Vector2(-0.55, 0.1), Vector2(0.45, -0.25), Vector2(0.05, 0.4)]
## Onde a queda termina: a sombra da nave (2,5D), um pouco mais longe e para o lado do giro.
const FALL_DROP := Vector2(0, 58)
const FALL_DRIFT := 10.0
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
## Depuração e capturas de teste: desenha todos os círculos de colisão da Sim (Hitboxes) por cima de tudo.
var debug_hitboxes: bool = false
var reduce_flashes: bool = false
## "Reduzir movimento": sem inclinação da nave nas curvas.
var reduce_motion: bool = false
var fx_level: int = 2
## Estilo da última morte (kill_fx): a Game escolhe som e tranco por ele.
var last_death: StringName = &""
var explosions: Array[Dictionary] = []
## Anéis de choque: {pos, t, duration, radius, color}.
var rings: Array[Dictionary] = []
## Receitas e partículas (explosões, faíscas, fumaça, destroços, números de pontos).
var fx := CombatFx.new()
## Poderes das naves (PowerView): projéteis, feixes, raios, ondas e a escuridão do eclipse.
var powers := PowerView.new()
## Laser e fluxo do Mergulho Solar saindo do bico (shader aditivo, um quad).
var stream := EnergyStream.new()
## Feixes inimigos dos padrões (corpo em shader, luz da boca e do respingo); os do cenário ficam aqui.
var beams := HostileBeams.new()

var _shadows: _Layer
var _entities: _Layer
var _items: _Layer
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
## Arte da nave, da ala e do Fantasma (SpriteBank.player) e os bocais da nave (popa, unidades lógicas).
var _art: Dictionary = {}
var _wing_art: Dictionary = {}
var _ghost_art: Dictionary = {}
var _nozzles: Array[Vector2] = []
var _shield: Texture2D
var _log: Texture2D
var _capsule: Texture2D
## Objetivos de fase: mira dos alvos, atlantes nas bolhas e relíquia.
var _objectives := ObjectiveView.new()
var _sea_view := SeaView.new()
## Pintura da loja (alfa 0 = a arte como é) e estágio de avaria do casco (ShipArt).
var _paint := Color(0, 0, 0, 0)
var _damage: int = 0
## Pintura equipada (Store.paint_fx, só desenho): cor do motor e do rastro e cor do estouro da nave.
var _exhaust := EXHAUST_COLOR
var _burst := Color(0, 0, 0, 0)
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
## Retorno de dano do chefe (HitPulse): corpo e cada parte por id; o chefe, o HP e o passo da Sim vistos
## no último passo de 60 Hz.
var _boss_pulse := HitPulse.new()
var _part_pulses: Dictionary = {}
var _boss_seen: SimBoss
var _boss_hp: float = 0.0
## Passo da Sim visto no último passo de 60 Hz (acerto só conta em passo novo: nada repete no hitstop).
var _sim_frame: int = -1
## Retorno de dano dos inimigos: um HitPulse por inimigo atingido, liberado quando ele sai.
var _enemy_pulses := EnemyPulses.new()
var _boss_pulse_idle := HitPulse.new()
## Mortes vistas nesta partida (entra no sorteio do estilo, junto com o lugar e o sprite).
var _kills: int = 0


func setup(p_sim: Sim) -> void:
	sim = p_sim
	_enemy_pulses.clear()
	_kills = 0
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
	_objectives.setup()
	dark = bool(sim.mission.get("dark", false))
	var paint := Store.tint_of(String(sim.loadout.get("cosmetic", "")))
	_paint = Color(paint) if not paint.is_empty() else Color(0, 0, 0, 0)
	_art = SpriteBank.player(StringName(String(sim.player.ship.get("id", "falcon"))))
	_nozzles = ShipArt.game_nozzles(_art)
	var paint_fx := Store.ship_fx(String(sim.player.ship.get("id", "falcon")), String(sim.loadout.get("cosmetic", "")))
	_exhaust = paint_fx.get("trail", EXHAUST_COLOR)
	_burst = paint_fx.get("burst", Color(0, 0, 0, 0))
	_livery = clampi(int(sim.loadout.get("ship_level", 1)), 1, Economy.SHIP_MAX_LEVEL)
	_wing_livery = clampi(int(sim.loadout.get("coop_level", 1)), 1, Economy.SHIP_MAX_LEVEL)
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
	fx.surface = StringName(String(scenery.get("floor", CombatFx.WATER))) if fx.ground else CombatFx.NONE
	fx.setup(int(budget * 0.7), int(budget * 0.3))
	if not fx.landed.is_connected(_on_landed):
		fx.landed.connect(_on_landed)
	_sea_view.setup(self, _enemy_pulses, flash)
	add_child(_sea_view)
	_shadows = _Layer.new(self, _draw_shadows)
	_shadows.texture_filter = SpriteBank.HD_FILTER
	# No espaço não há chão para receber sombra.
	_shadows.visible = fx.ground
	add_child(_shadows)
	_wrecks = _Layer.new(self, _draw_wrecks)
	var melt := ShaderMaterial.new()
	melt.shader = load("res://shaders/sprite_melt.gdshader") as Shader
	_wrecks.material = melt
	_wrecks.texture_filter = SpriteBank.HD_FILTER
	add_child(_wrecks)
	_entities = _Layer.new(self, _draw_entities)
	_entities.material = flash
	_entities.texture_filter = SpriteBank.HD_FILTER
	add_child(_entities)
	_items = _Layer.new(self, _draw_items)
	_items.material = flash
	add_child(_items)
	add_child(fx.matter)
	_player_bullets = BulletRenderer.new()
	_player_bullets.halo_alpha = [0.0, 0.6, 0.85][clampi(fx_level, 0, 2)]
	_player_bullets.halo_scale = 3.6
	_player_bullets.setup(BulletKinds.PLAYER, sim.player_bullets.capacity)
	if paint_fx.has("shot"):
		_player_bullets.set_glow(paint_fx["shot"])
	add_child(_player_bullets)
	_player = _Layer.new(self, _draw_player)
	_player.material = flash
	_player.texture_filter = SpriteBank.HD_FILTER
	add_child(_player)
	_fx_below = _Layer.new(self, _draw_fx_below)
	add_child(_fx_below)
	powers.reduce_flashes = reduce_flashes
	powers.fx_level = fx_level
	powers.ship_art = _art
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
	stream.reduce_flashes = reduce_flashes
	stream.setup(sim)
	add_child(stream)
	beams.reduce_flashes = reduce_flashes
	beams.setup(sim, fx, _flare)
	add_child(beams)
	_power_add =_Layer.new(self, _draw_power_add)
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
	# Entrada de 6 passos (0,1 s): a saída do emissor fica fluida sem atrasar a leitura da bala.
	_enemy_bullets.grow_frames = 6
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
	stream.refresh(delta, time)
	beams.refresh(delta, time)
	_player_bullets.render(sim.player_bullets)
	_enemy_bullets.render(sim.enemy_bullets)
	var ease := 1.0 - exp(-delta * 12.0)
	_bank = lerpf(_bank, _bank_target(sim.player), ease)
	if sim.wing != null:
		_wing_bank = lerpf(_wing_bank, _bank_target(sim.wing), ease)
	_trail(delta)
	_sea_view.queue_redraw()
	_shadows.queue_redraw()
	_wrecks.queue_redraw()
	_entities.queue_redraw()
	_items.queue_redraw()
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
		&"outro":
			# Fim da missão: o campo fica limpo (a explosão do chefe vem logo depois, no &"boss_dead").
			fx.clear()
			powers.clear()
			explosions.clear()
			rings.clear()
			_wake.clear()
			_muzzle = 0.0
		&"outro_rise":
			_ring_at(at + Vector2(0, 14), 0.45, 36.0, Color(_exhaust, 0.9))
		&"kill":
			var sprite := StringName(String(ev.get("sprite", "")))
			var big := bool(ev.get("big", false))
			_kills += 1
			var roll := absi(hash([_kills, int(at.x), int(at.y), String(sprite)]))
			var style := CombatFx.death_style(roll, big, fx.surface, SpriteBank.SPECIAL.has(sprite))
			var def: Dictionary = (sim.tables.get("enemies", {}) as Dictionary).get(StringName(String(ev.get("id", ""))), {})
			if not _sea_view.sink(def, ev):
				kill_fx(at, sprite, big, int(ev.get("points", 0)), style, float(def.get("scale", 1.0)), roll)
		&"hit":
			# No ponto fraco do chefe as faíscas saem douradas: o jogador vê onde está acertando.
			fx.impact(at, UiTheme.GOLD if _on_weak_point(at) else _weapon_tint())
		&"graze":
			fx.graze(at)
		&"shot":
			_muzzle = 0.06
		&"player_hit":
			_ring_at(at, 0.5, 70.0, Color(1.0, 0.4, 0.4))
			fx.explosion(at, 0.8, Color(1.0, 0.4, 0.35, 0.9))
			# Casco perdido com pintura: o estouro próprio da pintura por cima (anel e explosão na cor dela).
			if _burst.a > 0.0 and int(ev.get("hull", 1)) <= 0:
				_ring_at(at, 0.6, 90.0, _burst)
				fx.explosion(at, 1.6, Color(_burst, 0.95))
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
			BeamDrones.pop(sim.boss, fx)
			var ship := SpriteBank.ship(StringName((sim.tables["bosses"] as Dictionary).get(StringName(ev["id"]), {})
					.get("sprite", "")))
			for k: int in range(5):
				var off := Vector2(cos(k * 2.4) * 40.0, sin(k * 1.7) * 28.0)
				if ship["destruction"] == null:
					# Nave HD: a cadeia é de bolas de fogo em partículas (a Void tinha a tira de destruição própria).
					fx.later(k * 0.18, fx.explosion.bind(at + off, 1.8))
					continue
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
		&"objective_release":
			_ring_at(at, 0.5, 46.0, Color(0.5, 1.0, 0.95))
		&"survivor", &"relic":
			fx.collect(at, UiTheme.GOLD if StringName(ev["type"]) == &"relic" else Color(0.55, 1.0, 1.0), true)
			_ring_at(at, 0.4, 34.0, Color(1.0, 0.9, 0.55))
		&"bomb_pickup", &"capsule", &"log", &"heal", &"revive":
			fx.collect(at, Color(0.5, 1.0, 0.9), true)
			_ring_at(at, 0.4, 40.0, Color(0.5, 1.0, 0.9))
			if StringName(ev["type"]) == &"heal":
				powers.heal_burst(fx, at)
		&"splash":
			_ring_at(at, 0.25, float(ev.get("radius", 20.0)),
					UiTheme.GOLD if bool(ev.get("gold", false)) else Color(0.8, 0.55, 1.0))
		&"power":
			_on_power(ev, at)
		&"power_blast":
			_on_power_blast(ev, at)


## Morte de um inimigo no estilo pedido (CombatFx.EXPLODE, MELT ou FALL); `scale` é a do inimigo.
## Se a morte com sprite não couber (teto de CombatFx.MAX_WRECKS, sem chão), explode.
func kill_fx(at: Vector2, sprite: StringName, big: bool, points: int, style: StringName, scale: float = 1.0,
		roll: int = 0) -> void:
	var ship := SpriteBank.ship(sprite)
	var drift := FALL_DRIFT * (1.0 if roll % 2 == 0 else -1.0)
	var to := at + SHADOW_OFFSET + FALL_DROP * (1.3 if big else 1.0) + Vector2(drift, 0)
	if style != CombatFx.EXPLODE and not fx.wreck(ship["base"], ship["tex_size"], ship["size"], at, to, scale, style,
			big):
		style = CombatFx.EXPLODE
	last_death = style
	if style == CombatFx.EXPLODE:
		if ship["destruction"] != null:
			explosions.append({"tex": ship["destruction"], "frames": ship["destruction_frames"],
					"size": ship["destruction_size"], "pos": at, "t": 0.0, "scale": 1.5 if big else 1.15,
					"duration": EXPLOSION_TIME})
		else:
			# Nave HD: bola de fogo em partículas do porte da nave visível, no lugar da tira Void (pixel art).
			var used: Rect2 = ship["used"]
			fx.explosion(at, clampf(maxf(used.size.x, used.size.y) * scale / 30.0, 0.8, 2.4))
		fx.blast(at, big)
		_ring_at(at, 0.22, 34.0 if big else 20.0, Color(1.0, 0.95, 0.85))
		_ring_at(at, 0.45, 64.0 if big else 38.0, Color(1.0, 0.65, 0.35))
	elif style == CombatFx.FALL:
		_ring_at(at, 0.25, 30.0 if big else 18.0, Color(1.0, 0.7, 0.4))
	else:
		_ring_at(at, 0.3, 26.0 if big else 16.0, Color(1.0, 0.5, 0.2))
	fx.popup(at, points, UiTheme.GOLD if big else Color(1.0, 0.95, 0.82))


## Fim de uma morte em curso (CombatFx.landed): o anel do impacto, na cor da água, da poeira ou da brasa.
func _on_landed(at: Vector2, big: bool, kind: StringName) -> void:
	match kind:
		CombatFx.WATER:
			_ring_at(at, 0.5, 40.0 if big else 26.0, Color(fx.foam, 0.8))
		CombatFx.SOLID:
			_ring_at(at, 0.4, 44.0 if big else 28.0, Color(1.0, 0.65, 0.35))
		_:
			_ring_at(at, 0.3, 30.0 if big else 20.0, Color(1.0, 0.6, 0.3))


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
	var fresh := sim.frame != _sim_frame
	_sim_frame = sim.frame
	_tick_boss_hits(fresh)
	_enemy_pulses.tick(sim.enemies, fresh, reduce_motion)
	powers.emit(sim, fx, _ticks)
	if pl.alive and fx_level >= 1:
		var thrust := 1.0 if pl.last_move.y < -0.3 else 0.0
		_nozzle = 1 - _nozzle
		fx.exhaust(pl.pos + _nozzles[_nozzle], _exhaust, thrust)
		_damage_smoke(pl)
		if sim.outro.rise >= 0:
			# Arrancada da saída: os dois bocais a cada passo, com o rastro mais longo quanto mais rápido.
			for ship: SimPlayer in ([pl, sim.wing] if sim.wing != null else [pl]):
				for n: Vector2 in _nozzles:
					# Também a meio caminho do passo anterior: na subida rápida o rastro sai contínuo, sem contas soltas.
					fx.exhaust(ship.pos + n, _exhaust, _boost())
					fx.exhaust(ship.pos + n - ship.last_move * 0.5, _exhaust, _boost())
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
	_boss_wounds()



## Acertos no chefe viram pulsos (HitPulse), um passo de 60 Hz por vez. Só conta acerto num passo novo da
## Sim (no hitstop e na pausa o pulso apaga em vez de repetir); o tamanho do golpe é o HP que caiu.
func _tick_boss_hits(fresh: bool) -> void:
	var b := sim.boss
	if b != _boss_seen:
		_boss_seen = b
		_boss_pulse.reset()
		_part_pulses.clear()
		_boss_hp = b.hp if b != null else 0.0
	if b == null:
		return
	# 2,5% do HP total num passo (bomba, poder grande, parte destruída) já é golpe grande.
	var strength := clampf((_boss_hp - b.hp) / maxf(1.0, b.max_hp) * 40.0, 0.0, 1.0)
	_boss_hp = b.hp
	_boss_pulse.calm = reduce_motion
	_boss_pulse.tick(fresh and b.flash > 0, strength)
	for part: Dictionary in b.parts:
		var pulse: HitPulse = _part_pulses.get(part["id"])
		if pulse == null:
			pulse = HitPulse.new()
			_part_pulses[part["id"]] = pulse
		pulse.calm = reduce_motion
		pulse.tick(fresh and int(part["flash"]) > 0, strength)


## Chefe com menos de 30% do HP: fumaça leve saindo de três ferimentos fixos do casco, um por vez,
## e faíscas soltas de vez em quando (as brasas acesas ficam em _draw_wounds). Sinal contínuo de avaria
## que não cobre o sprite.
func _boss_wounds() -> void:
	var b := sim.boss
	if not _wounded(b) or _ticks % 9 != 0:
		return
	var spot := _wound_spot(b, (_ticks / 9) % WOUNDS.size()) + _boss_pulse.offset()
	fx.matter.spawn(CombatFx.SMOKE, spot, Vector2(sin(_ticks * 0.7) * 6.0, 26.0), 0.8, 0.5, 1.3,
			Color(0.16, 0.16, 0.18, 0.5), CombatFx.SMOKE_END, 1.0, Vector2.ZERO, _ticks * 0.37, 1.0)
	if _ticks % 36 == 0:
		fx.impact(spot, Color(1.0, 0.6, 0.25))


func _wounded(b: SimBoss) -> bool:
	return b != null and b.fighting() and b.hp < b.max_hp * WOUNDED_HP


func _wound_spot(b: SimBoss, k: int) -> Vector2:
	return b.body_pos() + WOUNDS[k] * b.body_radius()


## Brasas nos ferimentos do chefe avariado: piscam devagar (~1 Hz), defasadas, pequenas.
func _draw_wounds(ci: CanvasItem, b: SimBoss, shake: Vector2) -> void:
	if not _wounded(b):
		return
	var calm := 0.6 if reduce_flashes else 1.0
	for k: int in range(WOUNDS.size()):
		var beat := 0.5 + 0.5 * sin(time * 6.0 + k * 2.1)
		var at := _wound_spot(b, k) + shake
		_tex_centered(ci, _glow, at, 0.6 + 0.2 * beat, Color(1.0, 0.45, 0.15, (0.4 + 0.4 * beat) * calm))
		_tex_centered(ci, _sparkle, at, 1.0 + 0.3 * beat, Color(1.0, 0.85, 0.5, (0.5 + 0.5 * beat) * calm))


func _on_weak_point(at: Vector2) -> bool:
	var b := sim.boss
	if b == null:
		return false
	for part: Dictionary in b.parts:
		if float(part.get("weak", 0.0)) > 0.0 and b.part_active(part):
			var r := float(part.get("radius", 10.0)) + 4.0
			if at.distance_squared_to(b.part_pos(part)) <= r * r:
				return true
	return false


## Força do motor na arrancada da saída: 1 no começo, 3 quando a nave some.
func _boost() -> float:
	return 1.0 + 2.0 * clampf(sim.outro.rise / float(SimOutro.RISE_FRAMES), 0.0, 1.0)


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
		if SeaView.is_sea(e):
			continue
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
		_shadow(ci, _art, pl.pos, ShipArt.game_scale(_art), 1.0, _bank * BANK_ROT, 1.0 - BANK_SQUEEZE * absf(_bank))
	if sim.wing != null and sim.wing.alive:
		_shadow(ci, _wing(), sim.wing.pos, ShipArt.game_scale(_wing()), 1.0, _wing_bank * BANK_ROT,
				1.0 - BANK_SQUEEZE * absf(_wing_bank))


func _shadow(ci: CanvasItem, ship: Dictionary, pos: Vector2, scale: float, height: float, angle: float,
		squeeze: float = 1.0) -> void:
	var base: Texture2D = ship.get("base")
	if base == null:
		return
	var tex_size: int = ship["tex_size"]
	var size: float = ship["size"]
	var s := scale * SHADOW_SCALE
	ci.draw_set_transform(pos + SHADOW_OFFSET * height, angle, Vector2(s * squeeze, s))
	ci.draw_texture_rect_region(base, Rect2(-size * 0.5, -size * 0.5, size, size), Rect2(0, 0, tex_size, tex_size),
			Color(SHADOW_COLOR, SHADOW_COLOR.a * clampf(height, 0.25, 1.0)))
	ci.draw_set_transform(Vector2.ZERO)


# --- Entidades -------------------------------------------------------------------------------

## Naves HD (inimigos, chefe, escoltas) com filtro linear; a pixel art vai em _draw_items.
func _draw_entities(ci: CanvasItem) -> void:
	_draw_enemies(ci, true)
	if sim.boss != null:
		_draw_boss(ci, sim.boss)
	for esc: Dictionary in sim.escorts:
		# Escolta capturada: o inimigo dominado, menor e em ciano; pisca no último segundo.
		var fading := int(esc["frames"]) < 60 and int(time * 10.0) % 2 == 0
		var col := Color(0.55, 1.0, 1.0, 0.45 if fading else 0.95)
		_draw_ship(ci, SpriteBank.ship(StringName(String(esc["sprite"]))), esc["pos"], 1.0, 0.6, col, true)


## Inimigos de uma camada: `hd` (linear) ou pixel art (alvos dos objetivos, glifos, Void de reserva).
func _draw_enemies(ci: CanvasItem, hd: bool) -> void:
	for e: SimEnemy in sim.enemies:
		var ship := SpriteBank.ship(e.sprite)
		if bool(ship["hd"]) != hd or SeaView.is_sea(e):
			continue
		var pulse := _enemy_pulses.of(e)
		var tint := _hit_color(Color(String(e.def.get("tint", "#ffffff"))), pulse.intensity(), false)
		var at := e.pos + pulse.offset() * shake_scale(e.radius)
		_draw_ship(ci, ship, at, e.depth, float(e.def.get("scale", 1.0)), tint)
		if e.marked and sim.mods.chart and e.depth >= 1.0:
			# Carta de Nereu: losango dourado sobre os marcados.
			var m := e.pos + Vector2(0, -e.radius - 8.0)
			ci.draw_rect(Rect2(m - Vector2(1, 3), Vector2(2, 6)), UiTheme.GOLD)
			ci.draw_rect(Rect2(m - Vector2(3, 1), Vector2(6, 2)), UiTheme.GOLD)


## Pixel art sem filtro, por cima das naves: alvos dos objetivos, coletáveis, mísseis e drones.
func _draw_items(ci: CanvasItem) -> void:
	_draw_enemies(ci, false)
	_objectives.draw(ci, sim, time)
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
	SecondaryArt.draw(ci, sim, time)


## Tranco do acerto num inimigo, pelo raio: nenhum nos pequenos (tremer 1 px num sprite de 24 só parece
## defeito), metade nos médios e o do chefe nos grandes.
static func shake_scale(radius: float) -> float:
	return 0.0 if radius < 15.0 else clampf(radius / 30.0, 0.5, 1.0)


func _draw_ship(ci: CanvasItem, ship: Dictionary, pos: Vector2, depth: float, scale: float,
		tint: Color = Color(1, 1, 1), up: bool = false) -> void:
	var tex_size: int = ship["tex_size"]
	var size: float = ship["size"]
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
	ci.draw_set_transform(pos, 0.0 if up else PI, Vector2(s, s))
	var half := Vector2(size, size) * 0.5
	var engine: Texture2D = ship["engine"]
	if engine != null:
		var f := int(time * ANIM_FPS) % int(ship["engine_frames"])
		ci.draw_texture_rect_region(engine, Rect2(-half, half * 2.0), SpriteBank.frame_rect(f, tex_size), modulate)
	ci.draw_texture_rect_region(base, Rect2(-half, half * 2.0), Rect2(0, 0, tex_size, tex_size), modulate)
	ci.draw_set_transform(Vector2.ZERO)


func _draw_boss(ci: CanvasItem, b: SimBoss) -> void:
	var ship := SpriteBank.ship(StringName(String(b.def.get("sprite", ""))))
	var scale := float(b.def.get("scale", 1.0))
	# Tranco do acerto (HitPulse): o chefe todo junto, sem mexer na Sim.
	var shake := _boss_pulse.offset()
	var body := b.body_pos() + shake
	# Tentáculos atrás do corpo: segmentos numa curva da base até a ponta (a ponta é a parte da Sim).
	for part: Dictionary in b.parts:
		var tid := String(part["id"])
		if not tid.begins_with("t") or not tid.substr(1).is_valid_int():
			continue
		var pulse := _pulse_of(part)
		var tip := b.part_pos(part) + shake + pulse.offset()
		var root := body + Vector2((part["base"] as Vector2).x * 0.32, 18.0)
		var alive := bool(part["alive"])
		var segments := 11 if alive else 3
		var color := _hit_color(Color(1, 1, 1), pulse.intensity(), false) if alive else Color(0.45, 0.4, 0.5)
		var ctrl := root + Vector2(0, 56)
		for k: int in range(segments):
			var u := float(k) / 11.0
			var p := root.lerp(ctrl, u).lerp(ctrl.lerp(tip, u), u)
			_tex_centered(ci, _seg, p, 1.0 - u * 0.25, color)
		if alive:
			_tex_centered(ci, _tip, tip, 1.0, color)
	_draw_boss_parts(ci, b, body, shake)
	BeamDrones.draw_all(ci, sim, shake, _part_pulses, time, reduce_flashes)
	var tint := _hit_color(Color(String(b.def.get("tint", "#ffffff"))), _boss_pulse.intensity(), false)
	_draw_ship(ci, ship, b.pos + shake, 1.0, scale, tint)
	_draw_wounds(ci, b, shake)
	var beat := 0.6 + 0.4 * sin(time * 9.0)
	for part: Dictionary in b.parts:
		var pid := String(part["id"])
		if (pid.begins_with("eye") or pid == "core") and b.part_active(part):
			# Ponto fraco atingido: o brilho vira dourado e cresce um pouco a cada pulso.
			var k := _pulse_of(part).intensity() / HitPulse.PEAK_MAX
			var col := Color(1.0, 0.35, 0.4, beat) if pid.begins_with("eye") else Color(0.4, 1.0, 1.0, beat)
			col = Color(col.lerp(UiTheme.GOLD, minf(1.0, k * 1.6)), maxf(beat, k))
			_tex_centered(ci, _glow, b.part_pos(part) + shake,
					(0.6 + float(part.get("radius", 10.0)) / 20.0) * (1.0 + 0.25 * k), col)


## Partes genéricas dos chefes do Beta: corrente de segmentos (Sky Leviathan) ligada do corpo à
## cauda, anéis de escudo girando (Poseidon Prime) e núcleos com sprite próprio (Leviathan Protocol).
func _draw_boss_parts(ci: CanvasItem, b: SimBoss, body: Vector2, shake: Vector2) -> void:
	var prev := body
	for part: Dictionary in b.parts:
		var pulse := _pulse_of(part)
		var at := b.part_pos(part) + shake + pulse.offset()
		var alive := bool(part["alive"])
		var color := Color(String(b.def.get("tint", "#ffffff")))
		if not alive:
			color = Color(0.4, 0.38, 0.45)
		if bool(part.get("chain", false)):
			for k: int in range(1, 4):
				_tex_centered(ci, _seg, prev.lerp(at, k / 4.0), 0.8, Color(color, 0.9))
			prev = at
		if part.has("sprite") and (alive or bool(part.get("chain", false))):
			var s := float(part.get("part_scale", 1.0))
			var gold := float(part.get("weak", 0.0)) > 0.0
			var hit := _hit_color(color, pulse.intensity() if alive else 0.0, gold)
			_draw_ship(ci, SpriteBank.ship(StringName(String(part["sprite"]))), at, 1.0, s, hit)
		elif bool(part.get("ring", false)) and alive:
			ci.draw_set_transform(at, time * (2.0 if b.part_active(part) else 0.4), Vector2(0.5, 0.5))
			ci.draw_texture(_ring, -_ring.get_size() * 0.5, Color(1.0, 0.85, 0.4, 0.9 if b.part_active(part) else 0.35))
			ci.draw_set_transform(Vector2.ZERO)


func _pulse_of(part: Dictionary) -> HitPulse:
	var pulse: HitPulse = _part_pulses.get(part["id"])
	return pulse if pulse != null else _boss_pulse_idle


## Modulate de tinte de acerto que o shader de dano lê (HitPulse.tint).
static func _hit_color(base: Color, amount: float, gold: bool) -> Color:
	return HitPulse.tint(base, amount, gold)


# --- Jogador -----------------------------------------------------------------------------------

## Ala do co-op: a nave dela (carga "coop_level" na evolução) e, perto da nave 1, o Elo de Maré (linha que apaga
## balas).
func _draw_wing(ci: CanvasItem, w: SimPlayer, blink: bool) -> void:
	if sim.linked:
		var a := sim.player.pos
		var flick := 0.55 + 0.25 * sin(time * 18.0)
		ci.draw_line(a, w.pos, Color(TIDE_COLOR, flick), 2.0)
		_tex_centered(ci, _glow, (a + w.pos) * 0.5, 0.6, Color(TIDE_COLOR, 0.6))
	var art := _wing()
	var alpha := 0.45 if blink else 1.0
	_bank_transform(ci, w.pos, _wing_bank, ShipArt.game_scale(art))
	ShipArt.draw(ci, art, time, _wing_livery, alpha, w.last_move.y < -0.3, Color(0, 0, 0, 0), reduce_flashes)
	ci.draw_set_transform(Vector2.ZERO)
	var label := w.pos + Vector2(-2.5, ShipArt.game_used(art).end.y + 9.0)
	ci.draw_string_outline(Locale.font, label, "2", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, 2, Color(0.02, 0.04, 0.08, 0.8))
	ci.draw_string(Locale.font, label, "2", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.62, 0.91, 1.0, alpha))


func _wing() -> Dictionary:
	if _wing_art.is_empty() and sim.wing != null:
		_wing_art = SpriteBank.player(StringName(String(sim.wing.ship.get("id", "falcon"))))
	return _wing_art


func _draw_player(ci: CanvasItem) -> void:
	var pl := sim.player
	if not pl.alive:
		return
	var p := pl.pos
	# Durante um poder a invulnerabilidade é do poder: o escudo aparece, a nave não pisca.
	var blink := pl.invuln > 0 and int(time * 20.0) % 2 == 0 and sim.power_fx.is_empty()
	var alpha := 0.45 if blink else 1.0
	if PowerView.has_active(sim, &"cloak"):
		# Manto (Umbra, Ascensão): a nave fica translúcida e tremeluz.
		alpha = 0.38 + 0.14 * sin(time * 23.0)
	if sim.tide_frames > 0:
		var pulse := 1.0 + 0.15 * sin(time * 12.0)
		_tex_centered(ci, _ring, p, Sim.TIDE_RADIUS / 14.0 * pulse, TIDE_COLOR)
	if sim.mods.bubbles > 0:
		_tex_centered(ci, _ring, p, 1.2 * _reach() / ORIGINAL_REACH, Color(0.7, 0.95, 1.0, 0.45))
	if sim.wing != null:
		_draw_wing(ci, sim.wing, blink)
	if ghost_sim != null and ghost_sim.player.alive:
		if _ghost_art.is_empty():
			_ghost_art = SpriteBank.player(StringName(String(ghost_sim.player.ship.get("id", "falcon"))))
		ci.draw_set_transform(ghost_sim.player.pos, 0.0, Vector2.ONE * ShipArt.game_scale(_ghost_art))
		ShipArt.draw(ci, _ghost_art, time, 1, 0.3, false, Color(0.5, 1.0, 1.0), true)
		ci.draw_set_transform(Vector2.ZERO)
	_draw_wake(ci, alpha)
	var boost := _boost() if sim.outro.rise >= 0 else 1.0
	_bank_transform(ci, p, _bank, ShipArt.game_scale(_art))
	ShipArt.draw(ci, _art, time, _livery, alpha, pl.last_move.y < -0.3 or sim.outro.rise >= 0, _paint, reduce_flashes,
			_damage, boost, _muzzle > 0.0)
	ci.draw_set_transform(Vector2.ZERO)
	if pl.invuln > 0 and _shield != null:
		# Escudo na proporção da nave Void original: quadro de 64 para 30 unidades de nave visível.
		var side := _reach() * 64.0 / ORIGINAL_REACH
		var sf := int(time * ANIM_FPS) % maxi(1, _shield.get_width() / 64)
		ci.draw_texture_rect_region(_shield, Rect2(p - Vector2(side, side) * 0.5, Vector2(side, side)),
				SpriteBank.frame_rect(sf, 64), Color(1, 1, 1, 0.7))


## Lado maior da nave visível (caixa opaca na escala da partida), em unidades lógicas.
func _reach() -> float:
	var used := ShipArt.game_used(_art)
	return maxf(used.size.x, used.size.y)


## Fumaça da avaria: sai de um dos pontos de rachadura (ShipArt.damage_spots), um por vez, mais vezes no 1/3.
func _damage_smoke(pl: SimPlayer) -> void:
	_damage = ShipArt.damage_stage(pl.hull, pl.max_hull)
	if _damage == 0 or _ticks % (14 if _damage == 1 else 8) != 0:
		return
	var spots := ShipArt.game_spots(_art)
	var count := mini(spots.size(), ShipArt.DAMAGE_CRACKS[_damage])
	if count > 0:
		fx.damage_smoke(pl.pos + spots[(_ticks / 8) % count])


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


## Nave inclinada na curva: gira um pouco e estreita (a asa de dentro "abaixa"), na escala da partida
## (ShipArt.game_scale).
func _bank_transform(ci: CanvasItem, at: Vector2, bank: float, scale: float) -> void:
	ci.draw_set_transform(at, bank * BANK_ROT, Vector2(1.0 - BANK_SQUEEZE * absf(bank), 1.0) * scale)


# --- Efeitos -------------------------------------------------------------------------------------

func _draw_fx_below(ci: CanvasItem) -> void:
	for c: Dictionary in sim.covers:
		var r := Hazards.cover_rect(c, sim.field.y)
		ci.draw_rect(r, COVER_COLOR)
		ci.draw_rect(Rect2(r.position, Vector2(r.size.x, 2.0)), COVER_TRIM)
		for wy: int in range(int(r.position.y) + 8, int(r.end.y) - 4, 12):
			ci.draw_rect(Rect2(r.position.x + 5.0, wy, r.size.x - 10.0, 2.0), Color(1.0, 0.85, 0.5, 0.35))
	if sim.breach_frames > 0:
		HazardArt.breach(ci, sim, time)
	for b: Dictionary in sim.beams:
		var x := float(b["x"])
		var y := float(b["y"])
		var w := float(b["width"])
		var length := sim.field.y + 40.0 - y
		if int(b["age"]) < int(b["warn"]):
			HostileBeams.warning(ci, b, sim.field, HostileBeams.WARN if HostileBeams.pattern(b) else WARN_COLOR)
		elif String(b.get("kind", "")) == "lightning":
			HazardArt.lightning(ci, x, y, w, length, int(b["age"]), reduce_flashes, _glow)
		elif HAZARD_COLORS.has(String(b.get("kind", ""))):
			var hc: Color = HAZARD_COLORS[String(b["kind"])]
			var wob := 0.85 + 0.15 * sin(time * 30.0 + x)
			ci.draw_texture_rect(_beam, Rect2(x - w * 0.6, y, w * 1.2, length), false, Color(hc, hc.a * wob))
		elif not HostileBeams.pattern(b):
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
		if stream.open > 0.0:
			# O feixe é o EnergyStream (shader); aqui só o bocal pulsando no bico e o clarão onde ele bate.
			var w := sim.laser_width * 1.6 * stream.open
			var sun := Color(0.6, 1.0, 1.0).lerp(Color(1.0, 0.85, 0.55), stream.heat)
			var beat := 0.5 + 0.5 * sin(time * 23.0)
			_tex_centered(ci, _flare, Vector2(p.x, stream.top), (w / 20.0) * (0.9 + 0.2 * sin(time * 40.0)),
					Color(sun, 0.8 * stream.open))
			_tex_centered(ci, _flare, Vector2(p.x, p.y - EnergyStream.NOSE), w / 26.0 * (0.9 + 0.2 * beat),
					Color(sun.lerp(Color.WHITE, 0.3), (0.55 + 0.25 * beat) * stream.open))
		var thrust := 1.0 if pl.last_move.y < -0.3 else 0.0
		if sim.outro.rise >= 0:
			thrust = _boost() * 2.0
		for n: Vector2 in _nozzles:
			_tex_centered(ci, _flare, p + n, (0.28 + 0.12 * thrust) * (0.85 + 0.15 * sin(time * 37.0 + n.x)),
					Color(_exhaust, 0.75))
		if _muzzle > 0.0:
			var tint := _weapon_tint()
			var muzzle := p + Vector2(0, ShipArt.game_used(_art).position.y + 2.0)
			_tex_centered(ci, _flare, muzzle, 0.42, Color(tint, 0.9 * _muzzle / 0.06))
			_tex_centered(ci, _sparkle, muzzle, 1.6, Color(1, 1, 1, _muzzle / 0.06))
	if fx_level >= 1:
		for e: SimEnemy in sim.enemies:
			if e.depth >= 1.0 and not SeaView.is_sea(e):
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
		# Feixe dos padrões: o brilho é do HostileBeams; aqui só o do cenário (fora o raio).
		if int(b["age"]) >= int(b["warn"]) and not HostileBeams.pattern(b) and String(b["kind"]) != "lightning":
			var hc: Color = HAZARD_COLORS.get(String(b.get("kind", "")), BEAM_COLOR)
			var bw := float(b["width"])
			var by := float(b["y"])
			ci.draw_texture_rect(_beam, Rect2(float(b["x"]) - bw * 1.4, by, bw * 2.8, sim.field.y + 40.0 - by),
					false, Color(hc, 0.3 * flicker))
	for r: Dictionary in rings:
		var u := float(r["t"]) / float(r["duration"])
		var radius := float(r["radius"]) * (1.0 - (1.0 - u) * (1.0 - u))
		var alpha := (1.0 - u) * (0.5 if reduce_flashes else 0.95)
		ci.draw_texture_rect(_shock, Rect2((r["pos"] as Vector2) - Vector2(radius, radius), Vector2(radius, radius) * 2.0),
				false, Color(r["color"] as Color, alpha))
	SecondaryArt.draw_add(ci, sim, time)


func _draw_power_below(ci: CanvasItem) -> void:
	powers.draw_below(ci, sim)


func _draw_power_add(ci: CanvasItem) -> void:
	powers.draw_add(ci, sim)


## Mortes em curso (CombatFx.wreck). Queda: a nave gira, encolhe até a sombra e queima (avermelha e
## escurece). Derretimento: no lugar, o progresso vai no alfa (2..3) para shaders/sprite_melt.gdshader.
func _draw_wrecks(ci: CanvasItem) -> void:
	for w: Dictionary in fx.wrecks:
		var u := CombatFx.wreck_progress(w)
		var size: float = w["size"]
		var tex_size: int = w["tex_size"]
		var rect := Rect2(-size * 0.5, -size * 0.5, size, size)
		var src := Rect2(0, 0, tex_size, tex_size)
		if StringName(w["mode"]) == CombatFx.MELT:
			var ms := float(w["scale"])
			ci.draw_set_transform(w["pos"], PI, Vector2(ms, ms))
			ci.draw_texture_rect_region(w["tex"], rect, src, Color(1, 1, 1, 2.0 + u))
			continue
		var s := float(w["scale"]) * lerpf(1.0, 0.35, u)
		var burn := lerpf(1.0, 0.25, u)
		ci.draw_set_transform(w["pos"], PI + float(w["spin"]) * float(w["t"]) * (0.4 + u), Vector2(s, s))
		ci.draw_texture_rect_region(w["tex"], rect, src,
				Color(burn, burn * 0.62, burn * 0.5, 1.0 - u * 0.3))
	ci.draw_set_transform(Vector2.ZERO)


## Por cima das balas só o que não atrapalha a leitura: a escuridão do Registro Abissal e os números
## de pontos (pequenos, sobem e somem em 0,75 s).
func _draw_fx_above(ci: CanvasItem) -> void:
	if dark and sim.player.alive:
		HazardArt.dark(ci, sim, time, _ring)
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
	_draw_hitbox(ci)
	if debug_hitboxes:
		HitCircles.draw(ci, sim)


## Ponto da hitbox por cima de tudo (inclusive das balas): a nave HD é bem maior que a hitbox da Sim. Fica no ponto
## que leva o tiro (SimPlayer.hit_pos: a cabine da nave HD), não no centro do desenho.
func _draw_hitbox(ci: CanvasItem) -> void:
	if not touching or not sim.player.alive:
		return
	var p := sim.player.hit_pos()
	ci.draw_rect(Rect2(p - Vector2(2.5, 2.5), Vector2(5, 5)), Color(0.08, 0.07, 0.09))
	ci.draw_rect(Rect2(p - Vector2(1.5, 1.5), Vector2(3, 3)), Color(1, 1, 1))


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
