#best_result.gd  ("Os melhores da vez...")
extends PodiumScreen

func _best_first() -> bool:
	return true            # menos tomates primeiro

func _next_stage() -> String:
	return "worst"         # botão "Revelar piores"
