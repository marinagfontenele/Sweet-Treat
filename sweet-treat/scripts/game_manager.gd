#game_manager.gd
extends Node

## =====================================================================
## SINAIS DE REDE PARA REATIVIDADE DAS TELAS
## =====================================================================
signal lobby_updated
signal resposta_recebida
signal questions_synced
signal vote_received
signal force_reveal_results(round_idx: int)   # resultado oficial da rodada pronto
signal next_round_requested(round_idx: int)   # o host mandou ir para a próxima rodada
signal connection_failed(message)

## =====================================================================
## CONSTANTES
## =====================================================================

# Máximo de jogadores pedido ao Game Center. O jogo é de 2 a 8; se o lobby
# se comportar mal com 8, volte para 4 aqui (um lugar só).
const MAX_PLAYERS := 4
const MIN_PLAYERS := 2

# Voto em branco ("Pular voto"): não conta para ninguém e não gera
# a penalidade de "não votou".
const BLANK_VOTE := "__blank__"

# Cenas do fluxo de ranking final
const SCENE_BEST := "res://scenes/best_result_screen.tscn"
const SCENE_WORST := "res://scenes/worst_result_screen.tscn"
const SCENE_OVERALL := "res://scenes/overall_ranking_screen.tscn"
const SCENE_LOBBY := "res://scenes/lobby_room.tscn"
const SCENE_MENU := "res://scenes/main_menu.tscn"

# DEBUG: quantidade de jogadores falsos para testar sem Game Center.
# 0 desliga tudo (e esconde o botão de debug do menu).
const DEBUG_BOTS := 0

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

var _auth_pending: bool = false
var _searching: bool = false
var _search_id: int = 0
var _left_match: bool = false   # true depois de "Encerrar": ignora pacotes da sala antiga

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

# { indice_da_rodada: { player_id: { "id", "player", "answer", "no_answer" } } }
var answers_by_round: Dictionary = {}

# { player_id: tomates acumulados na partida }
var player_tomatoes: Dictionary = {}

# { round_index: { voter_id: target_player_id } }
var votes_by_round: Dictionary = {}

# { round_index: { player_id: tomates daquela rodada } } resultado OFICIAL,
# aplicado uma única vez por rodada (igual em todos os aparelhos)
var round_results: Dictionary = {}

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

# Quem decide o resultado da rodada e libera a próxima:
# o host (ou o próprio aparelho, no modo local sem rede).
func is_authority() -> bool:
	return is_host or current_match == null


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
	_search_id += 1   # ignora o retorno de qualquer busca antiga
	if _searching and matchmaker != null and matchmaker.has_method("cancel"):
		matchmaker.cancel()
	_searching = false
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
	votes_by_round.clear()
	player_tomatoes.clear()
	round_results.clear()

## =====================================================================
## AUTENTICAÇÃO E SALAS VIA APPLE GAME CENTER
## =====================================================================

func authenticate() -> void:
	# Só autentica uma vez. Recriar o GameCenterManager a cada abertura do menu
	# deixa local_player nulo durante o login e quebra criar/entrar em sala.
	if _auth_pending or (game_center != null and game_center.local_player != null):
		return
	_auth_pending = true
	game_center = GameCenterManager.new()

	game_center.authentication_error.connect(func(error: String) -> void:
		_auth_pending = false
		print("Erro de autenticação Game Center: %s" % error)
	)

	game_center.authentication_result.connect(func(status: bool) -> void:
		_auth_pending = false
		print("Status de autenticação: %s" % status)
		if status and game_center.local_player:
			local = game_center.local_player
			local.register_listener()
	)
	game_center.authenticate()


# Devolve false se não conseguiu nem iniciar a busca (ex.: Game Center sem login).
# Quem chama NÃO deve navegar para a próxima tela nesse caso.
func join_room_with_code(room_code: int, am_i_host: bool) -> bool:
	if game_center == null or game_center.local_player == null:
		print("Erro: Jogador não autenticado no Game Center!")
		emit_signal("connection_failed", "Não foi possível conectar ao Game Center. Tente novamente.")
		return false

	_left_match = false

	# Nova tentativa: cancela busca anterior que ainda esteja pendente
	if _searching and matchmaker != null and matchmaker.has_method("cancel"):
		matchmaker.cancel()

	is_host = am_i_host
	current_room_code = room_code
	connected_players_names.clear()
	connected_players_profiles.clear()

	if local == null:
		local = game_center.local_player
	register_local_player(false)

	var req := GKMatchRequest.new()
	req.max_players = MAX_PLAYERS
	req.min_players = MIN_PLAYERS
	req.player_group = room_code

	print("[LOBBY] auth ok | id=%s | host=%s | sala=%d | max=%d min=%d" % [_my_id(), am_i_host, room_code, MAX_PLAYERS, MIN_PLAYERS])

	_search_id += 1
	var my_search := _search_id
	var t0 := Time.get_ticks_msec()
	_searching = true

	matchmaker = GKMatchmaker.new()
	matchmaker.find_match(req, func(game_match: GKMatch, error: Variant) -> void:
		if my_search != _search_id:
			return   # busca antiga/cancelada
		_searching = false
		print("[LOBBY] find_match respondeu em %d ms | erro=%s | match=%s" % [Time.get_ticks_msec() - t0, str(error), game_match != null])

		if error != null:
			print("Matchmaker falhou com erro: %s" % str(error))
			call_deferred("emit_signal", "connection_failed", "Falha ao conectar na sala. Tente novamente.")
			return

		if game_match != null:
			print("Partida estabelecida com sucesso via Game Center!")
			call_deferred("_configurar_partida", game_match)
	)
	return true


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
	if _left_match:
		return

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
			if p_id == "":
				return
			var p_name = str(dict.get("name", "Jogador"))
			var is_new := not connected_players_profiles.has(p_id)
			connected_players_names[p_id] = p_name
			connected_players_profiles[p_id] = {
				"name": p_name,
				"character": clampi(int(dict.get("character", 0)), 0, characters.size() - 1),
				"background": clampi(int(dict.get("background", 0)), 0, backgrounds.size() - 1),
				"host": bool(dict.get("host", false))
			}
			print("[LOBBY] player_info de %s (novo: %s) | total na sala: %d" % [p_name, is_new, connected_players_profiles.size()])
			# O primeiro handshake pode se perder numa corrida de conexão:
			# quem recebe um jogador novo responde com o próprio, para ele também me ver.
			if is_new and p_id != _my_id():
				_enviar_handshake_nome()
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
			var remote_no_answer = bool(dict.get("no_answer", false))
			if _store_answer(remote_round, remote_id, remote_player, remote_answer, remote_no_answer):
				print("Resposta (rodada %d) de %s: %s (sem resposta: %s)" % [remote_round, remote_player, remote_answer, remote_no_answer])
				emit_signal("resposta_recebida")

		"player_vote":
			var voter = str(dict.get("voter_id", ""))
			var target = str(dict.get("target_id", ""))
			var r_idx = int(dict.get("round", current_question_index))
			if voter != "":
				register_vote(voter, target, r_idx)

		"reveal_votes":
			# O host manda o resultado pronto; todos aplicam o mesmo placar
			var r_idx = int(dict.get("round", current_question_index))
			var pen = dict.get("penalties", {})
			if pen is Dictionary:
				apply_round_results(r_idx, pen)

		"next_round":
			# O host apertou "Próxima rodada"
			var r_idx = int(dict.get("round", current_question_index))
			emit_signal("next_round_requested", r_idx)

		"ranking_stage":
			_go_to_ranking_stage(str(dict.get("stage", "")))

		"play_again":
			_go_play_again()


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


#func send_my_questions_to_others() -> void:
	#questions_by_player[_my_id()] = my_created_questions.duplicate()
	#_rebuild_game_questions()
#
	#if current_match == null:
		## Modo local/teste sem rede
		#game_questions = my_created_questions.duplicate()
		#game_questions.shuffle()
		#questions_finalized = true
		#emit_signal("lobby_updated")
		#return
#
	#_enviar_pacote_json({
		#"type": "player_questions",
		#"id": _my_id(),
		#"questions": my_created_questions
	#})
	#emit_signal("lobby_updated")
func send_my_questions_to_others() -> void:
	# Registra as perguntas do jogador real.
	questions_by_player[_my_id()] = my_created_questions.duplicate()

	# Modo de teste com bots.
	if debug_active():
		for i in range(_debug_ids.size()):
			var bot_id: String = str(_debug_ids[i])
			var bot_questions: Array = _generate_debug_bot_questions(i)

			questions_by_player[bot_id] = bot_questions

			print(
				"[DEBUG] %s enviou %d perguntas."
				% [
					connected_players_names.get(bot_id, bot_id),
					bot_questions.size()
				]
			)

		_rebuild_game_questions()
		game_questions.shuffle()
		questions_finalized = true

		print(
			"[DEBUG] Total de perguntas recebidas: %d"
			% get_total_questions_received()
		)

		emit_signal("lobby_updated")
		return

	# Fluxo normal, sem bots.
	_rebuild_game_questions()

	if current_match == null:
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

# no_answer = true quando o tempo acabou sem o jogador enviar nada
func _store_answer(round_idx: int, player_id: String, player: String, answer: String, no_answer: bool = false) -> bool:
	if not answers_by_round.has(round_idx):
		answers_by_round[round_idx] = {}
	var round_answers: Dictionary = answers_by_round[round_idx]
	if round_answers.has(player_id):
		return false
	round_answers[player_id] = { "id": player_id, "player": player, "answer": answer, "no_answer": no_answer }
	return true


func send_my_answer(answer_text: String, no_answer: bool = false) -> void:
	var nickname := _my_name()
	_store_answer(current_question_index, _my_id(), nickname, answer_text, no_answer)
	emit_signal("resposta_recebida")

	_enviar_pacote_json({
		"type": "player_answer",
		"id": _my_id(),
		"round": current_question_index,
		"player": nickname,
		"answer": answer_text,
		"no_answer": no_answer
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


# Sempre devolve UM CARD POR JOGADOR da sala, na mesma ordem em todos os aparelhos.
# Quem não respondeu (ou cujo pacote nunca chegou) vem com no_answer = true.
func get_round_cards() -> Array:
	var out: Array = []
	var answers: Dictionary = answers_by_round.get(current_question_index, {})
	var ids: Array = connected_players_names.keys()
	for k in answers.keys():
		if not ids.has(k):
			ids.append(k)
	ids.sort()
	for pid in ids:
		if answers.has(pid):
			out.append(answers[pid])
		else:
			out.append({
				"id": pid,
				"player": connected_players_names.get(pid, "Jogador"),
				"answer": "",
				"no_answer": true
			})
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
## VOTAÇÃO E PENALIDADES (SISTEMA DE TOMATES)
## =====================================================================

func register_vote(voter_id: String, target_id: String, round_idx: int = current_question_index) -> void:
	# Votos que chegam depois do resultado oficial são ignorados
	if round_results.has(round_idx):
		return
	# Votar na própria resposta é permitido (decisão do PO)
	if not votes_by_round.has(round_idx):
		votes_by_round[round_idx] = {}
	votes_by_round[round_idx][voter_id] = target_id
	print("Voto registrado na rodada %d: %s -> %s" % [round_idx, voter_id, target_id])
	emit_signal("vote_received")


func send_my_vote(target_player_id: String) -> void:
	register_vote(_my_id(), target_player_id, current_question_index)

	_enviar_pacote_json({
		"type": "player_vote",
		"voter_id": _my_id(),
		"target_id": target_player_id,
		"round": current_question_index
	})


# Apenas CALCULA (não acumula). O acúmulo é feito em apply_round_results.
#  - 2 tomates: não respondeu OU pior resposta isolada (mais votos)
#  - 1 tomate: não votou OU empatou no topo de votos
#  - Ninguém respondeu: ninguém pôde votar, todos levam só os 2 tomates
func calculate_round_penalties(round_idx: int = current_question_index) -> Dictionary:
	var round_penalties: Dictionary = {}
	var round_answers: Dictionary = answers_by_round.get(round_idx, {})
	var round_votes: Dictionary = votes_by_round.get(round_idx, {})
	var valid_ids: Array = []

	for pid in connected_players_names.keys():
		round_penalties[pid] = 0
		var d = round_answers.get(pid)
		if d != null and not d.get("no_answer", false):
			valid_ids.append(pid)

	# Ninguém respondeu: sem votação, todos +2
	if valid_ids.is_empty():
		for pid in round_penalties.keys():
			round_penalties[pid] = 2
		return round_penalties

	for pid in connected_players_names.keys():
		if not valid_ids.has(pid):
			round_penalties[pid] += 2          # não respondeu
		if not round_votes.has(pid):
			round_penalties[pid] += 1          # não votou (voto em branco conta como voto)

	# Votos recebidos por cada resposta válida (em branco e votos em quem não respondeu não contam)
	var vote_counts: Dictionary = {}
	for voter_id in round_votes.keys():
		var target_id = round_votes[voter_id]
		if not valid_ids.has(target_id):
			continue
		vote_counts[target_id] = int(vote_counts.get(target_id, 0)) + 1

	# Pior resposta = a mais votada. Vale mesmo com uma só resposta válida:
	# o voto nela conta (ex.: quem não respondeu votou nela, ela leva +2).
	if not vote_counts.is_empty():
		var max_votes := 0
		for pid in vote_counts.keys():
			max_votes = maxi(max_votes, vote_counts[pid])
		var top: Array = []
		for pid in vote_counts.keys():
			if vote_counts[pid] == max_votes:
				top.append(pid)
		var penalty := 2 if top.size() == 1 else 1   # isolado = 2, empate = 1 cada
		for pid in top:
			round_penalties[pid] += penalty

	return round_penalties


# Aplica o resultado oficial uma única vez por rodada e avisa as telas
func apply_round_results(round_idx: int, penalties: Dictionary) -> bool:
	if round_results.has(round_idx):
		return false
	var clean: Dictionary = {}
	for pid in penalties.keys():
		var key := str(pid)
		clean[key] = int(penalties[pid])        # JSON devolve número como float
		player_tomatoes[key] = int(player_tomatoes.get(key, 0)) + clean[key]
	round_results[round_idx] = clean
	emit_signal("force_reveal_results", round_idx)
	return true


# Só o host (ou o modo local) calcula e transmite o resultado
func host_resolve_round(round_idx: int) -> void:
	if round_results.has(round_idx):
		return
	var penalties := calculate_round_penalties(round_idx)
	apply_round_results(round_idx, penalties)
	_enviar_pacote_json({
		"type": "reveal_votes",
		"round": round_idx,
		"penalties": penalties
	})


# O host apertou "Próxima rodada": avisa todos (e a si mesmo)
func host_next_round() -> void:
	if not is_authority():
		return
	var r := current_question_index
	_enviar_pacote_json({
		"type": "next_round",
		"round": r
	})
	emit_signal("next_round_requested", r)


## =====================================================================
## PLACAR (para as telas finais)
## =====================================================================

# Ranking final: do MAIS tomates (perdedor) para o menos.
# Cada item: { "id", "name", "tomatoes" }
func get_tomato_ranking() -> Array:
	var ranking: Array = []
	for pid in connected_players_names.keys():
		ranking.append({
			"id": pid,
			"name": connected_players_names[pid],
			"tomatoes": int(player_tomatoes.get(pid, 0))
		})
	ranking.sort_custom(func(a, b):
		if a["tomatoes"] != b["tomatoes"]:
			return a["tomatoes"] > b["tomatoes"]
		return String(a["name"]) < String(b["name"])   # desempate estável
	)
	return ranking


# Quem perdeu (mais tomates). Pode ter mais de um em caso de empate.
func get_losers() -> Array:
	var ranking := get_tomato_ranking()
	if ranking.is_empty():
		return []
	var top: int = ranking[0]["tomatoes"]
	return ranking.filter(func(p): return p["tomatoes"] == top)


func get_my_tomatoes() -> int:
	return int(player_tomatoes.get(_my_id(), 0))


## =====================================================================
## RANKING FINAL (melhores -> piores -> pontuação geral)
## =====================================================================

# Ranking completo. best_first = true: MENOS tomates primeiro (melhores);
# false: MAIS tomates primeiro (piores).
# Cada item: { id, name, tomatoes, character, background, place }
# "place" é a posição com empate dividido (1º, 1º, 2º).
func get_ranking(best_first: bool) -> Array:
	var ranking: Array = []
	for pid in connected_players_names.keys():
		var prof: Dictionary = connected_players_profiles.get(pid, {})
		ranking.append({
			"id": pid,
			"name": connected_players_names[pid],
			"tomatoes": int(player_tomatoes.get(pid, 0)),
			"character": int(prof.get("character", 0)),
			"background": int(prof.get("background", 0))
		})

	ranking.sort_custom(func(a, b):
		if a["tomatoes"] != b["tomatoes"]:
			if best_first:
				return a["tomatoes"] < b["tomatoes"]
			return a["tomatoes"] > b["tomatoes"]
		if a["name"] != b["name"]:
			return String(a["name"]) < String(b["name"])
		return String(a["id"]) < String(b["id"])   # mesma ordem em todos os aparelhos
	)

	var place := 0
	var last := -1
	for e in ranking:
		if e["tomatoes"] != last:
			place += 1
			last = e["tomatoes"]
		e["place"] = place
	return ranking


# O host avança o ranking: stage = "best", "worst" ou "overall". Todos trocam de tela.
func host_ranking_go(stage: String) -> void:
	if not is_authority():
		return
	_enviar_pacote_json({ "type": "ranking_stage", "stage": stage })
	_go_to_ranking_stage(stage)


func _go_to_ranking_stage(stage: String) -> void:
	match stage:
		"best":
			call_deferred("change_scene", SCENE_BEST)
		"worst":
			call_deferred("change_scene", SCENE_WORST)
		"overall":
			call_deferred("change_scene", SCENE_OVERALL)


# "Jogar Novamente": todos voltam ao lobby com a mesma sala
func host_play_again() -> void:
	if not is_authority():
		return
	_enviar_pacote_json({ "type": "play_again" })
	_go_play_again()


func _go_play_again() -> void:
	reset_match_state()
	call_deferred("change_scene", SCENE_LOBBY)


# "Encerrar": sai da partida e volta ao menu.
# TODO: chamar aqui o método do plugin que desconecta o GKMatch (confirmar o nome).
func leave_match() -> void:
	_left_match = true
	reset_match_state()
	current_match = null
	is_host = false
	current_room_code = 0
	connected_players_names.clear()
	connected_players_profiles.clear()
	call_deferred("change_scene", SCENE_MENU)


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


## =====================================================================
## DEBUG: jogadores falsos para testar sem Game Center
## Apague este bloco (e as chamadas debug_*) antes de publicar.
## =====================================================================

var _debug_ids: Array = []

func debug_active() -> bool:
	return DEBUG_BOTS > 0 and current_match == null and not _debug_ids.is_empty()


# Pula Game Center e lobby: você vira host sozinho com DEBUG_BOTS bots
func debug_start_solo() -> void:
	is_host = true
	current_room_code = 1234
	connected_players_names.clear()
	connected_players_profiles.clear()
	_debug_ids.clear()
	register_local_player(false)
	for i in range(DEBUG_BOTS):
		var bid := "bot_%d" % (i + 1)
		var bname := "Bot %d" % (i + 1)
		_debug_ids.append(bid)
		connected_players_names[bid] = bname
		connected_players_profiles[bid] = {
			"name": bname,
			"character": (i + 1) % characters.size(),
			"background": (i + 3) % backgrounds.size(),
			"host": false
		}
	host_start_game()   # vai direto para create_questions


# Os bots respondem. skip_last = true: o último bot NÃO responde (testa "Sem Resposta")
func debug_bots_answer(skip_last: bool = false) -> void:
	if not debug_active():
		return
	for i in range(_debug_ids.size()):
		if skip_last and i == _debug_ids.size() - 1:
			continue
		var bid: String = _debug_ids[i]
		_store_answer(current_question_index, bid, connected_players_names[bid], "Resposta do %s" % connected_players_names[bid], false)
	emit_signal("resposta_recebida")


# Os bots votam em target_id (vazio = voto em branco)
func debug_bots_vote(target_id: String = "") -> void:
	if not debug_active():
		return
	for bid in _debug_ids:
		register_vote(bid, target_id if target_id != "" else BLANK_VOTE, current_question_index)

func _generate_debug_bot_questions(bot_index: int) -> Array:
	var question_pool: Array[String] = [
		"Qual seria o pior nome para um restaurante?",
		"O que todo mundo finge gostar, mas quase ninguém gosta?",
		"Qual seria o pior superpoder para ter?",
		"O que você nunca deveria dizer em uma entrevista?",
		"Qual objeto seria estranho encontrar na geladeira?",
		"Qual seria o pior lugar para tirar uma soneca?",
		"O que você faria se ficasse invisível por um dia?",
		"Qual desculpa seria péssima para chegar atrasado?",
		"Qual animal seria o pior colega de apartamento?",
		"O que seria estranho fazer durante uma reunião?"
	]

	question_pool.shuffle()

	var bot_questions: Array = []
	var amount: int = maxi(1, GameManager.config_questions_per_player)

	for i in range(amount):
		bot_questions.append(question_pool[i % question_pool.size()])

	return bot_questions
