extends Button


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	position = (get_viewport_rect().size - size) / 2.0
	position.y = 500
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass


func _on_pressed() -> void:
	GameManager.increment()
	pass # Replace with function body.
