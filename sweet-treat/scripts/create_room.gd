extends Node

func _ready() -> void:

	$VBoxContainer/HBoxContainer/VBoxContainer/PlayButton.pressed.connect(go_to_lobby)

	print("Botão de ir para lobby clicado")

# Called when the node enters the scene tree for the first time.
func go_to_lobby() -> void:
	
	GameManager.change_scene("res://scenes/lobby_room.tscn")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
