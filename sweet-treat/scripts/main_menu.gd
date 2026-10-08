#
#extends Node
#
#func _ready() -> void:
#
	#$CreateRoomButton.pressed.connect(_on_start_pressed)
	##### PARTE DO GAME CENTER
	##$CountLabel.position = (get_viewport_rect().size - $CountLabel.size) / 2.0
	#$CountLabel.text = "0"
	#GameManager.authenticate()
#
	#print("Main menu ready! Waiting for player input...")
#
#func _on_start_pressed() -> void:
	#print("Start button pressed! Loading Level 1...")
#
	## Change to the game level scene
	## GameManager is our autoload, so we can call its functions from anywhere!
	#GameManager.change_scene("res://scenes/create_room.tscn")
	#
#
## Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta: float) -> void:
	#pass

extends Node

func _ready() -> void:
	# Autentica no Game Center ao abrir o menu
	GameManager.authenticate()

	$CountLabel.text = "0"

	# Conecta o botão "Crie uma sala" para solicitar a partida no Game Center
	if $CreateRoomButton:
		$CreateRoomButton.pressed.connect(_on_create_room_pressed)

	print("Main menu ready! Waiting for player input...")


func _on_create_room_pressed() -> void:
	print("Criar Sala pressionado! Solicitando Matchmaker...")
	# Chama o Matchmaker do Game Center
	GameManager.request_match()
