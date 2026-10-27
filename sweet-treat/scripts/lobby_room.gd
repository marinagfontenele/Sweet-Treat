extends Node

const ALERT_POPUP_SCENE = preload("res://scenes/pop-ups/leave_room.tscn")

const MIN_VISIBLE_CARDS := 2
const PLAYER_LOBBY_SCRIPT_PATH := "res://scripts/player_lobby.gd"

@onready var room_code_label: Label = $MarginContainer/VBoxContainer/HBoxContainer4/RoomCodeLabel
@onready var play_button = $MarginContainer/VBoxContainer/HBoxContainer4/PlayButton
@onready var close_button = _find_close_button()

var player_containers: Array = []


func _ready() -> void:
	if room_code_label:
		room_code_label.text = "Código: %d" % GameManager.current_room_code

	if play_button:
		play_button.visible = GameManager.is_host
		if GameManager.is_host and not play_button.pressed.is_connected(go_to_create_questions):
			play_button.pressed.connect(go_to_create_questions)

	# Conecta o botão X para abrir o Pop-up de alerta
	if close_button:
		if not close_button.pressed.is_connected(_on_close_pressed):
			close_button.pressed.connect(_on_close_pressed)

	if not GameManager.lobby_updated.is_connected(update_lobby_ui):
		GameManager.lobby_updated.connect(update_lobby_ui)

	_collect_player_containers(self)

	GameManager.register_local_player()
	GameManager._enviar_handshake_nome()
	update_lobby_ui()


# Localiza o botão de fechar (X) na cena do Lobby
func _find_close_button() -> BaseButton:
	var btn = get_node_or_null("MarginContainer/InfoButton")
	if btn == null:
		btn = find_child("InfoButton", true, false)
	if btn == null:
		btn = find_child("CloseButton", true, false)
	return btn as BaseButton


# Disparado ao clicar no botão X
func _on_close_pressed() -> void:
	if ALERT_POPUP_SCENE:
		var popup = ALERT_POPUP_SCENE.instantiate()
		add_child(popup)
		if popup.has_method("set_message"):
			popup.set_message("Tem certeza que deseja sair da sala agora?")


func _collect_player_containers(node: Node) -> void:
	if node is AspectRatioContainer and node.has_node("PlayerLobby"):
		player_containers.append(node)
	for child in node.get_children():
		_collect_player_containers(child)


func update_lobby_ui() -> void:
	var players: Array = GameManager.get_lobby_players()
	print("Lobby: %d jogador(es), %d vaga(s) na cena" % [players.size(), player_containers.size()])
	var visible_cards: int = mini(maxi(players.size(), MIN_VISIBLE_CARDS), player_containers.size())

	for i in range(player_containers.size()):
		var container = player_containers[i]
		var card = container.get_node("PlayerLobby")
		var card_ready: bool = _ensure_card_script(card)

		if i < players.size():
			container.visible = true
			if card_ready:
				card.set_profile(players[i])
			else:
				_fill_name_only(card, players[i])
		elif i < visible_cards and card_ready:
			container.visible = true
			card.set_waiting()
		else:
			container.visible = false


func _ensure_card_script(card: Node) -> bool:
	if card.has_method("set_profile") and card.has_method("set_waiting"):
		return true

	if ResourceLoader.exists(PLAYER_LOBBY_SCRIPT_PATH):
		card.set_script(load(PLAYER_LOBBY_SCRIPT_PATH))
		return card.has_method("set_profile")

	push_warning("Não achei %s: salve o player_lobby.gd nessa pasta." % PLAYER_LOBBY_SCRIPT_PATH)
	return false


func _fill_name_only(card: Node, profile: Dictionary) -> void:
	var name_label = _find_label_in_node(card)
	if name_label:
		name_label.text = str(profile.get("name", "Jogador"))


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

	GameManager.host_start_game()
