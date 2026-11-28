# Progresso da implementação

Checklist por fase do [plano mestre](01-atlantis-ascension-game-plan.md). Atualize ao terminar cada item (regra do
[AGENTS.md](../AGENTS.md)).

Legenda: ⬜ a fazer · 🔄 em andamento · ✅ feito e validado · ⚠️ limitação registrada

## Estado atual (31/10/2026)

- ✅ Planejamento: plano mestre, catálogo de assets, pesquisa de mercado, políticas e AGENTS.md.
- ✅ Fase 0 concluída (versão `0.0.1`), exceto o Android SDK (⚠️ abaixo). `tools/run_checks.ps1`: `TUDO OK`
  (433 verificações de regras, 8.472 de integração e layout, 26 textos x 11 idiomas, 20 componentes de licença).
- ⚠️ `CLAUDE.md` não é link simbólico: o Windows negou o `mklink` sem privilégio. O arquivo importa o `AGENTS.md`
  com `@AGENTS.md`. Para o link real, ative o Modo de Desenvolvedor do Windows e rode
  `git config core.symlinks true` e `cmd /c mklink CLAUDE.md AGENTS.md` no lugar do arquivo atual.
- ⚠️ Android SDK não instalado: o `sdkmanager` exige que o mantenedor aceite as licenças do Google. Rode
  `powershell -ExecutionPolicy Bypass -File tools\setup_android_sdk.ps1` (instala os pacotes que o Godot 4.7 pede e
  aponta o editor para o JDK e o SDK). Sem ele, o export Android não roda; o resto da Fase 0 não depende dele.
- ✅ Fase 1 (Vertical Slice) concluída na versão `0.1.0`, exceto o APK (depende do Android SDK) e o playtest com
  pessoas. `tools/run_checks.ps1`: `TUDO OK` (534 verificações de regras, 24.876 de integração, layout e fluxo,
  84 textos x 11 idiomas, 21 componentes de licença e 87 arquivos de assets cobertos, mesmo hash em 1x/2x/3x e na
  qualidade Baixa). Benchmarks: rolagem 72/72 listas aprovadas nas 18 resoluções (p95 ≤ 2,5 ms); partida com 1.000
  balas inimigas p95 2,2 ms, pior quadro 20 ms.
- ✅ Fase 2 (Alpha) concluída na versão `0.5.0`. `tools/run_checks.ps1`: 630 verificações de regras (o bot vence
  as 11 missões, mesmo hash em 1x/2x/3x/Baixa), 45.914 de integração, layout (10 telas + HUD + painel de bênçãos nas
  18 resoluções), fluxo E2E e simulação da economia; 326 textos x 11 idiomas; 21 componentes de licença, 168 arquivos.
- ✅ Fase 3 (Beta) concluída na versão `0.9.0`: campanha completa de 9 capítulos (37 missões) vencida pelo bot de
  ponta a ponta com a carga do hangar; ver o checklist da Fase 3 para os números e o que ficou de fora.
- ✅ Fase 4 (Lançamento) com o código da `1.0.0` pronto: Segunda Maré, Correntes, replay e Fantasma do Abismo,
  placares, passe, conquistas e documentos de loja. O que depende de contas e contratos (Play Console,
  AdMob, Billing, Steamworks, Android SDK) está em `docs/store/release-checklist.md`.
  `tools/run_checks.ps1`: `TUDO OK` (892 verificações de regras, 71.619 de integração, layout e fluxo, 609 textos x
  11 idiomas, 21 componentes de licença e 169 arquivos, mesmo hash em 1x/2x/3x/Baixa). Benchmarks: partida com
  1.000 balas p95 2,2 ms (pior 3,2 ms); rolagem 72/72 listas aprovadas.
- ✅ Pós-lançamento em andamento sem depender de contas: ver a seção no fim.
- 🔄 Google Play (16/11/2026): AdMob (app, bloco recompensado, mensagem GDPR), declarações, ficha pt-BR e teste
  fechado Alpha 1.18.0 (34) aprovado no mesmo dia; 1.18.1 (35), com as correções da revisão do AdMob, enviada
  para revisão. Faltam: 12 testadores por 14 dias, produção e vincular o app à loja no AdMob.
- 🔄 Turbo (1x/1,5x/2x): compra única `turbo` pela Play Billing real (plugin GodotGooglePlayBilling, pendente, acknowledge, restauração), incluído na Steam; falta 👤 criar o produto no Play Console (`docs/store/play-console.md`).
- ⬜ Steam: checklist de lançamento (conta, Steamworks).

## Decisões pendentes do mantenedor

- ⬜ Ratificar CC-BY-3.0 e OGA-BY-3.0 na lista de licenças.
- ✅ Licenças de Void Fleet Pack 1, Fleet Pack 3 e Pickups Pack: CC0 e "No generative AI was used" nas páginas
  (snapshots em `docs/licenses/`, 30/10/2026).
- ✅ Retratos: derivados do *Cyberpunk Portraits* (Hyptosis, CC0) por `tools/gen_portraits.py` (1.15.1), sem o pack
  SakPix.
- ⬜ Pacote Android definitivo.
- ⬜ Preço na Steam (alvo US$ 9,99) e da compra "Apoiar" (alvo US$ 3,99).
- ⬜ Backend para os sistemas sociais do pós-lançamento.

## Fase 0 — Fundação · `0.0.x`

- ✅ Godot 4.7.2 + templates: editor em `C:\src\tools\godot`, templates em `%APPDATA%\Godot\export_templates\4.7.2.stable`
  (SHA-512 conferido com o `SHA512-SUMS.txt` oficial)
- ✅ gdtoolkit 4 (`python -m gdtoolkit.linter`; pyyaml instalado sem extensão C), JDK 17.0.20.1 Temurin em
  `C:\src\tools\jdk` (SHA-256 conferido)
- ⚠️ Android SDK: script pronto (`tools\setup_android_sdk.ps1`), falta o mantenedor rodar e aceitar as licenças
- ✅ `project.godot` (retrato, Compatibility, `untyped_declaration=2`, versão 0.0.1), `export_presets.cfg` (Android,
  Windows, Linux, todos em 0.0.1), `gdlintrc`, `.gitattributes` (LF; CRLF e BOM nos `.ps1`)
- ✅ Portado do hyakki e adaptado: PixelScaler (regra por orientação + janela de desktop que cabe no monitor),
  MenuKit (área segura nos 4 lados), TouchScroll, StaticBake, Stroke, SpatialHash, FrameStats, FramePacing,
  GfxQuality (orçamentos deste jogo), InputSetup (ações deste jogo), Settings, SaveManager, Locale, DB, GameClock;
  AudioManager novo (buses Music/SFX/UI, crossfade, pool); Log, Events, Languages
- ✅ `Playfield` (campo 270x450, HUD, zona do polegar, laterais) com teste em todos os casos
- ✅ App + telas de abertura (com o contorno do campo) e Créditos (lidos de `licenses/index.json`)
- ✅ `tests/device_profiles.gd` com as 18 resoluções (15 retrato + 3 paisagem); `tests/run_tests.gd` (escala, campo,
  SpatialHash, FrameStats, FramePacing, GfxQuality, idiomas, versão SemVer em todos os presets);
  `tests/integration_tests.tscn` (dados, 11 idiomas e glifos, opções, save com backup e migração, áudio, licenças,
  PixelScaler, layout de cada tela em todos os casos, créditos); `tests/screens_runner.tscn` (capturas para revisão)
- ✅ `tools/run_checks.ps1`, `check_licenses.py`, `build_license_index.py`, `fetch_licenses.py` (snapshots PDF pelo
  Edge), `sync_assets.py`, `build_i18n.py` + `i18n_keys.py`
- ✅ Downloads do Vertical Slice em `c:\src\downloads\assets\`: 14 packs Kenney, 6 packs Void, Ocean Creatures, 2 faixas
  CC0 da OpenGameArt e Fusion Pixel, todos no `licenses/registry.json` com snapshot da página de origem
- ✅ Critério: projeto abre, testes passam em todas as resoluções, licenças verdes
- ✅ Benchmark de rolagem (`tests/scroll_bench.tscn`): entra com a primeira lista longa (hub e mapa, Fase 1)

## Fase 1 — Vertical Slice · `0.1.0`

- ✅ `Sim` pura em passo fixo (`scripts/sim/`), `BulletPool` compactado (2.048 inimigas, 512 do jogador) desenhado
  em MultiMesh por tipo, `PatternRunner` com a DSL (ring, fan, aimed, aimed_fan, line, beam, wait, rotate, repeat)
- ✅ Falcon com Pulsar (leque 3/5/7 + traseiros, Ressonância) e Laser (feixe que acerta o alvo mais próximo),
  orbes que trocam de cor a cada 1,5 s, casco em 3 segmentos, bombas e especial com recarga e graze
- ✅ 3 inimigos (Esquife, Vespa de Maré, Boia Sentinela), ondas em JSON (linha, V, coluna), 6 trajetórias puras,
  entrada "do fundo" (profundidade 0,6 → 1,0 sem colisão)
- ✅ Cenário do capítulo 1 em parallax: água por shader (cáusticas, cristas), ruínas procedurais que emergem no
  Ocean Shift, espuma de primeiro plano; `ParallaxRig.layer_offset` puro e testado
- ✅ Bot de teste (`scripts/bot/bot_pilot.gd`) vence a 1-1 com 4 estrelas; mesmo hash em 1x, 2x, 3x e Baixa
- ✅ Pontuação: corrente (x1 a x16), medalhas de 100 a 10.000, graze, queima-roupa x1,5, pérolas das balas canceladas
- ✅ Juice: hitstop determinístico, tremor com teto, flash de dano, explosões das folhas Void, faíscas, anéis;
  sons Kenney por evento; aviso sonoro do feixe e alerta de chefe
- ⚠️ Som em camadas (impacto + destroços + grave) e Ocean Shift sincronizado ao compasso ficam para o Alpha
- ✅ HUD (pontuação, corrente, casco, bombas, arma, SP, BOMBA, pausa, rádio, nome do chefe, barra de HP, duelo) e
  tela de resultado com as 4 estrelas, recorde e créditos gravados no save
- ✅ Missão 1-1 (`data/stages/c1m1.json`): ~105 s de fase + mini-chefe + chefe, Ocean Shift aos 46 s
- ✅ Mini-chefe Quebra-Maré (2 etapas) e Kraken Engine (6 tentáculos destrutíveis, olhos, núcleo, 3 etapas, feixe,
  espirais, maré que volta na sobrecarga, duelo de raio por toques)
- ✅ Rádio só nos respiros (abertura, antes do Ocean Shift, respiro, antes do chefe, trocas de etapa sem balas)
- ✅ Hub: hangar vivo em 6 camadas (portal atlante, pilares, nave com reflexo, faíscas), arrastar inclina,
  tocar a nave pulsa o motor, tocar o fundo solta onda de luz; saldo, banner rotativo, JOGAR, 5 abas (2 abertas)
- ✅ Mapa "Carta da Ascensão" em 5 camadas de parallax com inércia, nós 1-1/1-2/1-3, cartão com estrelas e recorde
- ✅ 11 idiomas (84 chaves), SFX Kenney, música CC0 (HydroGene na missão, Junkala no chefe), jingles
- ⚠️ APK: depende do Android SDK (`tools\setup_android_sdk.ps1`, licenças aceitas pelo mantenedor)
- ✅ Layout de todas as telas e do HUD nas 18 resoluções (com recorte em cima e embaixo), fluxo E2E título → hub →
  mapa → missão → resultado → tentar de novo → sair, contraste das balas ≥ 4,5:1, benchmarks de rolagem e partida
- ⚠️ Playtest com 10 pessoas: precisa de pessoas; roteiro na seção 13 do plano mestre

## Fase 2 — Alpha · `0.5.0`

- ✅ Capítulos 1 a 3: 9 missões + bifurcação 3-3 (Superfície / Abismo, pontos x1,5) + missão secreta, geradas
  por `tools/gen_missions.py` (trechos autorais com semente fixa; 2 a 5 min cada, medido pelo bot)
- ✅ 3 mini-chefes (Quebra-Maré na 1-2, Guardião de Coral na 2-2, Olho da Tempestade na 3-2) e o Kraken Engine na 2-3
- ✅ Perigos novos: corrente marítima (capítulo 2), ventania e raios com aviso (capítulo 3), glifos atlantes
- ✅ Cenários por capítulo: Atlântico, Atlântida (água verde-azulada, ruínas expostas) e Tempestade (chuva diagonal,
  raios em zigue-zague); espuma e chuva derivam com a corrente e o vento
- ✅ Plasma, Railgun, mísseis e drones (secundárias com 5 níveis), 6 especiais, 4 aeronaves no Alpha (Falcon, Manta,
  Hydra, Tempest) com tinta própria
- ✅ Bênçãos das Marés (18, de Proteu, Tétis e Nereu), sinergia com 2 do mesmo deus e Avatar com 3; painel de
  escolha que congela a fase; Carta Náutica, Oráculo e Localizador implementados
- ✅ Maré Alta: medidor de Pressão no HUD, botão MARÉ (tecla Espaço / RT), aura e pontos x2
- ✅ Tutorial em jogo na 1-1 (6 dicas de rádio por tempo: mover, raspar, orbes, SP, Maré, marcados) e objetivo da
  missão ao entrar
- ✅ Hub: abas Hangar (oficina), Campanha e Naves abertas; Diário e Opções; banner do capítulo atual; JOGAR mostra a
  próxima missão. ⚠️ Eventos e Loja abrem no Beta; Cidade de Thalassa fica para o Beta
- ✅ Mapa com os estratos 0 a 4, 11 nós do grafo `Economy.CAMPAIGN` (pré-requisitos, bifurcação, nó secreto que só
  aparece aberto), cores por tipo (chefe coral, secreto violeta)
- ✅ Economia (`scripts/core/economy.gd`, regras puras): créditos, oricalco, pérolas, níveis 1 a 10 da aeronave,
  secundárias, fragmentos que abrem aeronaves, 6 asas liberadas por estrelas (até 2 equipadas), 4 dificuldades
- ✅ Simulação da economia pelo bot (`tests/economy_tests.gd`): campanha inteira com a carga do hangar; ao fim do
  Alpha a Falcon fica no nível 3 a 7 e o bot junta ≥ 20 estrelas (hoje: nível 3, 32 estrelas)
- ✅ Assistência: dificuldade Brisa (+2 casco, balas lentas, pontos x0,5). ⚠️ Conquistas ficam para o Beta
- ✅ Save v2 com migração, tela de Opções (idioma, gráficos, mão, volumes, tremor, sensibilidade, tiro automático,
  vibração, clarões, movimento, inclinação, FPS), 11 idiomas (326 chaves)
- ✅ Diário de Bordo (11 registros da Halcyon + carreira), cenas do prólogo, de Atlântida e do fim do Ato I,
  missão secreta "Cofre dos Glifos" (só Railgun) aberta destruindo 3 glifos na ordem na 2-1
- ✅ Decisão do mergulho entre camadas: a bifurcação Superfície/Abismo da 3-3 substitui o protótipo (mesmo efeito
  de risco e recompensa, sem custo de troca de camada no meio da fase)

## Fase 3 — Beta · `0.9.0`

- ✅ Capítulos 4 a 9 (Vulcões, Cidade Futura, Geleira, Estratosfera, Órbita, Núcleo) com cenário e partículas
  próprias; 5 mini-chefes (Forja Viva, Arquiteto, Rainha do Gelo, Albatroz de Aço, Portão Orbital) e os chefes de
  ato Sky Leviathan (serpente de 8 segmentos, faixas seguras), Poseidon Prime (anéis de escudo, Gravity Breach,
  tridente, dança final) e Leviathan Protocol (colagem das 3 facções, gravidade alternada, núcleo que APRENDE a faixa
  preferida do jogador). Gerados por `tools/gen_bosses_beta.py`
- ✅ 3 finais escolhidos no voo (entrar no feixe ou desviar) e o verdadeiro com os 4 Registros Abissais; cenas do
  fim dos Atos II e III e de cada final
- ✅ 7 rotas de Abismo (3-3 a 8-3, pontos x1,5), Glifos nas missões 2-1, 4-1, 6-1 e 8-1, 4 missões secretas (só
  Railgun, escuridão com sonar, gravidade para cima, Ocean Shift contínuo)
- ✅ Cápsulas de resgate com combo (até x8) e Cidade de Thalassa com 5 distritos e bônus permanentes
- ✅ 6 aeronaves (Trident e Atlas abertas por fragmentos nos capítulos 4 a 7), 12 alas, 6 especiais.
  ✅ Captura biomecânica entrou na `1.1.0` (ver Pós-lançamento)
- ✅ Gravity Breach (balas inimigas 100%, do jogador 40%) com bônus Redemoinho (raspões em dobro); lava, prédios
  que bloqueiam balas, gelo, detritos, raios, ventania e corrente
- ✅ Chefe que lembra (a faixa preferida do jogador fica no perfil e os chefes de ato começam puxados para ela).
  ⚠️ Kraken remendado vai com a Segunda Maré (Fase 4)
- ✅ Modos Arcade, Boss Rush (12 chefes), Desafio Diário (mesma fase para todos no dia, 1 tentativa pontuada),
  Sobrevivência das Marés (15 estágios) e Prática (sem recompensas), montados por `scripts/core/modes.gd`
- ✅ Login de 7 dias com escudo semanal, 3 tarefas diárias e 5 semanais sorteadas pela data, Núcleo de Oricalco e
  baú de 6 h (`scripts/core/live_ops.gd`)
- ✅ Acessibilidade: 3 modos de daltonismo nas balas (contraste ≥ 4,5:1 testado em todos), tamanho do texto
  100/115/130%, Brisa, menos clarões, menos movimento, qualidade gráfica
- ✅ Monetização simulada: Loja (pinturas por Pérolas, Apoiar), baú de 6 h, reviver 1 vez e dobrar créditos com
  anúncio recompensado opcional (`Store`, `Ads`); na Steam (feature `steam` dos presets) sem anúncios e com tudo
  incluso. AdMob/UMP real na 1.17.0 (abaixo). ⚠️ Play Billing real na Fase 4
- ⚠️ Build Steam com GodotSteam: os presets Windows/Linux já levam a feature `steam`; falta o mantenedor baixar o
  Steamworks SDK (licença da Valve) e o GodotSteam com o App ID da página da loja

## Fase 4 — Lançamento · `1.0.0`

- ✅ Segunda Maré (loop 2: balas +15%, bala de vingança, Kraken remendado com 4ª etapa), abre com o primeiro final
- ✅ Fantasma do Abismo: o recorde voa junto, translúcido, numa segunda Sim com a entrada gravada (opção nas Opções)
- ✅ Replay determinístico (`scripts/core/replay.gd`, entrada em blocos run-length; reproduzir dá o mesmo hash) e
  placares locais top 10 por missão e modo, com "Assistir ao recorde"
- ✅ Correntes semanais (missão + modificador da semana: balas rápidas, só Laser, só Railgun, escuridão, gravidade,
  casco de vidro)
- ✅ Passe da Maré por trimestre: 30 níveis, trilha grátis e trilha dourada com 3 pinturas (compra simulada)
- ✅ 22 conquistas locais (`data/achievements.json`, mesmas ids para a Steam) no Diário e no resultado
- ~~Modo foto do mapa~~ removido em 1.14.2 a pedido do mantenedor
- ✅ Ícone do jogo (`1.0.1`): pixel art gerada por `tools/gen_sprites.py` (nave subindo pelo portal atlante sobre as
  ondas), em 512 e 192 px e nas camadas do ícone adaptativo do Android (432 px, conteúdo na zona segura)
- ✅ Política de privacidade (pt-BR e en), textos das lojas, questionários IARC e de Segurança de dados, modelo do
  `app-ads.txt` e checklist de lançamento em `docs/store/`; créditos públicos em `CREDITS.md`
- ⚠️ Play Console, teste fechado (20 testadores por 14 dias), AdMob com UMP e Play Billing: exigem a conta e o aceite
  dos termos pelo mantenedor (passos em `docs/store/release-checklist.md`)
- ⚠️ Steam (página, Steamworks SDK, GodotSteam, Cloud, Deck Verified): idem; conquistas e placares já existem no
  jogo
- ✅ Traduções: sem revisão por nativos (decisão do mantenedor, 31/10/2026)
- ⬜ Critérios: aprovado nas duas lojas, crash-free ≥ 99,5%, D1 ≥ 40% no teste fechado

## Pós-lançamento · `1.x`

- ✅ `1.1.0` Frota completa: aeronaves 7 a 12 com traço próprio em `scripts/sim/ship_traits.gd` (Ariete: agulhas
  que explodem; Enxame: 2 drones fixos; Eclipse: tiro perfurante; Nova: 1 em 5 tiros crítico x2,5; Titã: abate
  explode; Ascension: arma do orbe vira assinatura e a especial gira entre as 6, aberta pelo final Maré Alta).
  Fragmentos nas missões 7-1 a 9-2 e nas 4 secretas. Captura biomecânica: marcado abatido a até 56 u vira escolta
  por 10 s (até 2) e atira junto. Conquista "Armada atlante" (12 aeronaves). Testes em `tests/post_tests.gd`
  (traços, captura, desbloqueio, o bot vence a 1-1 com cada nave nova e o hash se repete)
- ✅ `1.2.0` Retratos: 5 personagens (Maré, Farol, Duarte, Thalassa, Protocolo) em 3 expressões (calma, alerta,
  sorriso), pixel art 64x64 gerada por `tools/gen_portraits.py`. Aparecem no rádio da missão (32 px, à esquerda do
  texto) e nas cenas da história (64 px); a expressão vem do campo `mood` das falas. Testes: todo personagem que
  fala tem as 3 expressões; o narrador não tem rosto
- ✅ `1.3.0` Abismo Infinito (roguelite, abre na 7-1): 60 profundidades de 30 s remixadas por semente (capítulos 1 a
  9 em ciclo, cada vez mais densas); entre elas, alternados, 12 módulos novos (canhão, cadência, blindagem, mísseis,
  drones, sobrecarga, paiol, coral...) e as bênçãos com sinergias; mini-chefe a cada 5 e chefe de ato a cada 10. Cada
  profundidade deixa as balas 1% mais rápidas (até +45%) e os pontos 5% maiores. Placar e replay próprios,
  profundidade máxima no perfil, 2 de Oricalco a cada 5 profundidades e a conquista "Trinta braças"
- ✅ `1.3.0` Modo de janela no PC e Steam (Opções): em pé (tate, padrão), deitada (campo 9:16 no centro) ou tela
  cheia (monitor girado no sistema = tate em tela cheia). Janelas no maior múltiplo inteiro de 270x480 ou 480x270
- ✅ `1.4.0` Capítulo bônus 10, Fossa Hadal (abre depois da 9-3, no fundo do mapa abaixo do primeiro mar): 3
  missões (escuridão com sonar, fontes térmicas e correntes), mini-chefe Pescador Abissal e chefe Matriarca Hadal
  (braços de 5 segmentos, pressão com Gravity Breach, canto em espiral), gerados por `tools/gen_bosses_post.py`;
  cenário "hadal" com brilho bioluminescente, 5 falas, epílogo e a conquista "Silêncio no fundo"
- ✅ `1.5.0` Co-op local no PC (modo "Co-op local", abre na 1-3, oculto no celular): teclado (e toque) na nave 1 e o
  primeiro controle na ala; as duas naves dividem o casco e as bombas, cada uma com sua arma; perto uma da outra o
  Elo de Maré apaga balas no meio do caminho e dobra os raspões. Corrida do Arcade, sem placar nem replay
- ✅ Release Android: preset "Android Play" (AAB, arm64 + armv7 + x86_64) assinado com a chave de upload em
  `C:\src\tools\keys` (fora do repositório, senha só no `.env` de lá); `tools/build_release.ps1` gera APK de debug,
  AAB, zip do Windows e tar.gz do Linux
- ✅ `1.6.0` Redesenho premium "neon abissal" (pesquisa em `.ai/05-pesquisa-redesign-ui-gameplay.md`, guia em
  `docs/design/ui-style.md`): interface na resolução física (stretch `canvas_items`), fonte Exo 2 com reserva Fusion
  Pixel para CJK, tema chanfrado com halo de foco, resposta física em todo botão (`UiFx`), transição entre telas,
  fundo abissal 2,5D compartilhado em shader (raios, cáusticas, 3 terraços de ruínas em parallax, neve marinha) a
  30 Hz num SubViewport lógico, título com logo e nave, hub com pedestal holográfico e barra de abas com ícones
  (Kenney Game Icons, CC0), mapa com parallax ligado ao fundo e humor por estrato (redesenho só com a câmera
  andando), músicas novas por capítulo e de menu (Umplix, MintoDog, Pro Sensory, ansimuz, HydroGene, killerfishred:
  CC0; Magnesus: CC BY 4.0), músicas em laço
- ✅ `1.6.1` Pronto para a Google Play: release sem plugins não simula compra nem anúncio (loja paga oculta,
  recompensa direta), backup automático do save, arte da ficha gerada (`tools/build_store_art.ps1`: 8 capturas
  1080x1920 e destaque 1024x500 nos 11 idiomas), ficha revisada com os números atuais e títulos/descrições curtas
  nos 11 idiomas (`tools/check_store_texts.py`), política de privacidade 1.1 (offline, sem anúncios) com página
  HTML (`tools/build_privacy_page.py`) e roteiro com todas as respostas do Play Console em
  `docs/store/play-console.md`
- ✅ `1.7.0` Evolução visual da nave pelo nível do hangar (`ShipLivery`): cada nível do 2 ao 10 monta uma peça
  que fica — faixas de esquadrão, luzes de navegação piscando, canards de proa, cristal sensor, blindagem de
  oricalco (junto do +1 de casco), propulsores auxiliares com chama, runas atlantes pulsando, lâminas de maré e,
  no 10, a nave Ascendida (friso de ouro, halo e rastro de centelhas). Arte em `tools/gen_livery.py`, alinhada
  pixel a pixel à nave e com acento oposto à tinta (legível em toda pintura). Hangar anuncia a próxima peça,
  revela a nova com onda de luz e selo, e lista as nove em "Evolução da nave"; coleção e loja mostram a nave
  vestida; vale em todo modo e na ala do co-op, sem mudar a partida (hash igual)
- ✅ `1.8.0` Efeitos de combate premium (pesquisa em `.ai/06-pesquisa-efeitos-visuais.md`): luz aditiva em tudo
  que brilha (halo neon nos tiros, laser em três camadas com pulsos, luz dos motores, boca do canhão, halos dos
  coletáveis), explosões em camadas (clarão, fogo, faíscas alinhadas, fumaça, estilhaços, anel de choque), impacto
  com faíscas, fumaça de avaria, destroços 2,5D que caem até a sombra e espirram na água, bolhas de quem sobe do
  fundo, números de pontos, cancelamento de balas em onda na bomba, cadeia de explosões e hitstop nos chefes,
  vinheta, borda de perigo com o casco no fim, clarão e onda de choque com distorção (Média e Alta). Partículas em
  MultiMesh (`ParticleField`, teto `particles_max`), receitas em `CombatFx`, tela em `ScreenFx`; nenhum plugin de
  terceiros (avaliação na pesquisa). "Reduzir flashes" e qualidade Baixa reduzem a dose; hash da partida igual
- ✅ `1.9.0` Menus vivos: reflexo de oricalco que atravessa a tela e acende cada botão dourado em sequência
  (`UiGlint`, um material só, `shaders/ui_glint.gdshader`); onda e centelhas no ponto de todo toque, dourada no
  botão principal e ciano nos outros, e varredura de sonar na troca de tela (`UiSpark`, camada aditiva que só
  processa com algo vivo); entrada de tela em cascata (`UiFx.enter`); plâncton luminoso na cor do humor da tela
  sobre o fundo compartilhado (`AbyssMotes`, 30 Hz); sonar no farol escolhido e luzes que sobem pela rota aberta
  no mapa; moedas do hub que contam até o saldo novo. Só código e arte do projeto; "reduzir movimento" e
  "reduzir flashes" desligam o que se move ou pisca
- ⚠️ Fora do alcance sem contas e backend: Ecos dos Caídos, Elevação Global e Casas Atlantes (servidor), lojas
  (Play Console, Steamworks) e teste fechado — ver `docs/store/release-checklist.md`. Traduções sem revisão por
  nativos (decisão do mantenedor)
- ✅ `1.10.0` Chefes ao longo de toda fase: chefe intermediário (`mid_*`, um por capítulo, três etapas, peças
  destrutíveis em vários deles) perto do meio de todas as 41 missões e mini-chefes de elite (`elite_*`, dez desenhos
  com variante por capítulo) perto de 1/4 e 3/4 (uma elite só onde a missão já tem mini-chefe; nenhuma onde há
  chefe de ato). Gerador em `tools/gen_bosses_mid.py` (49 padrões novos); posição em `tools/gen_missions.py`.
  Eles entram com escolta, soltam o núcleo de força (`power`: +1 nível na arma atual, sem trocar de arma) e bomba;
  nas missões com chefe no fim os trechos de ondas ficam 15% mais curtos e mais densos. Sky Leviathan de 9.000
  para 6.800 de casco (era o chefe de ato mais longo). Balanceado com o bot (`tests/boss_timing.gd`): as 41
  missões vencidas de 2 a 5,5 min, com ≥ 50 abatidos; `run_checks.ps1` `TUDO OK` (1.207 regras, 82.894 de
  integração, 725 textos x 11 idiomas, 34 componentes de licença e 251 arquivos). Pesquisa profunda de assets
  (15 pacotes CC0 avaliados, `.ai/02-catalogo-assets-licencas.md`): entraram explosões em pixel art do ansimuz
  (peças e quedas de chefe), alarme e rugidos (rubberduck), estrondo de queda (faxcorp) e o tema de chefe
  intermediário (SketchyLogic). Os conjuntos de chefes em desenho liso ficaram de fora por destoar da arte Void
- ✅ `1.11.0` Evolução da nave fechada: som próprio da peça montada (trava metálica na compra e brilho de vidro na
  revelação, Kenney CC0) e celebração da nave Ascendida no nível 10 — doze raios de ouro atrás da nave, segunda
  onda dourada, dezesseis centelhas, título "Nave Ascendida!" (11 idiomas), sino e vinheta de tambor de aço por cima
  da trilha (`AudioManager.play_jingle`, abaixa a música sem trocá-la). O benchmark da partida passa a jogar com a
  nave no nível máximo (`--level=N` para outro): Ascendida p95 4,10 ms contra 4,19 ms no nível 1 (custo
  desprezível); `run_checks.ps1` `TUDO OK` (1.207 regras, 82.907 de integração, 726 textos, 254 arquivos)
- ✅ `1.12.0` Maré de Glória (pesquisa profunda em `.ai/07-pesquisa-diversao-e-surpresa.md`): o jogo passa a
  celebrar a jogada, criar expectativa na recompensa e dizer o quanto faltou na derrota. **Ecos de Estilo**
  (`StyleTracker` + `StyleCallouts`): frases curtas com som que sobe para os degraus da corrente (x4/x8/x12/x16),
  Dança das balas, Queima-roupa, Chuva de pérolas, Medalha máxima e chefe final Impecável ou Por um fio; só lê a
  Sim (hash igual), opção nas Opções. **Nota da missão** C/B/A/S/SS (`Grade`; SS = partida perfeita) carimbada em
  roseta no resultado e mostrada no mapa. **Arca da Maré** (`TideChest`): toda vitória na campanha abre uma arca de
  bronze, prata ou ouro conforme a nota, com carretel que desacelera e 10% (20% no SS) de Tesouro de Atlântida;
  determinística, sem compra nem anúncio, já dentro da simulação da economia. **"Quase lá"** (`DefeatInsight`):
  barra da missão, casco restante do chefe e dica tirada da partida (a Sim passa a contar `progress`, `boss_left`,
  `bombs_left` e `cause`). **Câmera lenta** de 1,1 s quando o chefe final cai (`GameClock.time_scale`, sem mudar a
  partida) e **vibração em camadas** por prioridade (o raspão nunca abafa o dano). 3 conquistas novas (Maestria,
  Lenda Atlante, Tesouro de Atlântida; 28 no total), 34 textos x 11 idiomas. Testes em `tests/glory_tests.gd`
- ✅ `1.13.0` Céu e Mar Vivos: clima dinâmico em 37 das 40 missões (o núcleo do cap. 9 fica de fora: é circuito, sem céu nem mar), sempre coerente com o meio do cenário
  (`data/weather.json`, 19 estados; `scripts/sim/weather.gd`, determinístico, fluxo próprio do `SimRng`). **Céu**:
  nuvens passando, chuva, tempestade com relâmpago ramificado, olho da tempestade (abre antes do mini-chefe Olho da
  Tempestade), neve, nevasca com véu nas bordas, chuva de cinzas com brasas, corrente de jato. **Mar**: cor da água
  que muda (turquesa, verde do plâncton, azul da termoclina, marrom do sedimento), neve marinha, filetes da corrente
  que muda de direção, ressaca, termoclina com borda ondulada, corrente abissal, fontes termais, tempestade na
  superfície (o raio ilumina a água de cima). **Órbita**: tempestade solar com aurora. **Pilotagem**: vento e
  corrente com rajadas que levam a nave e curvam as balas inimigas, turbulência que o modo preciso segura pela
  metade, resistência do meio (água fria ou turva, gelo no casco, cinzas) que responde no mesmo passo; biruta no
  canto do campo com seta, turbulência e lentidão. Frente anunciada no rádio (coral quando severa: 3 s de aviso,
  5 s de rampa). **Navegador da Tormenta**: frente severa atravessada sem dano dá 3.000 pontos e Eco de Estilo.
  **Surpresas**: arco-íris e sol rompendo quando a tempestade passa, nuvem acesa por dentro pelo relâmpago, sombra
  das nuvens no chão, gotas no casco e escorrendo das asas, vapor nas pontas das asas nas curvas dentro da nuvem,
  bolhas do motor arrastadas pela corrente, gelo cintilando no casco. **Som**: chuva fina e forte, vento, água
  correndo, pad grave na água funda (camadas no novo barramento Ambience), trovão atrasado pela distância e com
  vibração quando perto, música e ambiente abafados sob a água (passa-baixa), silêncio de vento no vácuo. Leitura
  intacta: base sob o teto de brilho do cenário, camada de perto abaixo das balas inimigas, ≤ 35% e some em padrão
  denso; "reduzir flashes" corta o clarão e o raio. Áudio CC0 do catálogo (kindland, isaiah658, rubberduck) recortado
  por `tools/cut_weather_audio.py`; nuvens procedurais (o pacote "Pixel Clouds and Thunderstorms" do catálogo é
  música). Bot compensa a deriva como a mão do jogador. Replays antigos seguem válidos (o clima padrão não mexe em
  nada). Testes de regras em `tests/weather_tests.gd` (mistura do som pura em `scripts/game/weather_mix.gd`), de tela
  em `tests/weather_view_tests.gd`; galeria em `tests/weather_shots_runner.tscn`. Benchmark (`game_bench --strict`,
  1.000 balas, nave nível 10, Radeon integrada): partida padrão 3,86 ms de média (p99 5,93, nenhum quadro > 20 ms);
  `--mission=c3m3s --weather=storm` 4,04 ms de média (p99 7,07, 1 quadro > 20 ms, nenhum > 33 ms)
- ✅ `1.14.0` Menus pelo controle (Steam Deck, PC): A confirma e B volta nos menus (o Godot só ligava o teclado a
  `ui_accept` e `ui_cancel`). `FocusNav` guarda o modo de entrada (controle ou teclado contra toque ou mouse): pelo
  controle cada tela abre com foco no controle padrão (`Screen.default_focus`: JOGAR no hub e no título, Próximo na
  história, botão principal no resultado, primeiro item das listas); pelo toque nada muda, e o primeiro D-pad numa
  tela sem foco só acorda o foco. As listas rolam atrás do foco e, remontadas depois de comprar ou equipar, devolvem
  o foco ao mesmo item. Mapa: cima e baixo andam pelas missões abertas com a câmera junto, baixo na primeira leva ao
  Jogar, A na missão escolhida joga. Reviver e bênção só recebem o foco 0,6 s depois de abrir
  (o A do tiro não escolhe sem o jogador ver). Testes em `tests/focus_nav_tests.gd`. Falta conferir num controle
  físico e no Steam Deck
- ✅ `1.14.3` Sons de coleta e de acerto refeitos (o mantenedor achou os antigos terríveis: a medalha não soava como
  moeda e o acerto era um sino metálico que embolava). `tools/mix_pickup_audio.py` mistura camadas CC0 baixadas:
  medalha `coin_medal` (Coin 3 de Deva + fichas do Kenney Casino Audio, 366 ms), pérola `coin_pearl_1..3` (cristal do
  Kenney Interface Sounds + bolha de rubberduck, 134 ms), cápsula `coin_capsule` (coin1 de Luke.RUSTLTD, 300 ms, tom
  sobe com o combo) e acerto `hit_1..5` (batida do Kenney Impact Sounds + estalo do Kenney UI Audio, corte duro em
  90 ms). `AudioManager` alterna variantes `id_N` sem repetir a anterior, com gerador próprio (fora da simulação
  determinística); limite e recarga contam pelo id. `kenney_medal`, `kenney_pearl` e `kenney_hit` seguem nos outros
  usos (resultado, Arca da Maré, selo, diário, glifo). Testes em `tests/integration_tests.gd`. Falta ouvir no aparelho
- ✅ `1.14.4` `tools/run_checks.ps1` ~5x mais rápido (727 s para ~140 s num Ryzen 5 4650U de 6 núcleos), com as mesmas
  verificações (integração 82.069, regras 1.785 + 26 novas das fatias) e os mesmos critérios. Medido antes: a
  integração esperava o relógio (o limite de 60 FPS fazia cada quadro custar 16,7 ms; layout, 345 s) e as regras eram
  41 partidas inteiras do bot em série (128 s). Agora: integração com `--fixed-fps 60` e esperas em quadros; regras e
  integração em fatias por processo (`-- --shard=I/N`, `tests/test_shard.gd`), conferidas pelo script (as fatias
  somam todas as unidades); etapas 2 a 6 em paralelo, cada Godot com user:// próprio e temporário. Otimizações reais
  e exatas no jogo: alvos do chefe para as balas do jogador montados uma vez entre acertos (`Sim`), e o piloto do bot
  calculando as projeções das balas uma vez por passo e descartando só as que provadamente não pesam (`BotPilot`):
  hash igual nas 80 partidas (40 missões x sementes 7 e 11) e no determinismo (`fc77bf6d...`). Caminho crítico
  restante: a campanha da economia (34 missões em série, ~75 s sozinha). Detalhes em `docs/policies/testes.md`
- ✅ `tools/run_checks.ps1` ~1/3 mais rápido nas etapas 2 a 6 (Ryzen 7 4750U, 8 núcleos / 16 lógicos; lado a lado
  na mesma carga: 358 s para 241 s), com as mesmas verificações (2.737 de regras e 540.518 de integração). Medido com `-- --timing`: a campanha da economia tinha crescido para ~165 s sozinha (~270 s com a
  máquina cheia) e marcava o fim; os pesos das fatias estavam fora (a unidade dos poderes valia 270 e custava 3 s; as
  "regras rápidas" valiam 2 e custavam 22 s). Agora: pesos em segundos medidos; as regras rápidas em uma unidade por
  arquivo; a campanha da economia em 3 trechos paralelos (`-- --economy=I/N`), cada um partindo do estado guardado em
  `.godot/test-cache/` e conferido pelo script contra o fim do trecho anterior nesta rodada (estado velho: o trecho
  roda de novo); a parte pura da Evolução e do "Quase lá" saiu do prefixo que rodava em toda fatia; o portão de
  scripts carrega tudo só numa fatia. A rodada logo depois de mudar a partida refaz um ou dois trechos (+~1 min)
- ✅ `1.14.5` Telas montadas uma vez só por abertura. Antes, o `_ready` de `Screen` chamava `refresh_texts()` e o App
  chamava `on_show()` logo depois, que chamava de novo: as 10 listas (`ListScreen`: hangar, naves, opções, diário,
  eventos, loja, cidade, prática, temporada, recordes) montavam a coluna inteira duas vezes na primeira abertura, e
  hub, mapa e resultados refaziam os textos (o resultado ainda montava uma vez com um resultado vazio). Agora a tela
  declara `refreshes_on_show()` e o `_ready` só calcula o layout (o hangar escolhe a escala da nave por ele); o App
  abre a tela por `Screen.present()`. Trocar de idioma remonta só a tela aberta; as escondidas ficam marcadas e
  remontam uma vez ao abrir. O hub guarda o saldo de antes do login do dia na primeira abertura (a recompensa
  continua subindo na pílula). Medido em todas as resoluções x 11 idiomas: 576 montagens de lista para 288 (uma por
  abertura); abrir as 16 telas, 237 s para 134 s de CPU (naves 34,6 para 16,3 s; hangar 31,6 para 15,2 s; eventos
  27,9 para 13,3 s; temporada 23,8 para 11,6 s); fatias de layout da integração ~115 s para ~87 s. Capturas do
  `tests/screens_runner.tscn` com `--fixed-fps 60` e user:// novo: as 576 iguais pixel a pixel, salvo o número da
  versão no título. Teste novo `tests/screen_build_tests.gd` (33 verificações): uma montagem por abertura, reabrir com
  dado novo (nível, saldo, resultado), idioma trocado com a tela escondida e com a tela aberta.
- 🔧 Menus de comando, fase 1 (fundação; branch `feat/menus-comando`, inspirado na estrutura dos shmups mobile, sem
  copiar arte nem monetização). Casca de navegação `NavShell` (`scripts/ui/nav_shell.gd`) por cima das cinco
  telas-aba — Loja, Oficina, Campanha (hub, no meio), Naves e Eventos: barra de cima com a piloto (retrato da Maré,
  nível e barrinha de XP, `Economy.pilot`), Poder em ouro (`Economy.power`), moedas em pílulas com "+" (levam à
  Loja) e Opções; barra de abas com a ativa elevada, bolinha "!" (`scripts/core/notices.gd`), LB/RB e Q/E. Trocar de
  aba não empilha histórico; voltar numa aba leva à Campanha. As telas-aba perderam Voltar e moedas próprias (título
  vira faixa `CommandKit.ribbon`) e recebem `safe` já sem a casca (`Screen.shell_insets`). Poder recomendado por
  capítulo ancorado na curva do bot (`Economy.recommended_power`). Kit visual para a fase 2 em
  `scripts/ui/command_kit.gd` (aviso, faixa, ladrilho por raridade, atributo, encaixe, selo do Poder). Textos em
  `tools/i18n/command.py`. Testes em `tests/command_tests.gd`, layout das abas com a casca em `tests/layout_tests.gd`.
  Falta a fase 2 (conteúdo de Campanha, Oficina e Loja) e conferir no aparelho
- 🔧 Menus de comando, fase 2 — aba Campanha: a casa é a trilha do capítulo (`hub_screen.gd`, regras puras em
  `scripts/core/campaign_trail.gd`, peças em `scripts/app/ui/campaign_parts.gd`, cartão em `mission_card.gd`):
  número do capítulo em ouro, Poder contra o recomendado, nós em zigue-zague com estrelas, sonar e nave na próxima
  missão, setas/deslize entre capítulos abertos, marco com prêmio que já existe (aeronave dos fragmentos ou próxima
  asa), atalhos dos dois lados, JOGAR entre Carta e Desafio. Textos em `tools/i18n/command_campaign.py`; testes em
  `tests/campaign_tests.gd` (todos os capítulos no layout apertado e no desktop). Arrastar a trilha na vertical
  (dedo ou mouse) rola entre os capítulos abertos com os nós à vista: para baixo o capítulo de cima entra pela borda
  de cima (para cima, o anterior por baixo), a linha que sai de um encontra a que entra no outro; ao soltar, além de
  1/3 da altura ou num piparote (700 px/s) assenta no vizinho em até 0,24 s (sem animação em "reduzir movimento"),
  senão volta; no primeiro e no último aberto a trilha só cede (18% da altura) e volta. Até 12 px é toque (o nó abre
  o cartão); o deslize lateral, as setas e o controle seguem iguais. Testes de arraste em `campaign_tests.gd`.
  Falta conferir no aparelho
- 🔧 Menus de comando, fase 2 — Loja, Naves e Eventos: Loja com sub-abas em pílula (`scripts/app/ui/pill_tabs.gd`),
  baú no cartão-destaque com retrato pixel art em escala física inteira (`store_banner.gd`), pinturas em grade de
  ladrilhos por raridade com estado sempre legível e painel de detalhe Comprar/Equipar (`command_sheet.gd`,
  `ship_icon.gd`), tira discreta da versão de teste; Naves com palco da nave em foco, atributos em placas e grade
  com aviso de nova; Eventos com faixas de seção e modos em banners ilustrados (`mode_banner.gd`). Regras intactas.
  Textos em `tools/i18n/command_store.py`; testes em `tests/store_tests.gd`. Falta conferir no aparelho
- 🔧 Menus de comando, fase 2 — aba Oficina (`hangar_screen.gd`): palco com a nave grande entre seis encaixes (arma,
  asas 1 e 2 | pintura, núcleo, desafio), atributos e "Evoluir nave" dourado com ganho de dano, Poder e peça; sub-abas
  Nave, Armas, Asas, Pinturas e Desafio em grade de ladrilhos por raridade (regra e figuras em
  `scripts/app/ui/loadout_art.gd`) e cartão de detalhe com antes → depois e preço sempre legível; palco e grade lado a
  lado no desktop. Regras intactas. Textos em `tools/i18n/command_hangar.py`; testes em `tests/hangar_tests.gd`,
  capturas em `tests/hangar_shots_runner.tscn`. Rebase sobre a 1.14.5: telas novas abrem por `Screen.present()` e
  montam uma vez por abertura; os testes novos entram nas fatias da integração (Oficina com um caso de resolução por
  unidade, ~2 min em série). Falta conferir no aparelho
- ✅ `1.15.1` Retratos novos com transmissão: os 5 personagens (Maré, Farol, Duarte, Thalassa, Protocolo) agora são
  arte ilustrada 96x96 derivada do *Cyberpunk Portraits* (Hyptosis, CC0; registro `hyptosis_cyberpunk_portraits`),
  refeita por `tools/gen_portraits.py` (numpy): recolor por matiz e luminância, figurino desenhado por código (faixa
  coral, óculos com reflexo ciano, quepe de almirante, dragona, glifo atlante, lente vermelha com malha hexagonal),
  expressões por deformação local de boca, sobrancelhas e bochechas mais luz por humor, fundo na cor da fala com
  halo e vinheta (`--preview DIR` grava a folha 5x3). Filtro linear com mipmaps (96 para 32 px sem serrilhar);
  retrato da história sobe de 72 para 96 pt. Shader `shaders/portrait_fx.gdshader` (MIT, próprio): rádio
  (varredura que rola, cintilação, grão, zumbido, borda ciano), etéreo para Thalassa (ondulação de água, cáusticas,
  brilho pulsante, aura violeta) e glitch para o Protocolo (separação RGB, rajadas de fatias, lente pulsante); cada
  fala nova faz a sintonia de 0,35 s (`Portraits.tune_in`: aberração, faixas, pixels entrando com chiado). Reduzir
  movimento ou flashes congela o efeito. Testes em `tests/post_tests.gd` (tamanho, shader, modo por voz, linhas por
  altura, acessibilidade, narrador sem efeito). Falta conferir no aparelho
- ✅ `1.16.0` Poderes das naves (.ai/08-poderes-das-naves.md): 3 poderes por aeronave (36) com o medidor de Corrente.
  Simulação em `scripts/sim/powers.gd` e `scripts/sim/power_effects.gd` (20 primitivas, determinísticas). Na tela:
  botão PODER (H / Y) na zona do polegar, de fora para dentro especial, bomba e PODER (espelhado na mão esquerda),
  com o anel da Corrente em 3 segmentos que enchem suave na cor da nave, o ícone do poder que sairia agora, pulso e
  tom (`power_charge_1..3`) a cada segmento, halo no nível III, tremida e `power_empty` no aperto vazio, e o nome
  do poder (encolhe a letra e termina em reticências em vez de quebrar). Poderes I e II: selo pequeno no alto
  do campo (ícone, nome e nível, 0,9 s); o III: título grande e curto (1,1 s) no terço de cima, com a música
  abaixada e a pausa de impacto da Sim; raio da Tempestade Elétrica com alcance 160; tremor, clarão e vibração por nível,
  respeitando "reduzir flashes", "reduzir movimento", tremor da tela e vibração. `scripts/view/power_view.gd`
  desenha os 20 tipos de efeito com os sprites de `assets/art/generated/powers/` (rastro da investida com imagens
  da nave, anel de choque, salvas com sprite e rumo, feixes com halo e núcleo, ondas de tempo, raio encadeado,
  onda e muralha com textura rolando, redemoinho girando, escudo frontal, orbes, morteiros caindo sobre o aviso,
  drones e seus tiros, manto translúcido, coroa, eclipse com a tela escura e halo macio, sobrecarga com mira de
  crítico, reparo com centelhas, implosão e explosão da supernova) em duas camadas novas do WorldView (normal e
  aditiva), só texturas e partículas do ParticleField, nada de nó por quadro; o que a Sim encerra apaga em 0,28 s.
  Dica `hint.power` no tutorial no primeiro segmento cheio. Tela Naves lista os 3 poderes de cada aeronave (ícone,
  nome, nível, frase). Co-op: a Sim só lê PODER da nave 1 (a ala segue sem poder). Capturas:
  `tests/game_shots_runner.tscn -- --powers[=naves]` lança os 36 no auge e grava também o medidor cheio. Testes:
  `tests/power_view_tests.gd` (os 36 desenhados do começo ao fim sem erro de script, todo tipo visto, nenhum nó a
  mais, HUD em cada carga) e o HUD de `tests/layout_tests.gd` com a Corrente cheia nas duas mãos, em todas as
  resoluções
- ✅ `1.17.0` Anúncio recompensado REAL (Google AdMob + consentimento UMP) no Android grátis. Plugin Poing AdMob
  5.1.0 em `addons/admob` (MIT, licença e crédito registrados, junto do SDK do Google como `LicenseRef-` com
  decisão), habilitado no `project.godot` com o app de TESTE do Google (`admob/general/android/app_id`).
  `scripts/core/admob_provider.gd` (portado do hyakki: UMP, inicialização, carga com nova tentativa, recompensa só
  com a confirmação do Google, opções de privacidade, conteúdo "PG") e `Ads` com três modos: "admob" (Android com o
  plugin; IDs de teste em debug), "mock" (editor, testes, PC) e "off" (release sem IDs reais: `RELEASE_UNITS` vazio,
  sem SDK, recompensa direto, como antes). Só recompensado: reviver, dobrar créditos, dobrar as Pérolas do Diário
  (novo, 1 vez por dia, `Modes.double_daily_pearls`) e baú em dobro; sem intersticial, sem banner, nunca na missão,
  nunca na Steam nem para quem apoiou. UMP na abertura (`Ads.start` no `App`, sem travar) e "Privacidade e
  anúncios" nas Opções quando o UMP exige. Anúncio ainda não carregado: o botão mostra o texto sem anúncio e a
  recompensa sai de presente; o baú em dobro some até carregar; a tela se refaz quando ele carrega.
  `Store.simulated` passa a depender só do Play Billing (o APK de debug com o AdMob segue simulando a compra).
  Testes em `tests/beta_tests.gd` (regras do provedor, Diário 1 vez por dia, apoiador). ⚠️ Falta o mantenedor: app
  e bloco no AdMob, `RELEASE_UNITS` e app_id reais, depois política, ficha e Data Safety (fim de
  `docs/store/play-console.md`); conferir no aparelho
- ✅ `1.18.0` Anúncio recompensado LIGADO no release: IDs reais do AdMob do mantenedor (`RELEASE_UNITS` e
  `admob/general/android/app_id`), teste de `tests/beta_tests.gd` invertido (tem IDs reais e o app_id fica no
  `project.godot`). Política de privacidade 1.2 (o que o SDK do Google coleta, consentimento UMP, ID de
  publicidade), ficha (anúncios opcionais, nunca na missão, sem venda de poder) e respostas do Play Console
  (Anúncios = Sim, Segurança dos dados, ID de publicidade) atualizadas; cópia da política em
  `netstart.github.io/atlantis/`. `tools/check_release_ads.py` (portado do hyakki, sem Play Billing) confere o AAB
  em `tools/build_release.ps1`. ⚠️ Falta o mantenedor: mensagem de consentimento no AdMob, publicar o site,
  declarações no Play Console, conferir no aparelho (cadastrado como dispositivo de teste no AdMob)
- ✅ `1.18.1` Correções da revisão do anúncio recompensado. Diário: o resultado da partida leva a data do Diário
  jogado (`Sim.result` lê `mission.daily`; a partida que passa da meia-noite conta no dia em que começou), então
  o Diário reinicia todo dia, paga as 10 Pérolas, dobra 1 vez por dia e aparece feito em Eventos; save antigo com
  `daily.date` vazio volta a funcionar sozinho. Anúncio fechado antes do fim não vira "grátis" na mesma tela de
  resultado (`Ads.show_rewarded(..., allow_free)`); anúncio que falha ao abrir conta como "sem anúncio" (o reviver
  não se perde); SDK e pedido de anúncio só com consentimento UMP obtido ou dispensado
  (`AdMobProvider.consent_allows_ads`); rede de segurança se o callback do anúncio não vier (5 s depois de o app
  voltar à frente, sem recompensa); anúncio carregado troca só o texto dos botões de dobrar (as linhas de
  recompensa não somem na revelação); chave `consent` sem uso tirada do save; `tools/build_release.ps1` falha
  cedo sem o JDK 17. Testes em `tests/beta_tests.gd` (Diário pelo `App.record_result`, consentimento, desfechos do
  anúncio, save) e `tests/glory_tests.gd` (botões de dobrar)
- ✅ Campo mais alto e botões na lateral: campo de 270 x 450 a 640 pela altura da tela (`Playfield.height_for`), guardado
  na carga da partida (`field_h`; replay e Fantasma reproduzem igual, replays antigos rodam em 450), indo até a borda de
  baixo; Sim, bot, VFX, clima e poderes leem `sim.field`. HUD de cima sobre o topo do campo, pausa pequena na linha do
  placar (toque de 36 pontos), botões redondos empilhados na borda esquerda (bomba, PODER, especial e a vaga do Turbo;
  direita para canhotos) com a arma e o nome do poder ao lado, mais apagados com a nave por baixo; o dedo que começa num
  botão não move a nave. Botão Turbo (`Turbo.owned`) troca 1x/1,5x/2x rodando mais passos fixos por quadro
  (`GameClock.turbo`). PC deitado: campo e HUD ampliados até a altura da janela (escala inteira quando dá, senão
  SubViewport com `shaders/sharp_pixels.gdshader`), placar, pausa e bloco 2x2 de botões colados no campo. Testes em `tests/run_tests.gd`, `tests/sim_tests.gd` (campo alto e replay antigo) e
  `tests/layout_tests.gd` (pilha, toque e Turbo)
- ✅ Retrato na largura inteira: o campo e o HUD são ampliados até a largura da área segura (escala = largura / 270, que
  pode ficar abaixo de 1; altura = altura / escala, entre 450 e 640), sem faixas laterais nos celulares; em tablet a
  altura manda e as laterais viram moldura. A pilha de botões fica centrada na vertical, encostada na borda esquerda
  (direita para canhotos), longe do canto de baixo onde a nave anda. Testes em `tests/run_tests.gd` e
  `tests/layout_tests.gd`
- ✅ Laser e Mergulho Solar fluidos: o feixe do Laser deixa de ser dois retângulos de `fx/beam` esticados (bordas duras,
  miolo branco chapado, corte reto no bico) e vira um quad só com `shaders/energy_stream.gdshader` (aditivo: núcleo
  claro, corpo e halo gaussianos que somem até zero, nasce fino no bico e abre, faixas de ruído subindo, apaga macio
  na ponta) desenhado por `scripts/view/energy_stream.gd`, que abre e fecha em rampa (0,07 s / 0,12 s). No Mergulho
  Solar (overdrive de cadência 2x) o feixe esquenta para branco-dourado e, com outra arma, sai uma pluma curta de sol
  do bico; bocal pulsante no bico e anel de choque com frente morna e rastro (`PowerView.solar_heat`: entra em 12 e
  sai em 30 passos). "Reduzir flashes" corta a cintilação e o halo. Só desenho (hash da Sim igual). Capturas:
  `tests/power_shots_runner.tscn -- --shots=<pasta> --power=falcon_3 --weapon=laser --level=4 --at=...`. Teste em
  `tests/vfx_tests.gd` (rampas de entrada e saída e a Sim intocada)
- ✅ Janela dos runners que cabe no monitor (AGENTS.md, regra 7): `tests/device_window.gd` põe o runner num
  SubViewport do tamanho físico pedido (tela lógica do PixelScaler) e mostra o quadro reduzido numa janela na área útil,
  centralizada. Capturas, benchmarks, retratos, arte da loja e Oficina usam o helper; PNGs e layout iguais aos de antes
- ✅ Saída da missão vencida (`scripts/sim/sim_outro.gd`): quando o chefe que encerra a fase cai (ou a última onda
  some, nas fases sem chefe no fim), o campo fica limpo de vez (inimigos sem pontos nem drops, balas, feixes, mísseis,
  perigos, poderes, especial, laser e Maré Alta), os coletáveis vêm todos até a nave, e ela centraliza, arranca com
  rastro maior (som da investida do Falcon) e sai pelo topo; só então `finished`/`cleared`, ~2,7 s depois da morte
  do chefe, no lugar do `FINISH_DELAY`. Botões de ação somem e a vista apaga os efeitos restantes (fica a explosão do
  chefe). Replays sem a marca `"outro"` na carga rodam com o fim antigo. Teste em `tests/sim_tests.gd` (`_outro`)
- ✅ Saída fluida das balas inimigas (revisão 2 da Sim, `scripts/sim/sim_revision.gd`): a bala nasce na boca do emissor
  (`PatternRunner.muzzle`, na borda do raio do inimigo, do corpo ou da parte do chefe, até 30), não no centro;
  vizinhas da mesma emissão nascem a ≥ 2,6 raios uma da outra (anel abre o raio, leque estreito abre de lado, fila
  escalonada).
  Acabou o bolo de balas em cima do sprite (Raia-Trovão e 86 outros usos de padrão). Na vista, a bala inimiga entra em
  6 passos de 65% ao tamanho cheio (hitbox igual desde o primeiro passo). A carga do replay grava `"rev"`; replays e
  Fantasmas sem ela rodam na revisão 1. Teste em `tests/sim_tests.gd` (`_spawn_spread`, todos os padrões);
  `boss_timing.gd` e `game_shots_runner` aceitam `--rev=1` para comparar
- ✅ Retorno de dano do chefe legível (só vista, hash igual): no lugar do branco chapado, que sob tiro contínuo escondia
  o chefe, um tinte quente (borda alaranjada e ~30% no miolo) que pulsa no máximo a cada 7 passos e apaga em 10,
  com tranco de 1 a 2 px pelo tamanho do golpe (`scripts/view/hit_pulse.gd`, `shaders/sprite_flash.gdshader`).
  Partes com o mesmo pulso; ponto fraco acende dourado, e o acerto nele solta faíscas douradas. Abaixo de 30% do HP,
  brasas piscando devagar em três ferimentos, fumaça leve e faíscas esparsas. "Reduzir movimento": sem tranco e
  tinte até 16%. Teste em `tests/vfx_tests.gd` (`_test_hit_pulse`)
- ✅ Mesmo retorno de dano em todo inimigo (comuns, elites, torres, chefes de meio; só vista, hash igual): o branco
  chapado saiu do shader; cada inimigo atingido ganha um HitPulse (`scripts/view/enemy_pulses.gd`, chave pelo id de
  instância, estoque reaproveitado, liberado quando ele morre ou sai). Tranco só em raio ≥ 15 (metade a inteiro pelo
  tamanho). Teste em `tests/vfx_tests.gd` (`_test_enemy_pulses`)
- ✅ Compras da Play sem vender força (`scripts/core/iap.gd`, catálogo no lugar do caminho só do Turbo): Turbo,
  "Apoiar a Halcyon" (agora real: sem anúncio e tema dourado do hub), 4 pinturas com rastro, halo de tiro pastel e
  estouro próprios (também por Pérolas), atalho da Tridente (nave lateral; fragmentos continuam), pacote inicial
  (oferta única no resultado do 1º chefe de ato, sempre em Loja › Extras) e o consumível de 3 revives sem anúncio
  (troca só o anúncio; 1 reviver por missão). Restaura, pendente, acknowledge/consume e reembolso; sem preço da Play
  não aparece. Expansão de modos ficou de fora (seção 17). Produtos para o Console em `docs/store/play-console.md`.
  Teste em `tests/iap_tests.gd`
- ✅ Rebalanceamento (revisão 3 da Sim, `scripts/sim/sim_curve.gd`): curva por capítulo (balas +30%, cadência +45%,
  vida +80% nos comuns e +15% no chefe de ato, no cap. 10 da Normal; Brisa 0,5x, Veterano 1,3x, Abissal 1,5x), rank
  na cadência (±10%) e hangar +3% de dano por nível (era +4%). Replays antigos seguem as regras da revisão deles.
  Meta e medição no plano mestre 4.7; `tests/boss_timing.gd` ganhou `--seeds`, `--diff`, `--hangar` e resumo por
  capítulo
- ✅ Mortes de inimigo vistosas e variadas (só vista, hash igual): três estilos sorteados no desenho
  (`CombatFx.death_style`, hash da contagem de mortes, do lugar e do sprite; pesos 40/25/35, e 45/10/45 nos grandes):
  explosão reforçada (clarão, bola de fogo maior, dois anéis, brasas, fumaça baixa e estouros secundários),
  derretimento no lugar (`shaders/sprite_melt.gdshader`: colunas escorrem, frente de dissolução com borda em brasa,
  pingos e brasas, estouro no fim) e queda em chamas girando até a sombra (rastro de fogo e fumaça), que bate no mar
  (coluna d'água, espuma, explosão abafada com bolhas) ou no chão (explosão, marca, estilhaços, poeira); no espaço
  (`floor: none` em stratosphere, orbit e core) a queda vira explosão ou derretimento. A queda generaliza o antigo
  destroço (`CombatFx.wreck`, teto `MAX_WRECKS`); o aviso `landed` dá anel, som e tranco no impacto. Testes em
  `tests/vfx_tests.gd` e `tests/death_view_tests.gd`; capturas com `game_shots_runner -- --deaths --mission=c1m1`
- ✅ Som: glifo e bênção mais quentes (glifo `kenney_orb` 0,6 + 0,05 por glifo, -6 dB, com `kenney_ascend_bell`;
  oferta de bênção com o sino no lugar do `kenney_weapon_up` agudo; tons do medidor uma quarta abaixo, -7 dB).
  Chefe sempre audível: `AudioManager.play_priority` (sem recarga nem limite por id, toma a voz mais antiga), parte
  quebrada em camadas com cauda de destroços e morte com estouros no tempo da cadeia visual (`fx.later`) e o
  estrondo final; mortes grandes com a explosão grande por baixo. Arrancada da saída (`outro_rise`) com o
  `outro_afterburner` (turbina, ignição e pós-combustor, `tools/mix_power_audio.py`) e vibração em rampa
- ✅ Objetivos de fase (plano mestre 5.6): 2 metas curtas por missão nos capítulos 1 a 3 e 3 do 4 em diante, sempre
  com um resgate, de 10 a 25 s, nunca reprovam. **Resgate** (Jaula do Protocolo no chão e no mar, cápsula-prisão
  à deriva no céu e no espaço; destruída solta 3 a 6 atlantes em bolhas que contam em `Sim.rescued`, final e
  Cidade de Thalassa), **sabotagem** (3 Faróis do Protocolo com prazo; falha chama a onda de reforço) e
  **interceptação** (mensageiro com a relíquia roubada; abatido, a relíquia voa até a nave). Acerto: 5.000 pontos,
  12 pérolas e 2 de oricalco (+1 no resgate perfeito). Regra em `scripts/sim/sim_objectives.gd`, revisão 4 da Sim
  (`SimRevision`; replay antigo ignora, provado passo a passo em `tests/objective_tests.gd`); alvos sem dano de
  contato (`data/enemies.json` "contact"). Roteiro em `data/stages/*.json` "objectives" por `tools/gen_missions.py`
  (os eventos das fases não mudaram). Arte gerada em `tools/gen_sprites.py` (jaula, cápsula-prisão, farol, atlante
  na bolha, relíquia, mira); desenho em `scripts/view/objective_view.gd`; marcador no HUD em
  `scripts/game/hud_objective.gd` (testado em todas as resoluções); falas e sons em `game.gd` (sino quente numa
  escala maior a partir de 0,6 por atlante salvo; nada agudo); linhas no resultado ("Resgate 4/5 ★"). Bot mira os
  alvos e busca atlantes e relíquia. Textos em `tools/i18n/objectives.py`. Falta conferir no aparelho
- ✅ Naves HD, fase 2 (pedido do dono: visual dos shmups modernos de celular). `tools/gen_hd_ships.py` gera as 12
  aeronaves e as 24 naves das três frotas em `assets/art/hd/` (2 texels por unidade, motor de 6 quadros, pós-combustão
  do jogador, brilho da silhueta; Kla'ed scout e fighter mais claros com borda vermelha) e registra cada arquivo no
  `asset_index` com a licença do autor (MillionthVector e XENIS em CC BY 3.0, ratificada; W_K_Studio CC0; crédito
  exato no campo `credit`, no `CREDITS.md` e na tela Créditos). `SpriteBank` prefere a HD (Void de reserva) e separa
  `tex_size` de `size`; a nave do jogador é a da carga (`SpriteBank.player`), desenhada por `ShipArt` na partida, na
  ala, no Fantasma e nos menus, sem a tinta de `ships.json`; pintura da loja recolore pelo shader
  (`sprite_flash.gdshader`, modo pintura) e nas miniaturas (`ShipIcon`). Camadas de naves com filtro linear com
  mipmaps; pixel art numa camada própria; hitbox por cima de tudo. Avaria genérica a 2/3 e 1/3 (escurece, rachaduras
  com faísca e fumaça em pontos fixos do casco). Evolução do hangar refeita como luz (`data/livery.json`,
  `ShipLivery`): chama 1,0→1,3x, brilho de acento, pós-combustão no 4, divisas no 5, luzes de navegação no 6, aura no
  7, cristal no 8, runas no 9 e pulso de borda em ouro no 10; emblemas e decalques em `tools/gen_livery.py` (as peças
  48x48 da Void saíram). Explosão das naves HD em partículas (sem tira Void). Objetivos (revisão 4): o rádio do aviso dura
  exatamente o aviso da Sim (1,5 s), então os alvos entram com o alto do campo livre em todo layout. Testes em
  `tests/sprite_bank_tests.gd`, `tests/livery_tests.gd`, `tests/layout_tests.gd` e `tests/credits_screen_tests.gd`.
  Falta conferir no aparelho
- ✅ Naves premium (pedido do dono: naves vistosas vendidas com dinheiro real na Play). Três naves (`hippocampus`,
  `nereid`, `amphitrite` em `data/ships.json`, campo `premium` com o produto e `kit` com a nave de origem: Tempest,
  Manta e Hydra) e o pacote `premium_fleet` (as três, US$ 5,99 contra 3 x US$ 2,99). Sem força à venda: mesmos
  atributos, arma, especial e os três poderes da origem (`Powers.validate` reprova diferença; mesmo Poder). Arte por
  `tools/gen_hd_ships.py` (`PREMIUM`): XENIS dourada e violeta giradas 180° e a meia-lua "RD2" da Faction 6 em
  turquesa, com madrepérola nos meios-tons, ouro nos realces, luz de borda cheia, chama de cor própria e a tira
  `<id>_sheen.png` do brilho que varre o casco (`ShipArt._sheen`). Rastro, tiro pastel e estouro próprios
  (`Store.ship_fx`, a pintura vale por cima). Loja: seção "Naves premium" no topo de Extras, pacote em destaque com a
  economia (micros da Play), cartões com a vitrine animada (`PremiumShowcase`), selo, preço da Play e "Visual
  exclusivo, não é mais forte". Coleção: grade "Naves premium" fora da contagem, com "Ver na Loja". Reembolso tira só
  o que nenhuma outra compra dá; restaurar devolve; Steam inclui as três (`Iap.include_premium`); conquista de frota
  não conta premium. Play Console: `tools/play_products.py` (convertRegionPrices, onetimeproducts.patch com
  allowMissing, ativação da opção `<id>-compra`; `--dry-run` e `list`). Testes em `tests/premium_tests.gd` (regras,
  Play falsa e layout da seção e da coleção em todas as resoluções). Falta: o mantenedor rodar `apply` com a chave e
  conferir no aparelho a compra de teste
- ✅ Caixas de colisão ajustadas à arte HD (pedido do dono: "ajuste o hitbox de todas as naves"). `tools/fit_hitboxes.py`
  (numpy e Pillow) lê o alfa da base de cada nave como ela é desenhada (escala, `part_scale`, inimigos e chefes girados
  em PI), tira antenas, pernas e asas finas (abertura de 3 unidades) e grava `data/hitboxes.json`: inimigos e partes
  com sprite ganham o círculo de dano que cobre 85% do corpo (generoso para o tiro), o centro deslocado e o raio de
  contato do miolo (50%); o corpo do chefe nunca fica abaixo do `body_radius` da tabela (a vida da luta foi balanceada
  nele); as naves do jogador mantêm o raio de `ships.json` (o ponto do piloto contra as balas, que não mudaram) e o
  ponto vai para a cabine de cada nave HD (posto de olho na folha; nave nova sem ponto usa o centro da espinha).
  `Hitboxes` (revisão 5 da Sim) aplica tudo na colisão (tiro, respingo, feixe, mísseis, poderes, contato, partes,
  raspão e o ponto da nave); o que falta no arquivo cai no valor antigo e a revisão 4 joga igual, passo a passo
  (replays antigos conferidos contra o código da 1.25.1). O ponto desenhado na nave fica no ponto da Sim
  (`SimPlayer.hit_pos`); `WorldView.debug_hitboxes` desenha os círculos e `game_shots_runner -- --hitboxes` grava as
  galerias (inimigos, chefes, naves). Bot: desvia pelo ponto deslocado, foge das paredes e contorna o chefe quando
  fica acima dele. Balanceamento (3 sementes, 120 partidas): antes 3 derrotas e 24 danos, depois 0 derrotas e 14
  danos; lutas de chefe 14% mais curtas no total (fragatas a 1,5x mais longas para o bot). Testes em
  `tests/hitbox_tests.gd`. Falta conferir no aparelho
- ✅ Evolução da nave com peças físicas (pedido do dono: "cada evolução da nave precisa adicionar algo no gráfico
  dela"). Cada nível do 2 ao 10 monta uma peça nova no casco, cumulativa: blindagem (2), canhões de asa com boca
  acesa (3), propulsores extras com chama própria (4), aletas de asa (5), estabilizadores (6), casulos de mísseis (7),
  domo sensor com antenas (8), bobinas de energia (9) e a coroa de ouro com o acabamento dourado das peças (10).
  `tools/gen_livery.py` desenha as peças em relevo (chanfro, luz de cima à esquerda, especular, luz de borda,
  contorno, sombra sobre o casco) na cor do metal de cada nave (tabela luminância -> cor do matiz dominante) e grava
  `<nave>_evo.png` (9 quadros do tamanho da base), `<nave>_evo_glow.png` e `<nave>_jet.png`; as âncoras por nave e os
  pontos da boca, dos jatos e das pontas das aletas ficam em `data/livery.json`, e o gerador reprova peça sobre o
  ponto de acerto (`data/hitboxes.json`). A luz ficou como reforço (brilho e aura mais suaves, luzes de navegação nas
  aletas, cristal no domo, bobinas pulsando); a divisa saiu. Emblemas da Oficina mostram a peça. Anfitrite trocou o
  casco "orangeship" pela meia-lua RD2 da Faction 6 (girada 180°, turquesa e ouro). Testes em
  `tests/livery_tests.gd`; folha em `tests/livery_shots_runner.tscn` (15 naves x níveis 1 a 10). Falta: o WorldView
  passar `firing` ao `ShipArt.draw` para a boca dos canhões lampejar a cada tiro
- ✅ Feixe dos chefes saindo da boca e mirando (pedido do dono, Aríete de Coral: "feixe desalinhado e gráfico muito
  ruim"). Antes o feixe ficava parado na vertical onde nasceu e o chefe saía de baixo dele. `EnemyBeam` (revisão 6 da
  Sim): o feixe do op `beam` sai da boca do emissor (centro + `ox`/`oy`) e a segue a cada passo; no aviso mira o
  jogador (as linhas mostram a mira real) e trava nos últimos 24 passos; aceso, gira para o jogador no máximo
  `track` graus/s (padrão 12: a 300 u do chefe a ponta anda ~63 u/s, a nave 163 a 192 u/s, então quem anda escapa).
  `aim: false` deixa colunas verticais que só seguem a boca (pilares do Arquiteto, faixas do Leviatã, tridente de
  Poseidon, pilares do Portão Orbital). Dano no segmento inclinado (distância ao segmento, da boca à borda do campo).
  Emissor que some (morto, fora da tela, parte destruída, troca de etapa) leva o feixe: no aviso some, aceso fecha em
  8 passos sem ferir. Feixes do cenário (raio, gêiser) e replays até a revisão 5 seguem iguais, passo a passo
  (conferido contra o código da 1.26.0 em c2m3, c3m1 e c5m2). Desenho novo em `HostileBeams` +
  `shaders/hostile_beam.gdshader` (um quad por feixe, girado): núcleo branco-quente, corpo vermelho-magenta, halo,
  contorno escuro (alfa pré-multiplicado) para ler em fundo claro, pulsos correndo para fora, abre e fecha em rampa;
  carga na boca durante o aviso, clarão na boca e respingo com faíscas na borda; "menos clarões" acalma tudo. O bot
  desvia do feixe inclinado. Balanceamento (bot, 3 sementes, 12 missões com feixe): danos 11 → 22, nenhuma perdida
  (com o Portão mirando, c8m2 perdia 2 de 3: virou coluna), 2 golpes de feixe em 36 partidas; o resto vem do
  desvio extra empurrando o bot para balas. Testes em `tests/beam_tests.gd`; capturas com
  `game_shots_runner.tscn -- --mission=c3m1 --beams`. Falta conferir no aparelho
- ✅ Nenhum feixe saindo do nada (pedido do dono, Sky Leviathan: "não pode ter um raio saindo do nada; ao menos precisa
  ter um drone"). Auditoria de todas as bocas de feixe de padrão contra a arte HD do emissor: fora do casco estavam
  as faixas laterais do Sky Leviathan (±95, 62 u fora), os raios do Olho da Tempestade (±70, 41 u), os pilares do
  Arquiteto (±90, 51 u), os feixes do Portão Orbital (±60, 27 u) e as asas da Raia-Trovão (±64, 27 u); os outros
  (Kraken, Poseidon, investida do Leviatã, Caranguejo, Hidra, Guardiã da Torre, Aríete, Enguia, Bulwark) já saem do
  casco ou a até 4 u dele. Revisão 9 da Sim: drones emissores (parte `"drone"` com `"deploy"`) nos postos das bocas,
  que saem de dentro do casco em 40 passos quando a etapa deles começa e voltam quando ela acaba; o feixe sai da
  lente do drone (padrões novos ancorados nele, mesmo ritmo) e destruir o drone corta o feixe e o tira da luta (2000
  pontos e medalha). Cada drone tem vida própria, de 4% a 10% da do chefe, independente dele (`leak` e `share` 0:
  acertar o drone não fere o chefe e vice-versa; pedido do dono), com uma barrinha coral logo acima do drone
  (`scripts/view/beam_drones.gd`), bem menor que a barra do chefe no topo, que some com ele. Raia-Trovão: a boca foi para as cápsulas laterais (±31), a arte não tem asas. Partes e entradas
  de padrão com `since_rev`/`until_rev` (`SimBoss.in_rev`): replays até a revisão 8 seguem a luta antiga. Arte do
  drone em `tools/gen_sprites.py` (`boss/beam_drone.png`, própria, 2 texels por unidade): casco de aço com aro coral,
  aletas, antena e lente magenta; no jogo (`BeamDrones`) a lente vira para o feixe, acende na cor dele durante o aviso e fica
  branca-quente aceso; os drones ainda no posto estouram com o chefe. Fontes: `tools/gen_bosses_beta.py`
  (Arquiteto, Portão, Leviatã), `tools/gen_bosses_mid.py` (Raia) e `data/bosses.json`/`data/patterns.json` (Olho da
  Tempestade, escrito à mão). Balanceamento (bot, sementes 7, 11 e 23): Arquiteto 121/102/103 → 122/103/102 s,
  Portão 54/81/78 → 54/84/79 s, Leviatã (c5m3a/c5m3s) igual a ±5 s, Raia igual; Olho da Tempestade 60/76/69 →
  62/68/55 s e danos 4 → 2 (os dois golpes de feixe somem: o bot derruba os drones de 480 de vida no caminho),
  nenhuma perdida. Testes em `tests/beam_tests.gd` (toda boca da revisão atual sobre a arte, drone com vida própria
  que morre sozinho, drone corta o feixe, dados dos drones, revisão 8 sem drones); capturas com
  `game_shots_runner.tscn -- --mission=c5m3s --beams --beam-boss=sky_leviathan --beam-phase=storm`. Falta conferir
  no aparelho
- ✅ Secundária sobe na fase (pedido do dono: "o tiro secundário também precisa receber atualização e ficar mais
  forte"). Revisão 10 da Sim (`SecondaryFire.phased`): cada orbe (e núcleo de força) sobe a arma principal e 1 nível
  da secundária, até 5; cada dano no casco tira 1. O módulo da Oficina dá só o nível inicial, com a mesma quantidade de
  antes (Oficina 1 a 5 → nível 1, 1, 2, 2, 3). Escala única: mísseis 2, 4 e 6 nos níveis 1 a 3, Ogiva I no 4 (+50%,
  maior, aço e ciano, rastro ciano) e Ogiva II no 5 (2x, dourada, rastro e halo dourados, estilhaço de 18 u que fere as
  escoltas no ar mas não o mar nem o chefe); drones 1, 2 e 3 com 30%, 35% e 40% do dano da arma principal, 60% no 4
  (drone e tiro violeta) e 80% no 5 (drone dourado, tiro champanhe); o lançador do mar das fases de água é sistema
  automático, não secundária, e segue fixo em 1 par de 5 (decisão do coordenador: com o nível, o bot perdia a c5m3a
  na semente 7); módulos do Abismo continuam instalando no nível 2 ou subindo 2. HUD: glifo da secundária e 5 degraus abaixo dos da
  arma (3 ciano, 2 ouro; `HudSecondary`), com pulso dourado e o som de melhora na subida. Arte própria em
  `tools/gen_sprites.py` (ogivas, drones e tiros); desenho em `scripts/view/secondary_art.gd`. Replays até a revisão 9
  seguem com o nível fixo da Oficina. Balanceamento (bot, sementes 7 e 11, c1m1, c1m3, c3m2, c5m2, c7m3s, c9m2,
  c10m3; `boss_timing.gd --secondary=missiles:3` e `drones:5`): fases de 142 a 187 s, nenhuma perdida, 0 dano; luta
  do Olho da Tempestade 43/60 → 29/34 s com mísseis, Arquiteto 53/66 → 56/47 s, Matriarca 98/113 → 66/84 s. Testes em
  `tests/secondary_tests.gd`; capturas com `game_shots_runner.tscn -- --secondary=missiles:5` (prende o nível).
  Falta conferir no aparelho
- ✅ Nave do jogador de volta ao tamanho original (pedido do dono: "a nave precisa ser menor, do tamanho da original").
  Medido pela caixa opaca: a Void da 1.24.0 tinha 30 x 26 unidades no nível 1 e 46 x 35 no 10 (lâminas); a HD da
  1.25.0 saía a 2 texels por unidade com 52 a 62 de altura (Falcon 43,5 x 56 no 1 e 67,5 x 57,5 no 10). Agora a
  partida desenha a nave, a ala, o Fantasma, a sombra e o rastro da investida em `ShipArt.GAME_SCALE` (0,5: 4 texels
  por unidade, texel a pixel num campo de 1080 px): Falcon 21,75 x 28 no 1 e 33,75 x 28,75 no 10, as 15 naves com 26
  a 31 no lado maior. Peças do hangar, chama, luz, rachaduras e brilho escalam no mesmo transform; bocais, fumaça de
  avaria, boca do canhão, número da ala e efeitos do clima usam `ShipArt.game_nozzles`/`game_used`/`game_spots`;
  escudo e bolhas voltam à proporção da original (quadro de 64 para 30 de nave). Menus e hangar têm zoom próprio e
  ficam como estavam. A boca dos tiros da Sim (-14/-16) e o bico do laser (`EnergyStream.NOSE` 15) já eram da nave
  original e voltam a casar com o nariz. Hitbox: o raio não mudou (é o de `data/ships.json` desde sempre); o ponto
  na cabine (`offset` de `data/hitboxes.json`, medido na HD em escala 1) encolhe junto na revisão 7 da Sim
  (`Hitboxes.ship`), e replays até a 6 seguem iguais. Testes em `tests/hitbox_tests.gd` e
  `tests/sprite_bank_tests.gd`. O bot passou a dar 10 unidades de folga ao feixe (eram 8): com o ponto novo ele
  encostava no feixe mirado da c8m1 na semente 7 (a c8m1 é limítrofe para o bot nas duas revisões). Falta conferir no
  aparelho
- ✅ Mar com submarinos e navios (pedido do dono: "quando o solo é água, adicione submarinos inimigos e navios inimigos
  na água; para atingi-los precisamos de um míssil teleguiado que dá preferência a inimigos em solo, depois voando").
  Revisão 8 da Sim. `sea_submarine` (30 de vida, sobe do fundo, 2 torpedos lentos mirados `sub_torpedo`, 500 pontos) e
  `sea_warship` (70 de vida, leque de 5 + leque mirado de 3 agulhas `warship_fan`, 900 pontos, marcado, medalha) em
  `data/enemies.json` com `"layer": "sea"` e sem contato (`SimEnemy.sea`). Tiro, feixe, drones, estilhaço da arma
  (`Sim.splash`: Plasma, Ressaca, explosão do Titan) e poderes de anel, investida, feixe, raio, onda, orbes, aura e
  eclipse passam por cima; ferem o mar só mísseis teleguiados (secundária, lançador do mar, salvas dos poderes) e
  explosões de área (bomba, especial de área, explosões dos poderes). Lançador do mar: nas missões de água (ocean,
  atlantis, hadal) toda nave solta um par de mísseis de 5 a cada 1 s (`SecondaryFire.sea_launcher`; submarino em 3
  pares, navio em 7); com a secundária de mísseis ele não soma (ela já busca o mar primeiro, com mais dano por
  segundo); na luta de chefe só dispara com alvo no mar (as lutas ficam como foram medidas: ligado nelas, o bot perdia
  a c5m3a na semente 7). `Sim.nearest_target` e `Powers.strongest_target` buscam primeiro o mar no campo, depois o ar ou o chefe.
  Aviso: o sonar grave toca quando um deles aparece (`sea_contact`). `tools/gen_missions.py` (`add_sea`, sorteio
  próprio) põe 1 a 3 ondas do mar nas 16 missões de água, a cada 10 a 15 s, longe de chefes (22 s), objetivos e dos
  30 s finais; replays até a revisão 7 jogam sem elas, passo a passo. Bot: não mira no mar. Balanceamento (bot,
  sementes 7 e 11): as 16 fases de água vencidas, de 146 a 314 s. Testes em `tests/sea_tests.gd`. A arte e a
  caixa de colisão (`sea_submarine`, `sea_warship`) vêm de outra tarefa. Falta conferir no aparelho
- ✅ Pacotes de Pérolas com dinheiro real (pedido do dono: "coloque na loja pacotes de compras de moedas do jogo usando
  dinheiro real"; decidido: só Pérolas, a moeda dos cosméticos). Quatro consumíveis na Google Play em
  `Iap.PEARL_PACKS` (`pearls_100` US$ 0,99, `pearls_550` US$ 4,99 +10%, `pearls_1200` US$ 9,99 +20%, `pearls_2600`
  US$ 19,99 +30% e "Melhor valor"): base de 100 por dólar, US$ 4,99 = uma pintura de 400 e um tom; a pintura avulsa
  segue mais barata para uma pintura só. Crédito pelo caminho dos consumíveis (credita, grava, consome; token contra
  crédito em dobro; pendente e cancelado não creditam), sem contar como Pérola ganha. Loja: sub-aba "Pérolas" (grade
  2 colunas no retrato e 4 no PC, pilha que cresce de 3 pérolas a um baú, `tools/gen_pearl_packs.py`, "atlantis_generated"),
  aberta direto pelo "+" das Pérolas na barra do topo (`NavShell._pick_currency`). Steam e release sem plugin: nada.
  Textos nos 11 idiomas (`tools/i18n/command_iap.py`) e fichas da Play (`tools/i18n/play_products.py`);
  `tools/play_products.py` cria os quatro pela API (só `--dry-run` rodado). Testes em `tests/iap_tests.gd`. Falta
  👤 criar/ativar os produtos no Play Console (`python tools\play_products.py apply --only pearls_100,pearls_550,pearls_1200,pearls_2600`)
  e conferir no aparelho
- ✅ `1.30.0` Qualidade adaptativa, "Remover anúncios" e chefes de ato na faixa de tempo:
  (1) `FpsGuard` (`scripts/core/fps_guard.gd`, puro e testado em `tests/run_tests.gd`) liga o rebaixamento
  adaptativo de `GfxQuality` na partida real (modo "auto"): se o aparelho sustenta FPS bem abaixo do alvo
  (média de 90 quadros acima de 22 ms), rebaixa um nível uma vez, com aquecimento e cooldown, sem tocar a
  simulação; antes era código sem chamador. (2) Novo IAP `remove_ads` (US$ 2,99, não consumível): recebe as
  recompensas opcionais sem assistir ao anúncio, sem tema nem cosmético; some para quem já apoiou
  (`Store.ads_allowed`, `Iap.PRODUCTS`, `tools/play_products.py`, 11 idiomas, `tests/iap_tests.gd`).
  (3) Balanceamento (bot, semente 7): 6 chefes de ato (tidebreaker, coral_guardian, kraken_engine, storm_eye,
  forge, orbital_gate) trazidos para a faixa 90-150 s por `hp` em `data/bosses.json`; +14% de cadência no
  mid-boss do cap. 9 (`mid_protocol_sentinel`), ainda 0 perdidas; sky_leviathan mantido (as duas rotas
  compartilham hp e baixá-lo quebrava o Boss Rush). Falta 👤 criar/ativar `remove_ads` no Play Console e
  conferir no aparelho
- ✅ `1.31.0` Retenção — raridade nas bênçãos e revanche do chefe:
  (1) Raridade (comum/rara/épica) em `data/blessings.json` (21/7/2), mostrada na oferta com cor e rótulo
  (reusa `store.rarity_*` e `CommandKit.rarity_color`), brilho da revelação modulado pela raridade
  (respeita `reduce_motion`/`reduce_flashes`) e som por pitch (`game.gd`). O SORTEIO segue uniforme
  (`Sim.offer_blessings`): a raridade é flavor, não viés — um viés no sorteio deslocava o RNG e tankava os
  chefes (kraken 100→235 s no c2m3). Testes em `tests/sim_tests.gd`. (2) Revanche do chefe: na derrota em
  chefe de ato, botão "Enfrentar o chefe de novo" cai direto no chefe via `Modes.boss_only`, como prática,
  com a mesma carga (`results_screen.gd`, `app.gd`, `results.rematch` nos 11 idiomas, `tests/flow_tests.gd`)
- ✅ `1.32.0` Monetização — passe "Maré Dourada" vendável e mais cosméticos:
  (1) O passe deixou de ser só simulado: novo IAP não-consumível `season_gold` (US$ 4,99) liga a trilha
  dourada (`Season.state()` deriva premium de `Iap.owns`, desbloqueio único via `premium_forever`);
  `Season.buy_premium`→`Iap.buy`; a tela do passe usa o fluxo de compra com preço da Play. Só cosmético
  (as 3 pinturas da trilha, resgatadas jogando), nunca poder. Ficha da Play (`tools/play_products.py`),
  11 idiomas, testes em `iap_tests.gd`/`launch_tests.gd`; docs obsoletos ("só simulado") corrigidos. Falta
  👤 criar/ativar `season_gold` no Play Console. (2) +4 cosméticos só-Pérolas (tints Maré/Brasa/Vazio, paint
  Geleira): sumidouro de Pérolas 1.770→2.390 (+35%), economia conferida saudável (~5-8 semanas p/ completista,
  item avulso em dias), sem mexer nas taxas de ganho
- ✅ `1.33.0` Áudio reativo à Corrente + confirmações:
  (1) A música ganha intensidade com a Corrente de Maré (`sim.scoring.chain`): realce de presença que entra
  em x8 e chega ao pico em x16, voltando suave ao quebrar. Efeito high-shelf no bus "Music" (ganho 1.0/1.3/1.6),
  neutro e desligado no nível 0 (passthrough bit-exato), sem brigar com o volume das opções; não toca a Sim
  (`AudioManager.music_intensity_for`/`set_music_intensity`, ligado em `game.gd`, teste em `run_tests.gd`).
  (2) Masterização auditada (ffmpeg): todas as trilhas ~-14 LUFS (-13,9 a -15,35), picos ≤ -1 dBTP (nit:
  flow_tide_rising a -0,81), consistente — sem re-master. (3) Benchmark de partida (estresse 1.000 balas,
  nível 10, Alta): p95 7,95 ms (< 8 ms), 0 quadro > 33 ms — performance mantida, sem otimização necessária
- ✅ `1.33.1` Política de privacidade atualizada com os produtos novos: a enumeração de compras (resumo e
  detalhe, pt-BR e inglês) em `docs/store/privacy-policy.md` passou a listar "Remover anúncios" e o passe
  "Maré Dourada" (`season_gold`). As práticas de dados NÃO mudaram (mesma Play Billing, só a posse do produto;
  nenhum dado novo). HTML regerado (`docs/privacy/index.html`, `build_privacy_page.py --check` em dia). Site
  `netstart.github.io/atlantis/` sincronizado com o mesmo conteúdo
- ✅ `1.34.0` Moeda de ouro (créditos) redesenhada (pedido do dono: "muito feia, sem brilho ou efeito"): o
  ícone da carteira era um disco chapado (aro, um borrão de luz e um anel). Agora é uma moeda premium
  desenhada por SDF na textura de 64 px (`ListScreen._icon_pixel` &"credits"): aro biselado (claro em cima
  à esquerda, escuro embaixo à direita), disco com volume (degradê vertical + oclusão junto ao aro + realce
  pela direção da luz), brilho especular com faísca de 4 pontas e o **tridente de Atlântida** gravado em
  relevo (`_credits_mark`). Sem custo de runtime (ícone gerado uma vez e cacheado), herdado por toda a UI que
  mostra créditos (carteira, oficina, baús, eventos). Conferido em engine (render headless bate com o
  protótipo).
- ✅ `1.35.0` Venda de moedas de ouro (créditos) por dinheiro real (decisão do dono: "Sim, vender créditos",
  revertendo o "sem pay-to-win"). Quatro pacotes consumíveis `credits_<total>` (`CREDIT_PACKS` em
  `scripts/core/iap.gd`): 2.000 (US$ 0,99), 11.000 (US$ 4,99 +10%), 24.000 (US$ 9,99 +20%), 52.000 (US$ 19,99
  +30%, "Melhor valor") — base de 2.000 créditos/dólar, a mesma estrutura dos pacotes de Pérolas. Ao contrário das
  Pérolas, os créditos DÃO progressão (sobem o nível da nave: casco e dano); comprados vão só para a carteira, não
  contam como ganhos jogando (`earned`). Crédito uma vez por token (pendente e cancelado não creditam), Steam e
  release sem plugin não vendem. Loja: sub-aba "Ouro" com a grade de cartões (arte própria `tools/gen_credit_packs.py`
  → `coins_<n>.png`: pilhas de moedas com o tridente), aberta pelo "+" da moeda de créditos na barra do topo.
  Produtos da Play em `tools/play_products.py` (lê `CREDIT_PACKS`). Honestidade alinhada: plano mestre, textos da
  loja, `store.credits_note` e a política de privacidade (docs e site) dizem que os créditos sobem o nível da nave e
  também saem jogando; removidas as afirmações gerais de "nenhuma compra vende poder / sem pay-to-win" (as notas por
  produto — Pérolas só cosmético, Apoiar sem poder — seguem verdadeiras). Testes: `iap_tests._credits`
- ✅ `1.35.1` CI sem testes (pedido do dono): o workflow `.github/workflows/android-play.yml` perdeu o job `checks`
  (que rodava `tools/run_checks.ps1`) e o gatilho de `pull_request`; o job `release` agora baixa o Godot sozinho
  (cache + download, não depende mais do job de checagens). O CI só assina o AAB e publica na Play. Regra registrada
  no `AGENTS.md` ("Testes e CI"): os testes rodam só na máquina do desenvolvedor, antes de cada push.
- ✅ `1.36.0` Ranking mundial de abates (Google Play Games Services): plugin
  `GodotPlayGameServices` 3.4.0 (`play-services-games-v2` 21.0.0, com o patch `loadTopScores100`, portado do hyakki;
  licenças do plugin, do SDK e do Gson registradas). Ordena pelo total de abates da carreira (`stats.kills`) e, no
  empate, pelo menor tempo jogado (`stats.time_played`), num inteiro só (`scripts/core/kill_ranking.gd`). Ponte
  `scripts/autoload/play_ranking.gd` (login, envio depois de cada resultado gravado e ao entrar, 100 melhores) e tela
  "Ranking de abates" (`ranking_screen.gd`; entra por Recordes e por Opções): posição, nome do Play Games, abates e
  tempo (`12h 05m`), ouro/prata/bronze, a linha do jogador em menta, estados "só no Android", indisponível, entrar,
  carregando, sem conexão e vazio; rola por toque, teclado e controle. IDs em `project.godot` (`[play_games]`),
  **vazios**: sem `game_id` o plugin de exportação não põe nada do Play Games no build. Permissões `INTERNET` e
  `ACCESS_NETWORK_STATE` nos dois presets Android. Testes: `tests/ranking_tests.gd` (regras) e
  `tests/ranking_view_tests.gd` (estados e layout com 100 linhas em todas as resoluções e idiomas). Falta 👤 criar o
  projeto do Play Games, as credenciais OAuth e o placar e colar os dois IDs (`docs/store/play-console.md`, "Play
  Games Services e ranking") e atualizar "Segurança dos dados". Política de privacidade 1.8 já cita o ranking.
- ✅ `1.36.0` Co-op em rede local (LAN/Wi-Fi), 2 aparelhos, sala por código: modo `coop_lan`
  em todas as plataformas (inclusive Android), aberto pela mesma regra do co-op local (1-3), com a corrida do Arcade.
  Sala (`scripts/net/lan_room.gd`, `lan_session.gd`, `net_link.gd`, adaptados do hyakki; tela `lan_screen.gd`, aberta
  pelo banner nos Eventos): o anfitrião abre e mostra um código de 4 dígitos sorteado; a convidada digita no teclado
  numérico da tela e acha a sala por busca UDP na rede local (broadcast e varredura do /24), só endereços privados,
  ENet confiável, máximo 2 aparelhos. Aperto de mão com protocolo, versão do jogo e `SimRevision`. Partida em
  **lockstep de entradas** (atraso de 3 passos, entrada nos campos do replay em 25 bytes, a mesma quantização nos dois
  lados): o anfitrião é a nave 1, a convidada a ala; fila, semente, carga, sensibilidade 1 e a menor altura de campo
  das duas telas vêm do pacote de início. Sem a entrada da parceira a Sim espera ("Esperando o parceiro…" depois de
  0,5 s); pausa avisada ("Parceiro pausou"); `SimHash` trocado a cada 60 passos (diferença, saída ou queda de 5 s
  encerram nos dois com aviso e voltam à sala, sem gravar resultado). Especial, PODER, Maré Alta, toques do duelo e a
  escolha da bênção valem de qualquer das duas naves (`SimInput.merged`); sem reviver por anúncio, sem placar nem
  replay (como o co-op local). **Balanceamento do co-op (local e LAN)**: vida ×1,7 nos inimigos comuns e ×1,8 nos
  chefes (`SimCurve.COOP_HP`, `COOP_BOSS_HP`), a mesma quantidade, cadência e velocidade de balas do solo, e a bala
  mirada procura a nave mais perto (`SimCurve.target`); medido com `tests/boss_timing.gd --coop` (9 missões do Arcade
  × 3 sementes: fase +3%, chefes de meio −5%, chefes finais +11% contra o solo). O solo não muda (mesmos hashes; a
  `SimRevision` continua 10). Testes: `tests/lan_tests.gd` (sala, codificação, fator de coop e duas sessões com duas
  Sims em 127.0.0.1 com latência e perda) e `tests/lan_screen_tests.gd` (layout de cada estado da sala em todas as
  resoluções e idiomas, e dois Apps jogando pelo Game até o resultado). Falta 👤 testar em dois aparelhos de
  verdade no mesmo Wi-Fi (Android + Android e Android + PC). Política de privacidade 1.8 já cita a rede local.
- ✅ `1.36.1` Co-op LAN corrigido e testes mais rápidos: o adeus do fim da corrida não derruba mais a parceira que
  está uns passos atrás (termina a missão com as entradas já recebidas e grava o resultado); a busca da sala varre
  primeiro a placa real (Wi-Fi) e deixa as virtuais (WSL, Hyper-V, VirtualBox, VPN) para o fim. `run_checks` de ~281 s
  para ~246 s com as mesmas verificações (campanha da economia em 3 trechos paralelos, pesos das fatias em segundos
  medidos, regras em 4 fatias e integração em 8).
- ✅ `1.37.0` Ranking de abates ligado: `project.godot` `[play_games]` com `game_id="1046588535122"` e
  `leaderboard_id="CgkI0uKm7LoeEAIQAA"` (placar "Kill ranking", en-US; clientes OAuth Android da chave de assinatura
  do app e da chave de upload no projeto do Cloud `atlantis-ascension`). O SDK do Play Games entra só nos builds
  Android. Falta 👤 os testadores, publicar o projeto do Play Games e atualizar "Segurança dos dados"
  (`docs/store/play-console.md`, "Play Games Services e ranking").
