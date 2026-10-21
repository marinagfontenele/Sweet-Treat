extends Node

# A votação ainda não existe: ao tocar numa resposta nada acontece.
const VOTING_ENABLED := false

var answer_slots: Array = []

func _ready() -> void:
	_collect_answer_containers(self)

	if not GameManager.resposta_recebida.is_connected(update_answers_ui):
		GameManager.resposta_recebida.connect(update_answers_ui)

	update_answers_ui()
	print("all_answers pronta (rodada %d). Slots: %d" % [GameManager.current_question_index, answer_slots.size()])

	_run_round_timer()


# Exibe as respostas por alguns segundos e depois vai para a próxima pergunta.
# Na última pergunta, permanece nesta tela.
func _run_round_timer() -> void:
	var display_seconds: float = float(GameManager.config_vote_time)
	await get_tree().create_timer(display_seconds).timeout
	if not is_inside_tree():
		return

	if GameManager.advance_to_next_question():
		print("Indo para a pergunta %d" % GameManager.current_question_index)
		GameManager.change_scene("res://scenes/show_question.tscn")
	else:
		print("Fim das perguntas: permanecendo na exibição das últimas respostas.")


func _collect_answer_containers(node: Node) -> void:
	if node is AspectRatioContainer and node.has_node("PlayerAnswer"):
		answer_slots.append(node)
	for child in node.get_children():
		_collect_answer_containers(child)


func _collect_labels(node: Node, out: Array) -> void:
	if node is Label:
		out.append(node)
	for child in node.get_children():
		_collect_labels(child, out)


func update_answers_ui() -> void:
	var answers: Array = GameManager.get_current_round_answers()

	for i in range(answer_slots.size()):
		var container = answer_slots[i]
		var player_answer_node = container.get_node("PlayerAnswer")

		if i >= answers.size():
			container.visible = false
			continue

		var data: Dictionary = answers[i]
		container.visible = true

		var player_name_label = player_answer_node.get_node_or_null("VBoxContainer/Label")
		var answer_label = player_answer_node.get_node_or_null("VBoxContainer/MarginContainer/AspectRatioContainer/Panel/Label")

		if player_name_label == null or answer_label == null:
			var labels: Array = []
			_collect_labels(player_answer_node, labels)
			if labels.size() >= 2:
				if player_name_label == null:
					player_name_label = labels[0]
				if answer_label == null:
					answer_label = labels[labels.size() - 1]
			elif labels.size() == 1 and answer_label == null:
				answer_label = labels[0]

		if player_name_label:
			player_name_label.text = str(data.get("player", "Jogador"))
		if answer_label:
			answer_label.text = str(data.get("answer", ""))

		if player_answer_node is BaseButton:
			if player_answer_node.has_meta("vote_cb"):
				var old_cb: Callable = player_answer_node.get_meta("vote_cb")
				if player_answer_node.pressed.is_connected(old_cb):
					player_answer_node.pressed.disconnect(old_cb)
			var cb: Callable = _on_vote_pressed.bind(str(data.get("player", "")))
			player_answer_node.pressed.connect(cb)
			player_answer_node.set_meta("vote_cb", cb)


func _on_vote_pressed(target_player: String) -> void:
	if not VOTING_ENABLED:
		return
	print("Você votou na resposta de: %s" % target_player)
	GameManager.change_scene("res://scenes/most_voted.tscn")
