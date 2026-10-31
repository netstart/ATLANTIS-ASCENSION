class_name Store
extends RefCounted
## Loja (plano mestre 17): cosméticos por Pérolas de Maré, compra única "Apoiar" e anúncio recompensado
## opcional. Nada de poder à venda e nenhuma compra de moeda. Pagamento e anúncio reais ficam para a
## Fase 4 (Play Billing, AdMob com UMP): aqui são SIMULADOS — `simulated()` diz quando a loja finge a
## transação (editor, testes e builds de desenvolvimento) e nenhuma cobrança acontece.
## Steam: premium, sem anúncios; os cosméticos vêm todos inclusos (feature "steam" no preset).

const COSMETICS_PATH := "res://data/cosmetics.json"


static func cosmetics() -> Array:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(COSMETICS_PATH))
	return parsed if typeof(parsed) == TYPE_ARRAY else []


static func owned(profile: Dictionary, id: String) -> bool:
	return is_steam() or (profile["unlocked"]["cosmetics"] as Array).has(id)


## Compra um cosmético com Pérolas. Devolve se comprou.
static func buy(profile: Dictionary, id: String) -> bool:
	if owned(profile, id):
		return false
	for c: Variant in cosmetics():
		var def := c as Dictionary
		if bool(def.get("supporter", false)) or bool(def.get("season", false)):
			continue
		if String(def["id"]) == id and Economy.pay(profile, {"pearls": int(def["pearls"])}):
			(profile["unlocked"]["cosmetics"] as Array).append(id)
			return true
	return false


static func equip(profile: Dictionary, id: String) -> void:
	if id.is_empty() or owned(profile, id):
		profile["selected"]["cosmetic"] = id


## Cor do cosmético equipado (tinta da aeronave) ou "" para a cor padrão.
static func tint_of(id: String) -> String:
	for c: Variant in cosmetics():
		if String((c as Dictionary)["id"]) == id:
			return String((c as Dictionary).get("color", ""))
	return ""


static func is_steam() -> bool:
	return OS.has_feature("steam")


## Anúncios só no Android grátis; nunca na Steam e nunca para quem apoiou.
static func ads_allowed(profile: Dictionary) -> bool:
	return not is_steam() and not bool(profile["purchases"].get("supporter", false))


## Sem plugin de pagamento ou de anúncio, a loja simula (Fase 4 liga os reais).
static func simulated() -> bool:
	return not Engine.has_singleton("GodotGooglePlayBilling") and not Engine.has_singleton("AdMob")


## "Apoiar": compra única que remove anúncios e dá a pintura dourada. Simulada até a Fase 4.
static func support(profile: Dictionary) -> bool:
	if bool(profile["purchases"].get("supporter", false)) or not simulated():
		return false
	profile["purchases"]["supporter"] = true
	var list: Array = profile["unlocked"]["cosmetics"]
	if not list.has("tint_supporter"):
		list.append("tint_supporter")
	return true
