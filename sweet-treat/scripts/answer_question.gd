#answer_question.gd
extends Node

const KeyboardPreview = preload("res://scripts/keyboard_preview.gd")

const WAIT_SCENE := "res://scenes/answer_formulation_wait.tscn"

const URGENT_SECONDS := 10                      # a partir daqui o timer fica vermelho
#const TIMER_URGENT_COLOR := Color("#EB4A50")    # mesmo vermelho da tela de votação

@onready var question_label = _find_question_label()
@onready var timer_label = get_node_or_null("MarginContainer/Label2")
@onready var answer_input = get_node_or_null("MarginContainer/VBoxContainer/LineEdit")
@onready var play_button = get_node_or_null("MarginContainer/VBoxContainer/PlayButton")

@onready var normal_time: LabelSettings = preload("res://resources/normal_time.tres")
@onready var red_time: LabelSettings = preload("res://resources/red_time.tres")

var _answer_sent: bool = false
var _time_left: float = 30.0
var _last_shown_second: int = -1


func _find_question_label():
	var n = get_node_or_null("MarginContainer/VBoxContainer/TextureRect/MarginContainer/Label")
	if n == null:
		n = find_child("Label", true, false)
	return n


func _ready() -> void:
	_answer_sent = false
	_time_left = float(GameManager.config_answer_time)
	_update_timer_label()

	if question_label:
		question_label.text = GameManager.get_current_question()
	else:
		push_error("Label da pergunta não encontrado em answer_question!")

	if play_button and not play_button.pressed.is_connected(_on_play_pressed):
		play_button.pressed.connect(_on_play_pressed)
	elif play_button == null:
		push_error("PlayButton não encontrado em answer_question!")

	if answer_input and not answer_input.text_submitted.is_connected(_on_text_submitted):
		answer_input.text_submitted.connect(_on_text_submitted)
		# Barra acima do teclado mostrando o que está sendo digitado
		KeyboardPreview.new().attach_to(self, answer_input)

	print("Responder pronta (rodada %d, %ds): %s" % [GameManager.current_question_index, GameManager.config_answer_time, GameManager.get_current_question()])

	GameManager.debug_bots_answer()   # DEBUG: não faz nada fora do modo bots


func _process(delta: float) -> void:
	if _answer_sent:
		return

	_time_left -= delta
	if _time_left <= 0.0:
		_time_left = 0.0
		_update_timer_label()
		_submit_answer(true)
		return

	if int(ceil(_time_left)) != _last_shown_second:
		_update_timer_label()


func _update_timer_label() -> void:
	var sec: int = int(ceil(_time_left))
	_last_shown_second = sec

	if timer_label:
		timer_label.text = "%d:%02d" % [
			floori(sec / 60.0),
			sec % 60
		]

		if sec <= URGENT_SECONDS:
			timer_label.label_settings = red_time
		else:
			timer_label.label_settings = normal_time


func _on_play_pressed() -> void:
	_submit_answer(false)


func _on_text_submitted(_text: String) -> void:
	_submit_answer(false)


# forced = true quando o tempo acabou (envia o que estiver digitado)
func _submit_answer(forced: bool) -> void:
	if _answer_sent:
		return

	var text: String = ""
	if answer_input:
		text = answer_input.text.strip_edges()

	# Tempo acabou sem nada digitado: conta como "não respondeu" (2 tomates,
	# card desabilitado na votação). O texto do card vem da tela de votação.
	var no_answer := false
	if text.is_empty():
		if not forced:
			if answer_input:
				answer_input.placeholder_text = "Digite uma resposta antes de enviar!"
			return
		no_answer = true

	_answer_sent = true
	GameManager.send_my_answer(text, no_answer)
	GameManager.call_deferred("change_scene", WAIT_SCENE)
