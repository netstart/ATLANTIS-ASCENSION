class_name EnemyBeam
extends RefCounted
## Feixe dos padrões de tiro (op "beam" do PatternRunner) a partir da revisão 6 da Sim (SimRevision). Antes ele
## ficava parado onde nasceu, na vertical, e o chefe saía de baixo dele (Aríete de Coral). Agora:
## - Âncora: a boca do emissor (origem que o runner recebeu neste passo + ox/oy), seguida a cada passo. Emissor que
##   some (inimigo morto ou fora da tela, parte destruída, troca de etapa, chefe vencido) corta o feixe: no aviso ele
##   some; aceso, fecha em CLOSE_FRAMES passos sem ferir. Nunca fica um feixe órfão pendurado.
## - Ângulo: no aviso mira o jogador (as linhas mostram a mira real) e trava nos últimos LOCK_FRAMES, para dar tempo
##   de sair; aceso, gira para o jogador no máximo `track` graus/s (padrão TRACK_DEG), mais devagar que a nave.
##   `aim: false` aponta para baixo e não gira (colunas e faixas: Arquiteto, Leviatã, Poseidon, Portão).
## - Dano: distância do ponto ao segmento inclinado, da boca até a borda do campo.
## Feixes do cenário (raio, gêiser: Sim.on_stage_event) e replays de revisões antigas não passam por aqui.

## Revisão da Sim que liga este feixe (SimRevision).
const REVISION := 6
## Giro do feixe aceso. A nave anda 192 u/s (163 na mais lenta, 82 no modo preciso); a 300 u do chefe isso é 31°/s
## (16°/s no preciso). 12°/s varre a ponta a ~63 u/s: persegue, mas quem anda escapa (tests/sim_tests.gd).
const TRACK_DEG := 12.0
## Passos finais do aviso com a mira travada (0,4 s: a nave sai de um feixe de 24 u com folga).
const LOCK_FRAMES := 24
## Passos em que um feixe cortado (emissor sumiu) fecha, sem ferir.
const CLOSE_FRAMES := 8
const DOWN := PI * 0.5


## Feixe novo saindo de `origin` (centro do emissor, sem o deslocamento do passo). `src` é o runner do emissor.
static func add(sim: Sim, src: PatternRunner, origin: Vector2, s: Dictionary) -> void:
	var off := Vector2(float(s.get("ox", 0.0)), float(s.get("oy", 0.0)))
	var at := origin + off
	var width := float(s.get("width", 16.0))
	var warn := int(s.get("warn_frames", 30))
	# Oráculo de Nereu: avisos de feixe 50% mais longos (como Sim.add_beam).
	if sim.mods.oracle:
		warn = roundi(warn * 1.5)
	var aim := bool(s.get("aim", true))
	sim.beams.append({"x": at.x, "y": at.y, "width": width, "warn": warn, "frames": int(s.get("frames", 60)),
			"age": 0, "angle": _aim(sim, at) if aim else DOWN, "aim": aim,
			"track": deg_to_rad(float(s.get("track", TRACK_DEG))) if aim else 0.0, "src": src, "off": off,
			"dead": false})
	sim.emit(&"beam_warn", {"pos": at, "width": width})


## Um passo (depois de envelhecer): segue a boca e gira. Falso = tirar o feixe da lista.
static func follow(sim: Sim, b: Dictionary) -> bool:
	var age := int(b["age"])
	var warn := int(b["warn"])
	# Eclipse Total: os emissores param (não rodam o runner); o feixe espera junto, sem cortar.
	if not sim.powers.frozen and not bool(b["dead"]):
		var src: PatternRunner = b["src"]
		if src.seen != sim.frame:
			if age < warn:
				return false
			b["dead"] = true
			b["frames"] = mini(int(b["frames"]), age - warn + CLOSE_FRAMES)
			return true
		var at := src.last_origin + (b["off"] as Vector2)
		b["x"] = at.x
		b["y"] = at.y
	if bool(b["dead"]) or not bool(b["aim"]) or sim.powers.frozen:
		return true
	var want := _aim(sim, Vector2(float(b["x"]), float(b["y"])))
	if age < lock_at(warn):
		b["angle"] = want
	elif age > warn:
		var turn := float(b["track"]) * Sim.STEP
		var a := float(b["angle"])
		b["angle"] = a + clampf(angle_difference(a, want), -turn, turn)
	return true


## Passo do aviso em que a mira trava: LOCK_FRAMES antes do disparo, ou na metade de um aviso curto.
static func lock_at(warn: int) -> int:
	return maxi(warn - LOCK_FRAMES, warn - floori(warn * 0.5))


## A nave (ponto da hitbox) está no feixe aceso.
static func hits(b: Dictionary, p: Vector2, hb: float, field: Vector2) -> bool:
	if bool(b["dead"]):
		return false
	var a := Vector2(float(b["x"]), float(b["y"]))
	var d := Vector2.from_angle(float(b["angle"]))
	var rel := p - a
	var t := rel.dot(d)
	return t > 0.0 and t <= reach(a, d, field) and absf(d.cross(rel)) <= float(b["width"]) * 0.5 + hb


## Distância da boca `a`, na direção `d` (unitária), até sair do campo crescido de `margin`.
static func reach(a: Vector2, d: Vector2, field: Vector2, margin: float = 0.0) -> float:
	var best := INF
	if d.x > 0.0:
		best = minf(best, (field.x + margin - a.x) / d.x)
	elif d.x < 0.0:
		best = minf(best, (-margin - a.x) / d.x)
	if d.y > 0.0:
		best = minf(best, (field.y + margin - a.y) / d.y)
	elif d.y < 0.0:
		best = minf(best, (-margin - a.y) / d.y)
	return maxf(0.0, best)


static func _aim(sim: Sim, from: Vector2) -> float:
	var to := sim.player.hit_pos() - from
	return to.angle() if to.length_squared() > 1.0 else DOWN
