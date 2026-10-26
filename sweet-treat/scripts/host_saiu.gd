extends CanvasLayer

@export var message_label: Label
@export var animation_player: AnimationPlayer


func _ready() -> void:
	layer = 100
	visible = false

	if message_label == null:
		message_label = _find_label(self)

	_ignore_mouse(self)


func _ignore_mouse(node: Node) -> void:
	for child in node.get_children():
		if child is Control and not (child is BaseButton):
			child.mouse_filter = Control.MOUSE_FILTER_IGNORE

		_ignore_mouse(child)


func _find_label(node: Node) -> Label:
	if node is Label:
		return node

	for child in node.get_children():
		var found: Label = _find_label(child)

		if found != null:
			return found

	return null


func show_notice(message: String) -> void:
	if message_label == null:
		message_label = _find_label(self)

	if message_label != null:
		message_label.text = message

	visible = true

	if animation_player != null and animation_player.has_animation("show"):
		animation_player.play("show")


func hide_notice() -> void:
	if animation_player != null and animation_player.is_playing():
		animation_player.stop()

	visible = false
