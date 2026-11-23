# Regras de qualidade

> Referenciado por [AGENTS.md](../../AGENTS.md). Origem: seção "Padrão de Excelência Profissional" do `AGENTS.md` do
> projeto [hyakki](https://github.com/netstart/hyakki/blob/main/AGENTS.md), ampliada com as regras de código, arte,
> áudio e jogabilidade de Atlantis Ascension.

## Padrão de excelência profissional

Todo trabalho neste projeto deve ser entregue com qualidade premium que surpreenda o usuário. O agente age como um
profissional especialista e demonstra:

- Domínio técnico completo das tecnologias usadas (Godot 4.7, GDScript tipado, exportação Android e Steam).
- Atenção minuciosa aos detalhes e à experiência do jogador.
- Soluções elegantes, otimizadas e documentadas.
- Código limpo, bem estruturado e alinhado com padrões de engenharia de software.
- Respeito à [política de licenças](licencas.md) e à [política de testes](testes.md).
- Compromisso com o [versionamento SemVer](versionamento.md) rigoroso em todo commit.

Excelência profissional significa entregar valor real, não apenas código que funciona. Cada contribuição eleva o
padrão do projeto.

## Código

- **GDScript tipado em tudo.** `gdscript/warnings/untyped_declaration=2` (erro) no `project.godot`.
- **`gdlint` limpo** com as regras de `gdlintrc` (linha ≤ 120 colunas, arquivo ≤ 1200 linhas, ≤ 60 métodos
  públicos por classe). Instalação: `pip install "gdtoolkit==4.*"`.
- **Regras puras separadas da cena.** Dano, pontuação, rank, economia, padrões de tiro e roteiro de fase vivem em
  classes `RefCounted` sem nós, testáveis em `tests/run_tests.gd` sem autoloads.
- **Simulação determinística.** A partida roda em passo fixo de 1/60 s (`GameClock`), com `RandomNumberGenerator`
  semeado por partida. Nada da simulação lê `delta` variável, `Time` ou `randf()` global. A mesma semente dá o mesmo
  hash de estado em 1x, 2x e 3x e em qualquer qualidade gráfica.
- **Dados fora do código.** Armas, aeronaves, inimigos, ondas, chefes, falas e loja ficam em `data/*.json`, lidos
  pelo autoload `DB` e validados por `tests/integration_tests.tscn`.
- **Textos fora do código.** Todo texto visível vem de `i18n/strings.csv` (11 idiomas) pelo autoload `Locale`.
- **Nada de `print` solto.** Logs de diagnóstico passam por `Log.debug()`, desligado em release.
- **Comentários em português**, explicando o porquê, não o quê.

## Desenho e desempenho

Regras herdadas do hyakki, protegidas pelos benchmarks da [política de testes](testes.md):

- O que é fixo não é redesenhado a cada quadro: camada própria ou `StaticBake` para desenhos grandes (mapa da
  campanha, cartões do hub).
- Desenho refeito a cada quadro não usa `draw_polygon`, `draw_colored_polygon`, `draw_polyline`, `draw_arc` nem
  `draw_multiline` (cada um cria buffer novo na GPU). Use retângulos, texturas ou o `Stroke`.
- **Projéteis em `MultiMeshInstance2D`**, um por tipo de textura, com pool fixo. Nenhum `Node` por bala.
- Colisão de projéteis por `SpatialHash` próprio, não por `Area2D`.
- Partículas: `GPUParticles2D` com limite por qualidade gráfica (Baixa, Média, Alta). Nada de `CPUParticles2D` com
  mais de 64 partículas.
- Trocar override de tema ou `StyleBox` só quando o estado muda.
- Animações só decorativas (fundo do hub, parallax ocioso) esperam enquanto uma lista rola pelo dedo
  (`TouchScroll.busy()`) e redesenham em ritmo próprio (30 Hz).
- Nada de laço por pixel em GDScript para gerar texturas. Use as operações nativas de `Image` ou shaders.
- Renderer **Compatibility (GLES3)** em todas as plataformas. Shaders precisam compilar nele.

## Arte e technical art

- **Naves em alta definição** (pedido do dono, 1.25): jogador, frotas inimigas e chefes são pré-renderizados,
  metálicos, com motor brilhante, no visual dos shmups modernos de celular (`tools/gen_hd_ships.py`, em
  `assets/art/hd/`). Uma família só: o gerador normaliza contraste, saturação, luz de borda (de cima à esquerda na
  tela) e contorno escuro fino de todas, e a chama de motor é desenhada pelo projeto. Texturas a 2 texels por
  unidade lógica (desenho = lado da textura / 2), com mipmaps no `.import` e filtro **linear com mipmaps** nas
  camadas que desenham naves (WorldView, vistas dos menus): nunca nearest, que serrilha e cintila em escala
  fracionária. A Void continua como reserva quando falta a arte HD.
- Pixel art (balas, coletáveis, efeitos, cenário, ícones da série Void e os gerados por `tools/gen_sprites.py`)
  continua sem filtro (`default_texture_filter=0`), em escala inteira e com `snap_2d_transforms_to_pixel`; ela não
  divide camada com as naves HD (cada camada tem um filtro só). Asset de outro pack de pixel art passa pelo shader
  de paleta unificada (`shaders/palette_tint.gdshader`) antes de entrar em cena.
- A nave HD não é tingida pela cor de `data/ships.json`: a arte já tem cor. A pintura da loja recolore preservando o
  sombreado (modo pintura de `shaders/sprite_flash.gdshader`). A evolução do hangar (pedido do dono, 1.26) monta
  uma peça física por nível no casco (`tools/gen_livery.py`), no mesmo acabamento metálico e na cor da própria
  nave, presa à silhueta pelas âncoras de `data/livery.json` e nunca sobre o ponto de acerto; a luz (chama, brilho,
  aura, luzes de navegação) só reforça as peças.
- Interface no guia [docs/design/ui-style.md](../design/ui-style.md) ("neon abissal", redesenho 1.6): stretch
  `canvas_items` (texto e vetores na resolução física, layout na lógica), fonte Exo 2, chanfro 45° como única
  forma, cor = significado, um fundo vivo compartilhado (`AbyssBackdrop`) e uma única ação dourada por tela.
- **Leitura de projéteis acima de tudo.** Balas inimigas têm contorno claro e núcleo saturado. O contraste da bala
  contra o fundo da fase é ≥ 4,5:1, medido por `tests/bullet_contrast_tests.gd` em capturas de cada capítulo.
- A profundidade (parallax, escala, névoa) nunca cobre a camada de jogo. Camadas de primeiro plano ficam abaixo de
  35% de opacidade sobre a área de jogo e somem durante padrões densos.
- Hitbox do jogador visível (ponto de 3 px) sempre que o dedo está pressionado, desenhado por cima de tudo
  (inclusive das balas inimigas): a nave HD é maior que a hitbox, e o jogador precisa ver o ponto que conta.

## Áudio

- Volume normalizado: música a −16 LUFS integrado, efeitos com pico ≤ −1 dBFS.
- Cada categoria tem som próprio e distinguível: tiro do jogador, tiro inimigo, dano recebido, dano causado, coleta,
  nível de arma, especial pronta, alerta de chefe.
- Pool de vozes com limite por categoria; o tiro do jogador nunca encobre o alerta de perigo.
- Ducking da música durante falas e alertas.

## Jogabilidade

- Latência do toque até o movimento da nave ≤ 1 quadro de simulação.
- Nenhum ataque impossível de antecipar: todo padrão novo de chefe tem aviso visual de pelo menos 0,5 s.
- Toda mecânica nova (Ocean Shift, Gravity Breach, vento, lava) é ensinada em zona segura antes de ser cobrada.
- Metas de balanceamento ficam na seção 15 do [plano mestre](../../.ai/01-atlantis-ascension-game-plan.md) e são
  medidas pelo bot (`--bot`) e por playtest.

## Definição de pronto (toda tarefa)

Uma tarefa só está pronta quando:

1. O código está tipado, com `gdlint` limpo.
2. Há testes unitários e, se for fluxo de jogo ou tela, E2E e teste de layout em todas as resoluções de
   `tests/device_profiles.gd`.
3. `tools/run_checks.ps1` termina com `TUDO OK`.
4. Textos novos estão nos 11 idiomas (`python -I tools/build_i18n.py --check`).
5. Assets novos estão no registro de licenças e na tela de créditos.
6. A versão subiu conforme o [versionamento](versionamento.md).
7. O checklist em [.ai/03-progresso-implementacao.md](../../.ai/03-progresso-implementacao.md) foi atualizado.
