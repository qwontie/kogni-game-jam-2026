extends CharacterBody2D

@export var speed: float = 190.0
@export var detection_radius: float = 4000.0
@export var wander_speed_factor: float = 0.5
@export_group("Attachment")
@export var attach_damage_interval: float = 0.5
@export var attach_distance: float = 96.0
@export var detach_opposite_dot: float = -0.55
@export var max_attached_global: int = 3

const ENEMY_TEXTURES := {
	"red": preload("res://assets/enemy_red.png"),
	"green": preload("res://assets/enemy_green.png"),
	"blue": preload("res://assets/enemy_blue.png"),
	"yellow": preload("res://assets/enemy_yellow.png"),
}
const KEY_TO_COLOR := {
	"red": Color.RED,
	"green": Color.GREEN,
	"blue": Color.BLUE,
	"yellow": Color.YELLOW,
}

var enemy_color: Color = Color.RED
var color_key: String = "red"
var forced_color_key: String = ""
var is_healer: bool = false
var base_scale: Vector2 = Vector2.ONE

var player: CharacterBody2D = null
var wander_direction: Vector2 = Vector2.ZERO
var wander_timer: float = 0.0
var attached: bool = false
var attach_side_direction: Vector2 = Vector2.RIGHT
var attach_damage_timer: float = 0.0
@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func _ready():
	player = get_tree().get_first_node_in_group("player")
	base_scale = sprite.scale
	_pick_random_color()
	_refresh_role()
	GameState.stroop_target_changed.connect(_on_stroop_target_changed)
	_pick_new_wander_direction()

func _physics_process(delta):
	if attached:
		_update_attached(delta)
		return

	# Healers should never physically push the player around. Trigger the heal
	# the moment we overlap, regardless of which body is moving — otherwise the
	# player slides along the healer's collision and the controls feel off.
	if is_healer and _try_heal_player_on_overlap():
		return

	var peaceful := is_healer or GameState.is_peace
	if not peaceful and _can_see_player():
		var direction = global_position.direction_to(player.global_position)
		velocity = direction * speed
	else:
		wander_timer -= delta
		if wander_timer <= 0:
			_pick_new_wander_direction()
		var s := speed * wander_speed_factor
		if peaceful:
			s *= 0.7
		velocity = wander_direction * s

	move_and_slide()
	if is_healer:
		var t := Time.get_ticks_msec() * 0.005
		var pulse := 1.0 + 0.08 * sin(t)
		sprite.scale = base_scale * pulse
	_on_contact()

func _can_see_player() -> bool:
	if player == null: return false
	return global_position.distance_to(player.global_position) < detection_radius

func _pick_new_wander_direction():
	var random_angle = randf_range(0, 2 * PI)
	wander_direction = Vector2(cos(random_angle), sin(random_angle))
	wander_timer = randf_range(1.0, 3.0)

func _pick_random_color() -> void:
	if forced_color_key != "" and ENEMY_TEXTURES.has(forced_color_key):
		color_key = forced_color_key
	else:
		var keys := ENEMY_TEXTURES.keys()
		color_key = keys[randi() % keys.size()]
	enemy_color = KEY_TO_COLOR[color_key]
	sprite.texture = ENEMY_TEXTURES[color_key]

func _on_stroop_target_changed(_enemy_color: Color, _weapon_color: Color) -> void:
	_refresh_role()

func _refresh_role() -> void:
	is_healer = not enemy_color.is_equal_approx(GameState.target_enemy_color)
	if is_healer:
		sprite.modulate = Color(1.0, 1.0, 1.0, 0.85)
	else:
		sprite.modulate = Color.WHITE
		sprite.scale = base_scale

func take_damage(bullet_color: Color = Color.WHITE):
	if attached:
		return
	var weapon_match := bullet_color.is_equal_approx(GameState.target_weapon_color)
	if not is_healer and weapon_match:
		if player != null and player.has_method("reward_enemy_kill"):
			player.reward_enemy_kill()
		GameState.add_kill()
		die()
	else:
		# Wrong weapon, or wrong target (healer) — punish the player but spare the bug.
		if player != null and player.has_method("take_damage"):
			player.take_damage(GameState.wrong_shot_damage)

func die():
	var particles = GPUParticles2D.new()
	# Detach from the dying enemy so the corpse can free immediately while the
	# burst plays out at the death position.
	get_parent().add_child(particles)
	particles.global_position = global_position

	var material = ParticleProcessMaterial.new()
	material.direction = Vector3(0, 0, 0)
	material.spread = 180.0
	material.initial_velocity_min = 80.0
	material.initial_velocity_max = 220.0
	material.gravity = Vector3.ZERO
	material.damping_min = 80.0
	material.damping_max = 140.0
	material.scale_min = 0.15
	material.scale_max = 0.35

	var scale_curve := Curve.new()
	scale_curve.add_point(Vector2(0.0, 1.0))
	scale_curve.add_point(Vector2(1.0, 0.0))
	var scale_tex := CurveTexture.new()
	scale_tex.curve = scale_curve
	material.scale_curve = scale_tex

	var alpha_grad := Gradient.new()
	alpha_grad.set_color(0, Color(1, 1, 1, 1))
	alpha_grad.set_color(1, Color(1, 1, 1, 0))
	var alpha_tex := GradientTexture1D.new()
	alpha_tex.gradient = alpha_grad
	material.color_ramp = alpha_tex

	particles.process_material = material
	particles.texture = $Sprite2D.texture
	particles.amount = 14
	particles.lifetime = 1.1
	particles.one_shot = true
	particles.emitting = true

	$Sprite2D.visible = false
	collision_shape.set_deferred("disabled", true)

	# Free the enemy now; particles live on their own and clean themselves up.
	var burst_lifetime: float = particles.lifetime
	queue_free()
	await particles.get_tree().create_timer(burst_lifetime).timeout
	if is_instance_valid(particles):
		particles.queue_free()

func is_attached_to_player() -> bool:
	return attached

func _attached_count() -> int:
	var n := 0
	for node in get_tree().get_nodes_in_group("enemy"):
		if node != self and node.has_method("is_attached_to_player") and node.is_attached_to_player():
			n += 1
	return n

func try_detach_with_dash(dash_direction: Vector2) -> bool:
	if not attached or dash_direction == Vector2.ZERO:
		return false
	if dash_direction.normalized().dot(attach_side_direction) > detach_opposite_dot:
		return false
	_detach()
	return true

func _try_heal_player_on_overlap() -> bool:
	if player == null or not is_instance_valid(player):
		return false
	# Player radius ~62, enemy radius ~34 → contact at ~96. Small buffer so the
	# heal fires just before the collision shapes start sliding against each other.
	if global_position.distance_to(player.global_position) > 100.0:
		return false
	GameState.heal_player(GameState.heal_amount)
	queue_free()
	return true

func _on_contact() -> void:
	for i in get_slide_collision_count():
		var collider := get_slide_collision(i).get_collider()
		if collider != null and collider.is_in_group("player"):
			if is_healer:
				GameState.heal_player(GameState.heal_amount)
				queue_free()
				return
			if GameState.is_peace:
				# Truce — bump and slide, no attach, no damage.
				return
			if _attached_count() >= max_attached_global:
				# Already enough bugs latched on — punch and die instead of
				# piling on (the dogpile is what causes the position glitch).
				if collider.has_method("take_damage"):
					collider.take_damage(GameState.hit_damage)
				queue_free()
				return
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
		if GameState.is_peace:
			return
		var dmg := GameState.hit_damage * 0.5
		if player.has_method("take_attached_damage"):
			player.take_attached_damage(dmg)
		elif player.has_method("take_damage"):
			player.take_damage(dmg)

func _update_attached_position() -> void:
	global_position = player.global_position + attach_side_direction * attach_distance

func _detach() -> void:
	attached = false
	collision_shape.set_deferred("disabled", false)
	velocity = attach_side_direction * speed
	wander_direction = attach_side_direction
	wander_timer = 0.35
