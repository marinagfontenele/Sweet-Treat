extends Node

## =====================================================================
## VARIÁVEIS GLOBAIS DE ESTADO E REDE (GAME CENTER)
## =====================================================================

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

## =====================================================================
## CONFIGURAÇÕES DA SALA (DEFINIDAS PELO HOST)
## =====================================================================

var config_questions_per_player: int = 1
var config_answer_time: int = 30
var config_vote_time: int = 15

## =====================================================================
## GERENCIAMENTO DE PERGUNTAS E RESPOSTAS DA PARTIDA
## =====================================================================

# Armazenamento das perguntas criadas pelo jogador local nesta partida
var my_created_questions: Array = []

# Armazenamento para receber as perguntas enviadas pelos outros jogadores via rede
var all_received_questions: Array = []

# Lista final com todas as perguntas da partida misturadas
var game_questions: Array = []
var current_question_index: int = 0

# Contador para saber quantos jogadores já enviaram as perguntas
var players_submitted_questions: int = 0

# Armazena as respostas da rodada atual enviadas pelos participantes: [{ "player": "Nome", "answer": "Texto" }]
var current_round_answers: Array = []


## =====================================================================
## FUNÇÕES PADRÃO DO CICLO DE VIDA E UTILITÁRIOS GERAIS
## =====================================================================

func _ready() -> void:
	pass

func _process(_delta: float) -> void:
	pass

# Altera a cena atual de forma global no jogo
func change_scene(scene: String) -> void:
	get_tree().change_scene_to_file(scene)

# Adiciona pontos de pontuação genérica (tomate)
func add_score(quant: int) -> void:
	tomato += quant


## =====================================================================
## AUTENTICAÇÃO E GERENCIAMENTO DE SALAS VIA APPLE GAME CENTER
## =====================================================================

# Inicia o processo de autenticação do jogador no Game Center
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

# Inicia a busca ou criação de sala baseada em um código numérico (Player Group)
func join_room_with_code(room_code: int, am_i_host: bool) -> void:
	if game_center == null or game_center.local_player == null:
		print("Erro: O jogador ainda não foi autenticado no Game Center!")
		return
		
	is_host = am_i_host
	current_room_code = room_code
	
	var req = GKMatchRequest.new()
	req.max_players = 4 
	req.min_players = 2
	req.player_group = room_code # O código numérico agrupa os jogadores na mesma sala
	
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


## =====================================================================
## CONFIGURAÇÃO DE REDE E SINCRONIZAÇÃO DE PACOTES ENTRE JOGADORES
## =====================================================================

# Função auxiliar para conectar os eventos de dados e sinais da partida ativa
func _configurar_partida(game_match: GKMatch) -> void:
	current_match = game_match
	RenderingServer.set_default_clear_color(Color("#1e7e34"))
	
	# Evento principal que recebe dados enviados por qualquer jogador da sala
	game_match.data_received.connect(func(data: PackedByteArray, _from_player: GKPlayer) -> void:
		print("Dados brutos recebidos da rede...")
		
		var text = data.get_string_from_utf8()
		var json = JSON.new()
		var error = json.parse(text)
		
		if error == OK:
			var dict = json.get_data()
			if dict is Dictionary and dict.has("type"):
				
				# 1. Tratamento: Recebimento de perguntas criadas por um jogador
				if dict["type"] == "player_questions":
					var remote_questions = dict["questions"]
					for q in remote_questions:
						if not game_questions.has(q):
							game_questions.append(q)
					print("Perguntas recebidas! Total acumulado: %d" % game_questions.size())
				
				# 2. Tratamento: Recebimento de resposta digitada por um participante na rodada
				elif dict["type"] == "player_answer":
					var remote_player = dict["player"]
					var remote_answer = dict["answer"]
	
					var entry = { "player": remote_player, "answer": remote_answer }
					if not current_round_answers.has(entry):
						current_round_answers.append(entry)
						print("Resposta recebida de %s: %s" % [remote_player, remote_answer])
					
				# 3. Tratamento: Recebimento da lista oficial embaralhada enviada pelo Host
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

# Funções auxiliares de teste de contador por rede
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


## =====================================================================
## FLUXO DE ENVIO DE PERGUNTAS E RESPOSTAS
## =====================================================================

# Envia as perguntas criadas pelo jogador local para todos na sala
func send_my_questions_to_others() -> void:
	if current_match == null:
		game_questions = my_created_questions.duplicate()
		game_questions.shuffle()
		return

	var packet = {
		"type": "player_questions",
		"questions": my_created_questions
	}
	
	var json_string = JSON.stringify(packet)
	var data: PackedByteArray = json_string.to_utf8_buffer()
	
	current_match.send_data_to_all_players(data, GKMatch.SendDataMode.RELIABLE)
	
	for q in my_created_questions:
		if not game_questions.has(q):
			game_questions.append(q)

# Processa dados que chegam isoladamente da rede do tipo "player_questions"
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

# Apenas o Host finaliza, embaralha e distribui a lista oficial de perguntas para a sala
func host_finalize_and_shuffle_questions() -> void:
	if not is_host:
		return
		
	game_questions.shuffle()
	print("Host embaralhou a lista oficial de perguntas: ", game_questions)
	
	var packet = {
		"type": "official_game_questions",
		"questions": game_questions
	}
	
	var json_string = JSON.stringify(packet)
	var data: PackedByteArray = json_string.to_utf8_buffer()
	
	if current_match:
		current_match.send_data_to_all_players(data, GKMatch.SendDataMode.RELIABLE)

# Envia a resposta digitada pelo jogador local para todos os participantes via rede
func send_my_answer(answer_text: String) -> void:
	var player_nickname = player_name if player_name != "" else "Jogador"
	
	var packet = {
		"type": "player_answer",
		"player": player_nickname,
		"answer": answer_text
	}
	
	# Adiciona a resposta local na lista da rodada
	var local_entry = { "player": player_nickname, "answer": answer_text }
	if not current_round_answers.has(local_entry):
		current_round_answers.append(local_entry)
	
	if current_match != null:
		var json_string = JSON.stringify(packet)
		var data: PackedByteArray = json_string.to_utf8_buffer()
		current_match.send_data_to_all_players(data, GKMatch.SendDataMode.RELIABLE)
		print("Resposta enviada para a rede: ", answer_text)
	else:
		print("Modo local (sem rede): Resposta salva apenas localmente.")


## =====================================================================
## MÉTODOS DE APOIO PARA AS TELAS DE JOGO (GETTERS E HELPERS)
## =====================================================================

# Retorna a pergunta da rodada atual com segurança
func get_current_question() -> String:
	if game_questions.is_empty():
		return "Qual a melhor sobremesa?"
		
	if current_question_index < game_questions.size():
		return game_questions[current_question_index]
	
	return game_questions[0]

# Retorna as respostas reais acumuladas da rodada atual para preencher a tela AllAnswers
func get_current_round_answers() -> Array:
	return current_round_answers

# Limpa o array de respostas para preparar o início de uma nova rodada/pergunta
func clear_round_answers() -> void:
	current_round_answers.clear()
