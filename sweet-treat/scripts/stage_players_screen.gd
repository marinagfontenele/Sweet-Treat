#stage_players_screen.gd
extends Control

# Tempo de exibição da tela antes de mudar para as perguntas
@export var display_seconds: float = 3.5

var card_nodes: Array = []


func _ready() -> void:
	card_nodes.clear()
	_collect_all_cards(self)
	
	# Ordena os cards da esquerda para a direita e de cima para baixo
	card_nodes.sort_custom(func(a, b):
		if abs(a.global_position.y - b.global_position.y) > 10:
			return a.global_position.y < b.global_position.y
		return a.global_position.x < b.global_position.x
	)
	
	_update_players_display()
	_start_transition_timer()


# Varre a árvore de nós procurando qualquer nó que represente um card de jogador
func _collect_all_cards(node: Node) -> void:
	if node != self and (node.name.begins_with("StageCardPanel") or node.has_node("PlayerName")):
		card_nodes.append(node)
		return

	for child in node.get_children():
		_collect_all_cards(child)


func _update_players_display() -> void:
	var players: Array = GameManager.get_lobby_players()

	for i in range(card_nodes.size()):
		var card: Node = card_nodes[i]

		if i < players.size():
			card.visible = true
			_apply_player_to_card(card, players[i])
		else:
			# Esconde os slots de jogadores não utilizados na sala
			card.visible = false


func _apply_player_to_card(card: Node, profile: Dictionary) -> void:
	# 1. NOME DO JOGADOR
	var name_label = card.find_child("PlayerName", true, false)
	if name_label and name_label is Label:
		name_label.text = str(profile.get("name", "Jogador"))

	# 2. CÍRCULO DO FUNDO (Pinta apenas a bolinha por trás sem afetar os filhos)
	var circle_panel = _find_circle_panel(card)
	if circle_panel and circle_panel is Panel:
		var bg_idx: int = int(profile.get("background", 0))
		if bg_idx >= 0 and bg_idx < GameManager.backgrounds.size():
			var player_color: Color = GameManager.backgrounds[bg_idx]
			
			# Garante que o painel da bolinha não module o Avatar que está na frente
			circle_panel.modulate = Color.WHITE
			
			# Cria um StyleBoxFlat exclusivo para a bolinha do fundo
			var style_box = StyleBoxFlat.new()
			style_box.bg_color = player_color
			style_box.set_corner_radius_all(1000) # Mantém o formato circular
			circle_panel.add_theme_stylebox_override("panel", style_box)

	# 3. ÍCONE DO PERSONAGEM (Avatar por cima de tudo com as cores perfeitas)
	var avatar_rect = card.find_child("Avatar", true, false)
	if avatar_rect and avatar_rect is TextureRect:
		var char_idx: int = int(profile.get("character", 0))
		if char_idx >= 0 and char_idx < GameManager.characters.size():
			avatar_rect.texture = GameManager.characters[char_idx]
			avatar_rect.modulate = Color.WHITE # Reseta a cor para manter a fidelidade do SVG
			
			# Garante que o Avatar fique no topo do nó pai
			if avatar_rect.get_parent():
				avatar_rect.get_parent().move_child(avatar_rect, avatar_rect.get_parent().get_child_count() - 1)


# Localiza o nó Panel do círculo cinza interno
func _find_circle_panel(card: Node) -> Node:
	var avatar_rect = card.find_child("Avatar", true, false)
	if avatar_rect and avatar_rect.get_parent() is Panel:
		return avatar_rect.get_parent()

	var margin = card.find_child("MarginContainer", true, false)
	if margin:
		var outer_panel = margin.find_child("Panel", false, false)
		if outer_panel and outer_panel.get_child_count() > 0:
			for child in outer_panel.get_children():
				if child is Panel:
					return child
	return null


func _start_transition_timer() -> void:
	await get_tree().create_timer(display_seconds).timeout
	GameManager.change_scene("res://scenes/show_question.tscn")
