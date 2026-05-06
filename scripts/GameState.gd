extends Node

# --- STROOP VARIABLES ---
var current_weapon_color: Color = Color.RED
var player_health: int = 5
signal stroop_changed(text: String, color: Color)
signal player_health_changed(health: int)

const COLOR_NAMES = ["RED", "GREEN", "BLUE", "YELLOW"]
const COLOR_VALUES = [Color.RED, Color.GREEN, Color.BLUE, Color.YELLOW]
	
var stroop_timer: float = 10.0
var stroop_interval: float = 10.0

# --- SPAWNER VARIABLES ---
@export_group("Spawner Settings")
@export var enemy_scene: PackedScene # Drag your Enemy.tscn here in the Inspector
@export var spawn_interval: float = 3.0
@export var min_distance: float = 400.0
@export var max_distance: float = 800.0

var spawn_timer: float = 0.0
var player_ref: Node2D = null

func _ready():
	# Find the player once at the start
	player_ref = get_tree().get_first_node_in_group("player")
	spawn_timer = spawn_interval # Start the timer

func _process(delta):
	# 1. Stroop Logic
	stroop_timer -= delta
	if stroop_timer <= 0:
		stroop_timer = stroop_interval
		_emit_stroop()
	
	# 2. Spawner Logic
	if player_ref and enemy_scene != null:
		spawn_timer -= delta
		if spawn_timer <= 0:
			spawn_timer = spawn_interval
			_spawn_enemy_randomly()

func _emit_stroop():
	var text_index = randi() % COLOR_NAMES.size()
	var color_index = randi() % COLOR_VALUES.size()
	while color_index == text_index:
		color_index = randi() % COLOR_VALUES.size()
	stroop_changed.emit(COLOR_NAMES[text_index], COLOR_VALUES[color_index])

func damage_player(amount: int = 1) -> void:
	player_health = maxi(player_health - amount, 0)
	player_health_changed.emit(player_health)

func heal_player(amount: int = 1) -> void:
	player_health = mini(player_health + amount, 5)
	player_health_changed.emit(player_health)

func _spawn_enemy_randomly():
	if enemy_scene == null:
		print("Warning: No enemy_scene assigned to the spawner!")
		return

	# 1. Create the instance (Unity's Instantiate)
	var enemy_instance = enemy_scene.instantiate()
	
	# 2. Calculate a random position in a circle around the player
	var random_angle = randf_range(0, 2 * PI)
	var random_radius = randf_range(min_distance, max_distance)
	var offset = Vector2(cos(random_angle), sin(random_angle)) * random_radius
	
	# 3. Set the position
	enemy_instance.global_position = player_ref.global_position + offset
	
	# 4. Add it to the scene (Unity's parenting logic)
	# We add it to the parent of this script (likely the Level) so 
	# the enemies don't move with the player/spawner.
	get_parent().add_child(enemy_instance)
