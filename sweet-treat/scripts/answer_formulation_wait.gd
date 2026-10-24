#answer_formulation_wait.gd
# Tela de espera: aguarda TODAS as respostas da rodada antes de exibi-las juntas.
extends Node

const NEXT_SCENE := "res://scenes/all_answers.tscn"

@onready var label_enviadas = _get_label("MarginContainer/VBoxContainer/HBoxContainer/PerguntasEnviadas", "PerguntasEnviadas")
@onready var label_totais = _get_label("MarginContainer/VBoxContainer/HBoxContainer/PerguntasTotais", "PerguntasTotais")

# Label de teste (opcional). Se não existir na cena, é simplesmente ignorado.
@onready var debug_label = get_node_or_null("MarginContainer/VBoxContainer/LabelDebug")

var _advanced: bool = false
var _elapsed: float = 0.0


func _get_label(path: String, node_name: String):
	var n = get_node_or_null(path)
	if n == null:
		n = find_child(node_name, true, false)
	return n


func _ready() -> void:
	if not GameManager.resposta_recebida.is_connected(_refresh):
		GameManager.resposta_recebida.connect(_refresh)
	if not GameManager.lobby_updated.is_connected(_refresh):
		GameManager.lobby_updated.connect(_refresh)
	_refresh()


func _process(delta: float) -> void:
	if _advanced:
		return
	_elapsed += delta
	# Segurança caso um jogador caia: tempo de resposta + margem para latência.
	# (Precisa ser MAIOR que o tempo de resposta, senão quem responde primeiro
	# é empurrado para a votação antes dos outros terminarem.)
	if _elapsed >= float(GameManager.config_answer_time) + 5.0:
		print("Timeout de espera: avançando com o que chegou.")
		_advance()


func _refresh() -> void:
	var received: int = GameManager.get_current_answers_count()
	var expected: int = GameManager.get_expected_players_count()

	if label_enviadas:
		label_enviadas.text = "%d" % received
	if label_totais:
		label_totais.text = "%d" % expected
	if debug_label:
		debug_label.text = "Rec: %d | Exp: %d" % [received, expected]

	if received >= expected:
		_advance()


func _advance() -> void:
	if _advanced:
		return
	_advanced = true
	GameManager.call_deferred("change_scene", NEXT_SCENE)
