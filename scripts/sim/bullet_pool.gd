class_name BulletPool
extends RefCounted
## Projéteis em arrays paralelos de tamanho fixo (plano mestre 10.4): nenhum nó e nenhuma alocação
## depois de criado. Os vivos ficam compactados em [0, count): matar troca o último para o lugar
## (ordem determinística), e o desenho usa os primeiros `count` direto num MultiMesh.

const MIN_SPEED := 12.0
## Alvos que uma bala perfurante já acertou (inimigo, corpo do chefe, cada parte): cada um leva dano uma
## vez só por bala. Anel fixo por bala, sem alocação; 4 basta porque a bala segue em frente e só
## sobrepõe poucos alvos ao mesmo tempo (o mais antigo sai do anel quando ela já passou por ele).
const HIT_SLOTS := 4

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
## Tiros do jogador: alvos que ainda atravessa (Railgun) e raio do dano em área (Plasma).
var pierce := PackedInt32Array()
var splash := PackedFloat32Array()
## Anel de alvos já acertados (HIT_SLOTS por bala) e quantos acertos a bala já marcou.
var hit_ids := PackedInt64Array()
var hit_n := PackedInt32Array()


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
	pierce.resize(capacity)
	splash.resize(capacity)
	hit_ids.resize(capacity * HIT_SLOTS)
	hit_n.resize(capacity)


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
	pierce[i] = 0
	splash[i] = 0.0
	hit_n[i] = 0
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
		pierce[i] = pierce[count]
		splash[i] = splash[count]
		var n: int = hit_n[count]
		hit_n[i] = n
		for k: int in range(mini(n, HIT_SLOTS)):
			hit_ids[i * HIT_SLOTS + k] = hit_ids[count * HIT_SLOTS + k]


## Se a bala `i` já acertou o alvo `target` (ver Sim.target_id).
func has_hit(i: int, target: int) -> bool:
	var base := i * HIT_SLOTS
	for k: int in range(mini(hit_n[i], HIT_SLOTS)):
		if hit_ids[base + k] == target:
			return true
	return false


## Guarda o alvo `target` no anel da bala `i` (o mais antigo sai quando enche).
func mark_hit(i: int, target: int) -> void:
	var n: int = hit_n[i]
	hit_ids[i * HIT_SLOTS + n % HIT_SLOTS] = target
	hit_n[i] = n + 1


func clear() -> void:
	count = 0


## Move todas as balas um passo; mata as que saem de `bounds`. `gravity` vem do Gravity Breach e do
## vento. `frozen` (Pulso EMP) segura todas no lugar sem envelhecer.
func step(dt: float, bounds: Rect2, gravity: Vector2 = Vector2.ZERO, frozen: bool = false) -> void:
	if frozen:
		return
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


## Puxa as balas a menos de `radius` de `center` (Fenda gravitacional); devolve as que chegaram ao
## centro (viram pérolas).
func pull(center: Vector2, radius: float, strength: float, dt: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var r2 := radius * radius
	var i := count - 1
	while i >= 0:
		var p: Vector2 = pos[i]
		var d2 := p.distance_squared_to(center)
		if d2 <= 64.0:
			out.append(p)
			kill(i)
		elif d2 <= r2:
			vel[i] = (vel[i] as Vector2).lerp((center - p).normalized() * strength, minf(1.0, dt * 6.0))
		i -= 1
	return out
