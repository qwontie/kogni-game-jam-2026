extends Marker2D

@export var bullet_scene: PackedScene
@onready var muzzle = $Weapon/Muzzle
@onready var weapon_sprite: Sprite2D = $Weapon

const COLOR_TEXTURES := {
	"red": preload("res://assets/shotgun_red.png"),
	"green": preload("res://assets/shotgun_green.png"),
	"blue": preload("res://assets/shotgun_blue.png"),
	"yellow": preload("res://assets/shotgun_yellow.png"),
}

var _last_color: Color = Color(0, 0, 0, 0)

func _ready():
	_apply_weapon_color(GameState.current_weapon_color)

func _process(_delta):
	look_at(get_global_mouse_position())

	if GameState.current_weapon_color != _last_color:
		_apply_weapon_color(GameState.current_weapon_color)

	if Input.is_action_just_pressed("click"):
		shoot()

func _apply_weapon_color(c: Color) -> void:
	_last_color = c
	var key := _color_key(c)
	if key != "" and COLOR_TEXTURES.has(key):
		weapon_sprite.texture = COLOR_TEXTURES[key]

func _color_key(c: Color) -> String:
	if c.is_equal_approx(Color.RED): return "red"
	if c.is_equal_approx(Color.GREEN): return "green"
	if c.is_equal_approx(Color.BLUE): return "blue"
	if c.is_equal_approx(Color.YELLOW): return "yellow"
	return ""

func shoot():
	if not bullet_scene:
		return
	var bullet = bullet_scene.instantiate()
	get_tree().root.add_child(bullet)
	bullet.global_position = muzzle.global_position
	var aim_dir: Vector2 = get_global_mouse_position() - muzzle.global_position
	if aim_dir.length_squared() > 0.0001:
		bullet.rotation = aim_dir.angle()
	else:
		bullet.rotation = global_rotation
	bullet.modulate = GameState.current_weapon_color
