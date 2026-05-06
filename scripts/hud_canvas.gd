extends CanvasLayer


func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _input(event):
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
