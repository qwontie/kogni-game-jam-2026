extends CharacterBody2D

@export var speed: float = 150.0
@export var detection_radius: float = 300.0
@export var wander_speed_factor: float = 0.5 # Wanders slower than chasing
@export var enemy_textures: Array[Texture2D] = []
@export_group("Attachment")
@export var attach_damage_interval: float = 0.5
@export var attach_damage: int = 1
@export var attach_distance: float = 96.0
@export var detach_opposite_dot: float = -0.55

var player: CharacterBody2D = null
var wander_direction: Vector2 = Vector2.ZERO
var wander_timer: float = 0.0
var attached: bool = false
var attach_side_direction: Vector2 = Vector2.RIGHT
var attach_damage_timer: float = 0.0
@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func _ready():
	# Find the player using the group we created
	player = get_tree().get_first_node_in_group("player")
	_pick_random_texture()
	_pick_new_wander_direction()

func _physics_process(delta):
	if attached:
		_update_attached(delta)
		return

	if _can_see_player():
		# STATE: CHASE
		var direction = global_position.direction_to(player.global_position)
		velocity = direction * speed
	else:
		# STATE: WANDER
		wander_timer -= delta
		if wander_timer <= 0:
			_pick_new_wander_direction()
		
		velocity = wander_direction * (speed * wander_speed_factor)
	
	move_and_slide()
	_damage_player_on_contact()

func _can_see_player() -> bool:
	if player == null: return false
	# Calculate distance between enemy and player
	return global_position.distance_to(player.global_position) < detection_radius

func _pick_new_wander_direction():
	# Get a random angle and convert to a vector
	var random_angle = randf_range(0, 2 * PI)
	wander_direction = Vector2(cos(random_angle), sin(random_angle))
	# Stay in this direction for 1 to 3 seconds
	wander_timer = randf_range(1.0, 3.0)

func _pick_random_texture() -> void:
	if enemy_textures.is_empty():
		return
	sprite.texture = enemy_textures.pick_random()
	
func take_damage():
	if attached:
		return
	if player != null and player.has_method("reward_enemy_kill"):
		player.reward_enemy_kill()
	queue_free() 

func is_attached_to_player() -> bool:
	return attached

func try_detach_with_dash(dash_direction: Vector2) -> bool:
	if not attached or dash_direction == Vector2.ZERO:
		return false
	if dash_direction.normalized().dot(attach_side_direction) > detach_opposite_dot:
		return false
	_detach()
	return true

func _damage_player_on_contact() -> void:
	for i in get_slide_collision_count():
		var collider := get_slide_collision(i).get_collider()
		if collider != null and collider.is_in_group("player"):
			_attach_to_player(collider)
			return

func _attach_to_player(target: CharacterBody2D) -> void:
	if attached:
		return
	player = target
	attached = true
	velocity = Vector2.ZERO
	attach_side_direction = player.global_position.direction_to(global_position)
	if attach_side_direction == Vector2.ZERO:
		attach_side_direction = Vector2.RIGHT
	attach_side_direction = attach_side_direction.normalized()
	attach_damage_timer = 0.0
	collision_shape.set_deferred("disabled", true)
	_update_attached_position()

func _update_attached(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		_detach()
		return
	_update_attached_position()
	attach_damage_timer -= delta
	if attach_damage_timer <= 0.0:
		attach_damage_timer += attach_damage_interval
		if player.has_method("take_attached_damage"):
			player.take_attached_damage(attach_damage)
		elif player.has_method("take_damage"):
			player.take_damage(attach_damage)

func _update_attached_position() -> void:
	global_position = player.global_position + attach_side_direction * attach_distance

func _detach() -> void:
	attached = false
	collision_shape.set_deferred("disabled", false)
	velocity = attach_side_direction * speed
	wander_direction = attach_side_direction
	wander_timer = 0.35
