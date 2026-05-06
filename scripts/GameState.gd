extends Node

# --- DIFFICULTY SCALING ---
var time_elapsed: float = 0.0
@export_group("Difficulty Scaling")
@export var difficulty_ramp: float = 0.05
@export var min_spawn_interval: float = 0.5
@export var min_stroop_interval: float = 2.0

# --- HEALTH ---
@export_group("Health")
@export var max_health: float = 100.0
@export var hit_damage: float = 20.0
@export var wrong_shot_damage: float = 8.0
@export var heal_amount: float = 20.0

var player_health: float = 100.0

# True while the Stroop word + halftime overlay is on screen — enemies act
# friendly so the player can read the prompt without taking chip damage.
var is_peace: bool = false

# --- STROOP / TARGETS ---
var current_weapon_color: Color = Color.RED
var target_enemy_color: Color = Color.RED
var target_weapon_color: Color = Color.RED

signal stroop_changed(text: String, color: Color)
signal stroop_target_changed(enemy_color: Color, weapon_color: Color)
signal player_health_changed(health: float, max_health: float)

# Latest stroop snapshot — late-subscribing HUD nodes replay this in their
# own _ready so they don't miss the first emit fired by the autoload before
# the main scene was alive.
var last_stroop_text: String = ""
var last_stroop_color: Color = Color.WHITE
var has_stroop: bool = false

const COLOR_NAMES = ["RED", "GREEN", "BLUE", "YELLOW"]
const COLOR_VALUES = [Color.RED, Color.GREEN, Color.BLUE, Color.YELLOW]

var stroop_timer: float = 10.0
@export var stroop_interval: float = 10.0

# --- SPAWNER ---
@export_group("Spawner Settings")
@export var enemy_scene: PackedScene
@export var spawn_interval: float = 3.0
@export var min_distance: float = 400.0
@export var max_distance: float = 800.0

var spawn_timer: float = 0.0
var player_ref: Node2D = null

func _ready():
	player_ref = get_tree().get_first_node_in_group("player")
	spawn_timer = spawn_interval
	player_health = max_health
	stroop_timer = stroop_interval
	_emit_stroop()

func _process(delta):
	time_elapsed += delta
	var difficulty_modifier = 1.0 + (time_elapsed / 60.0) * difficulty_ramp

	stroop_timer -= delta
	if stroop_timer <= 0:
		var actual_interval = max(min_stroop_interval, stroop_interval / difficulty_modifier)
		stroop_timer = actual_interval
		_emit_stroop()

	# Don't spawn during the halftime truce — the player should read the prompt
	# before new bugs walk on stage.
	if player_ref and enemy_scene != null and not is_peace:
		spawn_timer -= delta
		if spawn_timer <= 0:
			var actual_spawn_rate = max(min_spawn_interval, spawn_interval / difficulty_modifier)
			spawn_timer = actual_spawn_rate
			_spawn_enemy_randomly()

func _emit_stroop():
	var text_index = randi() % COLOR_NAMES.size()
	var color_index = randi() % COLOR_VALUES.size()
	# 25% chance the word's meaning and rendered color match — keeps the player honest.
	if randf() > 0.25:
		while color_index == text_index:
			color_index = randi() % COLOR_VALUES.size()
	target_enemy_color = COLOR_VALUES[text_index]
	target_weapon_color = COLOR_VALUES[color_index]
	last_stroop_text = COLOR_NAMES[text_index]
	last_stroop_color = target_weapon_color
	has_stroop = true
	stroop_changed.emit(last_stroop_text, last_stroop_color)
	stroop_target_changed.emit(target_enemy_color, target_weapon_color)

func damage_player(amount: float = 20.0) -> void:
	player_health = maxf(player_health - amount, 0.0)
	player_health_changed.emit(player_health, max_health)
	if player_health <= 0.0:
		print("Game Over")

func heal_player(amount: float = 20.0) -> void:
	player_health = minf(player_health + amount, max_health)
	player_health_changed.emit(player_health, max_health)

func _spawn_enemy_randomly():
	if enemy_scene == null: return

	var enemy_instance = enemy_scene.instantiate()
	if "speed" in enemy_instance:
		var speed_boost = 1.0 + (time_elapsed / 60.0) * (difficulty_ramp * 2)
		enemy_instance.speed *= speed_boost

	var random_angle = randf_range(0, 2 * PI)
	var random_radius = randf_range(min_distance, max_distance)
	var offset = Vector2(cos(random_angle), sin(random_angle)) * random_radius

	enemy_instance.global_position = player_ref.global_position + offset
	get_parent().add_child(enemy_instance)
