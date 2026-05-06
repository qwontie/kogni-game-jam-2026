extends HBoxContainer


func _ready():
	GameState.player_health_changed.connect(_on_player_health_changed)
	update_hearts()

func update_hearts():
	var hearts = get_children()
	for i in hearts.size():
		hearts[i].visible = i < GameState.player_health

func _on_player_health_changed(_health: int) -> void:
	update_hearts()

	
