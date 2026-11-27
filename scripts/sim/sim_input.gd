class_name SimInput
extends RefCounted
## Entrada de um passo de simulação. O dedo vira deslocamento relativo (`move`, em unidades do
## campo); teclado e controle viram `axis` (-1..1). O replay grava só isto, mais a semente.

var move := Vector2.ZERO
var axis := Vector2.ZERO
var precise: bool = false
var fire: bool = true
var special: bool = false
var bomb: bool = false
## Botão PODER (gasta os segmentos cheios da Corrente).
var power: bool = false
## Toques no duelo de raio neste passo.
var taps: int = 0
## Maré Alta (medidor de Pressão cheio).
var tide: bool = false
## Bênção escolhida (índice na oferta) ou -1.
var choice: int = -1


## Co-op: o que é do par (especial, PODER, Maré Alta, toques do duelo e a escolha da bênção) vale vindo de qualquer
## das duas naves. `self` é a entrada da nave 1.
func merged(other: SimInput) -> SimInput:
	var c := copy()
	c.special = special or other.special
	c.power = power or other.power
	c.tide = tide or other.tide
	c.taps = taps + other.taps
	if choice < 0:
		c.choice = other.choice
	return c


func copy() -> SimInput:
	var c := SimInput.new()
	c.move = move
	c.axis = axis
	c.precise = precise
	c.fire = fire
	c.special = special
	c.bomb = bomb
	c.power = power
	c.taps = taps
	c.tide = tide
	c.choice = choice
	return c
