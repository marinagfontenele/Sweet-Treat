extends Node

const KeyboardPreview = preload("res://scripts/keyboard_preview.gd")

# Nós da cena (com busca automática caso o caminho exato mude)
@onready var progress_bar = _find_progress_bar()
@onready var progress_label = get_node_or_null("MarginContainer/VBoxContainer/VBoxContainer/Label")
@onready var input_question = _find_line_edit()

# Botões: detectados pelo nome/texto (Voltar / Próxima / Enviar)
var back_button: BaseButton = null
var next_button: BaseButton = null
var send_button: BaseButton = null

var total_questions: int = 1
var current_index: int = 0
var questions: Array = []
var _finished: bool = false


func _ready() -> void:
	_finished = false
	total_questions = maxi(1, GameManager.config_questions_per_player)
	current_index = 0
	questions.clear()
	for i in range(total_questions):
		questions.append("")
	GameManager.my_created_questions.clear()

	_detect_buttons()

	if progress_bar:
		progress_bar.min_value = 0
		progress_bar.max_value = total_questions
		progress_bar.value = 0

	if back_button:
		back_button.pressed.connect(_on_back_pressed)
	if next_button:
		next_button.pressed.connect(_on_next_pressed)
	if send_button:
		send_button.pressed.connect(_on_send_pressed)

	if input_question:
		input_question.text_submitted.connect(_on_text_submitted)
		input_question.text_changed.connect(_on_text_changed)
		# Barra acima do teclado mostrando o que está sendo digitado
		KeyboardPreview.new().attach_to(self, input_question)

	_refresh()
	print("create_questions pronta: %d perguntas. Voltar=%s Próxima=%s Enviar=%s" % [
		total_questions, _name_of(back_button), _name_of(next_button), _name_of(send_button)])


func _name_of(n: Node) -> String:
	return String(n.name) if n else "nenhum"


# ---------------------------------------------------------------------
# Descoberta de nós
# ---------------------------------------------------------------------
func _find_progress_bar():
	var n = get_node_or_null("MarginContainer/VBoxContainer/VBoxContainer/ProgressBar/ProgressBar")
	if n == null:
		n = _find_first_of_class(self, "ProgressBar")
	return n


func _find_line_edit():
	var n = get_node_or_null("MarginContainer/VBoxContainer/VBoxContainer2/LineEdit")
	if n == null:
		n = _find_first_of_class(self, "LineEdit")
	return n


func _find_first_of_class(node: Node, cls: String):
	for child in node.get_children():
		if child.is_class(cls):
			return child
		var found = _find_first_of_class(child, cls)
		if found:
			return found
	return null


func _collect_buttons(node: Node, out: Array) -> void:
	for child in node.get_children():
		if child is BaseButton:
			out.append(child)
		_collect_buttons(child, out)


func _button_text(b: Node) -> String:
	var t = b.get("text")
	if t is String and t != "":
		return t
	var stack: Array = [b]
	while not stack.is_empty():
		var cur: Node = stack.pop_front()
		if cur is Label:
			return cur.text
		for c in cur.get_children():
			stack.append(c)
	return ""


func _has_any(s: String, words: Array) -> bool:
	for w in words:
		if s.contains(w):
			return true
	return false


func _detect_buttons() -> void:
	var all: Array = []
	_collect_buttons(self, all)
	for b in all:
		var key: String = (String(b.name) + " " + _button_text(b)).to_lower()
		if _has_any(key, ["voltar", "back", "anterior", "prev"]):
			back_button = b
		elif _has_any(key, ["próxima", "proxima", "avançar", "avancar", "next", "seguinte"]):
			next_button = b
		elif _has_any(key, ["enviar", "send", "play"]):
			send_button = b

	if send_button == null:
		send_button = get_node_or_null("MarginContainer/VBoxContainer/VBoxContainer2/PlayButton")


# ---------------------------------------------------------------------
# Estado da tela
# ---------------------------------------------------------------------
func _is_last() -> bool:
	return current_index >= total_questions - 1


func _filled_count() -> int:
	var c := 0
	for i in range(total_questions):
		var t: String = questions[i]
		if i == current_index and input_question:
			t = input_question.text.strip_edges()
		if not t.is_empty():
			c += 1
	return c


func _update_progress() -> void:
	if progress_bar:
		progress_bar.value = _filled_count()


func _refresh() -> void:
	if progress_label:
		progress_label.text = "Pergunta %d de %d" % [current_index + 1, total_questions]

	if input_question:
		input_question.placeholder_text = ""
		input_question.text = questions[current_index]
		input_question.caret_column = input_question.text.length()

	var two_buttons := next_button != null

	if back_button:
		back_button.disabled = current_index == 0

	if two_buttons:
		next_button.visible = not _is_last()
		if send_button:
			send_button.visible = _is_last()
	elif send_button and "text" in send_button:
		# Só existe um botão: ele avança e, na última pergunta, envia
		send_button.text = "Enviar" if _is_last() else "Próxima"

	_update_progress()


func _save_current() -> void:
	if input_question:
		questions[current_index] = input_question.text.strip_edges()


func _warn_empty() -> void:
	if input_question:
		input_question.placeholder_text = "Por favor, digite uma pergunta válida!"


# ---------------------------------------------------------------------
# Ações
# ---------------------------------------------------------------------
func _on_text_changed(_new_text: String) -> void:
	_update_progress()


func _on_text_submitted(_text: String) -> void:
	_primary_action()


func _primary_action() -> void:
	if _is_last():
		_on_send_pressed()
	else:
		_on_next_pressed()


func _on_back_pressed() -> void:
	if _finished or current_index == 0:
		return
	_save_current()
	current_index -= 1
	_refresh()


func _on_next_pressed() -> void:
	if _finished or _is_last():
		return
	if input_question and input_question.text.strip_edges().is_empty():
		_warn_empty()
		return
	_save_current()
	current_index += 1
	_refresh()


func _on_send_pressed() -> void:
	if _finished:
		return

	# Com um botão só, ele funciona como "Próxima" até a última pergunta
	if not _is_last():
		_on_next_pressed()
		return

	if input_question and input_question.text.strip_edges().is_empty():
		_warn_empty()
		return
	_save_current()

	# Confere se alguma pergunta anterior ficou vazia (editada com "Voltar")
	for i in range(total_questions):
		if String(questions[i]).is_empty():
			current_index = i
			_refresh()
			_warn_empty()
			return

	_finished = true
	GameManager.my_created_questions = questions.duplicate()
	GameManager.send_my_questions_to_others()
	print("Perguntas enviadas: %s" % str(questions))
	call_deferred("go_to_question_formulation_wait")


func go_to_question_formulation_wait() -> void:
	GameManager.change_scene("res://scenes/question_formulation_wait.tscn")
