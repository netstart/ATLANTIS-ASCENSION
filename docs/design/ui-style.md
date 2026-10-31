# Guia de estilo da interface — "Neon abissal" (redesenho 1.6)

> Referenciado por [docs/policies/qualidade.md](../policies/qualidade.md). Fonte de verdade do código:
> [scripts/ui/ui_theme.gd](../../scripts/ui/ui_theme.gd), [scripts/ui/ui_fx.gd](../../scripts/ui/ui_fx.gd) e
> [scripts/ui/abyss_backdrop.gd](../../scripts/ui/abyss_backdrop.gd). Pesquisa de mercado que embasa as regras:
> [.ai/05-pesquisa-redesign-ui-gameplay.md](../../.ai/05-pesquisa-redesign-ui-gameplay.md).

## Renderização

- **Resolução física, layout lógico.** O stretch é `canvas_items`: a tela lógica (305x678 no aparelho de
  referência) continua a régua de layout, mas texto, contornos, chanfros e shaders são desenhados na
  resolução física. Pixel art sobe em múltiplo inteiro com filtro nearest (nítido, sem borrão).
- **Um fundo só para todos os menus:** `AbyssBackdrop` (shader procedural num SubViewport na resolução lógica,
  redesenhado a 30 Hz). As telas **não** pintam fundo opaco; usam painéis de vidro por cima da água.
- O mapa liga a rolagem dele em `App.backdrop().scroll`: as três camadas de ruínas andam em velocidades
  diferentes (parallax 2,5D). O dedo, o mouse e o acelerômetro deslocam as camadas (`drift`).

## Paleta (cor = significado)

| Papel | Constante | Hex |
|---|---|---|
| Abismo (fundo) | `ABYSS` | `#050B1A` |
| Painel | `DEEP_BLUE` | `#0B1E33` (84–92 % de opacidade) |
| Painel elevado | `RAISED` | `#12304D` |
| Interativo e foco | `CYAN` | `#2FF3E0` |
| Secundário | `TURQUOISE` | `#14B8A6` |
| Ação principal e recompensa | `GOLD` | `#FFC94A` (texto `GOLD_DARK` `#1A1200` sobre ele) |
| Perigo | `CORAL` | `#FF4D6D` |
| Raro / épico | `VIOLET` | `#B57BFF` |
| Sucesso | `MINT` | `#5CF29B` |
| Texto | `TEXT` / `TEXT_DIM` | `#E6F7FF` / `#8FB3C9` |

Regra: dourado só na ação principal da tela e em recompensas. Ciano só no que se toca ou no foco.

## Formas

- Uma família: **chanfro de 45°** (`UiTheme.chamfer`). Chanfro grande em cima à esquerda e embaixo à direita.
- Botão secundário: `UiTheme.button_box` (vidro + borda ciano; foco acende halo).
- Ação principal (uma por tela): `UiTheme.style_primary(button)`.
- Abas: `UiTheme.style_tab(button, active)`.
- Painéis e cartões: `UiTheme.panel_box(accent)` em `PanelContainer`.
- Moedas: `UiTheme.pill_box()`.

## Tipografia

- **Exo 2** (OFL), variável: corpo peso 560 (`Locale.font`), títulos peso 800 (`Locale.font_bold`, `UiTheme.heading`).
- CJK cai na Fusion Pixel regional (reserva automática da `FontVariation`).
- Tamanhos lógicos: 10 (nota), 12 (corpo), 16 (cabeçalho), 24 (título), 30+ só no logo.

## Movimento

- Botões: afundam 0,94 em 60 ms e voltam com salto (1,05 → 1,0, 180 ms). Foco/hover: 1,03. (`UiFx`, automático.)
- Entrada de tela: fade de 220 ms. Contagens: `UiFx.count_up` (600–1200 ms).
- Nunca mais de 400 ms entre o toque e a tela nova. "Reduzir movimento" desliga escala, salto e relógio do fundo.

## Leiaute em retrato

- Topo: voltar (esquerda), título, moedas (direita). Nada mais.
- Ação principal na zona do polegar (terço inferior), ≥ 70 % da largura, ≥ 48 pt de altura.
- Barra de abas embaixo, 5 destinos no máximo, ícone + rótulo.
- Alvos de toque ≥ 36 pt (`UiTheme.TOUCH_MIN`).
