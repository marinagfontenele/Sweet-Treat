extends Button

func definir_cor(color: Color):
	var normal_style = get_theme_stylebox("normal").duplicate()
	normal_style.bg_color = color
	add_theme_stylebox_override("normal", normal_style)

	var hover_style = get_theme_stylebox("hover").duplicate()
	hover_style.bg_color = color
	add_theme_stylebox_override("hover", hover_style)
	
	var pressed_style = get_theme_stylebox("pressed").duplicate()
	pressed_style.bg_color = color
	add_theme_stylebox_override("pressed", pressed_style)

func restore_color():
	var normal_style = get_theme_stylebox("normal").duplicate()
	normal_style.bg_color = Color("#ffffff59")
	add_theme_stylebox_override("normal", normal_style)

	var hover_style = get_theme_stylebox("hover").duplicate()
	hover_style.bg_color = Color("#ffffff59")
	add_theme_stylebox_override("hover", hover_style)
	
	var pressed_style = get_theme_stylebox("pressed").duplicate()
	pressed_style.bg_color = Color("#1f0f8b")
	add_theme_stylebox_override("pressed", pressed_style)
