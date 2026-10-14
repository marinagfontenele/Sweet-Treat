extends Node

func _ready() -> void:

	$MarginContainer/VBoxContainer/PlayButton.pressed.connect(go_to_create_questions)

	print("Botão de ir para a criação de perguntas clicado")

# Called when the node enters the scene tree for the first time.
func go_to_create_questions() -> void:
	
	GameManager.change_scene("res://scenes/create_questions.tscn")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
