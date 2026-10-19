extends Node

# Ajustado para os caminhos reais baseados na sua árvore de nós
@onready var answer_label: Label = $MarginContainer/VBoxContainer/Panel/LabelAnswerMostVoted
@onready var winner_label: Label = $MarginContainer/VBoxContainer/Panel/WinnerLabel
@onready var next_button: Button = $MarginContainer/VBoxContainer/NextButton

func _ready() -> void:
	# Exemplo de preenchimento dinâmico dos textos
	if answer_label:
		answer_label.text = "Resposta foi X" # Aqui depois virá do GameManager
	if winner_label:
		winner_label.text = "O mais votado foi Fulano" # Aqui depois virá do GameManager

	# Conecta o botão para avançar
	if next_button:
		next_button.pressed.connect(advance_to_next_round)

	print("Tela de mais votados pronta!")
	

# Lógica para avançar para a próxima rodada ou finalizar a partida
func advance_to_next_round() -> void:
	GameManager.current_question_index += 1
	GameManager.clear_round_answers() # Limpa as respostas da rodada anterior!
	
	if GameManager.current_question_index < GameManager.game_questions.size():
		GameManager.change_scene("res://scenes/show_question.tscn")
	else:
		GameManager.change_scene("res://scenes/final_score.tscn")
