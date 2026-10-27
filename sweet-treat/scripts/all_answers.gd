#all_answers.gd
extends Node

## =====================================================================
## TELA DE VOTAÇÃO / RESULTADO DA RODADA
##
## Fases:
##   1) VOTAÇÃO   -> título "Quem se passou mais?", timer no canto, botões
##                   "Pular voto" e "Votar"
##   2) VOTOU     -> botões somem, LabelText: "Tomate jogado! Aguardando..."
##   3) RESULTADO -> título "Olha quem se passou!", nomes e tomates nos cards;
##                   host vê o botão "Próxima rodada", os outros veem LabelText
##
## Nós esperados na cena (procurados pelo NOME, em qualquer lugar da árvore):
##   TitleLabel, TimerLabel, LabelText, PlayButton ("Votar"),
##   ButtonVoteNull ("Pular voto"), ButtonNextRound
## E dentro do PlayerAnswer (card), opcional: TomatoSplat (tomate amassado).
## =====================================================================

# ---------------------------------------------------------------------
# TEXTOS
# ---------------------------------------------------------------------
const TITLE_VOTING := "Quem se passou mais?"
const TITLE_RESULTS := "Olha quem se passou!"
const TEXT_VOTED := "Tomate jogado! Aguardando a galera votar..."
const TEXT_SKIPPED := "Voto pulado! Aguardando a galera votar..."
const TEXT_WAITING_NEXT := "Aguardando o host iniciar a próxima rodada..."
const TEXT_NOBODY := "Ninguém respondeu. Aguardando o host iniciar a próxima rodada..."
const TEXT_NO_ANSWER := "Sem Resposta"

# ---------------------------------------------------------------------
# CORES (tiradas dos protótipos do Figma; ajuste aqui se precisar)
# ---------------------------------------------------------------------
const OWN_CARD_COLOR := Color("#4CA8E4")          # card da própria resposta
const NO_ANSWER_TEXT_COLOR := Color("#C7C7C7")    # texto "Sem Resposta"
const BADGE_RED := Color("#EB4A50")               # +2 (ou mais)
const BADGE_BLUE := Color("#4CA8E4")              # +1

const URGENT_SECONDS := 10    # a partir daqui o timer fica vermelho
const FALLBACK_GRACE := 6.0   # quem não é host espera isso a mais pelo resultado do host

# ---------------------------------------------------------------------
# CAMINHOS DENTRO DO CARD (PlayerAnswer)
# ---------------------------------------------------------------------
const P_NAME := "VBoxContainer/Label"
const P_OUTER := "VBoxContainer/MarginContainer"
const P_ANSWER := "VBoxContainer/MarginContainer/AspectRatioContainer/Panel/MarginContainer/Label"
const P_TARGET := "VBoxContainer/MarginContainer/AspectRatioContainer/Panel/MarginContainer/TextureRect"
const P_BADGE := "VBoxContainer/MarginContainer/AspectRatioContainer/Panel/TomatoBadge"
const P_SPLAT := "VBoxContainer/MarginContainer/AspectRatioContainer/Panel/TomatoSplat"

var answer_slots: Array = []
# Um item por card visível: { id, card, target, badge, splat, no_answer }
var _cards: Array = []

var selected_target_id: String = ""
var has_voted: bool = false
var is_revealing: bool = false
var _leaving: bool = false
var _selectable_count: int = 0

var _time_left: float = 0.0
var _grace_left: float = FALLBACK_GRACE
var _timer_running: bool = false
var _last_second: int = -1

@onready var vote_button: Button = _find_node("PlayButton") as Button
@onready var skip_button: Button = _find_node("ButtonVoteNull") as Button
@onready var next_round_button: Button = _find_node("ButtonNextRound") as Button
@onready var info_label: Label = _find_node("LabelText") as Label
@onready var title_label: Label = _find_node("TitleLabel") as Label
@onready var timer_label: Label = _find_node("TimerLabel") as Label

const NORMAL_TIME: LabelSettings = preload("res://resources/normal_time.tres")
const RED_TIME: LabelSettings = preload("res://resources/red_time.tres")

func _find_node(node_name: String) -> Node:
	return find_child(node_name, true, false)


func _ready() -> void:
	_collect_answer_containers(self)

	if title_label == null:
		push_warning("Label 'TitleLabel' não encontrado em all_answers (título da tela).")
	if timer_label == null:
		push_warning("Label 'TimerLabel' não encontrado em all_answers (timer do canto).")
	if info_label == null:
		push_warning("Label 'LabelText' não encontrado em all_answers.")

	# --- estado inicial da interface: fase de votação ---
	if title_label:
		title_label.text = TITLE_VOTING
	if vote_button:
		vote_button.text = "Votar"
		vote_button.disabled = true
		vote_button.visible = true
		vote_button.pressed.connect(_on_confirm_vote_pressed)
	if skip_button:
		skip_button.text = "Pular voto"
		skip_button.disabled = false
		skip_button.visible = true
		skip_button.pressed.connect(_on_skip_vote_pressed)
	if next_round_button:
		next_round_button.text = "Próxima rodada"
		next_round_button.visible = false
		next_round_button.pressed.connect(_on_next_round_pressed)
	if info_label:
		info_label.visible = false
	if timer_label:
		timer_label.visible = true

	# --- sinais do GameManager ---
	if not GameManager.vote_received.is_connected(_check_all_votes_received):
		GameManager.vote_received.connect(_check_all_votes_received)
	if not GameManager.force_reveal_results.is_connected(_on_force_reveal):
		GameManager.force_reveal_results.connect(_on_force_reveal)
	if not GameManager.next_round_requested.is_connected(_on_next_round):
		GameManager.next_round_requested.connect(_on_next_round)

	_setup_cards()

	_time_left = float(GameManager.config_vote_time)
	_grace_left = FALLBACK_GRACE
	_timer_running = true
	_update_timer_label()

	# Espera um frame: os sinais e a cena já estão prontos
	call_deferred("_post_setup")


func _collect_answer_containers(node: Node) -> void:
	if node is AspectRatioContainer and node.has_node("PlayerAnswer"):
		answer_slots.append(node)
	for child in node.get_children():
		_collect_answer_containers(child)


# Estados que já podem estar prontos quando a cena abre
func _post_setup() -> void:
	var r: int = GameManager.current_question_index

	# O host já tinha mandado o resultado antes de esta tela abrir
	if GameManager.round_results.has(r):
		_reveal_results()
		return

	# Ninguém respondeu: não há o que votar, vai direto ao resultado (todos +2)
	if _selectable_count == 0:
		if timer_label:
			timer_label.visible = false
		if GameManager.is_authority():
			GameManager.host_resolve_round(r)
		return

	_check_all_votes_received()


## =====================================================================
## CARDS
## =====================================================================

func _setup_cards() -> void:
	var data_list: Array = GameManager.get_round_cards()
	var my_id: String = GameManager._my_id()
	_selectable_count = 0
	_cards.clear()

	for i in range(answer_slots.size()):
		var container = answer_slots[i]
		var card = container.get_node("PlayerAnswer")

		if i >= data_list.size():
			container.visible = false
			continue

		container.visible = true
		var data: Dictionary = data_list[i]
		var pid := str(data.get("id", ""))
		var no_answer: bool = bool(data.get("no_answer", false))

		var name_label = card.get_node_or_null(P_NAME)
		var answer_label = card.get_node_or_null(P_ANSWER)
		var target_icon = _part(card, P_TARGET, "TextureRect")
		var badge = _part(card, P_BADGE, "TomatoBadge")
		var splat = _part(card, P_SPLAT, "TomatoSplat")

		if name_label:
			name_label.text = str(data.get("player", "Jogador"))
		_set_name_visible(card, false)

		if answer_label:
			answer_label.text = TEXT_NO_ANSWER if no_answer else str(data.get("answer", ""))
			if no_answer:
				answer_label.add_theme_color_override("font_color", NO_ANSWER_TEXT_COLOR)
			else:
				answer_label.remove_theme_color_override("font_color")

		if target_icon:
			target_icon.visible = false
		if badge:
			badge.visible = false
		if splat:
			splat.visible = false

		if card is BaseButton:
			card.focus_mode = Control.FOCUS_NONE
			if no_answer:
				card.disabled = true       # card desabilitado (cinza): não dá para votar
			else:
				card.disabled = false
				_selectable_count += 1
				if pid == my_id:
					_paint_card(card, OWN_CARD_COLOR, Color("#0081B0"))   # a própria resposta fica azul claro
				card.pressed.connect(_on_card_pressed.bind(pid))

		_cards.append({
			"id": pid,
			"card": card,
			"target": target_icon,
			"badge": badge,
			"splat": splat,
			"no_answer": no_answer
		})


# Procura um nó dentro do card pelo caminho; se não achar, pelo nome
func _part(card: Node, path: String, node_name: String) -> Node:
	var n = card.get_node_or_null(path)
	if n == null:
		n = card.find_child(node_name, true, false)
	return n


# Mostra/esconde o nome do jogador. O margin top do container do card existe só
# para compensar o nome escondido; com o nome visível ele precisa ser 0.
func _set_name_visible(card: Node, show_name: bool) -> void:
	var name_label = card.get_node_or_null(P_NAME)
	if name_label:
		name_label.visible = show_name

	var outer = card.get_node_or_null(P_OUTER) as MarginContainer
	if outer:
		if not outer.has_meta("orig_margin_top"):
			outer.set_meta("orig_margin_top", outer.get_theme_constant("margin_top"))
		if show_name:
			outer.add_theme_constant_override("margin_top", 0)
		else:
			outer.add_theme_constant_override("margin_top", int(outer.get_meta("orig_margin_top")))


# Pinta o card (cada card ganha o próprio estilo, sem afetar os outros)
func _paint_card(card: Node, color: Color, stroke_color: Color) -> void:
	if not (card is Button):
		return

	for shape in ["normal", "hover", "pressed", "hover_pressed"]:
		var style = card.get_theme_stylebox(shape)

		if style is StyleBoxFlat:
			var s: StyleBoxFlat = style.duplicate()

			# Muda a cor de fundo
			s.bg_color = color

			# Muda a cor do stroke (borda)
			s.border_color = stroke_color

			card.add_theme_stylebox_override(shape, s)


# Badge de tomates: vermelho para +2 (ou mais), azul para +1
func _style_badge(badge: Node, tomatoes: int) -> void:
	if not (badge is Label):
		return
	var color: Color = BADGE_RED if tomatoes >= 2 else BADGE_BLUE
	badge.add_theme_color_override("font_color", color)
	var style = badge.get_theme_stylebox("normal")
	if style is StyleBoxFlat:
		var s: StyleBoxFlat = style.duplicate()
		s.border_color = color
		badge.add_theme_stylebox_override("normal", s)


# Depois de votar / no resultado: cards não reagem mais ao mouse (sem hover),
# mas continuam com a mesma cor (não ficam cinza como os desabilitados)
func _lock_cards() -> void:
	for c in _cards:
		var card = c["card"]
		if card is Control:
			card.mouse_filter = Control.MOUSE_FILTER_IGNORE


## =====================================================================
## VOTAÇÃO
## =====================================================================

func _on_card_pressed(target_id: String) -> void:
	if has_voted or is_revealing:
		return

	selected_target_id = target_id

	# tiro ao alvo só no card escolhido
	for c in _cards:
		if c["target"]:
			c["target"].visible = (c["id"] == target_id)

	if vote_button:
		vote_button.disabled = false


func _on_confirm_vote_pressed() -> void:
	if selected_target_id == "":
		return
	_submit_vote(selected_target_id)


func _on_skip_vote_pressed() -> void:
	_submit_vote(GameManager.BLANK_VOTE)


func _submit_vote(target_id: String) -> void:
	if has_voted or is_revealing:
		return
	has_voted = true

	var skipped: bool = (target_id == GameManager.BLANK_VOTE)

	# o tiro ao alvo sai; o tomate amassado cai no card votado
	for c in _cards:
		if c["target"]:
			c["target"].visible = false
		if c["splat"]:
			c["splat"].visible = (not skipped and c["id"] == target_id)

	_show_vote_buttons(false)
	_show_info(TEXT_SKIPPED if skipped else TEXT_VOTED)
	_lock_cards()

	GameManager.send_my_vote(target_id)
	_check_all_votes_received()


# Só o host (ou o modo local) fecha a rodada quando todos votaram
func _check_all_votes_received() -> void:
	if is_revealing:
		return

	var r: int = GameManager.current_question_index
	if GameManager.round_results.has(r):
		return   # o resultado já é oficial; a revelação vem pelo sinal

	var votes: int = GameManager.votes_by_round.get(r, {}).size()
	if votes >= GameManager.get_expected_players_count() and GameManager.is_authority():
		GameManager.host_resolve_round(r)


func _process(delta: float) -> void:
	if not _timer_running or is_revealing:
		return

	_time_left = maxf(_time_left - delta, 0.0)
	_update_timer_label()
	if _time_left > 0.0:
		return

	var r: int = GameManager.current_question_index
	if GameManager.is_authority():
		# acabou o tempo de votação: o host fecha a rodada
		_timer_running = false
		GameManager.host_resolve_round(r)
	else:
		# os outros esperam o resultado do host; se ele não vier, calcula localmente
		_grace_left -= delta
		if _grace_left <= 0.0:
			_timer_running = false
			GameManager.apply_round_results(r, GameManager.calculate_round_penalties(r))



func _update_timer_label() -> void:
	if timer_label == null:
		return

	var sec: int = int(ceil(_time_left))

	if sec == _last_second:
		return

	_last_second = sec

	timer_label.text = "%d:%02d" % [
		floori(sec / 60.0),
		sec % 60
	]

	if sec <= URGENT_SECONDS:
		timer_label.label_settings = RED_TIME
	else:
		timer_label.label_settings = NORMAL_TIME

## =====================================================================
## RESULTADO
## =====================================================================

func _on_force_reveal(r_idx: int) -> void:
	if r_idx != GameManager.current_question_index:
		return   # resultado de outra rodada: ignora
	_reveal_results()


func _reveal_results() -> void:
	if is_revealing:
		return
	var r: int = GameManager.current_question_index
	if not GameManager.round_results.has(r):
		return
	is_revealing = true
	_timer_running = false

	var penalties: Dictionary = GameManager.round_results[r]
	var nobody_answered: bool = (_selectable_count == 0)

	if title_label:
		title_label.text = TITLE_RESULTS
	if timer_label:
		timer_label.visible = false
	_show_vote_buttons(false)
	_lock_cards()

	for c in _cards:
		if c["target"]:
			c["target"].visible = false
		if c["splat"]:
			c["splat"].visible = false

		_set_name_visible(c["card"], true)

		var tomatoes: int = int(penalties.get(c["id"], 0))
		var badge = c["badge"]
		if badge:
			badge.visible = tomatoes > 0
			if tomatoes > 0:
				if badge is Label:
					badge.text = "+%d" % tomatoes
				_style_badge(badge, tomatoes)

	# No lugar do texto: host vê o botão, os outros veem a mensagem
	if GameManager.is_authority():
		if info_label:
			info_label.visible = false
		if next_round_button:
			next_round_button.disabled = false
			next_round_button.visible = true
	else:
		_show_info(TEXT_NOBODY if nobody_answered else TEXT_WAITING_NEXT)


func _on_next_round_pressed() -> void:
	if not GameManager.is_authority():
		return
	if next_round_button:
		next_round_button.disabled = true   # evita clique duplo
	GameManager.host_next_round()


# Vale para todos: o host apertou "Próxima rodada"
func _on_next_round(r_idx: int) -> void:
	if _leaving or r_idx != GameManager.current_question_index:
		return
	_leaving = true

	if GameManager.advance_to_next_question():
		GameManager.change_scene("res://scenes/show_question.tscn")
	else:
		GameManager.change_scene("res://scenes/worst_result_screen.tscn")


## =====================================================================
## AUXILIARES DE INTERFACE
## =====================================================================

func _show_vote_buttons(show_buttons: bool) -> void:
	if vote_button:
		vote_button.visible = show_buttons
	if skip_button:
		skip_button.visible = show_buttons


func _show_info(text: String) -> void:
	if info_label:
		info_label.text = text
		info_label.visible = true
