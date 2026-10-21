extends Control

# Na cena, o texto da pergunta está no nó "Label2" (instância de screen_title),
# bem fundo na hierarquia. O antigo "$Label" não existia e retornava null.
@onready var question_label = _find_question_label()

var _started: bool = false

func _find_question_label():
	var n = get_node_or_null("TextureRect/MarginContainer/TextureRect/MarginContainer/Label2")
	if n == null:
		n = find_child("Label2", true, false)
	return n


func _ready() -> void:
	if question_label == null:
		push_error("Label da pergunta não encontrado em show_question!")

	if GameManager.game_questions.is_empty():
		if question_label:
			question_label.text = "Carregando pergunta..."
		if not GameManager.questions_synced.is_connected(_show_and_start):
			GameManager.questions_synced.connect(_show_and_start, CONNECT_ONE_SHOT)
	else:
		_show_and_start()


func _show_and_start() -> void:
	if _started:
		return
	_started = true

	var text_to_display: String = GameManager.get_current_question()
	if question_label:
		question_label.text = text_to_display

	print("Exibindo pergunta %d: %s" % [GameManager.current_question_index, text_to_display])

	await get_tree().create_timer(8.0).timeout
	if not is_inside_tree():
		return
	GameManager.change_scene("res://scenes/answer_question.tscn")
