extends Label

var blink_timer: float = 0.0
var hide_timer: float = 0.0
var is_blinking: bool = false

func _ready():
	GameState.stroop_changed.connect(_on_stroop)
	# Replay the last stroop in case the autoload emitted before we were alive.
	if GameState.has_stroop:
		_on_stroop(GameState.last_stroop_text, GameState.last_stroop_color)

func _process(delta):
	if is_blinking:
		blink_timer -= delta
		modulate.a = 1.0 if int(blink_timer * 6) % 2 == 0 else 0.0
		if blink_timer <= 0:
			is_blinking = false
			modulate.a = 1.0	
	
	if hide_timer > 0:
		hide_timer -= delta
		if hide_timer <= 0:
			visible = false

func _on_stroop(stroop_text: String, color: Color):
	text = stroop_text
	label_settings.font_color = color
	visible = true
	is_blinking = true
	blink_timer = 2.0
	hide_timer = 2.0
