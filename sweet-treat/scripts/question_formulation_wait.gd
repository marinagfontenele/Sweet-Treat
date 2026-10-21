extends Node

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

	# Só o Host libera a próxima etapa quando todos os jogadores enviaram
	if GameManager.is_host and not _advanced and jogadores_prontos >= total_jogadores:
		_advanced = true
		print("Todos os jogadores enviaram (%d/%d). Avançando..." % [jogadores_prontos, total_jogadores])

		if GameManager.lobby_updated.is_connected(_on_perguntas_atualizadas):
			GameManager.lobby_updated.disconnect(_on_perguntas_atualizadas)

		GameManager.host_start_question_display()
