class_name SimRevision
extends RefCounted
## Revisão das regras da Sim. Toda mudança que altera o resultado de uma entrada gravada sobe CURRENT; a carga
## guarda "rev" (Replay.to_dict) e a Sim segue as regras daquela revisão, para replays e Fantasmas antigos
## reproduzirem igual. Carga sem "rev" numa partida nova = revisão atual; replay sem "rev" = 1 (Replay.from_dict).
##   1: até a 1.20.1.
##   2: balas inimigas nascem na boca do emissor, espalhadas, não no centro (PatternRunner.muzzle).
##   3: rebalanceamento da dificuldade: curva por capítulo (balas, cadência, vida; Sim.CURVE_*) e rank na cadência.
##   4: objetivos de fase (SimObjectives: resgate, sabotagem, interceptação) e alvos sem dano de contato.
##   5: caixas de colisão medidas na arte HD (Hitboxes, data/hitboxes.json): dano, contato e ponto da nave.
##   6: feixe dos padrões sai da boca do emissor e o segue, mira o jogador e gira devagar (EnemyBeam).
##   7: nave do jogador de volta ao porte original na tela (meia escala da HD): ponto da hitbox a meia distância
##      do centro (Hitboxes.ship).
##   8: mar: submarinos e navios nas missões de água (SimEnemy.sea, só mísseis e explosões os ferem), mísseis do mar
##      automáticos (SecondaryFire.sea_launcher) e mísseis buscando o mar primeiro (Sim.nearest_target).
##   9: feixe só sai de algo visível: drones emissores destrutíveis nas bocas fora do casco (partes "drone" do
##      Olho da Tempestade, Arquiteto, Portão Orbital e Sky Leviathan; destruir um corta o feixe dele) e a boca da
##      Raia Trovejante nas cápsulas laterais. Partes e entradas de padrão com "since_rev"/"until_rev" (SimBoss).
##  10: secundária com nível na fase (SecondaryFire.phased): a Oficina dá o nível inicial, cada orbe sobe 1 até 5 e
##      cada dano tira 1; 2, 4 e 6 mísseis (1 a 3 drones), Ogiva I (+50%) e Ogiva II (2x e estilhaço). O lançador
##      do mar segue fixo (1 par de 5).
## A saída da fase continua na marca "outro" da carga, anterior a este número (SimOutro).

const CURRENT := 10


## Revisão das regras de uma partida com esta carga.
static func of(loadout: Dictionary) -> int:
	return clampi(int(loadout.get("rev", CURRENT)), 1, CURRENT)
