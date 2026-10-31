class_name SimRng
extends RefCounted
## Fluxos de números aleatórios da partida (plano mestre 10.3): um RandomNumberGenerator por fluxo
## (ondas, drops, padrões, chefe, bot), todos derivados da semente da missão. Fluxos separados mantêm
## o determinismo quando um sistema muda o quanto sorteia: o dos drops não desloca o dos padrões.

var seed_value: int = 0
var _streams: Dictionary = {}


func _init(p_seed: int = 0) -> void:
	seed_value = p_seed


func stream(name: StringName) -> RandomNumberGenerator:
	if not _streams.has(name):
		var rng := RandomNumberGenerator.new()
		rng.seed = hash("%d:%s" % [seed_value, name])
		_streams[name] = rng
	return _streams[name]


func randf_in(name: StringName, from: float, to: float) -> float:
	return stream(name).randf_range(from, to)


func randi_in(name: StringName, from: int, to: int) -> int:
	return stream(name).randi_range(from, to)


## Sorteio ponderado: devolve o índice escolhido em `weights`.
func weighted(name: StringName, weights: Array) -> int:
	var total := 0.0
	for w: Variant in weights:
		total += float(w)
	var roll := stream(name).randf() * total
	for i: int in range(weights.size()):
		roll -= float(weights[i])
		if roll < 0.0:
			return i
	return weights.size() - 1
