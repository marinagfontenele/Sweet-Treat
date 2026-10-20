extends Node

@onready var room_code_label: Label = $MarginContainer/VBoxContainer/HBoxContainer4/RoomCodeLabel
@onready var play_button = $MarginContainer/VBoxContainer/HBoxContainer4/PlayButton

var player_containers: Array = []

func _ready() -> void:
	if room_code_label:
		room_code_label.text = "Código: %d" % GameManager.current_room_code
		
	if play_button:
		play_button.visible = GameManager.is_host
		if GameManager.is_host and not play_button.pressed.is_connected(go_to_create_questions):
			play_button.pressed.connect(go_to_create_questions)

	# Conecta o sinal reativo do GameManager
	GameManager.lobby_updated.connect(update_lobby_ui)
	
	_collect_player_containers(self)
	
	# Re-envia as informações do jogador local assim que entra no lobby
	GameManager._enviar_handshake_nome()
	update_lobby_ui()


func _collect_player_containers(node: Node) -> void:
	if node is AspectRatioContainer and node.has_node("PlayerLobby"):
		player_containers.append(node)
	for child in node.get_children():
		_collect_player_containers(child)


func update_lobby_ui() -> void:
	var display_names: Array = []
	
	# Pega todos os nomes cadastrados no Dicionário Sincronizado do GameManager
	for p_id in GameManager.connected_players_names.keys():
		var p_name = GameManager.connected_players_names[p_id]
		if not display_names.has(p_name):
			display_names.append(p_name)
			
	print("Interface do Lobby Atualizada. Jogadores visíveis: ", display_names)
	
	for i in range(player_containers.size()):
		var container = player_containers[i]
		var player_lobby_node = container.get_node("PlayerLobby")
		
		if i < display_names.size():
			container.visible = true
			var name_label = _find_label_in_node(player_lobby_node)
			if name_label:
				name_label.text = display_names[i]
		else:
			container.visible = false


func _find_label_in_node(node: Node) -> Label:
	if node is Label:
		return node
	for child in node.get_children():
		var found = _find_label_in_node(child)
		if found:
			return found
	return null


func go_to_create_questions() -> void:
	if not GameManager.is_host:
		return
		
	GameManager._enviar_pacote_json({ "type": "start_game" })
	GameManager.change_scene("res://scenes/create_questions.tscn")
