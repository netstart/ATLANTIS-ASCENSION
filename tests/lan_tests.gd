extends RefCounted
## Coop em rede local (scripts/net): regras da sala e da codificação de entrada, o fator de coop (SimCurve) e o
## enlace de verdade, com duas LanSession e duas Sim no mesmo processo em 127.0.0.1 (ENet), com latência e perda
## simuladas: aperto de mão, recusas, espera quando falta a entrada, hashes iguais ao fim de uma missão e encerramento
## limpo em saída, queda e dessincronia. Chamado por tests/run_tests.gd (sem autoloads).
##
## Os testes de enlace abrem portas fixas (LanRoom): ficam todos numa unidade só, para duas fatias em paralelo nunca
## abrirem a mesma sala.

const HOST_INFO := {"ship": "falcon", "level": 3, "field_h": 600.0}
const GUEST_INFO := {"ship": "manta", "level": 2, "field_h": 520.0}
const PUMP_SECONDS := 6.0
## Portas desta suíte (LanRoom.test_shift): fora das do jogo e das de tests/lan_screen_tests.gd.
const PORT_SHIFT := 40

var _tables: Dictionary = {}


func units() -> Array[Dictionary]:
	return [{"name": "Coop LAN: sala, lockstep e enlace", "weight": 60.0, "run": _link}]


## Regras rápidas (sem rede).
func run_unit(check: Callable) -> void:
	_tables = Sim.load_tables()
	_room(check)
	_codec(check)
	_coop_factor(check)


func _room(check: Callable) -> void:
	var ok := true
	for _i: int in range(50):
		ok = ok and LanRoom.is_valid(LanRoom.new_code())
	check.call(ok, "Sala: o código sorteado tem sempre 4 dígitos")
	check.call(LanRoom.is_valid("0007") and not LanRoom.is_valid("123") and not LanRoom.is_valid("12345")
			and not LanRoom.is_valid("12a4") and not LanRoom.is_valid("-123") and not LanRoom.is_valid("１２３４"),
			"Sala: só 4 dígitos ASCII valem")
	check.call(LanRoom.read_probe(LanRoom.probe("4821")) == "4821" and LanRoom.read_probe("ATLP48".to_ascii_buffer()) == ""
			and LanRoom.read_probe("HYKP4821".to_ascii_buffer()) == "", "Sala: pergunta com o código")
	var port := LanRoom.BASE_PORT + LanRoom.test_shift + 2
	check.call(LanRoom.read_reply(LanRoom.reply("4821", port), "4821") == port, "Sala: a resposta traz a porta")
	check.call(LanRoom.read_reply(LanRoom.reply("4821", port), "4822") == 0, "Sala: resposta de outra sala não serve")
	check.call(LanRoom.read_reply(LanRoom.reply("4821", 80), "4821") == 0, "Sala: porta fora das vagas é recusada")
	check.call(LanRoom.answer_for(LanRoom.probe("4821"), "192.168.0.12", "4821", port) == LanRoom.reply("4821", port),
			"Sala: o anfitrião responde ao código certo")
	check.call(LanRoom.answer_for(LanRoom.probe("4822"), "192.168.0.12", "4821", port).is_empty(),
			"Sala: o anfitrião cala para o código errado")
	check.call(LanRoom.answer_for(LanRoom.probe("4821"), "8.8.8.8", "4821", port).is_empty(),
			"Sala: o anfitrião cala para fora da rede local")
	for address: String in ["192.168.1.7", "10.0.0.3", "172.16.4.1", "172.31.255.2", "127.0.0.1", "169.254.3.3"]:
		check.call(NetLink.is_private_address(address), "Rede local: %s é privado" % address)
	for address: String in ["8.8.8.8", "172.32.0.1", "192.169.0.1", "200.1.2.3", "", "abc", "1.2.3", "2001:db8::1"]:
		check.call(not NetLink.is_private_address(address), "Rede local: '%s' é recusado" % address)
	var to := LanRoom.targets(PackedStringArray(["192.168.0.12", "192.168.0.13", "10.1.2.3"]))
	check.call(to.size() == 1 + 2 * 254 and to.has("255.255.255.255") and to.has("192.168.0.255") and to.has("10.1.2.1")
			and not to.has("192.168.0.12") and to.has("192.168.0.13"),
			"Sala: a busca vai ao broadcast e a cada endereço das redes /24 (%d)" % to.size())
	var nets := LanRoom.addresses_of([{"name": "wlan0", "addresses": ["192.168.0.12", "fe80::1", "192.168.0.12"]},
			{"name": "rmnet_data0", "addresses": ["10.44.1.2"]}, {"name": "lo", "addresses": ["127.0.0.1"]},
			{"name": "eth0", "friendly": "Ethernet", "addresses": ["169.254.1.1", "8.8.4.4", "10.0.0.5"]}])
	check.call(nets == PackedStringArray(["192.168.0.12", "10.0.0.5"]),
			"Sala: só IPv4 privados de Wi-Fi ou cabo contam como rede local (%s)" % str(nets))
	check.call(LanRoom.addresses_of([{"name": "rmnet_data0", "addresses": ["10.44.1.2"]}]).is_empty(),
			"Sala: só com dados móveis não há rede local")
	check.call(LanSession.valid_pack({"missions": ["c1m1", "c2m3"], "seed": 7, "loadout": {}}), "Pacote de início válido")
	for bad: Dictionary in [{"missions": [], "seed": 7, "loadout": {}}, {"missions": ["../x"], "seed": 7, "loadout": {}},
			{"missions": ["nao_existe"], "seed": 7, "loadout": {}}, {"missions": ["c1m1"], "seed": "7", "loadout": {}},
			{"missions": ["c1m1"], "seed": 7}, {"missions": "c1m1", "seed": 7, "loadout": {}}]:
		check.call(not LanSession.valid_pack(bad), "Pacote de início recusado: %s" % str(bad))
	var session := LanSession.new()
	session.mine = HOST_INFO
	session.partner = LanSession._clean_info({"ship": "manta", "level": 99, "field_h": 9000.0})
	check.call(int(session.partner["level"]) == Economy.SHIP_MAX_LEVEL
			and float(session.partner["field_h"]) == Playfield.MAX_HEIGHT, "Aperto de mão: o que vem da rede é limitado")
	session.partner = LanSession._clean_info(GUEST_INFO)
	var pack := session.pack_for(Sim.default_loadout(&"falcon"), ["c1m1"], 7)
	var load: Dictionary = pack["loadout"]
	check.call(bool(load["coop"]) and load["coop_ship"] == "manta" and int(load["coop_level"]) == 2
			and float(load["field_h"]) == 520.0 and float(load["sensitivity"]) == 1.0
			and int(load["rev"]) == SimRevision.CURRENT,
			"Pacote de início: ala = nave da convidada, campo = a menor das duas telas, sensibilidade 1")


## Entrada no fio: ida e volta, a mesma quantização nos dois lados e pacote malformado recusado.
func _codec(check: Callable) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var same := true
	var stable := true
	for k: int in range(200):
		var input := SimInput.new()
		input.move = Vector2(rng.randf_range(-30.0, 30.0), rng.randf_range(-30.0, 30.0))
		input.axis = Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0))
		Replay.set_bits(input, rng.randi_range(0, 63))
		input.taps = rng.randi_range(0, 6)
		input.choice = rng.randi_range(-1, 2)
		var bytes := LanSession.encode_input(k % 9, 100000 + k, input)
		var row := LanSession.decode_input(bytes)
		var got: SimInput = row[2]
		same = same and int(row[0]) == k % 9 and int(row[1]) == 100000 + k and Replay.bits_of(got) == Replay.bits_of(input) \
				and got.taps == input.taps and got.choice == input.choice and got.move.is_equal_approx(input.move) \
				and got.axis.is_equal_approx(input.axis)
		# O lado que gera usa o que decodificou: codificar de novo dá os mesmos bytes (nada mais se perde).
		stable = stable and LanSession.encode_input(k % 9, 100000 + k, got) == bytes
	check.call(same, "Entrada: ida e volta preserva os campos do replay")
	check.call(stable, "Entrada: a versão quantizada é a mesma nos dois lados")
	var good := LanSession.encode_input(0, 1, SimInput.new())
	check.call(good.size() == LanSession.INPUT_BYTES and LanSession.decode_input(good.slice(1)).is_empty(),
			"Entrada: tamanho errado é recusado")
	var nan := good.duplicate()
	nan.encode_float(6, NAN)
	check.call(LanSession.decode_input(nan).is_empty(), "Entrada: número não finito é recusado")
	var a := SimInput.new()
	var b := SimInput.new()
	b.special = true
	b.power = true
	b.tide = true
	b.taps = 2
	b.choice = 1
	a.taps = 1
	var m := a.merged(b)
	check.call(m.special and m.power and m.tide and m.taps == 3 and m.choice == 1 and not a.special,
			"Entrada do par: especial, PODER, Maré, toques e bênção valem de qualquer nave")
	a.choice = 0
	check.call(a.merged(b).choice == 0, "Entrada do par: a escolha da nave 1 vem primeiro")


func _coop_loadout() -> Dictionary:
	var load := Sim.default_loadout(&"falcon")
	load["coop"] = true
	load["coop_ship"] = "manta"
	return load


## `rev`: revisão das regras (0 = a atual).
func _sim(coop: bool, rev: int = 0) -> Sim:
	var sim := Sim.new()
	var load := _coop_loadout() if coop else Sim.default_loadout(&"falcon")
	if rev > 0:
		load["rev"] = rev
	sim.setup(Sim.load_mission(&"c2m3"), _tables, load, 7)
	return sim


## Fator de coop: vida × nos inimigos comuns e nos chefes, a mesma quantidade de balas do solo e mira na nave mais
## perto.
func _coop_factor(check: Callable) -> void:
	var solo := _sim(false)
	var coop := _sim(true)
	var spec := {"enemy": "", "count": 1}
	for id: StringName in _tables["enemies"]:
		var def: Dictionary = _tables["enemies"][id]
		if String(def.get("layer", "")) != "sea":
			spec["enemy"] = String(id)
			break
	solo.spawn_enemy(spec, 0)
	coop.spawn_enemy(spec, 0)
	check.call(is_equal_approx(coop.enemies[-1].max_hp, solo.enemies[-1].max_hp * SimCurve.COOP_HP)
			and coop.enemies[-1].hp == coop.enemies[-1].max_hp,
			"Coop: inimigo comum com vida ×%.1f (%.1f → %.1f)" % [SimCurve.COOP_HP, solo.enemies[-1].max_hp,
			coop.enemies[-1].max_hp])
	spec["path"] = "scroll"
	solo.spawn_enemy(spec, 0)
	coop.spawn_enemy(spec, 0)
	check.call(coop.enemies[-1].max_hp == solo.enemies[-1].max_hp,
			"Coop: quem desce com o cenário fica com a vida do solo")
	solo.spawn_boss(&"kraken_engine", true)
	coop.spawn_boss(&"kraken_engine", true)
	check.call(is_equal_approx(coop.boss.max_hp, solo.boss.max_hp * SimCurve.COOP_BOSS_HP),
			"Coop: chefe com vida ×%.1f (%.0f → %.0f)" % [SimCurve.COOP_BOSS_HP, solo.boss.max_hp, coop.boss.max_hp])
	# Mesma missão, ninguém atira nem leva dano: os inimigos vivem o mesmo tempo, então as balas que nascem têm de
	# ser as mesmas em número (a mira muda a direção, nunca a quantidade). Na revisão antes do mar: os mísseis do mar
	# saem sozinhos e, com a vida do coop, o inimigo ferido por eles viveria mais (e atiraria mais) sem culpa do padrão.
	var shots := [0, 0]
	var sims: Array[Sim] = [_sim(false, SecondaryFire.SEA_REVISION - 1), _sim(true, SecondaryFire.SEA_REVISION - 1)]
	var idle := SimInput.new()
	idle.fire = false
	idle.choice = 0
	for k: int in range(2):
		var sim := sims[k]
		for _f: int in range(60 * 40):
			sim.player.invuln = 600
			sim.player.pos.x = 20.0
			if sim.wing != null:
				sim.wing.invuln = 600
				# A ala longe da nave 1: sem Elo de Maré apagando balas.
				sim.wing.pos = Vector2(250.0, sim.player.pos.y)
			sim.step(idle, idle if sim.wing != null else null)
			for i: int in range(sim.enemy_bullets.count):
				if sim.enemy_bullets.age[i] == 1:
					shots[k] += 1
	check.call(shots[0] > 100 and shots[0] == shots[1], "Coop: o mesmo número de balas inimigas do solo (%d e %d)" % shots)
	var from := Vector2(240.0, 100.0)
	coop.wing.pos = Vector2(250.0, 380.0)
	coop.player.pos = Vector2(20.0, 380.0)
	check.call(SimCurve.target(coop, from) == coop.wing and SimCurve.target(coop, Vector2(30.0, 100.0)) == coop.player,
			"Coop: a bala mirada procura a nave mais perto")
	check.call(SimCurve.target(coop, Vector2(135.0, 100.0)) == coop.player, "Coop: no empate a mira é da nave 1")
	coop.wing.alive = false
	check.call(SimCurve.target(coop, from) == coop.player and SimCurve.target(solo, from) == solo.player,
			"Coop: sem ala viva (ou no solo) a mira é a nave 1")


# --- Enlace de verdade (127.0.0.1) ------------------------------------------------------------------

func _session(latency: int = 0, loss: float = 0.0) -> LanSession:
	var s := LanSession.new()
	s.loopback = true
	s.test_latency_ms = latency
	s.test_loss = loss
	s.seek_seconds = 2.0
	return s


## Faz as sessões andarem até `done` valer (ou o prazo acabar).
func _pump(sessions: Array, done: Callable, seconds: float = PUMP_SECONDS) -> bool:
	var end := Time.get_ticks_msec() + int(seconds * 1000.0)
	var last := Time.get_ticks_msec()
	while Time.get_ticks_msec() < end:
		var now := Time.get_ticks_msec()
		for s: LanSession in sessions:
			s.poll((now - last) / 1000.0)
		last = now
		if done.call():
			return true
		OS.delay_msec(1)
	return false


## Anfitrião e convidada já na sala (LINKED).
func _pair(latency: int = 0, loss: float = 0.0) -> Array[LanSession]:
	var host := _session(latency, loss)
	var guest := _session(latency, loss)
	host.host(HOST_INFO)
	guest.join(host.code, GUEST_INFO)
	_pump([host, guest], func() -> bool:
		return host.state == LanSession.State.LINKED and guest.state == LanSession.State.LINKED)
	var out: Array[LanSession] = [host, guest]
	return out


## Começa a corrida nos dois e devolve a Sim de cada lado, montada só com o pacote que aquele lado recebeu.
func _start(pair: Array[LanSession]) -> Array[Sim]:
	var packs := [{}, {}]
	for i: int in range(2):
		pair[i].started.connect(func(pack: Dictionary) -> void: packs[i] = pack)
	pair[0].start(pair[0].pack_for(Sim.default_loadout(&"falcon"), ["c1m1"], 7))
	_pump(pair, func() -> bool: return pair[1].state == LanSession.State.PLAYING)
	var sims: Array[Sim] = []
	for i: int in range(2):
		var pack: Dictionary = packs[i]
		var sim := Sim.new()
		if not pack.is_empty():
			var load: Dictionary = pack["loadout"]
			sim.setup(Sim.load_mission(StringName(String((pack["missions"] as Array)[0]))), _tables, load, int(pack["seed"]),
					float(load["sensitivity"]))
		sims.append(sim)
		pair[i].begin_round()
	return sims


## Um quadro de cada aparelho, como o Game._lan_tick: manda a entrada se falta, dá o passo se tem as duas. Devolve
## quantos passos saíram.
func _frame(pair: Array[LanSession], sims: Array[Sim], bots: Array[BotPilot]) -> int:
	var stepped := 0
	for i: int in range(2):
		var s := pair[i]
		s.poll(0.0)
		if s.state != LanSession.State.PLAYING or sims[i].finished:
			continue
		if s.wants_input():
			s.push(bots[i].decide(sims[i]) if i == 0 else bots[i].decide_wing(sims[i]))
		var inputs := s.take()
		if inputs.is_empty():
			continue
		sims[i].step(inputs[0], inputs[1])
		sims[i].take_events()
		s.after_step(sims[i])
		stepped += 1
	return stepped


func _link(check: Callable) -> void:
	_tables = Sim.load_tables()
	LanRoom.test_shift = PORT_SHIFT
	_handshake(check)
	_lockstep(check)
	_endings(check)
	LanRoom.test_shift = 0


func _handshake(check: Callable) -> void:
	var lost := _session()
	lost.seek_seconds = 0.3
	lost.join("0000", GUEST_INFO)
	_pump([lost], func() -> bool: return lost.state == LanSession.State.IDLE)
	check.call(lost.error == &"not_found", "Sala: código sem sala dá 'não encontrada' (%s)" % lost.error)
	check.call(not _session().join("12", GUEST_INFO), "Sala: código incompleto nem procura")
	var host := _session()
	check.call(host.host(HOST_INFO) and LanRoom.is_valid(host.code) and host.state == LanSession.State.HOSTING,
			"Sala: aberta com código %s" % host.code)
	var wrong := _session()
	wrong.seek_seconds = 0.3
	wrong.join("%04d" % ((int(host.code) + 1) % 10000), GUEST_INFO)
	_pump([host, wrong], func() -> bool: return wrong.state == LanSession.State.IDLE)
	check.call(wrong.error == &"not_found" and host.state == LanSession.State.HOSTING,
			"Sala: o anfitrião só responde ao código certo")
	var old := _session()
	old.version = "0.0.1"
	old.join(host.code, GUEST_INFO)
	_pump([host, old], func() -> bool: return old.state == LanSession.State.IDLE)
	check.call(old.error == &"version" and host.state == LanSession.State.HOSTING,
			"Aperto de mão: versão diferente é recusada com aviso (%s)" % old.error)
	var guest := _session()
	guest.join(host.code, GUEST_INFO)
	check.call(_pump([host, guest, old], func() -> bool:
		return host.state == LanSession.State.LINKED and guest.state == LanSession.State.LINKED),
			"Sala: a convidada acha a sala pelo código e entra")
	check.call(String(host.partner.get("ship", "")) == "manta" and String(guest.partner.get("ship", "")) == "falcon"
			and float(host.partner.get("field_h", 0.0)) == 520.0, "Aperto de mão: cada lado conhece a nave da outra")
	var third := _session()
	third.join(host.code, GUEST_INFO)
	_pump([host, guest, third], func() -> bool: return third.state == LanSession.State.IDLE)
	check.call(third.error == &"full" and host.state == LanSession.State.LINKED and guest.state == LanSession.State.LINKED,
			"Sala: cheia recusa o terceiro aparelho (%s)" % third.error)
	guest.leave()
	check.call(_pump([host, guest], func() -> bool: return host.state == LanSession.State.HOSTING)
			and LanRoom.is_valid(host.code) and host.partner.is_empty(),
			"Sala: a convidada saiu e a vaga volta, com o mesmo código")
	host.leave()
	_pump([host, guest], func() -> bool: return false, 0.6)


## Partida inteira em lockstep com latência e perda: a Sim espera quando falta a entrada e os dois lados terminam
## com o mesmo hash.
func _lockstep(check: Callable) -> void:
	var pair := _pair(12, 0.03)
	check.call(pair[1].state == LanSession.State.LINKED, "Lockstep: par na sala com latência e perda simuladas")
	var sims := _start(pair)
	check.call(pair[0].state == LanSession.State.PLAYING and pair[1].state == LanSession.State.PLAYING
			and sims[1].wing != null and sims[1].field.y == 520.0 and sims[0].field.y == 520.0,
			"Lockstep: os dois começam com o mesmo pacote (campo de %.0f)" % sims[1].field.y)
	var bots: Array[BotPilot] = [BotPilot.new(), BotPilot.new()]
	# Os primeiros DELAY passos saem com a entrada neutra; o seguinte só com a entrada da parceira.
	var host := pair[0]
	for _k: int in range(LanSession.DELAY + 1):
		host.push(SimInput.new())
	var free := 0
	while not host.take().is_empty():
		free += 1
	check.call(free == LanSession.DELAY and host.tick == LanSession.DELAY and not host.wants_input(),
			"Lockstep: sem a entrada da parceira a Sim espera (andou %d passos)" % free)
	pair[1].push(SimInput.new())
	check.call(_pump(pair, func() -> bool: return not host.take().is_empty()) and host.tick == LanSession.DELAY + 1,
			"Lockstep: a entrada chegou e a Sim anda")
	# Esses passos foram só da sessão (nenhuma Sim andou): a partida de verdade começa com um par novo.
	pair[0].leave()
	_pump(pair, func() -> bool: return pair[1].state == LanSession.State.IDLE)
	_pump(pair, func() -> bool: return false, 0.6)
	pair = _pair(12, 0.03)
	sims = _start(pair)
	var waits := 0
	var end := Time.get_ticks_msec() + 20000
	# Trecho com rede ruim: 12 ms de latência e 3% de perda (retransmissão atrasa a fila).
	while sims[0].frame < 900 and Time.get_ticks_msec() < end and pair[0].state == LanSession.State.PLAYING:
		if _frame(pair, sims, bots) == 0:
			waits += 1
			OS.delay_msec(1)
	check.call(sims[0].frame >= 900 and waits > 0 and pair[0].error == &"" and pair[1].error == &"",
			"Lockstep: 15 s de partida com rede ruim, esperando %d vezes, sem dessincronia" % waits)
	# O resto da missão com a rede boa, para caber no tempo do teste.
	for s: LanSession in pair:
		s.link.latency_ms = 0
		s.link.loss = 0.0
	end = Time.get_ticks_msec() + 120000
	while not (sims[0].finished and sims[1].finished) and Time.get_ticks_msec() < end \
			and pair[0].state == LanSession.State.PLAYING and pair[1].state == LanSession.State.PLAYING:
		_frame(pair, sims, bots)
	_pump(pair, func() -> bool: return false, 0.2)
	check.call(sims[0].finished and sims[1].finished and sims[0].frame == sims[1].frame and sims[0].frame > 3000,
			"Lockstep: a missão termina nos dois no mesmo passo (%d e %d)" % [sims[0].frame, sims[1].frame])
	check.call(sims[0].state_hash() == sims[1].state_hash() and sims[0].scoring.score == sims[1].scoring.score,
			"Lockstep: hashes iguais ao fim da missão (%s)" % sims[0].state_hash())
	check.call(pair[0].error == &"" and pair[1].error == &"" and pair[0].state == LanSession.State.PLAYING,
			"Lockstep: nenhum hash trocado divergiu")
	# Fim normal da corrida: quem fecha primeiro não vira erro no outro.
	pair[0].leave(&"done")
	check.call(_pump(pair, func() -> bool: return pair[1].state == LanSession.State.IDLE) and pair[1].error == &"",
			"Fim: a sala fecha nos dois sem aviso de erro")
	_pump(pair, func() -> bool: return false, 0.6)


## Encerramento limpo: pausa avisada, dessincronia, parceira que sai e conexão que cai.
func _endings(check: Callable) -> void:
	var bots: Array[BotPilot] = [BotPilot.new(), BotPilot.new()]
	var pair := _pair()
	var sims := _start(pair)
	var ended := [&"", &""]
	for i: int in range(2):
		pair[i].ended.connect(func(reason: StringName) -> void: ended[i] = reason)
	for _k: int in range(30):
		_frame(pair, sims, bots)
	pair[1].set_paused(true)
	check.call(_pump(pair, func() -> bool: return pair[0].partner_paused), "Pausa: a parceira é avisada")
	var before := sims[0].frame
	for _k: int in range(40):
		pair[0].poll(0.0)
		if pair[0].wants_input():
			pair[0].push(SimInput.new())
		if not pair[0].take().is_empty():
			sims[0].step(SimInput.new(), SimInput.new())
	check.call(sims[0].frame - before <= LanSession.DELAY + 1 and pair[0].state == LanSession.State.PLAYING,
			"Pausa: quem não pausou espera (andou só %d passos)" % (sims[0].frame - before))
	pair[1].set_paused(false)
	check.call(_pump(pair, func() -> bool: return not pair[0].partner_paused), "Pausa: a volta também é avisada")
	pair[0].leave()
	check.call(_pump(pair, func() -> bool: return ended[1] != &"") and ended[1] == &"left" and pair[1].error == &"left"
			and pair[1].state == LanSession.State.IDLE, "Saída: a parceira saiu e a partida encerra com aviso (%s)" % ended[1])
	_pump(pair, func() -> bool: return false, 0.6)
	# Dessincronia: um lado diverge; no primeiro hash trocado os dois encerram com o mesmo motivo.
	pair = _pair()
	sims = _start(pair)
	ended = [&"", &""]
	for i: int in range(2):
		pair[i].ended.connect(func(reason: StringName) -> void: ended[i] = reason)
	sims[1].scoring.score += 1
	var end := Time.get_ticks_msec() + 8000
	while (ended[0] == &"" or ended[1] == &"") and Time.get_ticks_msec() < end:
		_frame(pair, sims, bots)
	check.call(ended[0] == &"desync" and ended[1] == &"desync" and pair[0].state == LanSession.State.IDLE
			and pair[1].state == LanSession.State.IDLE and sims[0].frame <= LanSession.HASH_EVERY + LanSession.DELAY + 1,
			"Dessincronia: os dois encerram no primeiro hash diferente (%s e %s, passo %d)" % [ended[0], ended[1],
			sims[0].frame])
	_pump(pair, func() -> bool: return false, 0.6)
	# Queda: o enlace da convidada some sem adeus; o anfitrião encerra com "a conexão caiu".
	pair = _pair()
	sims = _start(pair)
	ended = [&"", &""]
	pair[0].ended.connect(func(reason: StringName) -> void: ended[0] = reason)
	for _k: int in range(30):
		_frame(pair, sims, bots)
	pair[1].link.close()
	check.call(_pump([pair[0]], func() -> bool: return ended[0] != &"", NetLink.TIMEOUT_MS / 1000.0 + 2.0)
			and ended[0] == &"lost" and pair[0].state == LanSession.State.IDLE and not sims[0].finished,
			"Queda: sem a parceira o anfitrião encerra limpo (%s)" % ended[0])
	pair[1].leave()
