extends RefCounted
## SpriteBank (naves HD com a Void de reserva): todo sprite de data/enemies.json e data/bosses.json resolve, a HD
## é preferida, tamanho de textura e de desenho separados (desenho = textura / 2), motor de 6 quadros, sem tira de
## destruição na HD, os alvos dos objetivos e glifos continuam na arte própria, a aeronave do jogador cai na Void
## quando falta a HD, e as texturas HD têm mipmaps no .import (filtro linear sem cintilar).
## Chamado por tests/integration_tests.gd (precisa do DB).


func run(check: Callable) -> void:
	var ids: Dictionary = {}
	for row: Variant in DB.rows("enemies"):
		ids[StringName(String((row as Dictionary).get("sprite", "")))] = true
	for row: Variant in DB.rows("bosses"):
		var def := row as Dictionary
		ids[StringName(String(def.get("sprite", "")))] = true
		for part: Variant in def.get("parts", []):
			if (part as Dictionary).has("sprite"):
				ids[StringName(String((part as Dictionary)["sprite"]))] = true
	for id: StringName in ids:
		var ship := SpriteBank.ship(id)
		var base: Texture2D = ship["base"]
		check.call(base != null, "SpriteBank: %s tem base" % id)
		if base == null:
			continue
		var used: Rect2 = ship["used"]
		var half := float(ship["size"]) * 0.5
		check.call(int(ship["tex_size"]) == base.get_height() and Rect2(-half, -half, half * 2.0, half * 2.0)
				.grow(0.01).encloses(used) and used.size.x > 4.0, "SpriteBank: %s com caixa opaca dentro do quadro" % id)
		if SpriteBank.SPECIAL.has(id):
			check.call(not bool(ship["hd"]) and is_equal_approx(float(ship["size"]), float(ship["tex_size"]))
					and ship["destruction"] != null, "SpriteBank: %s na arte própria (pixel art, explosão Void)" % id)
			continue
		check.call(bool(ship["hd"]), "SpriteBank: %s usa a arte HD" % id)
		check.call(is_equal_approx(float(ship["size"]), float(ship["tex_size"]) / SpriteBank.HD_TEXELS),
				"SpriteBank: %s desenhado na metade do lado da textura" % id)
		check.call(ship["destruction"] == null and int(ship["engine_frames"]) == 6,
				"SpriteBank: %s sem tira de destruição e com motor de 6 quadros" % id)
	for id: StringName in [&"prison_barge", &"prison_pod", &"protocol_beacon", &"glyph"]:
		check.call(ids.has(id) or id == &"glyph" or SpriteBank.ship(id)["base"] != null,
				"SpriteBank: alvo %s continua com sprite" % id)
	var fallback := SpriteBank.player(&"nave_que_nao_existe")
	check.call(not bool(fallback["hd"]) and fallback["base"] != null and fallback["engine_boost"] != null
			and is_equal_approx(float(fallback["size"]), 48.0), "SpriteBank: sem HD, a aeronave cai na Void (48x48)")
	var falcon := SpriteBank.player(&"falcon")
	check.call(bool(falcon["hd"]) and float((falcon["used"] as Rect2).size.y) >= 52.0
			and float((falcon["used"] as Rect2).size.y) <= 60.0, "SpriteBank: a Falcon HD tem de 52 a 60 unidades")
	# Na partida, toda nave HD sai no porte da nave Void original (30 x 26 unidades, lado maior 30).
	var big: Array[String] = []
	for id: StringName in [&"falcon", &"amphitrite", &"hippocampus", &"ram", &"eclipse"]:
		var game := ShipArt.game_used(SpriteBank.player(id))
		if maxf(game.size.x, game.size.y) < 24.0 or maxf(game.size.x, game.size.y) > 34.0:
			big.append("%s %s" % [id, game.size])
	check.call(big.is_empty() and ShipArt.game_scale(fallback) == 1.0,
			"SpriteBank: nave na partida do porte da original (lado maior 24 a 34)%s" % (
			"" if big.is_empty() else ": " + ", ".join(big)))
	check.call(SpriteBank.frame_rect(2, 160) == Rect2(320, 0, 160, 160), "SpriteBank: quadro em texels")
	var missing: Array[String] = []
	for group: String in ["player", "klaed", "nairan", "nautolan", "sea"]:
		var dir := DirAccess.open("res://assets/art/hd/" + group)
		if dir == null:
			missing.append(group)
			continue
		for file: String in dir.get_files():
			if file.ends_with(".png.import"):
				var text := FileAccess.get_file_as_string("res://assets/art/hd/%s/%s" % [group, file])
				if not text.contains("mipmaps/generate=true"):
					missing.append(file)
	check.call(missing.is_empty(), "SpriteBank: texturas HD com mipmaps no .import %s" % str(missing))
	SpriteBank.clear()
