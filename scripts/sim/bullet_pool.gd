class_name BulletPool
extends RefCounted
## Projéteis em arrays paralelos de tamanho fixo (plano mestre 10.4): nenhum nó e nenhuma alocação
## depois de criado. Os vivos ficam compactados em [0, count): matar troca o último para o lugar
## (ordem determinística), e o desenho usa os primeiros `count` direto num MultiMesh.

const MIN_SPEED := 12.0

var capacity: int = 0
var count: int = 0
var pos := PackedVector2Array()
var vel := PackedVector2Array()
var radius := PackedFloat32Array()
## Giro da velocidade (rad/s): espirais e balas curvas.
var turn := PackedFloat32Array()
## Mudança da velocidade escalar (u/s²); negativa freia até MIN_SPEED.
var accel := PackedFloat32Array()
var damage := PackedFloat32Array()
## Tipo visual (ver BulletKinds).
var kind := PackedInt32Array()
## 1 depois do primeiro graze (cada bala conta uma vez).
var grazed := PackedByteArray()
## Passos de vida (balas que vencem pelo tempo, como as do chefe em sobrecarga).
var age := PackedInt32Array()


func _init(p_capacity: int) -> void:
	capacity = p_capacity
	pos.resize(capacity)
	vel.resize(capacity)
	radius.resize(capacity)
	turn.resize(capacity)
	accel.resize(capacity)
	damage.resize(capacity)
	kind.resize(capacity)
	grazed.resize(capacity)
	age.resize(capacity)


## Cria uma bala; devolve o índice ou -1 se o pool está cheio.
func spawn(p: Vector2, v: Vector2, r: float, k: int, dmg: float = 1.0, p_turn: float = 0.0,
		p_accel: float = 0.0) -> int:
	if count >= capacity:
		return -1
	var i := count
	pos[i] = p
	vel[i] = v
	radius[i] = r
	kind[i] = k
	damage[i] = dmg
	turn[i] = p_turn
	accel[i] = p_accel
	grazed[i] = 0
	age[i] = 0
	count += 1
	return i


func kill(i: int) -> void:
	if i < 0 or i >= count:
		return
	count -= 1
	if i != count:
		pos[i] = pos[count]
		vel[i] = vel[count]
		radius[i] = radius[count]
		kind[i] = kind[count]
		damage[i] = damage[count]
		turn[i] = turn[count]
		accel[i] = accel[count]
		grazed[i] = grazed[count]
		age[i] = age[count]


func clear() -> void:
	count = 0


## Move todas as balas um passo; mata as que saem de `bounds`. `gravity` vem do Gravity Breach.
func step(dt: float, bounds: Rect2, gravity: Vector2 = Vector2.ZERO) -> void:
	var i := count - 1
	var has_gravity := gravity != Vector2.ZERO
	while i >= 0:
		var v: Vector2 = vel[i]
		var t: float = turn[i]
		if t != 0.0:
			v = v.rotated(t * dt)
		var a: float = accel[i]
		if a != 0.0:
			var speed := maxf(MIN_SPEED, v.length() + a * dt)
			v = v.normalized() * speed
		if has_gravity:
			v += gravity * dt
		vel[i] = v
		var p: Vector2 = pos[i] + v * dt
		pos[i] = p
		age[i] += 1
		if not bounds.has_point(p):
			kill(i)
		i -= 1


## Mata todas as balas a menos de `dist` de `center` e devolve as posições delas (viram pérolas).
func cancel_near(center: Vector2, dist: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var d2 := dist * dist
	var i := count - 1
	while i >= 0:
		if (pos[i] as Vector2).distance_squared_to(center) <= d2:
			out.append(pos[i])
			kill(i)
		i -= 1
	return out


## Mata todas e devolve as posições.
func cancel_all() -> PackedVector2Array:
	var out := pos.slice(0, count)
	count = 0
	return out
