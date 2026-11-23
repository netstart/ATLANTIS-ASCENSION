class_name PremiumShowcase
extends Control
## Vitrine das naves premium na Loja (seção "Naves premium"): cada nave flutua sobre um foco de luz na cor do
## destaque, inclina devagar como num pedestal giratório (a largura encolhe e volta: a nave "vira" no eixo do
## comprimento), com o motor aceso e o brilho que varre o casco (ShipArt), e uma faixa de luz atravessa a vitrine
## de tempos em tempos, com centelhas que piscam em volta. Uma nave (cartão avulso) ou as três (pacote).
##
## Desempenho: só texturas e retângulos (nada de polígono por quadro), 30 Hz e parada enquanto uma lista rola
## pelo dedo (TouchScroll.busy) ou com "reduzir movimento" (aí fica a pose parada, ainda com a nave inteira).

const REDRAW_HZ := 30.0
## Passada da faixa de luz (s) e a duração dela dentro do período.
const SWEEP_PERIOD := 2.8
const SWEEP_TIME := 0.8
## Altura da vitrine em pontos lógicos (uma nave; o pacote usa a mesma, com as naves menores).
const HEIGHT := 112.0
const SPARKS := 6

var ships: Array[String] = []
var accent := UiTheme.GOLD

var _arts: Array[Dictionary] = []
var _glow: Texture2D
var _time: float = 0.0
var _wait: float = 0.0


func _init(p_ships: Array[String] = [], p_accent: Color = UiTheme.GOLD) -> void:
	ships = p_ships
	accent = p_accent
	name = "Showcase"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(0, HEIGHT)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clip_contents = true


func _ready() -> void:
	texture_filter = SpriteBank.HD_FILTER
	material = ShipArt.material()
	_glow = SpriteBank.generated("fx/glow_32")
	for ship: String in ships:
		_arts.append(SpriteBank.player(StringName(ship)))
	# Cada vitrine começa num ponto do ciclo (as três não brilham juntas).
	_time = float(get_index()) * 0.9


func _process(delta: float) -> void:
	if not is_visible_in_tree() or UiFx.reduced() or TouchScroll.busy():
		return
	_time += delta
	_wait -= delta
	if _wait <= 0.0:
		_wait = 1.0 / REDRAW_HZ
		queue_redraw()


func _draw() -> void:
	if _arts.is_empty() or size.x <= 4.0:
		return
	var calm := UiFx.reduced()
	var n := _arts.size()
	var slot := size.x / float(n)
	for i: int in range(n):
		var center := Vector2(slot * (float(i) + 0.5), size.y * 0.5)
		_spot(center, minf(slot, size.y))
	for i: int in range(n):
		var art := _arts[i]
		var phase := _time * 0.9 + float(i) * 1.3
		var bob := 0.0 if calm else sin(phase * 1.7) * 2.5
		var center := Vector2(slot * (float(i) + 0.5), size.y * 0.47 + bob)
		var used: Rect2 = art.get("used", Rect2(-24, -24, 48, 48))
		var room := minf(slot * (0.86 if n > 1 else 0.6), size.y * 0.78)
		var z := room / maxf(1.0, maxf(used.size.x, used.size.y))
		# Pedestal giratório: a largura vai de 100% a 78% e volta, com uma inclinação leve no mesmo ritmo.
		var turn := 0.0 if calm else sin(phase)
		var bank := 1.0 - 0.22 * absf(turn)
		draw_set_transform(center - used.get_center() * z, turn * 0.05, Vector2(z * bank, z))
		ShipArt.draw(self, art, _time + float(i) * 1.1, 1, 1.0, true, Color(0, 0, 0, 0), calm)
		draw_set_transform(Vector2.ZERO)
	if not calm:
		_sweep()
		_sparks(slot)


## Foco de luz atrás da nave e o filete do pedestal embaixo, na cor do destaque.
func _spot(center: Vector2, side: float) -> void:
	if _glow == null:
		return
	var halo := Vector2(side * 1.15, side * 0.95)
	draw_texture_rect(_glow, Rect2(center - halo * 0.5, halo), false, Color(accent, 0.38))
	var core := halo * 0.5
	draw_texture_rect(_glow, Rect2(center - core * 0.5, core), false, Color(accent.lightened(0.4), 0.3))
	var base := Vector2(side * 0.9, side * 0.16)
	var at := Vector2(center.x, size.y - base.y * 0.6)
	draw_texture_rect(_glow, Rect2(at - base * 0.5, base), false, Color(accent, 0.55))
	draw_rect(Rect2(at.x - side * 0.3, at.y - 0.5, side * 0.6, 1.0), Color(accent.lightened(0.5), 0.7))


## Faixa de luz inclinada que atravessa a vitrine numa passada curta.
func _sweep() -> void:
	var t := fmod(_time, SWEEP_PERIOD)
	if t >= SWEEP_TIME or _glow == null:
		return
	var k := t / SWEEP_TIME
	var x := lerpf(-size.y, size.x + size.y, k)
	var fade := sin(k * PI)
	draw_set_transform(Vector2(x, size.y * 0.5), 0.45, Vector2.ONE)
	draw_texture_rect(_glow, Rect2(-14.0, -size.y, 28.0, size.y * 2.0), false, Color(1, 1, 1, 0.22 * fade))
	draw_texture_rect(_glow, Rect2(-4.0, -size.y, 8.0, size.y * 2.0), false, Color(1, 0.97, 0.88, 0.35 * fade))
	draw_set_transform(Vector2.ZERO)


## Centelhas que piscam em volta das naves (posições fixas por índice, brilho pelo tempo).
func _sparks(slot: float) -> void:
	if _glow == null:
		return
	for i: int in range(SPARKS * _arts.size()):
		var key := float(i) * 2.399
		var cell := floorf(float(i) / float(SPARKS))
		var at := Vector2(slot * (cell + 0.5 + 0.42 * sin(key * 3.1)), size.y * (0.5 + 0.4 * cos(key * 1.7)))
		var beat := maxf(0.0, sin(_time * 2.2 + key * 5.0))
		if beat <= 0.05:
			continue
		var s := 3.0 + 5.0 * beat
		draw_texture_rect(_glow, Rect2(at - Vector2(s, s) * 0.5, Vector2(s, s)), false,
				Color(accent.lightened(0.6), 0.8 * beat))
		draw_rect(Rect2(at.x - s * 0.5, at.y - 0.25, s, 0.5), Color(1, 1, 1, 0.7 * beat))
		draw_rect(Rect2(at.x - 0.25, at.y - s * 0.5, 0.5, s), Color(1, 1, 1, 0.7 * beat))
