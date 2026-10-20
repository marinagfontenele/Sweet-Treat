extends Node

# Array para guardar os containers visuais de cada resposta na tela
var answer_slots: Array = []

func _ready() -> void:
	# 1. Coleta todos os containers de resposta na árvore da cena
	_collect_answer_containers(self)

	# 2. Conecta o sinal reativo para atualizar a tela automaticamente
	# sempre que uma nova resposta chegar pela rede do Game Center
	if not GameManager.resposta_recebida.is_connected(update_answers_ui):
		GameManager.resposta_recebida.connect(update_answers_ui)

	# 3. Preenche os cartões com as respostas que já estão salvas na memória
	update_answers_ui()

	print("Tela de respostas pronta! Total de slots encontrados: %d" % answer_slots.size())


# Função recursiva para achar os AspectRatioContainers que contêm os PlayerAnswer
func _collect_answer_containers(node: Node) -> void:
	if node is AspectRatioContainer and node.has_node("PlayerAnswer"):
		answer_slots.append(node)
	for child in node.get_children():
		_collect_answer_containers(child)


# Preenche os slots com as respostas reais
func update_answers_ui() -> void:
	var current_round_answers = GameManager.get_current_round_answers()
	print("Atualizando UI de respostas. Total acumulado até agora: %d" % current_round_answers.size())
	
	for i in range(answer_slots.size()):
		var container = answer_slots[i]
		var player_answer_node = container.get_node("PlayerAnswer")
		
		if i < current_round_answers.size():
			var data = current_round_answers[i]
			container.visible = true
			
			# 1. Pega os nós específicos de nome e resposta no PlayerAnswer
			var player_name_label: Label = player_answer_node.get_node_or_null("VBoxContainer/Label")
			var answer_label: Label = player_answer_node.get_node_or_null("VBoxContainer/MarginContainer/AspectRatioContainer/Panel/Label")
			
			# 2. Atualiza os textos na tela
			if player_name_label:
				player_name_label.text = data.get("player", "Jogador")
			if answer_label:
				answer_label.text = data.get("answer", "")
				
			# 3. Configura o clique no botão para registrar o voto
			if player_answer_node is BaseButton:
				# Desconecta closures/funções antigas antes de reconectar para evitar votos duplicados
				if player_answer_node.pressed.is_connected(_on_vote_pressed):
					player_answer_node.pressed.disconnect(_on_vote_pressed)
				
				player_answer_node.pressed.connect(func(): _on_vote_pressed(data["player"]))
		else:
			# Esconde slots excedentes se houverem menos respostas que o total de slots
			container.visible = false


# Função executada quando o jogador clica em uma resposta para votar
func _on_vote_pressed(target_player: String) -> void:
	print("Você votou na resposta de: %s" % target_player)
	
	# Registra o voto se necessário
	# GameManager.register_vote(target_player)
	
	# Avança para a próxima etapa
	GameManager.change_scene("res://scenes/most_voted.tscn")
