extends Node

@onready var room_code_label: Label = $MarginContainer/VBoxContainer/HBoxContainer4/RoomCodeLabel
@onready var play_button = $MarginContainer/VBoxContainer/HBoxContainer4/PlayButton

var player_containers: Array = []

func _ready() -> void:
	# 1. Exibe o código da sala gerado
	if room_code_label:
		room_code_label.text = "Código: %d" % GameManager.current_room_code

	# 2. Conecta o botão de iniciar
	if play_button:
		play_button.pressed.connect(go_to_create_questions)

	# 3. Coleta os containers principais da grade
	_collect_player_containers(self)

	# 4. Atualiza a interface
	update_lobby_ui()

	print("Lobby pronto! Total de slots visuais encontrados: %d" % player_containers.size())


# Função recursiva para achar os AspectRatioContainers que contêm os slots de player
func _collect_player_containers(node: Node) -> void:
	if node is AspectRatioContainer and node.has_node("PlayerLobby"):
		player_containers.append(node)
	for child in node.get_children():
		_collect_player_containers(child)


# Atualiza a interface do lobby garantindo que o host e os conectados apareçam
func update_lobby_ui() -> void:
	# Pega a lista oficial de conectados
	var display_list = []
	
	if GameManager.current_match:
		display_list = GameManager.current_match.get_players()
	
	# GARANTIA: Se a lista da partida estiver vazia mas nós somos o host (ou estamos na sala),
	# adicionamos pelo menos o jogador local (Host) para ele nunca sumir da tela!
	if display_list.size() == 0 and GameManager.local:
		display_list.append(GameManager.local)

	print("Total de jogadores para exibir no lobby: %d" % display_list.size())
	
	for i in range(player_containers.size()):
		var container = player_containers[i]
		var player_lobby_node = container.get_node("PlayerLobby")
		
		# Se existe um jogador para este slot
		if i < display_list.size():
			var player = display_list[i]
			container.visible = true # Mostra o slot na grade
			
			var name_label = _find_label_in_node(player_lobby_node)
			if name_label:
				# Pega o nome do player (GKPlayer ou GKLocalPlayer)
				if "display_name" in player and player.display_name:
					name_label.text = player.display_name
				else:
					name_label.text = "Host / Jogador"
				
				print("Slot %d preenchido com sucesso." % i)
		else:
			# Se o slot estiver vazio, esconde o container inteiro da grade
			container.visible = false


# Função auxiliar para achar uma Label dentro do componente do player
func _find_label_in_node(node: Node) -> Label:
	if node is Label:
		return node
	for child in node.get_children():
		var found = _find_label_in_node(child)
		if found:
			return found
	return null


func go_to_create_questions() -> void:
	print("Host iniciou a partida! Indo para a criação de perguntas...")
	GameManager.change_scene("res://scenes/create_questions.tscn")
