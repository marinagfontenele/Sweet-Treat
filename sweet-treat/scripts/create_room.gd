extends Node

const ALERT_POPUP_SCENE = preload("res://scenes/pop-ups/leave_room.tscn")

const QUESTION_OPTIONS := [1, 2, 3]
const ANSWER_OPTIONS := [30, 60, 90]
const VOTE_OPTIONS := [30, 60, 90]

@onready var room_code_label = _get_node_or_find("MarginContainer/VBoxContainer/HBoxContainer/Panel/VBoxContainer/Panel/RoomCodeLabel", "RoomCodeLabel")
@onready var play_button = _get_node_or_find("MarginContainer/PlayButton", "PlayButton")
@onready var close_button = _get_node_or_find("MarginContainer/InfoButton", "InfoButton")

# groups[0] = perguntas, groups[1] = tempo de resposta, groups[2] = tempo de votação
var groups: Array = [[], [], []]
var selected_idx: Array = [0, 0, 0]


func _ready() -> void:
	if room_code_label:
		room_code_label.text = "%04d" % GameManager.current_room_code
	else:
		push_error("RoomCodeLabel não encontrado na cena!")

	_collect_option_buttons()
	for g in range(3):
		_setup_group(g)
	_apply_config()

	if play_button:
		if play_button.pressed.is_connected(go_to_lobby):
			play_button.pressed.disconnect(go_to_lobby)
		play_button.pressed.connect(go_to_lobby)
	else:
		push_error("PlayButton não encontrado na cena create_room!")

	# Conecta o botão X para abrir o Pop-up de alerta
	if close_button:
		if not close_button.pressed.is_connected(_on_close_pressed):
			close_button.pressed.connect(_on_close_pressed)
	else:
		push_error("InfoButton (botão X) não encontrado na cena create_room!")

	print("create_room pronta. Botões: perguntas=%d, resposta=%d, voto=%d" % [groups[0].size(), groups[1].size(), groups[2].size()])


func _get_node_or_find(path: String, node_name: String) -> Node:
	var n = get_node_or_null(path)
	if n == null:
		n = find_child(node_name, true, false)
	return n


# ---------------------------------------------------------------------
# Abertura do Pop-up de Sair ao clicar no X
# ---------------------------------------------------------------------
func _on_close_pressed() -> void:
	if ALERT_POPUP_SCENE:
		var popup = ALERT_POPUP_SCENE.instantiate()
		add_child(popup)
		if popup.has_method("set_message"):
			popup.set_message("Tem certeza de que deseja sair agora? A sala será encerrada")


# ---------------------------------------------------------------------
# Descoberta e Seleção dos Botões de Configuração
# ---------------------------------------------------------------------
func _collect_option_buttons() -> void:
	var rows: Dictionary = {}
	_scan_named(self, rows)

	if rows.size() < 3:
		rows.clear()
		_scan_generic(self, rows)

	var ordered: Array = []
	if rows.has("HBoxContainer") and rows.has("HBoxContainer2") and rows.has("HBoxContainer3"):
		ordered = [rows["HBoxContainer"], rows["HBoxContainer2"], rows["HBoxContainer3"]]
	else:
		for k in rows.keys():
			ordered.append(rows[k])

	if ordered.size() >= 3:
		for g in range(3):
			var arr: Array = ordered[g]
			arr.sort_custom(func(a, b): return String(a.name) < String(b.name))
			groups[g] = arr
	else:
		push_error("Não achei as 3 linhas de botões de configuração (achei %d)." % ordered.size())


func _scan_named(node: Node, rows: Dictionary) -> void:
	for child in node.get_children():
		if child is BaseButton and String(child.name).begins_with("ConfigurationButtonButton"):
			var key := String(node.name)
			if not rows.has(key):
				rows[key] = []
			rows[key].append(child)
		_scan_named(child, rows)


func _scan_generic(node: Node, rows: Dictionary) -> void:
	var buttons: Array = []
	for child in node.get_children():
		if child is BaseButton and String(child.name) != "PlayButton" and String(child.name) != "InfoButton":
			buttons.append(child)
	if buttons.size() >= 3:
		rows[String(node.name) + "_" + str(node.get_instance_id())] = buttons
	for child in node.get_children():
		_scan_generic(child, rows)


func _setup_group(g: int) -> void:
	var buttons: Array = groups[g]
	if buttons.is_empty():
		return

	selected_idx[g] = 0
	for i in range(buttons.size()):
		if buttons[i].button_pressed:
			selected_idx[g] = i
			break
	_mark_selected(g)

	for i in range(buttons.size()):
		buttons[i].pressed.connect(_on_option_pressed.bind(g, i))


func _on_option_pressed(g: int, i: int) -> void:
	selected_idx[g] = i
	_mark_selected(g)
	_apply_config()


func _mark_selected(g: int) -> void:
	var buttons: Array = groups[g]
	for j in range(buttons.size()):
		buttons[j].set_pressed_no_signal(j == selected_idx[g])


func _value_for(g: int, options: Array, default_value: int) -> int:
	var i: int = selected_idx[g]
	if groups[g].size() > 0 and i < options.size():
		return options[i]
	return default_value


func _apply_config() -> void:
	GameManager.config_questions_per_player = _value_for(0, QUESTION_OPTIONS, 1)
	GameManager.config_answer_time = _value_for(1, ANSWER_OPTIONS, 30)
	GameManager.config_vote_time = _value_for(2, VOTE_OPTIONS, 15)
	print("Config atual: %d perguntas/jogador, %ds resposta, %ds voto" % [
		GameManager.config_questions_per_player,
		GameManager.config_answer_time,
		GameManager.config_vote_time
	])


func go_to_lobby() -> void:
	_apply_config()
	GameManager._enviar_handshake_nome()
	GameManager.call_deferred("change_scene", "res://scenes/lobby_room.tscn")
