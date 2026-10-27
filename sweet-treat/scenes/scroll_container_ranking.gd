#scroll_container_ranking.gd
extends ScrollContainer

func _ready():
	get_h_scroll_bar().modulate.a = 0
	get_v_scroll_bar().modulate.a = 0
	
