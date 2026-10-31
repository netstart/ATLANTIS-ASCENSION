extends RefCounted
## Testes dos efeitos visuais da partida (ParticleField e CombatFx), sem cena e sem autoloads.
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


func _fx(level: int, light: int, matter: int) -> CombatFx:
	var fx := CombatFx.new()
	fx.level = level
	fx.setup(light, matter)
	return fx


func _free(fx: CombatFx) -> void:
	fx.light.free()
	fx.matter.free()
