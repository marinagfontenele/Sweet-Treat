extends Control

# Modal "Conectando à sala..." exibido ao convidado enquanto o Game Center
# encontra a partida. Substitui o script atual do nó do modal.

@export var status_label: Label
@export var close_button: BaseButton

func _ready() -> void:
	visible = false

	if close_button and not close_button.pressed.is_connected(_on_close_pressed):
		close_button.pressed.connect(_on_close_pressed)

	if not GameManager.lobby_updated.is_connected(_on_lobby_connected):
		GameManager.lobby_updated.connect(_on_lobby_connected)

	if not GameManager.connection_failed.is_connected(_on_connection_failed):
		GameManager.connection_failed.connect(_on_connection_failed)


func show_modal(message: String = "Conectando à sala...") -> void:
	if status_label:
		status_label.text = message
	visible = true


func hide_modal() -> void:
	visible = false


func _on_close_pressed() -> void:
	hide_modal()
	GameManager.cancel_join()


# Só fecha quando a partida de fato existe (e a troca para o lobby acontece em seguida)
func _on_lobby_connected() -> void:
	if GameManager.current_match != null:
		hide_modal()


func _on_connection_failed(message: String) -> void:
	if status_label:
		status_label.text = message
	visible = true
