extends Node

## =====================================================================
## SINAIS DE REDE PARA REATIVIDADE DAS TELAS
## =====================================================================
signal lobby_updated
signal resposta_recebida
signal questions_synced
signal connection_failed(message)

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

# [player_id: nome_exibicao]
var connected_players_names: Dictionary = {}
# [player_id: { name, character, background, host }]
var connected_players_profiles: Dictionary = {}

var _fallback_id: String = "local_" + str(randi())

## =====================================================================
## CONFIGURAÇÕES DA SALA (DEFINIDAS PELO HOST)
## =====================================================================

var config_questions_per_player: int = 1
var config_answer_time: int = 30
var config_vote_time: int = 15

## =====================================================================
## PERGUNTAS E RESPOSTAS DA PARTIDA
## =====================================================================

var my_created_questions: Array = []
# Perguntas agrupadas por jogador: { player_id: [perguntas] }
var questions_by_player: Dictionary = {}
# Lista usada pelas telas. Antes do embaralhamento oficial é só um acumulado.
var game_questions: Array = []
var questions_finalized: bool = false
var current_question_index: int = 0

# { indice_da_rodada: { player_id: { "id", "player", "answer" } } }
var answers_by_round: Dictionary = {}


## =====================================================================
## FUNÇÕES PADRÃO DO CICLO DE VIDA E UTILITÁRIOS GERAIS
## =====================================================================

const SAVE_PATH = "user://player_profile.cfg"

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

var player_character_index: int = randi_range(0, characters.size() - 1)
var player_background_index: int = randi_range(0, backgrounds.size() - 1)

var DEFAULT_CHARACTER: Texture2D = characters[player_character_index]
var DEFAULT_BACKGROUND: Color = backgrounds[player_background_index]

var player_character: Texture2D = DEFAULT_CHARACTER
var player_background: Color = DEFAULT_BACKGROUND

func _ready() -> void:
	var perfil_carregado = _load_profile()

	if player_name.strip_edges() == "":
		player_name = "Jogador_%d" % randi_range(10, 99)

	if not perfil_carregado:
		_save_profile()


func _save_profile() -> void:
	var config = ConfigFile.new()

	config.set_value("perfil", "nome", player_name)
	config.set_value("perfil", "personagem", player_character_index)
	config.set_value("perfil", "fundo", player_background_index)

	var error = config.save(SAVE_PATH)

	if error != OK:
		print("Erro ao salvar perfil: ", error)


func _load_profile() -> bool:
	var config = ConfigFile.new()

	var error = config.load(SAVE_PATH)

	if error != OK:
		return false

	player_name = config.get_value("perfil", "nome", player_name)

	player_character_index = clampi(
		config.get_value("perfil", "personagem", player_character_index),
		0,
		characters.size() - 1
	)

	player_background_index = clampi(
		config.get_value("perfil", "fundo", player_background_index),
		0,
		backgrounds.size() - 1
	)

	player_character = characters[player_character_index]
	player_background = backgrounds[player_background_index]

	return true


func change_scene(scene: String) -> void:
	get_tree().change_scene_to_file(scene)

func add_score(quant: int) -> void:
	tomato += quant

func _my_id() -> String:
	if local != null and str(local.game_player_id) != "":
		return str(local.game_player_id)
	return _fallback_id

func _my_name() -> String:
	return player_name if player_name != "" else "Jogador"

# Registra o jogador local na lista da sala (sem esperar a partida do Game Center)
func register_local_player(notify: bool = true) -> void:
	var my_id := _my_id()
	connected_players_names[my_id] = _my_name()
	connected_players_profiles[my_id] = {
		"name": _my_name(),
		"character": player_character_index,
		"background": player_background_index,
		"host": is_host
	}
	if notify:
		emit_signal("lobby_updated")


# Chamado quando o jogador muda nome/avatar estando numa sala
func refresh_local_profile() -> void:
	if current_room_code == 0:
		return
	register_local_player()
	_enviar_handshake_nome()


# Lista ordenada para o lobby: Host primeiro, depois por id (igual em todos os aparelhos)
func get_lobby_players() -> Array:
	var out: Array = []
	for pid in connected_players_profiles.keys():
		var p: Dictionary = connected_players_profiles[pid].duplicate()
		p["id"] = pid
		out.append(p)
	out.sort_custom(func(a, b):
		if a["host"] != b["host"]:
			return a["host"]
		return str(a["id"]) < str(b["id"])
	)
	return out


# Cancela a tentativa de entrar numa sala (botão fechar do modal de conexão)
func cancel_join() -> void:
	if matchmaker != null and matchmaker.has_method("cancel"):
		matchmaker.cancel()
	current_room_code = 0
	connected_players_names.clear()
	connected_players_profiles.clear()


func reset_match_state() -> void:
	my_created_questions.clear()
	questions_by_player.clear()
	game_questions.clear()
	questions_finalized = false
	current_question_index = 0
	answers_by_round.clear()


## =====================================================================
## AUTENTICAÇÃO E SALAS VIA APPLE GAME CENTER
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
		emit_signal("connection_failed", "Não foi possível conectar ao Game Center. Tente novamente.")
		return

	is_host = am_i_host
	current_room_code = room_code
	connected_players_names.clear()
	connected_players_profiles.clear()

	if local == null:
		local = game_center.local_player
	register_local_player(false)

	var req := GKMatchRequest.new()
	req.max_players = 4
	req.min_players = 2
	req.player_group = room_code

	print("Buscando/Criando sala no Game Center (Player Group): %d..." % room_code)

	matchmaker = GKMatchmaker.new()
	matchmaker.find_match(req, func(game_match: GKMatch, error: Variant) -> void:
		if error != null:
			print("Matchmaker falhou com erro: %s" % str(error))
			call_deferred("emit_signal", "connection_failed", "Falha ao conectar na sala. Tente novamente.")
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

	register_local_player()
	_enviar_handshake_nome()

	# Convidado vai para o lobby ao conectar; o Host navega pelo botão.
	if not is_host:
		if get_tree().current_scene and get_tree().current_scene.scene_file_path != "res://scenes/lobby_room.tscn":
			call_deferred("change_scene", "res://scenes/lobby_room.tscn")
	else:
		call_deferred("_notificar_atualizacao_lobby")


func _enviar_handshake_nome() -> void:
	_enviar_pacote_json({
		"type": "player_info",
		"id": _my_id(),
		"name": _my_name(),
		"character": player_character_index,
		"background": player_background_index,
		"host": is_host
	})


func _processar_pacote_rede(data: PackedByteArray, _from_player: GKPlayer = null) -> void:
	var text = data.get_string_from_utf8()
	var json = JSON.new()
	var error = json.parse(text)
	if error != OK:
		return

	var dict = json.get_data()
	if not (dict is Dictionary and dict.has("type")):
		return

	match dict["type"]:
		"player_info":
			var p_id = str(dict.get("id", ""))
			var p_name = str(dict.get("name", "Jogador"))
			connected_players_names[p_id] = p_name
			connected_players_profiles[p_id] = {
				"name": p_name,
				"character": clampi(int(dict.get("character", 0)), 0, characters.size() - 1),
				"background": clampi(int(dict.get("background", 0)), 0, backgrounds.size() - 1),
				"host": bool(dict.get("host", false))
			}
			print("Jogador identificado na sala: %s" % p_name)
			emit_signal("lobby_updated")

		"room_config":
			config_questions_per_player = int(dict.get("questions_per_player", 1))
			config_answer_time = int(dict.get("answer_time", 30))
			config_vote_time = int(dict.get("vote_time", 15))
			print("Configurações via rede: %d perguntas/jogador." % config_questions_per_player)

		"start_game":
			print("Host iniciou o jogo!")
			reset_match_state()
			# A configuração vem junto do comando (não depende da ordem dos pacotes)
			if dict.has("questions_per_player"):
				config_questions_per_player = int(dict.get("questions_per_player", 1))
				config_answer_time = int(dict.get("answer_time", config_answer_time))
				config_vote_time = int(dict.get("vote_time", config_vote_time))
				print("Config recebida no start_game: %d perguntas/jogador." % config_questions_per_player)
			call_deferred("change_scene", "res://scenes/create_questions.tscn")

		"player_questions":
			var sender_id = str(dict.get("id", ""))
			var remote_questions = dict.get("questions", [])
			if sender_id != "" and remote_questions is Array:
				questions_by_player[sender_id] = remote_questions
				_rebuild_game_questions()
				print("Perguntas recebidas de %s. Total acumulado: %d" % [sender_id, get_total_questions_received()])
			emit_signal("lobby_updated")

		"official_game_questions":
			var official = dict.get("questions", [])
			if official is Array and not official.is_empty():
				game_questions = official
				questions_finalized = true
				print("Lista oficial sincronizada: %s" % str(game_questions))
				emit_signal("questions_synced")

		"start_display_questions":
			# A lista vem junto do comando para evitar corrida entre pacotes.
			var official_list = dict.get("questions", [])
			if official_list is Array and not official_list.is_empty():
				game_questions = official_list
				questions_finalized = true
			current_question_index = 0
			emit_signal("questions_synced")
			print("Host liberou a exibição de perguntas!")
			call_deferred("change_scene", "res://scenes/show_question.tscn")

		"player_answer":
			var remote_player = str(dict.get("player", "Jogador"))
			var remote_answer = str(dict.get("answer", ""))
			var remote_id = str(dict.get("id", remote_player))
			var remote_round = int(dict.get("round", current_question_index))
			if _store_answer(remote_round, remote_id, remote_player, remote_answer):
				print("Resposta (rodada %d) de %s: %s" % [remote_round, remote_player, remote_answer])
				emit_signal("resposta_recebida")


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
## FLUXO DE CRIAÇÃO E ENVIO DE PERGUNTAS
## =====================================================================

func _rebuild_game_questions() -> void:
	# Depois da lista oficial (embaralhada) não reconstruímos mais.
	if questions_finalized:
		return
	game_questions.clear()
	for pid in questions_by_player.keys():
		for q in questions_by_player[pid]:
			game_questions.append(q)

func get_total_questions_received() -> int:
	var total := 0
	for pid in questions_by_player.keys():
		total += questions_by_player[pid].size()
	return total


func send_my_questions_to_others() -> void:
	questions_by_player[_my_id()] = my_created_questions.duplicate()
	_rebuild_game_questions()

	if current_match == null:
		# Modo local/teste sem rede
		game_questions = my_created_questions.duplicate()
		game_questions.shuffle()
		questions_finalized = true
		emit_signal("lobby_updated")
		return

	_enviar_pacote_json({
		"type": "player_questions",
		"id": _my_id(),
		"questions": my_created_questions
	})
	emit_signal("lobby_updated")


func host_start_game() -> void:
	if not is_host:
		return

	reset_match_state()

	_enviar_pacote_json({
		"type": "room_config",
		"questions_per_player": config_questions_per_player,
		"answer_time": config_answer_time,
		"vote_time": config_vote_time
	})
	_enviar_pacote_json({
		"type": "start_game",
		"questions_per_player": config_questions_per_player,
		"answer_time": config_answer_time,
		"vote_time": config_vote_time
	})

	print("Host iniciando jogo com %d perguntas/jogador." % config_questions_per_player)
	call_deferred("change_scene", "res://scenes/create_questions.tscn")


func host_finalize_and_shuffle_questions() -> void:
	if not is_host:
		return
	questions_finalized = false
	_rebuild_game_questions()
	game_questions.shuffle()
	questions_finalized = true
	current_question_index = 0
	print("Lista final embaralhada pelo Host: %s" % str(game_questions))


func host_start_question_display() -> void:
	if not is_host:
		return

	host_finalize_and_shuffle_questions()

	_enviar_pacote_json({
		"type": "official_game_questions",
		"questions": game_questions
	})
	_enviar_pacote_json({
		"type": "start_display_questions",
		"questions": game_questions
	})

	call_deferred("change_scene", "res://scenes/show_question.tscn")


## =====================================================================
## RESPOSTAS (guardadas por rodada e por jogador)
## =====================================================================

func _store_answer(round_idx: int, player_id: String, player: String, answer: String) -> bool:
	if not answers_by_round.has(round_idx):
		answers_by_round[round_idx] = {}
	var round_answers: Dictionary = answers_by_round[round_idx]
	if round_answers.has(player_id):
		return false
	round_answers[player_id] = { "id": player_id, "player": player, "answer": answer }
	return true


func send_my_answer(answer_text: String) -> void:
	var nickname := _my_name()
	_store_answer(current_question_index, _my_id(), nickname, answer_text)
	emit_signal("resposta_recebida")

	_enviar_pacote_json({
		"type": "player_answer",
		"id": _my_id(),
		"round": current_question_index,
		"player": nickname,
		"answer": answer_text
	})


# Respostas da rodada atual, em ordem estável (por id) para todos os aparelhos
func get_current_round_answers() -> Array:
	var out: Array = []
	if answers_by_round.has(current_question_index):
		var round_answers: Dictionary = answers_by_round[current_question_index]
		var ids: Array = round_answers.keys()
		ids.sort()
		for k in ids:
			out.append(round_answers[k])
	return out


func get_current_answers_count() -> int:
	if answers_by_round.has(current_question_index):
		return answers_by_round[current_question_index].size()
	return 0


func get_expected_players_count() -> int:
	return maxi(1, connected_players_names.size())


func clear_round_answers() -> void:
	answers_by_round.erase(current_question_index)


## =====================================================================
## RODADAS E HELPERS
## =====================================================================

func has_next_question() -> bool:
	return current_question_index + 1 < game_questions.size()


# Avança para a próxima pergunta. Retorna false se não houver mais.
func advance_to_next_question() -> bool:
	if not has_next_question():
		return false
	current_question_index += 1
	return true


func get_current_question() -> String:
	if game_questions.is_empty():
		return ""
	if current_question_index < game_questions.size():
		return str(game_questions[current_question_index])
	return str(game_questions[0])
