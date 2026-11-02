# Poderes das naves (1.16.0)

Cada uma das 12 aeronaves ganha **três poderes novos**, além da especial que já tinha. Os poderes contam a história
da nave: o Falcão patrulha a superfície, a Manta caça no escuro do abismo, o Tridente fala a língua das ondas, a
Ascension carrega os ecos das outras onze.

## Regra de jogo: o medidor de Corrente

- Botão novo **PODER** (teclado `H`, controle `Y`/triângulo, toque: terceiro botão da zona do polegar, ao lado de SP e BOMBA).
- Medidor próprio, a **Corrente**, com **3 segmentos** (0,0 a 3,0). A especial (SP) e a bomba continuam como estão.
- Enche por abate (+0,06 por inimigo comum, +0,25 por elite/torre, +0,5 por miniboss), por graze (+0,004 por bala
  roçada) e pelo tempo (1 segmento a cada 14 s). Chefe dá +0,02 a cada 1% de vida tirada.
- Apertar PODER gasta **todos os segmentos cheios** e lança o poder do nível alcançado:
  - 1 segmento: **Poder I** (rápido, tático);
  - 2 segmentos: **Poder II** (forte, muda a sala);
  - 3 segmentos: **Poder III** (supremo: tela inteira, pausa de impacto, câmera e trilha reagem).
- Escolha de risco: gastar cedo um Poder I ou segurar até o Poder III. O HUD mostra os 3 segmentos e o nome do poder
  que sairia agora; cada segmento cheio toca um "tom" crescente (dó, mi, sol) e o terceiro brilha e pulsa.
- Durante um poder a Corrente não enche. Poder dá 0,5 s de invulnerabilidade de saída (I), 1 s (II) ou a duração
  inteira (III). Determinístico: o botão entra no `SimInput` como `power`, a replay grava só ele.
- O bot usa: Poder I com perigo próximo, Poder III com chefe na tela ou mais de 40 balas perto.

## Os 36 poderes

Ids em `data/powers.json` (`<nave>_1..3`). Cada poder é uma lista de efeitos primitivos com parâmetros
(`scripts/sim/powers.gd`), um efeito visual, um som e uma cor da nave.

| Nave | Poder I | Poder II | Poder III (supremo) |
|---|---|---|---|
| **Falcon** (equilibrada, patrulha da superfície) | **Investida do Falcão**: arranco curto na direção do movimento; o rastro corta balas | **Asas Cruzadas**: leque de 12 penas-lâmina teleguiadas | **Mergulho Solar**: sobe ao sol e mergulha; anel de choque na tela inteira e 5 s de Pulsar em dobro |
| **Manta** (precisão, caçadora do abismo) | **Lança de Coral**: feixe fino instantâneo, dano x6, perfura tudo | **Prisma Abissal**: o feixe se abre em três que varrem a tela por 3 s | **Raio do Abismo**: feixe colossal de 4 s, 48 de largura, apaga as balas que toca |
| **Hydra** (mísseis) | **Cardume**: 8 mísseis teleguiados | **Mordida Tripla**: 3 torpedos pesados com explosão em área | **Sete Cabeças**: 5 s de salvas contínuas, 7 mísseis por segundo |
| **Tempest** (velocidade) | **Corrente de Jato**: arranco relâmpago invulnerável | **Olho do Ciclone**: 4 s de balas inimigas a 35% da velocidade | **Tempestade Elétrica**: 4 s de raios encadeados entre inimigos e balas paradas |
| **Tridente** (controle de área, ondas) | **Onda Quebrante**: uma onda sobe pela tela e desfaz as balas em pérolas | **Redemoinho**: vórtice que puxa balas e inimigos pequenos e mói tudo por 4 s | **Maremoto**: três ondas de tela inteira em sequência, pérolas em cascata |
| **Atlas** (defesa) | **Égide**: escudo frontal por 3 s que devolve as balas para cima | **Bastião**: 3 orbes orbitais que bloqueiam balas por 8 s | **Muralha de Atlântida**: barreira de luz acima da nave por 5 s, absorve tudo e repara 1 casco |
| **Ariete** (artilharia) | **Salva de Morteiro**: 5 projéteis com mira e aviso no chão, explosão em área | **Carga do Ariete**: investida blindada para frente, dano de colisão enorme | **Bombardeio Abissal**: 14 impactos de artilharia em grade por 3 s |
| **Enxame** (drones) | **Colmeia**: +4 drones por 6 s | **Rede Neural**: 4 drones em anel ligados por feixes que cortam balas, 6 s | **Rainha do Enxame**: 12 drones kamikaze teleguiados e 8 s de enxame |
| **Eclipse** (plasma perfurante) | **Umbra**: 2 s de sombra; balas atravessam e o tiro perfura em dobro | **Corona**: anel de plasma pulsante em volta da nave por 4 s | **Eclipse Total**: a tela escurece, tudo para; 2 s depois as balas viram pérolas e todo inimigo leva dano massivo |
| **Nova** (crítico) | **Mira Estelar**: 4 s de crítico garantido | **Estrela Cadente**: 3 disparos perfurantes com crítico no inimigo mais forte | **Supernova**: implosão de 1 s (aviso) e explosão gigante com dano crítico |
| **Titan** (explosão) | **Granada Sísmica**: explosão em área à frente | **Reação em Cadeia**: 5 s em que todo inimigo abatido explode em área | **Cataclismo**: 6 explosões subindo em sequência pela tela |
| **Ascension** (lendária híbrida) | **Eco de Atlântida**: lança o Poder I da nave do rodízio atual | **Coro dos Doze**: 12 lanças de luz, uma na cor de cada nave, teleguiadas | **Ascensão**: 6 s invulnerável, arma em Ressonância, feixe central e anéis de maré |

## Primitivas (simulação)

`dash`, `ring`, `salvo`, `beam`, `slow`, `chain`, `wave`, `vortex`, `reflect`, `orbitals`, `barrier`, `strike`,
`drones`, `cloak`, `aura`, `eclipse`, `overdrive`, `heal`, `delayed_blast`, `echo`. Cada uma é determinística,
usa só o RNG da simulação e cabe no orçamento: nenhuma cria mais de 64 objetos por quadro.

## Som

Cada poder tem som próprio em `assets/audio/sfx/power_<id>.ogg`, misturado de camadas CC0 por
`tools/mix_power_audio.py` (ataque + corpo + cauda, com a cor da nave: Falcão metálico e solar, Manta cristalina e
profunda, Tridente aquosa, Eclipse grave e abafada, Ascension coral). Mais `power_charge_1..3.ogg` (os tons do
medidor) e `power_empty.ogg` (apertou sem carga). Pico em -1 dBFS, mono 44,1 kHz.

## Contrato entre simulação, arte e som

Nomes fixos, para as partes serem feitas em paralelo:

- Poderes: `data/powers.json`, ids `falcon_1`…`ascension_3` (nave + nível). Chaves de texto
  `power.<id>` (nome) e `power.<id>.desc` (uma frase), mais `hud.power`, `hint.power`, `power.tier` (`"Nível %d"`).
- Sons em `assets/audio/sfx/`: `power_<id>.ogg` (36), `power_charge_1.ogg`, `power_charge_2.ogg`, `power_charge_3.ogg`
  (segmento cheio), `power_empty.ogg` (apertou sem carga).
- Sprites em `assets/art/generated/powers/`: `feather.png` 8x16, `torpedo.png` 10x22, `missile_mini.png` 6x12,
  `orb.png` 16x16, `wave.png` 270x28, `vortex.png` 96x96, `corona.png` 72x72, `reticle.png` 32x32,
  `barrier.png` 160x18, `bolt.png` 10x32 (segmento de raio), `kamikaze.png` 12x12, `lance.png` 8x26,
  `mortar.png` 12x12, `warn_circle.png` 64x64, `dash_trail.png` 16x48, `shield_front.png` 64x24,
  `supernova.png` 128x128, `eclipse_disc.png` 128x128, e ícones `icons/power_<id>.png` 24x24 (36).

## Arte

Sprites novos gerados por `tools/gen_sprites.py` em `assets/art/generated/powers/` (penas-lâmina, torpedos, orbes,
onda, vórtice, coroa de plasma, mira, barreira, ícones dos 36 poderes para HUD e hangar) mais partículas do Kenney
Particle Pack (CC0) já baixado.
