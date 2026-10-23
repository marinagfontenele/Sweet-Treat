extends Node


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


func set_panel_colors(
	background_color: Color,
	border_color: Color,
	label_background_color: Color,
	label_border_color: Color
) -> void:
	
	var panel = $VBoxContainer/ColorPanel
	var panel_style = panel.get_theme_stylebox("panel").duplicate() as StyleBoxFlat

	panel_style.bg_color = background_color
	panel_style.border_color = border_color

	panel.add_theme_stylebox_override("panel", panel_style)

	var label = $VBoxContainer/PlayerName as Label

	var label_style = label.get_theme_stylebox("normal").duplicate() as StyleBoxFlat

	label_style.bg_color = label_background_color
	label_style.border_color = label_border_color

	label.add_theme_stylebox_override("normal", label_style)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
