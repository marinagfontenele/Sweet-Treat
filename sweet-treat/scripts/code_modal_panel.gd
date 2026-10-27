extends Panel

const KeyboardPreview = preload("res://scripts/keyboard_preview.gd")

@onready var answer_input = get_node_or_null("BluePanel/MarginContainer/RoomCodeInput")

func _ready() -> void:
	if answer_input:
		KeyboardPreview.new().attach_to(self, answer_input)
