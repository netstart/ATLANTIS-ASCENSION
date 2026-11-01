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
  placares, passe, conquistas, modo foto e documentos de loja. O que depende de contas e contratos (Play Console,
  AdMob, Billing, Steamworks, Android SDK) está em `docs/store/release-checklist.md`.
  `tools/run_checks.ps1`: `TUDO OK` (892 verificações de regras, 71.619 de integração, layout e fluxo, 609 textos x
  11 idiomas, 21 componentes de licença e 169 arquivos, mesmo hash em 1x/2x/3x/Baixa). Benchmarks: partida com
  1.000 balas p95 2,2 ms (pior 3,2 ms); rolagem 72/72 listas aprovadas.
- ✅ Pós-lançamento em andamento sem depender de contas: ver a seção no fim.
- ⬜ Lojas: o mantenedor executa o checklist de lançamento (contas, licenças, teste fechado).

## Decisões pendentes do mantenedor

- ⬜ Ratificar CC-BY-3.0 e OGA-BY-3.0 na lista de licenças.
- ✅ Licenças de Void Fleet Pack 1, Fleet Pack 3 e Pickups Pack: CC0 e "No generative AI was used" nas páginas
  (snapshots em `docs/licenses/`, 30/10/2026).
- ✅ Retratos: criados pelo projeto (`tools/gen_portraits.py`, MIT), sem o pack SakPix.
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
  incluso. ⚠️ AdMob/UMP e Play Billing reais na Fase 4
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
- ✅ Modo foto do mapa (esconde a interface, salva PNG em `user://photos/`)
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
