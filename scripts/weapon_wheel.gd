extends Control

@export var colors: Array[Color] = [Color.YELLOW, Color.GREEN, Color.RED, Color.BLUE]
@export var sectors: Array[TextureRect] = []

var current_index: int = 0
var center: Vector2 = Vector2.ZERO

func _ready():
	center = _calculate_center()
	hide()

func _process(_delta):
	if not visible:
		return
	if colors.is_empty() or sectors.is_empty():
		return
	var mouse = get_local_mouse_position() - center
	if mouse.length() < 48.0:
		return
	var angle = atan2(mouse.y, mouse.x)		
	var sector_size = TAU / colors.size()
	var index = int((angle + TAU) / sector_size) % colors.size()
	select_index(index)

func _calculate_center() -> Vector2:
	if sectors.is_empty():
		return size / 2.0

	var total := Vector2.ZERO
	var count := 0
	for sector in sectors:
		if sector == null:
			continue
		total += sector.position + sector.size / 2.0
		count += 1
	if count == 0:
		return size / 2.0
	return total / count

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
	center = _calculate_center()
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
