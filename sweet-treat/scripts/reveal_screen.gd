#reveal_screen.gd  ("A hora da verdade...")
# Anexe este script na raiz da cena reveal_screen.tscn.
extends Node

const NEXT_SCENE := "res://scenes/all_answers.tscn"

# Tempo de exibição antes de abrir a votação
@export var display_seconds: float = 3.0


func _ready() -> void:
	var timer := Timer.new()
	timer.one_shot = true
	timer.wait_time = display_seconds
	timer.timeout.connect(_go_to_voting)
	add_child(timer)
	timer.start()


func _go_to_voting() -> void:
	GameManager.change_scene(NEXT_SCENE)
