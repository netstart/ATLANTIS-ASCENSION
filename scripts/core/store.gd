class_name Store
extends RefCounted
## Loja (plano mestre 17): cosméticos por Pérolas de Maré, compra única "Apoiar" e anúncio recompensado
## opcional. Nada de poder à venda e nenhuma compra de moeda. A única compra com cobrança real é o Turbo
## (scripts/core/turbo.gd, Play Billing); "Apoiar" e o passe seguem SIMULADOS — `simulated()` diz quando a
## loja finge a transação (editor, testes e builds de desenvolvimento) e nenhuma cobrança acontece; em
## release eles somem. O anúncio é o do `Ads` (AdMob real, simulado ou "off"): sem IDs do AdMob não há
## anúncio e a recompensa sai direto.
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


## Anúncios só no Android grátis; nunca na Steam, nunca para quem apoiou e nunca no modo "off" do `Ads`
## (release sem IDs reais): sem anúncio, a recompensa é concedida direto.
static func ads_allowed(profile: Dictionary) -> bool:
	return (not is_steam() and not bool(profile["purchases"].get("supporter", false))
			and Ads.mode() != "off")


## Sem plugin de pagamento a loja simula a compra — só em builds de desenvolvimento (editor, testes, APK
## de debug sem o plugin). Release sem plugin nunca finge uma cobrança. O AdMob não conta aqui: o APK de
## debug com o plugin de anúncio continua simulando a compra. Com o plugin GodotGooglePlayBilling no
## pacote, só o Turbo (scripts/core/turbo.gd) é cobrado de verdade.
static func simulated() -> bool:
	return not Engine.has_singleton("GodotGooglePlayBilling") and OS.is_debug_build()


## "Apoiar" (supporter) e passe dourado (season_gold) aparecem na tela. Eles ainda NÃO têm produto no
## Play Console: só existem simulados (desenvolvimento). O plugin de Billing entrou no release para o
## Turbo e não liga estes dois; quando tiverem produto, passam pelo PlayBillingProvider como o Turbo.
static func purchases_enabled() -> bool:
	return not is_steam() and simulated()


## "Apoiar": compra única que remove anúncios e dá a pintura dourada. Simulada até a Fase 4.
static func support(profile: Dictionary) -> bool:
	if bool(profile["purchases"].get("supporter", false)) or not simulated():
		return false
	profile["purchases"]["supporter"] = true
	var list: Array = profile["unlocked"]["cosmetics"]
	if not list.has("tint_supporter"):
		list.append("tint_supporter")
	return true
