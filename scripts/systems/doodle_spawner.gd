extends Node2D

const DOODLE_PATHS: Array[String] = [
	"res://assets/sprites/doodles/doodle_1.png",
	"res://assets/sprites/doodles/doodle_2.png",
	"res://assets/sprites/doodles/doodle_3.png",
]

const CHUNK_SIZE: float = 600.0
const DOODLES_PER_CHUNK: int = 2
const VIEW_CHUNK_RADIUS: int = 6

var _textures: Array[Texture2D] = []
var _active_chunks: Dictionary = {}
var _player: Node2D

func _ready() -> void:
	for path in DOODLE_PATHS:
		_textures.append(load(path))
	_player = get_tree().get_first_node_in_group(&"player") as Node2D

func _process(_delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(&"player") as Node2D
		if _player == null:
			return

	var center := Vector2i(
		int(floor(_player.global_position.x / CHUNK_SIZE)),
		int(floor(_player.global_position.y / CHUNK_SIZE))
	)

	var needed: Dictionary = {}
	for dx in range(-VIEW_CHUNK_RADIUS, VIEW_CHUNK_RADIUS + 1):
		for dy in range(-VIEW_CHUNK_RADIUS, VIEW_CHUNK_RADIUS + 1):
			var coord := Vector2i(center.x + dx, center.y + dy)
			needed[coord] = true
			if not _active_chunks.has(coord):
				_active_chunks[coord] = _spawn_chunk(coord)

	for coord in _active_chunks.keys():
		if not needed.has(coord):
			for n in _active_chunks[coord]:
				if is_instance_valid(n):
					n.queue_free()
			_active_chunks.erase(coord)

func _spawn_chunk(coord: Vector2i) -> Array:
	var nodes: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = (coord.x * 73856093) ^ (coord.y * 19349663)
	for i in DOODLES_PER_CHUNK:
		var s := Sprite2D.new()
		s.texture = _textures[rng.randi_range(0, _textures.size() - 1)]
		var lx := rng.randf_range(0.0, CHUNK_SIZE)
		var ly := rng.randf_range(0.0, CHUNK_SIZE)
		s.position = Vector2(float(coord.x) * CHUNK_SIZE + lx, float(coord.y) * CHUNK_SIZE + ly)
		s.rotation = rng.randf_range(-0.7, 0.7)
		var sc := rng.randf_range(1.2, 2.1)
		s.scale = Vector2(sc, sc)
		add_child(s)
		nodes.append(s)
	return nodes
