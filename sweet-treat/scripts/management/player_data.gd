class_name PlayerData
extends RefCounted


var player_id: int
var player_name: String
var avatar_index: int = 0
var background_index: int = 0
var is_host: bool = false

var questions_created: Array[QuestionData] = []
var tomatoes: int = 0


func _init(id: int, name: String, host: bool = false) -> void:
	player_id = id
	player_name = name
	is_host = host

func add_question(question: QuestionData) -> void:
	questions_created.append(question)
