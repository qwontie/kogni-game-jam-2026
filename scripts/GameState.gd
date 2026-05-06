extends Node

const ENEMY_SCENE := preload("res://scenes/objects/Enemy.tscn")
const SPAWN_INDICATOR_SCRIPT := preload("res://scripts/spawn_indicator.gd")

# --- DIFFICULTY SCALING ---
var time_elapsed: float = 0.0
@export_group("Difficulty Scaling")
@export var difficulty_ramp: float = 0.9
@export var min_spawn_interval: float = 0.25
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

const COLOR_NAMES := ["RED", "GREEN", "BLUE", "YELLOW"]
const COLOR_VALUES := [Color.RED, Color.GREEN, Color.BLUE, Color.YELLOW]
const COLOR_KEYS := ["red", "green", "blue", "yellow"]

var stroop_timer: float = 10.0
@export var stroop_interval: float = 10.0

# --- SPAWNER ---
@export_group("Spawner Settings")
@export var spawn_interval: float = 1.4
@export var min_distance: float = 400.0
@export var max_distance: float = 800.0

@export_group("Spawn Juice")
@export var telegraph_time: float = 0.4
@export var calm_duration_min: float = 2.5
@export var calm_duration_max: float = 4.0
@export var burst_duration_min: float = 3.0
@export var burst_duration_max: float = 5.0
@export var calm_rate_mult: float = 1.2
@export var burst_rate_mult: float = 0.4
@export var stroop_bias_window: float = 3.0
@export var stroop_bias_target_chance: float = 0.65
@export var pity_heal_hp_threshold: float = 0.3
@export var pity_heal_drought: float = 8.0
@export var ring_cooldown: float = 20.0
@export var ring_hp_lockout: float = 0.4
@export var safe_cone_degrees: float = 25.0
@export var edge_buffer: float = 80.0

enum Phase { CALM, BURST }

var phase: int = Phase.CALM
var phase_timer: float = 5.0
var spawn_timer: float = 0.0
var player_ref: Node2D = null
var time_since_stroop: float = 0.0
var time_since_healer_spawn: float = 0.0
var ring_cooldown_timer: float = 0.0

func _ready():
	# Autoloads enter the tree before the main scene, so the player may not
	# exist yet — we lazily resolve it inside _process.
	# Open with a burst so the player feels pressure right away instead of
	# wandering an empty arena waiting for the first ticks.
	phase = Phase.BURST
	phase_timer = randf_range(burst_duration_min, burst_duration_max)
	spawn_timer = 0.3
	player_health = max_health
	stroop_timer = stroop_interval
	_emit_stroop()

func _process(delta):
	time_elapsed += delta
	time_since_stroop += delta
	time_since_healer_spawn += delta
	ring_cooldown_timer = maxf(ring_cooldown_timer - delta, 0.0)
	var difficulty_modifier := 1.0 + (time_elapsed / 60.0) * difficulty_ramp

	stroop_timer -= delta
	if stroop_timer <= 0:
		var actual_interval = max(min_stroop_interval, stroop_interval / difficulty_modifier)
		stroop_timer = actual_interval
		_emit_stroop()

	if player_ref == null or not is_instance_valid(player_ref):
		player_ref = get_tree().get_first_node_in_group("player")
	# Don't spawn during the halftime truce — the player should read the prompt
	# before new bugs walk on stage.
	if player_ref == null or is_peace:
		return

	phase_timer -= delta
	if phase_timer <= 0.0:
		_swap_phase()

	spawn_timer -= delta
	if spawn_timer <= 0.0:
		var rate_mult: float = calm_rate_mult if phase == Phase.CALM else burst_rate_mult
		var actual_spawn_rate := maxf(min_spawn_interval, (spawn_interval * rate_mult) / difficulty_modifier)
		spawn_timer = actual_spawn_rate
		_trigger_pattern(difficulty_modifier)

func _swap_phase() -> void:
	if phase == Phase.CALM:
		phase = Phase.BURST
		phase_timer = randf_range(burst_duration_min, burst_duration_max)
	else:
		phase = Phase.CALM
		phase_timer = randf_range(calm_duration_min, calm_duration_max)

func _trigger_pattern(difficulty_modifier: float) -> void:
	var pattern := _pick_pattern()
	match pattern:
		"single_jab":
			_spawn_single(difficulty_modifier)
		"arc":
			_spawn_arc(difficulty_modifier)
		"flank_line":
			_spawn_flank_line(difficulty_modifier)
		"ring":
			_spawn_ring(difficulty_modifier)

func _pick_pattern() -> String:
	if phase == Phase.CALM:
		return "single_jab"
	var hp_frac := 1.0 if max_health <= 0.0 else player_health / max_health
	var ring_ok := ring_cooldown_timer <= 0.0 and hp_frac >= ring_hp_lockout
	var roll := randf()
	if ring_ok and roll < 0.05:
		return "ring"
	if roll < 0.25:
		return "arc"
	if roll < 0.40:
		return "flank_line"
	return "single_jab"

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
	time_since_stroop = 0.0
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

# --- Spawn patterns ---

func _spawn_single(difficulty_modifier: float) -> void:
	var color_key := _pick_spawn_color()
	var pos := _edge_spawn_point(randf_range(0.0, TAU))
	_schedule_enemy(color_key, pos, 0.0, difficulty_modifier)

func _spawn_arc(difficulty_modifier: float) -> void:
	var count := 3 + (randi() % 2)
	var center_angle := randf_range(0.0, TAU)
	var arc_span := deg_to_rad(60.0)
	for i in range(count):
		var t := 0.0 if count == 1 else float(i) / float(count - 1)
		var angle := center_angle - arc_span * 0.5 + arc_span * t
		var pos := _edge_spawn_point(angle)
		_schedule_enemy(_pick_spawn_color(), pos, float(i) * 0.1, difficulty_modifier)

func _spawn_flank_line(difficulty_modifier: float) -> void:
	var count := 4 + (randi() % 2)
	var center_angle := randf_range(0.0, TAU)
	var center := _edge_spawn_point(center_angle)
	var perp := Vector2(-sin(center_angle), cos(center_angle))
	var spacing := 90.0
	for i in range(count):
		var offset := (float(i) - float(count - 1) * 0.5) * spacing
		var pos := center + perp * offset
		_schedule_enemy(_pick_spawn_color(), pos, float(i) * 0.08, difficulty_modifier)

func _spawn_ring(difficulty_modifier: float) -> void:
	var count := 6 + (randi() % 3)
	var radius := max_distance * 0.85
	var origin := player_ref.global_position
	var start_angle := randf_range(0.0, TAU)
	for i in range(count):
		var angle := start_angle + TAU * float(i) / float(count)
		var pos := origin + Vector2(cos(angle), sin(angle)) * radius
		_schedule_enemy(_pick_spawn_color(), pos, float(i) * 0.06, difficulty_modifier)
	ring_cooldown_timer = ring_cooldown
	# Force a long calm so the player gets breathing room after pushing through.
	phase = Phase.CALM
	phase_timer = calm_duration_max + 1.0

# --- Color selection ---

func _pick_spawn_color() -> String:
	var target_idx := _color_index(target_enemy_color)
	# Pity healer: low HP + healer drought → guarantee a non-target color.
	if max_health > 0.0 \
			and (player_health / max_health) < pity_heal_hp_threshold \
			and time_since_healer_spawn > pity_heal_drought:
		return _random_non_target_color(target_idx)
	var pick_target_chance := 0.5
	if time_since_stroop < stroop_bias_window:
		pick_target_chance = stroop_bias_target_chance
	if randf() < pick_target_chance:
		return COLOR_KEYS[target_idx]
	return _random_non_target_color(target_idx)

func _random_non_target_color(target_idx: int) -> String:
	var idx := randi() % COLOR_KEYS.size()
	while idx == target_idx:
		idx = randi() % COLOR_KEYS.size()
	return COLOR_KEYS[idx]

func _color_index(c: Color) -> int:
	for i in range(COLOR_VALUES.size()):
		if COLOR_VALUES[i].is_equal_approx(c):
			return i
	return 0

# --- Spawn execution ---

func _schedule_enemy(color_key: String, pos: Vector2, delay: float, difficulty_modifier: float) -> void:
	var key_idx := COLOR_KEYS.find(color_key)
	if key_idx < 0:
		key_idx = 0
	var color_val: Color = COLOR_VALUES[key_idx]
	if key_idx != _color_index(target_enemy_color):
		# A non-target enemy will spawn → it's a healer relative to the current Stroop.
		time_since_healer_spawn = 0.0
	var parent := _spawn_parent()
	if parent == null:
		return
	var indicator: Node2D = SPAWN_INDICATOR_SCRIPT.new()
	parent.add_child(indicator)
	indicator.setup(color_val, pos, telegraph_time + delay)
	indicator.spawn_now.connect(_on_indicator_fire.bind(color_key, pos, difficulty_modifier))

func _on_indicator_fire(color_key: String, pos: Vector2, difficulty_modifier: float) -> void:
	var parent := _spawn_parent()
	if parent == null:
		return
	var enemy := ENEMY_SCENE.instantiate()
	enemy.forced_color_key = color_key
	if "speed" in enemy:
		var speed_boost := 1.0 + (time_elapsed / 60.0) * (difficulty_ramp * 2.0)
		enemy.speed *= speed_boost
	parent.add_child(enemy)
	enemy.global_position = pos

func _spawn_parent() -> Node:
	if player_ref and player_ref.get_parent():
		return player_ref.get_parent()
	return get_tree().current_scene

# --- Edge spawn + safe cone ---

func _edge_spawn_point(angle: float) -> Vector2:
	var origin: Vector2 = player_ref.global_position
	var safe_angle := _apply_safe_cone(angle)
	var dir := Vector2(cos(safe_angle), sin(safe_angle))
	var cam: Camera2D = player_ref.get_viewport().get_camera_2d()
	if cam != null:
		var zoom: Vector2 = cam.zoom
		if zoom.x > 0.0001 and zoom.y > 0.0001:
			var view_size: Vector2 = player_ref.get_viewport_rect().size / zoom
			var half := view_size * 0.5 + Vector2(edge_buffer, edge_buffer)
			var dx := absf(dir.x)
			var dy := absf(dir.y)
			var tx := INF if dx < 0.0001 else half.x / dx
			var ty := INF if dy < 0.0001 else half.y / dy
			var t := minf(tx, ty)
			var center: Vector2 = cam.get_screen_center_position()
			var point := center + dir * t
			if point.distance_to(origin) >= min_distance:
				return point
	# Fallback: ring around player if we couldn't compute a sane edge point.
	var radius := randf_range(min_distance, max_distance)
	return origin + dir * radius

func _apply_safe_cone(angle: float) -> float:
	if player_ref == null or not ("last_move_direction" in player_ref):
		return angle
	var face: Vector2 = player_ref.last_move_direction
	if face == Vector2.ZERO:
		return angle
	var face_angle := face.angle()
	var diff := wrapf(angle - face_angle, -PI, PI)
	var cone := deg_to_rad(safe_cone_degrees)
	if absf(diff) <= cone:
		# Flip to the back arc so the player isn't ambushed face-first.
		return angle + PI
	return angle
