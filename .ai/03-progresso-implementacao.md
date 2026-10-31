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
- ⬜ Próximo passo: Fase 3 (Beta).

## Decisões pendentes do mantenedor

- ⬜ Ratificar CC-BY-3.0 e OGA-BY-3.0 na lista de licenças.
- ✅ Licenças de Void Fleet Pack 1, Fleet Pack 3 e Pickups Pack: CC0 e "No generative AI was used" nas páginas
  (snapshots em `docs/licenses/`, 30/10/2026).
- ⬜ Retratos: criar ou usar o pack SakPix (licença custom).
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
- ⬜ Benchmark de rolagem (`tests/scroll_bench.tscn`): entra com a primeira lista longa (hub e mapa, Fase 1)

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

- ⬜ Capítulos 4 a 9, Sky Leviathan, Poseidon Prime, Leviathan Protocol (que aprende), 3 finais
- ⬜ 7 rotas de Abismo, Glifos, 4 missões secretas
- ⬜ Resgate de cápsulas com combo, distritos da Cidade de Thalassa
- ⬜ 6 aeronaves, 12 alas, 6 especiais, captura biomecânica
- ⬜ Gravity Breach com Redemoinho, todos os perigos
- ⬜ Chefe que lembra, Kraken remendado
- ⬜ Arcade, Boss Rush, Desafio Diário, Sobrevivência, Prática
- ⬜ Login de 7 dias, diárias e semanais, Núcleo de Oricalco
- ⬜ Tutorial, acessibilidade, daltonismo, qualidade gráfica
- ⬜ Otimização: 60 fps em aparelho de entrada na Média
- ⬜ Monetização simulada (Loja, 6 h, reviver, dobrar)
- ⬜ Build Steam com GodotSteam

## Fase 4 — Lançamento · `1.0.0`

- ⬜ Segunda Maré, Fantasma do Abismo, placares com replay, Correntes semanais, passe, modo foto
- ⬜ Play Console, teste fechado (20 testadores por 14 dias), AdMob com UMP, Play Billing
- ⬜ Steam: página, conquistas, placares, Cloud, Deck Verified
- ⬜ Política de privacidade, `app-ads.txt`, créditos públicos
- ⬜ Revisão de traduções por nativos
- ⬜ Critérios: aprovado nas duas lojas, crash-free ≥ 99,5%, D1 ≥ 40% no teste fechado
