class_name HazardArt
extends RefCounted
## Desenhos de perigo e de clima do campo, fora do WorldView para ele caber no limite de linhas: a grade do
## Gravity Breach, o raio da tempestade e a escuridão do Registro Abissal. Só retângulos e texturas por quadro.

const LIGHTNING_COLOR := Color(0.85, 0.92, 1.0, 0.95)
const BREACH_COLOR := Color(0.75, 0.55, 1.0, 0.22)


## Gravity Breach: grade que escorre na direção da força e uma seta no centro (aviso de leitura).
static func breach(ci: CanvasItem, sim: Sim, time: float) -> void:
	var dir := sim.breach_dir.normalized()
	var shift := fposmod(time * 40.0, 24.0)
	for k: int in range(-1, int(sim.field.x / 24.0) + 2):
		var gx := k * 24.0 + dir.x * shift
		ci.draw_rect(Rect2(gx, 0, 1.0, sim.field.y), BREACH_COLOR)
	for k: int in range(-1, int(sim.field.y / 24.0) + 2):
		var gy := k * 24.0 + dir.y * shift
		ci.draw_rect(Rect2(0, gy, sim.field.x, 1.0), BREACH_COLOR)
	var c := sim.field * 0.5
	for k: int in range(5):
		var p := c + dir * (k * 6.0 - 12.0)
		ci.draw_rect(Rect2(p - Vector2(2, 2), Vector2(4, 4)), Color(0.85, 0.7, 1.0, 0.25 + 0.12 * k))


## Raio da tempestade: zigue-zague de segmentos (retângulos) com brilho, sorteado por passo.
static func lightning(ci: CanvasItem, x: float, y: float, w: float, length: float, age: int, reduce_flashes: bool,
		glow: Texture2D) -> void:
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
	if glow != null:
		ci.draw_texture_rect(glow, Rect2(Vector2(x, y + 8.0) - glow.get_size() * 0.5, glow.get_size()), false,
				Color(LIGHTNING_COLOR, 0.6))


## Escuridão do Registro Abissal: só um halo em volta da nave e o pulso do sonar a cada 2 s.
static func dark(ci: CanvasItem, sim: Sim, time: float, ring: Texture2D) -> void:
	var p := sim.player.pos
	var halo := 70.0
	var shade := Color(0.0, 0.01, 0.03, 0.86)
	var f := sim.field
	ci.draw_rect(Rect2(0, 0, f.x, maxf(0.0, p.y - halo)), shade)
	ci.draw_rect(Rect2(0, p.y + halo, f.x, maxf(0.0, f.y - p.y - halo)), shade)
	ci.draw_rect(Rect2(0, p.y - halo, maxf(0.0, p.x - halo), halo * 2.0), shade)
	ci.draw_rect(Rect2(p.x + halo, p.y - halo, maxf(0.0, f.x - p.x - halo), halo * 2.0), shade)
	var ping := fmod(time, 2.0) / 2.0
	if ring != null:
		var size := ring.get_size() * (1.0 + ping * 9.0)
		ci.draw_texture_rect(ring, Rect2(p - size * 0.5, size), false, Color(0.4, 1.0, 0.9, 0.5 * (1.0 - ping)))
