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

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.17, 0.17, 0.17, 0.97)
	style.set_corner_radius_all(28)
	style.content_margin_left = 22
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	style.border_color = Color(0, 0, 0, 0.6)
	style.set_border_width_all(1)
	_panel.add_theme_stylebox_override("panel", style)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	_panel.add_child(row)

	_preview = LineEdit.new()
	_preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preview.editable = false
	_preview.focus_mode = Control.FOCUS_NONE
	_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preview.context_menu_enabled = false
	_preview.add_theme_font_size_override("font_size", 24)
	_preview.add_theme_color_override("font_color", Color.WHITE)
	_preview.add_theme_color_override("font_uneditable_color", Color.WHITE)
	_preview.add_theme_color_override("font_placeholder_color", Color(1, 1, 1, 0.45))
	_preview.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	_preview.add_theme_stylebox_override("read_only", StyleBoxEmpty.new())
	row.add_child(_preview)

	_confirm = Button.new()
	_confirm.text = "OK"
	_confirm.flat = true
	_confirm.focus_mode = Control.FOCUS_NONE   # não rouba o foco do campo digitado
	_confirm.add_theme_font_size_override("font_size", 24)
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

	var w: float = minf(view.x * 0.8, 900.0)
	var h: float = 60.0
	_panel.size = Vector2(w, h)
	_panel.position = Vector2((view.x - w) * 0.5, view.y - kb_in_view - h - 8.0)
