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
## A saída da fase continua na marca "outro" da carga, anterior a este número (SimOutro).

const CURRENT := 6


## Revisão das regras de uma partida com esta carga.
static func of(loadout: Dictionary) -> int:
	return clampi(int(loadout.get("rev", CURRENT)), 1, CURRENT)
