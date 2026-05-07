extends Node2D

signal spawn_now

var color: Color = Color.WHITE
var lifetime: float = 0.4
var elapsed: float = 0.0
var radius: float = 30.0

func setup(c: Color, pos: Vector2, time: float) -> void:
	color = c
	lifetime = maxf(time, 0.05)
	global_position = pos
	z_index = 10

func _process(delta: float) -> void:
	elapsed += delta
	queue_redraw()
	if elapsed >= lifetime:
		spawn_now.emit()
		queue_free()

func _draw() -> void:
	var t := clampf(elapsed / lifetime, 0.0, 1.0)
	var pulse := 1.0 + 0.35 * sin(t * TAU * 3.0)
	var r := radius * pulse
	var alpha := 0.35 + 0.6 * t
	var fill_col := Color(color.r, color.g, color.b, 0.18 * alpha)
	var outline_col := Color(color.r, color.g, color.b, alpha)
	draw_circle(Vector2.ZERO, r, fill_col)
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 32, outline_col, 3.0)
	draw_circle(Vector2.ZERO, 4.0, outline_col)
