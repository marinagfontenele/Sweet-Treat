extends Node

@onready var question_label: Label = $Label 

func _ready() -> void:
	# Se a lista de perguntas do jogo ainda não foi baralhada, embaralha agora!
	if not GameManager.game_questions.is_empty():
		GameManager.game_questions.shuffle() # <--- EMBARALHA TODAS AS PERGUNTAS AQUI

	# Exibe a pergunta da rodada atual
	if question_label:
		question_label.text = GameManager.get_current_question()
		
	print("Mostrando pergunta da rodada %d..." % GameManager.current_question_index)

	# Espera 8 segundos e avança para a tela de resposta
	await get_tree().create_timer(8.0).timeout
	GameManager.change_scene("res://scenes/answer_question.tscn")
