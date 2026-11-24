extends RefCounted
## Testes do feixe dos padrões (EnemyBeam, revisão 6 da Sim): a boca segue o emissor que anda, o aviso mira o jogador
## e trava, o giro aceso respeita o teto, a colisão é no segmento inclinado, a nave que anda escapa, o emissor que
## some leva o feixe junto e a revisão 5 (replays antigos) continua com o feixe parado e vertical. Revisão 9: toda
## boca de feixe de chefe e de inimigo fica sobre a arte visível do emissor (nada de feixe saindo do vazio) e destruir o
## drone emissor corta o feixe dele. Chamado por tests/run_tests.gd (regras rápidas, sem autoloads).

const EMPTY := {"id": "beam_test", "chapter": 1, "events": []}
const WARN := 40
const FRAMES := 60
## Folga da boca até o pixel firme mais perto da arte do emissor (unidades na tela): o clarão da boca tem ~18 u.
const MOUTH_SLACK := 5.0
## Alfa a partir do qual o pixel da arte conta como casco (o mesmo de tools/fit_hitboxes.py).
const SOLID := 0.5

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
	_mouths_on_art(check)
	_drone_cuts_beam(check)
	_drone_data(check)


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


## Boca (âncora + ox/oy) de todo feixe de padrão que a revisão atual usa, em chefes e inimigos, em cima da arte do
## emissor: corpo (sprite girado 180°, na escala da tabela), parte com sprite, ou dentro do raio do drone/parte sem
## sprite. O Sky Leviathan tinha faixas a 95 u do casco, saindo do nada.
func _mouths_on_art(check: Callable) -> void:
	var patterns: Dictionary = _tables["patterns"]
	var bad: Array[String] = []
	var seen := 0
	for def: Dictionary in (_tables["bosses"] as Dictionary).values():
		var parts := {}
		for part: Dictionary in def.get("parts", []):
			if SimBoss.in_rev(part, SimRevision.CURRENT):
				parts[String(part.get("id", ""))] = part
		var body := Vector2(float(def.get("body_x", 0.0)), float(def.get("body_y", 0.0)))
		for ph: Dictionary in def.get("phases", []):
			for entry: Dictionary in ph.get("patterns", []):
				if not SimBoss.in_rev(entry, SimRevision.CURRENT):
					continue
				var anchor := String(entry.get("anchor", "body"))
				for st: Dictionary in (patterns.get(StringName(String(entry["pattern"])), {}) as Dictionary).get("steps", []):
					if String(st.get("op", "")) != "beam":
						continue
					seen += 1
					var off := Vector2(float(st.get("ox", 0.0)), float(st.get("oy", 0.0)))
					var ok := false
					if anchor == "body":
						ok = _on_art(String(def["sprite"]), float(def.get("scale", 1.0)), body + off)
					elif parts.has(anchor):
						var part: Dictionary = parts[anchor]
						var scale := float(part.get("part_scale", 1.0))
						var radius := float(part.get("radius", 10.0))
						ok = _on_art(String(part["sprite"]), scale, off) if part.has("sprite") else off.length() <= radius
					if not ok:
						bad.append("%s/%s %s@%s %s" % [def.get("id"), ph.get("id"), entry["pattern"], anchor, off])
	for def: Dictionary in (_tables["enemies"] as Dictionary).values():
		var pattern: Dictionary = patterns.get(StringName(String(def.get("pattern", ""))), {})
		for st: Dictionary in pattern.get("steps", []):
			if String(st.get("op", "")) == "beam":
				seen += 1
				var off := Vector2(float(st.get("ox", 0.0)), float(st.get("oy", 0.0)))
				if not _on_art(String(def.get("sprite", "")), float(def.get("scale", 1.0)), off):
					bad.append("%s %s %s" % [def.get("id"), def.get("pattern"), off])
	check.call(seen > 20 and bad.is_empty(), "Feixe: toda boca de feixe sai da arte do emissor (%d bocas; fora: %s)"
			% [seen, ", ".join(bad)])


## Há casco (alfa firme) a até MOUTH_SLACK de `at` (relativo ao centro, na tela) na arte HD de `sprite`, desenhada
## girada 180° com 2 texels por unidade vezes `scale` (WorldView._draw_ship, tools/fit_hitboxes.py).
func _on_art(sprite: String, scale: float, at: Vector2) -> bool:
	var fleet := sprite.get_slice("_", 0)
	var path := "res://assets/art/hd/%s/%s_base.png" % [fleet, sprite.trim_prefix(fleet + "_")]
	if not ResourceLoader.exists(path):
		return false
	var img := (load(path) as Texture2D).get_image()
	if img.is_compressed():
		img.decompress()
	var side := img.get_height()
	var unit := 0.5 * scale
	var cx := side * 0.5 - at.x / unit
	var cy := side * 0.5 - at.y / unit
	var r := MOUTH_SLACK / unit
	for y: int in range(maxi(0, floori(cy - r)), mini(side, ceili(cy + r) + 1)):
		for x: int in range(maxi(0, floori(cx - r)), mini(side, ceili(cx + r) + 1)):
			if Vector2(x + 0.5 - cx, y + 0.5 - cy).length() <= r and img.get_pixel(x, y).a >= SOLID:
				return true
	return false


## Olho da Tempestade (revisão 9): os dois drones saem do casco até o posto, cada feixe sai da lente do seu drone, e
## destruir um drone corta o feixe dele (fecha sem ferir) enquanto o do outro segue. Na revisão 8 não há drones e o
## padrão antigo continua (replays).
func _drone_cuts_beam(check: Callable) -> void:
	var sim := _sim()
	sim.spawn_boss(&"storm_eye", false)
	var boss := sim.boss
	var drones: Array[Dictionary] = []
	for part: Dictionary in boss.parts:
		if bool(part.get("drone", false)):
			drones.append(part)
	var mouth_ok := true
	var left: Dictionary = {}
	var right: Dictionary = {}
	for f: int in range(SimBoss.ENTER_FRAMES + 400):
		_boss_tick(sim)
		for b: Dictionary in sim.beams:
			var at := Vector2(float(b["x"]), float(b["y"]))
			var near := false
			for d: Dictionary in drones:
				near = near or at.distance_to(boss.part_pos(d)) < 0.01
			mouth_ok = mouth_ok and near
			if near and at.x < boss.pos.x:
				left = b
			elif near:
				right = b
		if not left.is_empty() and not right.is_empty() and int(right["age"]) > int(right["warn"]):
			break
	var home := boss.pos + (drones[0]["base"] as Vector2) if drones.size() == 2 else Vector2.INF
	var near := boss.part_pos(drones[0]).distance_to(home) <= 6.0 if drones.size() == 2 else false
	var posted := drones.size() == 2 and float(drones[0]["out"]) == 1.0 and near
	check.call(posted and mouth_ok and not left.is_empty() and not right.is_empty(),
			"Feixe: drones do Olho da Tempestade saem até o posto e cada feixe sai da lente de um drone")
	var kill: Dictionary = drones[1] if boss.part_pos(drones[1]).x > boss.pos.x else drones[0]
	var keep: Dictionary = drones[0] if kill == drones[1] else drones[1]
	# Vida própria: acertar o drone só tira dele; acertar o corpo não tira dos drones.
	var hp := boss.hp
	var mine := float(kill["hp"])
	boss.damage_part(kill, mine * 0.5, sim)
	var only_drone := boss.hp == hp and is_equal_approx(float(kill["hp"]), mine * 0.5) and bool(kill["alive"])
	var keep_hp := float(keep["hp"])
	var kill_hp := float(kill["hp"])
	boss.damage_body(10.0, sim)
	var only_body := boss.hp < hp and float(keep["hp"]) == keep_hp and float(kill["hp"]) == kill_hp
	hp = boss.hp
	boss.damage_part(kill, mine, sim)
	check.call(only_drone and only_body and not bool(kill["alive"]) and bool(keep["alive"]) and boss.hp == hp,
			"Feixe: drone tem vida própria (só a dele cai, morre sozinho, o chefe e o outro drone não perdem vida)")
	_boss_tick(sim)
	var cut := not bool(kill["alive"]) and (bool(right["dead"]) or not sim.beams.has(right))
	for f: int in range(EnemyBeam.CLOSE_FRAMES + 1):
		_boss_tick(sim)
	check.call(cut and not sim.beams.has(right), "Feixe: destruir o drone corta o feixe dele")
	var again := false
	for f: int in range(400):
		_boss_tick(sim)
		for b: Dictionary in sim.beams:
			again = again or float(b["x"]) > boss.pos.x
	check.call(not again, "Feixe: drone destruído não volta a atirar na luta")
	var old := _sim(8)
	old.spawn_boss(&"storm_eye", false)
	var none := true
	for part: Dictionary in old.boss.parts:
		none = none and not bool(part.get("drone", false))
	check.call(none, "Feixe: revisão 8 (replays antigos) sem drones no Olho da Tempestade")


## Todo drone emissor dos dados: vida própria bem menor que a do chefe (até 15%) e sem vazar para ele.
func _drone_data(check: Callable) -> void:
	var bad: Array[String] = []
	var count := 0
	for def: Dictionary in (_tables["bosses"] as Dictionary).values():
		for part: Dictionary in def.get("parts", []):
			if not bool(part.get("drone", false)):
				continue
			count += 1
			var hp := float(part.get("hp", 0.0))
			var leaks := float(part.get("leak", 0.25)) != 0.0 or float(part.get("share", 0.0)) != 0.0
			if hp <= 0.0 or hp > float(def.get("hp", 0.0)) * 0.15 or leaks:
				bad.append("%s/%s" % [def.get("id"), part.get("id")])
	check.call(count >= 8 and bad.is_empty(), "Feixe: %d drones com vida própria, menor que a do chefe, sem vazar (%s)"
			% [count, ", ".join(bad)])


## Um passo do chefe sozinho, como na Sim: o chefe roda os padrões, os feixes envelhecem.
func _boss_tick(sim: Sim) -> void:
	sim.frame += 1
	if sim.no_fire > 0:
		sim.no_fire -= 1
	sim.boss.step(sim)
	sim._beams_step()
