extends Node


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	
	$MarginContainer/HBoxContainer/PodiumPlayer.set_panel_colors(
	Color("#FF3549"), Color("#C30000"), Color("#FF0040"),Color("#870000"))
	
	$MarginContainer/HBoxContainer/PodiumPlayer2.set_panel_colors(
	Color("#FF3549"), Color("#C30000"), Color("#FF0040"),Color("#870000"))
	
	$MarginContainer/HBoxContainer/PodiumPlayer3.set_panel_colors(
	Color("#FF3549"), Color("#C30000"), Color("#FF0040"),Color("#870000"))


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
