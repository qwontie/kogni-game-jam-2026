extends CanvasLayer


func _input(event):
	if Input.is_action_just_pressed("ui_focus_next"):  # TAB
		$WeaponWheel.open()
	if Input.is_action_just_released("ui_focus_next"):
		var chosen = $WeaponWheel.close()
		GameState.current_weapon_color = chosen
		
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
