class_name ScreenFx
extends Control
## Acabamento sobre o campo de jogo (.ai/06-pesquisa-efeitos-visuais.md): vinheta, borda de perigo
## com o casco no fim, clarão de bomba/chefe e onda de choque que distorce a imagem. Fica dentro do
## recorte do campo, acima do mundo e abaixo do HUD. Só visual.
## "Reduzir flashes" limita o clarão a 30%; a onda de choque lê a tela, então só existe em qualidade
## Média ou Alta e só fica visível enquanto corre (fora disso não custa nada).

const WAVE_TIME := 0.55
const FLASH_DECAY := 4.5

var reduce_flashes: bool = false
var fx_level: int = 2

var _grade: ColorRect
var _grade_mat: ShaderMaterial
var _wave: ColorRect
var _wave_mat: ShaderMaterial
var _flash: float = 0.0
var _danger: float = 0.0
var _danger_target: float = 0.0
var _wave_t: float = -1.0
var _wave_strength: float = 0.02
var _time: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_wave = ColorRect.new()
	_wave.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wave.set_anchors_preset(Control.PRESET_FULL_RECT)
	_wave_mat = ShaderMaterial.new()
	_wave_mat.shader = load("res://shaders/shockwave.gdshader") as Shader
	_wave.material = _wave_mat
	_wave.visible = false
	add_child(_wave)
	_grade = ColorRect.new()
	_grade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_grade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_grade_mat = ShaderMaterial.new()
	_grade_mat.shader = load("res://shaders/field_grade.gdshader") as Shader
	_grade_mat.set_shader_parameter("vignette", 0.18 if fx_level == 0 else 0.26)
	_grade.material = _grade_mat
	add_child(_grade)


## Clarão de tela inteira (0..1), na cor pedida.
func flash(amount: float, color: Color = Color(1, 1, 1)) -> void:
	var cap := 0.3 if reduce_flashes else 1.0
	_flash = maxf(_flash, minf(amount, cap))
	_grade_mat.set_shader_parameter("flash_color", color)


## Onda de choque saindo de `at` (coordenadas do campo).
func shockwave(at: Vector2, strength: float = 0.02) -> void:
	if fx_level < 1 or size.x <= 0.0:
		return
	_wave_t = 0.0
	_wave_strength = strength * (0.5 if reduce_flashes else 1.0)
	_wave_mat.set_shader_parameter("center", at / Playfield.FIELD)
	_wave_mat.set_shader_parameter("aspect", Playfield.FIELD.x / Playfield.FIELD.y)
	_wave.visible = true


## Perigo (0..1): casco no último ponto pulsa a borda em vermelho.
func set_danger(value: float) -> void:
	_danger_target = value


func advance(delta: float) -> void:
	_time += delta
	_flash = maxf(0.0, _flash - FLASH_DECAY * delta * maxf(0.4, _flash))
	_danger = move_toward(_danger, _danger_target, delta * 2.0)
	var pulse := _danger * (0.55 + 0.45 * sin(_time * 6.0)) if not reduce_flashes else _danger * 0.6
	_grade_mat.set_shader_parameter("flash", _flash)
	_grade_mat.set_shader_parameter("danger", pulse)
	if _wave_t >= 0.0:
		_wave_t += delta
		var u := _wave_t / WAVE_TIME
		if u >= 1.0:
			_wave_t = -1.0
			_wave.visible = false
		else:
			_wave_mat.set_shader_parameter("radius", (1.0 - (1.0 - u) * (1.0 - u)) * 0.9)
			_wave_mat.set_shader_parameter("strength", _wave_strength * (1.0 - u))
			_wave_mat.set_shader_parameter("width", 0.05 + 0.06 * u)
