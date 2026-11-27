extends Node
## Ponte do Google Play Games Services (plugin GodotPlayGameServices) para o ranking mundial de abates:
## login, envio do total da carreira (KillRanking) e leitura das 100 melhores pontuações.
##
## Os dois IDs ficam em project.godot ([play_games] game_id e leaderboard_id). Sem eles, ou fora do Android,
## `available` fica falso e nada aqui toca o SDK (o plugin de exportação nem o põe no build). Nada bloqueia o
## jogo: toda chamada é assíncrona e falha de rede só deixa a lista como estava.

signal changed

const SINGLETON := "GodotPlayGameServices"
const LEADERBOARDS := "res://addons/GodotPlayGameServices/scripts/leaderboards/leaderboards_client.gd"
const SIGN_IN := "res://addons/GodotPlayGameServices/scripts/sign_in/sign_in_client.gd"
const PLAYERS := "res://addons/GodotPlayGameServices/scripts/players/players_client.gd"
## PlayGamesLeaderboardVariant: TimeSpan.TIME_SPAN_ALL_TIME e Collection.COLLECTION_PUBLIC.
const ALL_TIME := 2
const PUBLIC := 0

var available := false
var authenticated := false
## Pedido das melhores pontuações a caminho (as anteriores continuam em `scores` até a resposta).
var loading := false
## A última leitura falhou (sem conexão): a tela avisa em vez de dizer que o ranking está vazio.
var offline := false
var scores: Array = []
## ID do jogador no Play Games (destaca a linha dele).
var player_id := ""

var _board := ""
var _client: Node
var _sign_in: Node


func _ready() -> void:
	_board = str(ProjectSettings.get_setting("play_games/leaderboard_id", "")).strip_edges()
	if _board.is_empty() or not Engine.has_singleton(SINGLETON):
		return
	var plugin := get_node_or_null("/root/" + SINGLETON)
	if plugin == null or int(plugin.call("initialize")) != 0:
		return
	available = true
	_client = (load(LEADERBOARDS) as GDScript).new()
	_sign_in = (load(SIGN_IN) as GDScript).new()
	var players: Node = (load(PLAYERS) as GDScript).new()
	for node: Node in [_client, _sign_in, players]:
		add_child(node)
	_client.connect("top_scores_loaded", _on_scores_loaded)
	_sign_in.connect("user_authenticated", _on_authenticated.bind(players))
	players.connect("current_player_loaded", func(player: Object) -> void:
		player_id = String(player.get("player_id")) if player != null else ""
		changed.emit())
	_sign_in.call("is_authenticated")


func sign_in_user() -> void:
	if _sign_in != null:
		_sign_in.call("sign_in")


## Pede as melhores pontuações de novo; as atuais ficam à vista até a resposta (sem piscar vazio).
func refresh() -> void:
	if authenticated and _client != null:
		loading = true
		_client.call("load_top_scores_100", _board, ALL_TIME, PUBLIC, true)
	changed.emit()


## Envia o total da carreira (o placar do Google só guarda o maior). Sem login não faz nada.
func submit(profile: Dictionary) -> void:
	if authenticated and _client != null:
		_client.call("submit_score", _board, KillRanking.score_of(profile))


func _on_authenticated(value: bool, players: Node) -> void:
	authenticated = value
	if value:
		players.call("load_current_player", false)
		# Quem entra agora já aparece no ranking com a carreira que tem.
		submit(SaveManager.data)
		refresh()
	else:
		changed.emit()


func _on_scores_loaded(_board_id: String, result: RefCounted) -> void:
	loading = false
	# O plugin responde sem o placar quando a leitura falha.
	offline = result.get("leaderboard") == null
	if not offline:
		scores = result.get("scores")
	changed.emit()
