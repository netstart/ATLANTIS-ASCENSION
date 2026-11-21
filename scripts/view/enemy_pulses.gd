class_name EnemyPulses
extends RefCounted
## Retorno de dano dos inimigos (comuns, elites, torres, chefes de meio), só na vista: o mesmo HitPulse do
## chefe, um por inimigo vivo, no lugar do branco chapado. Sob tiro contínuo o sprite pisca no máximo a cada
## HitPulse.GAP passos e volta a aparecer inteiro entre os pulsos.
##
## Chave: o id de instância do SimEnemy (não segura o objeto nem mexe na Sim). Quem morre ou sai do campo
## some da lista da Sim e o pulso dele volta para um estoque, reaproveitado pelo próximo inimigo: sem
## objeto novo por acerto nem por quadro depois que o estoque se forma.

## Pulso apagado, para quem ainda não tem estado (inimigo que nunca levou dano).
var idle := HitPulse.new()
var _live: Dictionary = {}
var _pool: Array[HitPulse] = []
## Marca do último passo: pulso com marca antiga é de inimigo que já saiu.
var _mark: int = 0


## Um passo de 60 Hz. `fresh`: a Sim andou desde o último passo (no hitstop e na pausa nada conta como
## acerto novo, o pulso só apaga). `calm`: "reduzir movimento".
func tick(enemies: Array[SimEnemy], fresh: bool, calm: bool) -> void:
	_mark += 1
	var seen := 0
	for e: SimEnemy in enemies:
		var key := e.get_instance_id()
		var pulse: HitPulse = _live.get(key)
		var hit := fresh and e.flash > 0 and e.alive
		if pulse == null:
			if not hit:
				continue
			pulse = _pool.pop_back() if not _pool.is_empty() else HitPulse.new()
			pulse.reset()
			pulse.seen_hp = e.max_hp
			_live[key] = pulse
		pulse.mark = _mark
		seen += 1
		pulse.calm = calm
		# 15% do HP num passo já é golpe grande (inimigo comum morre em poucos tiros).
		var strength := clampf((pulse.seen_hp - e.hp) / maxf(1.0, e.max_hp) * 6.0, 0.0, 1.0)
		pulse.seen_hp = e.hp
		pulse.tick(hit, strength)
	if _live.size() > seen:
		_sweep()


## Pulso do inimigo agora (o apagado se ele não tem estado).
func of(e: SimEnemy) -> HitPulse:
	var pulse: HitPulse = _live.get(e.get_instance_id())
	return pulse if pulse != null else idle


func live_count() -> int:
	return _live.size()


func clear() -> void:
	for pulse: HitPulse in _live.values():
		_pool.append(pulse)
	_live.clear()


## Devolve ao estoque os pulsos de quem não apareceu neste passo (morreu, saiu ou a partida trocou).
## Só roda quando sobra estado, isto é, no passo em que alguém sai.
func _sweep() -> void:
	for key: int in _live.keys():
		var pulse: HitPulse = _live[key]
		if pulse.mark != _mark:
			_live.erase(key)
			_pool.append(pulse)
