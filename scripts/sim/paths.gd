class_name Paths
extends RefCounted
## Trajetórias dos inimigos como funções puras do tempo (plano mestre 5.5): posição = f(origem, t,
## parâmetros). Sem estado: a mesma onda passa igual em qualquer velocidade de jogo.
##
## - straight: anda em linha reta (dir, speed).
## - dive: desce e faz a curva para o lado (side, amp, speed, k).
## - sine: desce em onda senoidal (amp, freq, speed, phase).
## - stop_go: desce até stop_y, para por hold s e sai (exit: down | left | right).
## - scroll: preso ao cenário, desce com a rolagem (speed).
## - hover: flutua em torno de um ponto (amp, freq), para chefes e torres.


static func position(path: StringName, origin: Vector2, t: float, p: Dictionary) -> Vector2:
	var speed := float(p.get("speed", 60.0))
	match path:
		&"straight":
			var dir := Vector2(float(p.get("dx", 0.0)), float(p.get("dy", 1.0))).normalized()
			return origin + dir * speed * t
		&"dive":
			var side := float(p.get("side", 1.0))
			var amp := float(p.get("amp", 90.0))
			var k := float(p.get("k", 1.4))
			return origin + Vector2(side * amp * (1.0 - cos(minf(t * k, PI))), speed * t)
		&"sine":
			var amp := float(p.get("amp", 40.0))
			var freq := float(p.get("freq", 0.5))
			var phase := float(p.get("phase", 0.0))
			return origin + Vector2(amp * sin((t * freq + phase) * TAU), speed * t)
		&"stop_go":
			return _stop_go(origin, t, p, speed)
		&"scroll":
			return origin + Vector2(0.0, speed * t)
		&"hover":
			var amp := float(p.get("amp", 12.0))
			var freq := float(p.get("freq", 0.25))
			return origin + Vector2(amp * sin(t * freq * TAU), amp * 0.4 * sin(t * freq * 2.0 * TAU))
	return origin + Vector2(0.0, speed * t)


static func _stop_go(origin: Vector2, t: float, p: Dictionary, speed: float) -> Vector2:
	var stop_y := float(p.get("stop_y", 120.0))
	var hold := float(p.get("hold", 3.0))
	var travel := maxf(stop_y - origin.y, 0.0)
	var t_in := travel / maxf(speed, 1.0)
	if t <= t_in:
		# Chega freando (ease-out) para a parada ser legível.
		var u := t / maxf(t_in, 0.001)
		return Vector2(origin.x, origin.y + travel * (1.0 - (1.0 - u) * (1.0 - u)))
	var stopped := Vector2(origin.x, stop_y)
	if t <= t_in + hold:
		return stopped
	var out := t - t_in - hold
	match StringName(String(p.get("exit", "down"))):
		&"left":
			return stopped + Vector2(-speed * 1.5 * out, -10.0 * out)
		&"right":
			return stopped + Vector2(speed * 1.5 * out, -10.0 * out)
	return stopped + Vector2(0.0, speed * 1.4 * out)
