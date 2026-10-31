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
