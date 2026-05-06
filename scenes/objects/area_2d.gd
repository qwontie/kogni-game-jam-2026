extends Area2D

@export var speed: float = 800.0

func _process(delta):
	# Движение вперед по вектору направления (вправо в локальных координатах)
	position += Vector2.RIGHT.rotated(rotation) * speed * delta

# Удаление пули при выходе за экран для оптимизации
func _on_visible_on_screen_notifier_2d_screen_exited():
	queue_free()

# Обработка попадания
func _on_body_entered(body):
	if body.has_method("take_damage"):
		body.take_damage()
	queue_free() # Пуля исчезает при столкновении
