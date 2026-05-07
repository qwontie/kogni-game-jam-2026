extends Control

@export var heart_texture: Texture2D
@export var bar_width: float = 280.0
@export var bar_height: float = 38.0
@export var heart_size: float = 56.0
# v = real^k. With k=1.6 the last 10% visible bar ≈ the last 25% of real HP,
# so the final sliver "lasts longer" — clutch moments feel earned.
@export var visual_curve_exponent: float = 1.6

var current_visual: float = 1.0
var target_visual: float = 1.0

func _ready() -> void:
	GameState.player_health_changed.connect(_on_health_changed)
	target_visual = _to_visual(GameState.player_health / GameState.max_health)
	current_visual = target_visual
	queue_redraw()

func _process(delta: float) -> void:
	if not is_equal_approx(current_visual, target_visual):
		current_visual = lerpf(current_visual, target_visual, clampf(delta * 8.0, 0.0, 1.0))
		if absf(current_visual - target_visual) < 0.001:
			current_visual = target_visual
		queue_redraw()

func _on_health_changed(hp: float, max_hp: float) -> void:
	target_visual = _to_visual(clampf(hp / max_hp, 0.0, 1.0))

func _to_visual(real_ratio: float) -> float:
	return pow(clampf(real_ratio, 0.0, 1.0), visual_curve_exponent)

func _draw() -> void:
	var pad := 12.0
	var heart_rect := Rect2(Vector2(pad, pad), Vector2(heart_size, heart_size))
	if heart_texture != null:
		draw_texture_rect(heart_texture, heart_rect, false)

	var bar_x := heart_rect.position.x + heart_size + 16.0
	var bar_y := pad + (heart_size - bar_height) * 0.5
	var bar_rect := Rect2(Vector2(bar_x, bar_y), Vector2(bar_width, bar_height))

	# Paper-like background
	draw_rect(bar_rect.grow(2.0), Color(1, 1, 1, 0.08), true)

	var fill_w := bar_rect.size.x * current_visual
	if fill_w > 1.0:
		var fill_rect := Rect2(
			bar_rect.position + Vector2(2.0, 2.0),
			Vector2(maxf(fill_w - 4.0, 0.0), bar_rect.size.y - 4.0)
		)
		_draw_doodle_fill(fill_rect, _hp_color(current_visual))

	# Sketchy outline last so it sits on top.
	_draw_doodle_rect(bar_rect, Color(0.07, 0.07, 0.08), 2.5, 3)

func _hp_color(v: float) -> Color:
	if v > 0.55:
		return Color(0.42, 0.82, 0.34)
	elif v > 0.25:
		return Color(0.96, 0.74, 0.22)
	else:
		return Color(0.92, 0.27, 0.27)

func _draw_doodle_rect(rect: Rect2, color: Color, width: float, passes: int) -> void:
	var seed_v := 1337
	for p in passes:
		var jitter := 1.4 + p * 0.5
		var pts := PackedVector2Array()
		var corners := [
			rect.position,
			Vector2(rect.position.x + rect.size.x, rect.position.y),
			rect.position + rect.size,
			Vector2(rect.position.x, rect.position.y + rect.size.y),
			rect.position
		]
		var steps := 14
		for i in range(corners.size() - 1):
			var a: Vector2 = corners[i]
			var b: Vector2 = corners[i + 1]
			for s in steps:
				var t := float(s) / float(steps)
				var pos := a.lerp(b, t)
				pos += Vector2(
					_pseudo(seed_v + p * 100 + i * 30 + s) * jitter,
					_pseudo(seed_v + p * 100 + i * 30 + s + 999) * jitter
				)
				pts.append(pos)
		pts.append(pts[0])
		draw_polyline(pts, color, width, true)

func _draw_doodle_fill(rect: Rect2, color: Color) -> void:
	draw_rect(rect, Color(color.r, color.g, color.b, 0.55), true)
	var hatch_color := Color(color.r * 0.55, color.g * 0.55, color.b * 0.55, 0.85)
	var step := 7.0
	var x := rect.position.x + 2.0
	var x_end := rect.position.x + rect.size.x - 2.0
	while x < x_end:
		var jx := x + _pseudo(int(x * 7.0)) * 0.8
		var y0 := rect.position.y + 3.0
		var y1 := rect.position.y + rect.size.y - 3.0
		draw_line(Vector2(jx, y0), Vector2(jx + 2.0, y1), hatch_color, 1.2, true)
		x += step

func _pseudo(n: int) -> float:
	var v := sin(float(n) * 12.9898) * 43758.5453
	return (v - floor(v)) * 2.0 - 1.0
