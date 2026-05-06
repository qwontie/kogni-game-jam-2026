extends Area2D

@export var speed: float = 800.0

func _ready():
	# Connect the signal in code so it always works
	body_entered.connect(_on_body_entered)
	$VisibleOnScreenNotifier2D.screen_exited.connect(_on_visible_on_screen_notifier_2d_screen_exited)

func _process(delta):
	position += Vector2.RIGHT.rotated(rotation) * speed * delta

func _on_visible_on_screen_notifier_2d_screen_exited():
	queue_free()

func _on_body_entered(body):
	if body.has_method("take_damage"):
		body.take_damage()
	queue_free()
