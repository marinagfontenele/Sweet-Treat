extends Node

## =====================================================================
## SINAIS DE REDE PARA REATIVIDADE DAS TELAS
## =====================================================================
signal lobby_updated
signal resposta_recebida

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

# Dicionário para sincronizar IDs do GameCenter e Nomes: [player_id: nome_exibicao]
var connected_players_names: Dictionary = {}

## =====================================================================
## CONFIGURAÇÕES DA SALA (DEFINIDAS PELO HOST)
## =====================================================================

var config_questions_per_player: int = 1
var config_answer_time: int = 30
var config_vote_time: int = 15

## =====================================================================
## GERENCIAMENTO DE PERGUNTAS E RESPOSTAS DA PARTIDA
## =====================================================================

var my_created_questions: Array = []
var all_received_questions: Array = []
var game_questions: Array = []
var current_question_index: int = 0
var players_submitted_questions: int = 0

# Armazena as respostas da rodada atual: [{ "player": "Nome", "answer": "Texto" }]
var current_round_answers: Array = []

## =====================================================================
## FUNÇÕES PADRÃO DO CICLO DE VIDA E UTILITÁRIOS GERAIS
## =====================================================================

var characters = [
	preload("res://assets/images/characters/character1.svg"),
	preload("res://assets/images/characters/character2.svg"),
	preload("res://assets/images/characters/character3.svg"),
	preload("res://assets/images/characters/character4.svg"),
	preload("res://assets/images/characters/character5.svg"),
	preload("res://assets/images/characters/character6.svg"),
	preload("res://assets/images/characters/character7.svg"),
	preload("res://assets/images/characters/character8.svg"),
	preload("res://assets/images/characters/character9.svg"),
	preload("res://assets/images/characters/character10.svg")
]

var backgrounds = [
	Color("#FF0040"),
	Color("#47C65F"),
	Color("#EC92E7"),
	Color("#45FAFD"),
	Color("#7E2DF7"),
	Color("#01ABEA"),
	Color("#1746E2"),
	Color("#001046"),
	Color("#FFDA38"),
	Color("#F23FBF")
]

const DEFAULT_CHARACTER: Texture2D = preload("res://assets/images/characters/character1.svg")
const DEFAULT_BACKGROUND: Color = Color("#FF0040")

var player_character_index: int = 0
var player_background_index: int = 0
var player_character: Texture2D = DEFAULT_CHARACTER
var player_background: Color = DEFAULT_BACKGROUND

## =====================================================================
## FUNÇÕES PADRÃO DO CICLO DE VIDA E UTILITÁRIOS GERAIS
## =====================================================================

func _ready() -> void:
	if player_name == "":
		player_name = "Jogador_%d" % randi_range(10, 99)

func change_scene(scene: String) -> void:
	get_tree().change_scene_to_file(scene)

func add_score(quant: int) -> void:
	tomato += quant


## =====================================================================
## AUTENTICAÇÃO E GERENCIAMENTO DE SALAS VIA APPLE GAME CENTER
## =====================================================================

func authenticate() -> void:
	game_center = GameCenterManager.new()

	game_center.authentication_error.connect(func(error: String) -> void:
		print("Erro de autenticação Game Center: %s" % error)
	)
	
	game_center.authentication_result.connect(func(status: bool) -> void:
		print("Status de autenticação: %s" % status)
		if status and game_center.local_player:
			local = game_center.local_player
			local.register_listener()
	)
	game_center.authenticate()


func join_room_with_code(room_code: int, am_i_host: bool) -> void:
	if game_center == null or game_center.local_player == null:
		print("Erro: Jogador não autenticado no Game Center!")
		return
		
	is_host = am_i_host
	current_room_code = room_code
	connected_players_names.clear()
	
	var req := GKMatchRequest.new()
	req.max_players = 4 
	req.min_players = 2
	req.player_group = room_code
	
	print("Buscando/Criando sala no Game Center (Player Group): %d..." % room_code)
	
	matchmaker = GKMatchmaker.new()
	matchmaker.find_match(req, func(game_match: GKMatch, error: Variant) -> void:
		if error != null:
			print("Matchmaker falhou com erro: %s" % str(error))
			return
			
		if game_match != null:
			print("Partida estabelecida com sucesso via Game Center!")
			call_deferred("_configurar_partida", game_match)
	)


func _configurar_partida(game_match: GKMatch) -> void:
	current_match = game_match
	RenderingServer.set_default_clear_color(Color("#1e7e34"))
	
	game_match.data_received.connect(func(data: PackedByteArray, from_player: GKPlayer) -> void:
		call_deferred("_processar_pacote_rede", data, from_player)
	)
	
	game_match.data_received_for_recipient_from_player.connect(func(data: PackedByteArray, _for_recipient: GKPlayer, from_remote_player: GKPlayer) -> void:
		call_deferred("_processar_pacote_rede", data, from_remote_player)
	)
	
	game_match.player_changed.connect(func(_player: GKPlayer, _connected: bool) -> void:
		_enviar_handshake_nome()
		call_deferred("_notificar_atualizacao_lobby")
	)

	# Registra o id e nome local
	var my_id = local.game_player_id if local else "local_" + str(randi())
	connected_players_names[my_id] = player_name if player_name != "" else "Jogador"

	# Notifica a rede enviando handshake
	_enviar_handshake_nome()

	# REGRA CRÍTICA DE NAVEGAÇÃO:
	# Se for Convidado, transiciona para o lobby ao conectar.
	# Se for Host, NÃO toca na cena (o Host navega ao clicar no botão de avançar).
	if not is_host:
		if get_tree().current_scene and get_tree().current_scene.scene_file_path != "res://scenes/lobby_room.tscn":
			call_deferred("change_scene", "res://scenes/lobby_room.tscn")
	else:
		call_deferred("_notificar_atualizacao_lobby")


func _enviar_handshake_nome() -> void:
	var my_id = local.game_player_id if local else "local"
	var packet = {
		"type": "player_info",
		"id": my_id,
		"name": player_name if player_name != "" else "Jogador"
	}
	_enviar_pacote_json(packet)


func _processar_pacote_rede(data: PackedByteArray, _from_player: GKPlayer = null) -> void:
	var text = data.get_string_from_utf8()
	var json = JSON.new()
	var error = json.parse(text)
	
	if error == OK:
		var dict = json.get_data()
		if dict is Dictionary and dict.has("type"):
			
			match dict["type"]:
				"player_info":
					var p_id = dict.get("id", "")
					var p_name = dict.get("name", "Jogador")
					connected_players_names[p_id] = p_name
					print("Player conectado identificado via rede: %s" % p_name)
					emit_signal("lobby_updated")

				"player_questions":
					var remote_questions = dict["questions"]
					for q in remote_questions:
						if not game_questions.has(q):
							game_questions.append(q)
					
				"player_answer":
					var remote_player = dict.get("player", "Jogador")
					var remote_answer = dict.get("answer", "")
					
					var entry = { "player": remote_player, "answer": remote_answer }
					
					var ja_existe = false
					for ans in current_round_answers:
						if ans["player"] == remote_player and ans["answer"] == remote_answer:
							ja_existe = true
							break
					
					if not ja_existe:
						current_round_answers.append(entry)
						print("Nova resposta recebida via rede de %s: %s" % [remote_player, remote_answer])
						emit_signal("resposta_recebida")
					
				"official_game_questions":
					game_questions = dict["questions"]
					
				"start_game":
					print("Host iniciou o jogo! Convidado trocando de cena...")
					call_deferred("change_scene", "res://scenes/create_questions.tscn")


func _notificar_atualizacao_lobby() -> void:
	emit_signal("lobby_updated")
	var current_scene = get_tree().current_scene
	if current_scene and current_scene.has_method("update_lobby_ui"):
		current_scene.update_lobby_ui()


func _enviar_pacote_json(packet: Dictionary) -> void:
	if current_match:
		var json_string = JSON.stringify(packet)
		var data: PackedByteArray = json_string.to_utf8_buffer()
		current_match.send_data_to_all_players(data, GKMatch.SendDataMode.RELIABLE)


## =====================================================================
## FLUXO DE ENVIO DE PERGUNTAS E RESPOSTAS
## =====================================================================

func send_my_questions_to_others() -> void:
	if current_match == null:
		game_questions = my_created_questions.duplicate()
		game_questions.shuffle()
		return

	_enviar_pacote_json({
		"type": "player_questions",
		"questions": my_created_questions
	})
	
	for q in my_created_questions:
		if not game_questions.has(q):
			game_questions.append(q)

func host_finalize_and_shuffle_questions() -> void:
	if not is_host:
		return
		
	game_questions.shuffle()
	_enviar_pacote_json({
		"type": "official_game_questions",
		"questions": game_questions
	})

func send_my_answer(answer_text: String) -> void:
	var player_nickname = player_name if player_name != "" else "Jogador"
	var local_entry = { "player": player_nickname, "answer": answer_text }
	
	var ja_existe = false
	for ans in current_round_answers:
		if ans["player"] == player_nickname and ans["answer"] == answer_text:
			ja_existe = true
			break
			
	if not ja_existe:
		current_round_answers.append(local_entry)
	
	_enviar_pacote_json({
		"type": "player_answer",
		"player": player_nickname,
		"answer": answer_text
	})


## =====================================================================
## MÉTODOS DE APOIO E HELPERS
## =====================================================================

func get_current_question() -> String:
	if game_questions.is_empty():
		return "Qual a melhor sobremesa?"
	if current_question_index < game_questions.size():
		return game_questions[current_question_index]
	return game_questions[0]

func get_current_round_answers() -> Array:
	return current_round_answers

func clear_round_answers() -> void:
	current_round_answers.clear()
