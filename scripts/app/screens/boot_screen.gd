class_name BootScreen
extends Screen
## Tela de título (redesenho 1.6): o logo surge da água sobre o fundo abissal compartilhado, a Halcyon
## flutua num halo de luz e a única ação dourada (Jogar) fica na zona do polegar. Créditos é
## secundário e discreto; a versão fica no rodapé.
##
## O brilho que corre no logo é um shader barato no próprio rótulo (uma faixa diagonal a cada
## SHINE_PERIOD s); a nave flutua por código a 60 Hz, sem redesenhar nada além dela.

const CONTENT_MAX_WIDTH := 300.0
const SHIP_PATH := "res://assets/art/void/main_ship/base_full.png"
const ENGINE_PATH := "res://assets/art/void/main_ship/engine_base_powering.png"
const SHINE_PERIOD := 5.0
const LOGO_SPACING := 8
## Avanço médio das maiúsculas da Exo 2 em negrito, em fração do tamanho (para o logo caber na largura).
const CAPS_ADVANCE := 0.74
const SHINE_SHADER := """
shader_type canvas_item;
uniform float period = 5.0;
uniform vec4 shine : source_color = vec4(1.0, 0.97, 0.85, 1.0);
varying vec2 local;
void vertex() { local = VERTEX; }
void fragment() {
	vec4 c = COLOR;
	float t = mod(TIME, period) / period;
	float x = local.x * 0.004 + local.y * 0.006;
	float band = smoothstep(0.06, 0.0, abs(x - (t * 2.4 - 0.6)));
	COLOR = vec4(mix(c.rgb, shine.rgb, band * 0.85), c.a);
}
"""

var _logo: Label
var _logo_sub: Label
var _tagline: Label
var _ship: TextureRect
var _engine: TextureRect
var _halo: TextureRect
var _play: Button
var _credits: Button
var _version: Label
var _time: float = 0.0
var _ship_base := Vector2.ZERO
var _engine_frames: int = 1


func _build() -> void:
	_halo = TextureRect.new()
	_halo.texture = SpriteBank.generated("fx/glow_32")
	_halo.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_halo.modulate = Color(UiTheme.CYAN, 0.35)
	_halo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_halo.stretch_mode = TextureRect.STRETCH_SCALE
	_halo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_halo)
	_engine = _sprite(ENGINE_PATH)
	# O motor é uma tira de quadros 48x48: mostra um quadro por vez (chama animada).
	var strip := _engine.texture
	var atlas := AtlasTexture.new()
	atlas.atlas = strip
	atlas.region = SpriteBank.frame_rect(0, 48)
	_engine.texture = atlas
	_engine_frames = maxi(1, strip.get_width() / 48) if strip != null else 1
	_ship = _sprite(SHIP_PATH)
	_logo = UiTheme.heading("ATLANTIS", 38, UiTheme.WHITE)
	_logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_logo.add_theme_font_override("font", _tracked(LOGO_SPACING))
	_logo.add_theme_color_override("font_shadow_color", Color(UiTheme.CYAN, 0.55))
	_logo.add_theme_constant_override("shadow_outline_size", 14)
	var shine := ShaderMaterial.new()
	shine.shader = Shader.new()
	shine.shader.code = SHINE_SHADER
	shine.set_shader_parameter("period", SHINE_PERIOD)
	_logo.material = shine
	add_child(_logo)
	_logo_sub = UiTheme.heading("ASCENSION", 15, UiTheme.GOLD)
	_logo_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_logo_sub.add_theme_font_override("font", _tracked(9))
	add_child(_logo_sub)
	_tagline = UiTheme.label("", UiTheme.FONT_SIZE, UiTheme.TEXT_DIM, true)
	_tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_tagline)
	_play = Button.new()
	_play.name = "Play"
	UiTheme.style_primary(_play, 18)
	_play.pressed.connect(func() -> void:
		AudioManager.play_ui("kenney_ui_confirm")
		navigate.emit(&"hub"))
	add_child(_play)
	_credits = Button.new()
	_credits.name = "Credits"
	_credits.flat = false
	_credits.pressed.connect(func() -> void:
		AudioManager.play_ui("kenney_ui_click")
		navigate.emit(&"credits"))
	add_child(_credits)
	_version = UiTheme.label("", UiTheme.SMALL_SIZE, Color(UiTheme.TEXT_DIM, 0.7))
	_version.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_version)


func _sprite(path: String) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = SpriteBank.texture(path)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)
	return rect


## Fonte de título com espaço entre letras (o logo respira como uma marca, não como um rótulo).
static func _tracked(spacing: int) -> Font:
	var base := UiTheme.bold_font()
	var variation := FontVariation.new()
	variation.base_font = base if base != null else ThemeDB.fallback_font
	variation.spacing_glyph = spacing
	return variation


## Pelo controle a tela abre no Jogar.
func default_focus() -> Control:
	return _play


func on_show(_app: Node) -> void:
	_time = 0.0
	if UiFx.reduced():
		return
	# Entrada: o logo sobe da água e acende; a nave chega um pouco depois.
	for node: CanvasItem in [_logo, _logo_sub, _tagline]:
		node.modulate = Color(1, 1, 1, 0)
	var tween := create_tween()
	tween.tween_property(_logo, "modulate", Color.WHITE, 0.6).set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(_logo_sub, "modulate", Color.WHITE, 0.6).set_delay(0.25)
	tween.parallel().tween_property(_tagline, "modulate", Color.WHITE, 0.6).set_delay(0.5)


func refresh_texts() -> void:
	_tagline.text = tr("boot.tagline")
	_play.text = tr("boot.play").to_upper()
	_credits.text = tr("boot.credits")
	_version.text = tr("boot.dev_build") % String(ProjectSettings.get_setting("application/config/version"))
	relayout()


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_time += delta
	if UiFx.reduced():
		return
	var bob := Vector2(0.0, roundf(sin(_time * 1.6) * 3.0))
	_ship.position = _ship_base + bob
	_engine.position = _ship.position
	(_engine.texture as AtlasTexture).region = SpriteBank.frame_rect(int(_time * 12.0) % _engine_frames, 48)
	var pulse := 1.0 + 0.04 * sin(_time * 1.6)
	_halo.scale = Vector2(pulse, pulse)
	_halo.modulate.a = 0.3 + 0.08 * sin(_time * 1.6)


func _layout() -> void:
	if _play == null:
		return
	var width := minf(CONTENT_MAX_WIDTH, safe.size.x - 32.0)
	var left := floorf(safe.position.x + (safe.size.x - width) * 0.5)
	var cx := safe.position.x + safe.size.x * 0.5
	var landscape := safe.size.x > safe.size.y
	# Logo no terço de cima, no maior tamanho que cabe (8 letras + espaçamento).
	var logo_size := clampi(floori((width / 8.0 - LOGO_SPACING) / CAPS_ADVANCE), 22, 44)
	_logo.add_theme_font_size_override("font_size", logo_size)
	var top := safe.position.y + safe.size.y * (0.1 if not landscape else 0.06)
	_place(_logo, left, top, width)
	_place(_logo_sub, left, _logo.position.y + _logo.size.y, width)
	_place(_tagline, left, _logo_sub.position.y + _logo_sub.size.y + 10.0, width)
	# Botões na zona do polegar.
	_version.size = Vector2(safe.size.x, 0.0)
	_version.reset_size()
	_version.size.x = safe.size.x
	_version.position = Vector2(safe.position.x, safe.end.y - _version.size.y - 6.0)
	var play_w := minf(width, 280.0)
	_play.size = Vector2(play_w, 54.0)
	_credits.size = Vector2(minf(play_w * 0.6, 180.0), UiTheme.TOUCH_MIN)
	_credits.position = Vector2(floorf(cx - _credits.size.x * 0.5), _version.position.y - _credits.size.y - 14.0)
	_play.position = Vector2(floorf(cx - play_w * 0.5), _credits.position.y - _play.size.y - 12.0)
	# Nave no espaço entre o texto e os botões, em escala inteira (pixel art nítido).
	var gap_top := _tagline.position.y + _tagline.size.y + 8.0
	var gap := maxf(0.0, _play.position.y - gap_top - 8.0)
	var k := clampi(floori(minf(gap * 0.6, width) / 96.0), 1, 3)
	var ship_size := Vector2(48, 48) * k
	_ship_base = Vector2(floorf(cx - ship_size.x * 0.5), floorf(gap_top + (gap - ship_size.y) * 0.5))
	for rect: TextureRect in [_ship, _engine]:
		rect.size = ship_size
		rect.position = _ship_base
	var halo := ship_size * 3.0
	_halo.size = halo
	_halo.pivot_offset = halo * 0.5
	_halo.position = _ship_base + ship_size * 0.5 - halo * 0.5
	var show_ship := gap >= 48.0
	for node: CanvasItem in [_ship, _engine, _halo]:
		node.visible = show_ship


func _place(label: Label, left: float, y: float, width: float) -> void:
	# Rótulo com quebra: a altura mínima depende da largura, então a largura vem primeiro.
	label.size = Vector2(width, label.size.y)
	var lines := maxi(1, label.get_line_count())
	label.size = Vector2(width, lines * label.get_line_height() + (lines - 1) * 1.0)
	label.position = Vector2(left, floorf(y))


## Controles que precisam caber na área segura (testes de layout).
func layout_controls() -> Array[Control]:
	return [_logo, _logo_sub, _tagline, _play, _credits, _version]
