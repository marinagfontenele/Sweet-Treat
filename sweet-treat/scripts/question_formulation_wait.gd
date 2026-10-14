extends Node

func _ready():
	await get_tree().create_timer(3.0).timeout
	GameManager.change_scene("res://scenes/show_question.tscn")
	
