class_name LanSession
extends RefCounted
## Coop em rede local (Wi-Fi), 2 aparelhos: a sala (código de 4 dígitos, LanRoom), o aperto de mão e a partida em
## lockstep de entradas. Sem nós e sem autoloads: o App a guarda e chama poll() a cada quadro; os testes rodam duas
## no mesmo processo em 127.0.0.1.
##
## Sala: o anfitrião abre (host) e mostra o código; a convidada entra (join) e o acha pela busca na rede. A convidada
## manda HELLO (protocolo, versão do jogo, revisão da Sim, a nave dela e a altura de campo que cabe na tela dela); o
## anfitrião confere e responde WELCOME, ou REFUSE ("version", "full"). Com as duas na sala o anfitrião manda START: a
## fila de missões, a semente e a carga, tudo o que entra em Sim.setup (pack_for). Nada local do aparelho entra na Sim
## sem vir desse pacote.
##
## Partida: os dois aparelhos rodam a mesma Sim. A cada passo cada lado manda a própria SimInput para o passo
## N + DELAY e só dá o passo quando tem as duas (take); sem a da parceira, espera. A entrada vai em binário (os
## campos do replay, floats de 32 bits) e quem a gera usa a mesma versão quantizada que mandou (push), senão as
## Sims divergem. A cada HASH_EVERY passos os lados trocam SimHash: diferença encerra a partida nos dois ("desync").
## Queda da conexão (NetLink.TIMEOUT_MS) encerra com "lost"; a parceira saindo, com "left". O adeus do fim da corrida
## ("done") não encerra quem ainda está uns passos atrás: as entradas dela até o fim já chegaram.

signal changed
## Começou a corrida (nos dois aparelhos): {"missions": [ids], "seed", "loadout"}.
signal started(pack: Dictionary)
## A partida ou a sala caiu sem este aparelho pedir (`error` diz o motivo).
signal ended(reason: StringName)

enum State { IDLE, HOSTING, SEEKING, LINKED, PLAYING }
enum Msg { HELLO, WELCOME, REFUSE, START, INPUT, HASH, PAUSE, BYE }

const PROTOCOL := 1
## Atraso das entradas, em passos (50 ms): cobre a ida da entrada no Wi-Fi sem a Sim esperar.
const DELAY := 3
const HASH_EVERY := 60
## Com um dos lados em pausa (app em segundo plano no Android não responde) a conexão espera isto antes de cair.
const AWAY_SECONDS := 120.0
const CONNECT_SECONDS := 5.0
const INPUT_BYTES := 25
## Chave de uma entrada: missão da corrida * LAP_SPAN + passo (uma missão tem bem menos passos que isto).
const LAP_SPAN := 1 << 24
const MAX_BUFFER := 4096
const DYING_MS := 500

var state := State.IDLE
var is_host: bool = false
var code: String = ""
## Motivo da última falha: no_network, port, not_found, full, version, left, lost, desync (ou vazio).
var error: StringName = &""
## O que este aparelho diz de si no aperto de mão e o que a parceira disse: {"ship", "level", "field_h"}.
var mine: Dictionary = {}
var partner: Dictionary = {}
var version: String = String(ProjectSettings.get_setting("application/config/version", ""))
var link: NetLink
## Missão da corrida (0, 1, 2...) e o próximo passo a simular nela.
var lap: int = -1
var tick: int = 0
var partner_paused: bool = false
## Testes: tudo em 127.0.0.1 (nada vai para a rede de verdade), com latência e perda simuladas no NetLink.
var loopback: bool = false
var test_latency_ms: int = 0
var test_loss: float = 0.0
## Quanto a convidada procura a sala antes de desistir (os testes encurtam).
var seek_seconds: float = LanRoom.SEEK_FOR

var _answer: LanRoom.Answer
var _seek: LanRoom.Seek
var _connect_left: float = 0.0
var _peer_id: int = 0
var _paused: bool = false
var _sent: int = 0
var _mine: Dictionary = {}
var _theirs: Dictionary = {}
var _my_hash: Dictionary = {}
var _their_hash: Dictionary = {}
## Enlace que já se despediu: fica vivo um instante para o adeus sair antes de fechar.
var _dying: NetLink
var _dying_at: int = 0
## A parceira já terminou a corrida e fechou o enlace (adeus "done"): o resto da missão sai das entradas guardadas.
var _partner_done: bool = false


# --- Sala ----------------------------------------------------------------------------------------

## Abre a sala e sorteia o código. `info`: {"ship", "level", "field_h"} deste aparelho.
func host(info: Dictionary) -> bool:
	leave()
	if _dying != null:
		# A sala anterior deste aparelho ainda se despedia: a porta dela precisa estar livre para a nova.
		_dying.close()
		_dying = null
	mine = info
	is_host = true
	error = &""
	if not loopback and LanRoom.local_addresses().is_empty():
		return _fail(&"no_network")
	link = NetLink.new(test_latency_ms, test_loss)
	var port := 0
	for slot: int in range(LanRoom.SLOTS):
		if link.host(LanRoom.BASE_PORT + LanRoom.test_shift + slot) == OK:
			port = LanRoom.BASE_PORT + LanRoom.test_shift + slot
			break
	_answer = LanRoom.Answer.new()
	code = LanRoom.new_code()
	if port == 0 or not _answer.open(code, port):
		return _fail(&"port")
	_enter(State.HOSTING)
	return true


## Procura a sala `p_code` na rede local e entra nela.
func join(p_code: String, info: Dictionary) -> bool:
	leave()
	mine = info
	is_host = false
	error = &""
	if not LanRoom.is_valid(p_code):
		return _fail(&"not_found")
	var addresses := PackedStringArray(["127.0.0.1"]) if loopback else LanRoom.local_addresses()
	if addresses.is_empty():
		return _fail(&"no_network")
	code = p_code
	_seek = LanRoom.Seek.new()
	if not _seek.open(code, addresses if loopback else LanRoom.targets(addresses)):
		return _fail(&"no_network")
	_seek.left = seek_seconds
	_connect_left = CONNECT_SECONDS
	_enter(State.SEEKING)
	return true


## Pacote de início que o anfitrião manda: a carga `base` com a nave da parceira na ala, a MENOR altura de campo das
## duas telas (cabe nas duas) e sensibilidade 1 (cada aparelho aplica a sua no próprio arrasto antes de mandar).
func pack_for(base: Dictionary, missions: Array, seed: int) -> Dictionary:
	var loadout := base.duplicate(true)
	loadout["coop"] = true
	loadout["coop_ship"] = String(partner.get("ship", "manta"))
	loadout["coop_level"] = int(partner.get("level", 1))
	loadout["field_h"] = minf(float(mine.get("field_h", Playfield.FIELD.y)), float(partner.get("field_h",
			Playfield.FIELD.y)))
	loadout["sensitivity"] = 1.0
	loadout["rev"] = SimRevision.CURRENT
	return {"missions": missions, "seed": seed, "loadout": loadout}


## Anfitrião, com a parceira na sala: começa a corrida nos dois aparelhos.
func start(pack: Dictionary) -> void:
	if not is_host or state != State.LINKED:
		return
	link.send(_msg(Msg.START, pack))
	_begin(pack)


## Sai da sala ou da partida por vontade própria (a parceira recebe o motivo). Não emite `ended`.
func leave(why: StringName = &"left") -> void:
	if link != null and state in [State.LINKED, State.PLAYING]:
		link.send(_msg(Msg.BYE, {"why": String(why)}))
		link.finish()
		if _dying != null:
			_dying.close()
		_dying = link
		_dying_at = Time.get_ticks_msec() + DYING_MS
		link = null
	var was := state
	_close()
	if was != State.IDLE:
		changed.emit()


func poll(delta: float) -> void:
	if _dying != null:
		_dying.poll()
		if Time.get_ticks_msec() >= _dying_at:
			_dying.close()
			_dying = null
	if _answer != null:
		_answer.poll()
	if _seek != null:
		if _seek.poll(delta):
			link = NetLink.new(test_latency_ms, test_loss)
			var err := link.join(_seek.found_ip, _seek.found_port)
			_seek = null
			if err != OK:
				_fail(&"not_found")
		elif not _seek.active():
			_fail(&"not_found")
	elif state == State.SEEKING:
		_connect_left -= delta
		if _connect_left <= 0.0:
			_fail(&"not_found")
	if link == null:
		return
	for ev: Dictionary in link.poll():
		if link == null:
			return
		_on_event(ev)


func _on_event(ev: Dictionary) -> void:
	var from := int(ev["peer"])
	match String(ev["kind"]):
		"connected":
			link.patience()
			if not is_host:
				var hello := mine.duplicate()
				hello.merge({"proto": PROTOCOL, "version": version, "rev": SimRevision.CURRENT})
				link.send(_msg(Msg.HELLO, hello))
			elif link.peers.size() > 1 or not NetLink.is_private_address(String(ev.get("address", ""))):
				# A vaga é de uma parceira só, e só da rede local.
				link.refuse(from, _msg(Msg.REFUSE, {"why": "full"}))
		"disconnected":
			if is_host and from != _peer_id:
				return
			if state == State.PLAYING:
				_end(&"lost")
			elif state == State.SEEKING:
				_fail(&"not_found")
			elif state == State.LINKED and is_host:
				# A parceira saiu da sala: a vaga volta a ficar livre, com o mesmo código.
				_peer_id = 0
				partner = {}
				_enter(State.HOSTING)
			elif state == State.LINKED:
				_end(&"left")
		"packet":
			if not is_host or (not link.peers.is_empty() and from == link.peers[0]):
				_on_packet(from, ev["data"])


func _on_packet(from: int, data: PackedByteArray) -> void:
	if data.is_empty():
		return
	if data[0] == Msg.INPUT:
		_read_input(data)
		return
	var parsed: Variant = bytes_to_var(data.slice(1)) if data.size() > 1 else null
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var body: Dictionary = parsed
	match int(data[0]):
		Msg.HELLO:
			if not is_host or state != State.HOSTING:
				return
			if int(body.get("proto", 0)) != PROTOCOL or String(body.get("version", "")) != version \
					or int(body.get("rev", 0)) != SimRevision.CURRENT:
				link.refuse(from, _msg(Msg.REFUSE, {"why": "version"}))
				return
			_peer_id = from
			partner = _clean_info(body)
			link.send(_msg(Msg.WELCOME, mine))
			_enter(State.LINKED)
		Msg.WELCOME:
			if not is_host and state == State.SEEKING:
				partner = _clean_info(body)
				_enter(State.LINKED)
		Msg.REFUSE:
			if not is_host and state == State.SEEKING:
				var why := String(body.get("why", ""))
				_fail(StringName(why) if why in ["full", "version"] else &"not_found")
		Msg.START:
			if not is_host and state == State.LINKED and valid_pack(body):
				_begin(body)
		Msg.HASH:
			if state == State.PLAYING and _their_hash.size() < MAX_BUFFER:
				_their_hash[int(body.get("k", -1))] = String(body.get("h", ""))
				_compare(int(body.get("k", -1)))
		Msg.PAUSE:
			partner_paused = bool(body.get("on", false))
			_sync_patience()
			changed.emit()
		Msg.BYE:
			var why := String(body.get("why", ""))
			if why == "done" and state == State.PLAYING:
				# Fim normal da corrida: a parceira terminou e fechou. Este aparelho pode estar uns passos atrás (em
				# pausa, ou o adeus chegou junto com as últimas entradas): as entradas dela até o fim já chegaram (canal
				# em ordem), então ele termina a própria missão com elas e fecha ao gravar o resultado (leave). Sem
				# `error` e sem `ended`: nada a avisar.
				_partner_done = true
				link.close()
				link = null
				changed.emit()
			elif why == "done":
				_close()
				changed.emit()
			elif not (is_host and state == State.LINKED):
				# (A convidada que sai da sala do anfitrião só libera a vaga, quando a conexão dela fecha.)
				_end(&"desync" if why == "desync" else &"left")


## O que a parceira disse de si, só com os tipos e as faixas que a Sim aceita (vem da rede).
static func _clean_info(body: Dictionary) -> Dictionary:
	return {"ship": String(body.get("ship", "manta")).left(32),
			"level": clampi(int(body.get("level", 1)), 1, Economy.SHIP_MAX_LEVEL),
			"field_h": clampf(float(body.get("field_h", Playfield.FIELD.y)), Playfield.FIELD.y, Playfield.MAX_HEIGHT)}


## Pacote de início aceitável (vem da rede): missões que existem neste jogo, semente e carga.
static func valid_pack(pack: Dictionary) -> bool:
	var missions: Variant = pack.get("missions")
	if typeof(missions) != TYPE_ARRAY or (missions as Array).is_empty() or (missions as Array).size() > 32:
		return false
	for id: Variant in missions:
		if typeof(id) != TYPE_STRING or not String(id).is_valid_identifier() \
				or not FileAccess.file_exists("res://data/stages/%s.json" % id):
			return false
	return typeof(pack.get("seed")) == TYPE_INT and typeof(pack.get("loadout")) == TYPE_DICTIONARY


func _begin(pack: Dictionary) -> void:
	# Em partida a sala some da rede.
	if _answer != null:
		_answer.close()
		_answer = null
	lap = -1
	partner_paused = false
	_paused = false
	state = State.PLAYING
	changed.emit()
	started.emit(pack)


# --- Lockstep ------------------------------------------------------------------------------------

## Começa a próxima missão da corrida (os dois aparelhos chamam ao criar a partida): os primeiros DELAY passos, que
## ninguém teve tempo de mandar, usam a entrada neutra nos dois lados.
func begin_round() -> void:
	lap += 1
	tick = 0
	_sent = DELAY
	_my_hash.clear()
	_their_hash.clear()
	_mine.clear()
	for key: int in _theirs.keys():
		if key < lap * LAP_SPAN:
			_theirs.erase(key)
	for t: int in range(DELAY):
		_mine[_key(t)] = SimInput.new()
		_theirs[_key(t)] = SimInput.new()


## Falta mandar a entrada do passo `tick + DELAY`? Só então o Game lê os controles (o arrasto do dedo se acumula
## enquanto a Sim espera a parceira, em vez de se perder).
func wants_input() -> bool:
	return state == State.PLAYING and _sent <= tick + DELAY


## Manda a entrada deste aparelho para o passo `tick + DELAY` e guarda a mesma versão quantizada para a própria Sim.
func push(input: SimInput) -> void:
	var bytes := encode_input(lap, _sent, input)
	_mine[_key(_sent)] = decode_input(bytes)[2]
	_send(bytes)
	_sent += 1


## As duas entradas do próximo passo, [nave 1 (anfitrião), ala (convidada)], ou vazio se a da parceira não chegou.
func take() -> Array[SimInput]:
	var out: Array[SimInput] = []
	var key := _key(tick)
	if state == State.PLAYING and _partner_done and not _theirs.has(key):
		# A parceira fechou e esta missão pede mais do que ela mandou: não há como seguir.
		_end(&"left")
	if state != State.PLAYING or not _mine.has(key) or not _theirs.has(key):
		return out
	var a: SimInput = _mine[key]
	var b: SimInput = _theirs[key]
	_mine.erase(key)
	_theirs.erase(key)
	tick += 1
	out.append(a if is_host else b)
	out.append(b if is_host else a)
	return out


## A parceira já está passos à frente (este aparelho engasgou): o Game dá um passo a mais neste quadro.
func behind() -> bool:
	return _theirs.has(_key(tick + DELAY + 2))


## Depois de cada passo: a cada HASH_EVERY passos (e no fim da missão) manda o hash do estado e confere com o dela.
func after_step(sim: Sim) -> void:
	if state != State.PLAYING or (tick % HASH_EVERY != 0 and not sim.finished):
		return
	var key := _key(tick)
	_my_hash[key] = sim.state_hash()
	_send(_msg(Msg.HASH, {"k": key, "h": _my_hash[key]}))
	_compare(key)


## Pausa deste aparelho (menu de pausa ou app em segundo plano): avisa a parceira, que passa a esperar, e manda já,
## porque o Android pode congelar o app logo em seguida.
func set_paused(on: bool) -> void:
	if state != State.PLAYING or on == _paused:
		return
	_paused = on
	_send(_msg(Msg.PAUSE, {"on": on}))
	_sync_patience()
	if link != null:
		link.flush()


func _sync_patience() -> void:
	if link != null:
		link.patience(AWAY_SECONDS if _paused or partner_paused else 0.0)


## Manda para a parceira, se o enlace ainda existe (depois do adeus "done" dela não existe mais).
func _send(bytes: PackedByteArray) -> void:
	if link != null:
		link.send(bytes)


func _compare(key: int) -> void:
	if not _my_hash.has(key) or not _their_hash.has(key):
		return
	var same: bool = _my_hash[key] == _their_hash[key]
	_my_hash.erase(key)
	_their_hash.erase(key)
	if not same:
		leave(&"desync")
		error = &"desync"
		ended.emit(&"desync")


func _read_input(data: PackedByteArray) -> void:
	var row := decode_input(data)
	if row.is_empty() or state != State.PLAYING or _theirs.size() >= MAX_BUFFER:
		return
	var key := int(row[0]) * LAP_SPAN + int(row[1])
	# Uma missão à frente pode chegar antes de este aparelho sair do resultado da anterior: fica guardada.
	if key >= _key(tick):
		_theirs[key] = row[2]


func _key(t: int) -> int:
	return lap * LAP_SPAN + t


## Entrada de um passo em INPUT_BYTES bytes: missão, passo e os campos do replay (Replay.bits_of).
static func encode_input(p_lap: int, p_tick: int, input: SimInput) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(INPUT_BYTES)
	out[0] = Msg.INPUT
	out[1] = p_lap & 0xff
	out.encode_u32(2, p_tick)
	out.encode_float(6, input.move.x)
	out.encode_float(10, input.move.y)
	out.encode_float(14, input.axis.x)
	out.encode_float(18, input.axis.y)
	out[22] = Replay.bits_of(input)
	out[23] = clampi(input.taps, 0, 255)
	out.encode_s8(24, clampi(input.choice, -1, 127))
	return out


## [missão, passo, SimInput] de um pacote de entrada, ou vazio se ele não serve (tamanho errado, número não finito).
static func decode_input(data: PackedByteArray) -> Array:
	if data.size() != INPUT_BYTES or data[0] != Msg.INPUT:
		return []
	var input := SimInput.new()
	input.move = Vector2(data.decode_float(6), data.decode_float(10))
	input.axis = Vector2(data.decode_float(14), data.decode_float(18))
	if not input.move.is_finite() or not input.axis.is_finite():
		return []
	Replay.set_bits(input, data[22])
	input.taps = data[23]
	input.choice = data.decode_s8(24)
	return [int(data[1]), data.decode_u32(2), input]


static func _msg(kind: Msg, body: Dictionary) -> PackedByteArray:
	var out := PackedByteArray([kind])
	out.append_array(var_to_bytes(body))
	return out


# --- Estado --------------------------------------------------------------------------------------

func _enter(value: State) -> void:
	state = value
	changed.emit()


## Falha ao abrir ou entrar na sala: fecha tudo e deixa o motivo em `error`.
func _fail(reason: StringName) -> bool:
	_close()
	error = reason
	changed.emit()
	return false


## A sala ou a partida caiu sem este aparelho pedir.
func _end(reason: StringName) -> void:
	_close()
	error = reason
	changed.emit()
	ended.emit(reason)


func _close() -> void:
	if _answer != null:
		_answer.close()
	if _seek != null:
		_seek.close()
	if link != null:
		link.close()
	_answer = null
	_seek = null
	link = null
	state = State.IDLE
	code = ""
	partner = {}
	_peer_id = 0
	partner_paused = false
	_paused = false
	_partner_done = false
	_mine.clear()
	_theirs.clear()
	_my_hash.clear()
	_their_hash.clear()
