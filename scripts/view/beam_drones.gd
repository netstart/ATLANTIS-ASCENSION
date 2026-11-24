class_name BeamDrones
extends RefCounted
## Desenho dos drones emissores dos chefes (partes "drone", revisão 9 da Sim; arte em tools/gen_sprites.py,
## boss/beam_drone, 2 texels por unidade). Só lê a Sim; o WorldView chama draw_all entre as partes e o casco (o drone
## sai de baixo do casco) e pop quando o chefe cai. O drone vira a lente para o feixe dele, acende a lente na cor do
## feixe (HostileBeams) durante o aviso e a deixa branca-quente aceso; saindo do casco ou voltando, cresce de 60% a
## 100% (a posição é da Sim, SimBoss._move). Cada drone tem vida própria (independente do chefe: "leak" e "share" 0)
## e mostra uma barrinha dela logo acima, no coral da barra do chefe (HudBossBar), em escala de mundo e bem menor que
## a do topo; ela some com o drone.

## Lente: 2,6 unidades abaixo do centro do desenho (gen_sprites.beam_drone), em unidades de desenho de 24.
const LENS_Y := 2.6
## Quanto do tinte do chefe o casco do drone pega (o resto é o aço da arte).
const TINT := 0.25
## Barrinha de vida: largura e altura em unidades na escala 1 do drone e folga acima do casco.
const BAR_W := 18.0
const BAR_H := 2.0
const BAR_GAP := 3.0

static var _tex: Texture2D
static var _glow: Texture2D


## Drone que aparece: vivo, fora do casco e com o chefe em luta (ou entrando).
static func shown(b: SimBoss, part: Dictionary) -> bool:
	return bool(part.get("drone", false)) and bool(part["alive"]) and float(part.get("out", 0.0)) > 0.02 \
			and (b.fighting() or b.state == SimBoss.State.ENTER)


## Chefe vencido: os drones ainda no posto estouram junto (o desenho deles para fora da luta).
static func pop(b: SimBoss, fx: CombatFx) -> void:
	if b == null:
		return
	for part: Dictionary in b.parts:
		if bool(part.get("drone", false)) and bool(part["alive"]) and float(part.get("out", 0.0)) > 0.02:
			fx.explosion(b.part_pos(part), 1.2)


## Feixe de padrão com a boca neste ponto (o do drone sai da lente, ox = oy = 0); vazio se não há.
static func beam_of(sim: Sim, mouth: Vector2) -> Dictionary:
	for beam: Dictionary in sim.beams:
		if not HostileBeams.pattern(beam) or bool(beam.get("dead", false)):
			continue
		if Vector2(float(beam["x"]), float(beam["y"])).distance_squared_to(mouth) < 1.0:
			return beam
	return {}


## Todos os drones do chefe. `shake`: tranco do chefe; `pulses`: HitPulse de cada parte (por id), do WorldView.
static func draw_all(ci: CanvasItem, sim: Sim, shake: Vector2, pulses: Dictionary, time: float, calm: bool) -> void:
	var b := sim.boss
	if b == null:
		return
	if _tex == null:
		_tex = SpriteBank.generated("boss/beam_drone")
		_glow = SpriteBank.generated("fx/glow_32")
	var tint := Color(1, 1, 1).lerp(Color(String(b.def.get("tint", "#ffffff"))), TINT)
	for part: Dictionary in b.parts:
		if not shown(b, part):
			continue
		var pulse: HitPulse = pulses.get(part["id"])
		var at := b.part_pos(part) + shake
		var hit := 0.0
		if pulse != null:
			at += pulse.offset()
			hit = pulse.intensity()
		_draw(ci, sim, b, part, at, HitPulse.tint(tint, hit, false), time, calm)


static func _draw(ci: CanvasItem, sim: Sim, b: SimBoss, part: Dictionary, at: Vector2, modulate: Color, time: float,
		calm_flashes: bool) -> void:
	var s := float(part.get("part_scale", 1.0)) * 0.5 * lerpf(0.6, 1.0, float(part["out"]))
	var beam := beam_of(sim, b.part_pos(part))
	var rot := 0.0
	var charge := 0.0
	if not beam.is_empty():
		rot = HostileBeams.angle_of(beam) - PI * 0.5
		var age := int(beam["age"])
		var warn := int(beam["warn"])
		charge = float(age) / maxf(1.0, warn) if age < warn else 1.0 + HostileBeams.open_of(beam)
	var calm := 0.6 if calm_flashes else 1.0
	var size := _tex.get_size() * s
	ci.draw_set_transform(at, rot)
	ci.draw_texture_rect(_tex, Rect2(-size * 0.5, size), false, modulate)
	ci.draw_set_transform(Vector2.ZERO)
	_bar(ci, part, at + Vector2(0.0, -size.y * 0.5 - BAR_GAP), s * 2.0, float(part["out"]))
	var lens := at + Vector2(0.0, LENS_Y * s * 2.0).rotated(rot)
	if charge <= 0.0:
		_light(ci, lens, 0.44 * s, Color(HostileBeams.BODY, (0.25 + 0.1 * sin(time * 5.0 + at.x)) * calm))
		return
	var beat := 0.85 + 0.15 * sin(time * 40.0) * calm
	var k := minf(1.0, charge)
	_light(ci, lens, (0.5 + 0.9 * k) * s * beat, Color(HostileBeams.HALO, (0.35 + 0.5 * k) * calm))
	_light(ci, lens, (0.24 + 0.4 * k) * s, Color(HostileBeams.CORE.lerp(HostileBeams.BODY, 1.0 - k), 0.5 + 0.5 * k))


## Barrinha de vida do drone, centrada em `at` (sem giro: fica legível com o drone virado para o feixe).
static func _bar(ci: CanvasItem, part: Dictionary, at: Vector2, scale: float, alpha: float) -> void:
	var w := BAR_W * scale
	var u := clampf(float(part["hp"]) / maxf(1.0, float(part["max_hp"])), 0.0, 1.0)
	var r := Rect2(at - Vector2(w * 0.5, BAR_H * 0.5), Vector2(w, BAR_H))
	ci.draw_rect(r.grow(1.0), Color(UiTheme.ABYSS, 0.85 * alpha))
	ci.draw_rect(Rect2(r.position, Vector2(w * u, BAR_H)), Color(UiTheme.CORAL, alpha))
	ci.draw_rect(Rect2(r.position, Vector2(w * u, BAR_H * 0.4)), Color(1.0, 0.85, 0.88, 0.45 * alpha))


static func _light(ci: CanvasItem, at: Vector2, scale: float, color: Color) -> void:
	var size := _glow.get_size() * scale
	ci.draw_texture_rect(_glow, Rect2(at - size * 0.5, size), false, color)
