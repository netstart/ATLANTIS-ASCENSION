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
## Toques no duelo de raio neste passo.
var taps: int = 0


func copy() -> SimInput:
	var c := SimInput.new()
	c.move = move
	c.axis = axis
	c.precise = precise
	c.fire = fire
	c.special = special
	c.bomb = bomb
	c.taps = taps
	return c
