extends RefCounted
## Resoluções-alvo dos testes (fonte única; ver docs/policies/testes.md). A regra de qualidade é por
## RESOLUÇÃO LÓGICA, não por aparelho. O PixelScaler usa, com k >= 1 e stretch "viewport":
## - retrato: k = min(round(largura / 300), floor(altura / 480));
## - paisagem: k = floor(altura / 540).
## Os aparelhos ficam só como exemplo no comentário de cada linha.
##
## Toda tela, painel, hub e HUD percorre layout_cases(): em retrato, cada resolução sem recorte
## (todos os idiomas), com o furo da câmera em cima e com ele embaixo (aparelho girado 180°); em
## paisagem (desktop), só sem recorte. "cutout" é a faixa do recorte em pixels físicos (a mesma do
## hyakki, que mediu os aparelhos em paisagem).
##
## Origem: tests/device_profiles.gd do projeto hyakki (mesmo autor, MIT), transposto para retrato.

const RESOLUTIONS: Array[Dictionary] = [
	# 1220x2712 (9:20), ×4. Ex.: Redmi Note 14 Pro+ 5G (referência).
	{"label": "305x678", "view": Vector2(305, 678), "physical": Vector2i(1220, 2712), "scale": 4, "cutout": 120.0},
	# 1080x2400 (9:20), ×4. Ex.: Samsung Galaxy M55 5G (SM-M556B), Google Pixel 7.
	{"label": "270x600", "view": Vector2(270, 600), "physical": Vector2i(1080, 2400), "scale": 4, "cutout": 118.0},
	# 1080x2340 (9:19.5), ×4. Ex.: Galaxy A15 / A15 5G, Galaxy A56 5G, POCO M3, S24/S25 Ultra em FHD+.
	{"label": "270x585", "view": Vector2(270, 585), "physical": Vector2i(1080, 2340), "scale": 4, "cutout": 110.0},
	# 1440x3120 (9:19.5), ×5. Ex.: Galaxy S24 Ultra / S25 Ultra em QHD+.
	{"label": "288x624", "view": Vector2(288, 624), "physical": Vector2i(1440, 3120), "scale": 5, "cutout": 160.0},
	# 720x1560 (9:19.5), ×2. Ex.: Galaxy S24 Ultra / S25 Ultra em HD+.
	{"label": "360x780", "view": Vector2(360, 780), "physical": Vector2i(720, 1560), "scale": 2, "cutout": 80.0},
	# 1080x1920 (9:16), ×4. Ex.: telas 9:16.
	{"label": "270x480", "view": Vector2(270, 480), "physical": Vector2i(1080, 1920), "scale": 4, "cutout": 118.0},
	# 1600x2560 (10:16), ×5. Ex.: Galaxy Tab S9 / S9 FE+ (sem furo: faixa genérica).
	{"label": "320x512", "view": Vector2(320, 512), "physical": Vector2i(1600, 2560), "scale": 5, "cutout": 120.0},
	# 1200x2000 (10:16), ×4. Ex.: Galaxy Tab A9+ (sem furo: faixa genérica).
	{"label": "300x500", "view": Vector2(300, 500), "physical": Vector2i(1200, 2000), "scale": 4, "cutout": 100.0},
	# 1536x2048 (3:4), ×4 (a altura mínima de 480 baixa o fator de 5 para 4). Ex.: tablets 4:3.
	{"label": "384x512", "view": Vector2(384, 512), "physical": Vector2i(1536, 2048), "scale": 4, "cutout": 120.0},
	# 720x1600 (9:20), ×2. Ex.: Galaxy A05 / A05s, Moto E13 / E14.
	{"label": "360x800", "view": Vector2(360, 800), "physical": Vector2i(720, 1600), "scale": 2, "cutout": 80.0},
	# 720x1612 (9:20), ×2. Ex.: Moto G04 / G24 / E22, Redmi A3.
	{"label": "360x806", "view": Vector2(360, 806), "physical": Vector2i(720, 1612), "scale": 2, "cutout": 80.0},
	# 1812x2176 (quase 1:1), ×4. Ex.: Galaxy Z Fold5 / Fold6 aberto.
	{"label": "453x544", "view": Vector2(453, 544), "physical": Vector2i(1812, 2176), "scale": 4, "cutout": 150.0},
	# 904x2316 (9:23), ×3. Ex.: Galaxy Z Fold5 / Fold6 fechado.
	{"label": "301x772", "view": Vector2(301, 772), "physical": Vector2i(904, 2316), "scale": 3, "cutout": 96.0},
	# 1080x2520 (9:21), ×4. Ex.: Sony Xperia 1 / Xperia 5.
	{"label": "270x630", "view": Vector2(270, 630), "physical": Vector2i(1080, 2520), "scale": 4, "cutout": 118.0},
	# 1080x2640 (9:22), ×4. Ex.: aparelhos 22:9.
	{"label": "270x660", "view": Vector2(270, 660), "physical": Vector2i(1080, 2640), "scale": 4, "cutout": 118.0},
	# Paisagem (Steam). 1920x1080 ×2 (e 3840x2160 ×4): monitores Full HD e 4K.
	{"label": "960x540", "view": Vector2(960, 540), "physical": Vector2i(1920, 1080), "scale": 2, "cutout": 0.0},
	# 2560x1440 ×2 (e 1280x720 ×1): monitores QHD, janelas 720p.
	{"label": "1280x720", "view": Vector2(1280, 720), "physical": Vector2i(2560, 1440), "scale": 2, "cutout": 0.0},
	# 1280x800 ×1 (e 2560x1600 ×2): Steam Deck, notebooks 16:10.
	{"label": "1280x800", "view": Vector2(1280, 800), "physical": Vector2i(1280, 800), "scale": 1, "cutout": 0.0},
]
## Telas físicas fora da tabela para conferir o PixelScaler: [físico, k esperado, lógico esperado].
const SCALER_EXTRA: Array = [
	[Vector2i(3840, 2160), 4, Vector2(960, 540)],
	[Vector2i(1280, 720), 1, Vector2(1280, 720)],
	[Vector2i(2560, 1600), 2, Vector2(1280, 800)],
	[Vector2i(610, 1356), 2, Vector2(305, 678)],
	[Vector2i(305, 678), 1, Vector2(305, 678)],
	[Vector2i(2048, 1536), 2, Vector2(1024, 768)],
]


static func is_portrait(res: Dictionary) -> bool:
	var view: Vector2 = res["view"]
	return view.y >= view.x


## Fator inteiro para uma tela física (a mesma regra do PixelScaler, escrita à parte para o teste
## conferir o PixelScaler de verdade contra ela).
static func scale_for(physical: Vector2i) -> int:
	if physical.y >= physical.x:
		return maxi(1, mini(roundi(physical.x / 300.0), floori(physical.y / 480.0)))
	return maxi(1, floori(physical.y / 540.0))


static func logical_for(physical: Vector2i) -> Vector2:
	var k := scale_for(physical)
	return Vector2(floorf(float(physical.x) / k), floorf(float(physical.y) / k))


## Faixa do recorte em pixels lógicos.
static func cutout_logical(res: Dictionary) -> float:
	return float(res["cutout"]) / int(res["scale"])


static func views() -> Array[Vector2]:
	var list: Array[Vector2] = []
	for r: Dictionary in RESOLUTIONS:
		list.append(r["view"])
	return list


## Tela de referência (os testes de comportamento rodam nela).
static func main_view() -> Vector2:
	return RESOLUTIONS[0]["view"]


## Casos de layout: {label, view, insets: Vector4(esquerda, cima, direita, baixo), langs}.
static func layout_cases() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	for r: Dictionary in RESOLUTIONS:
		list.append({"label": r["label"], "view": r["view"], "insets": Vector4.ZERO, "langs": Languages.SUPPORTED})
	for r: Dictionary in RESOLUTIONS:
		if not is_portrait(r):
			continue
		var c := cutout_logical(r)
		list.append({"label": "%s câmera em cima (%.1f)" % [r["label"], c], "view": r["view"],
				"insets": Vector4(0.0, c, 0.0, 0.0), "langs": Languages.INSET_LANGS})
		list.append({"label": "%s câmera embaixo (%.1f)" % [r["label"], c], "view": r["view"],
				"insets": Vector4(0.0, 0.0, 0.0, c), "langs": Languages.INSET_LANGS})
	return list


static func safe_rect(view: Vector2, insets: Vector4) -> Rect2:
	return MenuKit.safe_rect(view, insets)


static func simulate_insets(insets: Vector4) -> void:
	MenuKit.set_test_insets(insets)


static func clear_insets() -> void:
	MenuKit.set_test_insets(Vector4.ZERO)


## Confere a tabela contra o PixelScaler de verdade: põe o tamanho físico na raiz, chama o _apply
## dele e lê o content_scale_size; depois restaura a raiz.
static func check_scaler(host: Node, check: Callable) -> void:
	var root := host.get_tree().root
	var scaler := root.get_node_or_null(^"PixelScaler")
	check.call(scaler != null, "Resoluções: PixelScaler carregado")
	if scaler == null:
		return
	var size := root.size
	var css := root.content_scale_size
	var mode := root.content_scale_mode
	var aspect := root.content_scale_aspect
	var factor: int = scaler.get("scale_factor")
	for r: Dictionary in RESOLUTIONS:
		root.size = r["physical"]
		scaler.call("_apply")
		check.call(Vector2(root.content_scale_size) == r["view"] and logical_for(r["physical"]) == r["view"]
				and int(scaler.get("scale_factor")) == int(r["scale"]),
				"Resoluções: %s físico dá %s lógico (×%d; obtido %s ×%d)" % [r["physical"], r["label"], r["scale"],
				root.content_scale_size, scaler.get("scale_factor")])
		if is_portrait(r):
			var c := cutout_logical(r)
			check.call(c >= 20.0 and c <= 40.0, "Resoluções: recorte de %s com %.1f pontos lógicos" % [r["label"], c])
			check.call((r["view"] as Vector2).y >= 480.0, "Resoluções: %s com altura lógica ≥ 480" % r["label"])
		else:
			check.call((r["view"] as Vector2).y >= 540.0, "Resoluções: %s com altura lógica ≥ 540" % r["label"])
	for e: Array in SCALER_EXTRA:
		root.size = e[0]
		scaler.call("_apply")
		check.call(int(scaler.get("scale_factor")) == int(e[1]) and Vector2(root.content_scale_size) == e[2]
				and scale_for(e[0]) == int(e[1]) and logical_for(e[0]) == e[2],
				"Resoluções: %s físico dá %s lógico (×%d; obtido %s ×%d)" % [e[0], e[2], e[1],
				root.content_scale_size, scaler.get("scale_factor")])
	root.size = size
	root.content_scale_size = css
	root.content_scale_mode = mode
	root.content_scale_aspect = aspect
	scaler.set("scale_factor", factor)
