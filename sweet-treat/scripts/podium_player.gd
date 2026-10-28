#podium_player.gd
extends Node

# Nomes que o script tenta achar dentro do card (ajuste aqui se os seus forem outros)
const AVATAR_NAMES := ["Avatar", "PlayerImage", "CharacterImage", "Character", "Profile"]
const CIRCLE_NAMES := ["PlayerBackground", "AvatarBackground", "Circle", "CircleBackground", "AvatarPanel"]
const COUNT_NAMES := ["TomatoCount", "TomatoLabel", "TomatoBadge", "Tomatoes", "Count", "Score"]


func set_panel_colors(
	background_color: Color,
	border_color: Color,
	label_background_color: Color,
	label_border_color: Color
) -> void:

	var panel = $VBoxContainer/ColorPanel
	var panel_style = panel.get_theme_stylebox("panel").duplicate() as StyleBoxFlat

	panel_style.bg_color = background_color
	panel_style.border_color = border_color

	panel.add_theme_stylebox_override("panel", panel_style)

	var label = $VBoxContainer/PlayerName as Label

	var label_style = label.get_theme_stylebox("normal").duplicate() as StyleBoxFlat

	label_style.bg_color = label_background_color
	label_style.border_color = label_border_color

	label.add_theme_stylebox_override("normal", label_style)


# entry = { id, name, tomatoes, character, background, place } (vem de GameManager.get_ranking)
func set_player_info(entry: Dictionary) -> void:
	var name_label := get_node_or_null("VBoxContainer/PlayerName") as Label
	if name_label:
		name_label.text = str(entry.get("name", ""))

	var count_label := _find_count_label(name_label)
	if count_label:
		count_label.text = str(int(entry.get("tomatoes", 0)))

	var chars: Array = GameManager.characters
	var bgs: Array = GameManager.backgrounds
	var ch_idx: int = clampi(int(entry.get("character", 0)), 0, chars.size() - 1)
	var bg_idx: int = clampi(int(entry.get("background", 0)), 0, bgs.size() - 1)

	var avatar := _find_avatar()
	if avatar:
		avatar.texture = chars[ch_idx]

	_paint_circle(_find_by_names(CIRCLE_NAMES), bgs[bg_idx])


func _find_by_names(names: Array) -> Node:
	for n in names:
		var found = find_child(n, true, false)
		if found:
			return found
	return null


func _find_count_label(name_label: Label) -> Label:
	var by_name = _find_by_names(COUNT_NAMES)
	if by_name is Label:
		return by_name
	# Plano B: o único outro Label do card que não é o nome
	for l in find_children("*", "Label", true, false):
		if l != name_label:
			return l
	return null


func _find_avatar() -> TextureRect:
	var by_name = _find_by_names(AVATAR_NAMES)
	if by_name is TextureRect:
		return by_name
	# Plano B: primeiro TextureRect dentro do painel colorido
	var panel = get_node_or_null("VBoxContainer/ColorPanel")
	if panel:
		for t in panel.find_children("*", "TextureRect", true, false):
			return t
	return null


func _paint_circle(circle: Node, color: Color) -> void:
	if circle == null:
		return
	if circle is ColorRect:
		circle.color = color
	elif circle is Panel or circle is PanelContainer:
		var style = circle.get_theme_stylebox("panel")
		if style is StyleBoxFlat:
			var s: StyleBoxFlat = style.duplicate()
			s.bg_color = color
			circle.add_theme_stylebox_override("panel", s)
