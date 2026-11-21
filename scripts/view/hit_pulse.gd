class_name HitPulse
extends RefCounted
## Retorno de dano de um alvo grande (corpo, parte ou ponto fraco do chefe), só na vista: em vez do
## branco chapado, um tinte quente que pulsa e apaga, mais um tranco curto do sprite.
##
## Avança a 60 Hz (WorldView._emit). Tiro contínuo não trava o tinte no máximo: um pulso novo só sai
## `GAP` passos depois do anterior e cada um some em `FADE` passos, então o sprite volta a aparecer
## inteiro entre os pulsos. `strength` (0..1, o tamanho do golpe) aumenta o pico e o tranco;
## "reduzir movimento" (`calm`) tira o tranco e enfraquece o tinte.

## Passos mínimos entre dois pulsos, mesmo com acerto em todo passo.
const GAP := 7
## Passos até o tinte apagar.
const FADE := 10
## Pico do tinte (fração da cor quente misturada ao sprite): golpe pequeno e golpe grande.
const PEAK_MIN := 0.24
const PEAK_MAX := 0.34
## Com "reduzir movimento".
const PEAK_CALM := 0.16
## Passos de tranco e amplitude em pixels (golpe pequeno, grande).
const SHAKE_STEPS := 4
const SHAKE_MIN := 1.0
const SHAKE_MAX := 2.0

var calm: bool = false
## Para quem guarda um pulso por alvo (EnemyPulses): o HP visto no último passo e a marca do passo.
var seen_hp: float = 0.0
var mark: int = 0
## Passos desde o último pulso (começa "há muito tempo").
var _since: int = 1 << 20
var _peak: float = 0.0
var _shake: float = 0.0


## Um passo de 60 Hz; `hit` diz se o alvo levou dano neste passo e `strength` quanto (0..1).
func tick(hit: bool, strength: float = 0.0) -> void:
	_since = mini(_since + 1, 1 << 20)
	if hit and _since >= GAP:
		var s := clampf(strength, 0.0, 1.0)
		_since = 0
		_peak = PEAK_CALM if calm else lerpf(PEAK_MIN, PEAK_MAX, s)
		_shake = 0.0 if calm else lerpf(SHAKE_MIN, SHAKE_MAX, s)


## Quanto do tinte quente está aceso agora (0..PEAK_MAX), caindo em curva até 0.
func intensity() -> float:
	if _since >= FADE:
		return 0.0
	var u := 1.0 - float(_since) / FADE
	return _peak * u * u


## Tranco do sprite agora: alterna de lado a cada passo e encolhe até parar (sem sorteio).
func offset() -> Vector2:
	if _since >= SHAKE_STEPS or _shake <= 0.0:
		return Vector2.ZERO
	var side := 1.0 if _since % 2 == 0 else -1.0
	var a := _shake * (1.0 - float(_since) / SHAKE_STEPS)
	return Vector2(side * a, -0.5 * a)


## Modulate que o shader de dano (shaders/sprite_flash.gdshader) lê como tinte de acerto: a força vai no
## alfa (2 + força: quente; 4 + força: dourado, ponto fraco). Sem força, a cor normal.
static func tint(base: Color, amount: float, gold: bool) -> Color:
	if amount <= 0.0:
		return base
	return Color(base.r, base.g, base.b, (4.0 if gold else 2.0) + clampf(amount, 0.0, 1.0))


func reset() -> void:
	_since = 1 << 20
	_peak = 0.0
	_shake = 0.0
