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
