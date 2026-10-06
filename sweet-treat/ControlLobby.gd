extends Control

# ==============================================================================
# VARIÁVEIS DE INSTÂNCIA / ESTADO
# ==============================================================================
var game_center: GameCenterManager
var local_player: GKLocalPlayer

var active_match: GKMatch = null
var matchmaker := GKMatchmaker.new()
var matchmaker_controller: GKMatchmakerViewController = null

# ==============================================================================
# REFERÊNCIAS DE NÓS (@ONREADY)
# ==============================================================================
@onready var label_title: Label = $VBoxContainer/LabelTittle
@onready var label_status: Label = $VBoxContainer/LabelStatus
@onready var btn_criar: Button = $VBoxContainer/HBoxContainer/ButtonCreatRoom
@onready var btn_buscar: Button = $VBoxContainer/HBoxContainer/ButtonSearchPlayer
@onready var item_list: ItemList = $VBoxContainer/ItemListPlayers
@onready var btn_iniciar: Button = $VBoxContainer/ButtonStart


# ==============================================================================
# MÉTODOS VIRTUAIS DO GODOT
# ==============================================================================
func _ready() -> void:
	print("--- Inicializando Lobby GameKit Nativo ---")
	
	btn_iniciar.disabled = true
	btn_criar.disabled = true
	btn_buscar.disabled = true
	label_status.text = "Iniciando Game Center..."
	
	btn_criar.pressed.connect(_on_criar_pressed)
	btn_buscar.pressed.connect(_on_buscar_pressed)
	btn_iniciar.pressed.connect(_on_iniciar_pressed)
	
	_inicializar_game_center()


# ==============================================================================
# LÓGICA DO GAME CENTER E MATCHMAKING
# ==============================================================================
func _inicializar_game_center() -> void:
	game_center = GameCenterManager.new()

	game_center.authentication_error.connect(func(error: String) -> void:
		print("Received error: %s" % error)
		label_status.text = "Erro GC: %s" % error
	)
	
	game_center.authentication_result.connect(func(status: bool) -> void:
		print("Authentication updated, status: %s" % status)
		if status:
			local_player = game_center.local_player
			label_status.text = "Autenticado: %s" % local_player.game_player_id
			btn_criar.disabled = false
			btn_buscar.disabled = false

			# 1. Registrar o listener para receber eventos de convite
			local_player.register_listener()
			
			# 2. FLUXO DE CONVITE ACEITO (Dispositivo Convidado)
			local_player.invite_accepted.connect(func(player: GKPlayer, invite: GKInvite) -> void:
				label_status.text = "Convite aceito. Conectando..."
				print("Convite aceito de %s" % player.alias)
				
				# Chama match_for_invite na instância de GKMatchmaker
				matchmaker.match_for_invite(invite, func(game_match: GKMatch, error: Variant) -> void:
					if error:
						print("Invite match error: %s" % error)
						label_status.text = "Erro no convite: %s" % str(error)
					else:
						print("Joined invited match successfully!")
						active_match = game_match
						_configurar_eventos_da_partida(active_match)
						_mudar_para_cena_jogo()
				)
			)
		else:
			label_status.text = "Falha na Autenticação GC"
	)

	game_center.authenticate()


func _solicitar_partida() -> void:
	label_status.text = "Abrindo Matchmaker..."
	print("Criando requisição GKMatchRequest...")
	
	var req := GKMatchRequest.new()
	req.min_players = 2
	req.max_players = 2
	req.invite_message = "Join me in a quest to fun"
	
	# Solicita a partida usando request_match
	GKMatchmakerViewController.request_match(req, func(game_match: GKMatch, error: Variant) -> void:
		if error:
			print("Could not request a match: %s" % error)
			label_status.text = "Erro no Matchmaker: %s" % str(error)
		else:
			print("Partida estabelecida!")
			active_match = game_match
			_configurar_eventos_da_partida(active_match)
			_mudar_para_cena_jogo()
	)


func _configurar_eventos_da_partida(game_match: GKMatch) -> void:
	game_match.data_received.connect(func(data: PackedByteArray, from_player: GKPlayer) -> void:
		print("Dados recebidos do jogador: %s" % from_player.game_player_id)
	)
	
	game_match.did_fail_with_error.connect(func(err: String) -> void:
		print("Match failed with: %s" % err)
		label_status.text = "Falha na partida: %s" % err
	)
	
	game_match.player_changed.connect(func(player: GKPlayer, connected: bool) -> void:
		print("Status do jogador %s mudou para conectado = %s" % [player.game_player_id, connected])
		if connected and active_match != null:
			label_status.text = "Jogador %s conectou!" % player.game_player_id
	)


func _fechar_matchmaker_ui() -> void:
	if matchmaker_controller:
		matchmaker_controller.dismiss()
		matchmaker_controller = null


func _mudar_para_cena_jogo() -> void:
	_fechar_matchmaker_ui()
	print("Carregando res://Jogo.tscn ...")
	get_tree().change_scene_to_file("res://Jogo.tscn")


# ==============================================================================
# CALLBACKS DE BOTÕES E UI
# ==============================================================================
func _on_buscar_pressed() -> void:
	_solicitar_partida()


func _on_criar_pressed() -> void:
	_solicitar_partida()


func _on_iniciar_pressed() -> void:
	_mudar_para_cena_jogo()