# Plano: montar o plano de implementação de ATLANTIS ASCENSION em `.ai/`

> Plano aprovado em 30/10/2026 e executado. Mudanças feitas durante a execução, que valem sobre o texto abaixo:
>
> - **Área de jogo:** 270x450 (não 270x480), para caber na tela 270x480 com o recorte da câmera.
> - **Desktop:** regra `k = floor(altura / 540)`; resoluções lógicas 960x540, 1280x720 e 1280x800 (Steam Deck).
>   As linhas 640x360 e 640x400 deste plano estavam erradas: deixariam a área de jogo baixa demais.
> - **Parallax no mapa** (pedido do usuário): mapa "Carta da Ascensão" com 6 camadas, seção 7.3 do plano mestre.
> - **Pesquisa de jogos semelhantes** (pedido do usuário): `.ai/04-pesquisa-mercado-e-retencao.md` e seção 19 do
>   plano mestre.
> - **CLAUDE.md:** o Windows negou o link simbólico; o arquivo importa o `AGENTS.md` com `@AGENTS.md`.

## Contexto

O repositório está vazio (só `LICENSE` MIT e `.ai/` com `prompt.md` e `atlantis_ascension_conceito_jogo.md`).
O prompt pede um plano completo de implementação de um shoot'em up 2.5D para Godot/Android (Play Store e
Steam), só com assets gratuitos de uso comercial, SemVer, e a governança do projeto **hyakki**
(`AGENTS.md`) copiada e dividida em arquivos referenciados.

Decisões tomadas com o usuário nesta sessão:

| Decisão | Escolha |
|---|---|
| Orientação | **Retrato** (vertical). Steam: janela paisagem com playfield 9:16 central e painéis laterais. |
| Técnica 2.5D | **Sprites 2D + profundidade simulada** (parallax em camadas, escala/blur por profundidade, inimigos entrando "do fundo"). Sem renderer 3D. |
| Monetização v1 | **Grátis + anúncio recompensado + cosméticos** (modelo do hyakki). Steam: premium sem anúncios. Vertical Slice sem monetização. |
| Menu | **Hub interativo estilo *Star Wars: Galaxy of Heroes*** (cena viva, abas inferiores, carrossel de banners, cartões horizontais, transições animadas). Detalhe na seção 7. Hub mínimo já no Vertical Slice; completo no Alpha. |

Fatos levantados na pesquisa (usar no plano, não re-pesquisar):

- **hyakki** (`github.com/netstart/hyakki`): Godot **4.7.2 stable** em `C:\src\tools\godot\Godot_v4.7.2-stable_win64_console.exe`
  (não existe nesta máquina; nem Python gdtoolkit, Android SDK, Java ou Blender). Estrutura: `scripts/autoload/*`
  (Events, GameClock, PixelScaler, Settings, SaveManager, DB, Locale, AudioManager, AdsManager, PurchaseManager,
  ShopManager), `data/*.json`, `i18n/strings.csv` (11 idiomas), `tests/run_tests.gd` (SceneTree headless),
  `tests/integration_tests.tscn`, `tests/device_profiles.gd` (fonte única das resoluções), `tests/scroll_bench.tscn`,
  `tests/game_bench.tscn`, `tools/run_checks.ps1`, `tools/check_licenses.py`, `tools/build_license_index.py`,
  `tools/sync_assets.py` (zips ficam fora do repo; só arquivos usados entram em `assets/`), `licenses/registry.json`
  + `texts/` + `notices/`, `CREDITS.md`, `ASSET_LICENSES.md`, `gdlintrc`, `.ai/01-…-game-plan.md` (18 seções) e
  `.ai/03-progresso-implementacao.md`. PixelScaler: `k = min(round(altura/300), floor(largura/480))`, k ≥ 1, stretch viewport.
- **AGENTS.md do hyakki** (texto completo obtido): seções "Padrão de Excelência Profissional", "Política de licença"
  (lista permitida MIT, Apache-2.0, CC0-1.0, OFL-1.1, CC-BY-4.0; processo de 8 passos), "Tela de créditos",
  "Política de testes automatizados" (tabela de 15 resoluções lógicas; testes por resolução só no Godot; emulador só
  manual; benchmark p95 ≤ 6 ms, nenhum quadro > 33 ms; regras de desenho), "Versionamento (SemVer em todo commit)".
- **Catálogo** `github.com/netstart/awsome-free-assets-to-games` (sem README; conteúdo em `assets/*.md`). Achados
  relevantes com licença verificada no catálogo: Foozle **Void** series (Main Ship CC0 confirmado, Fleet Pack 2 Nairan
  CC0 confirmado, Fleet Pack 1 Kla'ed e 3 Nautolan a confirmar na página, Void Environment Pack CC0, Void Pickups
  a confirmar); Kenney **Pixel Shmup**, Space Shooter Redux/Extension, Simple Space, Planets, Background Elements,
  Particle Pack, Smoke Particles, UI Pack Sci-fi, Game Icons, Input Prompts, Kenney Fonts, Sci-fi Sounds, Impact
  Sounds, Interface Sounds, Digital Audio, Music Jingles (todos CC0); ansimuz *Space Ship Shooter Pixel Art Assets* e
  *Warped Caves* (CC0, OpenGameArt); Screaming Brain *Planet Surface Backgrounds/Skyboxes* e *3 Layer Parallax Star
  and Nebula Field* (CC0); *Ocean Creatures* (michael-jay-rov, CC BY 4.0); música: albesca *Outer Space Music Pack*
  (CC0), HydroGene *8-bit Epic Space Shooter Music* (CC0), *Space Shooter (Loop)* (CC0), *Boss Battle Music* /
  *Battle Music* / *Massive Battle* / *War Theme* (CC0, OGA), Matthew Pablo *Space Dimensions* (CC BY 3.0); fonte
  Fusion Pixel (OFL, 11 idiomas, já usada no hyakki), Orbitron (OFL) para display.
- O link do ChatGPT (`chatgpt.com/share/6ae48f70…`) não é legível por ferramenta (página só com título). A fonte da
  história é `.ai/atlantis_ascension_conceito_jogo.md`, que já é o export desse conceito. Registrar isso no plano.

## Escopo desta execução

**Entregar documentação e governança, não código do jogo.** Depois de aprovado, criar:

1. `.ai/01-atlantis-ascension-game-plan.md` — plano mestre (GDD + implementação), ~18 seções, modelo do hyakki.
2. `.ai/02-catalogo-assets-licencas.md` — catálogo de assets por necessidade do jogo, com URL, autor, licença,
   status de verificação, destino em `c:\src\downloads\assets\<fonte>\` e o que **criar** por não existir.
3. `.ai/03-progresso-implementacao.md` — checklist vazio por fase, mesmo formato do hyakki.
4. `AGENTS.md` — índice curto: excelência profissional + papéis simultâneos + links para as políticas + fatos do
   projeto (engine, orientação, pastas, comandos).
5. `docs/policies/licencas.md`, `docs/policies/testes.md`, `docs/policies/qualidade.md`,
   `docs/policies/versionamento.md` — as seções do AGENTS.md do hyakki, cada uma em seu arquivo, adaptadas
   (retrato, shmup, Steam). Regras de qualidade e política de testes ficam separadas e referenciadas, como pedido.
6. `CLAUDE.md` → link simbólico para `AGENTS.md` (`cmd /c mklink CLAUDE.md AGENTS.md`; exige Modo Desenvolvedor ou
   admin no Windows; se falhar, avisar e deixar `CLAUDE.md` com uma linha "Siga AGENTS.md" até o usuário criar o link).
7. `README.md` — 20 linhas: o que é, como rodar, links para `.ai/` e políticas.

Não fazer agora: baixar assets, criar `project.godot`, instalar Godot. Isso é a Fase 0 do roadmap dentro do plano.

## Conteúdo do `.ai/01-atlantis-ascension-game-plan.md`

Cabeçalho em tabela (gênero, engine Godot 4.7.2 GDScript Compatibility/GLES3, plataforma Android retrato +
Steam Windows/Linux, arte base Foozle Void + Kenney CC0, política de assets, data 30/10/2026) e sumário.

0. **Resumo executivo** — pitch, por que a série Void (um só estilo pixel coerente, CC0, 3 facções = 3 linhagens
   de inimigos), diferenciais (Ocean Shift, Gravity Breach, chefes em etapas, campanha com mistério), escopo 1.0,
   estimativa 1 dev meio período ~28–32 semanas, protótipo jogável na semana 3.
1. **Pesquisa das referências** — Galaxy Attack: Space Shooter (ONEMT/ABI: toque-arrasta, tiro automático, power-ups
   trocam arma, 160+ níveis, chefes, skills ativas, queixa de grind e anúncios), Atlantis Invaders (estética
   oceânica), Wing Fighter (frota/evolução de caça, ala auxiliares), Falcon Squad (retenção: eventos, naves
   colecionáveis, modos), Raiden (padrões legíveis, rank dinâmico, bomba). Tabela "o que levamos / o que evitamos".
   Pilares derivados: um polegar move, tiro automático, leitura de projéteis acima de tudo, sessão de 2–5 min,
   poder perceptível por nível de arma, chefes como espetáculo.
2. **Conceito** — reescrita executável do conceito (`atlantis_ascension_conceito_jogo.md`), loop principal, controles
   (arrastar relativo com offset do dedo, dead zone, botão especial, auto-tiro, opção de toque para bomba),
   acessibilidade.
3. **Narrativa e mundo** — premissa 2147 / Heart of Poseidon / Leviathan Protocol, prólogo + 4 atos, 3 personagens
   falantes (piloto, oficial de ciência, voz atlante), registros coletáveis, chefes com apresentação, 2 finais.
   Formato de entrega: falas curtas em `data/dialogue.json`, cenas entre missões com 3–5 quadros.
4. **Game design (sistemas)** — 7 armas × 3 níveis (tabela de dano/cadência/padrão por nível), 12 aeronaves do
   conceito com perfil (6 na 1.0, 6 pós-lançamento), habilidade de recarga por nave, power-ups e drops, vidas/
   escudo/HP, pontuação e multiplicador por "graze", bomba, Ocean Shift (script de fase), Gravity Breach (campo de
   força sobre projéteis), rank dinâmico leve, dificuldade (Normal/Veterano/Abissal), economia (créditos, cristais
   cosméticos), progressão permanente (hangar), desafios diários, modo sobrevivência, ranking local.
5. **Level design** — 9 capítulos × 3 missões (27) na 1.0; estrutura de missão (ondas em JSON: formação, timing,
   trajetória, drops), 1 mini-chefe por missão, chefe de ato; tabela por capítulo (ambiente, regra nova, inimigos,
   perigo ambiental, trilha). Duração-alvo 2–5 min.
6. **Bestiário e chefes** — ~24 inimigos (8 por facção Kla'ed/Nairan/Nautolan reinterpretados como drones oceânicos,
   caças atlantes, criaturas biomecânicas), comportamento e padrão de tiro; 4 chefes de ato (Kraken Engine, Sky
   Leviathan, Poseidon Prime, Leviathan Protocol) com máquina de estados por etapa, pontos fracos, arena; chefes
   montados por **partes modulares** (sprites Void + Ocean Creatures + tentáculos como cadeias segmentadas por código).
7. **UI/UX (retrato)** — **Menu interativo estilo *Star Wars: Galaxy of Heroes*** (pedido do usuário): a tela
   inicial é um **hub vivo**, não uma lista de botões. Referência SWGoH a reproduzir (sem copiar arte/nomes):
   cena de fundo animada em parallax (hangar atlante com a nave atual em exibição, água/energia em movimento,
   tripulação/drones idle) que reage ao toque (tocar/arrastar a nave gira e inspeciona, tocar o fundo dispara
   efeito); **barra de abas inferior** (Hangar · Campanha · Naves · Eventos · Loja) com badges de notificação;
   **carrossel horizontal de banners** no topo (eventos por tempo, desafio diário, novidades) com arrasto e
   auto-rolagem; **cartões grandes roláveis na horizontal** para naves e capítulos (cartão selecionado cresce e
   mostra a nave animada, atributos e botão de ação); painéis de recompensa que abrem com animação (baú/caixa,
   contagem de moedas); **transições animadas** entre telas (deslizar/zoom na cena, 150–250 ms, interrompíveis);
   feedback em todo toque (escala + SFX de interface Kenney + vibração leve). Telas: consentimento, título/hub,
   hangar (naves/armas/cosméticos), capítulos (mapa do oceano à órbita com nós e progresso), HUD (vida, bomba,
   especial, pontos, nível de arma), pausa, resultado, loja, eventos, créditos/licenças, opções, diálogos. Área segura
   (furo de câmera em cima/embaixo no retrato), zona do polegar, 11 idiomas (pt-BR, en, es, de, fr, ru, id, ja, ko,
   zh-TW, zh-CN) com Fusion Pixel; Steam: playfield central + painéis laterais com pontuação/arte, teclado/controle,
   hub navegável por mouse e controle (foco visível). Regras técnicas do hub: cena de fundo em camada própria a
   30 Hz, cartões assados (`StaticBake`), carrosséis via `TouchScroll`, animações decorativas pausam durante o
   arrasto, nenhum `draw_polygon` por quadro; o hub entra no benchmark de rolagem (horizontal e vertical) e nos
   testes de layout em todas as resoluções.
8. **Direção de arte e technical art** — paleta do conceito, resolução lógica base 305×678 (sprites Void 48–64 px),
   profundidade 2.5D: 5 camadas parallax (céu/oceano/ruínas/nuvens/espuma), inimigos "do fundo" com escala 0,6→1,0 e
   tint, shaders (água caustics, energia atlante, distorção da Gravity Breach, scanline opcional), regras de desenho
   do hyakki (sem `draw_polygon` por quadro, `StaticBake`, MultiMesh para balas), paleta unificada por shader de
   tint para casar packs diferentes.
9. **Áudio** — tabela trilha por capítulo (faixas CC0 listadas), SFX por categoria (Kenney Sci-fi/Impact/Interface/
   Digital), ducking, pool, diferenciação tiro próprio × inimigo.
10. **Arquitetura técnica (Godot 4.7.2)** — autoloads do hyakki; simulação em passo fixo determinística (`GameClock`,
    semente, bot para testes, velocidade 1x/2x/3x com hash de estado); `BulletPool` em `MultiMeshInstance2D` +
    `SpatialHash`; dados em JSON (`data/weapons.json`, `ships.json`, `enemies.json`, `waves/*.json`, `bosses/*.json`,
    `dialogue.json`); DSL de padrão de tiro (anel, leque, espiral, mira, laser) interpretada por `PatternRunner`;
    `StageScript` (eventos: onda, Ocean Shift, Gravity Breach, diálogo, mini-chefe); save com migração; estrutura de
    pastas; adaptação do PixelScaler ao retrato (`k = min(round(largura/300), floor(altura/480))`, mesmo k das telas do
    hyakki giradas; no desktop paisagem a regra dá 960×540 em 1080p e o playfield 9:16 fica central).
11. **Android, Steam e dispositivos** — export Android (arm64 + x86_64, gradle, imersivo, retrato sensor),
    Steam via GodotSteam (MIT) + Steamworks SDK (licença própria, registrada como `LicenseRef-Steamworks`),
    conquistas, cloud save, Steam Deck 1280×800; teste manual no emulador apenas.
12. **Assets e licenças** — resumo e link para `02-catalogo-assets-licencas.md`; política igual ao hyakki com
    **adição de CC-BY-3.0 e OGA-BY-3.0 à lista permitida** (permissivas, exigem crédito) — marcar como decisão a
    ratificar pelo usuário; "o que não existe, criar" (lista em 02).
13. **Roadmap** — Fase 0 ferramentas (Godot 4.7.2 em `C:\src\tools\godot`, gdtoolkit, Android SDK, JDK 17,
    `project.godot`, export presets, `run_checks.ps1`); Fase 1 **Vertical Slice** (1 nave, capítulo 1 missão 1
    completa, 3 inimigos, mini-chefe, Kraken Engine 3 etapas, 3 armas, HUD, resultado, SFX, trilha, APK) — semanas
    1–6; Fase 2 **Alpha** (3 capítulos, 4 naves, hangar, economia, 11 idiomas, save) — semanas 7–14; Fase 3 **Beta**
    (9 capítulos, 4 chefes, 6 naves, tutorial, acessibilidade, otimização, monetização simulada, Steam build) —
    semanas 15–24; Fase 4 **Lançamento** (Play Console, AdMob/UMP, Billing, Steamworks, loja, política de
    privacidade, screenshots) — semanas 25–30; pós-lançamento (6 naves, modos, eventos). Cada fase com critério de
    pronto e versão SemVer alvo (0.1.0 VS, 0.5.0 Alpha, 0.9.0 Beta, 1.0.0).
14. **Plano de testes** — unitários (regras puras), integração (dados, idiomas, fontes), layout em **todas as
    resoluções** de `tests/device_profiles.gd` com recorte em cima e embaixo, benchmark de rolagem, benchmark de
    partida (1.000 balas + 150 inimigos a 60 fps na qualidade Alta), determinismo (hash igual em 1x/2x/3x),
    teste de créditos, `check_licenses.py`, `gdlint`; tudo só no Godot do PC; emulador só manual.
15. **Critérios de qualidade** — código (GDScript tipado, gdlint, arquivos ≤ 1200 linhas), jogabilidade (input
    latency, leitura de projéteis: nenhuma bala com contraste < 4,5:1 sobre o fundo), balanceamento (tabela de
    metas: morte média, tempo de chefe), diversão (playtest), som.
16. **Riscos e mitigação** — colcha de retalhos visual (tint unificado, 1 pack base), performance de balas,
    licenças a confirmar (Fleet 1/3, Pickups), ausência de toolchain local, políticas da Play (anúncios, idade),
    Steam Deck.
17. **Monetização** — rewarded opcional (reviver 1×, dobrar créditos, cristais a cada 6 h), cosméticos (skins,
    rastros de tiro, temas de HUD), compra única "apoiar/sem anúncios", nenhum anúncio durante a missão, Steam
    premium sem anúncios com os cosméticos inclusos; conformidade (UMP/consentimento, família).
18. **Apêndices** — fórmulas (dano, pontuação, rank, curva de HP por capítulo), tabela de resoluções, template de
    onda JSON, template de chefe JSON, DSL de padrões.

## Conteúdo do `.ai/02-catalogo-assets-licencas.md`

Tabelas por necessidade (nave do jogador, inimigos por facção, chefes, projéteis, VFX, fundos por capítulo, UI,
ícones, fontes, SFX, música por capítulo): asset, autor, URL, licença, verificação (✅ confirmada na página /
⚠️ confirmar ao baixar), destino `c:\src\downloads\assets\<fonte>\<pack>.zip`, uso no jogo. Seção "Criar" (chefes
modulares, ruínas atlantes a partir de Simple Space + tint, caustics/energia por shader, ícones de arma faltantes,
retratos dos 3 personagens — opção: SakPix *Galaxy Legacy* portraits, licença custom a confirmar), e seção
"Rejeitados" (CraftPix freebies, xyezawr, disruptorart etc.: custom "não revender" fora da lista permitida; ansimuz
itch sem licença declarada; GPL/NC/ND). Processo de entrada = `docs/policies/licencas.md`.

## Conteúdo de `docs/policies/*.md` (adaptações ao copiar do hyakki)

- `licencas.md`: texto do hyakki + lista permitida com CC-BY-3.0/OGA-BY-3.0 (marcadas "a ratificar"); caminhos
  iguais (`licenses/registry.json`, `tools/check_licenses.py`, `tools/build_license_index.py`, `CREDITS.md`, tela de
  créditos `scripts/app/screens/credits_screen.gd`).
- `testes.md`: texto do hyakki com a **tabela transposta para retrato** (mesmos 15 aparelhos e fatores; lógica =
  física girada / k): 305×678 (1220×2712 ×4, Redmi Note 14 Pro+), 270×600 (1080×2400 ×4, Galaxy M55 / Pixel 7),
  270×585 (1080×2340 ×4, A15 / A56 / POCO M3 / S24-S25 Ultra FHD+), 288×624 (1440×3120 ×5, S24/S25 Ultra QHD+),
  360×780 (720×1560 ×2, S24/S25 Ultra HD+), 270×480 (1080×1920 ×4, 16:9), 320×512 (1600×2560 ×5, Tab S9),
  300×500 (1200×2000 ×4, Tab A9+), 384×512 (1536×2048 ×4, tablets 4:3), 360×800 (720×1600 ×2, A05 / Moto E13),
  360×806 (720×1612 ×2, Moto G04 / Redmi A3), 453×544 (1812×2176 ×4, Z Fold aberto), 301×772 (904×2316 ×3, Z Fold
  fechado), 270×630 (1080×2520 ×4, Xperia), 270×660 (1080×2640 ×4, 22:9); **mais linhas desktop/Steam** em paisagem:
  960×540 (1920×1080 ×2), 1280×720 (2560×1440 ×2), 640×360 (1280×720 ×2), 640×400 (1280×800 ×2, Steam Deck).
  Recorte da câmera no retrato fica em cima (e embaixo no giro de 180°). Benchmarks: rolagem (hub com carrossel
  de banners e cartões horizontais, hangar, capítulos, naves, eventos, loja, créditos, opções; piparotes e arrasto
  lento nos dois eixos), partida (`-- --bot --seed=7 --stress=1000`), p95 ≤ 6 ms, nenhum quadro > 33 ms.
- `qualidade.md`: Padrão de Excelência + regras de código (gdlint, tipagem, regras de desenho do hyakki, limites de
  arquivo), definição de pronto por tarefa.
- `versionamento.md`: SemVer do hyakki sem alteração (4 lugares: `project.godot`, `export_presets.cfg` ×2 campos
  em todos os presets, inclusive os de Windows/Linux para Steam).

## Arquivos a criar (resumo)

```
AGENTS.md
CLAUDE.md  (symlink -> AGENTS.md)
README.md
docs/policies/licencas.md
docs/policies/testes.md
docs/policies/qualidade.md
docs/policies/versionamento.md
.ai/01-atlantis-ascension-game-plan.md
.ai/02-catalogo-assets-licencas.md
.ai/03-progresso-implementacao.md
```

Tudo em português (pt-BR), prosa normal, Markdown com tabelas; sem código de jogo além de templates JSON e trechos
ilustrativos de GDScript nos apêndices.

## Verificação

1. Cada link interno do `AGENTS.md` e dos `.ai/*.md` resolve para um arquivo existente (`grep -o '\](\S*\.md' | sort -u` e `Test-Path`).
2. `CLAUDE.md` é link simbólico (`(Get-Item CLAUDE.md).LinkType -eq 'SymbolicLink'`); se não for, está registrado no recap.
3. Tabela de resoluções em `docs/policies/testes.md` tem as 15 linhas do hyakki (transpostas) + 4 de desktop, e
   cada linha satisfaz `k = min(round(largura/300), floor(altura/480))` (conferir manualmente em 3 linhas: 1220×2712→4,
   1536×2048→4, 1920×1080→2).
4. Toda URL do catálogo em `02` foi obtida do catálogo/pesquisa desta sessão; itens não confirmados estão marcados ⚠️.
5. O plano menciona que o link do ChatGPT não foi acessível e que a fonte narrativa é o `.md` de conceito.
6. `git status` mostra só arquivos novos; nenhum commit (o usuário não pediu).
