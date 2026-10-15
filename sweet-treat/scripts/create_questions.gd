extends Node

func _ready() -> void:

	$MarginContainer/VBoxContainer/PlayButton.pressed.connect(go_to_question_formulation_wait)

	print("Botão de ir para o aguardo de formulação clicado")

# Called when the node enters the scene tree for the first time.
func go_to_question_formulation_wait() -> void:
	
	GameManager.change_scene("res://scenes/question_formulation_wait.tscn")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
