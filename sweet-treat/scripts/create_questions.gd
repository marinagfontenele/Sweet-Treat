extends Node

@onready var progress_bar: ProgressBar = $MarginContainer/VBoxContainer/VBoxContainer/ProgressBar/ProgressBar
@onready var progress_label: Label = $MarginContainer/VBoxContainer/VBoxContainer/Label
@onready var input_question: LineEdit = $MarginContainer/VBoxContainer/VBoxContainer2/LineEdit
@onready var play_button = $MarginContainer/VBoxContainer/VBoxContainer2/PlayButton

var total_questions_needed: int = 1
var current_question_index: int = 0
var local_questions: Array = []

func _ready() -> void:
	# 1. Pega a quantidade de perguntas configurada pelo Host no GameManager
	total_questions_needed = GameManager.config_questions_per_player
	current_question_index = 0
	local_questions.clear()
	GameManager.my_created_questions.clear()

	# 2. Configura os limites da barra de progresso visual
	if progress_bar:
		progress_bar.min_value = 0
		progress_bar.max_value = total_questions_needed
		progress_bar.value = 0

	# 3. Atualiza os textos iniciais da interface
	_update_ui()

	# 4. Conecta o botão de Enviar
	if play_button:
		play_button.pressed.connect(_on_submit_question_pressed)
		
	# Permite enviar apertando a tecla Enter no teclado
	if input_question:
		input_question.text_submitted.connect(func(_text): _on_submit_question_pressed())

	print("Tela de criação de perguntas pronta! O jogador precisa criar: %d perguntas." % total_questions_needed)


func _update_ui() -> void:
	# Atualiza o avanço visual da barra de progresso
	if progress_bar:
		progress_bar.value = current_question_index

	# Atualiza o texto do rótulo indicando a pergunta atual (Ex: "Pergunta 1 de 3")
	if progress_label:
		progress_label.text = "Pergunta %d de %d" % [current_question_index + 1, total_questions_needed]

	# Limpa o campo de texto para a próxima pergunta
	if input_question:
		input_question.placeholder_text = "Digite sua pergunta aqui..."
		input_question.text = ""


func _on_submit_question_pressed() -> void:
	if not input_question:
		return
		
	var typed_question: String = input_question.text.strip_edges()

	# Validação básica para evitar o envio de textos vazios
	if typed_question.is_empty():
		input_question.placeholder_text = "Por favor, digite uma pergunta válida!"
		return

	# 1. Guarda a pergunta na lista local do jogador
	local_questions.append(typed_question)
	current_question_index += 1
	print("Pergunta adicionada (%d/%d): %s" % [current_question_index, total_questions_needed, typed_question])

	# 2. Verifica se atingiu o total de perguntas exigidas pelo Host
	if current_question_index >= total_questions_needed:
		# Salva definitivamente no GameManager para uso futuro na partida
		GameManager.my_created_questions = local_questions.duplicate()
		print("Todas as perguntas foram inseridas com sucesso! Indo para a tela de espera...")
		
		# Avança para a cena de espera informada
		go_to_question_formulation_wait()
	else:
		# Atualiza a interface para coletar a próxima pergunta
		_update_ui()


func go_to_question_formulation_wait() -> void:
	GameManager.change_scene("res://scenes/question_formulation_wait.tscn")
