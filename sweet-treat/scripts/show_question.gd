extends Node

func _ready():
	await get_tree().create_timer(8.0).timeout
	GameManager.change_scene("res://scenes/answer_question.tscn")
