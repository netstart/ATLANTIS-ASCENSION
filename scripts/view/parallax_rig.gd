class_name ParallaxRig
extends Node2D
## Camadas de profundidade (plano mestre 7.3 e 8.3). Cada camada é um nó com um fator: a posição dela
## é uma função pura da rolagem e da inclinação (layer_offset), testada em tests/parallax_tests.gd.
## "Reduzir movimento" zera a inclinação e limita o fator de cada camada.

const REDUCED_MAX_FACTOR := 1.0
const TILT_MAX := 6.0
## Chão em perspectiva ("mode 7", shaders/seabed_floor.gdshader): quanto a profundidade cresce por
## unidade de tela acima da linha de referência. 0,00065 deixa o topo do campo a ≈ 0,5x da rolagem.
const FLOOR_PERSP := 0.00065
## Câmera que acompanha a nave na horizontal: no máximo 8% da largura do campo (só visual).
const CAM_SHIFT := 0.08

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


## Profundidade z do chão na linha `y` da tela: 1 na linha de referência `y_ref` (onde está a nave),
## maior para cima (mais longe). Mesma conta do shader do chão. Regra pura.
static func floor_depth(y: float, y_ref: float, persp: float = FLOOR_PERSP) -> float:
	return 1.0 / maxf(0.1, 1.0 - (y_ref - y) * persp)


## Velocidade aparente do chão na linha `y`, como fração da rolagem (1/z²): 1,0 na nave, menos ao longe.
static func floor_speed(y: float, y_ref: float, persp: float = FLOOR_PERSP) -> float:
	var z := floor_depth(y, y_ref, persp)
	return 1.0 / (z * z)


## Ponto do chão → tela. `ahead` é a distância do ponto à frente da linha de referência (unidades do
## mundo; posição do ponto menos a rolagem). Devolve (x, y, escala 1/z); escala 0 = atrás da câmera.
static func floor_to_screen(world_x: float, ahead: float, cx: float, y_ref: float, cam_x: float = 0.0,
		persp: float = FLOOR_PERSP) -> Vector3:
	var z := 1.0 + persp * ahead
	if z <= 0.1:
		return Vector3(cx, y_ref + 100000.0, 0.0)
	var w := 1.0 / z
	return Vector3(cx + (world_x - cam_x - cx) * w, y_ref - (1.0 - w) / persp, w)


## Deslocamento horizontal da câmera (unidades do chão) para a nave em `player_x` de um campo de
## largura `field_w`: no máximo CAM_SHIFT da largura para cada lado; zero com "reduzir movimento".
static func camera_shift(player_x: float, field_w: float, reduced: bool) -> float:
	if reduced or field_w <= 0.0:
		return 0.0
	return clampf(player_x / field_w * 2.0 - 1.0, -1.0, 1.0) * CAM_SHIFT * field_w
