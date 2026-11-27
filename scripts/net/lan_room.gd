class_name LanRoom
extends RefCounted
## Sala do coop em rede local: um código de 4 dígitos sorteado pelo anfitrião e a busca dele na rede.
## - o anfitrião, com a sala aberta, escuta a porta FIND_PORT em todas as placas e só responde à pergunta que traz o
##   código dele;
## - a convidada pergunta a cada SEEK_EVERY s por SEEK_FOR s: no broadcast geral, no de cada rede /24 dela e em cada
##   endereço dessas redes (o unicast chega mesmo onde o roteador filtra o broadcast);
## - a resposta vem do endereço do anfitrião e traz a porta do ENet dele.
## Pergunta: "ATLP" + o código (4 dígitos ASCII). Resposta: "ATLR" + o código + a porta do ENet (u16). Só isso vai na
## rede (nada do perfil nem do aparelho), e as duas pontas só aceitam endereços privados (NetLink.is_private_address).
## Permissões: só a INTERNET do Android (mandar broadcast e unicast e receber unicast não pedem mais nada).
##
## Origem: lan_find.gd do projeto hyakki (mesmo autor, MIT); lá o código sai do IP, aqui é sorteado.

const PROBE := "ATLP"
const REPLY := "ATLR"
## Portas do ENet (a primeira livre das SLOTS) e a da busca, logo depois.
const BASE_PORT := 47440
const SLOTS := 10
const FIND_PORT := BASE_PORT + SLOTS
const SEEK_FOR := 8.0
const SEEK_EVERY := 1.0
## Redes /24 varridas pela convidada (o broadcast geral vai sempre).
const SWEEP_NETS := 3
## Pacotes lidos por chamada (uma rede barulhenta não segura o quadro).
const READ_MAX := 32
## Dados móveis pelo nome da placa (Android rmnet/ccmni, o clat do IPv4 sobre IPv6, o "Cellular" do Windows).
const CELLULAR_HINTS: Array[String] = ["rmnet", "ccmni", "clat", "pdp", "wwan", "cellular"]

## Só para testes: desloca as portas, para suítes que rodam em processos paralelos não abrirem a mesma sala.
static var test_shift: int = 0


## Código novo de sala: 4 dígitos ao acaso (fora da Sim: não precisa de semente).
static func new_code() -> String:
	return "%04d" % (randi() % 10000)


## Código válido: exatamente 4 dígitos ASCII (nada de sinal, espaço ou outros algarismos).
static func is_valid(code: String) -> bool:
	if code.length() != 4:
		return false
	for c: String in code:
		if not "0123456789".contains(c):
			return false
	return true


## IPv4 privados deste aparelho: vazio = sem Wi-Fi nem rede local.
static func local_addresses() -> PackedStringArray:
	return addresses_of(IP.get_local_interfaces())


## IPv4 privados das placas `interfaces` (linhas de IP.get_local_interfaces), sem 127.x, link-local nem as placas de
## dados móveis: a operadora dá muitas vezes um 10.x que o outro aparelho nunca alcança, e só com ele o jogo tem de
## dizer "sem rede local".
static func addresses_of(interfaces: Array) -> PackedStringArray:
	var out := PackedStringArray()
	for row: Variant in interfaces:
		var iface: Dictionary = row if row is Dictionary else {}
		var label := (String(iface.get("name", "")) + " " + String(iface.get("friendly", ""))).to_lower()
		var cellular := false
		for hint: String in CELLULAR_HINTS:
			cellular = cellular or label.contains(hint)
		for value: Variant in ([] if cellular else iface.get("addresses", [])):
			var address := String(value)
			if not address.contains(":") and not address.begins_with("127.") and not address.begins_with("169.254.") \
					and NetLink.is_private_address(address) and not out.has(address):
				out.append(address)
	return out


static func probe(code: String) -> PackedByteArray:
	return (PROBE + code).to_ascii_buffer()


## O código de uma pergunta ("" se não é uma pergunta válida).
static func read_probe(data: PackedByteArray) -> String:
	if data.size() != 8 or data.slice(0, 4).get_string_from_ascii() != PROBE:
		return ""
	var code := data.slice(4).get_string_from_ascii()
	return code if is_valid(code) else ""


static func reply(code: String, port: int) -> PackedByteArray:
	var out := (REPLY + code).to_ascii_buffer()
	out.resize(10)
	out.encode_u16(8, port)
	return out


## A porta do ENet de uma resposta à pergunta de `code` (0 se não é resposta, é de outra sala ou a porta está fora
## das vagas).
static func read_reply(data: PackedByteArray, code: String) -> int:
	if data.size() != 10 or data.slice(0, 4).get_string_from_ascii() != REPLY:
		return 0
	if data.slice(4, 8).get_string_from_ascii() != code:
		return 0
	var port := data.decode_u16(8)
	return port if port >= BASE_PORT + test_shift and port < BASE_PORT + test_shift + SLOTS else 0


## Anfitrião: a resposta a `data` vindo de `from` (vazia se não é a pergunta pela sala `code` ou se `from` não é da
## rede local).
static func answer_for(data: PackedByteArray, from: String, code: String, port: int) -> PackedByteArray:
	if code.is_empty() or read_probe(data) != code or not NetLink.is_private_address(from):
		return PackedByteArray()
	return reply(code, port)


## Para onde a convidada pergunta: o broadcast geral e, em cada rede /24 de `addresses` (os IPv4 dela), o broadcast
## da rede e cada endereço menos o dela.
static func targets(addresses: PackedStringArray) -> PackedStringArray:
	var out := PackedStringArray(["255.255.255.255"])
	var nets: Array[String] = []
	for address: String in addresses:
		var net := address.substr(0, address.rfind(".") + 1)
		if nets.has(net) or nets.size() >= SWEEP_NETS:
			continue
		nets.append(net)
		out.append(net + "255")
		for n: int in range(1, 255):
			if net + str(n) != address:
				out.append(net + str(n))
	return out


static func _plain(ip: String) -> String:
	return ip.substr(7) if ip.begins_with("::ffff:") else ip


## Anfitrião: escuta a porta de busca e responde ao código da sala.
class Answer extends RefCounted:
	var udp := PacketPeerUDP.new()
	var code: String = ""
	var port: int = 0

	## false se a porta de busca está ocupada (outra sala aberta neste mesmo aparelho).
	func open(p_code: String, p_port: int) -> bool:
		code = p_code
		port = p_port
		return udp.bind(LanRoom.FIND_PORT + LanRoom.test_shift, "0.0.0.0") == OK

	func poll() -> void:
		if not udp.is_bound():
			return
		for _i: int in LanRoom.READ_MAX:
			if udp.get_available_packet_count() <= 0:
				return
			var data := udp.get_packet()
			var from := LanRoom._plain(udp.get_packet_ip())
			var from_port := udp.get_packet_port()
			var out := LanRoom.answer_for(data, from, code, port)
			if not out.is_empty() and udp.set_dest_address(from, from_port) == OK:
				udp.put_packet(out)

	func close() -> void:
		udp.close()


## Convidada: pergunta pela sala `code` em `to` a cada SEEK_EVERY s, por SEEK_FOR s.
class Seek extends RefCounted:
	var udp := PacketPeerUDP.new()
	var code: String = ""
	var to := PackedStringArray()
	var left: float = LanRoom.SEEK_FOR
	## Achou: o endereço do anfitrião e a porta do ENet.
	var found_ip: String = ""
	var found_port: int = 0
	var _next: float = 0.0

	func open(p_code: String, p_targets: PackedStringArray) -> bool:
		code = p_code
		to = p_targets
		udp.set_broadcast_enabled(true)
		return udp.bind(0, "0.0.0.0") == OK

	## Ainda procurando (false: achou, o prazo acabou ou o socket fechou).
	func active() -> bool:
		return udp.is_bound()

	## Anda `delta` s; true quando achou (found_ip e found_port), e então fecha.
	func poll(delta: float) -> bool:
		if not udp.is_bound():
			return false
		for _i: int in LanRoom.READ_MAX:
			if udp.get_available_packet_count() <= 0:
				break
			var data := udp.get_packet()
			var from := LanRoom._plain(udp.get_packet_ip())
			var port := LanRoom.read_reply(data, code)
			if port > 0 and NetLink.is_private_address(from):
				found_ip = from
				found_port = port
				close()
				return true
		left -= delta
		if left <= 0.0:
			close()
			return false
		_next -= delta
		if _next <= 0.0:
			_next = LanRoom.SEEK_EVERY
			var bytes := LanRoom.probe(code)
			for address: String in to:
				if udp.set_dest_address(address, LanRoom.FIND_PORT + LanRoom.test_shift) == OK:
					udp.put_packet(bytes)
		return false

	func close() -> void:
		udp.close()
