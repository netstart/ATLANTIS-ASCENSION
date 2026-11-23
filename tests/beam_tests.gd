extends RefCounted
## Testes do feixe dos padrões (EnemyBeam, revisão 6 da Sim): a boca segue o emissor que anda, o aviso mira o jogador
## e trava, o giro aceso respeita o teto, a colisão é no segmento inclinado, a nave que anda escapa, o emissor que
## some leva o feixe junto e a revisão 5 (replays antigos) continua com o feixe parado e vertical. Chamado por
## tests/run_tests.gd (regras rápidas, sem autoloads).

const EMPTY := {"id": "beam_test", "chapter": 1, "events": []}
const WARN := 40
const FRAMES := 60

var _tables: Dictionary = {}


func run_unit(check: Callable) -> void:
	_tables = Sim.load_tables()
	_follow(check)
	_aim_and_turn(check)
	_segment(check)
	_escape(check)
	_emitter_gone(check)
	_columns(check)
	_old_revision(check)


func _sim(rev: int = SimRevision.CURRENT, field_h: float = Playfield.FIELD.y) -> Sim:
	var sim := Sim.new()
	var load := Sim.default_loadout(&"falcon")
	load["rev"] = rev
	load["field_h"] = field_h
	sim.setup(EMPTY, _tables, load, 7)
	sim.player.invuln = 0
	return sim


func _runner(extra: Dictionary = {}) -> PatternRunner:
	var step := {"op": "beam", "warn_frames": WARN, "frames": FRAMES, "width": 20, "oy": 12}
	step.merge(extra, true)
	return PatternRunner.new({"steps": [step, {"op": "wait", "frames": 999}], "loop": false})


## Um passo como o da Sim: o emissor roda o runner em `at` (se vivo), depois os feixes envelhecem.
func _tick(sim: Sim, runner: PatternRunner, at: Vector2, alive: bool = true) -> void:
	sim.frame += 1
	if alive:
		runner.step(sim, at, true)
	sim._beams_step()


func _follow(check: Callable) -> void:
	var sim := _sim()
	var runner := _runner()
	var ok := true
	for f: int in range(WARN + 20):
		var at := Vector2(80.0 + f * 1.5, 90.0 + sin(f * 0.1) * 8.0)
		_tick(sim, runner, at)
		var b: Dictionary = sim.beams[0]
		ok = ok and b.has("src") and Vector2(float(b["x"]), float(b["y"])) == at + Vector2(0, 12)
	check.call(sim.beams.size() == 1 and ok, "Feixe: a boca segue o emissor que anda, passo a passo")


func _aim_and_turn(check: Callable) -> void:
	var sim := _sim()
	var runner := _runner()
	sim.player.pos = Vector2(200, 380)
	var aimed := true
	var locked := true
	var capped := true
	var turned := 0.0
	var lock := EnemyBeam.lock_at(WARN)
	var last := 0.0
	for f: int in range(WARN + FRAMES - 1):
		_tick(sim, runner, Vector2(135, 90))
		var b: Dictionary = sim.beams[0]
		var a := float(b["angle"])
		var age := int(b["age"])
		var want := (sim.player.hit_pos() - Vector2(135, 102)).angle()
		if age < lock:
			aimed = aimed and is_equal_approx(a, want)
		elif age <= WARN:
			locked = locked and a == last
		else:
			capped = capped and absf(angle_difference(last, a)) <= deg_to_rad(EnemyBeam.TRACK_DEG) * Sim.STEP + 1e-6
			turned += absf(angle_difference(last, a))
		last = a
		# A nave foge para a esquerda e para cima: o feixe vai atrás, sem alcançar.
		sim.player.pos = Vector2(200.0 - f * 2.0, 380.0) if age < lock else Vector2(60, 300)
	check.call(aimed, "Feixe: o aviso mira o jogador (linhas na mira real)")
	check.call(locked, "Feixe: a mira trava nos últimos passos do aviso (%d)" % (WARN - lock))
	check.call(capped and turned > 0.05, "Feixe: aceso, gira para o jogador no teto de %.0f°/s (girou %.1f°)"
			% [EnemyBeam.TRACK_DEG, rad_to_deg(turned)])


func _segment(check: Callable) -> void:
	var sim := _sim()
	var b := {"x": 100.0, "y": 100.0, "width": 20.0, "angle": PI * 0.25, "dead": false}
	var on := Vector2(100, 100) + Vector2.from_angle(PI * 0.25) * 150.0
	check.call(EnemyBeam.hits(b, on, 3.0, sim.field), "Feixe: acerta sobre o segmento inclinado")
	check.call(not EnemyBeam.hits(b, Vector2(100, 250), 3.0, sim.field),
			"Feixe: inclinado, não acerta embaixo da boca (onde o vertical acertaria)")
	check.call(not EnemyBeam.hits(b, Vector2(100, 100) - Vector2.from_angle(PI * 0.25) * 40.0, 3.0, sim.field),
			"Feixe: não acerta atrás da boca")
	var side := on + Vector2.from_angle(PI * 0.75) * 12.0
	check.call(EnemyBeam.hits(b, side, 3.0, sim.field) and not EnemyBeam.hits(b, side + Vector2.from_angle(PI * 0.75)
			* 2.0, 3.0, sim.field), "Feixe: largura medida na perpendicular (meia largura + hitbox)")
	b["dead"] = true
	check.call(not EnemyBeam.hits(b, on, 3.0, sim.field), "Feixe: cortado (fechando) não fere")
	# Pela colisão da Sim: a nave no feixe aceso inclinado leva dano de feixe.
	var runner := _runner()
	sim.player.pos = Vector2(220, 330)
	for f: int in range(WARN):
		_tick(sim, runner, Vector2(60, 90))
	var hull := sim.player.hull
	sim._collide_ship(sim.player)
	check.call(sim.player.hull == hull - 1 and sim.last_cause == &"beam", "Feixe: a nave parada na mira leva o feixe")


## A nave mais lenta (0,85), andando de lado na velocidade normal desde a trava da mira, nunca é atingida; parada,
## seria. Mede a justiça do giro (TRACK_DEG) com o feixe mais largo de mira dos chefes (30 u, Leviatã).
func _escape(check: Callable) -> void:
	var escaped := true
	var stood := 0
	for start: Vector2 in [Vector2(135, 390), Vector2(40, 560), Vector2(230, 300)]:
		for run: int in range(2):
			var sim := _sim(SimRevision.CURRENT, 640.0)
			var runner := _runner({"width": 30, "frames": 60})
			sim.player.pos = start
			var hits := 0
			var dir := -1.0 if start.x > 135.0 else 1.0
			for f: int in range(WARN + FRAMES - 1):
				_tick(sim, runner, Vector2(135, 96))
				if run == 0 and int((sim.beams[0] as Dictionary)["age"]) >= EnemyBeam.lock_at(WARN):
					sim.player.pos.x += dir * SimPlayer.AXIS_SPEED * 0.85
					sim.player.keep_inside()
				if EnemyBeam.hits(sim.beams[0], sim.player.hit_pos(), sim.player.hitbox, sim.field) \
						and int((sim.beams[0] as Dictionary)["age"]) >= WARN:
					hits += 1
			if run == 0:
				escaped = escaped and hits == 0
			elif hits > 0:
				stood += 1
	check.call(escaped, "Feixe: a nave que anda a partir da trava da mira escapa (giro de %.0f°/s)" % EnemyBeam.TRACK_DEG)
	check.call(stood == 3, "Feixe: a nave parada é atingida (%d de 3)" % stood)


func _emitter_gone(check: Callable) -> void:
	var sim := _sim()
	var runner := _runner()
	for f: int in range(10):
		_tick(sim, runner, Vector2(135, 90))
	_tick(sim, runner, Vector2(135, 90), false)
	check.call(sim.beams.is_empty(), "Feixe: emissor que some no aviso leva o feixe junto")
	sim = _sim()
	runner = _runner()
	for f: int in range(WARN + 10):
		_tick(sim, runner, Vector2(135, 90))
	_tick(sim, runner, Vector2(135, 90), false)
	var b: Dictionary = sim.beams[0] if not sim.beams.is_empty() else {}
	var closing := not b.is_empty() and bool(b["dead"])
	for f: int in range(EnemyBeam.CLOSE_FRAMES):
		_tick(sim, runner, Vector2(135, 90), false)
	check.call(closing and sim.beams.is_empty(), "Feixe: emissor que some com o feixe aceso: fecha sem ferir e some")


func _columns(check: Callable) -> void:
	var sim := _sim()
	var runner := _runner({"aim": false})
	sim.player.pos = Vector2(30, 400)
	var down := true
	for f: int in range(WARN + 30):
		_tick(sim, runner, Vector2(135 + f, 90))
		down = down and float((sim.beams[0] as Dictionary)["angle"]) == EnemyBeam.DOWN
	check.call(down, "Feixe: coluna (aim false) fica vertical e só segue a boca")


## Revisão 5: o feixe nasce parado na vertical, onde o emissor estava, e fere só embaixo dele, como antes.
func _old_revision(check: Callable) -> void:
	var sim := _sim(5)
	var runner := _runner()
	for f: int in range(WARN + 5):
		_tick(sim, runner, Vector2(100.0 + f * 2.0, 90))
	var b: Dictionary = sim.beams[0]
	check.call(not b.has("src") and not b.has("angle") and float(b["x"]) == 100.0 and float(b["y"]) == 102.0,
			"Feixe: revisão 5 nasce parado na vertical (replays antigos)")
	sim.player.pos = Vector2(100, 300) - sim.player.hit_offset
	var hull := sim.player.hull
	sim._collide_ship(sim.player)
	check.call(sim.player.hull == hull - 1 and sim.last_cause == &"beam", "Feixe: revisão 5 fere embaixo da boca")
