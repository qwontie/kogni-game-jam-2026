extends CanvasLayer

const MAIN_MENU_SCENE := "res://scenes/MainMenu.tscn"

var score_label: Label
var death_overlay: Control
var death_score_label: Label

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_build_score_label()
	_build_death_overlay()
	GameState.score_changed.connect(_on_score_changed)
	GameState.player_died.connect(_on_player_died)
	_on_score_changed(GameState.score, GameState.total_score)
	if GameState.is_dead:
		_on_player_died()


func _input(event):
	if GameState.is_dead:
		return

	if event.is_action_pressed("ui_focus_next"):  # TAB
		$WeaponWheel.open()
		get_viewport().set_input_as_handled()
		return

	if event.is_action_released("ui_focus_next"):
		var chosen = $WeaponWheel.close()
		GameState.current_weapon_color = chosen
		get_viewport().set_input_as_handled()
		return

	if $WeaponWheel.visible and event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN:
				$WeaponWheel.select_from_arrow_key(event.keycode)
				get_viewport().set_input_as_handled()


func _build_score_label() -> void:
	score_label = Label.new()
	score_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	score_label.offset_left = -380.0
	score_label.offset_right = -24.0
	score_label.offset_top = 24.0
	score_label.offset_bottom = 80.0
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	score_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	score_label.add_theme_font_size_override("font_size", 30)
	score_label.add_theme_color_override("font_color", Color(0.07, 0.07, 0.08))
	score_label.add_theme_color_override("font_outline_color", Color(1, 1, 1, 0.85))
	score_label.add_theme_constant_override("outline_size", 6)
	score_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(score_label)


func _build_death_overlay() -> void:
	death_overlay = Control.new()
	death_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	death_overlay.visible = false
	death_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(death_overlay)

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.05, 0.04, 0.06, 0.6)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	death_overlay.add_child(bg)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -280.0
	panel.offset_right = 280.0
	panel.offset_top = -220.0
	panel.offset_bottom = 220.0
	panel.add_theme_stylebox_override("panel", _panel_style())
	death_overlay.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 36)
	margin.add_theme_constant_override("margin_right", 36)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_bottom", 28)
	panel.add_child(margin)

	var stack := VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 18)
	margin.add_child(stack)

	var title := Label.new()
	title.text = "YOU DIED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 56)
	title.add_theme_color_override("font_color", Color(0.92, 0.27, 0.27))
	stack.add_child(title)

	death_score_label = Label.new()
	death_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	death_score_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	death_score_label.add_theme_font_size_override("font_size", 26)
	death_score_label.add_theme_color_override("font_color", Color(0.07, 0.07, 0.08))
	stack.add_child(death_score_label)

	var restart_btn := Button.new()
	restart_btn.text = "RESTART"
	restart_btn.custom_minimum_size = Vector2(0, 56)
	restart_btn.add_theme_font_size_override("font_size", 26)
	restart_btn.pressed.connect(_on_restart_pressed)
	stack.add_child(restart_btn)

	var menu_btn := Button.new()
	menu_btn.text = "MAIN MENU"
	menu_btn.custom_minimum_size = Vector2(0, 56)
	menu_btn.add_theme_font_size_override("font_size", 26)
	menu_btn.pressed.connect(_on_menu_pressed)
	stack.add_child(menu_btn)


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.98, 0.94, 0.84)
	style.border_color = Color(0.08, 0.06, 0.06)
	style.set_border_width_all(5)
	style.corner_radius_top_left = 24
	style.corner_radius_top_right = 18
	style.corner_radius_bottom_left = 18
	style.corner_radius_bottom_right = 24
	style.shadow_color = Color(0.05, 0.04, 0.04, 0.5)
	style.shadow_size = 14
	style.shadow_offset = Vector2(6, 8)
	return style


func _on_score_changed(score: int, total: int) -> void:
	if score_label != null:
		score_label.text = "Kills: %d   Total: %d" % [score, total]


func _on_player_died() -> void:
	if death_score_label != null:
		death_score_label.text = "Bugs squashed this run: %d\nLifetime total: %d" % [GameState.score, GameState.total_score]
	if death_overlay != null:
		death_overlay.visible = true
	get_tree().paused = true


func _on_restart_pressed() -> void:
	get_tree().paused = false
	GameState.restart_run()
	get_tree().reload_current_scene()


func _on_menu_pressed() -> void:
	get_tree().paused = false
	GameState.restart_run()
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)
