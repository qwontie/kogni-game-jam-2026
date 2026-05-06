extends HBoxContainer


func _ready():
	update_hearts()

func update_hearts():
	var hearts = get_children()
	for i in hearts.size():
		hearts[i].visible = i < GameState.player_health


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
	
