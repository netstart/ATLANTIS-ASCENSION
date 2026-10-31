# Pesquisa para o redesenho 1.6 — UI, jogabilidade e 2,5D dos concorrentes

> Pesquisa de 31/10/2026 que embasa o [guia de estilo](../docs/design/ui-style.md). Só mecânica e padrões; nada de
> arte, nomes ou interface dos jogos citados. Os números de tempo e escala são propostas de design, não medições.

## 1. O que os concorrentes fazem e o que a crítica diz

| Jogo | Gancho | Elogio | Queixa |
|---|---|---|---|
| Sky Force Reloaded | Medalhas por fase (70 %/100 % de abates, resgates, sem dano) abrem a próxima dificuldade; 60+ melhorias | Repetição recompensadora | Grind, nave começa fraca |
| Galaxy Attack / Space Shooter | Fases de 1–3 min, armas que caem, energia | Sessão curta | Anúncios e vantagem paga |
| Cygni: All Guns Blazing | Energia vai para escudo ou arma | 2,5D denso e bonito | Fases de 10–15 min sem checkpoint, upgrade confuso |
| Crimzon Clover | Trava em até 16 alvos multiplica; medidor de quebra | Profundidade de pontuação | Curva íngreme |
| Danmaku Unlimited 3 | Graze contínuo, transe que vira balas em gemas | Legibilidade | — |
| Rolling Gunner | Rank multiplica pontos; medalhas maiores por tiro rápido | Risco e recompensa "fácil de entender" | — |
| Nova Drift | 200+ melhorias, corridas de ~30 min | "Só mais uma" | Começo lento |
| Ghost Blade HD / Ex-Zodiac | Polimento | Visual | Pouco conteúdo, sem identidade |

Fontes: gameinformer.com (Sky Force Reloaded), pocketgamer.com, godisageek.com (Cygni), shmups.wiki (Rolling Gunner,
Danmaku Unlimited 3), en.wikipedia.org (Crimzon Clover), rogueliker.com (Nova Drift), opencritic.com.

**Padrão:** vencem um medidor único e legível que transforma risco em pontos, metas claras por fase e partidas curtas.
Perdem grind, fases longas sem checkpoint, anúncios forçados e pouco conteúdo.

**O que Atlantis já tem e os supera:** medalhas de oricalco escalonadas, Corrente de Maré, graze e queima-roupa, Ocean
Shift, 4 estrelas por missão, chefes com fases, Abismo Infinito (roguelite), replays e fantasma determinísticos,
co-op local. **O que faltava era apresentação:** menus, fundo, tipografia, 2,5D e som.

## 2. Interface (padrões de mercado)

- Hub em retrato: logo no terço de cima, nave em destaque, **uma** ação principal grande na zona do polegar, barra de
  5 abas embaixo, só moedas e engrenagem no topo. Fundo vivo com parallax e partículas.
- Uma família de formas (chanfro 45°), paleta com uma primária e um destaque, cor = significado.
- Toda interação responde em até 60 ms (escala, som). Transições ≤ 300 ms, puláveis.
- HUD fora do campo de 270x450 quando sobra espaço; mínimo quando dentro.
- Resultados em sequência (pontos → bônus → total → medalha → recompensas) com contagem animada e som subindo.
- Hangar: nave grande, antes → depois numérico, 1 tela, 3–4 categorias, sem submenus.
- Steam Deck: testar 1280x800 à distância de braço; texto ≥ 12 px de altura a 800p.

Fontes: blakecrosley.com/guides/design/balatro, gamedeveloper.com ("The anatomy of a shmup"), shmups.system11.org,
mockplus.com, uxpin.com, bugnet.io.

## 3. 2,5D no Godot 4 (Compatibility)

- Camadas: abismo 0,1x · ruínas longe 0,3x · chão em perspectiva 0,6–1,0x · campo de jogo 1,0x · primeiro plano 1,5x
  (alfa ≤ 0,35 sobre o campo, fora do centro).
- Chão em perspectiva por shader `canvas_item` (estilo "mode 7"): profundidade 1/(y·tilt + c), neblina por
  profundidade (`#0A2A3A` → `#02070C`).
- Sombras: cópia escura (alfa 0,35) deslocada (+6, +10), escala 0,8, abaixo das balas.
- Inimigos que entram do fundo: escala 0,35 → 1,0 em 40–60 quadros, sem colisão até chegar.
- Mapa da campanha com profundidade: 4–5 camadas a 0,2x / 0,45x / 1,0x / 1,3x, inércia e mola nas bordas, acelerômetro
  ±12 px.

## 4. Músicas e assets escolhidos (todos registrados em `licenses/registry.json`)

| Uso | Faixa | Autor | Licença |
|---|---|---|---|
| Menus | Deep Sea | Umplix | CC0 |
| Fases do oceano | Ocean Trance | MintoDog | CC0 |
| Fases de Atlântida | Binary Underwater Village | Pro Sensory | CC0 |
| Fases de tempestade e núcleo | Cyber Runner | ansimuz | CC0 |
| Fases finais | Deadly Contracts, Hostile Territory | Magnesus | CC BY 4.0 |
| Chefes | 8-bit Danger!! Strong Boss | HydroGene | CC0 |
| Chefes | Boss Stage Synth Track | killerfishred | CC0 |
| Fonte da interface | Exo 2 | Natanael Gama | OFL 1.1 |
