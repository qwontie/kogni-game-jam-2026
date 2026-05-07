extends ColorRect

@export var slow_factor: float = 0.22
@export var duration: float = 1.8

var remaining: float = 0.0
var shader_mat: ShaderMaterial

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	shader_mat = material as ShaderMaterial
	if shader_mat:
		shader_mat.set_shader_parameter("intensity", 0.0)
	visible = false
	GameState.stroop_changed.connect(_on_stroop)
	if GameState.has_stroop:
		_on_stroop(GameState.last_stroop_text, GameState.last_stroop_color)

func _on_stroop(_text: String, _color: Color) -> void:
	remaining = duration
	visible = true
	GameState.is_peace = true

func _process(delta: float) -> void:
	if remaining <= 0.0:
		if not is_equal_approx(Engine.time_scale, 1.0):
			Engine.time_scale = 1.0
		if visible:
			visible = false
		if GameState.is_peace:
			GameState.is_peace = false
		return
	var ts: float = max(Engine.time_scale, 0.0001)
	var real_dt: float = delta / ts
	remaining -= real_dt
	var t: float = clampf(remaining / duration, 0.0, 1.0)
	var ease_t: float = t * t
	Engine.time_scale = lerpf(1.0, slow_factor, ease_t)
	if shader_mat:
		shader_mat.set_shader_parameter("intensity", ease_t)
