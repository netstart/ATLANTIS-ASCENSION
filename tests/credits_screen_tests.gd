extends RefCounted
## Tela de créditos (docs/policies/licencas.md): toda entrada de licenses/index.json aparece na tela,
## na seção certa, e no CREDITS.md; a lista rola até o fim. Chamado por tests/integration_tests.gd.

const LayoutTests := preload("res://tests/layout_tests.gd")
const DeviceProfiles := preload("res://tests/device_profiles.gd")


func run(host: Node, check: Callable) -> void:
	var entries := CreditsScreen.load_index()
	check.call(not entries.is_empty(), "Créditos: licenses/index.json tem entradas")
	var credits_md := FileAccess.get_file_as_string("res://CREDITS.md")
	check.call(not credits_md.is_empty(), "Créditos: CREDITS.md existe")
	for lang: String in Languages.SUPPORTED:
		Locale.set_language(lang, false)
		var app := App.new()
		host.add_child(app)
		await host.get_tree().process_frame
		LayoutTests.fit(app, DeviceProfiles.main_view())
		app.go(&"credits")
		await LayoutTests.settle(host)
		var screen := app.screen(&"credits") as CreditsScreen
		var shown := "\n".join(screen.shown_texts())
		for row: Variant in entries:
			var entry := row as Dictionary
			var name := String(entry.get("name", ""))
			var author := String(entry.get("author", ""))
			check.call(shown.contains(name), "Créditos %s: '%s' na tela" % [lang, name])
			check.call(shown.contains(author), "Créditos %s: autor '%s' na tela" % [lang, author])
			if lang == "pt_BR":
				check.call(credits_md.contains(name), "Créditos: '%s' no CREDITS.md" % name)
		var sections: Dictionary = {}
		for row: Variant in entries:
			sections[CreditsScreen.section_of(row as Dictionary)] = true
		for key: String in sections:
			check.call(screen.find_child("Section_" + key, true, false) != null,
					"Créditos %s: seção %s presente" % [lang, key])
		var scroll := screen.scroll()
		var bar := scroll.get_v_scroll_bar()
		scroll.scroll_vertical = int(bar.max_value)
		await host.get_tree().process_frame
		check.call(scroll.scroll_vertical >= int(bar.max_value - bar.page) - 1,
				"Créditos %s: rola até o fim" % lang)
		app.queue_free()
		await host.get_tree().process_frame
	Locale.set_language("pt_BR", false)
