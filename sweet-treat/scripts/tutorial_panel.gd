extends Node

@onready var leftButton: Button = $BluePanel/MarginContainer/HBoxContainer/LeftButton
@onready var rightButton: Button = $BluePanel/MarginContainer/HBoxContainer/RightButton
@onready var right_button_texture: TextureRect = $BluePanel/MarginContainer/HBoxContainer/RightButton/TextureRect
@onready var close_button: Button = $BluePanel/MarginContainer/CloseButton

@onready var pages: Array[VBoxContainer] = [
	$BluePanel/MarginContainer/MarginContainer/Page1,
	$BluePanel/MarginContainer/MarginContainer/Page2,
	$BluePanel/MarginContainer/MarginContainer/Page3,
	$BluePanel/MarginContainer/MarginContainer/Page4,
	$BluePanel/MarginContainer/MarginContainer/Page5
]

var current_page: int = 0

@export var final_page_texture: Texture2D = preload("res://assets/images/symbols/checkmark.svg")

func _ready() -> void:
	leftButton.pressed.connect(_previous_page)
	rightButton.pressed.connect(_on_right_button_pressed)
	close_button.pressed.connect(_on_close_pressed)

	_update_page()


func _on_right_button_pressed() -> void:
	if current_page == pages.size() - 1:
		_on_close_pressed()
	else:
		_next_page()


func _next_page() -> void:
	if current_page < pages.size() - 1:
		current_page += 1
		_update_page()


func _previous_page() -> void:
	if current_page > 0:
		current_page -= 1
		_update_page()


func _update_page() -> void:
	for i in range(pages.size()):
		pages[i].visible = (i == current_page)

	leftButton.visible = current_page > 0
	close_button.visible = current_page < 4

	if current_page == pages.size() - 1:
		right_button_texture.texture = final_page_texture
	else:
		right_button_texture.texture = preload("res://assets/images/symbols/arrow_right.svg")
	


func _on_close_pressed() ->void:
	var tutorial_panel = get_tree().root.find_child("TutorialPanel", true, false)
	if tutorial_panel:
		tutorial_panel.visible = false
	
	current_page = 0
	_update_page()
