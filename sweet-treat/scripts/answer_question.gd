extends Node


func _ready() -> void:

	$MarginContainer/VBoxContainer/PlayButton.pressed.connect(go_to_all_answers)

	print("Botão de ir para todas as respostas clicado")

# Called when the node enters the scene tree for the first time.
func go_to_all_answers() -> void:
	
	GameManager.change_scene("res://scenes/all_answers.tscn")
