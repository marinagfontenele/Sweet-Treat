#all_answers.gd
extends Node

var answer_slots: Array = []
var selected_target_id: String = ""
var has_voted: bool = false
var is_revealing: bool = false

@onready var vote_button: Button = $MarginContainer/VBoxContainer/PlayButton

func _ready() -> void:
	_collect_answer_containers(self)

	if vote_button:
		vote_button.text = "Votar"
		vote_button.disabled = true
		vote_button.pressed.connect(_on_confirm_vote_pressed)

	if not GameManager.resposta_recebida.is_connected(update_answers_ui):
		GameManager.resposta_recebida.connect(update_answers_ui)

	if not GameManager.vote_received.is_connected(_check_all_votes_received):
		GameManager.vote_received.connect(_check_all_votes_received)

	if not GameManager.force_reveal_results.is_connected(_on_force_reveal):
		GameManager.force_reveal_results.connect(_on_force_reveal)

	_setup_initial_ui()
	_run_round_timer()


func _collect_answer_containers(node: Node) -> void:
	if node is AspectRatioContainer and node.has_node("PlayerAnswer"):
		answer_slots.append(node)
	for child in node.get_children():
		_collect_answer_containers(child)


func _setup_initial_ui() -> void:
	var answers: Array = GameManager.get_current_round_answers()

	for i in range(answer_slots.size()):
		var container = answer_slots[i]
		var player_answer_node = container.get_node("PlayerAnswer")

		if i >= answers.size():
			container.visible = false
			continue

		container.visible = true
		var data: Dictionary = answers[i]
		var target_player_id = str(data.get("id", ""))

		var name_label = player_answer_node.get_node_or_null("VBoxContainer/Label")
		var answer_label = player_answer_node.get_node_or_null("VBoxContainer/MarginContainer/AspectRatioContainer/Panel/MarginContainer/Label")
		var target_icon = player_answer_node.get_node_or_null("VBoxContainer/MarginContainer/AspectRatioContainer/Panel/MarginContainer/TextureRect")

		if name_label:
			name_label.visible = false
			name_label.text = str(data.get("player", "Jogador"))
		
		if answer_label:
			answer_label.text = str(data.get("answer", ""))

		if target_icon:
			target_icon.visible = false

		if player_answer_node is BaseButton:
			player_answer_node.pressed.connect(func(): _on_card_selected(target_player_id, target_icon))


func update_answers_ui() -> void:
	pass


func _on_card_selected(target_player_id: String, active_icon: TextureRect) -> void:
	if has_voted or is_revealing:
		return

	selected_target_id = target_player_id

	for container in answer_slots:
		var target_icon = container.get_node_or_null("PlayerAnswer/VBoxContainer/MarginContainer/AspectRatioContainer/Panel/MarginContainer/TextureRect")
		if target_icon:
			target_icon.visible = (target_icon == active_icon)

	if vote_button:
		vote_button.disabled = false


func _on_confirm_vote_pressed() -> void:
	if has_voted or selected_target_id == "" or is_revealing:
		return

	has_voted = true
	vote_button.disabled = true
	vote_button.text = "Aguardando outros jogadores..."

	GameManager.send_my_vote(selected_target_id)
	_check_all_votes_received()


func _check_all_votes_received() -> void:
	if is_revealing:
		return

	var total_expected = GameManager.get_expected_players_count()
	var current_votes = GameManager.votes_by_round.get(GameManager.current_question_index, {}).size()

	# Se todos votaram, quem detectou primeiro envia a ordem para todos revelarem juntos
	if current_votes >= total_expected:
		if GameManager.is_host or not GameManager.current_match:
			GameManager.send_force_reveal_results()
		_reveal_results_and_penalties()


func _run_round_timer() -> void:
	var display_seconds: float = float(GameManager.config_vote_time)
	await get_tree().create_timer(display_seconds).timeout

	# Se o tempo esgotar e ainda não revelou, força a revelação geral
	if is_inside_tree() and not is_revealing:
		if GameManager.is_host or not GameManager.current_match:
			GameManager.send_force_reveal_results()
		_reveal_results_and_penalties()


func _on_force_reveal(_r_idx: int) -> void:
	_reveal_results_and_penalties()


func _reveal_results_and_penalties() -> void:
	if is_revealing:
		return
	is_revealing = true

	var penalties = GameManager.calculate_round_penalties(GameManager.current_question_index)
	var answers: Array = GameManager.get_current_round_answers()

	for i in range(answers.size()):
		if i >= answer_slots.size():
			break

		var data: Dictionary = answers[i]
		var pid = str(data.get("id", ""))
		var container = answer_slots[i]
		var player_answer_node = container.get_node("PlayerAnswer")

		var name_label = player_answer_node.get_node_or_null("VBoxContainer/Label")
		if name_label:
			name_label.visible = true

		var tomatoes_added = penalties.get(pid, 0)
		var tomato_badge = player_answer_node.get_node_or_null("VBoxContainer/MarginContainer/AspectRatioContainer/Panel/TomatoBadge")
		
		if tomato_badge:
			if tomatoes_added > 0:
				tomato_badge.visible = true
				if tomato_badge is Label:
					tomato_badge.text = "+%d" % tomatoes_added
			else:
				tomato_badge.visible = false

	# Pausa de 4 segundos para ler os resultados na tela
	await get_tree().create_timer(8.0).timeout
	if not is_inside_tree():
		return

	if GameManager.advance_to_next_question():
		GameManager.change_scene("res://scenes/show_question.tscn")
	else:
		GameManager.change_scene("res://scenes/worst_result_screen.tscn")
