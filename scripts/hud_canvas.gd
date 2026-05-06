extends CanvasLayer


func _input(_event):
	if Input.is_action_just_pressed("ui_focus_next"):  # TAB
		$WeaponWheel.open()
	if Input.is_action_just_released("ui_focus_next"):
		var chosen = $WeaponWheel.close()
		GameState.current_weapon_color = chosen
