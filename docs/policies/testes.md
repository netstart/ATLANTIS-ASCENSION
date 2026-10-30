# Política de testes automatizados

> Referenciado por [AGENTS.md](../../AGENTS.md). Origem: seção "Política de testes automatizados" do `AGENTS.md` do
> projeto [hyakki](https://github.com/netstart/hyakki/blob/main/AGENTS.md). As resoluções e os aparelhos são os
> mesmos do hyakki, **transpostos para retrato**, mais as resoluções de desktop e Steam Deck.
> **Obrigatório para qualquer contribuição.**

**Tudo neste jogo precisa ter testes automatizados.** Qualquer código, feature, sistema ou comportamento adicionado
ao repositório deve ser coberto por:

1. **Testes unitários**: rápidos e isolados (regras puras em GDScript), executados dentro do Godot pela suíte do
   projeto (`tests/run_tests.gd`, headless, sem autoloads).
2. **Testes de integração**: dados, idiomas, fontes, save, economia e telas (`tests/integration_tests.tscn`).
3. **Testes end-to-end (E2E)**: fluxos completos do jogo (partida do bot, missão inteira com chefe, hub, hangar,
   telas em sequência), executados **só no Godot** do PC, em cada resolução-alvo abaixo.

## Testes por resolução só no Godot; emulador Android só para teste manual

Os testes que simulam a tela dos aparelhos rodam **apenas no Godot** do PC: runners headless ou com janela que leem
`tests/device_profiles.gd` (layout de cada tela, painel, hub e HUD), `tests/scroll_bench.tscn`, os testes de
desempenho (`tests/perf_tests.gd`, `tests/game_bench.tscn`) e o `tools/run_checks.ps1`.

**É proibido executar testes automatizados no emulador Android** (roteiro E2E, AVDs de teste, `adb input`, medição
de quadros ou qualquer script que instale, toque e confira sozinho). O emulador, o Steam Deck e o aparelho físico
servem só para **teste manual**: uma pessoa instala, joga e confere (`Testar no emulador.bat`,
`Testar release no emulador.bat`). Não crie script, roteiro nem critério de aprovação que rode no emulador.

## Resoluções-alvo

A regra de qualidade é **por resolução lógica**, não por aparelho. O jogo escala a tela por um fator inteiro `k`
(`scripts/autoload/pixel_scaler.gd`), sempre `k ≥ 1`, com stretch `viewport`:

- **Retrato (Android, padrão do jogo):** `k = min(round(largura / 300), floor(altura / 480))`. É a regra do hyakki
  com a tela girada: em retrato, o lado curto é a largura. O segundo termo garante altura lógica de pelo menos 480 e
  só muda o fator em telas quase quadradas (Z Fold aberto, tablets 4:3), que descem um passo inteiro e ficam mais
  largas (até 453) em vez de baixas.
- **Paisagem (Windows/Linux, Steam, Steam Deck):** `k = floor(altura / 540)`. A altura lógica fica entre 540 e 800.
  A área de jogo é um retângulo 9:16 centralizado com a altura inteira da tela; as laterais mostram painéis de
  pontuação, arte e controles.

**Toda tela, todo painel, o hub e o HUD precisam ser testados em todas as resoluções lógicas da tabela.** Os
aparelhos são só exemplos de cada resolução.

### Retrato (Android)

| Resolução lógica | Tela física (retrato) | Escala | Aparelhos de exemplo |
|---|---|---|---|
| **305x678** | 1220x2712 (9:20) | ×4 | Redmi Note 14 Pro+ 5G (referência) |
| **270x600** | 1080x2400 (9:20) | ×4 | Samsung Galaxy M55 5G (SM-M556B/DS), Google Pixel 7 |
| **270x585** | 1080x2340 (9:19.5) | ×4 | Samsung Galaxy A15 / A15 5G (SM-A155F / SM-A156B), Galaxy A56 5G (SM-A566B), Xiaomi POCO M3, Galaxy S24 Ultra / S25 Ultra em FHD+ (padrão) |
| **288x624** | 1440x3120 (9:19.5) | ×5 | Samsung Galaxy S24 Ultra (SM-S928B) / S25 Ultra (SM-S938B) em QHD+ |
| **360x780** | 720x1560 (9:19.5) | ×2 | Samsung Galaxy S24 Ultra / S25 Ultra em HD+ |
| **270x480** | 1080x1920 (9:16) | ×4 | telas 9:16 |
| **320x512** | 1600x2560 (10:16) | ×5 | Samsung Galaxy Tab S9 / S9 FE+ e tablets 16:10 QHD (sem furo) |
| **300x500** | 1200x2000 (10:16) | ×4 | Samsung Galaxy Tab A9+ e tablets 16:10 de entrada (sem furo) |
| **384x512** | 1536x2048 (3:4) | ×4 | tablets 4:3 (estilo iPad), Xiaomi Pad 4:3 (sem furo) |
| **360x800** | 720x1600 (9:20) | ×2 | Samsung Galaxy A05 / A05s, Motorola Moto E13 / E14 (HD+ baratos) |
| **360x806** | 720x1612 (9:20) | ×2 | Motorola Moto G04 / G24 / E22, Xiaomi Redmi A3 (HD+ baratos) |
| **453x544** | 1812x2176 (quase 1:1) | ×4 | Samsung Galaxy Z Fold5 / Fold6 aberto (tela interna) |
| **301x772** | 904x2316 (9:23) | ×3 | Samsung Galaxy Z Fold5 / Fold6 fechado (tela externa) |
| **270x630** | 1080x2520 (9:21) | ×4 | Sony Xperia 1 / Xperia 5 (FHD+), Xiaomi e Motorola 21:9 |
| **270x660** | 1080x2640 (9:22) | ×4 | aparelhos 22:9 muito alongados (FHD+) |

### Paisagem (Steam)

| Resolução lógica | Tela física | Escala | Exemplos |
|---|---|---|---|
| **960x540** | 1920x1080 / 3840x2160 | ×2 / ×4 | monitores Full HD e 4K |
| **1280x720** | 2560x1440 / 1280x720 | ×2 / ×1 | monitores QHD, janelas 720p |
| **1280x800** | 1280x800 / 2560x1600 | ×1 / ×2 | Steam Deck, notebooks 16:10 |

### Regras

- **Todas as resoluções, sempre:** **cada** tela, painel, diálogo, sobreposição, o hub e o HUD da partida
  (inclusive a área de jogo visível e a borda de surgimento dos inimigos) são testados em **todas** as resoluções
  lógicas das duas tabelas, sem exceção, antes de qualquer commit e de qualquer versão. Tela nova só entra com teste
  de layout que percorra a tabela inteira (`DeviceProfiles.layout_cases()`). Falha em uma resolução reprova o commit,
  mesmo que as outras passem. A correção é sempre de layout responsivo (quebra de linha, rolagem, empilhar, colunas
  menores, tamanhos a partir da tela), nunca caso especial para uma resolução.
- **Área de jogo igual para todos:** a simulação usa um campo fixo de **270x450 unidades** (largura x altura),
  desenhado 1:1 em pixels lógicos. É o maior campo que cabe na menor tela da tabela (270x480) depois do recorte.
  Telas maiores nunca mostram mais área de jogo: a sobra lateral vira moldura com parallax e painéis, a sobra de
  cima recebe o HUD e a sobra de baixo vira a **zona do polegar** (o dedo arrasta ali sem cobrir a nave). Isso mantém
  a dificuldade, o ranking e o determinismo iguais em todos os aparelhos. O teste do campo em `tests/run_tests.gd`
  (regra pura `Playfield.layout`) confere que o campo cabe inteiro em todas as resoluções, fora do recorte, e que o
  HUD não cobre mais de 6% do campo nas telas curtas.
- **Fonte única:** a lista de resoluções fica em `tests/device_profiles.gd`. Os testes de layout leem dela, sem tamanho
  fixo no código. Resolução nova é uma linha nesta tabela **e** em `tests/device_profiles.gd`. Aparelhos que dão a
  mesma resolução lógica ficam na mesma linha.
- **Recorte da câmera:** em retrato o furo fica **em cima**, e embaixo quando o aparelho gira 180°. Os casos de layout
  rodam sem recorte (todos os idiomas), com recorte em cima e com recorte embaixo (idiomas `pt_BR`, `de`, `ru`). O
  modo imersivo esconde a barra de navegação, então ela não entra na área segura. Tablets e Fold aberto, sem furo, são
  testados com a mesma faixa genérica.
  A faixa física de cada linha é a do hyakki (120, 118, 110, 160, 80, 118, 120, 100, 120, 80, 80, 150, 96, 118, 118 px).
- **Testes unitários de layout:** em **cada** resolução, nos 11 idiomas e com a área segura simulada, nenhum botão,
  texto ou elemento de toque pode ficar fora da tela, cortado, sobreposto ou dentro do recorte. Alvos de toque têm
  pelo menos 44x44 pontos lógicos multiplicados pela escala física equivalente a 7 mm.
- **PixelScaler conferido:** `DeviceProfiles.check_scaler()` aplica cada tela física e confere `k` e a resolução
  lógica da tabela, inclusive telas extras (janelas de desktop e capturas).

## Rolagem suave e desempenho (qualidade Alta)

Toda tela com lista rolável precisa rolar sem engasgo, na qualidade gráfica **Alta**, em todas as resoluções. Os
testes rodam no Godot do PC (nunca no emulador).

- **Benchmark de rolagem (`tests/scroll_bench.tscn`, sem `--headless`):** em cada tela com rolagem (hub com o
  carrossel de banners e os cartões horizontais, mapa da campanha em parallax, Hangar, Naves, Eventos, Loja, Opções,
  Créditos, Resultados, Diário de Bordo), mede a tela parada e, em cada lista, piparotes até o fim e de volta e um
  arrasto lento com o dedo simulado, **nos dois eixos** quando a lista for horizontal. Mede em todas as resoluções de
  `tests/device_profiles.gd`, sem VSync, com média, p95, p99, pior quadro, travadas, render na CPU, chamadas de
  desenho e tempo da 1ª abertura. Só os quadros em movimento contam. **Critério:** com `-- --strict` passa com
  **p95 ≤ 6 ms**, **nenhum quadro > 33 ms** e **nenhuma travada** por lista, em todas as resoluções.
  Uso: `-- --res=305x678 --screens=hub,map --out=bench.json`.
- **Parallax:** `tests/parallax_tests.gd` confere que a posição de cada camada é função pura do deslocamento da
  câmera (mesmo deslocamento, mesma posição), que as camadas respeitam a ordem de profundidade e que o modo
  "reduzir movimento" zera a inclinação pelo acelerômetro e limita o fator de cada camada.
- **Unitários de desempenho (`tests/perf_tests.gd`):** medidor de quadros, rolagem pelo dedo começando em cima de
  botões (sem apertá-los), ritmo de quadros, pool de projéteis sem alocação após o aquecimento, fundo do hub
  redesenhando só as camadas animadas.
- **Partida (`tests/game_bench.tscn`, sem `--headless`):** quadro, render na CPU, chamadas de desenho e projéteis
  ativos de uma partida do bot (`-- --bot --seed=7 --stress=1000`: 1.000 projéteis inimigos + 150 inimigos +
  chefe). **Critério:** p95 ≤ 8 ms e nenhum quadro > 33 ms na qualidade Alta em 305x678 e 960x540.
- **Determinismo (`tools/run_checks.ps1`, passo 3):** a mesma semente dá o mesmo hash de estado em 1x, 2x e 3x e na
  qualidade Baixa. Qualquer diferença reprova o commit.

## Testes obrigatórios por área

| Área | Arquivo | O que confere |
|---|---|---|
| Regras puras | `tests/run_tests.gd` | dano, pontuação, graze, multiplicador, rank, economia, curva de HP, DSL de padrões |
| Dados | `tests/integration_tests.tscn` | todo JSON carrega, referências cruzadas existem, sprites e áudios existem |
| Idiomas | `tests/i18n_tests.gd` | 11 idiomas, chaves, marcadores, glifos da fonte para cada idioma |
| Save | `tests/save_tests.gd` | ida e volta, backup, migração de versões antigas |
| Fase | `tests/stage_tests.gd` | roteiro de cada missão termina, chefe aparece, sem onda impossível |
| Chefes | `tests/boss_tests.gd` | todas as etapas alcançáveis, aviso ≥ 0,5 s antes de cada ataque novo |
| Projéteis | `tests/bullet_contrast_tests.gd` | contraste ≥ 4,5:1 contra o fundo de cada capítulo |
| Créditos | `tests/credits_screen_tests.gd` | todo nome do índice de licenças está na tela e no `CREDITS.md` |
| Versão | `tests/version_tests.gd` | `project.godot` e todos os presets com a mesma versão |
| Layout | `tests/layout_tests.gd` | todas as telas em `DeviceProfiles.layout_cases()` |
| Parallax | `tests/parallax_tests.gd` | camadas determinísticas, ordem de profundidade, reduzir movimento |
| Loja e anúncios | `tests/shop_tests.gd` | recompensas, relógio voltado, provedor simulado, nada de anúncio na missão |

Nenhum PR é mesclado e nenhuma versão é lançada sem que os testes unitários (inclusive os de layout em todas as
resoluções), os de integração, os E2E e os benchmarks de rolagem e de partida passem **no Godot** em todas as
resoluções-alvo. Teste no emulador, no Steam Deck ou no aparelho é só manual e não substitui nenhum deles.

## Como rodar

```powershell
powershell -ExecutionPolicy Bypass -File tools\run_checks.ps1
```

O script importa o projeto, roda `gdlint`, os testes de regras, i18n, licenças, integração, determinismo (1x, 2x, 3x,
Baixa) e o estresse de 1.000 projéteis. Termina com `TUDO OK` ou `FALHOU`. O executável do Godot vem de `$env:GODOT`
ou de `C:\src\tools\godot\Godot_v4.7.2-stable_win64_console.exe`.
