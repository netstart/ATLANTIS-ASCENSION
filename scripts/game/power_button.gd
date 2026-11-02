class_name PowerButton
extends Button
## Botão PODER do HUD da partida (.ai/08-poderes-das-naves.md), o terceiro da zona do polegar. Dentro dele, o
## anel da Corrente em 3 segmentos (HudKit.draw_power) que anda suave até a carga real (encaixa na hora quando o
## jogador gasta), o ícone do poder que sairia agora e a legenda; no nível III um halo na cor da nave pulsa.
## O nome do poder fica num rótulo do GameHud (fora do botão, ao lado dos botões), que este botão preenche.
## Como o resto do HUD, só troca StyleBox, texto e desenho quando o degrau, o nível ou o poder vivo mudam.

## Segmentos por segundo que o desenho anda até a carga real.
const FILL_RATE := 2.5
## Degraus do anel inteiro (3 segmentos): redesenho só na troca de degrau.
const STEPS := 48
## Algarismos romanos dos níveis (nome no HUD e faixa do poder).
const ROMAN: Array[String] = ["", "I", "II", "III"]

## Botão grande (zona do polegar com espaço e desktop): legenda embaixo do anel.
var big := false
## "Reduzir movimento": sem pulso, tremida, halo pulsando nem enchimento animado.
var reduced := false
## Rótulo do nome do poder (do GameHud; este botão só escreve, mede a letra e mostra ou esconde).
var name_label: Label

var _gauge: Control
var _caption: Label
var _glow: Panel
var _glow_tween: Tween
var _icon: Texture2D
var _id: StringName = &""
var _tint := Color(1, 1, 1)
var _shown: float = 0.0
var _q: int = -1
var _seg: int = -1
var _live := false
var _name_w: float = 120.0
var _name_size: int = UiTheme.SMALL_SIZE
var _shake: float = 0.0


func setup(label: Label, p_reduced: bool) -> void:
	name_label = label
	reduced = p_reduced
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.visible = false
	_glow = HudKit.ignore(Panel.new()) as Panel
	_glow.show_behind_parent = true
	_glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_glow.visible = false
	add_child(_glow)
	_gauge = HudKit.ignore(Control.new())
	_gauge.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_gauge.draw.connect(func() -> void: HudKit.draw_power(_gauge, big, _q / float(STEPS) * Powers.SEGMENTS, _tint,
			_icon, _live, _shake))
	add_child(_gauge)
	_caption = HudKit.caption(self)
	_restyle()


## Tamanho do botão (lado `side`): legenda só no grande, como na especial e na bomba.
func set_side(side: float, p_big: bool) -> void:
	big = p_big
	custom_minimum_size = Vector2(side, side)
	size = custom_minimum_size
	_caption.visible = big
	_caption.position = Vector2(2, side - 15.0)
	_caption.size = Vector2(side - 4.0, 13)
	_gauge.queue_redraw()


## Rótulo do nome: na altura `y`, encostado no botão e correndo para dentro até `inner_x` (a borda do outro
## lado). Nome comprido diminui a letra e, no limite, termina em reticências (nunca quebra a linha).
func place_name(y: float, inner_x: float, left_handed: bool) -> void:
	var h := 14.0
	if left_handed:
		_name_w = inner_x - position.x
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		name_label.position = Vector2(position.x, y)
	else:
		_name_w = position.x + size.x - inner_x
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		name_label.position = Vector2(inner_x, y)
	name_label.size = Vector2(_name_w, h)
	_fit_name()


## Textos do idioma (a legenda e o nome, refeito no próximo refresh).
func retext() -> void:
	_caption.text = tr("hud.power")
	_id = &""


## Segmentos cheios mostrados agora (dica do tutorial).
func segments() -> int:
	return _seg


func refresh(sim: Sim, delta: float) -> void:
	var charge := clampf(sim.player.power_charge, 0.0, Powers.SEGMENTS)
	if charge < _shown or reduced:
		_shown = charge
	else:
		_shown = move_toward(_shown, charge, FILL_RATE * delta)
	var q := int(_shown / Powers.SEGMENTS * STEPS + 0.0001)
	var seg := Powers.whole(charge)
	var live := not sim.power_fx.is_empty()
	var id := StringName("%s_%d" % [sim.player.ship.get("id", "falcon"), clampi(seg, 1, 3)])
	if live:
		id = StringName(String(sim.power_fx[0]["id"]))
	var changed := false
	if id != _id:
		_id = id
		var def: Dictionary = (sim.tables.get("powers", {}) as Dictionary).get(id, {})
		_icon = SpriteBank.texture(String(def.get("icon", "")))
		_tint = Color(String(def.get("color", "#ffffff")))
		name_label.text = "%s · %s" % [ROMAN[clampi(int(def.get("tier", 1)), 1, 3)], tr(String(def.get("name_key", "")))]
		name_label.add_theme_color_override("font_color", _tint.lerp(UiTheme.WHITE, 0.35))
		_fit_name()
		changed = true
	if seg != _seg or live != _live:
		_seg = seg
		_live = live
		name_label.visible = seg >= 1 and not live
		_restyle()
		changed = true
	if q != _q or changed:
		_q = q
		_gauge.queue_redraw()
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta)
		_gauge.queue_redraw()


## Segmento cheio (evento power_charge): o botão pulsa, mais forte a cada segmento.
func charged(count: int) -> void:
	if reduced:
		return
	pivot_offset = size * 0.5
	var grow := 1.12 + 0.06 * count
	scale = Vector2(grow, grow)
	create_tween().tween_property(self, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK) \
			.set_ease(Tween.EASE_OUT)


## Apertou sem segmento cheio: o medidor treme (o som vem do Game).
func empty() -> void:
	if not reduced:
		_shake = HudKit.POWER_SHAKE
		_gauge.queue_redraw()


## Letra do nome: a maior (até SMALL_SIZE, no mínimo 2 pontos menor) em que o nome cabe na largura.
func _fit_name() -> void:
	var font := name_label.get_theme_font("font")
	var font_size := UiTheme.SMALL_SIZE
	if font != null:
		while font_size > UiTheme.SMALL_SIZE - 2 and \
				font.get_string_size(name_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > _name_w - 2.0:
			font_size -= 1
	if font_size != _name_size:
		_name_size = font_size
		name_label.add_theme_font_size_override("font_size", font_size)


## Vidro na cor da nave: fraco sem carga, aceso com um segmento cheio; no nível III, halo pulsando.
func _restyle() -> void:
	var lit := _seg >= 1 and not _live
	HudKit.style_round(self, _tint, 1.0 if lit else 0.75, lit, 14)
	_caption.add_theme_color_override("font_color", _tint if lit else UiTheme.TEXT_DIM)
	var supreme := _seg >= 3 and not _live
	_glow.add_theme_stylebox_override("panel", HudKit.glow_box(_tint))
	_glow.visible = supreme
	if _glow_tween != null and _glow_tween.is_valid():
		_glow_tween.kill()
	_glow.modulate.a = 1.0
	if supreme and not reduced:
		_glow_tween = _glow.create_tween().set_loops()
		_glow_tween.tween_property(_glow, "modulate:a", 0.35, 0.4).set_trans(Tween.TRANS_SINE)
		_glow_tween.tween_property(_glow, "modulate:a", 1.0, 0.4).set_trans(Tween.TRANS_SINE)
