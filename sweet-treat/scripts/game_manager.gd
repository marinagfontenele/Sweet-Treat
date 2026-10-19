extends Node

var tomato: int = 0
var count: int = 0

var game_center: GameCenterManager
var local: GKLocalPlayer

var matchmaker := GKMatchmaker.new()
var current_match: GKMatch
var is_host: bool = false
var current_room_code: int = 0

var score: int = 0
var player_name: String = ""

# Configurações da Sala (definidas pelo Host)
var config_questions_per_player: int = 1
var config_answer_time: int = 30
var config_vote_time: int = 15

# Armazenamento das perguntas criadas pelo jogador local nesta partida
var my_created_questions: Array = []

# Armazenamento para receber as perguntas enviadas pelos outros jogadores via rede
var all_received_questions: Array = []

# Lista final com todas as perguntas da partida misturadas
var game_questions: Array = []
var current_question_index: int = 0

# Contador para saber quantos jogadores já enviaram as perguntas
var players_submitted_questions: int = 0

func _ready() -> void:
	pass

func change_scene(scene: String) -> void:
	get_tree().change_scene_to_file(scene)

func add_score(quant: int) -> void:
	tomato += quant

func _process(_delta: float) -> void:
	pass

func authenticate() -> void:
	game_center = GameCenterManager.new()

	game_center.authentication_error.connect(func(error: String) -> void:
		print("Received error %s" % error)
	)
	
	game_center.authentication_result.connect(func(status: bool) -> void:
		print("Authentication updated, status: %s" % status)
		if status and game_center.local_player:
			local = game_center.local_player
			local.register_listener()
			local.invite_accepted.connect(func(_player: GKPlayer, invite: GKInvite) -> void:
				matchmaker.match_for_invite(invite, func(match: GKMatch, error: Variant) -> void:
					if error:
						print("Invite match error: %s" % error)
					else:
						print("Joined invited match")
						_configurar_partida(match)
				)
			)
	)

	game_center.authenticate()


## NOVO: Inicia a busca ou criação de sala baseada em um código numérico (Player Group)
func join_room_with_code(room_code: int, am_i_host: bool) -> void:
	if game_center == null or game_center.local_player == null:
		print("Erro: O jogador ainda não foi autenticado no Game Center!")
		return
		
	is_host = am_i_host
	current_room_code = room_code
	
	var req = GKMatchRequest.new()
	req.max_players = 4 
	req.min_players = 2
	req.player_group = room_code # O código numérico agrupa os jogadores na mesma sala!
	
	print("Buscando/Criando sala com o código (Player Group): %d..." % room_code)
	
	matchmaker.find_match(req, func(game_match: GKMatch, error: Variant) -> void:
		if error:
			print("Matchmaker falhou com erro: %s" % str(error))
			return
			
		if game_match:
			print("Partida encontrada com sucesso via código de sala!")
			_configurar_partida(game_match)
			
			# Se for convidado, vai direto para a tela de lobby ao achar a sala
			if not is_host:
				call_deferred("change_scene", "res://scenes/lobby_room.tscn")
	)


# Função auxiliar para conectar os eventos de dados da partida
func _configurar_partida(game_match: GKMatch) -> void:
	current_match = game_match
	RenderingServer.set_default_clear_color(Color("#1e7e34"))
	
	# Evento que recebe dados enviados por qualquer jogador
	game_match.data_received.connect(func(data: PackedByteArray, _from_player: GKPlayer) -> void:
		print("Dados brutos recebidos da rede...")
		
		# --- CONVERTE E TRATA OS DADOS RECEBIDOS AQUI ---
		var text = data.get_string_from_utf8()
		var json = JSON.new()
		var error = json.parse(text)
		
		if error == OK:
			var dict = json.get_data()
			if dict is Dictionary and dict.has("type"):
				
				# 1. Se for o pacote de perguntas enviadas por um jogador
				if dict["type"] == "player_questions":
					var remote_questions = dict["questions"]
					for q in remote_questions:
						if not game_questions.has(q):
							game_questions.append(q)
					print("Perguntas recebidas! Total acumulado: %d" % game_questions.size())
				
				# 2. Se for a lista oficial embaralhada enviada pelo Host (O trecho que você perguntou!)
				elif dict["type"] == "official_game_questions":
					game_questions = dict["questions"]
					print("Convidado recebeu a lista oficial sincronizada!")
					
	)
	
	game_match.data_received_for_recipient_from_player.connect(func(data: PackedByteArray, _for_recipient: GKPlayer, _from_remote_player: GKPlayer) -> void:
		print("Received data from a player to another player")
		print(data.get_string_from_utf8())
		set_count(data.get_string_from_utf8().to_int())
	)
	
	game_match.did_fail_with_error.connect(func(err: String) -> void:
		print("Match failed with: %s" % err)
	)
	
	game_match.should_reinvite_disconnected_player = (func(_player: GKPlayer) -> bool:
		return true
	)
	
	game_match.player_changed.connect(func(_player: GKPlayer, connected: bool) -> void:
		print("Status of player changed to %s" % connected)
	)


func set_count(value: int) -> void:
	count = value
	print(count)
	var label := get_tree().current_scene.get_node_or_null("CountLabel") as Label
	if label:
		label.text = str(count)


func increment() -> void:
	print("increment")
	set_count(count + 1)
	var data: PackedByteArray = str(count).to_utf8_buffer()
	if current_match == null:
		return
	current_match.send_data_to_all_players(data, GKMatch.SendDataMode.RELIABLE)

## 1. Envia as perguntas criadas pelo jogador local para todos na sala
func send_my_questions_to_others() -> void:
	if current_match == null:
		# Se estiveres a testar sozinho localmente sem rede ativa, usa logo as tuas próprias perguntas
		game_questions = my_created_questions.duplicate()
		game_questions.shuffle()
		return

	# Cria um dicionário com o pacote de dados
	var packet = {
		"type": "player_questions",
		"questions": my_created_questions
	}
	
	var json_string = JSON.stringify(packet)
	var data: PackedByteArray = json_string.to_utf8_buffer()
	
	# Envia de forma confiável para todos os jogadores da partida
	current_match.send_data_to_all_players(data, GKMatch.SendDataMode.RELIABLE)
	
	# Adiciona também as do próprio host/jogador local à lista geral
	for q in my_created_questions:
		if not game_questions.has(q):
			game_questions.append(q)


## 2. Processa os dados que chegam da rede (adiciona dentro do teu data_received)
# Quando receber dados, verificamos se o tipo é "player_questions"
func handle_received_data(data: PackedByteArray) -> void:
	var text = data.get_string_from_utf8()
	var json = JSON.new()
	var error = json.parse(text)
	
	if error == OK:
		var dict = json.get_data()
		if dict is Dictionary and dict.has("type") and dict["type"] == "player_questions":
			var remote_questions = dict["questions"]
			for q in remote_questions:
				if not game_questions.has(q):
					game_questions.append(q)
			
			print("Perguntas recebidas de um jogador remoto! Total acumulado: %d" % game_questions.size())
			
# Chamado quando todos os jogadores terminarem de enviar as perguntas
func host_finalize_and_shuffle_questions() -> void:
	if not is_host:
		return # Apenas o Host faz isso para evitar conflitos de ordem!
		
	# Embaralha a lista oficial no dispositivo do Host
	game_questions.shuffle()
	print("Host embaralhou a lista oficial de perguntas: ", game_questions)
	
	# Cria um pacote para enviar a lista embaralhada para os convidados
	var packet = {
		"type": "official_game_questions",
		"questions": game_questions
	}
	
	var json_string = JSON.stringify(packet)
	var data: PackedByteArray = json_string.to_utf8_buffer()
	
	# Envia a ordem exata para todo mundo na sala
	if current_match:
		current_match.send_data_to_all_players(data, GKMatch.SendDataMode.RELIABLE)
		
		# Retorna a pergunta da rodada atual com segurança
func get_current_question() -> String:
	if game_questions.is_empty():
		return "Qual a melhor sobremesa?"
		
	if current_question_index < game_questions.size():
		return game_questions[current_question_index]
	
	return game_questions[0]


# Retorna as respostas da rodada atual para preencher a tela AllAnswers
func get_current_round_answers() -> Array:
	# Por enquanto, podes retornar uma estrutura de teste (mock) ou a lista real de respostas recolhidas
	# Exemplo estruturado: [{ "player": "Nome do Jogador", "answer": "Resposta digitada" }]
	
	# Mock temporário para testes visuais na cena AllAnswers:
	return [
		{ "player": "Jogador 1", "answer": "Abóbora com ketchup" },
		{ "player": "Jogador 2", "answer": "Pizza de chocolate com pimenta" },
		{ "player": "Você", "answer": "Sorvete derretido" }
	]
		
