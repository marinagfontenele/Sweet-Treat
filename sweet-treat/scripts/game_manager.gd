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
	
	game_match.data_received.connect(func(data: PackedByteArray, _from_player: GKPlayer) -> void:
		print("Received data from Player")
		print(data.get_string_from_utf8())
		set_count(data.get_string_from_utf8().to_int())
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
