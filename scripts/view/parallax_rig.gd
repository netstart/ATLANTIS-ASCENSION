class_name ParallaxRig
extends Node2D
## Camadas de profundidade (plano mestre 7.3 e 8.3). Cada camada é um nó com um fator: a posição dela
## é uma função pura da rolagem e da inclinação (layer_offset), testada em tests/parallax_tests.gd.
## "Reduzir movimento" zera a inclinação e limita o fator de cada camada.

const REDUCED_MAX_FACTOR := 1.0
const TILT_MAX := 6.0

## Camadas na ordem de desenho: {node: Node2D, factor: float, tilt: float, period: float}.
var layers: Array[Dictionary] = []
var reduce_motion: bool = false


func add_layer(node: Node2D, factor: float, tilt_factor: float = 0.0, period: float = 0.0) -> void:
	add_child(node)
	layers.append({"node": node, "factor": factor, "tilt": tilt_factor, "period": period})


## Aplica a rolagem (unidades) e a inclinação (-1..1 por eixo) a todas as camadas.
func apply(scroll: float, tilt: Vector2 = Vector2.ZERO) -> void:
	for layer: Dictionary in layers:
		var offset := layer_offset(scroll, float(layer["factor"]), float(layer["period"]), tilt,
				float(layer["tilt"]), reduce_motion)
		(layer["node"] as Node2D).position = offset


## Deslocamento de uma camada: rolagem vezes o fator (com volta em `period`, se houver), mais a
## inclinação vezes o fator de inclinação (no máximo TILT_MAX pontos). Regra pura.
static func layer_offset(scroll: float, factor: float, period: float, tilt: Vector2, tilt_factor: float,
		reduced: bool) -> Vector2:
	var f := minf(factor, REDUCED_MAX_FACTOR) if reduced else factor
	var y := scroll * f
	if period > 0.0:
		y = fposmod(y, period)
	var t := Vector2.ZERO if reduced else tilt.limit_length(1.0) * TILT_MAX * tilt_factor
	return Vector2(t.x, y + t.y)
