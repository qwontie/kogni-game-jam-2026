extends CharacterBody2D

@export var speed: float = 150.0
@export var detection_radius: float = 300.0
@export var wander_speed_factor: float = 0.5 # Wanders slower than chasing

var player: CharacterBody2D = null
var wander_direction: Vector2 = Vector2.ZERO
var wander_timer: float = 0.0

func _ready():
	# Find the player using the group we created
	player = get_tree().get_first_node_in_group("Player")
	_pick_new_wander_direction()

func _physics_process(delta):
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
