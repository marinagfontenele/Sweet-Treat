extends Node

# Referências dos nós da cena
@onready var room_code_label: Label = $VBoxContainer/HBoxContainer/Panel/VBoxContainer/Panel/RoomCodeLabel

@onready var botao_quest1 = $VBoxContainer/HBoxContainer/VBoxContainer/HBoxContainer/ConfigurationButtonButton
@onready var botao_quest2 = $VBoxContainer/HBoxContainer/VBoxContainer/HBoxContainer/ConfigurationButtonButton2
@onready var botao_quest3 = $VBoxContainer/HBoxContainer/VBoxContainer/HBoxContainer/ConfigurationButtonButton3

@onready var botao_resp1 = $VBoxContainer/HBoxContainer/VBoxContainer/HBoxContainer2/ConfigurationButtonButton
@onready var botao_resp2 = $VBoxContainer/HBoxContainer/VBoxContainer/HBoxContainer2/ConfigurationButtonButton2
@onready var botao_resp3 = $VBoxContainer/HBoxContainer/VBoxContainer/HBoxContainer2/ConfigurationButtonButton3

@onready var botao_vote1 = $VBoxContainer/HBoxContainer/VBoxContainer/HBoxContainer3/ConfigurationButtonButton
@onready var botao_vote2 = $VBoxContainer/HBoxContainer/VBoxContainer/HBoxContainer3/ConfigurationButtonButton2
@onready var botao_vote3 = $VBoxContainer/HBoxContainer/VBoxContainer/HBoxContainer3/ConfigurationButtonButton3

@onready var play_button = $VBoxContainer/HBoxContainer/PlayButton

func _ready() -> void:
	# 1. Exibe o código da sala gerado pelo sistema
	if room_code_label:
		room_code_label.text = "%d" % GameManager.current_room_code
		print("Código da sala exibido com sucesso: %d" % GameManager.current_room_code)

	# 2. Configura os grupos de botões estilo rádio
	configure_quest_buttons()
	configure_resp_buttons()
	configure_vote_buttons()

	# 3. Conecta o botão de avançar garantindo que não haja reconexões pendentes
	if play_button:
		if play_button.pressed.is_connected(go_to_lobby):
			play_button.pressed.disconnect(go_to_lobby)
			
		play_button.pressed.connect(go_to_lobby)
		print("PlayButton conectado com sucesso no create_room!")
	else:
		push_error("ERRO: PlayButton não encontrado na cena create_room!")

	print("Tela de configuração pronta!")


func configure_quest_buttons():
	if not (botao_quest1 and botao_quest2 and botao_quest3): return
	
	botao_quest1.toggled.connect(func(pressionado):
		if pressionado:
			botao_quest2.button_pressed = false
			botao_quest3.button_pressed = false
	)
		
	botao_quest2.toggled.connect(func(pressionado):
		if pressionado:
			botao_quest1.button_pressed = false
			botao_quest3.button_pressed = false
	)
	
	botao_quest3.toggled.connect(func(pressionado):
		if pressionado:
			botao_quest1.button_pressed = false
			botao_quest2.button_pressed = false
	)


func configure_resp_buttons():
	if not (botao_resp1 and botao_resp2 and botao_resp3): return

	botao_resp1.toggled.connect(func(pressionado):
		if pressionado:
			botao_resp2.button_pressed = false
			botao_resp3.button_pressed = false
	)
		
	botao_resp2.toggled.connect(func(pressionado):
		if pressionado:
			botao_resp1.button_pressed = false
			botao_resp3.button_pressed = false
	)
	
	botao_resp3.toggled.connect(func(pressionado):
		if pressionado:
			botao_resp1.button_pressed = false
			botao_resp2.button_pressed = false
	)


func configure_vote_buttons():
	if not (botao_vote1 and botao_vote2 and botao_vote3): return

	botao_vote1.toggled.connect(func(pressionado):
		if pressionado:
			botao_vote2.button_pressed = false
			botao_vote3.button_pressed = false
	)
		
	botao_vote2.toggled.connect(func(pressionado):
		if pressionado:
			botao_vote1.button_pressed = false
			botao_vote3.button_pressed = false
	)
	
	botao_vote3.toggled.connect(func(pressionado):
		if pressionado:
			botao_vote1.button_pressed = false
			botao_vote2.button_pressed = false
	)


func go_to_lobby() -> void:
	print("Host clicou em avançar! Salvando opções e trocando para o lobby...")
	
	# 1. Salva a quantidade de perguntas
	var questions = 1
	if botao_quest2 and botao_quest2.button_pressed: 
		questions = 2
	elif botao_quest3 and botao_quest3.button_pressed: 
		questions = 3
	GameManager.config_questions_per_player = questions
	
	# 2. Salva tempo de resposta
	var answer_time = 30
	if botao_resp2 and botao_resp2.button_pressed:
		answer_time = 45
	elif botao_resp3 and botao_resp3.button_pressed:
		answer_time = 60
	GameManager.config_answer_time = answer_time

	# 3. Salva tempo de votação
	var vote_time = 15
	if botao_vote2 and botao_vote2.button_pressed:
		vote_time = 20
	elif botao_vote3 and botao_vote3.button_pressed:
		vote_time = 30
	GameManager.config_vote_time = vote_time

	# 4. Envia handshake com o nome do Host para a rede
	GameManager._enviar_handshake_nome()

	# 5. Muda de cena de forma diferida (libera o frame atual da Main Thread)
	GameManager.call_deferred("change_scene", "res://scenes/lobby_room.tscn")
