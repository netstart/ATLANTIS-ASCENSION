# Atlantis Ascension — Pesquisa de efeitos visuais e plugins (1.8)

> Data: 31/10/2026. Duas frentes: como os shmups verticais de referência fazem tiro, impacto, explosão, coleta e
> interação com o mapa parecerem fortes; e quais plugins do Godot (GDScript ou C++/GDExtension) valem a pena.
> Resultado aplicado na 1.8.0 (ver [03-progresso](03-progresso-implementacao.md)). Inspiração de técnica, nunca
> cópia de arte, nome ou interface (AGENTS.md).

## 1. Resumo para decisão

1. **O que faltava era luz, camadas e consequência.** As referências (Sky Force Reloaded, Raiden, DoDonPachi e a
   série Cave, Crimzon Clover, Jamestown, Danmaku Unlimited 3, Steredenn, Ikaruga) somam luz aditiva a toda arma e
   explosão. Cada golpe tem várias camadas e deixa rastro no mundo: destroço, fumaça, splash. O jogo desenhava
   sprites com mistura normal, explosão de uma camada e faíscas de 2 px.
2. **Nenhum plugin de terceiros entra.** Nenhum supera um sistema próprio pequeno nas regras do projeto:
   - simulação determinística;
   - renderer Compatibility no Android fraco;
   - nenhum nó por bala;
   - licença livre registrada.
   Usamos recursos nativos do Godot (mistura aditiva, MultiMesh com cor por instância, shader que lê a tela) e
   sistemas próprios (seção 4).
3. **O glow nativo (`WorldEnvironment`) não serve aqui.** O modo Canvas do Compatibility não alterou nada no nosso
   2D, nem com intensidade 3 e limiar 0,3. O HDR 2D é só Forward+/Mobile, e o borrão de tela cheia pesa no celular.
   O brilho vem de sprites de clarão desenhados em mistura aditiva, que custam quase nada e funcionam em todo
   aparelho.

## 2. O que as referências fazem (técnica, com números)

| Momento | Técnica | Parâmetros usados |
|---|---|---|
| Tiro do jogador | Núcleo claro + halo colorido aditivo | Halo 3,6x a bala, alfa 0,6 (Média) a 0,85 (Alta) |
| Boca do canhão | Clarão curto a cada rajada | 60 ms, clarão + estrela de 4 pontas |
| Impacto | Ponto branco + faíscas contra o tiro | Clarão 90 ms; 2–3 riscos de 120–220 ms, ±63° |
| Inimigo avariado | Fumaça e brasa abaixo de 40% de vida | Uma baforada a cada 6 passos |
| Explosão | Clarão → bolas de fogo → faíscas → fumaça → estilhaços → anel | 0,1 s / 0,3–0,55 s / 0,25–0,5 s / 0,8–1,3 s / 0,5–0,9 s |
| Explosão grande e chefe | Mesma receita escalada (tier 1,7 / 2,5 / 3,5) e cadeia | Chefe: 6–12 explosões em 1,3 s e estouro final |
| Hitstop | Congelar a partida no golpe forte | Parte do chefe 50 ms; chefe 140 ms (nunca em inimigo comum) |
| Tremor | Decai rápido; dose por qualidade e opção | Comum 0,8; grande 3; dano 7; chefe 10 |
| Destroços (2,5D) | A nave abatida cai girando até a sombra | 0,75 s, encolhe a 40% e escurece; splash ao chegar |
| Água | Bolhas de quem sobe do fundo; splash dos destroços | Cor de espuma da paleta do capítulo |
| Coleta | Clarão + estrelas para fora; anel quando a arma sobe | 4 a 8 estrelas, 0,25–0,4 s |
| Medalhas | Brilho que passa em ciclo; número de valor | Estrela de 4 pontas por 0,25 s a cada ~0,6 s |
| Pontos | Número sobe 16 px e some | 0,75 s, salta 1,5x no começo; dourado nos grandes |
| Cancelamento de balas | Bala vira brilho em onda a partir da bomba | Atraso proporcional à distância, até 0,45 s |
| Bomba e especial | Clarão de tela, onda de choque com distorção, anéis | Clarão 0,45; distorção 0,03 por 0,55 s |
| Casco no fim | Borda vermelha pulsando | Vinheta vermelha a 6 rad/s |
| Leitura | Balas inimigas sempre por cima de toda luz | A camada aditiva fica abaixo das balas inimigas |

Paleta: o fundo continua escuro e dessaturado (teto de luminância por capítulo, `OceanBackdrop.capped`). As balas
inimigas têm núcleo claro e halo só em Alta (alfa 0,22). Os tiros do jogador ficam em ciano, azul ou violeta e os
coletáveis em ouro.

## 3. Plugins avaliados

| Plugin | Licença | Situação | Decisão |
|---|---|---|---|
| Phantom Camera | MIT | Ativo; tem ruído de câmera 2D | Não: campo fixo de 270x450, câmera não se move |
| Shaker | MIT (há cópia CC0 parada no 4.0) | Genérico | Não: o tremor já existe em ~10 linhas |
| BlastBullets2D (C++) | MIT | 4.5–4.7, binários Android | Reserva: só se o `game_bench` reprovar no Android fraco; troca o núcleo das balas e o controle do determinismo |
| BulletUpHell | MIT | Parado no 4.0 | Não |
| godotshaders.com | Por shader (CC0, MIT, GPL, ports do Shadertoy) | Referência | Só como ideia; shaders escritos aqui (GPL e ports NC são proibidos) |
| LimboAI / Beehave | MIT | 4.7 não confirmado | Não: inimigos de shmup são padrões roteirizados |
| GodotSteam | MIT | Necessário para a Steam | Fora deste escopo (espera o App ID; já no plano mestre) |
| Glow do WorldEnvironment | Motor | Sem efeito no nosso 2D Compatibility | Não (seção 1) |

## 4. O que foi construído

- `scripts/view/particle_field.gd`: partículas em lote com um `MultiMeshInstance2D` por textura e cor por
  instância. O estado vive em vetores empacotados (troca com a última ao morrer). Tem arrasto exponencial,
  aceleração, giro e faíscas que alinham e esticam com a velocidade. O teto vem de `particles_max` (250/600/1400).
- `scripts/view/combat_fx.gd`: as receitas da tabela da seção 2, com semente própria (não toca a Sim) e agenda para
  as cadeias e ondas. Usa duas camadas: luz (aditiva, linear) e matéria (normal, pixel art).
- `scripts/view/screen_fx.gd` com `shaders/field_grade.gdshader` (vinheta, perigo e clarão, sem ler a tela) e
  `shaders/shockwave.gdshader` (distorção com separação de cor). A onda só existe em Média e Alta e só fica
  visível enquanto corre.
- `BulletRenderer`: halo aditivo opcional que reaproveita o buffer das balas.
- `WorldView`: camada aditiva com laser em três camadas (halo, corpo, núcleo branco e pulsos subindo), luz dos
  motores (nave e inimigos), halos dos coletáveis, luz das explosões, brilho dos feixes e anéis de choque com borda
  macia.
- `Game`: hitstop, clarão, onda e perigo ligados aos eventos da Sim. Os eventos de coleta passaram a levar `pos`
  (não muda o hash da partida).
- `HangarStage`: a luz dos bocais da nave no hub é a mesma da partida.
- Arte nova em `tools/gen_sprites.py` (licença do projeto): `flare_64`, `streak`, `smoke_16`, `debris_6`,
  `sparkle_9`, `shock_64`.

## 5. Acessibilidade e orçamento

- "Reduzir flashes": clarão de tela até 30%, explosão com clarão a 60%, anéis a 50%, onda de choque à metade e
  borda de perigo sem pulsar.
- Qualidade Baixa: sem halo de bala, sem fumaça, estilhaços, onda de choque, rastro de motor ou bolhas.
  Explosões e impactos ficam no mínimo.
- O bot e os replays não fazem hitstop: o tempo das partidas de teste não muda.
