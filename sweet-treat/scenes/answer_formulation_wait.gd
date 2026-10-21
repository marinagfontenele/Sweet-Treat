extends Node

# Tela de espera: aguarda TODAS as respostas da rodada antes de exibi-las juntas.
const NEXT_SCENE := "res://scenes/all_answers.tscn"
const MAX_WAIT_SECONDS := 20.0   # segurança caso um jogador caia

@onready var label_enviadas = _get_label("MarginContainer/VBoxContainer/HBoxContainer/PerguntasEnviadas", "PerguntasEnviadas")
@onready var label_totais = _get_label("MarginContainer/VBoxContainer/HBoxContainer/PerguntasTotais", "PerguntasTotais")

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
	if _elapsed >= MAX_WAIT_SECONDS:
		print("Tempo de espera esgotado; exibindo as respostas recebidas.")
		_advance()


func _refresh() -> void:
	var received: int = GameManager.get_current_answers_count()
	var expected: int = GameManager.get_expected_players_count()

	if label_enviadas:
		label_enviadas.text = "%d" % received
	if label_totais:
		label_totais.text = "%d" % expected

	if received >= expected:
		_advance()


func _advance() -> void:
	if _advanced:
		return
	_advanced = true
	print("Todas as respostas da rodada chegaram. Exibindo.")
	GameManager.call_deferred("change_scene", NEXT_SCENE)
