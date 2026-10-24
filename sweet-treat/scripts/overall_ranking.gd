extends Node

@onready var scroll_container: ScrollContainer = $MarginContainer/VBoxContainer/Panel/MarginContainer/ScrollContainer

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
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
	

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
