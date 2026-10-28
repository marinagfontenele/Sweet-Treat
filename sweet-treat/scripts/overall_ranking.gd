#overall_ranking.gd  ("Pontuação da galera")
extends Node

@onready var scroll_container: ScrollContainer = $MarginContainer/VBoxContainer/Panel/MarginContainer/ScrollContainer


func _ready() -> void:
	_style_scrollbar()
	_fill_rows()
	_setup_buttons()


func _style_scrollbar() -> void:
	var scrollbar = scroll_container.get_v_scroll_bar()

	var track = StyleBoxFlat.new()
	track.bg_color = Color("#071B5F")
	track.border_color = Color.BLACK
	track.set_border_width_all(1)
	track.set_corner_radius_all(8)

	var thumb = StyleBoxFlat.new()
	thumb.bg_color = Color("#FFDA38")
	thumb.border_color = Color("#BF9B00")
	thumb.border_width_right = 2
	thumb.border_width_bottom = 2
	thumb.border_width_left = 0
	thumb.border_width_top = 0
	thumb.set_corner_radius_all(8)

	scrollbar.add_theme_stylebox_override("scroll", track)
	scrollbar.add_theme_stylebox_override("grabber", thumb)
	scrollbar.add_theme_stylebox_override("grabber_highlight", thumb)
	scrollbar.add_theme_stylebox_override("grabber_pressed", thumb)

	scrollbar.custom_minimum_size.x = 10


# Lista: menos tomates em cima; empate divide a posição (1º, 1º, 2º)
func _fill_rows() -> void:
	if scroll_container.get_child_count() == 0:
		return
	var list: Node = scroll_container.get_child(0)
	var rows: Array = list.get_children()
	var ranking: Array = GameManager.get_ranking(true)

	for i in range(rows.size()):
		var row = rows[i]
		if i >= ranking.size():
			row.visible = false
			continue
		row.visible = true
		if row.has_method("set_row_info"):
			row.set_row_info(ranking[i])
		else:
			push_warning("Linha %d sem o script ranking_row.gd" % i)


# Botões achados pelo TEXTO ("Encerrar" / "Jogar Novamente")
func _setup_buttons() -> void:
	for b in find_children("*", "Button", true, false):
		var t: String = str(b.text).strip_edges().to_lower()
		if t == "encerrar":
			b.pressed.connect(GameManager.leave_match)
		elif t == "jogar novamente":
			if GameManager.is_authority():
				b.pressed.connect(GameManager.host_play_again)
			else:
				b.visible = false    # só o host recomeça
