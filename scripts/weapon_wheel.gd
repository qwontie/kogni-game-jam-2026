extends Control

@export var colors: Array[Color] = [Color.YELLOW, Color.GREEN, Color.RED, Color.BLUE]
@export var sectors: Array[TextureRect] = []

var current_index: int = 0

func _ready():
	hide()

func _process(_delta):
	if not visible:
		return
	if colors.is_empty() or sectors.is_empty():
		return
	# Split the WHOLE viewport into 4 quadrants by the 45° diagonals:
	# right -> 0 (Yellow), down -> 1 (Green), left -> 2 (Red), up -> 3 (Blue).
	var screen_size = get_viewport().get_visible_rect().size
	var mouse = get_viewport().get_mouse_position() - screen_size * 0.5
	if mouse == Vector2.ZERO:
		return
	var dx = mouse.x
	var dy = mouse.y
	var index: int
	if absf(dx) >= absf(dy):
		index = 0 if dx >= 0.0 else 2
	else:
		index = 1 if dy >= 0.0 else 3
	select_index(index)

func select_index(index: int) -> void:
	if colors.is_empty() or sectors.is_empty():
		return

	index = clampi(index, 0, mini(colors.size(), sectors.size()) - 1)
	if index == current_index:
		return

	current_index = index
	_highlight(current_index)

func _highlight(index: int):
	var sector_count := mini(colors.size(), sectors.size())
	for i in sector_count:
		if sectors[i] == null:
			continue
		sectors[i].modulate.a = 0.5 if i != index else 1.0

func open():
	var idx := colors.find(GameState.current_weapon_color)
	if idx >= 0:
		current_index = idx
	show()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_highlight(current_index)

func close():
	hide()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	return colors[current_index]

func select_from_arrow_key(keycode: Key) -> void:
	match keycode:
		KEY_RIGHT:
			select_index(0)
		KEY_DOWN:
			select_index(1)
		KEY_LEFT:
			select_index(2)
		KEY_UP:
			select_index(3)
