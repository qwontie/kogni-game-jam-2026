extends Camera2D

@export var target_group: StringName = &"player"
@export var follow_speed: float = 18.0
@export var snap_to_pixels: bool = true

var target: Node2D

func _ready() -> void:
	make_current()
	_find_target()
	if target != null:
		global_position = _snap_position(target.global_position)

func _physics_process(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		_find_target()
		if target == null:
			return

	var follow_weight := 1.0 - exp(-follow_speed * delta)
	global_position = global_position.lerp(target.global_position, follow_weight)
	global_position = _snap_position(global_position)

func _find_target() -> void:
	target = get_tree().get_first_node_in_group(target_group) as Node2D

func _snap_position(value: Vector2) -> Vector2:
	return value.round() if snap_to_pixels else value
