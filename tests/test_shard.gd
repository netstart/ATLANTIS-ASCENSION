extends RefCounted
## Fatias de uma suíte de testes por processo (tools/run_checks.ps1 roda as fatias em paralelo).
##
## Uma suíte se descreve como uma lista de unidades, cada uma com nome e peso (custo estimado em
## segundos). `-- --shard=I/N` roda só as unidades da fatia I (0 ≤ I < N). A divisão é determinística:
## maior peso primeiro, sempre para a fatia menos carregada (empate: menor índice). Assim toda unidade
## cai em exatamente uma fatia e a união das N fatias é a suíte inteira, com as mesmas verificações.
## O peso só equilibra o tempo; peso errado nunca tira verificação de lugar nenhum.
##
## Sem `--shard`, a suíte roda inteira num processo só (N = 1), como antes das fatias.
## Cada fatia termina imprimindo `summary()`; o run_checks.ps1 confere que as fatias somam todas as
## unidades da suíte (fatia que caiu no meio reprova o commit).


## (I, N) da linha de comando; (0, 1) sem `--shard`; (-1, 0) se o argumento estiver malformado.
static func parse(args: PackedStringArray) -> Vector2i:
	for arg: String in args:
		if not arg.begins_with("--shard="):
			continue
		var parts := arg.trim_prefix("--shard=").split("/")
		if parts.size() == 2 and parts[0].is_valid_int() and parts[1].is_valid_int():
			var index := int(parts[0])
			var count := int(parts[1])
			if count >= 1 and index >= 0 and index < count:
				return Vector2i(index, count)
		return Vector2i(-1, 0)
	return Vector2i(0, 1)


## Fatia de cada unidade (mesma ordem de `weights`) para `count` fatias.
static func assign(weights: PackedFloat32Array, count: int) -> PackedInt32Array:
	var order: Array[int] = []
	for i: int in range(weights.size()):
		order.append(i)
	order.sort_custom(func(a: int, b: int) -> bool:
		return weights[a] > weights[b] or (weights[a] == weights[b] and a < b))
	var loads := PackedFloat32Array()
	loads.resize(maxi(count, 1))
	var owners := PackedInt32Array()
	owners.resize(weights.size())
	for i: int in order:
		var best := 0
		for s: int in range(1, loads.size()):
			if loads[s] < loads[best]:
				best = s
		owners[i] = best
		loads[best] += weights[i]
	return owners


## Unidades da fatia `shard` (Vector2i(I, N)), na ordem original da suíte.
static func mine(units: Array[Dictionary], shard: Vector2i) -> Array[Dictionary]:
	var weights := PackedFloat32Array()
	for unit: Dictionary in units:
		weights.append(float(unit.get("weight", 1.0)))
	var owners := assign(weights, shard.y)
	var out: Array[Dictionary] = []
	for i: int in range(units.size()):
		if owners[i] == shard.x:
			out.append(units[i])
	return out


## Linha final que o run_checks.ps1 lê para conferir a cobertura das fatias.
static func summary(suite: String, shard: Vector2i, ran: int, total: int) -> String:
	return "fatia %s %d/%d: %d de %d unidades" % [suite, shard.x, shard.y, ran, total]


## Tempo de cada unidade (`-- --timing`), para achar pontos quentes e acertar os pesos.
static func timing_enabled() -> bool:
	return "--timing" in OS.get_cmdline_user_args()
