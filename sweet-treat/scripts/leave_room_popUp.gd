extends Control

signal confirmed
signal cancelled

@onready var message_label: Label = _find_message_label()
@onready var cancel_button: BaseButton = _find_button("DarkBlueButton")
@onready var confirm_button: BaseButton = _find_button("DarkBlueButton2")


func _find_message_label() -> Label:
	var n = find_child("Label2", true, false)
	if n == null:
		n = find_child("MessageLabel", true, false)
	return n as Label


func _find_button(node_name: String) -> BaseButton:
	var n = find_child(node_name, true, false)
	return n as BaseButton


func _ready() -> void:
	if cancel_button and not cancel_button.pressed.is_connected(_on_cancel_pressed):
		cancel_button.pressed.connect(_on_cancel_pressed)

	if confirm_button and not confirm_button.pressed.is_connected(_on_confirm_pressed):
		confirm_button.pressed.connect(_on_confirm_pressed)


# Define o texto da mensagem dinamicamente
func set_message(text: String) -> void:
	if message_label:
		message_label.text = text
	else:
		# Se a Label ainda não foi carregada pelo @onready, aguarda o _ready
		call_deferred("_apply_message_text", text)


func _apply_message_text(text: String) -> void:
	if message_label:
		message_label.text = text


func _on_cancel_pressed() -> void:
	emit_signal("cancelled")
	queue_free()


func _on_confirm_pressed() -> void:
	emit_signal("confirmed")

	if GameManager.has_method("leave_room"):
		GameManager.leave_room()

	GameManager.change_scene("res://scenes/main_menu.tscn")
	queue_free()
