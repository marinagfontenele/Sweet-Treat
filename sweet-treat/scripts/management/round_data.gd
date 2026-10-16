class_name RoundData
extends RefCounted


var question: QuestionData

# Chave: peer_id do jogador
# Valor: texto da resposta
var answers: Dictionary = {}

# Chave: peer_id de quem votou
# Valor: peer_id de quem recebeu o voto
var votes: Dictionary = {}

# Quantidade de votos recebidos por jogador
var vote_counts: Dictionary = {}

# Jogadores empatados ou vencedores da votação
var most_voted_player_ids: Array[int] = []

# Indica se os resultados já foram processados
var has_been_processed: bool = false


func _init(round_question: QuestionData) -> void:
	question = round_question


func submit_answer(
	player_id: int,
	answer_text: String
) -> bool:
	if answers.has(player_id):
		return false

	answers[player_id] = answer_text
	return true


func submit_vote(
	voter_id: int,
	target_id: int
) -> bool:
	if votes.has(voter_id):
		return false

	if not answers.has(voter_id):
		return false

	if not answers.has(target_id):
		return false

	votes[voter_id] = target_id
	return true


func calculate_vote_result() -> void:
	vote_counts.clear()
	most_voted_player_ids.clear()

	for target_id in votes.values():
		vote_counts[target_id] = (
			vote_counts.get(target_id, 0) + 1
		)

	if vote_counts.is_empty():
		return

	var highest_votes: int = 0

	for target_id in vote_counts:
		var total_votes: int = vote_counts[target_id]

		if total_votes > highest_votes:
			highest_votes = total_votes
			most_voted_player_ids.clear()
			most_voted_player_ids.append(target_id)

		elif total_votes == highest_votes:
			most_voted_player_ids.append(target_id)
