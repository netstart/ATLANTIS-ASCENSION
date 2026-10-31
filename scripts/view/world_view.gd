class_name WorldView
extends Node2D
## Desenho do campo de jogo a partir da Sim (só leitura). Camadas, de baixo para cima:
##   entidades (sombras, inimigos, chefe, coletáveis) → tiros do jogador → nave e laser →
##   efeitos de baixo (feixes, explosões, duelo) → balas inimigas (sempre por cima: leitura) →
##   efeitos de cima (faíscas, graze, anéis).
## Só texturas e retângulos por quadro (docs/policies/qualidade.md). Efeitos vivem aqui, não na Sim:
## qualidade gráfica e "reduzir flashes" nunca mudam a partida.

const ANIM_FPS := 12.0
const EXPLOSION_TIME := 0.6
const SHADOW_OFFSET := Vector2(7, 11)
const WATER_TINT := Color(0.45, 0.72, 0.92, 0.6)
const LASER_COLOR := Color(0.55, 0.97, 1.0, 0.95)
const BEAM_COLOR := Color(1.0, 0.42, 0.45, 0.95)
const WARN_COLOR := Color(1.0, 0.42, 0.45, 0.7)
const MAX_SPARKS := 160
const LIGHTNING_COLOR := Color(0.85, 0.92, 1.0, 0.95)
const TIDE_COLOR := Color(0.45, 1.0, 0.95, 0.55)
## Colunas de perigo por tipo (lava do cap. 4, gelo do 6, detritos do 8).
const HAZARD_COLORS := {"lava": Color(1.0, 0.45, 0.15, 0.95), "icefall": Color(0.75, 0.95, 1.0, 0.9),
		"debris": Color(0.7, 0.7, 0.75, 0.9)}
const COVER_COLOR := Color(0.16, 0.2, 0.3, 0.95)
const COVER_TRIM := Color(0.45, 0.85, 1.0, 0.8)
const BREACH_COLOR := Color(0.75, 0.55, 1.0, 0.22)
var dark: bool = false
## Paleta de daltonismo das balas inimigas (Settings "colorblind").
var colorblind: String = "off"
## Fantasma do Abismo: a Sim do recorde (só a nave dele é desenhada, translúcida).
var ghost_sim: Sim

var sim: Sim
var time: float = 0.0
var touching: bool = false
var reduce_flashes: bool = false
var fx_level: int = 2
var explosions: Array[Dictionary] = []
var sparks: Array[Dictionary] = []
var rings: Array[Dictionary] = []

var _entities: _Layer
var _player: _Layer
var _fx_below: _Layer
var _fx_above: _Layer
var _player_bullets: BulletRenderer
var _enemy_bullets: BulletRenderer
var _glow: Texture2D
var _ring: Texture2D
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


func setup(p_sim: Sim) -> void:
	sim = p_sim
	_glow = SpriteBank.generated("fx/glow_32")
	_ring = SpriteBank.generated("fx/ring_32")
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
	for name: String in ["base_very_damaged", "base_damaged", "base_slight", "base_full"]:
		_ship_bases.append(SpriteBank.texture("res://assets/art/void/main_ship/%s.png" % name))
	_engine_idle = SpriteBank.texture("res://assets/art/void/main_ship/engine_base_idle.png")
	_engine_power = SpriteBank.texture("res://assets/art/void/main_ship/engine_base_powering.png")
	_shield = SpriteBank.texture("res://assets/art/void/main_ship/shield_invincibility.png")
	_entities = _Layer.new(self, _draw_entities)
	add_child(_entities)
	_player_bullets = BulletRenderer.new()
	_player_bullets.setup(BulletKinds.PLAYER, sim.player_bullets.capacity)
	add_child(_player_bullets)
	_player = _Layer.new(self, _draw_player)
	add_child(_player)
	_fx_below = _Layer.new(self, _draw_fx_below)
	add_child(_fx_below)
	_enemy_bullets = BulletRenderer.new()
	_enemy_bullets.palette = colorblind
	_enemy_bullets.setup(BulletKinds.ENEMY, sim.enemy_bullets.capacity)
	add_child(_enemy_bullets)
	_fx_above = _Layer.new(self, _draw_fx_above)
	add_child(_fx_above)


## Um quadro: avança os efeitos e redesenha tudo.
func refresh(delta: float) -> void:
	time += delta
	_age(explosions, delta)
	_age(rings, delta)
	var i := sparks.size() - 1
	while i >= 0:
		var s := sparks[i]
		s["life"] = float(s["life"]) - delta
		s["pos"] = (s["pos"] as Vector2) + (s["vel"] as Vector2) * delta
		if float(s["life"]) <= 0.0:
			sparks.remove_at(i)
		i -= 1
	_player_bullets.render(sim.player_bullets)
	_enemy_bullets.render(sim.enemy_bullets)
	_entities.queue_redraw()
	_player.queue_redraw()
	_fx_below.queue_redraw()
	_fx_above.queue_redraw()


func on_event(ev: Dictionary) -> void:
	match StringName(ev["type"]):
		&"kill":
			var ship := SpriteBank.ship(StringName(ev.get("sprite", "")))
			explosions.append({"tex": ship["destruction"], "frames": ship["destruction_frames"],
					"size": ship["destruction_size"], "pos": ev["pos"], "t": 0.0, "scale": 1.0, "duration": EXPLOSION_TIME})
			_burst(ev["pos"], 6 if fx_level >= 1 else 2, Color(1.0, 0.75, 0.35))
		&"hit":
			if fx_level >= 1 and sparks.size() < MAX_SPARKS:
				_burst(ev["pos"], 1, Color(0.9, 1.0, 1.0))
		&"graze":
			_burst(ev["pos"], 2, Color(0.4, 0.95, 1.0))
		&"player_hit":
			rings.append({"pos": ev["pos"], "t": 0.0, "duration": 0.5, "radius": 70.0, "color": Color(1.0, 0.4, 0.4)})
			_burst(ev["pos"], 14, Color(1.0, 0.55, 0.4))
		&"capture":
			rings.append({"pos": ev["pos"], "t": 0.0, "duration": 0.45, "radius": 50.0, "color": Color(0.4, 1.0, 1.0)})
			_burst(ev["pos"], 10, Color(0.4, 1.0, 1.0))
		&"bomb", &"special":
			rings.append({"pos": ev["pos"], "t": 0.0, "duration": 0.7, "radius": 340.0, "color": Color(0.6, 1.0, 1.0)})
		&"boss_part":
			_burst(ev["pos"], 18, Color(0.85, 0.55, 1.0))
			rings.append({"pos": ev["pos"], "t": 0.0, "duration": 0.4, "radius": 60.0, "color": Color(0.85, 0.6, 1.0)})
		&"boss_dead":
			var ship := SpriteBank.ship(StringName((sim.tables["bosses"] as Dictionary).get(StringName(ev["id"]), {})
					.get("sprite", "")))
			for k: int in range(5):
				var off := Vector2(cos(k * 2.4) * 40.0, sin(k * 1.7) * 28.0)
				explosions.append({"tex": ship["destruction"], "frames": ship["destruction_frames"],
						"size": ship["destruction_size"], "pos": (ev["pos"] as Vector2) + off, "t": -k * 0.18, "scale": 1.6,
						"duration": 0.9})
			rings.append({"pos": ev["pos"], "t": 0.0, "duration": 1.0, "radius": 400.0, "color": Color(1, 1, 1)})
			_burst(ev["pos"], 40, Color(1.0, 0.85, 0.5))


func _age(list: Array[Dictionary], delta: float) -> void:
	var i := list.size() - 1
	while i >= 0:
		var e := list[i]
		e["t"] = float(e["t"]) + delta
		if float(e["t"]) >= float(e["duration"]):
			list.remove_at(i)
		i -= 1


func _burst(at: Vector2, count: int, color: Color) -> void:
	for k: int in range(count):
		if sparks.size() >= MAX_SPARKS:
			return
		var a := (k * 2.399963) + time * 3.0
		var speed := 40.0 + float((k * 37) % 90)
		sparks.append({"pos": at, "vel": Vector2.from_angle(a) * speed, "life": 0.25 + float(k % 4) * 0.08,
				"color": color})


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
	var s := scale * depth
	var modulate := tint
	if depth < 1.0:
		var u := (depth - SimEnemy.DEPTH_START) / (1.0 - SimEnemy.DEPTH_START)
		modulate = WATER_TINT.lerp(tint, u)
	if flash:
		modulate = Color(1.8, 1.8, 1.8)
	# Sombra no "chão": deslocada pela altura, maior com a profundidade.
	ci.draw_texture_rect(_glow, Rect2(pos + SHADOW_OFFSET * depth - Vector2(size, size) * 0.35 * s,
			Vector2(size, size) * 0.7 * s), false, Color(0, 0.02, 0.06, 0.35))
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
	if b.state == SimBoss.State.DYING and fx_level >= 1 and int(time * 20.0) % 3 == 0:
		_burst(body + Vector2(sin(time * 13.0) * 60.0, cos(time * 7.0) * 30.0), 3, Color(1.0, 0.8, 0.4))


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
	ci.draw_texture_rect_region(engine, Rect2(w.pos - Vector2(24, 24), Vector2(48, 48)),
			SpriteBank.frame_rect(int(time * ANIM_FPS) % frames, 48), col)
	ci.draw_texture(_ship_bases[3], w.pos - Vector2(24, 24), col)
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
		ci.draw_texture_rect(_beam, Rect2(p.x - w * 0.5, top, w, p.y - 14.0 - top), false,
				Color(LASER_COLOR, LASER_COLOR.a * flicker))
		_tex_centered(ci, _glow, Vector2(p.x, top), 0.5, Color(0.6, 1.0, 1.0, 0.8))
	var hull_frac := float(pl.hull) / maxf(1.0, float(pl.max_hull))
	var base := _ship_bases[clampi(int(ceil(hull_frac * 3.0)), 0, 3)]
	var blink := pl.invuln > 0 and int(time * 20.0) % 2 == 0
	var col := Color(_ship_tint, 0.45 if blink else 1.0)
	if sim.tide_frames > 0:
		var pulse := 1.0 + 0.15 * sin(time * 12.0)
		_tex_centered(ci, _ring, p, Sim.TIDE_RADIUS / 14.0 * pulse, TIDE_COLOR)
	if sim.mods.bubbles > 0:
		_tex_centered(ci, _ring, p, 1.2, Color(0.7, 0.95, 1.0, 0.45))
	if sim.wing != null:
		_draw_wing(ci, sim.wing, blink)
	if ghost_sim != null and ghost_sim.player.alive:
		ci.draw_texture(_ship_bases[3], ghost_sim.player.pos - Vector2(24, 24), Color(0.5, 1.0, 1.0, 0.3))
	var engine := _engine_power if pl.last_move.y < -0.3 else _engine_idle
	var frames := maxi(1, engine.get_width() / 48)
	ci.draw_texture_rect_region(engine, Rect2(p - Vector2(24, 24), Vector2(48, 48)),
			SpriteBank.frame_rect(int(time * ANIM_FPS) % frames, 48), col)
	ci.draw_texture(base, p - Vector2(24, 24), col)
	if pl.invuln > 0 and _shield != null:
		var sf := int(time * ANIM_FPS) % maxi(1, _shield.get_width() / 64)
		ci.draw_texture_rect_region(_shield, Rect2(p - Vector2(32, 32), Vector2(64, 64)), SpriteBank.frame_rect(sf, 64),
				Color(1, 1, 1, 0.7))
	if touching:
		ci.draw_rect(Rect2(p - Vector2(2.5, 2.5), Vector2(5, 5)), Color(0.08, 0.07, 0.09))
		ci.draw_rect(Rect2(p - Vector2(1.5, 1.5), Vector2(3, 3)), Color(1, 1, 1))


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
		ci.draw_set_transform(e["pos"], PI, Vector2(s, s))
		ci.draw_texture_rect_region(e["tex"], Rect2(-size * 0.5, -size * 0.5, size, size), SpriteBank.frame_rect(f, size))
		ci.draw_set_transform(Vector2.ZERO)


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
	if int(time * 30.0) % 2 == 0:
		_burst(meet, 2, Color(1.0, 0.9, 0.6))


func _draw_fx_above(ci: CanvasItem) -> void:
	if dark and sim.player.alive:
		_draw_dark(ci)
	for s: Dictionary in sparks:
		var life := float(s["life"])
		var c: Color = s["color"]
		ci.draw_rect(Rect2(s["pos"], Vector2(2, 2)), Color(c, clampf(life * 4.0, 0.0, 1.0)))
	for r: Dictionary in rings:
		var u := float(r["t"]) / float(r["duration"])
		var radius := float(r["radius"]) * (1.0 - (1.0 - u) * (1.0 - u))
		var alpha := (1.0 - u) * (0.5 if reduce_flashes else 0.9)
		var col: Color = r["color"]
		ci.draw_texture_rect(_ring, Rect2((r["pos"] as Vector2) - Vector2(radius, radius), Vector2(radius, radius) * 2.0),
				false, Color(col, alpha))


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
