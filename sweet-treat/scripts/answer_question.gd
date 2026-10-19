extends Node

# Ajuste estes caminhos de acordo com os nomes dos nós reais na sua cena answer_question
@onready var question_label: Label = $MarginContainer/VBoxContainer/QuestionLabel 
@onready var answer_input: LineEdit = $MarginContainer/VBoxContainer/LineEdit 
@onready var play_button: Button = $MarginContainer/VBoxContainer/PlayButton

func _ready() -> void:
	# 1. Pega a pergunta atual do GameManager e exibe no topo da tela
	if question_label:
		question_label.text = GameManager.get_current_question()

	# 2. Conecta o botão de avançar
	if play_button:
		if not play_button.pressed.is_connected(go_to_all_answers):
			play_button.pressed.connect(go_to_all_answers)

	print("Tela de responder pergunta pronta!")


# Chamado quando o jogador clica para ir para todas as respostas
func go_to_all_answers() -> void:
	var user_answer = ""
	if answer_input:
		user_answer = answer_input.text
		
	# Envia a resposta para o GameManager (que despacha para a rede)
	GameManager.send_my_answer(user_answer)
	
	# Avança para a cena de todas as respostas
	GameManager.change_scene("res://scenes/all_answers.tscn")
