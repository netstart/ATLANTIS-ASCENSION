class_name ShopScreen
extends ListScreen
## Loja (plano mestre 17): baú grátis a cada 6 h (em dobro com anúncio opcional), cosméticos por
## Pérolas e a compra única "Apoiar". Nada de poder à venda. Pagamento e anúncio são simulados até a
## Fase 4 (Store.simulated); a tela avisa isso para ninguém achar que pagou de verdade.


func title_key() -> String:
	return "hub.tab_shop"


func show_wallet() -> bool:
	return true


func _fill() -> void:
	var profile := SaveManager.data
	var now := int(Time.get_unix_time_from_system())
	if Store.simulated():
		add_text(tr("shop.simulated"), UiTheme.CORAL)
	add_heading(tr("shop.chest"))
	var wait := LiveOps.chest_wait(profile, now)
	if wait > 0:
		add_text(tr("shop.chest_wait") % [wait / 3600, (wait % 3600) / 60], UiTheme.TEXT_DIM)
	else:
		add_button(tr("shop.chest_open"), func() -> void:
			LiveOps.open_chest(SaveManager.data, now)
			SaveManager.save_profile(), true, "Chest")
		if Store.ads_allowed(profile):
			add_button(tr("shop.chest_double"), func() -> void:
				Ads.show_rewarded(SaveManager.data, func(granted: bool) -> void:
					if granted:
						LiveOps.open_chest(SaveManager.data, now, 2)
						SaveManager.save_profile()
						refill()), true, "ChestAd")
	add_heading(tr("shop.cosmetics"))
	var equipped := String(profile["selected"].get("cosmetic", ""))
	add_button(("◆ " if equipped.is_empty() else "◇ ") + tr("shop.default_paint"), func() -> void:
		Store.equip(SaveManager.data, "")
		SaveManager.save_profile())
	for c: Variant in Store.cosmetics():
		var def := c as Dictionary
		var id := String(def["id"])
		var name := tr("cosmetic." + id)
		if Store.owned(profile, id):
			add_button(("◆ " if equipped == id else "◇ ") + name, func() -> void:
				Store.equip(SaveManager.data, id)
				SaveManager.save_profile(), true, "Equip_" + id)
		elif bool(def.get("supporter", false)):
			add_text("◇ %s · %s" % [name, tr("shop.supporter_only")], UiTheme.TEXT_DIM)
		else:
			add_button(tr("shop.buy") % [name, int(def["pearls"])], func() -> void:
				if Store.buy(SaveManager.data, id):
					AudioManager.play_ui("kenney_ui_confirm")
					SaveManager.save_profile(), Economy.can_pay(profile, {"pearls": int(def["pearls"])}), "Buy_" + id)
	if not Store.is_steam():
		add_heading(tr("shop.support"))
		add_text(tr("shop.support_desc"), UiTheme.TEXT_DIM)
		if bool(profile["purchases"].get("supporter", false)):
			add_text("◆ " + tr("shop.support_thanks"), UiTheme.GOLD)
		else:
			add_button(tr("shop.support_buy"), func() -> void:
				if Store.support(SaveManager.data):
					SaveManager.save_profile(), Store.simulated(), "Support")
