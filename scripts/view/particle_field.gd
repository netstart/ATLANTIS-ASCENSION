class_name ParticleField
extends Node2D
## Partículas só visuais em lote (docs/policies/qualidade.md: nenhum nó por partícula). Um
## MultiMeshInstance2D por textura, com cor por instância; o estado vive em vetores empacotados e a
## partícula que morre troca de lugar com a última (sem buracos, sem alocação por quadro).
## Movimento: velocidade com arrasto exponencial e aceleração constante; tamanho, cor e alfa
## interpolam do início ao fim da vida. Partículas "alinhadas" giram para a velocidade e esticam
## com ela (faíscas). O campo cheio ignora novas partículas: o orçamento (GfxQuality
## "particles_max") é teto, não meta.
## Nada aqui toca a Sim: a semente própria só dá variedade, nunca muda a partida.

## Floats por instância: transformação 2D (8) + cor (4).
const STRIDE := 12

var capacity: int = 0
var count: int = 0

var _textures: Array[Texture2D] = []
var _instances: Array[MultiMeshInstance2D] = []
var _buffers: Array[PackedFloat32Array] = []
var _counts := PackedInt32Array()
var _tex := PackedByteArray()
var _align := PackedByteArray()
var _pos := PackedVector2Array()
var _vel := PackedVector2Array()
var _accel := PackedVector2Array()
var _life := PackedFloat32Array()
var _span := PackedFloat32Array()
var _size0 := PackedFloat32Array()
var _size1 := PackedFloat32Array()
var _rot := PackedFloat32Array()
var _spin := PackedFloat32Array()
var _drag := PackedFloat32Array()
var _color0 := PackedColorArray()
var _color1 := PackedColorArray()


## `textures`: uma por tipo (o índice é o `tex` de spawn). `additive`: mistura aditiva (luz).
## `smooth`: filtro linear (brilhos escalados); sem ele, pixel art nítida.
func setup(textures: Array[Texture2D], p_capacity: int, additive: bool, smooth: bool) -> void:
	capacity = maxi(1, p_capacity)
	_textures = textures
	if additive:
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = mat
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR if smooth else CanvasItem.TEXTURE_FILTER_NEAREST
	for tex: Texture2D in textures:
		var mesh := QuadMesh.new()
		mesh.size = Vector2(tex.get_size()) if tex != null else Vector2(8, 8)
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_2D
		mm.use_colors = true
		mm.mesh = mesh
		mm.instance_count = capacity
		mm.visible_instance_count = 0
		var node := MultiMeshInstance2D.new()
		node.multimesh = mm
		node.texture = tex
		node.use_parent_material = true
		add_child(node)
		_instances.append(node)
		var buf := PackedFloat32Array()
		buf.resize(capacity * STRIDE)
		_buffers.append(buf)
	_counts.resize(textures.size())
	# Vetores empacotados são valores (cópia ao iterar): cada um muda de tamanho pelo próprio nome.
	_tex.resize(capacity)
	_align.resize(capacity)
	_pos.resize(capacity)
	_vel.resize(capacity)
	_accel.resize(capacity)
	_life.resize(capacity)
	_span.resize(capacity)
	_size0.resize(capacity)
	_size1.resize(capacity)
	_rot.resize(capacity)
	_spin.resize(capacity)
	_drag.resize(capacity)
	_color0.resize(capacity)
	_color1.resize(capacity)


func free_slots() -> int:
	return capacity - count


## Uma partícula. `size0`/`size1`: escala no início e no fim; `drag`: fração da velocidade perdida
## por segundo (exponencial); `align`: gira para a velocidade e estica com ela.
func spawn(tex: int, at: Vector2, vel: Vector2, life: float, size0: float, size1: float, color0: Color,
		color1: Color, drag: float = 0.0, accel: Vector2 = Vector2.ZERO, rot: float = 0.0, spin: float = 0.0,
		align: bool = false) -> void:
	if count >= capacity or life <= 0.0:
		return
	var i := count
	count += 1
	_tex[i] = tex
	_align[i] = 1 if align else 0
	_pos[i] = at
	_vel[i] = vel
	_accel[i] = accel
	_life[i] = life
	_span[i] = life
	_size0[i] = size0
	_size1[i] = size1
	_rot[i] = rot
	_spin[i] = spin
	_drag[i] = drag
	_color0[i] = color0
	_color1[i] = color1


func clear() -> void:
	count = 0


## Avança `delta` segundos e reescreve os buffers dos MultiMesh.
func advance(delta: float) -> void:
	var i := count - 1
	while i >= 0:
		var life := _life[i] - delta
		if life <= 0.0:
			_remove(i)
		else:
			_life[i] = life
			var v := _vel[i]
			if _drag[i] > 0.0:
				v *= exp(-_drag[i] * delta)
			v += _accel[i] * delta
			_vel[i] = v
			_pos[i] += v * delta
			_rot[i] += _spin[i] * delta
		i -= 1
	_write()


func _remove(i: int) -> void:
	var last := count - 1
	if i != last:
		_tex[i] = _tex[last]
		_align[i] = _align[last]
		_pos[i] = _pos[last]
		_vel[i] = _vel[last]
		_accel[i] = _accel[last]
		_life[i] = _life[last]
		_span[i] = _span[last]
		_size0[i] = _size0[last]
		_size1[i] = _size1[last]
		_rot[i] = _rot[last]
		_spin[i] = _spin[last]
		_drag[i] = _drag[last]
		_color0[i] = _color0[last]
		_color1[i] = _color1[last]
	count = last


func _write() -> void:
	_counts.fill(0)
	for i: int in range(count):
		var k: int = _tex[i]
		var n: int = _counts[k]
		var u := 1.0 - _life[i] / _span[i]
		var s := lerpf(_size0[i], _size1[i], u)
		var sx := s
		var sy := s
		var angle := _rot[i]
		if _align[i] == 1:
			var v := _vel[i]
			# Eixo y da textura contra a velocidade: a ponta clara (topo) vai na frente.
			angle = atan2(v.x, -v.y)
			sy = s * clampf(v.length() / 110.0, 0.7, 2.6)
		var c := cos(angle)
		var sn := sin(angle)
		var col := _color0[i].lerp(_color1[i], u)
		var p := _pos[i]
		var buf := _buffers[k]
		var b := n * STRIDE
		buf[b] = c * sx
		buf[b + 1] = -sn * sy
		buf[b + 2] = 0.0
		buf[b + 3] = p.x
		buf[b + 4] = sn * sx
		buf[b + 5] = c * sy
		buf[b + 6] = 0.0
		buf[b + 7] = p.y
		buf[b + 8] = col.r
		buf[b + 9] = col.g
		buf[b + 10] = col.b
		buf[b + 11] = col.a
		_counts[k] = n + 1
	for k: int in range(_instances.size()):
		var mm := _instances[k].multimesh
		mm.buffer = _buffers[k]
		mm.visible_instance_count = _counts[k]
