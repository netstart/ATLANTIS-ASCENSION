class_name NetLink
extends RefCounted
## Transporte do coop em rede local: ENetMultiplayerPeer do próprio Godot (MIT, já no motor), sem plugin e sem
## servidor. Pacotes crus, todos confiáveis e em ordem (o lockstep do LanSession precisa de cada entrada, na ordem).
##
## Origem: net_link.gd do projeto hyakki (mesmo autor, MIT), sem os modos sem garantia.
##
## Só rede local, garantido aqui: as duas pontas só aceitam endereços privados (is_private_address: 10/8, 172.16/12,
## 192.168/16, link-local e 127.0.0.1 para os testes); não existe campo de IP nem servidor (a sala é achada pelo
## código de 4 dígitos, LanRoom).
##
## Camada de teste: latency_ms atrasa tudo o que sai e loss sorteia essa fração dos pacotes para "se perder": como o
## canal é confiável, a perda vira o atraso da retransmissão (RESEND_MS a mais), segurando os pacotes de trás na fila,
## como o ENet faz na rede ruim.

## Um anfitrião e uma convidada; a vaga a mais do ENet só existe para o terceiro aparelho ouvir "sala cheia".
const MAX_CLIENTS := 2
## Sem resposta por este tempo a conexão cai (o padrão do ENet espera até 30 s).
const TIMEOUT_MS := 5000
const ENET_TIMEOUT_LIMIT := 32
## Quanto a ponta recusada espera (ms) antes de o anfitrião desconectá-la: ela lê o aviso e fecha antes.
const REFUSE_GRACE_MS := 1500
const RESEND_MS := 120

var peer: ENetMultiplayerPeer
var is_host: bool = false
var latency_ms: int = 0
var loss: float = 0.0
## Pontas conectadas agora (ids do ENet), sem as recusadas. O anfitrião fala com a primeira.
var peers: Array[int] = []

## Eventos para o LanSession: {"kind": "connected"|"disconnected"|"packet", "peer", "data", "address"}.
var _events: Array[Dictionary] = []
var _out: Array = []
var _out_at: int = 0
## Pontas recusadas (id -> quando desconectar, ms): o aviso sai antes.
var _refused: Dictionary = {}
var _rng := RandomNumberGenerator.new()


func _init(test_latency_ms: int = 0, test_loss: float = 0.0, seed_value: int = 1) -> void:
	latency_ms = test_latency_ms
	loss = test_loss
	_rng.seed = seed_value


## Endereço de rede local (ou 127.0.0.1): o único tipo que as pontas aceitam.
static func is_private_address(address: String) -> bool:
	if address.begins_with("::ffff:"):
		address = address.substr(7)
	if address == "127.0.0.1" or address == "::1":
		return true
	if address.contains(":"):
		return address.to_lower().begins_with("fe80:")
	var parts := address.split(".")
	if parts.size() != 4:
		return false
	for part: String in parts:
		if not part.is_valid_int() or part.to_int() < 0 or part.to_int() > 255:
			return false
	var a := parts[0].to_int()
	var b := parts[1].to_int()
	return a == 10 or (a == 172 and b >= 16 and b <= 31) or (a == 192 and b == 168) or (a == 169 and b == 254)


func host(port: int) -> Error:
	is_host = true
	peer = ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_CLIENTS)
	if err != OK:
		peer = null
		return err
	_watch()
	return OK


func join(address: String, port: int) -> Error:
	is_host = false
	if not is_private_address(address):
		return ERR_UNAUTHORIZED
	peer = ENetMultiplayerPeer.new()
	var err := peer.create_client(address, port)
	if err != OK:
		peer = null
		return err
	_watch()
	return OK


func _watch() -> void:
	peer.peer_connected.connect(func(id: int) -> void:
		var address := ""
		var remote := peer.get_peer(id)
		if remote != null:
			address = remote.get_remote_address()
		peers.append(id)
		_events.append({"kind": "connected", "peer": id, "address": address}))
	peer.peer_disconnected.connect(func(id: int) -> void:
		peers.erase(id)
		_refused.erase(id)
		_events.append({"kind": "disconnected", "peer": id}))


func is_open() -> bool:
	return peer != null and peer.get_connection_status() != MultiplayerPeer.CONNECTION_DISCONNECTED


## Manda `bytes` para a outra ponta (o anfitrião para a parceira, a convidada para o anfitrião).
func send(bytes: PackedByteArray) -> void:
	if peer == null:
		return
	if latency_ms <= 0 and loss <= 0.0:
		_put(bytes)
		return
	# Em ordem, como o canal: um pacote "perdido" atrasa também os que vêm atrás dele.
	_out_at = maxi(_out_at, Time.get_ticks_msec() + latency_ms + (RESEND_MS if _rng.randf() < loss else 0))
	_out.append([_out_at, bytes])


func _put(bytes: PackedByteArray) -> void:
	if is_host and peers.is_empty():
		return
	peer.transfer_mode = MultiplayerPeer.TRANSFER_MODE_RELIABLE
	peer.transfer_channel = 0
	peer.set_target_peer(peers[0] if is_host else MultiplayerPeer.TARGET_PEER_SERVER)
	peer.put_packet(bytes)


## Solta os pacotes atrasados que venceram, lê o que chegou e devolve os eventos novos.
func poll() -> Array[Dictionary]:
	if peer == null:
		var none: Array[Dictionary] = []
		return none
	# Depois da desconexão o ENet não aceita mais poll; os eventos que ficaram (a própria desconexão) ainda saem.
	if is_open():
		var now := Time.get_ticks_msec()
		while not _out.is_empty() and int((_out[0] as Array)[0]) <= now:
			_put((_out.pop_front() as Array)[1])
		peer.poll()
		while peer.get_available_packet_count() > 0:
			var from := peer.get_packet_peer()
			var data := peer.get_packet()
			if not _refused.has(from):
				_events.append({"kind": "packet", "peer": from, "data": data})
		_drop_refused()
	var out := _events
	_events = []
	return out


## Manda já o que está na fila (atrasados de teste e o que o ENet guarda até o próximo poll): antes de o app parar em
## segundo plano (LanSession.set_paused).
func flush() -> void:
	if peer == null or not is_open():
		return
	while not _out.is_empty():
		_put((_out.pop_front() as Array)[1])
	peer.poll()


## Quanto o ENet espera a outra ponta sem resposta antes de desconectar: TIMEOUT_MS, ou `seconds` com uma das pontas
## em pausa (o app em segundo plano no Android não responde).
func patience(seconds: float = 0.0) -> void:
	if peer == null:
		return
	var most := maxi(TIMEOUT_MS, int(seconds * 1000.0))
	for id: int in (peers.duplicate() if is_host else [MultiplayerPeer.TARGET_PEER_SERVER]):
		var remote := peer.get_peer(id)
		if remote != null:
			remote.set_timeout(ENET_TIMEOUT_LIMIT, most, most)


## Recusa e derruba a conexão `id` (endereço fora da rede local, versão diferente, sala cheia). O aviso sai confiável
## e a desconexão só vem REFUSE_GRACE_MS depois, com peer_disconnect_later (que espera a fila sair): o cliente do
## Godot descarta os pacotes que chegam junto com a desconexão, então a ponta recusada precisa ler o aviso antes
## (ela mesma fecha ao recebê-lo). Da ponta recusada nada mais é lido.
func refuse(id: int, bytes: PackedByteArray) -> void:
	if peer == null or not peers.has(id):
		return
	peer.transfer_mode = MultiplayerPeer.TRANSFER_MODE_RELIABLE
	peer.transfer_channel = 0
	peer.set_target_peer(id)
	peer.put_packet(bytes)
	peers.erase(id)
	_refused[id] = Time.get_ticks_msec() + REFUSE_GRACE_MS


func _drop_refused() -> void:
	if _refused.is_empty():
		return
	var now := Time.get_ticks_msec()
	for id: int in _refused.keys():
		if int(_refused[id]) > now:
			continue
		_refused.erase(id)
		var remote := peer.get_peer(id)
		if remote != null:
			remote.peer_disconnect_later()


## Fim com educação: o que estava atrasado sai agora e a outra ponta recebe tudo antes do adeus.
func finish() -> void:
	if peer == null:
		return
	flush()
	# disconnect_later: o ENet só desconecta depois de mandar a fila (disconnect_peer a descartaria).
	for id: int in (peers.duplicate() if is_host else [MultiplayerPeer.TARGET_PEER_SERVER]):
		var remote := peer.get_peer(id)
		if remote != null:
			remote.peer_disconnect_later()


func close() -> void:
	if peer != null:
		peer.close()
	peer = null
	peers.clear()
	_out.clear()
	_refused.clear()
	_events.clear()
