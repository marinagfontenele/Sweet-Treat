extends Node

const KeyboardPreview = preload("res://scripts/keyboard_preview.gd")

# =====================================================================
# AJUSTE AQUI: Caminho exato do arquivo de imagem do Check no projeto
# =====================================================================
const CHECK_TEXTURE = preload("res://assets/images/symbols/checkmark.svg") # <--- Coloque o caminho real do seu arquivo do Check aqui

# Nós da cena
@onready var progress_bar = _find_progress_bar()
@onready var progress_label = get_node_or_null("MarginContainer/VBoxContainer/VBoxContainer/Label")
@onready var input_question = _find_line_edit()

# Botões da interface
var back_button: BaseButton = null
var next_button: BaseButton = null

# Guarda a textura original da seta para alternar quando não for a última pergunta
var _original_next_texture: Texture2D = null

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

	_find_and_setup_buttons()
	_remove_hidden_button_texts()

	if progress_bar:
		progress_bar.min_value = 0
		progress_bar.max_value = total_questions
		progress_bar.value = 0

	if input_question:
		input_question.text_submitted.connect(_on_text_submitted)
		KeyboardPreview.new().attach_to(self, input_question)

	_refresh()


# ---------------------------------------------------------------------
# Mapeamento de Nós e Texturas
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


func _collect_all_buttons(node: Node, out: Array) -> void:
	for child in node.get_children():
		if child is BaseButton:
			out.append(child)
		_collect_all_buttons(child, out)


func _find_and_setup_buttons() -> void:
	var all_buttons: Array = []
	_collect_all_buttons(self, all_buttons)

	if all_buttons.size() >= 2:
		all_buttons.sort_custom(func(a, b): return a.global_position.x < b.global_position.x)
		back_button = all_buttons[0]
		next_button = all_buttons[all_buttons.size() - 1]
	elif all_buttons.size() == 1:
		next_button = all_buttons[0]

	if back_button and not back_button.pressed.is_connected(_on_back_pressed):
		back_button.pressed.connect(_on_back_pressed)
	if next_button and not next_button.pressed.is_connected(_on_next_pressed):
		next_button.pressed.connect(_on_next_pressed)

	# Salva a textura original da seta (seja TextureButton ou TextureRect filho)
	_original_next_texture = _get_button_texture(next_button)


func _get_button_texture(btn: Node) -> Texture2D:
	if btn == null:
		return null
	if btn is TextureButton and btn.texture_normal != null:
		return btn.texture_normal
	var rect = _find_first_of_class(btn, "TextureRect")
	if rect and rect.texture != null:
		return rect.texture
	return null


func _set_button_texture(btn: Node, tex: Texture2D) -> void:
	if btn == null or tex == null:
		return
	if btn is TextureButton:
		btn.texture_normal = tex
	var rect = _find_first_of_class(btn, "TextureRect")
	if rect:
		rect.texture = tex


func _remove_hidden_button_texts() -> void:
	var buttons = [back_button, next_button]
	for b in buttons:
		if b != null:
			if "text" in b:
				b.text = ""
			_hide_labels_in_node(b)


func _hide_labels_in_node(node: Node) -> void:
	for child in node.get_children():
		if child is Label:
			child.visible = false
		_hide_labels_in_node(child)


# ---------------------------------------------------------------------
# Atualização Visual dos Estados
# ---------------------------------------------------------------------
func _is_last() -> bool:
	return current_index >= total_questions - 1


func _confirmed_count() -> int:
	var count := 0
	for i in range(total_questions):
		if not String(questions[i]).strip_edges().is_empty():
			count += 1
	return count


func _update_progress() -> void:
	if progress_bar:
		progress_bar.value = _confirmed_count()


func _refresh() -> void:
	if progress_label:
		progress_label.text = "Pergunta %d de %d" % [current_index + 1, total_questions]

	if input_question:
		input_question.placeholder_text = ""
		input_question.text = questions[current_index]
		input_question.caret_column = input_question.text.length()

	# Botão Voltar desabilitado na 1ª pergunta
	if back_button:
		back_button.disabled = (current_index == 0) or _finished

	# Botão Avançar / Enviar
	if next_button:
		next_button.disabled = _finished
		
		# Troca dinâmica da imagem entre Seta e Check
		if _is_last():
			if CHECK_TEXTURE:
				_set_button_texture(next_button, CHECK_TEXTURE)
		else:
			if _original_next_texture:
				_set_button_texture(next_button, _original_next_texture)

	_update_progress()


func _save_current() -> void:
	if input_question:
		questions[current_index] = input_question.text.strip_edges()


func _warn_empty() -> void:
	if input_question:
		input_question.placeholder_text = "Por favor, digite uma pergunta válida!"


# ---------------------------------------------------------------------
# Fluxo e Ações
# ---------------------------------------------------------------------
func _on_text_submitted(_text: String) -> void:
	_handle_advance_or_send()


func _on_back_pressed() -> void:
	if _finished or current_index == 0:
		return
	_save_current()
	current_index -= 1
	_refresh()


func _on_next_pressed() -> void:
	_handle_advance_or_send()


func _handle_advance_or_send() -> void:
	if _finished:
		return

	if input_question and input_question.text.strip_edges().is_empty():
		_warn_empty()
		return

	_save_current()

	if not _is_last():
		current_index += 1
		_refresh()
		return

	_on_send_pressed()


func _on_send_pressed() -> void:
	for i in range(total_questions):
		if String(questions[i]).is_empty():
			current_index = i
			_refresh()
			_warn_empty()
			return

	_finished = true
	_update_progress()

	if input_question:
		input_question.editable = false

	if back_button:
		back_button.disabled = true

	if next_button:
		next_button.disabled = true

	GameManager.my_created_questions = questions.duplicate()
	GameManager.send_my_questions_to_others()

	await get_tree().create_timer(0.6).timeout
	go_to_question_formulation_wait()


func go_to_question_formulation_wait() -> void:
	GameManager.change_scene("res://scenes/question_formulation_wait.tscn")
