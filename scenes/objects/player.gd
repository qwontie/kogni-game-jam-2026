extends CharacterBody2D

@export_group("Movement")
@export var speed: float = 400.0
@export var acceleration: float = 3200.0
@export var friction: float = 3800.0

@export_group("Sprint")
@export var sprint_multiplier: float = 1.35
@export var max_stamina: float = 1.0
@export var sprint_stamina_drain: float = 0.45
@export var stamina_recovery: float = 0.7
@export var exhausted_recovery_threshold: float = 0.35

@export_group("Dash")
@export var dash_speed: float = 1100.0
@export var dash_duration: float = 0.14
@export var dash_cooldown: float = 0.45
@export var dash_input_buffer: float = 0.1
@export var dash_iframe_duration: float = 0.12
@export var dash_steer_strength: float = 0.18
@export var max_dash_charges: int = 1
@export var dash_ghost_interval: float = 0.04

@export_group("Perfect Dodge")
@export var perfect_dodge_radius: float = 96.0
@export var perfect_dodge_cooldown_refund: float = 0.32
@export var perfect_dodge_bonus_charges: int = 1
@export var dash_kill_chain_window: float = 0.5

@export_group("Damage")
@export var hurt_invulnerability: float = 0.65

var stamina: float = max_stamina
var exhausted: bool = false
var dash_timer: float = 0.0
var dash_cooldown_timer: float = 0.0
var dash_buffer_timer: float = 0.0
var dash_ghost_timer: float = 0.0
var iframe_timer: float = 0.0
var hurt_timer: float = 0.0
var kill_chain_timer: float = 0.0
var dash_charges: int = max_dash_charges
var dash_direction: Vector2 = Vector2.RIGHT
var last_move_direction: Vector2 = Vector2.RIGHT
var perfect_dodge_ready: bool = false
var base_sprite_modulate: Color = Color.WHITE
var sprite: Sprite2D

func _physics_process(_delta: float) -> void:
	var direction := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if direction != Vector2.ZERO:
		last_move_direction = direction.normalized()

	_tick_timers(_delta)
	_handle_dash_input()
	_recover_dash_charge()

	if _is_dashing():
		_update_dash(direction, _delta)
	else:
		_update_run(direction, _delta)

	move_and_slide()
	_update_feedback()

func _ready() -> void:
	sprite = $Sprite2D
	base_sprite_modulate = sprite.modulate
	stamina = max_stamina
	dash_charges = max_dash_charges

func _tick_timers(delta: float) -> void:
	dash_timer = maxf(dash_timer - delta, 0.0)
	dash_cooldown_timer = maxf(dash_cooldown_timer - delta, 0.0)
	dash_buffer_timer = maxf(dash_buffer_timer - delta, 0.0)
	dash_ghost_timer = maxf(dash_ghost_timer - delta, 0.0)
	iframe_timer = maxf(iframe_timer - delta, 0.0)
	hurt_timer = maxf(hurt_timer - delta, 0.0)
	kill_chain_timer = maxf(kill_chain_timer - delta, 0.0)

func _handle_dash_input() -> void:
	if Input.is_action_just_pressed("dash"):
		dash_buffer_timer = dash_input_buffer
	if dash_buffer_timer > 0.0 and _can_dash():
		_start_dash()

func _recover_dash_charge() -> void:
	if dash_charges < max_dash_charges and dash_cooldown_timer <= 0.0:
		dash_charges += 1
		if dash_charges < max_dash_charges:
			dash_cooldown_timer = dash_cooldown

func _update_run(direction: Vector2, delta: float) -> void:
	var sprinting := _is_sprinting(direction)
	var target_speed := speed
	if sprinting:
		target_speed *= sprint_multiplier
		stamina = maxf(stamina - sprint_stamina_drain * delta, 0.0)
		if stamina <= 0.0:
			exhausted = true
	else:
		stamina = minf(stamina + stamina_recovery * delta, max_stamina)
		if exhausted and stamina >= exhausted_recovery_threshold:
			exhausted = false

	var target_velocity := direction * target_speed
	var rate := acceleration if direction != Vector2.ZERO else friction
	velocity = velocity.move_toward(target_velocity, rate * delta)

func _update_dash(direction: Vector2, _delta: float) -> void:
	if direction != Vector2.ZERO:
		dash_direction = dash_direction.lerp(direction.normalized(), dash_steer_strength).normalized()
	velocity = dash_direction * dash_speed
	if perfect_dodge_ready:
		_try_perfect_dodge()
	if dash_ghost_timer <= 0.0:
		_spawn_dash_ghost()
		dash_ghost_timer = dash_ghost_interval

func _is_sprinting(direction: Vector2) -> bool:
	return direction != Vector2.ZERO and Input.is_action_pressed("sprint") and not exhausted and stamina > 0.0

func _is_dashing() -> bool:
	return dash_timer > 0.0

func _can_dash() -> bool:
	return dash_charges > 0 and not _is_dashing()

func _start_dash() -> void:
	dash_buffer_timer = 0.0
	dash_charges -= 1
	dash_cooldown_timer = dash_cooldown
	dash_timer = dash_duration
	iframe_timer = dash_iframe_duration
	perfect_dodge_ready = true
	kill_chain_timer = dash_duration + dash_kill_chain_window
	dash_direction = _get_dash_direction()
	dash_ghost_timer = 0.0
	_spawn_dash_ghost()

func _get_dash_direction() -> Vector2:
	var input_direction := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if input_direction != Vector2.ZERO:
		return input_direction.normalized()
	var mouse_direction := global_position.direction_to(get_global_mouse_position())
	if mouse_direction != Vector2.ZERO:
		return mouse_direction.normalized()
	return last_move_direction

func _try_perfect_dodge() -> void:
	for node in get_tree().get_nodes_in_group("enemy"):
		if node is Node2D and global_position.distance_to(node.global_position) <= perfect_dodge_radius:
			perfect_dodge_ready = false
			dash_cooldown_timer = maxf(dash_cooldown_timer - perfect_dodge_cooldown_refund, 0.0)
			dash_charges = mini(dash_charges + perfect_dodge_bonus_charges, max_dash_charges + perfect_dodge_bonus_charges)
			_flash(Color.CYAN)
			return

func take_damage(amount: int = 1) -> void:
	if is_invulnerable():
		return
	hurt_timer = hurt_invulnerability
	iframe_timer = hurt_invulnerability
	GameState.damage_player(amount)
	_flash(Color.RED)

func reward_enemy_kill() -> void:
	if kill_chain_timer <= 0.0:
		return
	dash_charges = mini(dash_charges + 1, max_dash_charges + perfect_dodge_bonus_charges)
	dash_cooldown_timer = maxf(dash_cooldown_timer - perfect_dodge_cooldown_refund, 0.0)
	_flash(Color(0.7, 1.0, 0.25))

func is_invulnerable() -> bool:
	return iframe_timer > 0.0

func _update_feedback() -> void:
	if sprite == null:
		return
	if is_invulnerable():
		sprite.self_modulate.a = 0.45 + 0.35 * absf(sin(Time.get_ticks_msec() * 0.035))
	else:
		sprite.self_modulate.a = 1.0

func _flash(color: Color) -> void:
	if sprite == null:
		return
	sprite.modulate = color
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", base_sprite_modulate, 0.18)

func _spawn_dash_ghost() -> void:
	if sprite == null or sprite.texture == null or get_parent() == null:
		return
	var ghost := Sprite2D.new()
	ghost.texture = sprite.texture
	ghost.global_position = sprite.global_position
	ghost.global_rotation = sprite.global_rotation
	ghost.global_scale = sprite.global_scale
	ghost.modulate = Color(0.35, 0.9, 1.0, 0.35)
	get_parent().add_child(ghost)
	var tween := ghost.create_tween()
	tween.tween_property(ghost, "modulate:a", 0.0, 0.18)
	tween.finished.connect(ghost.queue_free)
