extends Node

var tomato: int = 0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

func change_scene(scene: String) -> void:
	get_tree().change_scene_to_file(scene)

func add_score(quant: int) -> void:
	tomato += quant


## INCREMENTAÇÃO PARA LÓGICA DE TESTE
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

var count: int = 0

var game_center: GameCenterManager
var local: GKLocalPlayer

var matchmaker := GKMatchmaker.new()

var current_match: GKMatch

var score: int = 0
var player_name: String = ""

func authenticate() -> void:
	game_center = GameCenterManager.new()

	game_center.authentication_error.connect(func(error: String) -> void:
		print("Received error %s" % error)
	)
	game_center.authentication_result.connect(func(status: bool) -> void:
		print("Authentication updated, status: %s" % status)
		local = game_center.local_player
		local.register_listener()
		local.invite_accepted.connect(func(_player: GKPlayer, invite: GKInvite) -> void:
			matchmaker.match_for_invite(invite, func(match: GKMatch, error: Variant) -> void:
				if error:
					print("Invite match error: %s" % error)
				else:
					print("Joined invited match")
					current_match = match
					current_match.data_received.connect(func (data: PackedByteArray, _from_player: GKPlayer)->void:
						print("Received data from Player")
						print(data.get_string_from_utf8())
						set_count(data.get_string_from_utf8().to_int())
					)
					current_match.data_received_for_recipient_from_player.connect(func(data: PackedByteArray, _for_recipient: GKPlayer, _from_remote_player: GKPlayer)->void: 
						print("Received data from a player to another player")
						print(data.get_string_from_utf8())
						set_count(data.get_string_from_utf8().to_int())
					)
					RenderingServer.set_default_clear_color(Color("#1e7e34"))
			)
		)
	)

	game_center.authenticate()

func request_match() -> void:
	var req = GKMatchRequest.new()
	req.max_players = 2
	req.min_players = 2
	GKMatchmakerViewController.request_match(req, func(game_match: GKMatch, error: Variant)->void:
		if error:
			print("Could not request a match %s" % error)
		else:
			print("Got a match!")
			current_match = game_match
			RenderingServer.set_default_clear_color(Color("#1e7e34"))
			game_match.data_received.connect(func (data: PackedByteArray, _from_player: GKPlayer)->void:
				print("Received data from Player")
				print(data.get_string_from_utf8())
				set_count(data.get_string_from_utf8().to_int())
			)
			game_match.data_received_for_recipient_from_player.connect(func(data: PackedByteArray, _for_recipient: GKPlayer, _from_remote_player: GKPlayer)->void: 
				print("Received data from a player to another player")
				print(data.get_string_from_utf8())
				set_count(data.get_string_from_utf8().to_int())
			)
			game_match.did_fail_with_error.connect(func(_error: String)->void:
				print("Match failed with %s" % error)
			)
			game_match.should_reinvite_disconnected_player = (func(_player: GKPlayer)->bool:
				# We always reinvite
				return true
			)
			game_match.player_changed.connect(func(_player: GKPlayer, connected: bool)->void: 
				print("Status of player changed to %s" % connected)
			)
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
	pass
