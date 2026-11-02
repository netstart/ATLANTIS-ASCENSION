class_name PowerView
extends RefCounted
## Desenho dos poderes das naves (.ai/08-poderes-das-naves.md) a partir de `sim.power_fx` (só leitura; contrato
## no topo de scripts/sim/powers.gd). O WorldView chama as passadas na ordem das camadas:
##   draw_below (mistura normal, acima da nave): projéteis, drones, orbes, onda, barreira, morteiros, rastros;
##   draw_add (aditiva, filtro linear): feixes, raios, anéis, halos, avisos de artilharia e explosões;
##   draw_above (por cima das balas inimigas): o véu do Olho do Ciclone e a escuridão do Eclipse Total.
## Efeitos que a Sim acabou de encerrar (investida, feixe, anel, explosão, raio) apagam em FADE s aqui, só no
## desenho. Sem nó por quadro: só texturas e retângulos; as faíscas vão para o ParticleField do CombatFx
## (emit, a 60 Hz). "Reduzir flashes" corta a luz dos clarões; qualidade Baixa não solta faíscas.

const DIR := "res://assets/art/generated/powers/%s.png"
const SPRITES: Array[String] = ["feather", "torpedo", "missile_mini", "orb", "wave", "vortex", "corona", "reticle",
		"barrier", "bolt", "kamikaze", "lance", "mortar", "warn_circle", "dash_trail", "shield_front", "supernova",
		"eclipse_disc"]
## Sprites tingidos pela cor da nave (os outros já vêm pintados).
const TINTED: Array[String] = ["lance"]
const FADE := 0.28
## A investida dura poucos passos: o rastro e as imagens ficam mais tempo, apagando.
const DASH_FADE := 0.45
const FADE_TYPES: Array[StringName] = [&"dash", &"beam", &"ring", &"chain", &"delayed_blast", &"aura", &"barrier",
		&"reflect", &"vortex"]
## Passos de entrada e saída dos efeitos longos (o desenho cresce e some, a Sim não muda).
const FADE_IN := 6.0
const FADE_OUT := 14.0
## Linhas de velocidade em volta do rastro da investida.
const SPEED_LINES := 5
## Raios que caem sozinhos na Tempestade Elétrica (só desenho) a cada STORM_STEP s, quando o raio da Sim não
## tem alvo ao alcance.
const STORM_STEP := 0.16
## Altura de onde cai o morteiro até o alvo durante o aviso.
const MORTAR_DROP := 150.0
const AFTERIMAGES := 6
## A muralha do Atlas aparece mais alta que a faixa de colisão da Sim (parede de luz, não fio).
const WALL_SCALE := 2.2
const SLOW_TINT := Color(0.35, 0.62, 1.0, 0.09)
const ECLIPSE_SHADE := Color(0.01, 0.0, 0.04, 0.78)
## Raio do halo que a escuridão do eclipse deixa em volta da nave.
const ECLIPSE_HOLE := 46.0
## Lado da textura do halo do eclipse (transparente no meio, opaca nas bordas; feita uma vez no setup).
const HOLE_RES := 64
const HEAL_COLOR := Color(0.55, 1.0, 0.55)
const HEAL_GOLD := Color(1.0, 0.86, 0.4)

var reduce_flashes: bool = false
var fx_level: int = 2
## Quantas vezes cada tipo de efeito passou inteiro pelas duas passadas de desenho (teste de fumaça).
var drawn: Dictionary = {}
var time: float = 0.0
## Nave do jogador (rastro de imagens da investida) e a cor dela.
var ship_texture: Texture2D

var _tex: Dictionary = {}
var _beam: Texture2D
var _flare: Texture2D
var _glow: Texture2D
var _shock: Texture2D
var _ring: Texture2D
var _sparkle: Texture2D
var _hole: Texture2D
var _seen: Array[Dictionary] = []
var _fading: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()


func setup() -> void:
	for name: String in SPRITES:
		_tex[name] = SpriteBank.texture(DIR % name)
	_beam = SpriteBank.generated("fx/beam")
	_flare = SpriteBank.generated("fx/flare_64")
	_glow = SpriteBank.generated("fx/glow_32")
	_shock = SpriteBank.generated("fx/shock_64")
	_ring = SpriteBank.generated("fx/ring_128")
	_sparkle = SpriteBank.generated("fx/sparkle_9")
	_rng.seed = 7
	_hole = _hole_texture()


## Halo macio da escuridão do eclipse: alfa 0 no meio, 1 a partir da borda do quadrado (encaixa nos
## retângulos de fora sem emenda).
static func _hole_texture() -> Texture2D:
	var img := Image.create(HOLE_RES, HOLE_RES, false, Image.FORMAT_RGBA8)
	var c := HOLE_RES * 0.5
	for y: int in range(HOLE_RES):
		for x: int in range(HOLE_RES):
			var d := Vector2(x + 0.5 - c, y + 0.5 - c).length() / c
			img.set_pixel(x, y, Color(1, 1, 1, smoothstep(0.45, 1.0, d)))
	return ImageTexture.create_from_image(img)


func texture(name: String) -> Texture2D:
	return _tex.get(name)


## Algum efeito vivo deste tipo (já fora do aviso)?
static func has_active(sim: Sim, type: StringName) -> bool:
	for e: Dictionary in sim.power_fx:
		if e["type"] == type and int(e["wait"]) <= 0:
			return true
	return false


## Há algo para desenhar (efeito vivo ou apagando)?
func busy(sim: Sim) -> bool:
	return not sim.power_fx.is_empty() or not _fading.is_empty()


## Um quadro: guarda quem a Sim acabou de encerrar (para apagar suave) e envelhece os que apagam.
func advance(sim: Sim, delta: float) -> void:
	time += delta
	var i := _fading.size() - 1
	while i >= 0:
		_fading[i]["t"] = float(_fading[i]["t"]) + delta
		if float(_fading[i]["t"]) >= _fade_of(_fading[i]["e"]):
			_fading.remove_at(i)
		i -= 1
	if _seen.is_empty() and sim.power_fx.is_empty():
		return
	for old: Dictionary in _seen:
		if not old["type"] in FADE_TYPES or int(old["wait"]) > 0:
			continue
		var gone := true
		for e: Dictionary in sim.power_fx:
			if is_same(e, old):
				gone = false
				break
		if gone:
			_fading.append({"e": old, "t": 0.0})
	_seen.assign(sim.power_fx)


func clear() -> void:
	_seen.clear()
	_fading.clear()


# --- Faíscas (60 Hz) -----------------------------------------------------------------------------

## Emissores dos poderes: sucção do redemoinho e da supernova, faíscas de crítico, brilho do manto,
## centelhas da muralha e fumaça dos mísseis. Tudo no ParticleField (MultiMesh), nada de nó.
func emit(sim: Sim, fx: CombatFx, tick: int) -> void:
	if fx_level < 1 or sim.power_fx.is_empty():
		return
	for e: Dictionary in sim.power_fx:
		var col := Color(String(e["color"]))
		var at: Vector2 = e["pos"]
		var waiting := int(e["wait"]) > 0
		match e["type"]:
			&"vortex":
				if tick % 2 == 0:
					var r := float(e["radius"])
					var a := _rng.randf() * TAU
					var p := at + Vector2.from_angle(a) * r * _rng.randf_range(0.7, 1.0)
					var v := (at - p) * 1.6 + Vector2.from_angle(a + PI * 0.5) * r * 1.4
					fx.light.spawn(CombatFx.SPARKLE, p, v, 0.55, 1.2, 0.3, Color(0.8, 1.0, 0.95, 0.9), Color(col, 0.0),
							1.5)
			&"overdrive":
				if tick % 4 == 0:
					var spec: Dictionary = e["_spec"]
					var hot := Color(1.0, 0.95, 0.6) if float(spec.get("crit", 0.0)) > 0.0 else col
					var p := at + Vector2(_rng.randf_range(-14, 14), _rng.randf_range(-12, 14))
					fx.light.spawn(CombatFx.SPARKLE, p, Vector2(_rng.randf_range(-20, 20), -40.0), 0.4, 1.3, 0.2, hot,
							Color(col, 0.0), 2.0, Vector2.ZERO, 0.0, 4.0)
			&"cloak":
				if tick % 5 == 0:
					var p := at + Vector2(_rng.randf_range(-16, 16), _rng.randf_range(-14, 16))
					fx.light.spawn(CombatFx.FLARE, p, Vector2(0, 18), 0.4, 0.12, 0.02, Color(col, 0.5), Color(col, 0.0))
			&"barrier":
				if tick % 3 == 0 and not waiting:
					var w := float(e["width"])
					var p := at + Vector2(_rng.randf_range(-w * 0.5, w * 0.5), 0.0)
					fx.light.spawn(CombatFx.STREAK, p, Vector2(0, -_rng.randf_range(40.0, 90.0)), 0.35, 0.7, 0.2,
							Color(1.0, 0.95, 0.7, 0.9), Color(col, 0.0), 2.0, Vector2.ZERO, 0.0, 0.0, true)
			&"delayed_blast":
				if waiting and bool((e["_spec"] as Dictionary).get("implode", false)):
					for k: int in range(2):
						var a := _rng.randf() * TAU
						var p := at + Vector2.from_angle(a) * _rng.randf_range(90.0, 150.0)
						fx.light.spawn(CombatFx.STREAK, p, (at - p) * 2.4, 0.4, 0.9, 0.3, Color(1.0, 1.0, 0.85),
								Color(col, 0.0), 0.0, Vector2.ZERO, 0.0, 0.0, true)
			&"dash":
				var from: Vector2 = e["from"]
				for j: int in range(2):
					var p := from.lerp(at, _rng.randf()) + Vector2(_rng.randf_range(-6, 6), _rng.randf_range(-6, 6))
					fx.light.spawn(CombatFx.STREAK, p, Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(60.0, 140.0),
							0.25, 0.8, 0.2, Color(1, 1, 0.9), Color(col, 0.0), 4.0, Vector2.ZERO, 0.0, 0.0, true)
			&"salvo":
				if tick % 2 == 0 and String(e["sprite"]) in ["missile_mini", "torpedo"]:
					var points: PackedVector2Array = e["points"]
					var angles: PackedFloat32Array = e["angles"]
					for k: int in range(mini(points.size(), 14)):
						var back := Vector2.from_angle(angles[k]) * -6.0
						fx.light.spawn(CombatFx.FLARE, points[k] + back, back * 4.0, 0.22, 0.14, 0.05,
								Color(1.0, 0.65, 0.3, 0.7), Color(col, 0.0), 2.0)


## Reparo do casco: centelhas verdes e douradas subindo da nave.
func heal_burst(fx: CombatFx, at: Vector2) -> void:
	var n := 14 if fx_level >= 2 else 7
	for k: int in range(n):
		var p := at + Vector2(_rng.randf_range(-14, 14), _rng.randf_range(-4, 14))
		var col := HEAL_COLOR if k % 2 == 0 else HEAL_GOLD
		fx.light.spawn(CombatFx.SPARKLE, p, Vector2(_rng.randf_range(-10, 10), -_rng.randf_range(40.0, 80.0)),
				_rng.randf_range(0.5, 0.8), 1.5, 0.4, col, Color(col, 0.0), 1.0, Vector2.ZERO, 0.0, 3.0)


# --- Desenho -----------------------------------------------------------------------------------

func draw_below(ci: CanvasItem, sim: Sim) -> void:
	for e: Dictionary in sim.power_fx:
		_below(ci, e, 1.0)
	for f: Dictionary in _fading:
		_below(ci, f["e"], 1.0 - float(f["t"]) / _fade_of(f["e"]))
	ci.draw_set_transform(Vector2.ZERO)


func draw_add(ci: CanvasItem, sim: Sim) -> void:
	for e: Dictionary in sim.power_fx:
		_add(ci, sim, e, 1.0)
		_count(e)
	for f: Dictionary in _fading:
		_add(ci, sim, f["e"], 1.0 - float(f["t"]) / _fade_of(f["e"]))
	ci.draw_set_transform(Vector2.ZERO)


func draw_above(ci: CanvasItem, sim: Sim) -> void:
	for e: Dictionary in sim.power_fx:
		if int(e["wait"]) > 0:
			continue
		match e["type"]:
			&"slow":
				var k := _life(e)
				ci.draw_rect(Rect2(Vector2.ZERO, Playfield.FIELD), Color(SLOW_TINT, SLOW_TINT.a * k))
			&"eclipse":
				_draw_eclipse(ci, sim, e)
	ci.draw_set_transform(Vector2.ZERO)


static func _fade_of(e: Dictionary) -> float:
	return DASH_FADE if e["type"] == &"dash" else FADE


func _count(e: Dictionary) -> void:
	drawn[e["type"]] = int(drawn.get(e["type"], 0)) + 1


## Entrada e saída suaves de um efeito longo (0..1).
static func _life(e: Dictionary) -> float:
	var frames := float(e["frames"])
	var left := float(e["total"]) - frames
	return clampf(frames / FADE_IN, 0.0, 1.0) * clampf(left / FADE_OUT, 0.0, 1.0)


func _flash(a: float) -> float:
	return a * (0.6 if reduce_flashes else 1.0)


func _below(ci: CanvasItem, e: Dictionary, k: float) -> void:
	var col := Color(String(e["color"]))
	var at: Vector2 = e["pos"]
	var waiting := int(e["wait"]) > 0
	match e["type"]:
		&"dash":
			if waiting or ship_texture == null:
				return
			var from: Vector2 = e["from"]
			var half := ship_texture.get_size() * 0.5
			for i: int in range(AFTERIMAGES):
				var u := float(i + 1) / float(AFTERIMAGES + 1)
				ci.draw_set_transform(from.lerp(at, u))
				ci.draw_texture(ship_texture, -half, Color(col.lerp(Color(0.55, 0.9, 1.0), 0.35), (0.25 + 0.55 * u) * k))
			ci.draw_set_transform(Vector2.ZERO)
		&"salvo":
			var sprite := String(e["sprite"])
			var tex: Texture2D = _tex.get(sprite)
			if tex == null:
				return
			var points: PackedVector2Array = e["points"]
			var angles: PackedFloat32Array = e["angles"]
			var shots: PackedInt32Array = e["shots"]
			var tints: Array = e["tints"]
			var tinted := sprite in TINTED
			var half := tex.get_size() * 0.5
			for i: int in range(points.size()):
				var c := Color(1, 1, 1)
				if tinted:
					c = Color(String(tints[shots[i] % tints.size()])) if not tints.is_empty() else col
				ci.draw_set_transform(points[i], angles[i] + PI * 0.5)
				ci.draw_texture(tex, -half, c)
			ci.draw_set_transform(Vector2.ZERO)
		&"reflect":
			if waiting:
				return
			var tex: Texture2D = _tex["shield_front"]
			var pulse := 1.0 + 0.06 * sin(time * 14.0)
			var size := Vector2(float(e["width"]), float(e["height"])) * pulse
			ci.draw_texture_rect(tex, Rect2(at - size * 0.5, size), false, Color(1, 1, 1, 0.92 * _life(e) * k))
		&"orbitals":
			var tex: Texture2D = _tex["orb"]
			var s := float(e["radius"]) * 2.4 / 16.0
			var size := tex.get_size() * s
			for p: Vector2 in e["points"] as PackedVector2Array:
				ci.draw_texture_rect(tex, Rect2(p - size * 0.5, size), false, Color(1, 1, 1, _life(e)))
		&"barrier":
			if waiting:
				return
			var tex: Texture2D = _tex["barrier"]
			var w := float(e["width"])
			var h := float(e["height"])
			var a := _life(e) * k
			var tall := h * WALL_SCALE
			ci.draw_rect(Rect2(at.x - w * 0.5, at.y - tall * 0.5, w, tall), Color(col.darkened(0.2), 0.22 * a))
			var rect := Rect2(at.x - w * 0.5, at.y - tall * 0.5, w, tall)
			ci.draw_texture_rect_region(tex, rect, Rect2(fposmod(time * 36.0, 160.0), 0, w, tex.get_height()),
					Color(1, 1, 1, 0.95 * a))
			var inner := Rect2(at.x - w * 0.5, at.y - tall * 0.22, w, tall * 0.44)
			ci.draw_texture_rect_region(tex, inner, Rect2(fposmod(-time * 22.0, 160.0), 0, w, tex.get_height()),
					Color(1, 1, 1, 0.45 * a))
		&"wave":
			if waiting:
				return
			var tex: Texture2D = _tex["wave"]
			var h := float(e["height"]) * 1.4
			var w := float(e["width"])
			# Corpo d'água translúcido que a crista arrasta, depois a crista com a espuma correndo de lado.
			ci.draw_rect(Rect2(0, at.y + h * 0.3, w, 26.0), Color(col.lerp(Color(0.3, 0.8, 1.0), 0.5), 0.14))
			ci.draw_rect(Rect2(0, at.y + h * 0.3 + 26.0, w, 22.0), Color(col.lerp(Color(0.3, 0.8, 1.0), 0.5), 0.06))
			ci.draw_texture_rect_region(tex, Rect2(0, at.y - h * 0.5, w, h), Rect2(fposmod(time * 70.0, 270.0), 0,
					w, tex.get_height()), Color(1, 1, 1, 0.95))
		&"vortex":
			if waiting:
				return
			var tex: Texture2D = _tex["vortex"]
			var r := float(e["radius"]) * (0.85 + 0.15 * _life(e))
			ci.draw_set_transform(at, -time * 5.0)
			ci.draw_texture_rect(tex, Rect2(-r, -r, r * 2.0, r * 2.0), false, Color(1, 1, 1, 0.8 * _life(e) * k))
			ci.draw_set_transform(Vector2.ZERO)
		&"strike":
			_draw_mortars(ci, e)
		&"drones":
			var tex: Texture2D = _tex["kamikaze"]
			var half := tex.get_size() * 0.5
			for p: Vector2 in e["points"] as PackedVector2Array:
				ci.draw_set_transform(p, 0.0)
				ci.draw_texture(tex, -half, Color(1, 1, 1, maxf(0.3, _life(e))))
			ci.draw_set_transform(Vector2.ZERO)


## Morteiros do Ariete: durante o aviso de cada alvo a granada cai do alto, crescendo, com a sombra no chão.
func _draw_mortars(ci: CanvasItem, e: Dictionary) -> void:
	var tex: Texture2D = _tex["mortar"]
	var points: PackedVector2Array = e["points"]
	var warns: PackedInt32Array = e["warns"]
	var warn := float(e["warn"])
	for i: int in range(points.size()):
		var w := float(warns[i])
		if w < 0.0 or w > warn:
			continue
		var u := 1.0 - w / maxf(1.0, warn)
		var p := points[i]
		ci.draw_set_transform(p + Vector2(3, 4), 0.0, Vector2(0.4 + 0.6 * u, 0.25 + 0.15 * u))
		ci.draw_texture(_glow, -_glow.get_size() * 0.5, Color(0, 0.02, 0.06, 0.45 * u))
		var s := 0.7 + 0.6 * u
		ci.draw_set_transform(p + Vector2(0, -MORTAR_DROP * (1.0 - u * u)), time * 9.0 + i, Vector2(s, s))
		ci.draw_texture(tex, -tex.get_size() * 0.5)
	ci.draw_set_transform(Vector2.ZERO)


func _add(ci: CanvasItem, sim: Sim, e: Dictionary, k: float) -> void:
	var col := Color(String(e["color"]))
	var at: Vector2 = e["pos"]
	var waiting := int(e["wait"]) > 0
	match e["type"]:
		&"dash":
			if waiting:
				return
			var from: Vector2 = e["from"]
			var w := float(e["width"]) * 1.3
			var tint := col.lerp(Color(0.7, 0.95, 1.0), 0.3)
			_strip(ci, _tex["dash_trail"], from, at, w, Color(tint, 0.95 * k))
			_strip(ci, _beam, from, at, w * 0.35, Color(1, 1, 1, 0.85 * k))
			var d := at - from
			if d.length() > 4.0:
				var side := d.normalized().orthogonal()
				for j: int in range(SPEED_LINES):
					var off := side * (float(j) - (SPEED_LINES - 1) * 0.5) * (w * 0.55)
					var lag := 0.15 + 0.12 * float((j * 7) % SPEED_LINES)
					_strip(ci, _beam, from + off + d * lag, at + off - d * 0.05, 1.6, Color(tint, 0.7 * k))
			_centered(ci, _flare, at, 0.8, Color(col, _flash(0.85) * k))
		&"ring":
			if waiting:
				# Mergulho Solar: a nave sobe ao sol antes do choque (um sol que cresce acima dela).
				var u := 1.0 - float(e["wait"]) / maxf(1.0, float((e["_spec"] as Dictionary).get("delay", 30)))
				var sun := sim.player.pos + Vector2(0, -36.0 * u)
				_centered(ci, _flare, sun, 0.6 + 1.6 * u, Color(1.0, 0.9, 0.6, _flash(0.85)))
				_centered(ci, _sparkle, sun, 2.0 + 3.0 * u, Color(1, 1, 1, _flash(0.9)))
				return
			var r := float(e["radius"])
			var u := r / maxf(1.0, float(e["max"]))
			var a := (1.0 - u * u) * k
			ci.draw_texture_rect(_shock, Rect2(at - Vector2(r, r), Vector2(r, r) * 2.0), false, Color(col, 0.95 * a))
			var r2 := r * 0.82
			ci.draw_texture_rect(_shock, Rect2(at - Vector2(r2, r2), Vector2(r2, r2) * 2.0), false,
					Color(1, 1, 1, _flash(0.55) * a))
			if u < 0.2:
				_centered(ci, _flare, at, 1.8 * (1.0 - u * 5.0), Color(col, _flash(0.6)))
		&"salvo":
			var points: PackedVector2Array = e["points"]
			var shots: PackedInt32Array = e["shots"]
			var tints: Array = e["tints"]
			var glow := 0.32 if String(e["sprite"]) != "torpedo" else 0.55
			for i: int in range(points.size()):
				var c := col if tints.is_empty() else Color(String(tints[shots[i] % tints.size()]))
				_centered(ci, _flare, points[i], glow, Color(c, 0.55))
		&"beam":
			if not waiting:
				_draw_beams(ci, e, col, k)
		&"slow":
			if waiting:
				return
			# Ondas de tempo saindo da nave, lentas, a cada 0,7 s.
			for j: int in range(3):
				var u := fposmod(time / 2.1 + j / 3.0, 1.0)
				var r := 20.0 + u * 180.0
				ci.draw_texture_rect(_ring, Rect2(at - Vector2(r, r), Vector2(r, r) * 2.0), false,
						Color(0.55, 0.8, 1.0, 0.35 * (1.0 - u) * _life(e)))
		&"chain":
			if not waiting:
				_draw_chain(ci, sim, e, col, k)
		&"wave":
			if waiting:
				return
			_centered_rect(ci, _glow, Rect2(0, at.y - 24.0, float(e["width"]), 48.0), Color(col, 0.28))
		&"vortex":
			if waiting:
				return
			var r := float(e["radius"])
			var a := _life(e) * k
			ci.draw_set_transform(at, time * 3.0)
			ci.draw_texture_rect(_tex["vortex"], Rect2(-r * 0.8, -r * 0.8, r * 1.6, r * 1.6), false, Color(col, 0.3 * a))
			ci.draw_set_transform(Vector2.ZERO)
			_centered(ci, _flare, at, r / 40.0, Color(col, 0.45 * a))
		&"reflect":
			if waiting:
				return
			_centered(ci, _flare, at, 0.9, Color(1.0, 0.85, 0.4, 0.35 * _life(e) * k))
			for p: Vector2 in e["points"] as PackedVector2Array:
				_centered(ci, _flare, p, 0.22, Color(1.0, 0.85, 0.4, 0.85))
				_centered(ci, _sparkle, p, 1.0, Color(1, 1, 1, 0.9))
		&"orbitals":
			var a := _life(e)
			var spec: Dictionary = e["_spec"]
			var orbit := float(spec.get("radius", 30.0))
			ci.draw_texture_rect(_ring, Rect2(at - Vector2(orbit, orbit), Vector2(orbit, orbit) * 2.0), false,
					Color(col, 0.22 * a))
			for p: Vector2 in e["points"] as PackedVector2Array:
				_centered(ci, _flare, p, 0.45, Color(col, 0.6 * a))
		&"barrier":
			if waiting:
				return
			var w := float(e["width"])
			var h := float(e["height"])
			var a := _life(e) * k
			var tall := h * WALL_SCALE
			_centered_rect(ci, _glow, Rect2(at.x - w * 0.5 - 18.0, at.y - tall * 1.4, w + 36.0, tall * 2.8),
					Color(col, 0.55 * a * (0.85 + 0.15 * sin(time * 9.0))))
			# Brilho correndo pela parede e as bordas acesas em cima e embaixo.
			var sweep := at.x - w * 0.5 + fposmod(time * 140.0, w + 40.0) - 20.0
			_centered_rect(ci, _glow, Rect2(sweep - 16.0, at.y - tall * 0.6, 32.0, tall * 1.2), Color(1, 1, 1, 0.5 * a))
			for edge: float in [-0.5, 0.5]:
				ci.draw_texture_rect(_beam, Rect2(at.x - w * 0.5, at.y + tall * edge - 1.5, w, 3.0), false,
						Color(col.lerp(Color.WHITE, 0.5), 0.9 * a))
		&"strike":
			_draw_warns(ci, e, col)
		&"drones":
			_draw_drones(ci, e, col)
		&"cloak":
			if not waiting:
				_centered(ci, _ring, at, 1.4 + 0.1 * sin(time * 10.0), Color(col, 0.35 * _life(e)))
		&"aura":
			if waiting:
				return
			var r := float(e["radius"]) * 1.25
			var a := _life(e) * k
			ci.draw_set_transform(at, time * 2.5)
			ci.draw_texture_rect(_tex["corona"], Rect2(-r, -r, r * 2.0, r * 2.0), false, Color(1, 1, 1, 0.95 * a))
			ci.draw_set_transform(at, -time * 1.7, Vector2(0.86, 0.86))
			ci.draw_texture_rect(_tex["corona"], Rect2(-r, -r, r * 2.0, r * 2.0), false, Color(col, 0.45 * a))
			ci.draw_set_transform(Vector2.ZERO)
		&"overdrive":
			if waiting:
				return
			var a := _life(e)
			var spec: Dictionary = e["_spec"]
			_centered(ci, _flare, at, 0.95 + 0.12 * sin(time * 12.0), Color(col, _flash(0.22) * a))
			if float(spec.get("crit", 0.0)) > 0.0:
				var tex: Texture2D = _tex["reticle"]
				ci.draw_set_transform(at + Vector2(0, -34), time * 2.0)
				ci.draw_texture(tex, -tex.get_size() * 0.5, Color(1, 1, 1, 0.85 * a))
				ci.draw_set_transform(Vector2.ZERO)
			if float(spec.get("blast_radius", 0.0)) > 0.0:
				var u := fposmod(time * 1.6, 1.0)
				_centered(ci, _ring, at, 1.0 + u * 1.6, Color(col, 0.5 * (1.0 - u) * a))
		&"delayed_blast":
			_draw_blast(ci, e, col, k)


## Feixes (Lança de Coral, Prisma Abissal, Raio do Abismo, o feixe da Ascensão): halo largo, corpo na cor da
## nave e núcleo branco, que abrem nos primeiros passos e fecham no fim; os largos ganham pulsos que sobem
## e bordas que tremem.
func _draw_beams(ci: CanvasItem, e: Dictionary, col: Color, k: float) -> void:
	var at: Vector2 = e["pos"]
	var width := float(e["width"])
	var length := float(e["length"])
	var open := clampf(float(e["frames"]) / 4.0, 0.0, 1.0)
	var close := clampf((float(e["total"]) - float(e["frames"])) / 8.0, 0.0, 1.0)
	var wob := 1.0 + (0.08 if width >= 20.0 else 0.04) * sin(time * 47.0)
	var w := width * open * close * wob * (0.6 + 0.4 * k)
	var a := k
	for angle: float in e["angles"] as PackedFloat32Array:
		var dir := Vector2.from_angle(angle)
		var from := at + dir * 14.0
		var to := at + dir * length
		if width < 20.0:
			_strip(ci, _beam, from, to, w * 3.0, Color(col, _flash(0.26) * a))
			_strip(ci, _beam, from, to, w * 1.4, Color(col, 0.7 * a))
			_strip(ci, _beam, from, to, w * 0.5, Color(1, 1, 1, 0.92 * a))
			_centered(ci, _flare, from, maxf(0.5, w / 14.0), Color(col.lerp(Color.WHITE, 0.5), _flash(0.95) * a))
			continue
		_draw_colossal(ci, from, dir, length, w, col, a)


## Feixe colossal (Raio do Abismo): corpo ciano translúcido (quem está embaixo continua visível), bordas
## acesas que ondulam, um fio claro no meio e anéis de energia subindo; nada de núcleo branco largo.
func _draw_colossal(ci: CanvasItem, from: Vector2, dir: Vector2, length: float, w: float, col: Color, a: float) -> void:
	var to := from + dir * length
	var side := dir.orthogonal()
	_strip(ci, _beam, from, to, w * 2.2, Color(col, _flash(0.14) * a))
	_strip(ci, _beam, from, to, w * 1.1, Color(col, 0.32 * a))
	_strip(ci, _beam, from, to, w * 0.12, Color(col.lerp(Color.WHITE, 0.6), 0.6 * a))
	var segs := 10
	for edge: float in [-1.0, 1.0]:
		var prev := from + side * edge * w * 0.5
		for j: int in range(1, segs + 1):
			var u := float(j) / segs
			var wob := sin(time * 18.0 + u * 14.0 + edge) * w * 0.06
			var p := from + dir * length * u + side * (edge * w * 0.5 + wob)
			_strip(ci, _beam, prev, p, 3.0, Color(col.lerp(Color.WHITE, 0.45), 0.85 * a))
			prev = p
	if fx_level >= 1:
		for j: int in range(5):
			var d := fposmod(time * 380.0 + j * 92.0, length)
			var c := from + dir * d
			_strip(ci, _beam, c - side * w * 0.48, c + side * w * 0.48, 2.0, Color(col.lerp(Color.WHITE, 0.3), 0.45 * a))
	_centered(ci, _flare, from, maxf(0.5, w / 22.0), Color(col.lerp(Color.WHITE, 0.3), _flash(0.7) * a))


## Tempestade Elétrica: o raio do momento em segmentos de bolt.png entre os vértices, clarão que apaga entre
## um disparo e o próximo e brilho em cada salto.
func _draw_chain(ci: CanvasItem, sim: Sim, e: Dictionary, col: Color, k: float) -> void:
	var points: PackedVector2Array = e["points"]
	var at: Vector2 = e["pos"]
	# A nave estala carregada o tempo todo (quatro arcos girando em volta dela).
	for j: int in range(4):
		var dir := Vector2.from_angle(time * 7.0 + j * TAU / 4.0)
		var mid := at + dir * 14.0 + dir.orthogonal() * sin(time * 50.0 + j) * 5.0
		_strip(ci, _tex["bolt"], at + dir * 7.0, mid, 6.0, Color(1, 1, 1, 0.6 * k), true)
		_strip(ci, _tex["bolt"], mid, at + dir * 24.0, 6.0, Color(1, 1, 1, 0.6 * k), true)
	if points.size() < 2:
		_draw_storm(ci, sim, at, col, k)
		return
	var flash := float(e["flash"])
	var a := maxf(0.2, 1.0 - flash / 10.0) * k
	var bolt: Texture2D = _tex["bolt"]
	for i: int in range(points.size() - 1):
		var p0 := points[i]
		var p1 := points[i + 1]
		var mid := (p0 + p1) * 0.5 + (p1 - p0).orthogonal().normalized() * sin(time * 60.0 + i) * 5.0
		_strip(ci, bolt, p0, mid, 10.0, Color(1, 1, 1, a), true)
		_strip(ci, bolt, mid, p1, 10.0, Color(1, 1, 1, a), true)
		_strip(ci, _beam, p0, p1, 22.0, Color(col, _flash(0.25) * a))
	for p: Vector2 in points:
		_centered(ci, _flare, p, 0.55, Color(col.lerp(Color.WHITE, 0.4), _flash(0.85) * a))


## Sem alvo para o raio da Sim: um raio (só desenho) cai a cada STORM_STEP s numa bala inimiga da tela ou num
## ponto do campo, ziguezagueando da nave até lá e apagando antes do próximo.
func _draw_storm(ci: CanvasItem, sim: Sim, at: Vector2, col: Color, k: float) -> void:
	var beat := floori(time / STORM_STEP)
	var u := fposmod(time, STORM_STEP) / STORM_STEP
	var roll := absi(hash(beat * 7919))
	var target := Vector2(float(roll % 230) + 20.0, float((roll / 230) % 260) + 30.0)
	var pool := sim.enemy_bullets
	if pool.count > 0:
		target = pool.pos[roll % pool.count]
	var a := (1.0 - u) * k
	var prev := at
	for j: int in range(1, 6):
		var t := float(j) / 5.0
		var jitter := float(absi(hash(beat * 31 + j)) % 100) / 100.0 - 0.5
		var p := at.lerp(target, t) + (target - at).orthogonal().normalized() * jitter * 22.0 * (1.0 - absf(t - 0.5) * 2.0)
		if j == 5:
			p = target
		_strip(ci, _tex["bolt"], prev, p, 9.0, Color(1, 1, 1, a), true)
		_strip(ci, _beam, prev, p, 20.0, Color(col, _flash(0.22) * a))
		prev = p
	_centered(ci, _flare, target, 0.6, Color(col.lerp(Color.WHITE, 0.4), _flash(0.9) * a))


func _draw_warns(ci: CanvasItem, e: Dictionary, col: Color) -> void:
	var tex: Texture2D = _tex["warn_circle"]
	var points: PackedVector2Array = e["points"]
	var warns: PackedInt32Array = e["warns"]
	var warn := float(e["warn"])
	var r := float(e["radius"])
	for i: int in range(points.size()):
		var w := float(warns[i])
		if w < 0.0 or w > warn:
			continue
		var u := 1.0 - w / maxf(1.0, warn)
		var blink := 0.7 + 0.3 * sin(time * (14.0 + 20.0 * u))
		ci.draw_set_transform(points[i], time * 1.5 + i)
		ci.draw_texture_rect(tex, Rect2(-r, -r, r * 2.0, r * 2.0), false, Color(1, 1, 1, 0.85 * blink))
		var inner := r * u
		ci.draw_texture_rect(_glow, Rect2(-inner, -inner, inner * 2.0, inner * 2.0), false, Color(col, 0.35 * u))
	ci.draw_set_transform(Vector2.ZERO)


func _draw_drones(ci: CanvasItem, e: Dictionary, col: Color) -> void:
	var points: PackedVector2Array = e["points"]
	var a := maxf(0.3, _life(e))
	if bool(e["ring"]):
		for i: int in range(points.size()):
			var p0 := points[i]
			var p1 := points[(i + 1) % points.size()]
			_strip(ci, _beam, p0, p1, 9.0, Color(col, 0.55 * a))
			_strip(ci, _beam, p0, p1, 3.0, Color(1, 1, 1, 0.8 * a))
	for p: Vector2 in points:
		_centered(ci, _flare, p, 0.35, Color(col, 0.6 * a))
	for b: Vector2 in e["bullets"] as PackedVector2Array:
		ci.draw_texture_rect(_beam, Rect2(b.x - 1.5, b.y - 5.0, 3.0, 10.0), false, Color(col.lerp(Color.WHITE, 0.5), 0.95))
		_centered(ci, _flare, b, 0.16, Color(col, 0.7))


## Explosão atrasada: no aviso, o círculo de mira (Granada, Cataclismo) ou a implosão da Supernova; depois o
## clarão que cresce e some.
func _draw_blast(ci: CanvasItem, e: Dictionary, col: Color, k: float) -> void:
	var at: Vector2 = e["pos"]
	var r := float(e["radius"])
	var spec: Dictionary = e["_spec"]
	var implode := bool(spec.get("implode", false))
	var nova: Texture2D = _tex["supernova"]
	if int(e["wait"]) > 0:
		var u := 1.0 - float(e["wait"]) / maxf(1.0, float(spec.get("delay", 30)))
		if implode:
			var s := lerpf(150.0, 26.0, u * u)
			ci.draw_set_transform(at, -time * 6.0)
			ci.draw_texture_rect(nova, Rect2(-s, -s, s * 2.0, s * 2.0), false, Color(1, 1, 1, _flash(0.4 + 0.5 * u)))
			ci.draw_set_transform(Vector2.ZERO)
			_centered(ci, _flare, at, 0.6 + u * 0.8, Color(1, 1, 1, _flash(0.9)))
		else:
			var tex: Texture2D = _tex["warn_circle"]
			ci.draw_set_transform(at, time * 2.0)
			ci.draw_texture_rect(tex, Rect2(-r, -r, r * 2.0, r * 2.0), false,
					Color(col.lerp(Color.WHITE, 0.4), 0.5 + 0.5 * u))
			ci.draw_set_transform(Vector2.ZERO)
		return
	var u := clampf(float(e["frames"]) / maxf(1.0, float(e["total"])), 0.0, 1.0)
	var grow := 1.0 - (1.0 - u) * (1.0 - u)
	var a := (1.0 - u) * k
	if implode:
		var s := r * (0.25 + 0.95 * grow)
		ci.draw_set_transform(at, time * 2.0)
		ci.draw_texture_rect(nova, Rect2(-s, -s, s * 2.0, s * 2.0), false, Color(1, 1, 1, _flash(0.95) * a))
		ci.draw_set_transform(Vector2.ZERO)
	else:
		var s := r * (0.5 + 0.7 * grow)
		var fire := Color(col.lerp(Color(1.0, 0.7, 0.4), 0.5), _flash(0.8) * a)
		ci.draw_texture_rect(nova, Rect2(at - Vector2(s, s), Vector2(s, s) * 2.0), false, fire)
		ci.draw_texture_rect(_shock, Rect2(at - Vector2(s, s) * 1.1, Vector2(s, s) * 2.2), false, Color(col, 0.9 * a))


## Eclipse Total: a tela escurece (menos um halo em volta da nave), o disco negro sobe no meio do campo e, no
## fim, cresce e acende antes de soltar (o clarão vem do evento power_blast).
func _draw_eclipse(ci: CanvasItem, sim: Sim, e: Dictionary) -> void:
	var frames := float(e["frames"])
	var total := maxf(1.0, float(e["total"]))
	var u := frames / total
	var shade := Color(ECLIPSE_SHADE, ECLIPSE_SHADE.a * clampf(frames / 18.0, 0.0, 1.0))
	var f := Playfield.FIELD
	var p := sim.player.pos
	var h := ECLIPSE_HOLE
	ci.draw_rect(Rect2(0, 0, f.x, maxf(0.0, p.y - h)), shade)
	ci.draw_rect(Rect2(0, p.y + h, f.x, maxf(0.0, f.y - p.y - h)), shade)
	ci.draw_rect(Rect2(0, p.y - h, maxf(0.0, p.x - h), h * 2.0), shade)
	ci.draw_rect(Rect2(p.x + h, p.y - h, maxf(0.0, f.x - p.x - h), h * 2.0), shade)
	ci.draw_texture_rect(_hole, Rect2(p - Vector2(h, h), Vector2(h, h) * 2.0), false, shade)
	var disc: Texture2D = _tex["eclipse_disc"]
	var rise := clampf(frames / 30.0, 0.0, 1.0)
	var swell := clampf((u - 0.8) / 0.2, 0.0, 1.0)
	var s := (0.75 + 0.25 * rise + 0.35 * swell * swell) * 1.15
	var center := Vector2(f.x * 0.5, f.y * 0.36 + 30.0 * (1.0 - rise))
	ci.draw_set_transform(center, time * 0.2, Vector2(s, s))
	ci.draw_texture(disc, -disc.get_size() * 0.5, Color(1, 1, 1, rise))
	ci.draw_set_transform(Vector2.ZERO)


## Textura esticada de `from` a `to` (o "para cima" da textura aponta para `to`); `tile` repete na vertical.
func _strip(ci: CanvasItem, tex: Texture2D, from: Vector2, to: Vector2, width: float, color: Color,
		tile: bool = false) -> void:
	var d := to - from
	var length := d.length()
	if length < 0.5 or tex == null:
		return
	ci.draw_set_transform(from, d.angle() + PI * 0.5)
	ci.draw_texture_rect(tex, Rect2(-width * 0.5, -length, width, length), tile, color)
	ci.draw_set_transform(Vector2.ZERO)


func _centered(ci: CanvasItem, tex: Texture2D, at: Vector2, scale: float, color: Color) -> void:
	if tex == null:
		return
	var size := tex.get_size() * scale
	ci.draw_texture_rect(tex, Rect2(at - size * 0.5, size), false, color)


func _centered_rect(ci: CanvasItem, tex: Texture2D, rect: Rect2, color: Color) -> void:
	if tex != null:
		ci.draw_texture_rect(tex, rect, false, color)
