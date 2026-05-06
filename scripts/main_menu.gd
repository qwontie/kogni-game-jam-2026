extends Control

const GAME_SCENE := "res://scenes/Main.tscn"
const MENU_SHADER := preload("res://shaders/painted_stroop_menu.gdshader")
const TRANSITION_SHADER := preload("res://shaders/stroop_melt_transition.gdshader")
const PLAYER_TEXTURE := preload("res://assets/stroopy.png")
const ENEMY_RED := preload("res://assets/enemy_red.png")
const ENEMY_BLUE := preload("res://assets/enemy_blue.png")
const ENEMY_YELLOW := preload("res://assets/enemy_yellow.png")
const ENEMY_GREEN := preload("res://assets/enemy_green.png")

const INK_BLACK := Color(0.08, 0.06, 0.06)
const PAPER_CREAM := Color(0.98, 0.94, 0.84)
const PAPER_DEEP := Color(0.93, 0.86, 0.72)
const STROOP_RED := Color(0.90, 0.20, 0.24)
const STROOP_BLUE := Color(0.13, 0.50, 0.90)
const STROOP_YELLOW := Color(0.95, 0.74, 0.18)
const STROOP_GREEN := Color(0.28, 0.66, 0.32)

var resolutions: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
]

var transition_material: ShaderMaterial
var settings_panel: PanelContainer
var fullscreen_check: CheckBox
var resolution_option: OptionButton
var transitioning := false

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_build_scene()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and settings_panel.visible:
		settings_panel.hide()

func _build_scene() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var background := ColorRect.new()
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var background_material := ShaderMaterial.new()
	background_material.shader = MENU_SHADER
	background.material = background_material
	add_child(background)

	_build_floating_doodles()

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	# Hand-drawn paper card behind the menu so content reads against the swirls.
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(560, 720)
	card.add_theme_stylebox_override("panel", _paper_card_style())
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	center.add_child(card)

	var card_margin := MarginContainer.new()
	card_margin.add_theme_constant_override("margin_left", 44)
	card_margin.add_theme_constant_override("margin_right", 44)
	card_margin.add_theme_constant_override("margin_top", 36)
	card_margin.add_theme_constant_override("margin_bottom", 36)
	card.add_child(card_margin)

	var stack := VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 18)
	card_margin.add_child(stack)

	var icon_holder := CenterContainer.new()
	icon_holder.custom_minimum_size = Vector2(0, 170)
	stack.add_child(icon_holder)

	var player_icon := TextureRect.new()
	player_icon.texture = PLAYER_TEXTURE
	player_icon.custom_minimum_size = Vector2(160, 160)
	player_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	player_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	player_icon.pivot_offset = Vector2(80, 80)
	icon_holder.add_child(player_icon)

	var title := RichTextLabel.new()
	title.bbcode_enabled = true
	title.fit_content = true
	title.scroll_active = false
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.custom_minimum_size = Vector2(560, 0)
	title.add_theme_font_size_override("normal_font_size", 78)
	title.add_theme_font_size_override("bold_font_size", 78)
	title.add_theme_color_override("default_color", INK_BLACK)
	stack.add_child(title)
	_init_title_cycle(title, "STROOPY")

	var subtitle := Label.new()
	subtitle.text = "Read the word - shoot bugs that match its MEANING\nusing a weapon in the word's COLOR.\nWrong shots hurt. Mismatched bugs heal on touch."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.add_theme_font_size_override("font_size", 18)
	subtitle.add_theme_color_override("font_color", Color(0.20, 0.16, 0.14))
	stack.add_child(subtitle)

	var separator := Control.new()
	separator.custom_minimum_size = Vector2(0, 8)
	stack.add_child(separator)

	var buttons := VBoxContainer.new()
	buttons.custom_minimum_size = Vector2(420, 0)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 14)
	stack.add_child(buttons)

	var play_button := _make_menu_button("PLAY", STROOP_RED)
	play_button.pressed.connect(_start_game)
	buttons.add_child(play_button)

	var settings_button := _make_menu_button("SETTINGS", STROOP_BLUE)
	settings_button.pressed.connect(_toggle_settings)
	buttons.add_child(settings_button)

	var quit_button := _make_menu_button("QUIT", STROOP_YELLOW)
	quit_button.pressed.connect(get_tree().quit)
	buttons.add_child(quit_button)

	_build_settings_panel()
	_build_transition_overlay()

const TITLE_PALETTE := [STROOP_RED, STROOP_BLUE, STROOP_YELLOW, STROOP_GREEN]
const TITLE_CYCLE_SPEED := 0.18  # palette steps per second
const TITLE_REFRESH_INTERVAL := 0.06

var _title_label: RichTextLabel
var _title_text := ""
var _title_phases: PackedFloat32Array = PackedFloat32Array()
var _title_time := 0.0
var _title_refresh_accum := 0.0

func _init_title_cycle(label: RichTextLabel, text: String) -> void:
	_title_label = label
	_title_text = text
	_title_phases = PackedFloat32Array()
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in text.length():
		# Stagger letters along the palette plus a small random jitter.
		_title_phases.append(float(i) * 0.35 + rng.randf_range(-0.12, 0.12))
	_refresh_title_colors()

func _palette_color_at(phase: float) -> Color:
	var n := TITLE_PALETTE.size()
	var p := fposmod(phase, float(n))
	var idx := int(floor(p))
	var frac := p - float(idx)
	# Smooth ease so transitions linger on the pure colours, not the mid-blend.
	frac = smoothstep(0.0, 1.0, frac)
	return TITLE_PALETTE[idx].lerp(TITLE_PALETTE[(idx + 1) % n], frac)

func _refresh_title_colors() -> void:
	var out := "[center]"
	for i in _title_text.length():
		var ch := _title_text[i]
		if ch == " ":
			out += " "
			continue
		var c := _palette_color_at(_title_time * TITLE_CYCLE_SPEED + _title_phases[i])
		out += "[color=#%s][b]%s[/b][/color]" % [c.to_html(false), ch]
	out += "[/center]"
	_title_label.text = out

var _bacteria: Array = []  # [{node, vel}]

func _build_floating_doodles() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var specs := [
		{"tex": ENEMY_RED,    "size": 110},
		{"tex": ENEMY_BLUE,   "size": 90},
		{"tex": ENEMY_YELLOW, "size": 96},
		{"tex": ENEMY_GREEN,  "size": 104},
	]
	var viewport := get_viewport_rect().size
	for spec in specs:
		var rect := TextureRect.new()
		rect.texture = spec["tex"]
		rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var s: float = spec["size"]
		rect.size = Vector2(s, s)
		rect.pivot_offset = rect.size * 0.5
		rect.modulate = Color(1, 1, 1, 0.42)
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rect.position = Vector2(
			rng.randf_range(0.0, max(0.0, viewport.x - s)),
			rng.randf_range(0.0, max(0.0, viewport.y - s))
		)
		var angle := rng.randf_range(0.0, TAU)
		var speed := rng.randf_range(60.0, 110.0)
		var vel := Vector2(cos(angle), sin(angle)) * speed
		add_child(rect)
		_bacteria.append({"node": rect, "vel": vel})

func _process(delta: float) -> void:
	if _title_label != null:
		_title_time += delta
		_title_refresh_accum += delta
		if _title_refresh_accum >= TITLE_REFRESH_INTERVAL:
			_title_refresh_accum = 0.0
			_refresh_title_colors()
	if _bacteria.is_empty():
		return
	var viewport := get_viewport_rect().size
	for b in _bacteria:
		var rect: TextureRect = b["node"]
		var vel: Vector2 = b["vel"]
		rect.position += vel * delta
		var max_x := viewport.x - rect.size.x
		var max_y := viewport.y - rect.size.y
		if rect.position.x <= 0.0 and vel.x < 0.0:
			vel.x = -vel.x
			rect.position.x = 0.0
		elif rect.position.x >= max_x and vel.x > 0.0:
			vel.x = -vel.x
			rect.position.x = max_x
		if rect.position.y <= 0.0 and vel.y < 0.0:
			vel.y = -vel.y
			rect.position.y = 0.0
		elif rect.position.y >= max_y and vel.y > 0.0:
			vel.y = -vel.y
			rect.position.y = max_y
		b["vel"] = vel

func _make_menu_button(text: String, accent: Color) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(420, 72)
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_size_override("font_size", 30)
	button.add_theme_stylebox_override("normal", _ink_button_style(PAPER_CREAM, INK_BLACK, 4))
	button.add_theme_stylebox_override("hover", _ink_button_style(accent.lerp(PAPER_CREAM, 0.55), INK_BLACK, 5))
	button.add_theme_stylebox_override("pressed", _ink_button_style(accent.lerp(PAPER_CREAM, 0.25), INK_BLACK, 5))
	button.add_theme_stylebox_override("focus", _ink_button_style(Color(0, 0, 0, 0), accent, 5))
	button.add_theme_color_override("font_color", INK_BLACK)
	button.add_theme_color_override("font_hover_color", INK_BLACK)
	button.add_theme_color_override("font_pressed_color", INK_BLACK)
	button.add_theme_color_override("font_focus_color", INK_BLACK)
	return button

func _ink_button_style(bg: Color, border: Color, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(width)
	# Slightly asymmetric corner radii give a hand-drawn wobble.
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 22
	style.corner_radius_bottom_left = 24
	style.corner_radius_bottom_right = 12
	style.shadow_color = Color(0.05, 0.04, 0.04, 0.55)
	style.shadow_size = 6
	style.shadow_offset = Vector2(4, 5)
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style

func _paper_card_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = PAPER_CREAM
	style.border_color = INK_BLACK
	style.set_border_width_all(5)
	style.corner_radius_top_left = 28
	style.corner_radius_top_right = 18
	style.corner_radius_bottom_left = 22
	style.corner_radius_bottom_right = 32
	style.shadow_color = Color(0.05, 0.04, 0.04, 0.42)
	style.shadow_size = 18
	style.shadow_offset = Vector2(8, 12)
	style.content_margin_left = 0
	style.content_margin_right = 0
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	return style

func _build_settings_panel() -> void:
	settings_panel = PanelContainer.new()
	settings_panel.visible = false
	settings_panel.set_anchors_preset(Control.PRESET_CENTER)
	settings_panel.offset_left = -240.0
	settings_panel.offset_top = -160.0
	settings_panel.offset_right = 240.0
	settings_panel.offset_bottom = 160.0
	settings_panel.add_theme_stylebox_override("panel", _paper_card_style())
	add_child(settings_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_bottom", 22)
	settings_panel.add_child(margin)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 14)
	margin.add_child(stack)

	var title := Label.new()
	title.text = "SETTINGS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", INK_BLACK)
	stack.add_child(title)

	fullscreen_check = CheckBox.new()
	fullscreen_check.text = "Fullscreen"
	fullscreen_check.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	fullscreen_check.add_theme_color_override("font_color", INK_BLACK)
	fullscreen_check.add_theme_color_override("font_hover_color", INK_BLACK)
	fullscreen_check.toggled.connect(_set_fullscreen)
	stack.add_child(fullscreen_check)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	stack.add_child(row)

	var resolution_label := Label.new()
	resolution_label.text = "Resolution"
	resolution_label.custom_minimum_size = Vector2(130, 0)
	resolution_label.add_theme_color_override("font_color", INK_BLACK)
	row.add_child(resolution_label)

	resolution_option = OptionButton.new()
	resolution_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for resolution in resolutions:
		resolution_option.add_item("%dx%d" % [resolution.x, resolution.y])
	resolution_option.selected = _closest_resolution_index(DisplayServer.window_get_size())
	resolution_option.item_selected.connect(_set_resolution)
	row.add_child(resolution_option)

	var close_button := _make_menu_button("CLOSE", STROOP_GREEN)
	close_button.custom_minimum_size = Vector2(0, 56)
	close_button.pressed.connect(settings_panel.hide)
	stack.add_child(close_button)

func _build_transition_overlay() -> void:
	var transition := ColorRect.new()
	transition.name = "TransitionOverlay"
	transition.set_anchors_preset(Control.PRESET_FULL_RECT)
	transition.mouse_filter = Control.MOUSE_FILTER_IGNORE
	transition.visible = false
	transition_material = ShaderMaterial.new()
	transition_material.shader = TRANSITION_SHADER
	transition_material.set_shader_parameter("progress", 0.0)
	transition.material = transition_material
	add_child(transition)

func _toggle_settings() -> void:
	settings_panel.visible = not settings_panel.visible

func _set_fullscreen(enabled: bool) -> void:
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if enabled else DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(mode)

func _set_resolution(index: int) -> void:
	if index < 0 or index >= resolutions.size():
		return
	DisplayServer.window_set_size(resolutions[index])
	_center_window()

func _closest_resolution_index(size: Vector2i) -> int:
	var closest := 0
	var closest_distance := INF
	for i: int in range(resolutions.size()):
		var resolution: Vector2i = resolutions[i]
		var distance := Vector2(size - resolution).length_squared()
		if distance < closest_distance:
			closest = i
			closest_distance = distance
	return closest

func _center_window() -> void:
	var screen := DisplayServer.window_get_current_screen()
	var screen_rect := DisplayServer.screen_get_usable_rect(screen)
	DisplayServer.window_set_position(screen_rect.position + (screen_rect.size - DisplayServer.window_get_size()) / 2)

func _start_game() -> void:
	if transitioning:
		return
	transitioning = true
	settings_panel.hide()
	var transition := $TransitionOverlay as ColorRect
	transition.visible = true
	var tween := create_tween()
	tween.tween_method(_set_transition_progress, 0.0, 1.0, 0.78).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_callback(_change_to_game)

func _set_transition_progress(value: float) -> void:
	transition_material.set_shader_parameter("progress", value)

func _change_to_game() -> void:
	get_tree().change_scene_to_file(GAME_SCENE)
