extends Control

@export var colors: Array[Color] = [Color.YELLOW, Color.GREEN, Color.RED, Color.BLUE]
@export var sectors: Array[TextureRect] = []

var current_index: int = 0
var center: Vector2

func _ready():
	center = size / 2
	hide()

func _process(_delta):
	if not visible:
		return
	var mouse = get_local_mouse_position() - center
	if mouse.length() < 20:
		return
	var angle = atan2(mouse.y, mouse.x)
	var sector_size = TAU / colors.size()
	var index = int((angle + TAU) / sector_size) % colors.size()
	if index != current_index:
		current_index = index
		_highlight(index)

func _highlight(index: int):
	for i in sectors.size():
		sectors[i].modulate.a = 0.5 if i != index else 1.0

func open():
	center = size / 2
	show()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func close():
	hide()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	return colors[current_index]
