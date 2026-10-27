#podium_screen.gd  (script-base das telas "melhores" e "piores")
# Salve em res://scripts/podium_screen.gd. As telas best_result e worst_result
# herdam deste script; só mudam 3 coisas (ordem, próxima etapa, cores).
class_name PodiumScreen
extends Node

# Os 8 PodiumPlayer que ficam no ScrollContainer horizontal
const SLOTS_PATH := "MarginContainer/Panel/MarginContainer/ScrollContainer/HBoxContainer"
# HBoxContainer antigo (3 degraus): fica escondido
const OLD_PODIUM_PATH := "MarginContainer/HBoxContainer"

var _pressed: bool = false


# ---- as telas filhas sobrescrevem estas 3 funções ----
func _best_first() -> bool:
	return true          # true = menos tomates primeiro (melhores)

func _next_stage() -> String:
	return ""            # "worst" ou "overall"

func _panel_colors() -> Array:
	return []            # [fundo, borda, fundo_nome, borda_nome]; vazio = deixa como está na cena
# ------------------------------------------------------


func _ready() -> void:
	var old = get_node_or_null(OLD_PODIUM_PATH)
	if old:
		old.visible = false

	var button := find_child("PlayButton", true, false) as Button
	var wait_label := find_child("Label2", true, false) as Label

	# Só o host tem o botão; os outros veem a mensagem de espera
	if GameManager.is_authority():
		if button:
			button.visible = true
			button.disabled = false
			button.pressed.connect(_on_next_pressed)
		if wait_label:
			wait_label.visible = false
	else:
		if button:
			button.visible = false
		if wait_label:
			wait_label.visible = true

	_fill_podium()


func _fill_podium() -> void:
	var slots = get_node_or_null(SLOTS_PATH)
	if slots == null:
		push_error("Caminho dos degraus não encontrado: %s" % SLOTS_PATH)
		return

	# O pódio mostra só quem empatou na pontuação extrema: menos tomates (melhores)
	# ou mais tomates (piores). O ranking já vem ordenado, então o 1º define o valor.
	var full: Array = GameManager.get_ranking(_best_first())
	var ranking: Array = []
	if not full.is_empty():
		var top_score: int = full[0]["tomatoes"]
		ranking = full.filter(func(e): return e["tomatoes"] == top_score)

	# Poucos cards ficam centralizados; com 4 ou mais o conteúdo passa da largura
	# e o ScrollContainer rola para o lado.
	if slots is BoxContainer:
		slots.alignment = BoxContainer.ALIGNMENT_CENTER
		slots.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var colors: Array = _panel_colors()
	var nodes: Array = slots.get_children()

	for i in range(nodes.size()):
		var slot = nodes[i]
		if i >= ranking.size():
			slot.visible = false       # sem jogador para esse degrau
			continue

		slot.visible = true
		if colors.size() == 4 and slot.has_method("set_panel_colors"):
			slot.set_panel_colors(colors[0], colors[1], colors[2], colors[3])
		if slot.has_method("set_player_info"):
			slot.set_player_info(ranking[i])


func _on_next_pressed() -> void:
	if _pressed:
		return
	_pressed = true
	var button := find_child("PlayButton", true, false) as Button
	if button:
		button.disabled = true
	GameManager.host_ranking_go(_next_stage())
