#ranking_row.gd  (script da linha da tela "Pontuação da galera")
extends Node

const AVATAR_NAMES := ["Avatar", "PlayerImage", "CharacterImage", "Character", "Profile"]
const CIRCLE_NAMES := ["AvatarBackground", "Circle", "CircleBackground", "AvatarPanel"]


# entry = { id, name, tomatoes, character, background, place }
func set_row_info(entry: Dictionary) -> void:
	# Ordem dos Labels na árvore: posição ("1º"), nome, tomates
	var labels: Array = find_children("*", "Label", true, false)
	if labels.size() >= 3:
		labels[0].text = "%dº" % int(entry.get("place", 1))
		labels[1].text = str(entry.get("name", ""))
		labels[labels.size() - 1].text = str(int(entry.get("tomatoes", 0)))
	else:
		push_warning("ranking_row: esperava 3 Labels (posição, nome, tomates), achei %d" % labels.size())

	var chars: Array = GameManager.characters
	var bgs: Array = GameManager.backgrounds
	var ch_idx: int = clampi(int(entry.get("character", 0)), 0, chars.size() - 1)
	var bg_idx: int = clampi(int(entry.get("background", 0)), 0, bgs.size() - 1)

	var avatar := _find_avatar()
	if avatar:
		avatar.texture = chars[ch_idx]

	var circle = _find_by_names(CIRCLE_NAMES)
	if circle is ColorRect:
		circle.color = bgs[bg_idx]
	elif circle is Panel or circle is PanelContainer:
		var style = circle.get_theme_stylebox("panel")
		if style is StyleBoxFlat:
			var s: StyleBoxFlat = style.duplicate()
			s.bg_color = bgs[bg_idx]
			circle.add_theme_stylebox_override("panel", s)


func _find_by_names(names: Array) -> Node:
	for n in names:
		var found = find_child(n, true, false)
		if found:
			return found
	return null


func _find_avatar() -> TextureRect:
	var by_name = _find_by_names(AVATAR_NAMES)
	if by_name is TextureRect:
		return by_name
	# Plano B: primeiro TextureRect da linha (o avatar vem antes do tomate)
	for t in find_children("*", "TextureRect", true, false):
		return t
	return null
