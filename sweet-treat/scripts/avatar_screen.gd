extends Control

signal customization_confirmed(nickname, character, background)

@onready var avatar_button = $MarginContainer/HBoxContainer/VBoxContainer2/HBoxContainer/AvatarButton
@onready var backgound_button = $MarginContainer/HBoxContainer/VBoxContainer2/HBoxContainer/BackgroundButton
@onready var preview_panel = $MarginContainer/HBoxContainer/VBoxContainer/Panel
@onready var selected_character = $MarginContainer/HBoxContainer/VBoxContainer/Panel/SelectedCharacter
@onready var name_input = $MarginContainer/HBoxContainer/VBoxContainer/LineEdit

@onready var preview_style = preview_panel.get_theme_stylebox("panel").duplicate()

# Botões da primeira linha
@onready var line1 = [
	$MarginContainer/HBoxContainer/VBoxContainer2/Panel/VBoxContainer/HBoxContainer/CharacterButton,
	$MarginContainer/HBoxContainer/VBoxContainer2/Panel/VBoxContainer/HBoxContainer/CharacterButton2,
	$MarginContainer/HBoxContainer/VBoxContainer2/Panel/VBoxContainer/HBoxContainer/CharacterButton3,
	$MarginContainer/HBoxContainer/VBoxContainer2/Panel/VBoxContainer/HBoxContainer/CharacterButton4,
	$MarginContainer/HBoxContainer/VBoxContainer2/Panel/VBoxContainer/HBoxContainer/CharacterButton5
]

# Botões da segunda linha
@onready var line2 = [
	$MarginContainer/HBoxContainer/VBoxContainer2/Panel/VBoxContainer/HBoxContainer2/CharacterButton,
	$MarginContainer/HBoxContainer/VBoxContainer2/Panel/VBoxContainer/HBoxContainer2/CharacterButton2,
	$MarginContainer/HBoxContainer/VBoxContainer2/Panel/VBoxContainer/HBoxContainer2/CharacterButton3,
	$MarginContainer/HBoxContainer/VBoxContainer2/Panel/VBoxContainer/HBoxContainer2/CharacterButton4,
	$MarginContainer/HBoxContainer/VBoxContainer2/Panel/VBoxContainer/HBoxContainer2/CharacterButton5
]

# Junta os dez botões em uma única lista
var options = []

# Substitua os caminhos pelos caminhos reais dos seus SVGs

var current_mode = "avatar"
var current_character = null
var current_backgound = null

var selected_character_index = 0
var selected_background_index = 0


func _ready():
	print("AvatarButton: ", avatar_button)
	print("BackgroundButton: ", backgound_button)
	
	print("Avatar válido: ", is_instance_valid(avatar_button))
	print("Background válido: ", is_instance_valid(backgound_button))
	
	var close_button = get_node("MarginContainer/CloseButton")
	close_button.pressed.connect(_on_close_button_pressed)
	
	options = line1 + line2
	
	name_input.max_length = 12
	
	for botao in options:
		botao.toggle_mode = true
	

	avatar_button.toggle_mode = true
	backgound_button.toggle_mode = true

	avatar_button.pressed.connect(_enable_avatar)
	backgound_button.pressed.connect(_enable_background)

	for i in range(options.size()):
		options[i].pressed.connect(_select_option.bind(i))

	for i in range(options.size()):
		options[i].pressed.connect(_select_option.bind(i))

	load_from_saved()
	
	var finish_button = find_child("FinishButton", true, false)

	if finish_button:
		finish_button.pressed.connect(_on_finish_button_pressed)


func _enable_avatar():
	current_mode = "avatar"

	avatar_button.set_pressed_no_signal(true)
	backgound_button.set_pressed_no_signal(false)

	_update_options()


func _enable_background():
	current_mode = "fundo"

	avatar_button.set_pressed_no_signal(false)
	backgound_button.set_pressed_no_signal(true)

	_update_options()


func _select_option(indice):
	if current_mode == "avatar":
		selected_character_index = indice
		current_character = GameManager.characters[indice]
		selected_character.texture = current_character

	else:
		selected_background_index = indice
		current_backgound = GameManager.backgrounds[indice]
		preview_style.bg_color = current_backgound
		preview_panel.add_theme_stylebox_override("panel", preview_style)

	_update_options()

func _update_options():
	for i in range(options.size()):
		var botao = options[i]
		var imagem = botao.get_node("TextureCharacter")
		var fundo = botao.get_node("TextureColor")

		botao.set_pressed_no_signal(false)

		if current_mode == "avatar":
			botao.restore_color()
			imagem.texture = GameManager.characters[i]
			imagem.show()
			fundo.hide()

			if i == selected_character_index:
				botao.set_pressed_no_signal(true)

		else:
			botao.definir_cor(GameManager.backgrounds[i])
			fundo.hide()
			imagem.hide()

			if i == selected_background_index:
				botao.set_pressed_no_signal(true)

func _on_close_button_pressed() -> void:
	var avatar_panel = get_tree().root.find_child("AvatarPanel", true, false)
	
	if avatar_panel:
		avatar_panel.visible = false


func load_from_saved() -> void:
	selected_character_index = GameManager.player_character_index
	selected_background_index = GameManager.player_background_index
	current_character = GameManager.characters[selected_character_index]
	current_backgound = GameManager.backgrounds[selected_background_index]

	selected_character.texture = current_character
	preview_style.bg_color = current_backgound
	preview_panel.add_theme_stylebox_override("panel", preview_style)

	name_input.text = GameManager.player_name

	current_mode = "avatar"
	avatar_button.set_pressed_no_signal(true)
	backgound_button.set_pressed_no_signal(false)
	_update_options()


func _on_finish_button_pressed() -> void:
	var nickname = name_input.text.strip_edges()

	if nickname.is_empty():
		nickname = GameManager.player_name

	GameManager.player_name = nickname
	GameManager.player_character_index = selected_character_index
	GameManager.player_background_index = selected_background_index
	GameManager.player_character = current_character
	GameManager.player_background = current_backgound

	customization_confirmed.emit(nickname, current_character, current_backgound)

	var avatar_panel = get_tree().root.find_child("AvatarPanel", true, false)
	if avatar_panel:
		avatar_panel.visible = false
