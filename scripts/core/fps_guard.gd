class_name FpsGuard
extends RefCounted
## Monitor de FPS da partida: decide, só pela sequência de deltas, quando pedir um rebaixamento
## de qualidade (GfxQuality.auto_downgrade). Puro, sem nós e sem autoloads, para a regra ser
## testável sem cena (tests/run_tests.gd).
##
## Depois de um aquecimento (WARMUP quadros, para o aparelho acomodar a carga), se a MÉDIA de
## quadro numa janela recente (WINDOW) passar de SLOW_MS (FPS sustentado bem abaixo do alvo),
## tick() devolve true UMA vez e entra num período de espera (COOLDOWN quadros) em que não
## sinaliza de novo, para o orçamento mais leve assentar antes de reavaliar. Nunca pede para
## subir de volta; quem age é a partida, e GfxQuality decide se há o que rebaixar.

## Quadros da janela deslizante que define a média (~1,5 s a 60 FPS).
const WINDOW := 90
## Limite da média de quadro em ms; acima dele o FPS está sustentado abaixo de ~45.
const SLOW_MS := 22.0
## Espera, em quadros, depois de sinalizar (~3 s a 60 FPS): tempo do orçamento mais leve assentar.
const COOLDOWN := 180
## Quadros iniciais ignorados: a carga do começo da missão não vale como lentidão real.
const WARMUP := 120

var _window := PackedFloat32Array()
var _sum: float = 0.0
var _seen: int = 0
var _cooldown: int = 0


## Alimenta o guarda com a duração do quadro (s). Devolve true no único quadro em que pede rebaixar.
func tick(delta: float) -> bool:
	_seen += 1
	_window.push_back(delta)
	_sum += delta
	if _window.size() > WINDOW:
		_sum -= _window[0]
		_window.remove_at(0)
	if _cooldown > 0:
		_cooldown -= 1
		return false
	if _seen <= WARMUP or _window.size() < WINDOW:
		return false
	if _sum / float(_window.size()) * 1000.0 > SLOW_MS:
		_cooldown = COOLDOWN
		return true
	return false


## Esquece a janela e a espera (nova missão).
func reset() -> void:
	_window = PackedFloat32Array()
	_sum = 0.0
	_seen = 0
	_cooldown = 0
