extends Control

# Anexe este script na RAIZ da cena player_lobby.tscn (nó "PlayerLobby").
# Estrutura esperada:
#   PlayerLobby
#     VBoxContainer
#       Panel   -> círculo do avatar (recebe a cor de fundo e o personagem)
#       Label   -> nome do jogador
#
# A cor de fundo é aplicada SOMENTE no círculo (VBoxContainer/Panel);
# o fundo do card (azul escuro) não é alterado.

const WAITING_TEXT := "Aguardando..."
const WAITING_CIRCLE_COLOR := Color(1, 1, 1, 0.25)

var _name_label: Label = null
var _avatar_panel: Control = null
var _avatar_rect: TextureRect = null
var _circle_style: StyleBoxFlat = null


func _ready() -> void:
	_resolve_nodes()


func _resolve_nodes() -> void:
	if _name_label == null:
		_name_label = get_node_or_null("VBoxContainer/Label")
		if _name_label == null:
			_name_label = find_child("Label", true, false)
	if _avatar_panel == null:
		_avatar_panel = get_node_or_null("VBoxContainer/Panel")
		if _avatar_panel == null:
			_avatar_panel = find_child("Panel", true, false)


# profile = { "name": String, "character": int, "background": int, "host": bool }
func set_profile(profile: Dictionary) -> void:
	_resolve_nodes()
	modulate = Color.WHITE

	if _name_label:
		_name_label.text = str(profile.get("name", "Jogador"))

	var bidx: int = clampi(int(profile.get("background", 0)), 0, GameManager.backgrounds.size() - 1)
	var cidx: int = clampi(int(profile.get("character", 0)), 0, GameManager.characters.size() - 1)

	_set_circle_color(GameManager.backgrounds[bidx])
	_set_avatar_texture(GameManager.characters[cidx])


# Vaga vazia na sala (ainda ninguém entrou)
func set_waiting() -> void:
	_resolve_nodes()
	modulate = Color(1, 1, 1, 0.55)

	if _name_label:
		_name_label.text = WAITING_TEXT
	_set_circle_color(WAITING_CIRCLE_COLOR)
	_set_avatar_texture(null)


func _set_circle_color(color: Color) -> void:
	if _avatar_panel == null:
		return

	if _circle_style == null:
		# O estilo original é compartilhado entre todas as instâncias do card,
		# por isso cada card precisa da sua própria cópia.
		var sb = _avatar_panel.get_theme_stylebox("panel")
		if sb is StyleBoxFlat:
			_circle_style = sb.duplicate()
		else:
			_circle_style = StyleBoxFlat.new()
			_circle_style.set_corner_radius_all(999)
		_avatar_panel.add_theme_stylebox_override("panel", _circle_style)

	_circle_style.bg_color = color


func _set_avatar_texture(tex: Texture2D) -> void:
	if _avatar_panel == null:
		return

	if _avatar_rect == null:
		_avatar_rect = _avatar_panel.get_node_or_null("AvatarTexture")
		if _avatar_rect == null:
			_avatar_rect = TextureRect.new()
			_avatar_rect.name = "AvatarTexture"
			_avatar_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			_avatar_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			_avatar_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_avatar_panel.add_child(_avatar_rect)
			_avatar_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_avatar_rect.texture = tex
	_avatar_rect.visible = tex != null
