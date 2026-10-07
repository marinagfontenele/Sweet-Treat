extends Button


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	#position = (get_viewport_rect().size - size) / 2.0
	#position.y = 75
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass


func _on_pressed() -> void:
	print("_on_pressed")
	GameManager.request_match()
