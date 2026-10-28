#worst_result.gd  ("E os melhores em serem os piores...")
extends PodiumScreen

func _best_first() -> bool:
	return false           # mais tomates primeiro

func _next_stage() -> String:
	return "overall"       # botão "Pontuação Geral"

# Mesmas cores que você já usava na tela vermelha
func _panel_colors() -> Array:
	return [Color("#FF3549"), Color("#C30000"), Color("#FF0040"), Color("#870000")]
