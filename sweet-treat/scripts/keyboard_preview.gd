extends CanvasLayer

# Barra que fica logo acima do teclado virtual e espelha o que está sendo
# digitado no LineEdit (o teclado, deitado, tapa o campo original).
#
# Uso, em qualquer tela (ex.: no _ready de create_questions.gd e answer_question.gd):
#   const KeyboardPreview = preload("res://scripts/keyboard_preview.gd")
#   ...
#   KeyboardPreview.new().attach_to(self, input_question)

# false = o botão OK só fecha o teclado; true = fecha e também "envia" (text_submitted)
const SUBMIT_ON_CONFIRM := false

var _target: LineEdit
var _panel: PanelContainer
var _preview: LineEdit
var _confirm: Button


func attach_to(host: Node, target: LineEdit) -> void:
	if target == null:
		push_warning("KeyboardPreview: LineEdit não encontrado.")
		return
	_target = target
	layer = 100
	host.add_child(self)
	_build_ui()

	_target.text_changed.connect(_on_target_text_changed)
	_target.focus_entered.connect(_sync_from_target)
	_sync_from_target()

func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.visible = false
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP

	# Fundo escuro atrás da barra
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("#ffffff00")
	panel_style.set_corner_radius_all(0)
	panel_style.content_margin_left = 0
	panel_style.content_margin_right = 0
	panel_style.content_margin_top = 0
	panel_style.content_margin_bottom = 0
	_panel.add_theme_stylebox_override("panel", panel_style)

	# Organização horizontal: campo de texto + botão
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_panel.add_child(row)

	# Campo de texto cinza
	_preview = LineEdit.new()
	_preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preview.custom_minimum_size = Vector2(0, 60)
	_preview.editable = false
	_preview.focus_mode = Control.FOCUS_NONE
	_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preview.context_menu_enabled = false
	_preview.add_theme_font_size_override("font_size", 24)
	_preview.add_theme_color_override("font_color", Color.WHITE)
	_preview.add_theme_color_override("font_uneditable_color", Color.WHITE)
	var lilita_font = load("res://assets/fonts/LilitaOne-Regular.ttf")
	_preview.add_theme_font_override("font", lilita_font)
	_preview.add_theme_color_override(
		"font_placeholder_color", Color("#dddddd")
	)

	var input_style := StyleBoxFlat.new()
	input_style.bg_color = Color("#64646488")
	input_style.set_corner_radius_all(40)
	input_style.set_border_width_all(2)
	input_style.border_color = Color.BLACK
	input_style.content_margin_left = 24
	input_style.content_margin_right = 20
	input_style.content_margin_top = 8
	input_style.content_margin_bottom = 8

	_preview.add_theme_stylebox_override("normal", input_style)
	_preview.add_theme_stylebox_override("read_only", input_style)
	_preview.add_theme_stylebox_override("focus", input_style)
	row.add_child(_preview)

	# Botão circular amarelo
	_confirm = Button.new()
	_confirm.custom_minimum_size = Vector2(60, 60)
	_confirm.size_flags_horizontal = Control.SIZE_SHRINK_END
	_confirm.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_confirm.text = ""

	var checkmark := TextureRect.new()
	checkmark.texture = load("res://assets/images/symbols/checkmark.svg")
	checkmark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	checkmark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	checkmark.custom_minimum_size = Vector2(36, 36)
	checkmark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	checkmark.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	checkmark.position = Vector2(-18, -18)

	_confirm.add_child(checkmark)
	_confirm.flat = false
	_confirm.focus_mode = Control.FOCUS_NONE
	_confirm.add_theme_font_size_override("font_size", 48)
	_confirm.add_theme_color_override("font_color", Color.WHITE)
	_confirm.add_theme_color_override("font_hover_color", Color.WHITE)
	_confirm.add_theme_color_override("font_pressed_color", Color.WHITE)

	var button_normal := StyleBoxFlat.new()
	button_normal.bg_color = Color("#ffdc35")
	button_normal.set_corner_radius_all(50)
	button_normal.set_border_width_all(2)
	button_normal.border_color = Color.BLACK
	button_normal.content_margin_left = 0
	button_normal.content_margin_right = 0
	button_normal.content_margin_top = 0
	button_normal.content_margin_bottom = 0

	var button_hover := button_normal.duplicate()
	button_hover.bg_color = Color("#ffe45c")

	var button_pressed := button_normal.duplicate()
	button_pressed.bg_color = Color("#e6c329")

	_confirm.add_theme_stylebox_override("normal", button_normal)
	_confirm.add_theme_stylebox_override("hover", button_hover)
	_confirm.add_theme_stylebox_override("pressed", button_pressed)
	_confirm.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

	_confirm.pressed.connect(_on_confirm_pressed)
	row.add_child(_confirm)

	add_child(_panel)

func _sync_from_target() -> void:
	if _preview == null or _target == null:
		return
	_preview.placeholder_text = _target.placeholder_text
	_preview.text = _target.text
	_preview.caret_column = _preview.text.length()


func _on_target_text_changed(_new_text: String) -> void:
	_sync_from_target()


func _on_confirm_pressed() -> void:
	if _target == null:
		return
	var typed := _target.text
	_target.release_focus()
	if SUBMIT_ON_CONFIRM:
		_target.text_submitted.emit(typed)


func _process(_delta: float) -> void:
	if _target == null or not is_instance_valid(_target):
		return

	var kb_h: int = DisplayServer.virtual_keyboard_get_height()
	var should_show: bool = _target.has_focus() and kb_h > 0
	_panel.visible = should_show
	if not should_show:
		return

	# Texto trocado por código (ex.: botão Próxima/Voltar) não dispara text_changed
	if _preview.text != _target.text:
		_sync_from_target()

	# Converte a altura do teclado (pixels da janela) para o espaço do jogo
	var win: Vector2 = Vector2(DisplayServer.window_get_size())
	var view: Vector2 = get_viewport().get_visible_rect().size
	var ratio: float = view.y / maxf(1.0, win.y)
	var kb_in_view: float = kb_h * ratio

	var margin: float = 30.0
	var w: float = view.x - margin * 2.0
	var h: float = 60.0

	_panel.size = Vector2(w, h)
	_panel.position = Vector2(
	margin,
	view.y - kb_in_view - h - 16.0
	)
