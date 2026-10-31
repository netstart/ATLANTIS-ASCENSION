class_name BootScreen
extends Screen
## Tela de abertura da Fase 0: título, lema, versão e acesso aos Créditos. Mostra o contorno da área
## de jogo (Playfield) para conferir o encaixe em cada aparelho. Vira o hub interativo no Vertical
## Slice (plano mestre 7.2).

const CONTENT_MAX_WIDTH := 260.0

var _background: TextureRect
var _content: VBoxContainer
var _title: Label
var _tagline: Label
var _play: Button
var _credits: Button
var _version: Label
## Contorno da área de jogo (só na Fase 0), acima do fundo e abaixo do conteúdo.
var _field_guide: ReferenceRect


func _build() -> void:
	_background = TextureRect.new()
	_background.texture = _gradient()
	_background.stretch_mode = TextureRect.STRETCH_SCALE
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_background)
	_field_guide = ReferenceRect.new()
	_field_guide.editor_only = false
	_field_guide.border_color = Color(UiTheme.TURQUOISE, 0.35)
	_field_guide.border_width = 1.0
	_field_guide.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_field_guide)
	_content = VBoxContainer.new()
	_content.alignment = BoxContainer.ALIGNMENT_CENTER
	_content.add_theme_constant_override("separation", 12)
	add_child(_content)
	_title = UiTheme.label("ATLANTIS\nASCENSION", UiTheme.TITLE_SIZE, UiTheme.GOLD)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content.add_child(_title)
	_tagline = UiTheme.label("", UiTheme.FONT_SIZE, UiTheme.TEXT, true)
	_tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content.add_child(_tagline)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 24)
	_content.add_child(gap)
	_play = Button.new()
	_play.name = "Play"
	_play.custom_minimum_size = Vector2(160, UiTheme.TOUCH_MIN + 8.0)
	_play.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_play.add_theme_font_size_override("font_size", UiTheme.HEADING_SIZE)
	_play.pressed.connect(func() -> void: navigate.emit(&"hub"))
	_content.add_child(_play)
	_credits = Button.new()
	_credits.name = "Credits"
	_credits.custom_minimum_size = Vector2(160, UiTheme.TOUCH_MIN)
	_credits.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_credits.pressed.connect(func() -> void: navigate.emit(&"credits"))
	_content.add_child(_credits)
	_version = UiTheme.label("", UiTheme.FONT_SIZE, UiTheme.TEXT_DIM)
	_version.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_version)


func refresh_texts() -> void:
	_tagline.text = tr("boot.tagline")
	_play.text = tr("boot.play")
	_credits.text = tr("boot.credits")
	_version.text = tr("boot.dev_build") % String(ProjectSettings.get_setting("application/config/version"))
	relayout()


func _layout() -> void:
	if _content == null:
		return
	var field: Rect2 = Playfield.layout(size, safe)["field"]
	_field_guide.position = field.position
	_field_guide.size = field.size
	var width := minf(CONTENT_MAX_WIDTH, safe.size.x - 32.0)
	_content.size = Vector2(width, 0.0)
	_content.reset_size()
	_content.position = Vector2(floorf(safe.position.x + (safe.size.x - width) * 0.5),
			floorf(safe.position.y + (safe.size.y - _content.size.y) * 0.45))
	_version.size = Vector2(safe.size.x, 0.0)
	_version.reset_size()
	_version.position = Vector2(safe.position.x, safe.end.y - _version.size.y - 8.0)
	_version.size.x = safe.size.x


func _gradient() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, UiTheme.ABYSS)
	gradient.set_color(1, UiTheme.DEEP_BLUE.lerp(UiTheme.TURQUOISE, 0.25))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0.5, 1.0)
	texture.fill_to = Vector2(0.5, 0.0)
	texture.width = 4
	texture.height = 256
	return texture


## Controles que precisam caber na área segura (testes de layout).
func layout_controls() -> Array[Control]:
	return [_title, _tagline, _play, _credits, _version]
