class_name BulletRenderer
extends Node2D
## Desenha um BulletPool com um MultiMeshInstance2D por tipo de bala (docs/policies/qualidade.md:
## nenhum nó por bala). A cada quadro escreve o buffer de transformações só dos vivos e ajusta o
## visible_instance_count; o motor desenha cada tipo numa chamada.
## Halo (opcional): um segundo MultiMesh por tipo, aditivo e com filtro linear, que reaproveita o
## mesmo buffer com a textura de clarão maior e a cor "glow" do tipo. Fica atrás das balas: o núcleo e
## o contorno continuam por cima (leitura), o halo só dá a luz neon.

## Floats por instância no buffer 2D: duas linhas de 4 (base x, base y, origem).
const STRIDE := 8
## Modos de daltonismo (plano mestre 2.4 e 6.1): as cores das balas trocam juntas, mantendo o núcleo
## claro e o contorno escuro (o contraste continua ≥ 4,5:1). Tinta multiplicada sobre a textura.
const COLORBLIND := {
	"protanopia": {&"orb_coral_l": Color(1.0, 0.95, 0.45), &"orb_violet_m": Color(0.55, 0.75, 1.0),
			&"orb_gold_m": Color(1.0, 1.0, 1.0)},
	"deuteranopia": {&"orb_coral_l": Color(1.0, 0.9, 0.4), &"orb_violet_m": Color(0.5, 0.7, 1.0),
			&"orb_gold_m": Color(1.0, 1.0, 1.0)},
	"tritanopia": {&"orb_cyan_s": Color(1.0, 0.65, 0.8), &"orb_cyan_m": Color(1.0, 0.65, 0.8),
			&"orb_gold_m": Color(1.0, 0.72, 0.72), &"needle_gold": Color(1.0, 0.72, 0.72)},
}

## Paleta de daltonismo ativa ("off" = cores originais).
var palette: String = "off"
## Alfa do halo aditivo (0 = sem halo) e quanto ele é maior que a bala.
var halo_alpha: float = 0.0
var halo_scale: float = 3.0

var _kinds: Array[Dictionary] = []
var _instances: Array[MultiMeshInstance2D] = []
var _halos: Array[MultiMeshInstance2D] = []
var _buffers: Array[PackedFloat32Array] = []
var _counts := PackedInt32Array()
var _orient := PackedByteArray()


## `kinds`: BulletKinds.ENEMY ou PLAYER. `capacity`: tamanho do pool.
func setup(kinds: Array[Dictionary], capacity: int) -> void:
	_kinds = kinds
	var halo_layer: Node2D = null
	if halo_alpha > 0.0:
		halo_layer = Node2D.new()
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		halo_layer.material = mat
		halo_layer.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		add_child(halo_layer)
	var flare := SpriteBank.generated("fx/flare_64")
	for k: Dictionary in kinds:
		var tex := SpriteBank.texture(String(k["texture"]))
		var mesh := QuadMesh.new()
		mesh.size = Vector2(tex.get_size()) if tex != null else Vector2(8, 8)
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_2D
		mm.mesh = mesh
		mm.instance_count = capacity
		mm.visible_instance_count = 0
		var node := MultiMeshInstance2D.new()
		node.multimesh = mm
		node.texture = tex
		node.modulate = (COLORBLIND.get(palette, {}) as Dictionary).get(k["id"], Color(1, 1, 1))
		add_child(node)
		_instances.append(node)
		if halo_layer != null:
			var hmesh := QuadMesh.new()
			hmesh.size = mesh.size * halo_scale
			var hmm := MultiMesh.new()
			hmm.transform_format = MultiMesh.TRANSFORM_2D
			hmm.mesh = hmesh
			hmm.instance_count = capacity
			hmm.visible_instance_count = 0
			var halo := MultiMeshInstance2D.new()
			halo.multimesh = hmm
			halo.texture = flare
			halo.use_parent_material = true
			halo.modulate = Color(k.get("glow", Color(1, 1, 1)) as Color, halo_alpha)
			halo_layer.add_child(halo)
			_halos.append(halo)
		var buf := PackedFloat32Array()
		buf.resize(capacity * STRIDE)
		_buffers.append(buf)
		# Agulhas e tiros alongados giram com a velocidade; bolas não.
		_orient.append(1 if String(k["id"]).begins_with("needle") or String(k["id"]).begins_with("shot") else 0)
	_counts.resize(kinds.size())


func render(pool: BulletPool) -> void:
	_counts.fill(0)
	for i: int in range(pool.count):
		var k: int = pool.kind[i]
		if k < 0 or k >= _kinds.size():
			continue
		var n: int = _counts[k]
		var p: Vector2 = pool.pos[i]
		var base := n * STRIDE
		var buf := _buffers[k]
		if _orient[k] == 1:
			var dir: Vector2 = (pool.vel[i] as Vector2).normalized()
			# Eixo y da textura ao longo da velocidade (a agulha aponta para onde vai); eixo x
			# perpendicular: x = (d.y, -d.x), y = (d.x, d.y). Buffer: [x.x, y.x, _, o.x, x.y, y.y, _, o.y].
			buf[base] = dir.y
			buf[base + 1] = dir.x
			buf[base + 3] = p.x
			buf[base + 4] = -dir.x
			buf[base + 5] = dir.y
			buf[base + 7] = p.y
		else:
			buf[base] = 1.0
			buf[base + 1] = 0.0
			buf[base + 3] = p.x
			buf[base + 4] = 0.0
			buf[base + 5] = 1.0
			buf[base + 7] = p.y
		_counts[k] = n + 1
	for k: int in range(_kinds.size()):
		var mm := _instances[k].multimesh
		mm.buffer = _buffers[k]
		mm.visible_instance_count = _counts[k]
		if k < _halos.size():
			_halos[k].multimesh.buffer = _buffers[k]
			_halos[k].multimesh.visible_instance_count = _counts[k]


## Posições das balas desenhadas no último quadro (até `limit`), lidas do buffer: o cancelamento de
## balas da bomba precisa de onde elas estavam antes de a Sim apagá-las.
func last_positions(limit: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	for k: int in range(_kinds.size()):
		var buf := _buffers[k]
		var n := _instances[k].multimesh.visible_instance_count
		for i: int in range(n):
			if out.size() >= limit:
				return out
			out.append(Vector2(buf[i * STRIDE + 3], buf[i * STRIDE + 7]))
	return out
