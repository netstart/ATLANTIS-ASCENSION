class_name HudBossBar
extends Control
## Barra do chefe do HUD da partida (GameHud): placa com o nome, trilho, rastro do dano, preenchimento e uma marca
## em cada limiar de etapa. Enche ao entrar (BOSS_FILL_SECONDS), o rastro branco segura e desce atrás do dano e
## a barra some quando o chefe cai. Só tamanho de ColorRect anda a cada quadro.

const FILL_SECONDS := 1.2
const BAR_H := 6.0

## "Reduzir movimento": sem enchimento animado nem entrada deslizando.
var reduced := false

var _name: Label
var _track: Panel
var _ghost: ColorRect
var _fill: ColorRect
var _shine: ColorRect
var _ticks: Array[ColorRect] = []
var _ref: SimBoss
var _w: float = 200.0
var _fill_t: float = 0.0
var _shown: float = -1.0
var _ghost_v: float = 0.0
var _hold: float = 0.0
var _rest_y: float = 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_name = UiTheme.heading("", UiTheme.SMALL_SIZE, UiTheme.CORAL)
	_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name.add_theme_color_override("font_outline_color", UiTheme.ABYSS)
	_name.add_theme_constant_override("outline_size", 3)
	_name.clip_text = true
	add_child(_name)
	_track = HudKit.ignore(Panel.new()) as Panel
	var track := UiTheme.chamfer(Color(UiTheme.ABYSS, 0.82), Color(UiTheme.CORAL, 0.55), 1, 4)
	track.shadow_color = Color(UiTheme.CORAL, 0.2)
	track.shadow_size = 4
	_track.add_theme_stylebox_override("panel", track)
	add_child(_track)
	_ghost = _bar(Color(UiTheme.WHITE, 0.7))
	_fill = _bar(UiTheme.CORAL)
	_shine = _bar(Color(1.0, 0.85, 0.88, 0.45))


func _bar(color: Color) -> ColorRect:
	var r := HudKit.ignore(ColorRect.new()) as ColorRect
	r.color = color
	add_child(r)
	return r


## Canto de cima à esquerda em `at` e largura até `right`.
func place(at: Vector2, right: float) -> void:
	position = at
	_rest_y = at.y
	_w = maxf(80.0, right - at.x)
	size = Vector2(_w, 14.0 + BAR_H + 2.0)
	_name.position = Vector2(1, 0)
	_name.size = Vector2(_w - 2.0, 13)
	_track.position = Vector2(0, 14)
	_track.size = Vector2(_w, BAR_H + 2.0)
	for r: ColorRect in [_ghost, _fill, _shine]:
		r.position = Vector2(1, 15)
		r.size.y = BAR_H
	_shine.size.y = 1.0
	_layout_ticks()
	_shown = -1.0


## Borda de baixo da barra parada (sem o deslize da entrada): o rádio e o selo do poder ficam abaixo dela.
func bottom() -> float:
	return _rest_y + size.y


func _layout_ticks() -> void:
	var inner := _w - 2.0
	for tick: ColorRect in _ticks:
		var at := float(tick.get_meta(&"at", 0.5))
		tick.position = Vector2(1.0 + floorf(inner * at), 12)
		tick.size = Vector2(1, BAR_H + 6.0)


## Um quadro. Devolve true quando a barra aparece ou some (o rádio desce ou sobe junto).
func refresh(sim: Sim, delta: float) -> bool:
	var boss := sim.boss
	var active := boss != null and boss.state != SimBoss.State.DEAD
	var changed := false
	if active and boss != _ref:
		_appear(boss)
		changed = true
	elif not active and visible:
		visible = false
		_ref = null
		return true
	if not active:
		return changed
	var target := clampf(boss.hp / maxf(1.0, boss.max_hp), 0.0, 1.0)
	_fill_t = minf(1.0, _fill_t + delta / FILL_SECONDS)
	var shown := minf(target, ease(_fill_t, 0.4)) if _fill_t < 1.0 else target
	if shown < _shown - 0.0001 and _fill_t >= 1.0:
		_hold = 0.35
	if _hold > 0.0:
		_hold -= delta
	else:
		_ghost_v = move_toward(_ghost_v, shown, delta * 0.6)
	_ghost_v = maxf(_ghost_v, shown)
	var inner := _w - 2.0
	if not is_equal_approx(shown, _shown):
		_shown = shown
		_fill.size.x = floorf(inner * shown)
		_shine.size.x = _fill.size.x
	_ghost.size.x = floorf(inner * _ghost_v)
	if boss.state == SimBoss.State.DYING:
		modulate.a = maxf(0.0, modulate.a - delta * 1.5)
	return changed


func _appear(boss: SimBoss) -> void:
	_ref = boss
	_name.text = tr(String(boss.def.get("name_key", ""))).to_upper()
	for tick: ColorRect in _ticks:
		tick.queue_free()
	_ticks.clear()
	# Uma marca em cada limiar de etapa (until_hp entre 0 e 1): o jogador vê quando o chefe muda.
	for raw: Variant in boss.def.get("phases", []):
		var at := float((raw as Dictionary).get("until_hp", 0.0))
		if at <= 0.0 or at >= 1.0:
			continue
		var tick := HudKit.ignore(ColorRect.new()) as ColorRect
		tick.color = Color(UiTheme.WHITE, 0.85)
		tick.set_meta(&"at", at)
		add_child(tick)
		_ticks.append(tick)
	_layout_ticks()
	_fill_t = 1.0 if reduced else 0.0
	_ghost_v = 0.0
	_shown = -1.0
	_fill.size.x = 0.0
	visible = true
	modulate.a = 1.0
	if not reduced:
		var y := position.y
		position.y = y - 8.0
		modulate.a = 0.0
		var t := create_tween().set_parallel()
		t.tween_property(self, "position:y", y, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		t.tween_property(self, "modulate:a", 1.0, 0.25)
