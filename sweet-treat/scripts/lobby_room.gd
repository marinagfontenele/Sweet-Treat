extends Node

@onready var code_label: Label = $MarginContainer/VBoxContainer/HBoxContainer4/RoomCodeLabel
@onready var play_button = $MarginContainer/VBoxContainer/HBoxContainer4/PlayButton

func _ready() -> void:
	# Exibe o código da sala na tela para referência usando o nome correto da variável (code_label)
	if code_label:
		code_label.text = "Código: %d" % GameManager.current_room_code
		print("Código da sala exibido no lobby com sucesso!")
	else:
		print("Aviso: RoomCodeLabel não foi encontrado no caminho especificado.")

	if play_button:
		play_button.pressed.connect(go_to_create_questions)
		print("PlayButton do lobby conectado com sucesso!")
	else:
		print("Aviso: PlayButton não foi encontrado no caminho especificado.")

	print("Lobby pronto! Aguardando jogadores...")

func go_to_create_questions() -> void:
	print("Host clicou para iniciar! Indo para a criação de perguntas...")
	GameManager.change_scene("res://scenes/create_questions.tscn")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
