class_name CampaignTrail
extends RefCounted
## Trilha do capítulo na aba Campanha (1.15, menus de comando): regras puras sobre o grafo da campanha
## (Economy.CAMPAIGN) e o perfil, sem autoloads, para a tela e os testes.
##
## - Cada capítulo vira uma trilha de linhas que sobem: missão 1 embaixo, missão 3 (ou as duas rotas,
##   superfície e abismo, lado a lado) em cima. As missões secretas ficam na Carta da Ascensão, fora da
##   trilha (são achadas por glifos, não seguem a ordem do capítulo).
## - Os capítulos navegáveis são os que já têm alguma missão aberta.
## - O marco do capítulo mostra um prêmio que JÁ existe no jogo, sem economia nova: a aeronave cujos
##   fragmentos se completam numa missão do capítulo (Economy.apply_result: a primeira vitória de cada
##   missão-fonte dá FRAGMENTS_FIRST) ou, se não há aeronave a ganhar ali, a próxima asa liberada pelas
##   estrelas somadas (Economy.wings_available).

const CHAPTERS := 10


## Capítulo de uma missão (0 se não existe).
static func chapter_of(id: StringName) -> int:
	return int(Economy.node(id).get("chapter", 0))


## Linha da missão na trilha: 0 para a missão 1, 1 para a 2, 2 para a 3 e suas rotas.
static func row_of(id: StringName) -> int:
	var text := String(id)
	return maxi(0, int(text.substr(3, 1)) - 1) if text.begins_with("c") else 0


## Capítulo que o jogador está jogando agora: o da próxima missão.
static func current_chapter(profile: Dictionary) -> int:
	return chapter_of(Economy.next_mission(profile))


## Capítulos com alguma missão aberta, em ordem (o bônus, 10, vem depois do 9).
static func open_chapters(profile: Dictionary) -> Array[int]:
	var out: Array[int] = []
	for n: Dictionary in Economy.CAMPAIGN:
		var c := int(n["chapter"])
		if n["kind"] != &"secret" and not out.has(c) and Economy.mission_unlocked(profile, n["id"]):
			out.append(c)
	out.sort()
	return out


## Capítulo vizinho aberto (`step` -1 ou +1); o próprio capítulo quando não há para onde ir.
static func neighbor(profile: Dictionary, chapter: int, step: int) -> int:
	var list := open_chapters(profile)
	var at := list.find(chapter)
	if at < 0:
		return list[0] if not list.is_empty() else chapter
	return list[clampi(at + step, 0, list.size() - 1)]


## Nós da trilha do capítulo, de baixo para cima: {id, row, kind, route, open, cleared, stars, next}.
## `stars` conta as estrelas ganhas (0 a 4); `next` marca a próxima missão a jogar.
static func nodes(profile: Dictionary, chapter: int) -> Array[Dictionary]:
	var next := Economy.next_mission(profile)
	var out: Array[Dictionary] = []
	for n: Dictionary in Economy.CAMPAIGN:
		if int(n["chapter"]) != chapter or n["kind"] == &"secret":
			continue
		var id: StringName = n["id"]
		out.append({"id": id, "row": row_of(id), "kind": n["kind"], "route": n.get("route", &""),
				"after": n["after"], "open": Economy.mission_unlocked(profile, id),
				"cleared": Economy.cleared(profile, id), "stars": stars(profile, id), "next": id == next})
	return out


## Estrelas ganhas numa missão (0 a 4).
static func stars(profile: Dictionary, id: StringName) -> int:
	var rec: Dictionary = (profile.get("missions", {}) as Dictionary).get(String(id), {})
	var total := 0
	for s: Variant in rec.get("stars", []):
		total += 1 if bool(s) else 0
	return total


## Estrelas do capítulo: Vector2i(ganhas, possíveis).
static func chapter_stars(profile: Dictionary, chapter: int) -> Vector2i:
	var got := 0
	var most := 0
	for n: Dictionary in nodes(profile, chapter):
		got += int(n["stars"])
		most += 4
	return Vector2i(got, most)


## Marco do capítulo: {kind: &"ship" | &"wing" | &"done", id, mission, have, need, done}.
## - ship: a aeronave (lançada, fora dos finais) cuja última missão-fonte é deste capítulo e ainda está
##   fechada; `mission` é essa missão (concluí-la completa os fragmentos de quem venceu as anteriores).
## - wing: a próxima asa pelas estrelas somadas; `have` e `need` são as estrelas.
## - done: nada mais a ganhar por aqui (todas as asas abertas); `have`/`need` são as estrelas do capítulo.
static func milestone(profile: Dictionary, chapter: int, ships: Array = [], wings: Array = []) -> Dictionary:
	var ship_rows := ships if not ships.is_empty() else Economy.data_rows("ships")
	var unlocked: Array = profile["unlocked"]["ships"]
	for row: Variant in ship_rows:
		var def := row as Dictionary
		var sources: Array = def.get("sources", [])
		if sources.is_empty() or not Economy.released(def) or unlocked.has(String(def["id"])):
			continue
		var last := _last_source(sources)
		if last == &"" or Economy.node(last)["kind"] == &"secret" or chapter_of(last) != chapter:
			continue
		var have := int((profile["hangar"]["fragments"] as Dictionary).get(String(def["id"]), 0))
		return {"kind": &"ship", "id": StringName(String(def["id"])), "mission": last, "have": have,
				"need": int(def.get("fragments", 0)), "done": false}
	var total := Economy.total_stars(profile)
	var wing_rows := (wings if not wings.is_empty() else Economy.data_rows("wings")).duplicate()
	wing_rows.sort_custom(func(a: Variant, b: Variant) -> bool:
		return int((a as Dictionary).get("stars", 0)) < int((b as Dictionary).get("stars", 0)))
	for row: Variant in wing_rows:
		var def := row as Dictionary
		if Economy.released(def) and total < int(def.get("stars", 0)):
			return {"kind": &"wing", "id": StringName(String(def["id"])), "mission": &"", "have": total,
					"need": int(def["stars"]), "done": false}
	var got := chapter_stars(profile, chapter)
	return {"kind": &"done", "id": &"", "mission": &"", "have": got.x, "need": got.y, "done": true}


## Missão-fonte que vem por último na campanha.
static func _last_source(sources: Array) -> StringName:
	var best := -1
	for s: Variant in sources:
		for i: int in range(Economy.CAMPAIGN.size()):
			if Economy.CAMPAIGN[i]["id"] == StringName(String(s)):
				best = maxi(best, i)
	return Economy.CAMPAIGN[best]["id"] if best >= 0 else &""
