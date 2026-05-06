extends Node

# --- DIFFICULTY SCALING ---
var time_elapsed: float = 0.0
@export_group("Difficulty Scaling")
@export var difficulty_ramp: float = 0.05 # How much harder it gets per minute
@export var min_spawn_interval: float = 0.5 # The absolute fastest enemies can spawn
@export var min_stroop_interval: float = 2.0 # The absolute fastest the text can change

# --- STROOP VARIABLES ---
var current_weapon_color: Color = Color.RED
var player_health: int = 5
signal stroop_changed(text: String, color: Color)
signal player_health_changed(health: int)

const COLOR_NAMES = ["RED", "GREEN", "BLUE", "YELLOW"]
const COLOR_VALUES = [Color.RED, Color.GREEN, Color.BLUE, Color.YELLOW]
	
var stroop_timer: float = 10.0
@export var stroop_interval: float = 10.0 # Base speed

# --- SPAWNER VARIABLES ---
@export_group("Spawner Settings")
@export var enemy_scene: PackedScene 
@export var spawn_interval: float = 3.0 # Base speed
@export var min_distance: float = 400.0
@export var max_distance: float = 800.0

var spawn_timer: float = 0.0
var player_ref: Node2D = null

func _ready():
	player_ref = get_tree().get_first_node_in_group("player")
	spawn_timer = spawn_interval

func _process(delta):
	# 0. UPDATE GLOBAL TIME
	time_elapsed += delta
	
	# CALCULATE CURRENT DIFFICULTY MODIFIER
	# (e.g., after 60s at 0.05 ramp, difficulty is 1.05x)
	var difficulty_modifier = 1.0 + (time_elapsed / 60.0) * difficulty_ramp

	# 1. Stroop Logic (Scales with difficulty)
	stroop_timer -= delta
	if stroop_timer <= 0:
		# Difficulty reduces the wait time
		var actual_interval = max(min_stroop_interval, stroop_interval / difficulty_modifier)
		stroop_timer = actual_interval
		_emit_stroop()
	
	# 2. Spawner Logic (Scales with difficulty)
	if player_ref and enemy_scene != null:
		spawn_timer -= delta
		if spawn_timer <= 0:
			# Difficulty reduces the wait time between spawns
			var actual_spawn_rate = max(min_spawn_interval, spawn_interval / difficulty_modifier)
			spawn_timer = actual_spawn_rate
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
	if player_health <= 0:
		print("Game Over") # Add your game over logic here

func heal_player(amount: int = 1) -> void:
	player_health = mini(player_health + amount, 5)
	player_health_changed.emit(player_health)

func _spawn_enemy_randomly():
	if enemy_scene == null: return

	var enemy_instance = enemy_scene.instantiate()
	
	# --- OPTIONAL: Make enemies faster over time ---
	# If your Enemy script has a 'speed' variable, we can boost it here
	if "speed" in enemy_instance:
		var speed_boost = 1.0 + (time_elapsed / 60.0) * (difficulty_ramp * 2)
		enemy_instance.speed *= speed_boost

	var random_angle = randf_range(0, 2 * PI)
	var random_radius = randf_range(min_distance, max_distance)
	var offset = Vector2(cos(random_angle), sin(random_angle)) * random_radius
	
	enemy_instance.global_position = player_ref.global_position + offset
	get_parent().add_child(enemy_instance)
