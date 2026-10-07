extends Node2D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$CountLabel.position = (get_viewport_rect().size - $CountLabel.size) / 2.0
	$CountLabel.text = "0"
	GameManager.authenticate()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass
