extends Control

# Referência da partida mantida
var current_match: GKMatch = null

func _ready() -> void:
	print("--- Cena Jogo.tscn Ativa ---")

# Função para enviar dados da partida para todos os jogadores
func enviar_dados_partida(mensagem: String) -> void:
	if current_match != null:
		var data: PackedByteArray = mensagem.to_utf8_buffer()
		# O parâmetro 0 corresponde ao modo Reliable (envio garantido)
		current_match.send_data_to_all_players(data, 0)
		print("Dados enviados para todos os jogadores: ", mensagem)
