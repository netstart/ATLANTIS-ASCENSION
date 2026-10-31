class_name BulletRenderer
extends Node2D
## Desenha um BulletPool com um MultiMeshInstance2D por tipo de bala (docs/policies/qualidade.md:
## nenhum nó por bala). A cada quadro escreve o buffer de transformações só dos vivos e ajusta o
## visible_instance_count; o motor desenha cada tipo numa chamada.

## Floats por instância no buffer 2D: duas linhas de 4 (base x, base y, origem).
const STRIDE := 8

var _kinds: Array[Dictionary] = []
var _instances: Array[MultiMeshInstance2D] = []
var _buffers: Array[PackedFloat32Array] = []
var _counts := PackedInt32Array()
var _orient := PackedByteArray()


## `kinds`: BulletKinds.ENEMY ou PLAYER. `capacity`: tamanho do pool.
func setup(kinds: Array[Dictionary], capacity: int) -> void:
	_kinds = kinds
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
		add_child(node)
		_instances.append(node)
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
