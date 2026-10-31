class_name BulletKinds
extends RefCounted
## Tipos de projétil: id numérico (usado no BulletPool e no MultiMesh), raio de colisão e textura.
## Balas inimigas têm contorno escuro e núcleo claro (leitura, docs/policies/qualidade.md); o raio
## de colisão é menor que o desenho, como manda o gênero.

const ENEMY: Array[Dictionary] = [
	{"id": &"orb_cyan_s", "radius": 2.5, "texture": "res://assets/art/generated/bullets/orb_cyan_8.png"},
	{"id": &"orb_cyan_m", "radius": 3.5, "texture": "res://assets/art/generated/bullets/orb_cyan_12.png"},
	{"id": &"orb_gold_m", "radius": 3.5, "texture": "res://assets/art/generated/bullets/orb_gold_12.png"},
	{"id": &"orb_violet_m", "radius": 3.5, "texture": "res://assets/art/generated/bullets/orb_violet_12.png"},
	{"id": &"orb_coral_l", "radius": 5.0, "texture": "res://assets/art/generated/bullets/orb_coral_16.png"},
	{"id": &"needle_gold", "radius": 2.0, "texture": "res://assets/art/generated/bullets/needle_gold.png"},
]
const PLAYER: Array[Dictionary] = [
	{"id": &"shot_pulsar", "radius": 4.0, "texture": "res://assets/art/generated/bullets/shot_pulsar.png"},
	{"id": &"shot_back", "radius": 4.0, "texture": "res://assets/art/generated/bullets/shot_pulsar.png"},
]


static func enemy_index(id: StringName) -> int:
	for i: int in range(ENEMY.size()):
		if ENEMY[i]["id"] == id:
			return i
	return 1


static func enemy_radius(index: int) -> float:
	return float(ENEMY[clampi(index, 0, ENEMY.size() - 1)]["radius"])


static func player_index(id: StringName) -> int:
	for i: int in range(PLAYER.size()):
		if PLAYER[i]["id"] == id:
			return i
	return 0
