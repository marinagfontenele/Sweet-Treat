extends Node

# Array para guardar os containers visuais de cada resposta na tela
var answer_slots: Array = []

func _ready() -> void:
	# 1. Coleta todos os containers de resposta na árvore da cena
	_collect_answer_containers(self)

	# 2. Preenche os cartões com as respostas da rodada atual
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
	# Mock ou lista de respostas da rodada atual vindas do GameManager
	var current_round_answers = GameManager.get_current_round_answers() 
	
	for i in range(answer_slots.size()):
		var container = answer_slots[i]
		var player_answer_node = container.get_node("PlayerAnswer")
		
		if i < current_round_answers.size():
			var data = current_round_answers[i]
			container.visible = true
			
			# Procura o componente de texto (Label) dentro do PlayerAnswer para mostrar a resposta
			var text_label = _find_label_in_node(player_answer_node)
			if text_label:
				text_label.text = data["answer"]
				
			# Configura o clique no botão para registrar o voto
			if player_answer_node is BaseButton:
				if not player_answer_node.pressed.is_connected(_on_vote_pressed):
					player_answer_node.pressed.connect(func(): _on_vote_pressed(data["player"]))
		else:
			# Esconde slots excedentes se houverem menos respostas que o total de slots
			container.visible = false


# Função executada quando o jogador clica em uma resposta para votar
func _on_vote_pressed(target_player: String) -> void:
	print("Você votou na resposta de: %s" % target_player)
	
	# Aqui podes salvar o voto no GameManager se precisares
	# GameManager.register_vote(target_player)
	
	# Avança para a próxima etapa (ex: mostrar quem ganhou mais votos)
	GameManager.change_scene("res://scenes/most_voted.tscn")


# Função auxiliar para achar uma Label dentro do componente
func _find_label_in_node(node: Node) -> Label:
	if node is Label:
		return node
	for child in node.get_children():
		var found = _find_label_in_node(child)
		if found:
			return found
	return null
