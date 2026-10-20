extends Node

@onready var code_modal: Control = $CodeModalPanel

func _ready() -> void:
	GameManager.authenticate()
	
	var create_room_btn = _find_node_by_name(self, "CreateRoomButton")
	if create_room_btn:
		create_room_btn.pressed.connect(_on_create_room_pressed)

	var open_join_btn = _find_node_by_name(self, "JoinRoomButton")
	if open_join_btn:
		open_join_btn.pressed.connect(_on_open_join_modal_pressed)

	var confirm_join_btn = _find_node_by_name(self, "ConfirmJoinButton")
	if confirm_join_btn:
		confirm_join_btn.pressed.connect(_on_confirm_join_pressed)

	if code_modal:
		code_modal.visible = false


func _find_node_by_name(node: Node, node_name: String) -> Node:
	if node.name == node_name:
		return node
	for child in node.get_children():
		var found = _find_node_by_name(child, node_name)
		if found:
			return found
	return null


func _salvar_nome_jogador() -> void:
	var name_input = _find_node_by_name(self, "PlayerNameInput") as LineEdit
	if name_input and name_input.text.strip_edges() != "":
		GameManager.player_name = name_input.text.strip_edges()
	else:
		GameManager.player_name = "Jogador_%d" % randi_range(10, 99)


## HOST: Gera o código de 1 a 9999
func _on_create_room_pressed() -> void:
	_salvar_nome_jogador()
	
	# Gera um código estritamente de 4 dígitos (1000 a 9999)
	var generated_code: int = randi_range(1000, 9999)
	print("Código gerado para a sala: %d" % generated_code)
	
	GameManager.current_room_code = generated_code
	GameManager.join_room_with_code(generated_code, true)
	
	# O Host entra na tela de criar/configurar sala imediatamente
	GameManager.change_scene("res://scenes/create_room.tscn")


## GUEST: Abre o modal
func _on_open_join_modal_pressed() -> void:
	if code_modal:
		code_modal.visible = true


## GUEST: Confirma o código
func _on_confirm_join_pressed() -> void:
	var input_field = _find_node_by_name(self, "RoomCodeInput") as LineEdit
	if input_field:
		var typed_text: String = input_field.text.strip_edges()
		
		if typed_text.is_valid_int() and typed_text.to_int() > 0:
			var entered_code: int = typed_text.to_int()
			print("Procurando sala com o código: %d" % entered_code)
			
			_salvar_nome_jogador()
			GameManager.current_room_code = entered_code
			
			if code_modal:
				code_modal.visible = false
				
			# Inicia a busca no Game Center. 
			# A TROCA DE CENA PARA O LOBBY FOI REMOVIDA DAQUI E AGORA É FEITA PELO GAMEMANAGER QUANDO A REDE CONECTAR.
			GameManager.join_room_with_code(entered_code, false)
		else:
			input_field.placeholder_text = "Código Inválido!"
			input_field.text = ""
