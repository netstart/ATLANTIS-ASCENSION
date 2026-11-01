class_name Grade
extends RefCounted
## Nota da missão (pesquisa em .ai/07-pesquisa-diversao-e-surpresa.md, seção 3.2): uma letra que
## resume a partida e vira meta de maestria (C, B, A, S e SS "Lenda Atlante"). Regras puras, sem nós;
## só a campanha grava a melhor nota de cada missão.
##
## Pontos (0 a 100): 20 por estrela, até 10 pela maior corrente (1 a cada 8 abates seguidos) e 10 por
## não gastar bomba; cada reviver tira 20. SS exige a partida perfeita: 4 estrelas, sem dano, sem
## bomba, sem reviver e corrente de pelo menos SS_CHAIN.

const NONE := -1
const C := 0
const B := 1
const A := 2
const S := 3
const SS := 4
const LETTERS: Array[String] = ["C", "B", "A", "S", "SS"]
## Pontos mínimos de B, A e S.
const THRESHOLDS: Array[int] = [50, 70, 95]
const SS_CHAIN := 48
const CHAIN_STEP := 8
const CHAIN_POINTS_MAX := 10
const NO_BOMB_POINTS := 10
const REVIVE_PENALTY := 20
## Cor de cada letra (bronze, prata, turquesa, ouro, violeta) para o carimbo e o cartão do mapa.
const COLORS: Array[Color] = [Color("c98b5a"), Color("c9d6e3"), Color("4fe3d0"), Color("ffcf4a"), Color("c48bff")]


## Pontos da partida (0 a 100); -1 se a missão não foi vencida.
static func points(result: Dictionary) -> int:
	if not bool(result.get("cleared", false)):
		return -1
	var total := 0
	for s: Variant in result.get("stars", []):
		total += 20 if bool(s) else 0
	total += mini(CHAIN_POINTS_MAX, floori(int(result.get("max_chain", 0)) / float(CHAIN_STEP)))
	if int(result.get("bombs_used", 0)) == 0:
		total += NO_BOMB_POINTS
	total -= REVIVE_PENALTY * int(result.get("revives", 0))
	return clampi(total, 0, 100)


## Nota de C (0) a SS (4); NONE se a missão não foi vencida.
static func compute(result: Dictionary) -> int:
	var pts := points(result)
	if pts < 0:
		return NONE
	if perfect(result):
		return SS
	var grade := C
	for i: int in range(THRESHOLDS.size()):
		if pts >= THRESHOLDS[i]:
			grade = i + 1
	return grade


## Partida perfeita: o que separa o SS do S.
static func perfect(result: Dictionary) -> bool:
	var stars: Array = result.get("stars", [])
	var all_stars := stars.size() >= 4
	for s: Variant in stars:
		all_stars = all_stars and bool(s)
	return bool(result.get("cleared", false)) and all_stars and int(result.get("hull_lost", 0)) == 0 \
			and int(result.get("bombs_used", 0)) == 0 and int(result.get("revives", 0)) == 0 \
			and int(result.get("max_chain", 0)) >= SS_CHAIN


static func letter(grade: int) -> String:
	return LETTERS[grade] if grade >= 0 and grade < LETTERS.size() else "—"


static func color(grade: int) -> Color:
	return COLORS[grade] if grade >= 0 and grade < COLORS.size() else Color(0.6, 0.65, 0.7)


## Melhor nota gravada da missão (NONE se nunca venceu).
static func best(profile: Dictionary, mission_id: String) -> int:
	var record: Dictionary = (profile.get("missions", {}) as Dictionary).get(mission_id, {})
	return int(record.get("grade", NONE))


## Grava a nota se for a melhor; devolve true quando melhorou.
static func record(profile: Dictionary, mission_id: String, grade: int) -> bool:
	if grade == NONE:
		return false
	var all: Dictionary = profile["missions"]
	if not all.has(mission_id):
		all[mission_id] = {"stars": [false, false, false, false], "best_score": 0, "cleared": false, "route": ""}
	var rec: Dictionary = all[mission_id]
	if grade <= int(rec.get("grade", NONE)):
		return false
	rec["grade"] = grade
	return true


## Quantas missões têm nota igual ou melhor que `grade` (conquistas).
static func count_at_least(profile: Dictionary, grade: int) -> int:
	var n := 0
	for rec: Variant in (profile.get("missions", {}) as Dictionary).values():
		if int((rec as Dictionary).get("grade", NONE)) >= grade:
			n += 1
	return n
