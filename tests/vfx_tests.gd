extends RefCounted
## Testes dos efeitos visuais da partida (ParticleField, CombatFx e o EnergyStream do bico) e da luz dos
## menus (UiSpark, AbyssMotes, UiGlint), sem cena e sem autoloads.
## Chamados por tests/run_tests.gd.

var _check: Callable


func run_unit(check: Callable) -> void:
	_check = check
	_test_field_capacity()
	_test_field_motion()
	_test_fx_budget()
	_test_fx_schedule()
	_test_fx_wrecks_and_popups()
	_test_fx_repeatable()
	_test_ui_spark()
	_test_motes()
	_test_glint()
	_test_energy_stream()
	_test_hit_pulse()


func _field(capacity: int) -> ParticleField:
	var tex: Array[Texture2D] = [SpriteBank.generated("fx/flare_64"), SpriteBank.generated("fx/streak")]
	var f := ParticleField.new()
	f.setup(tex, capacity, true, true)
	return f


## Campo cheio ignora o excesso; partícula morta sai e o MultiMesh mostra só as vivas, por textura.
func _test_field_capacity() -> void:
	var f := _field(8)
	for k: int in range(12):
		f.spawn(k % 2, Vector2(k, 0), Vector2.ZERO, 0.5 if k < 4 else 2.0, 1.0, 1.0, Color.WHITE, Color.WHITE)
	_check.call(f.count == 8, "ParticleField: teto de capacidade (8 de 12)")
	f.advance(1.0)
	_check.call(f.count == 4, "ParticleField: as 4 de vida curta saem")
	var shown := 0
	for node: Node in f.get_children():
		shown += (node as MultiMeshInstance2D).multimesh.visible_instance_count
	_check.call(shown == 4, "ParticleField: MultiMesh mostra só as vivas (%d)" % shown)
	f.spawn(0, Vector2.ZERO, Vector2.ZERO, 0.0, 1.0, 1.0, Color.WHITE, Color.WHITE)
	_check.call(f.count == 4, "ParticleField: vida 0 não entra")
	f.clear()
	_check.call(f.count == 0 and f.free_slots() == 8, "ParticleField: clear esvazia")
	f.free()


## Arrasto freia, aceleração soma e a posição anda com a velocidade.
func _test_field_motion() -> void:
	var f := _field(4)
	f.spawn(0, Vector2.ZERO, Vector2(100, 0), 5.0, 1.0, 1.0, Color.WHITE, Color.WHITE, 2.0)
	f.spawn(1, Vector2.ZERO, Vector2.ZERO, 5.0, 1.0, 1.0, Color.WHITE, Color.WHITE, 0.0, Vector2(0, 10), 0.0, 0.0, true)
	for k: int in range(60):
		f.advance(1.0 / 60.0)
	var mm0 := (f.get_child(0) as MultiMeshInstance2D).multimesh
	var x := mm0.buffer[3]
	# Com arrasto 2/s: distância = 100 (1 − e^−2) / 2 ≈ 43,2.
	_check.call(x > 38.0 and x < 48.0, "ParticleField: arrasto exponencial (x = %.1f)" % x)
	var mm1 := (f.get_child(1) as MultiMeshInstance2D).multimesh
	_check.call(mm1.buffer[7] > 4.0 and mm1.buffer[7] < 6.0, "ParticleField: aceleração (y = %.1f)" % mm1.buffer[7])
	f.free()


## A dose cresce com a qualidade, nunca passa do orçamento.
func _test_fx_budget() -> void:
	var counts: Array[int] = []
	for level: int in range(3):
		var fx := _fx(level, 600, 300)
		fx.explosion(Vector2(100, 100), 3.0)
		counts.append(fx.light.count + fx.matter.count)
		_free(fx)
	_check.call(counts[0] < counts[1] and counts[1] < counts[2], "CombatFx: explosão cresce com a qualidade %s" % [counts])
	var small := _fx(2, 20, 10)
	for k: int in range(20):
		small.explosion(Vector2(k, k), 3.0)
	_check.call(small.light.count <= 20 and small.matter.count <= 10, "CombatFx: nunca passa do orçamento")
	_free(small)


## Cadeias e ondas de cancelamento disparam na hora certa.
func _test_fx_schedule() -> void:
	var fx := _fx(2, 1400, 400)
	fx.chain(Vector2(135, 100), Vector2(40, 20), 4, 1.0, 1.0)
	fx.advance(0.01)
	_check.call(fx.light.count > 0 and fx.pending() == 3, "CombatFx: a cadeia começa na hora")
	fx.advance(0.5)
	_check.call(fx.pending() == 2, "CombatFx: a cadeia continua depois (%d)" % fx.pending())
	_free(fx)
	fx = _fx(2, 1400, 400)
	var bullets := PackedVector2Array([Vector2(135, 200), Vector2(10, 10), Vector2(260, 440)])
	fx.cancel_wave(Vector2(135, 200), bullets)
	fx.advance(0.001)
	_check.call(fx.pending() == 2, "CombatFx: a bala no centro some primeiro (%d)" % fx.pending())
	fx.advance(CombatFx.CANCEL_SPREAD)
	_check.call(fx.pending() == 0, "CombatFx: a onda alcança todas as balas")
	_free(fx)


func _test_fx_wrecks_and_popups() -> void:
	var fx := _fx(2, 400, 200)
	var tex := SpriteBank.generated("fx/drone")
	fx.wreck(tex, 10, Vector2(50, 50), Vector2(58, 64), 1.0)
	_check.call(fx.wrecks.size() == 1, "CombatFx: destroço cai")
	fx.light.clear()
	fx.advance(CombatFx.WRECK_TIME + 0.01)
	_check.call(fx.wrecks.is_empty() and fx.light.count > 0, "CombatFx: destroço espirra na água ao chegar")
	fx.ground = false
	fx.wreck(tex, 10, Vector2(50, 50), Vector2(58, 64), 1.0)
	_check.call(fx.wrecks.is_empty(), "CombatFx: no espaço não há destroço caindo")
	for k: int in range(CombatFx.MAX_POPUPS + 5):
		fx.popup(Vector2.ZERO, 100 + k, Color.WHITE)
	_check.call(fx.popups.size() == CombatFx.MAX_POPUPS, "CombatFx: números de pontos limitados")
	_check.call(String(fx.popups[-1]["text"]) == "+%d" % (100 + CombatFx.MAX_POPUPS + 4),
			"CombatFx: o número mais novo fica")
	fx.popup(Vector2.ZERO, 0, Color.WHITE)
	fx.advance(1.0)
	_check.call(fx.popups.is_empty(), "CombatFx: números somem em 0,75 s")
	_free(fx)


## Mesma sequência de acontecimentos, mesmo resultado (semente própria, nada global).
func _test_fx_repeatable() -> void:
	var a := _fx(2, 800, 300)
	var b := _fx(2, 800, 300)
	for fx: CombatFx in [a, b]:
		fx.explosion(Vector2(100, 100), 2.0)
		fx.impact(Vector2(50, 50), Color.CYAN)
		fx.advance(0.2)
	var ba := (a.light.get_child(0) as MultiMeshInstance2D).multimesh.buffer
	var bb := (b.light.get_child(0) as MultiMeshInstance2D).multimesh.buffer
	_check.call(a.light.count == b.light.count and ba == bb, "CombatFx: repetível")
	_free(a)
	_free(b)


## Toque: onda e centelhas vivem pouco, com teto; parada, a camada não processa.
func _test_ui_spark() -> void:
	var old := UiSpark.instance
	var spark := UiSpark.new()
	spark._ready()
	_check.call(not spark.busy() and not spark.is_processing(), "UiSpark: parada não processa")
	for k: int in range(UiSpark.MAX_RIPPLES + 3):
		spark.ripple(Vector2(10 * k, 20), Color.CYAN)
	spark.sweep()
	_check.call(spark.busy() and spark.is_processing(), "UiSpark: toque acorda a camada")
	_check.call(spark._ripples.size() == UiSpark.MAX_RIPPLES and spark._sparks.size() <= UiSpark.MAX_SPARKS,
			"UiSpark: ondas e centelhas com teto")
	for k: int in range(40):
		spark._process(1.0 / 60.0)
	_check.call(not spark.busy() and not spark.is_processing(), "UiSpark: tudo some em menos de 0,7 s")
	spark.free()
	UiSpark.instance = old


## Plâncton: fica na tela, sobe com o tempo e é sempre o mesmo para o mesmo relógio.
func _test_motes() -> void:
	var motes := AbyssMotes.new()
	motes.size = Vector2(360, 800)
	var inside := true
	for i: int in range(AbyssMotes.COUNT):
		var m := motes.mote(i)
		inside = inside and m.y >= -30.0 and m.y <= 830.0 and m.w > 0.0 and m.w <= 1.0
	_check.call(inside, "AbyssMotes: pontos dentro da tela e com alfa válido")
	var y0 := motes.mote(4).y
	motes.clock = 0.1
	var y1 := motes.mote(4).y
	_check.call(y1 < y0, "AbyssMotes: o plâncton sobe (%.1f -> %.1f)" % [y0, y1])
	var twin := AbyssMotes.new()
	twin.size = motes.size
	twin.clock = motes.clock
	_check.call(twin.mote(4) == motes.mote(4), "AbyssMotes: determinístico")
	twin.free()
	motes.free()


## Um material só para todos os botões dourados; "reduzir movimento" apaga a faixa.
func _test_glint() -> void:
	var a := Button.new()
	var b := Button.new()
	UiTheme.style_primary(a)
	UiTheme.style_primary(b)
	_check.call(a.material != null and a.material == b.material, "UiGlint: material compartilhado")
	UiGlint.set_reduced(true)
	_check.call(float(UiGlint.material().get_shader_parameter("strength")) == 0.0, "UiGlint: reduzir movimento apaga")
	UiGlint.set_reduced(false)
	_check.call(float(UiGlint.material().get_shader_parameter("strength")) > 0.0, "UiGlint: volta a brilhar")
	a.free()
	b.free()


func _fx(level: int, light: int, matter: int) -> CombatFx:
	var fx := CombatFx.new()
	fx.level = level
	fx.setup(light, matter)
	return fx


func _free(fx: CombatFx) -> void:
	fx.light.free()
	fx.matter.free()


## Fluxo do bico (Laser e Mergulho Solar): o sol acende e apaga em rampa, o Laser abre e fecha em rampa, e o
## desenho não muda a Sim (o hash de estado fica igual ao de uma Sim gêmea sem desenho).
func _test_energy_stream() -> void:
	var tables := Sim.load_tables()
	var empty := {"id": "vfx_test", "events": []}
	var sim := Sim.new()
	sim.setup(empty, tables, Sim.default_loadout(&"falcon"), 3)
	var twin := Sim.new()
	twin.setup(empty, tables, Sim.default_loadout(&"falcon"), 3)
	var stream := EnergyStream.new()
	stream.setup(sim)
	for s: Sim in [sim, twin]:
		s.player.invuln = 1 << 24
		s.powers.cast(s, &"falcon_3", 3)
	var heats: Array[float] = []
	var input := SimInput.new()
	for k: int in range(400):
		sim.step(input)
		twin.step(input)
		stream.refresh(1.0 / 60.0, k / 60.0)
		heats.append(stream.heat)
	_check.call(sim.state_hash() == twin.state_hash(), "EnergyStream: o desenho não mexe na Sim")
	var lit: Array[float] = []
	for h: float in heats:
		if h > 0.0:
			lit.append(h)
	_check.call(lit.max() == 1.0 and lit[0] < 0.2, "EnergyStream: o sol acende em rampa (%s)" % [lit.slice(0, 3)])
	_check.call(lit[-1] < 0.2 and heats[-1] == 0.0, "EnergyStream: o sol apaga em rampa (%s)" % [lit.slice(-3)])
	sim.player.weapon = &"laser"
	sim.laser_active = true
	sim.laser_to_y = 40.0
	sim.laser_width = 9.0
	stream.refresh(1.0 / 60.0, 7.0)
	_check.call(stream.open > 0.0 and stream.open < 1.0, "EnergyStream: o Laser abre em rampa (%.2f)" % stream.open)
	sim.laser_active = false
	stream.refresh(1.0 / 60.0, 7.1)
	_check.call(stream.open > 0.0 and stream.top == 40.0, "EnergyStream: o Laser fecha em rampa, no mesmo lugar")
	stream.free()


## Retorno de dano do chefe (HitPulse): com acerto em todo passo o tinte nunca passa do teto, cada pulso
## novo respeita o intervalo e o sprite volta a aparecer limpo entre os pulsos; "reduzir movimento" tira
## o tranco e enfraquece o tinte.
func _test_hit_pulse() -> void:
	var pulse := HitPulse.new()
	var top := 0.0
	var peaks: Array[int] = []
	var last := 0.0
	var clean := 0
	var shook := false
	var max_off := 0.0
	for k: int in range(240):
		pulse.tick(true, 1.0 if k % 50 == 0 else 0.1)
		var now := pulse.intensity()
		top = maxf(top, now)
		if now > last + 0.001:
			peaks.append(k)
		if now < 0.05:
			clean += 1
		shook = shook or pulse.offset() != Vector2.ZERO
		max_off = maxf(max_off, pulse.offset().length())
		last = now
	_check.call(top <= HitPulse.PEAK_MAX + 0.0001 and top >= HitPulse.PEAK_MIN,
			"HitPulse: tinte sob tiro contínuo fica entre %.2f e %.2f (%.3f)" % [HitPulse.PEAK_MIN, HitPulse.PEAK_MAX, top])
	var gaps_ok := peaks.size() > 1
	for i: int in range(1, peaks.size()):
		gaps_ok = gaps_ok and peaks[i] - peaks[i - 1] >= HitPulse.GAP
	_check.call(gaps_ok and peaks.size() <= 240 / HitPulse.GAP + 1,
			"HitPulse: um pulso a cada %d passos no máximo (%d pulsos)" % [HitPulse.GAP, peaks.size()])
	_check.call(clean > 0 and shook and max_off <= HitPulse.SHAKE_MAX * 1.2,
			"HitPulse: o sprite volta limpo entre pulsos (%d passos) e treme até %.1f px" % [clean, max_off])
	for k: int in range(HitPulse.FADE):
		pulse.tick(false)
	_check.call(pulse.intensity() == 0.0 and pulse.offset() == Vector2.ZERO, "HitPulse: sem acerto apaga e para")
	var calm := HitPulse.new()
	calm.calm = true
	var calm_top := 0.0
	var still := true
	for k: int in range(60):
		calm.tick(true, 1.0)
		calm_top = maxf(calm_top, calm.intensity())
		still = still and calm.offset() == Vector2.ZERO
	_check.call(still and calm_top <= HitPulse.PEAK_CALM + 0.0001,
			"HitPulse: reduzir movimento sem tranco e tinte até %.2f (%.3f)" % [HitPulse.PEAK_CALM, calm_top])
