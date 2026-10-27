#show_question.gd
extends Control

# Mapeamento dos nós da sua cena
@onready var label_rodada_atual: Label = _find_node_by_name("RodadaAtual")
@onready var label_total_rodadas: Label = _find_node_by_name("TotalRodadas")
@onready var question_label: Label = _find_node_by_name("Label2")

@export var display_seconds: float = 6.0

var _started: bool = false
var _transition_timer: Timer = null


func _ready() -> void:
	_update_round_labels()

	# Se as perguntas já estão montadas no GameManager, exibe imediatamente
	if not GameManager.game_questions.is_empty():
		_show_and_start()
	else:
		if question_label:
			question_label.text = "Carregando pergunta..."

		if not GameManager.questions_synced.is_connected(_show_and_start):
			GameManager.questions_synced.connect(_show_and_start, CONNECT_ONE_SHOT)

		# Fallback de 1.5s para não travar a tela caso o sinal de rede já tenha passado
		_create_fallback_timer()


func _find_node_by_name(node_name: String) -> Label:
	var path_exact = "TextureRect/MarginContainer/TextureRect/MarginContainer/VBoxContainer/HBoxContainer/" + node_name
	var found = get_node_or_null(path_exact)
	if found == null and node_name == "Label2":
		found = get_node_or_null("TextureRect/MarginContainer/TextureRect/MarginContainer/VBoxContainer/Label2")
	if found == null:
		found = find_child(node_name, true, false)
	return found as Label


func _create_fallback_timer() -> void:
	var fallback = Timer.new()
	fallback.wait_time = 1.5
	fallback.one_shot = true
	fallback.autostart = true
	fallback.timeout.connect(func():
		if not _started and is_inside_tree():
			_show_and_start()
		fallback.queue_free()
	)
	add_child(fallback)


func _update_round_labels() -> void:
	var total_rounds: int = GameManager.game_questions.size()
	if total_rounds == 0:
		var players_count: int = maxi(1, GameManager.get_lobby_players().size())
		total_rounds = players_count * GameManager.config_questions_per_player

	var current_round: int = GameManager.current_question_index + 1

	if label_rodada_atual:
		label_rodada_atual.text = str(current_round)

	if label_total_rodadas:
		label_total_rodadas.text = str(total_rounds)


func _show_and_start() -> void:
	if _started:
		return
	_started = true

	if GameManager.questions_synced.is_connected(_show_and_start):
		GameManager.questions_synced.disconnect(_show_and_start)

	_update_round_labels()

	var text_to_display: String = GameManager.get_current_question()
	if text_to_display.strip_edges().is_empty():
		text_to_display = "Qual é a sua resposta para esta rodada?"

	if question_label:
		question_label.text = text_to_display

	# Inicia o temporizador físico de leitura
	_start_direct_scene_timer()


func _start_direct_scene_timer() -> void:
	if _transition_timer != null:
		return

	_transition_timer = Timer.new()
	_transition_timer.wait_time = display_seconds
	_transition_timer.one_shot = true
	_transition_timer.autostart = true
	_transition_timer.timeout.connect(_go_to_answer_screen)
	add_child(_transition_timer)


func _go_to_answer_screen() -> void:
	var target_path: String = "res://scenes/answer_question.tscn"

	if ResourceLoader.exists(target_path):
		var next_scene = load(target_path) as PackedScene
		if next_scene:
			get_tree().change_scene_to_packed(next_scene)
			return

	GameManager.change_scene(target_path)
