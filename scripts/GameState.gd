extends Node

var current_weapon_color: Color = Color.RED
var player_health: int = 5

signal stroop_changed(text: String, color: Color)

const COLOR_NAMES = ["RED", "GREEN", "BLUE", "YELLOW"]
const COLOR_VALUES = [Color.RED, Color.GREEN, Color.BLUE, Color.YELLOW]
	
var stroop_timer: float = 10.0
var stroop_interval: float = 10.0

func _process(delta):
	stroop_timer -= delta
	if stroop_timer <= 0:
		stroop_timer = stroop_interval
		_emit_stroop()

func _emit_stroop():
	var text_index = randi() % COLOR_NAMES.size()
	var color_index = randi() % COLOR_VALUES.size()
	# гарантируем что цвет текста != смысл слова
	while color_index == text_index:
		color_index = randi() % COLOR_VALUES.size()
	stroop_changed.emit(COLOR_NAMES[text_index], COLOR_VALUES[color_index])
