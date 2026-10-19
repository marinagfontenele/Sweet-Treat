extends Node

@onready var code_modal: Control = $CodeModalPanel # Certifique-se de ter esse painel na cena se quiser testar o convidado

func _ready() -> void:
	# Autentica no Game Center ao abrir o menu
	GameManager.authenticate()
	
	# Conexão do botão de criar sala do Host
	var create_room_btn = get_node_or_null("$MarginContainer/HBoxContainer/VBoxContainer/CreateRoomButton")
	if not create_room_btn:
		create_room_btn = _find_node_by_name(self, "CreateRoomButton")
		
	if create_room_btn:
		create_room_btn.pressed.connect(_on_create_room_pressed)

	# Conexão do botão que abre o modal para o convidado digitar o código
	var open_join_btn = _find_node_by_name(self, "JoinRoomButton")
	if open_join_btn:
		open_join_btn.pressed.connect(_on_open_join_modal_pressed)

	# Conexão do botão de confirmar dentro do modal
	var confirm_join_btn = _find_node_by_name(self, "ConfirmJoinButton")
	if confirm_join_btn:
		confirm_join_btn.pressed.connect(_on_confirm_join_pressed)

	# Esconde o modal ao iniciar
	if code_modal:
		code_modal.visible = false

	print("Main menu ready! Waiting for player input...")


# Função auxiliar de busca segura caso mude a estrutura de nós
func _find_node_by_name(node: Node, node_name: String) -> Node:
	if node.name == node_name:
		return node
	for child in node.get_children():
		var found = _find_node_by_name(child, node_name)
		if found:
			return found
	return null


## HOST: Cria a sala, gera o código numérico e vai para a configuração
func _on_create_room_pressed() -> void:
	print("Criar Sala pressionado! Gerando código da sala...")
	
	var generated_code: int = randi_range(10000, 99999)
	print("Código gerado para a sala: %d" % generated_code)
	
	GameManager.current_room_code = generated_code
	
	# Inicia o matchmaker avisando que SOMOS o host (true)
	GameManager.join_room_with_code(generated_code, true)
	
	# O Host vai direto para a tela de configurar o jogo
	GameManager.change_scene("res://scenes/create_room.tscn")


## GUEST: Abre o modal para digitar o código da sala
func _on_open_join_modal_pressed() -> void:
	if code_modal:
		code_modal.visible = true


## GUEST: Confirma o código digitado e entra na sala
func _on_confirm_join_pressed() -> void:
	var input_field = _find_node_by_name(self, "RoomCodeInput") as LineEdit
	if input_field:
		var typed_text: String = input_field.text
		
		if typed_text.is_valid_int() and typed_text.to_int() > 0:
			var entered_code: int = typed_text.to_int()
			print("Entrando na sala com o código: %d" % entered_code)
			
			GameManager.current_room_code = entered_code
			if code_modal:
				code_modal.visible = false
				
			# Inicia a busca como CONVIDADO (false)
			GameManager.join_room_with_code(entered_code, false)
		else:
			input_field.placeholder_text = "Código Inválido!"
			input_field.text = ""
