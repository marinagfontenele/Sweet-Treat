
extends Node

func _ready() -> void:

	$CreateRoomButton.pressed.connect(_on_start_pressed)

	print("Main menu ready! Waiting for player input...")

func _on_start_pressed() -> void:
	print("Start button pressed! Loading Level 1...")

	# Change to the game level scene
	# GameManager is our autoload, so we can call its functions from anywhere!
	GameManager.change_scene("res://scenes/create_room.tscn")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
