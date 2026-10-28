extends Node

# Tempo fixo de espera (em segundos) após todos enviarem antes de ir para o Stage
@export var wait_time_seconds: float = 10.0

@onready var label_perguntas_enviadas: Label = $MarginContainer/VBoxContainer/HBoxContainer/PerguntasEnviadas
@onready var label_perguntas_totais: Label = $MarginContainer/VBoxContainer/HBoxContainer/PerguntasTotais

var _advanced: bool = false


func _ready() -> void:
	if not GameManager.lobby_updated.is_connected(_on_perguntas_atualizadas):
		GameManager.lobby_updated.connect(_on_perguntas_atualizadas)

	_on_perguntas_atualizadas()


# Conta jogadores que já enviaram TODAS as suas perguntas
func _count_players_submitted() -> int:
	var count := 0
	for pid in GameManager.questions_by_player.keys():
		if GameManager.questions_by_player[pid].size() >= GameManager.config_questions_per_player:
			count += 1
	return count


func _on_perguntas_atualizadas() -> void:
	var total_jogadores: int = maxi(1, GameManager.connected_players_names.size())
	var jogadores_prontos: int = _count_players_submitted()

	if label_perguntas_enviadas:
		label_perguntas_enviadas.text = "%d" % jogadores_prontos

	if label_perguntas_totais:
		label_perguntas_totais.text = "%d" % total_jogadores

	# Quando todos enviam, aguarda o tempo fixo e avança localmente em cada aparelho
	if not _advanced and jogadores_prontos >= total_jogadores:
		_advanced = true
		print("Todos os jogadores prontos! Aguardando tempo fixo (%.1fs)..." % wait_time_seconds)

		if GameManager.lobby_updated.is_connected(_on_perguntas_atualizadas):
			GameManager.lobby_updated.disconnect(_on_perguntas_atualizadas)

		_start_fixed_countdown()


func _start_fixed_countdown() -> void:
	# Aguarda o tempo fixo configurado para dar o suspense em todas as telas
	await get_tree().create_timer(wait_time_seconds).timeout
	
	# Troca de cena automaticamente no aparelho local
	GameManager.change_scene("res://scenes/stage_players_screen.tscn")
