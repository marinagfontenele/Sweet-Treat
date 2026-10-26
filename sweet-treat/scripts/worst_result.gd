#worst_result.gd
extends Node

# Pódio dos que mais levaram tomates (do pior para o menos pior).
# Ordem dos nós = ordem do ranking: PodiumPlayer = 1º pior, PodiumPlayer2 = 2º, PodiumPlayer3 = 3º.
const PODIUM_PATHS := [
	"MarginContainer/HBoxContainer/PodiumPlayer",
	"MarginContainer/HBoxContainer/PodiumPlayer2",
	"MarginContainer/HBoxContainer/PodiumPlayer3",
]


func _ready() -> void:
	# Do mais para o menos tomates: { id, name, tomatoes }
	var ranking: Array = GameManager.get_tomato_ranking()

	for i in range(PODIUM_PATHS.size()):
		var podium = get_node_or_null(PODIUM_PATHS[i])
		if podium == null:
			continue

		# Sem jogador para essa posição (ex.: partida com 2 jogadores): esconde o degrau
		if i >= ranking.size():
			podium.visible = false
			continue

		podium.visible = true
		podium.set_panel_colors(
			Color("#FF3549"), Color("#C30000"), Color("#FF0040"), Color("#870000"))

		var entry: Dictionary = ranking[i]
		print("Pódio %d: %s com %d tomate(s)" % [i + 1, entry["name"], entry["tomatoes"]])

		# Entrega nome e tomates ao degrau, se o script dele tiver esse método.
		# (Falta me mandar o podium_player.gd para ligar isso direto.)
		if podium.has_method("set_player_info"):
			podium.set_player_info(entry["name"], entry["tomatoes"], GameManager.connected_players_profiles.get(entry["id"], {}))
