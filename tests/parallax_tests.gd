extends RefCounted
## Parallax (docs/policies/testes.md): a posição de cada camada é função pura da rolagem e da
## inclinação, as camadas respeitam a ordem de profundidade e "reduzir movimento" zera a inclinação e
## limita o fator. Chamado por tests/run_tests.gd (sem autoloads).


func run_unit(check: Callable) -> void:
	var a := ParallaxRig.layer_offset(123.4, 0.5, 0.0, Vector2(0.3, -0.2), 1.0, false)
	var b := ParallaxRig.layer_offset(123.4, 0.5, 0.0, Vector2(0.3, -0.2), 1.0, false)
	check.call(a == b, "Parallax: mesma rolagem, mesma posição")
	var factors: Array[float] = [0.1, 0.25, 0.5, 1.0, 1.35]
	var last := -1.0
	for f: float in factors:
		var y := ParallaxRig.layer_offset(400.0, f, 0.0, Vector2.ZERO, 0.0, false).y
		check.call(y > last, "Parallax: camada de fator %.2f anda mais que a de trás (%.1f)" % [f, y])
		last = y
	var wrapped := ParallaxRig.layer_offset(1000.0, 1.0, 96.0, Vector2.ZERO, 0.0, false)
	check.call(wrapped.y >= 0.0 and wrapped.y < 96.0, "Parallax: volta no período (%.1f)" % wrapped.y)
	var tilted := ParallaxRig.layer_offset(0.0, 1.0, 0.0, Vector2(5.0, 0.0), 1.0, false)
	check.call(is_equal_approx(tilted.x, ParallaxRig.TILT_MAX),
			"Parallax: inclinação limitada a %.0f pt" % ParallaxRig.TILT_MAX)
	var reduced := ParallaxRig.layer_offset(400.0, 1.35, 0.0, Vector2(1.0, 1.0), 1.0, true)
	check.call(reduced.x == 0.0 and is_equal_approx(reduced.y, 400.0 * ParallaxRig.REDUCED_MAX_FACTOR),
			"Parallax: reduzir movimento zera inclinação e limita o fator")
	# Chão em perspectiva (shaders/seabed_floor.gdshader): 1,0x na nave, mais lento ao longe, ida e volta.
	var y_ref := 450.0
	check.call(is_equal_approx(ParallaxRig.floor_speed(y_ref, y_ref), 1.0), "Chão 2,5D: 1,0x na linha da nave")
	var top_speed := ParallaxRig.floor_speed(0.0, y_ref)
	check.call(top_speed > 0.4 and top_speed < 0.7, "Chão 2,5D: topo do campo a %.2fx (0,4–0,7)" % top_speed)
	var mid_speed := ParallaxRig.floor_speed(y_ref * 0.5, y_ref)
	check.call(mid_speed > top_speed and mid_speed < 1.0, "Chão 2,5D: velocidade cresce de longe para perto")
	var z := ParallaxRig.floor_depth(120.0, y_ref)
	var ahead := (z - 1.0) / ParallaxRig.FLOOR_PERSP
	var back := ParallaxRig.floor_to_screen(135.0 + 65.0 * z + 9.0, ahead, 135.0, y_ref, 9.0)
	check.call(absf(back.y - 120.0) < 0.01 and absf(back.x - 200.0) < 0.01 and is_equal_approx(back.z, 1.0 / z),
			"Chão 2,5D: tela → mundo → tela volta ao mesmo ponto (%.2f, %.2f)" % [back.x, back.y])
	var cam := ParallaxRig.camera_shift(270.0, 270.0, false)
	check.call(is_equal_approx(cam, ParallaxRig.CAM_SHIFT * 270.0) and ParallaxRig.camera_shift(270.0, 270.0, true) == 0.0,
			"Chão 2,5D: câmera desloca até %.0f%% e para com reduzir movimento" % (ParallaxRig.CAM_SHIFT * 100.0))
