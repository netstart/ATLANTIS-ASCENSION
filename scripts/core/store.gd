class_name Store
extends RefCounted
## Loja (plano mestre 17): cosméticos por Pérolas de Maré e anúncio recompensado opcional. Nada de poder à
## venda e nenhuma compra de moeda. As compras com dinheiro real (Turbo, Apoiar, pinturas, atalho de nave,
## pacotes) são as do catálogo `Iap` (scripts/core/iap.gd, Play Billing); só o passe dourado segue SIMULADO
## — `simulated()` diz quando a loja finge a transação (editor, testes e builds de desenvolvimento) e
## nenhuma cobrança acontece. As pinturas com produto na Play também saem por Pérolas. O anúncio é o do
## `Ads` (AdMob real, simulado ou "off"): sem IDs do AdMob não há anúncio e a recompensa sai direto.
## Steam: premium, sem anúncios; os cosméticos vêm todos inclusos (feature "steam" no preset).

const COSMETICS_PATH := "res://data/cosmetics.json"


static func cosmetics() -> Array:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(COSMETICS_PATH))
	return parsed if typeof(parsed) == TYPE_ARRAY else []


static func owned(profile: Dictionary, id: String) -> bool:
	return is_steam() or (profile["unlocked"]["cosmetics"] as Array).has(id) or Iap.grants_cosmetic(profile, id)


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
	return String(cosmetic(id).get("color", ""))


static func cosmetic(id: String) -> Dictionary:
	if id.is_empty():
		return {}
	for c: Variant in cosmetics():
		if String((c as Dictionary)["id"]) == id:
			return c
	return {}


## Efeitos da pintura na partida (só desenho: a Sim não lê nada disto): rastro do motor, halo do tiro do
## jogador e estouro da explosão da nave. Cor vazia = a padrão. O halo do tiro é sempre pastel (pouca
## saturação, muito claro) para nunca lembrar uma bala inimiga, que é saturada (tests/iap_tests.gd).
static func paint_fx(id: String) -> Dictionary:
	var def := cosmetic(id)
	var out := {}
	for key: String in ["trail", "shot", "burst"]:
		if def.has(key):
			out[key] = Color(String(def[key]))
	return out


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
## pacote, as compras do catálogo (scripts/core/iap.gd) são cobradas de verdade.
static func simulated() -> bool:
	return not Engine.has_singleton("GodotGooglePlayBilling") and OS.is_debug_build()


## Passe dourado (season_gold) à venda: ainda NÃO tem produto no Play Console e só existe simulado
## (desenvolvimento). O "Apoiar" deixou de depender disto: é do catálogo `Iap`.
static func purchases_enabled() -> bool:
	return not is_steam() and simulated()


## "Apoiar" no modo simulado (testes): o mesmo `Iap.buy` da Loja. Na Play a compra volta por Iap.on_changed.
static func support(profile: Dictionary) -> bool:
	return Iap.buy(profile, Iap.SUPPORT)
