extends Node

@onready var botao_quest1 = $VBoxContainer/HBoxContainer/VBoxContainer/HBoxContainer/ConfigurationButtonButton
@onready var botao_quest2 = $VBoxContainer/HBoxContainer/VBoxContainer/HBoxContainer/ConfigurationButtonButton2
@onready var botao_quest3 = $VBoxContainer/HBoxContainer/VBoxContainer/HBoxContainer/ConfigurationButtonButton3

@onready var botao_resp1 = $VBoxContainer/HBoxContainer/VBoxContainer/HBoxContainer2/ConfigurationButtonButton
@onready var botao_resp2 = $VBoxContainer/HBoxContainer/VBoxContainer/HBoxContainer2/ConfigurationButtonButton2
@onready var botao_resp3 = $VBoxContainer/HBoxContainer/VBoxContainer/HBoxContainer2/ConfigurationButtonButton3

@onready var botao_vote1 = $VBoxContainer/HBoxContainer/VBoxContainer/HBoxContainer3/ConfigurationButtonButton
@onready var botao_vote2 = $VBoxContainer/HBoxContainer/VBoxContainer/HBoxContainer3/ConfigurationButtonButton2
@onready var botao_vote3 = $VBoxContainer/HBoxContainer/VBoxContainer/HBoxContainer3/ConfigurationButtonButton3

func _ready() -> void:
	
	configure_quest_buttons()
	configure_resp_buttons()
	configure_vote_buttons()

	#$VBoxContainer/HBoxContainer/PlayButton.pressed.connect(go_to_lobby)

	print("Botão de ir para lobby clicado")

func configure_quest_buttons():
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
	
	GameManager.change_scene("res://scenes/lobby_room.tscn")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
