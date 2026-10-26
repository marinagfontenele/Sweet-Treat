extends Node

# Quanto tempo o convidado espera achar a sala antes de desistir
const JOIN_TIMEOUT_SECONDS := 25.0

@onready var loadingScreen: Control = $LoadingScreen
@onready var code_modal: Control = $CodeModalPanel # Certifique-se de ter esse painel na cena se quiser testar o convidado
@onready var configuration_panel: Control = $ConfigurationPanel
@onready var avatar_panel: Control = $AvatarPanel
@onready var edit_panel: Control = $AvatarPanel
@onready var tutorial_panel: Control = $TutorialPanel

var _join_timer: Timer

func _ready() -> void:
	GameManager.authenticate()

	if not GameManager.connection_failed.is_connected(_on_connection_failed):
		GameManager.connection_failed.connect(_on_connection_failed)

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

	if loadingScreen:
		loadingScreen.visible = false

	var open_configuration_btn = _find_node_by_name(self, "SettingsButton")
	if open_configuration_btn:
		open_configuration_btn.pressed.connect(_show_settings)
	
	if configuration_panel:
		configuration_panel.visible = false

	if avatar_panel:
		avatar_panel.visible = false
	
	if tutorial_panel:
		tutorial_panel.visible = false
	
	var open_info_btn = _find_node_by_name(self, "InfoButton")
	if open_info_btn:
		open_info_btn.pressed.connect(_show_tutorial)

	# Círculo do avatar E botão roxo abrem o painel
	for node_name in ["CharacterBackground", "EditButton"]:
		var btn := _find_node_by_name(self, node_name) as BaseButton
		if btn and not btn.pressed.is_connected(_show_avatar):
			btn.pressed.connect(_show_avatar)
	
	var avatar_screen = _find_node_by_name(self, "AvatarScreen")

	if avatar_screen:
		avatar_screen.customization_confirmed.connect(
			_on_customization_confirmed
		)

	_apply_profile()

	var name_input = _find_node_by_name(self, "PlayerNameInput") as LineEdit
	if name_input:
		name_input.select_all_on_focus = true
		name_input.text_changed.connect(_on_player_name_changed)

	_add_debug_button()


# DEBUG: pula Game Center e lobby, com bots (some quando GameManager.DEBUG_BOTS = 0)
func _add_debug_button() -> void:
	if GameManager.DEBUG_BOTS <= 0:
		return
	var dbg := Button.new()
	dbg.text = "DEBUG SOLO"
	dbg.position = Vector2(20, 20)
	dbg.z_index = 100
	dbg.pressed.connect(GameManager.debug_start_solo)
	add_child(dbg)


func _on_player_name_changed(new_name: String) -> void:
	GameManager.player_name = new_name.strip_edges()

	print("Nome digitado: ", GameManager.player_name)
	GameManager._save_profile()

	print("Salvamento solicitado.")


func _find_node_by_name(node: Node, node_name: String) -> Node:
	if node.name == node_name:
		return node
	for child in node.get_children():
		var found = _find_node_by_name(child, node_name)
		if found:
			return found
	return null


# Procura o modal de "Conectando..." (o nó cujo script tem show_modal)
func _find_loading_modal(node: Node = null) -> Node:
	if node == null:
		node = self
	for child in node.get_children():
		if child.has_method("show_modal"):
			return child
		var found = _find_loading_modal(child)
		if found:
			return found
	return null


# Falha ao entrar/criar sala: fecha o "Conectando..." e para o limite de espera
func _on_connection_failed(message: String) -> void:
	print("[LOBBY] %s" % message)
	if _join_timer:
		_join_timer.stop()
	if loadingScreen:
		loadingScreen.visible = false
	var loading_modal = _find_loading_modal()
	if loading_modal and loading_modal.has_method("hide_modal"):
		loading_modal.hide_modal()


func _start_join_timeout() -> void:
	if _join_timer == null:
		_join_timer = Timer.new()
		_join_timer.one_shot = true
		_join_timer.timeout.connect(_on_join_timeout)
		add_child(_join_timer)   # morre junto com a cena (sem await solto)
	_join_timer.start(JOIN_TIMEOUT_SECONDS)


func _on_join_timeout() -> void:
	if GameManager.current_match != null:
		return
	GameManager.cancel_join()
	_on_connection_failed("Não encontrei essa sala. Confira o código e tente de novo.")


## HOST: Gera o código de 1 a 9999
func _on_create_room_pressed() -> void:
	# Gera um código estritamente de 4 dígitos (1000 a 9999)
	var generated_code: int = randi_range(1000, 9999)
	print("Código gerado para a sala: %d" % generated_code)

	GameManager.current_room_code = generated_code

	# Só entra na tela de configurar sala se a busca realmente começou.
	# Sem isso, o host ficava com um código que ninguém estava procurando.
	if GameManager.join_room_with_code(generated_code, true):
		GameManager.change_scene("res://scenes/create_room.tscn")


## GUEST: Abre o modal
func _on_open_join_modal_pressed() -> void:
	if code_modal:
		code_modal.visible = true


func _show_avatar() -> void:
	var avatar_screen = _find_node_by_name(self, "AvatarScreen")
	if avatar_screen:
		avatar_screen.load_from_saved()
	if avatar_panel:
		avatar_panel.visible = true


func _show_settings() -> void:
	if configuration_panel:
		configuration_panel.visible = true


func _show_tutorial() -> void:
	if tutorial_panel:
		tutorial_panel.visible = true


## GUEST: Confirma o código
func _on_confirm_join_pressed() -> void:
	var input_field = _find_node_by_name(self, "RoomCodeInput") as LineEdit
	if input_field:
		var typed_text: String = input_field.text.strip_edges()

		if typed_text.is_valid_int() and typed_text.to_int() > 0:
			var entered_code: int = typed_text.to_int()
			print("Procurando sala com o código: %d" % entered_code)

			GameManager.current_room_code = entered_code

			if code_modal:
				code_modal.visible = false

			#mostrando tela de aguardando entrar na sala
			if loadingScreen:
				loadingScreen.visible = true

			# Retorno visual imediato enquanto o Game Center conecta
			var loading_modal = _find_loading_modal()
			if loading_modal:
				loading_modal.show_modal("Conectando à sala %d..." % entered_code)
				
			# Inicia a busca no Game Center. 
			# A TROCA DE CENA PARA O LOBBY FOI REMOVIDA DAQUI E AGORA É FEITA PELO GAMEMANAGER QUANDO A REDE CONECTAR.
			GameManager.join_room_with_code(entered_code, false)
		else:
			input_field.placeholder_text = "Código Inválido!"
			input_field.text = ""


func _apply_profile() -> void:
	var name_input = _find_node_by_name(self, "PlayerNameInput") as LineEdit
	if name_input:
		name_input.text = GameManager.player_name

	var avatar = _find_node_by_name(self, "Avatar") as TextureRect
	if avatar:
		avatar.texture = GameManager.player_character

	var character_background = _find_node_by_name(self, "CharacterBackground") as Button
	if character_background:
		for shape in ["normal", "hover", "pressed", "focus"]:
			var style = character_background.get_theme_stylebox(shape).duplicate()

			if style is StyleBoxFlat:
				style.bg_color = GameManager.player_background
				character_background.add_theme_stylebox_override(shape, style)


func _on_customization_confirmed(_nickname: String, _character: Texture2D, _background: Color) -> void:
	_apply_profile()
