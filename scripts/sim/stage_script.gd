class_name StageScript
extends RefCounted
## Roteiro de uma missão (plano mestre 10.6; data/stages/<id>.json): eventos por tempo de missão.
## O tempo da fase para enquanto um chefe ou mini-chefe luta, para a fase nunca "andar" debaixo dele.
##
## Eventos: wave, dialogue, ocean_shift, scroll_speed, music_layer, miniboss, boss, checkpoint,
## secret_trigger, end. Ondas: enemy, formation (single | line | v | column), count, x (0..1),
## spacing, interval (passos entre membros), path, params, from_depth, drop_last, marked.

var mission: Dictionary = {}
var events: Array = []
var index: int = 0
## Passos de tempo de fase (não conta enquanto espera um chefe).
var frame: int = 0
var waiting_boss: bool = false
var ended: bool = false
var _pending: Array[Dictionary] = []


func setup(p_mission: Dictionary) -> void:
	mission = p_mission
	events = (mission.get("events", []) as Array).duplicate()
	events.sort_custom(func(a: Variant, b: Variant) -> bool:
		return float((a as Dictionary).get("t", 0.0)) < float((b as Dictionary).get("t", 0.0)))


func step(sim: Sim) -> void:
	if waiting_boss:
		if sim.boss != null:
			return
		waiting_boss = false
	frame += 1
	while index < events.size() and float((events[index] as Dictionary).get("t", 0.0)) * 60.0 <= frame:
		_run(events[index], sim)
		index += 1
		if waiting_boss:
			break
	var i := 0
	while i < _pending.size():
		var p := _pending[i]
		if int(p["at"]) <= frame:
			sim.spawn_enemy(p["spec"], int(p["member"]))
			_pending.remove_at(i)
		else:
			i += 1


## Ainda há ondas por nascer?
func has_pending() -> bool:
	return not _pending.is_empty() or index < events.size()


func _run(ev: Dictionary, sim: Sim) -> void:
	match StringName(String(ev.get("op", ""))):
		&"wave":
			var count := maxi(1, int(ev.get("count", 1)))
			var interval := int(ev.get("interval", 0))
			for m: int in range(count):
				if interval <= 0:
					sim.spawn_enemy(ev, m)
				else:
					_pending.append({"at": frame + interval * m, "spec": ev, "member": m})
		&"miniboss", &"boss":
			sim.spawn_boss(StringName(String(ev.get("id", ""))), String(ev.get("op")) == "boss")
			waiting_boss = true
		&"end":
			ended = true
		_:
			sim.on_stage_event(ev)
