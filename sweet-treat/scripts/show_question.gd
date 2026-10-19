extends Node

@onready var question_label: Label = $Label  

func _ready() -> void:
	# Exibe a pergunta da rodada atual de forma segura sem re-embaralhar
	if question_label:
		question_label.text = GameManager.get_current_question()
		
	print("Mostrando pergunta da rodada %d: %s" % [GameManager.current_question_index, question_label.text])

	# Espera 8 segundos e avança para a tela de resposta
	await get_tree().create_timer(8.0).timeout
	GameManager.change_scene("res://scenes/answer_question.tscn")
