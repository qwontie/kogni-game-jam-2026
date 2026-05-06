extends Marker2D

@export var bullet_scene: PackedScene # Перетащите сцену пули сюда в инспекторе
@onready var muzzle = $Weapon/Muzzle

func _process(_delta):
	# 1. Поворот к курсору
	look_at(get_global_mouse_position())
	
	# 2. Обработка стрельбы
	if Input.is_action_just_pressed("click"): # Настройте "click" в Input Map (LMB)
		shoot()

func shoot():
	if bullet_scene:
		var bullet = bullet_scene.instantiate()
		# Добавляем пулю в корень сцены, чтобы она не вращалась вместе с игроком
		get_tree().root.add_child(bullet)
		
		# Устанавливаем позицию и направление
		bullet.global_position = muzzle.global_position
		bullet.rotation = global_rotation
