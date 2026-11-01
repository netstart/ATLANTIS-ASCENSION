# Atlantis Ascension — O que torna o jogo divertido, viciante e surpreendente

> Data: 01/11/2026. Pesquisa feita na internet (game feel, risco e recompensa, recompensa variável, retenção da
> primeira sessão, vibração no celular, rejogabilidade de roguelites e shmups recentes), cruzada com o que o jogo já
> tem na versão `1.11.0`. Complementa a [pesquisa de mercado e retenção](04-pesquisa-mercado-e-retencao.md), cujas
> recomendações P0 a P2 já estão quase todas no jogo. Implementado na versão `1.12.0` "Maré de Glória".

## Como ler

- **✅** já existe no jogo. **🆕** entrou na `1.12.0`. **⬜** recomendado para depois.
- Afirmações marcadas **[CG]** são conhecimento geral do gênero que esta pesquisa não confirmou em fonte.
- Os números de retenção vêm de blogs de análise de mercado e variam por gênero; servem de ordem de grandeza.

---

## 1. Resumo para decisão

O jogo já tem o que a pesquisa de mercado de 30/10 pediu: pontuação com risco (corrente, raspão, queima-roupa,
pérolas), Maré Alta, Bênçãos com sinergias, rotas, segredos, chefes que lembram, Segunda Maré, roguelite, diárias,
passe, conquistas, fantasma e replay. **O que faltava não era sistema, era momento**: o jogo calculava as jogadas
bonitas, mas não as celebrava; dava a recompensa, mas sem expectativa; mostrava a derrota, mas não o quanto faltou.

Três achados guiaram a `1.12.0`:

1. **Reconhecer a jogada na hora.** O *Vampire Survivors* "quase não deixa passar alguns segundos sem algo bom
   acontecer", e o som de coleta que sobe de tom é comparado a um caça-níquel pagando. O *Devil Blade Reboot*
   (Overwhelmingly Positive) vive de uma regra só — chegar perto rende mais — e de deixar o jogador sentir isso.
   → **Ecos de Estilo**: frases curtas e sons que sobem a cada degrau da corrente, raspões em série, abates à
   queima-roupa, medalha máxima, chuva de pérolas e chefe final vencido sem dano ou por um fio.
2. **Expectativa vale tanto quanto o prêmio.** A arca do *Vampire Survivors* pausa a ação, gira os prêmios como um
   carretel e toca música; o criador programava caça-níqueis antes do jogo. A pesquisa de Portsmouth chama isso de
   laço "só mais uma". O *Hades* separa bênçãos por raridade e esconde as duplas atrás de 12% de chance.
   → **Arca da Maré**: toda vitória abre uma arca cujo metal vem da **nota** (jogar melhor = arca melhor) e cujo
   carretel desacelera até o prêmio; 10% de chance (20% no SS) do **Tesouro de Atlântida**. Sem dinheiro real, sem
   anúncio, sem compra: é o oposto de uma loot box paga.
3. **A derrota precisa dizer "faltou pouco" e "faça isto".** A análise do *Vampire Survivors* nota que quase toda
   tentativa fracassada parece um quase-acerto, o que cria a coceira de tentar de novo. Guias de retenção mandam
   ensinar fazendo e terminar a sessão com uma meta aberta.
   → **"Quase lá"**: a tela de derrota mostra a barra da missão até onde o jogador chegou, o casco que restou ao chefe
   e uma dica tirada da própria partida (bomba guardada, raio que avisou, choque com inimigo).

Para fechar o pacote de *game feel*: **nota da missão C a SS** como meta de maestria em cada fase, **câmera lenta**
quando o chefe final cai e **vibração em camadas** (o raspão é um toque leve e nunca abafa o aviso de dano).

---

## 2. O que a pesquisa diz

### 2.1 Game feel ("juice")

- A palestra *Juice it or lose it* (Jonasson e Purho, GDC 2012) parte de um Breakout cru e soma camadas: clarão,
  tremor, texto flutuante, som e partículas; o resumo da disciplina inclui câmera lenta e "mais permanência" (fumaça).
- Câmera lenta e hitstop funcionam **com moderação**: congelar 0,2 s num golpe crítico dá peso; em toda ação, cansa
  e esconde o impacto que importa. O tremor deve escalar com a força do golpe.
- Contraponto: *Don't Juice It or Lose It* (Folmer Kelly) lembra que polimento demais tira imersão.
- **No jogo:** ✅ hitstop, tremor com teto, clarão, partículas, onda de choque, números de pontos (1.8.0).
  🆕 frases de estilo, câmera lenta só no chefe final (1,1 s, sem mudar a partida), vibração por prioridade.

### 2.2 Risco e recompensa no shmup

- Pontuação de shmup prende quando apresenta "cenários de risco e recompensa interessantes" (fórum da Steam); a
  corrente sobe com abates seguidos e zera quando o ritmo quebra; a hitbox mínima tornou o danmaku mais legível, não
  só mais difícil.
- Um desenvolvedor que fez o "raspão" de um shmup em Godot alerta: o bônus de raspão é **decisão de desenho**, numa
  faixa definida fora da nave, pago uma vez por bala, nunca durante escudo; e a vibração do raspão precisa de
  prioridade baixa e intervalo para não abafar o aviso de dano.
- **No jogo:** ✅ corrente x1 a x16, raspão, queima-roupa x1,5, pérolas, Maré Alta, medalhas.
  🆕 os degraus x4, x8, x12 e x16 viram eco na tela; raspão com vibração leve de prioridade 0.

### 2.3 Recompensa variável e expectativa

- *Vampire Survivors*: arca com carretel, luzes e música; o som de XP lembra moedas de caça-níquel; o desenvolvedor
  trabalhou com caça-níqueis. Não há dinheiro em jogo, o que o torna "bem manso" perto de um caça-níquel real.
- *Balatro*: o encanto vem de descobrir os curingas e as combinações; apresentação limpa e intuitiva.
- *Hades II*: quatro raridades de bênção, mais as especiais (Dupla, Lendária), que só aparecem com os pré-requisitos e
  nem sempre.
- **No jogo:** ✅ Bênçãos com sinergia e Avatar, módulos do Abismo Infinito. 🆕 Arca da Maré com carretel e Tesouro.
  ⬜ raridade nas bênçãos (comum, rara, épica) com cor e som próprios.

### 2.4 Maestria e metas claras

- Uma meta clara depois de vencer é o que mantém quem já "zerou": conquistas como objetivos laterais seguram o
  jogador no mesmo conteúdo (*Vampire Survivors*). [CG] notas por fase (S, A, B) são padrão em jogos de ação
  (*Devil May Cry*, *Bayonetta*, *Sonic*) porque mostram que dá para jogar **melhor**, não só passar.
- **No jogo:** ✅ 4 estrelas por missão, placares, conquistas. 🆕 nota C a SS por missão, melhor nota no mapa,
  conquistas "Maestria" (S em 10 missões), "Lenda Atlante" (um SS) e "Tesouro de Atlântida".

### 2.5 Primeira sessão e retenção

- Referências de 2026: D1 bom ~27% a 30%, D7 8% a 14%, D30 3% a 7% (variam por gênero e fonte).
- Primeira vitória em menos de 90 s; ensinar fazendo, não lendo; dar a primeira recompensa ainda na primeira sessão;
  terminar a sessão com uma meta aberta; não monetizar cedo.
- **No jogo:** ✅ prólogo curto, tutorial em jogo na 1-1, recompensas na primeira vitória, sem anúncio forçado.
  🆕 a primeira vitória já abre uma arca e grava a primeira nota (meta aberta: subir a letra).
  ⬜ medir o tempo até o primeiro abate e a primeira vitória no teste fechado.

### 2.6 Vibração no celular

- Android e Material: vibração consistente, curta, opcional e com intensidade ajustável; evitar vibrações longas.
- Apple: cada padrão ligado a uma causa clara, para o jogador aprender o que significa; mais forte para eventos
  maiores. Uso demais dessensibiliza e gasta bateria; testar em aparelho real.
- **No jogo:** ✅ opção e intensidade. 🆕 três prioridades: 0 (raspão, eco, abate grande), 1 (bomba, maré, captura),
  2 (dano, chefe caindo); vibração leve nunca interrompe uma importante.

### 2.7 Rejogabilidade

- *Brotato*: a variedade vem das builds, não do mapa; personagens que distorcem atributos mudam a corrida inteira.
- *Nova Drift*: partidas rápidas para experimentar e encadear módulos em sinergias.
- Shmups recentes: *Sophstar* é elogiado pela variedade de naves; *Ghost Blade HD* foi chamado de "sólido, mas
  dispensável" por ter pouco motivo para voltar depois de vencer — falta de meta pós-créditos derruba a nota.
- **No jogo:** ✅ 12 aeronaves com traço, Abismo Infinito, Segunda Maré, rotas, segredos, Correntes semanais.
  🆕 nota e arca dão motivo para revisitar cada missão já vencida.

---

## 3. O que o jogo deve conter — e o que entrou na `1.12.0`

### 3.1 🆕 Ecos de Estilo

| Jogada | Frase | Destaque |
|---|---|---|
| Corrente chega a x4, x8, x12 | "Corrente x8!" | 0 a 2 |
| Corrente chega a x16 | "CORRENTE MÁXIMA!" | 3 |
| 12 raspões em 1,5 s | "Dança das balas!" | 1 |
| 3 abates à queima-roupa em 1,5 s | "Queima-roupa!" | 1 |
| 15 pérolas em 1 s | "Chuva de pérolas!" | 1 |
| Medalha de 10.000 | "Medalha máxima!" | 2 |
| Chefe final sem dano na missão | "Impecável!" | 3 |
| Chefe final com 1 de casco | "Por um fio!" | 3 |

- Cor e tamanho sobem com o destaque (ciano, menta, ouro, violeta); som de medalha mais agudo a cada degrau; o
  destaque 3 toca o som de poder. No máximo 3 frases na tela; cada tipo espera 4 s para repetir.
- Só lê a Sim (`StyleTracker`), não muda o hash nem o replay. Opção "Ecos de estilo" nas Opções.

### 3.2 🆕 Nota da missão

- Pontos: 20 por estrela, até 10 pela maior corrente, 10 por não usar bomba, −20 por reviver.
  B ≥ 50, A ≥ 70, S ≥ 95. **SS** = partida perfeita: 4 estrelas, sem dano, sem bomba, sem reviver e corrente ≥ 48.
- Selo em roseta carimbado no resultado (tom sobe com a letra; S e SS soltam centelhas), "Nova melhor nota!" e a
  melhor nota no cartão da missão no mapa. Só a campanha grava.

### 3.3 🆕 Arca da Maré

| Nota | Metal | Créditos | Pérolas | Oricalco | Tesouro de Atlântida |
|---|---|---|---|---|---|
| C, B | Bronze | 10 a 30 | — | — | — |
| A | Prata | 25 a 60 | 1 a 2 | — | 4% |
| S | Ouro | 50 a 110 | 2 a 4 | 1 | 10% |
| SS | Ouro | 50 a 110 | 2 a 4 | 2 | 20% |

- Tesouro: créditos x3 e +1 de oricalco. Determinística (missão, semente da partida e número de partidas).
- Carretel com 14 símbolos que desacelera (45 ms a 200 ms), tique que desce de tom e carimbo no prêmio.
- Ética: nada se compra, nada exige anúncio, a chance está documentada aqui, e o prêmio só soma (nunca tira).
  A média do ouro fica ≤ 130 créditos (teste), um bônus perto do pagamento base da missão, sem quebrar a curva.

### 3.4 🆕 "Quase lá" na derrota

- Barra da missão até onde o jogador chegou (a marca dos 90% é o chefe final), casco restante do chefe e a dica:
  1. chefe com ≤ 25% → "O chefe estava com só N%. Mais uma tentativa e ele cai!";
  2. bomba guardada → explica que a bomba apaga as balas e dá invencibilidade;
  3. caiu num raio → "quando a faixa acender, saia dela"; 4. choque → "dê espaço aos grandes";
  5. senão, uma dica geral (modo preciso, Maré Alta, hangar, sinergia, raspão) escolhida pela semente.
- A Sim passou a contar `progress`, `boss_left`, `bombs_left` e `cause` no resultado (sem mudar o hash).

### 3.5 🆕 Câmera lenta do golpe final

- Quando o chefe final cai, o relógio da partida roda a 22% por meio segundo e volta suave ao normal em 1,1 s
  (`GameClock.time_scale`): menos passos por segundo real, os mesmos passos. Bot e replays não desaceleram.

### 3.6 🆕 Vibração em camadas

- `Settings.vibrate(ms, intensidade, prioridade)`: intervalo de 80 ms (160 ms nos toques leves); uma vibração mais
  importante passa por cima de uma leve; uma leve nunca corta uma importante ainda tocando.

### 3.7 ⬜ Próximos passos recomendados

| # | O quê | Por quê | Custo |
|---|---|---|---|
| 1 | Raridade nas bênçãos (comum, rara, épica) com revelação própria | Expectativa e "achado raro" do *Hades* | M |
| 2 | Música que ganha camadas com a corrente (percussão em x8, melodia em x16) | O som acompanha o fluxo | M |
| 3 | Desafios de maestria por nave (SS com cada aeronave) com pintura exclusiva | Meta longa para quem já tem tudo | P |
| 4 | Revanche do chefe: botão "Enfrentar de novo" direto na derrota diante do chefe | Encurta o "só mais uma" | P |
| 5 | Cartão compartilhável do resultado (nota, arca, recorde) | Social sem servidor | P |
| 6 | Medir tempo até a primeira vitória e D1 no teste fechado | Meta de < 90 s e D1 ≥ 40% | P |
| 7 | Ecos dos Caídos e Elevação Global | Social assíncrono (precisa de servidor) | G |

---

## 4. Armadilhas e como o jogo evita

| Armadilha | Evidência | Como evitamos |
|---|---|---|
| Recompensa variável virar jogo de azar | Debate sobre a arca do *Vampire Survivors* | Arca sem compra, sem anúncio, prêmio só positivo, chances publicadas |
| Juice demais esconde o importante | Guias de game feel | Frases com teto de 3 e intervalo de 4 s; câmera lenta só no chefe final |
| Vibração que abafa o aviso | Desenvolvedor de shmup em Godot | Prioridades; o raspão é prioridade 0 |
| Recompensa que pune o próprio comportamento | O raspão que enchia o rank (mesma fonte) | Os ecos e a nota não mexem no rank nem na partida |
| Derrota sem rumo | Retenção da primeira sessão | "Quase lá" com dica da própria partida |
| Pouco motivo para voltar depois de vencer | *Ghost Blade HD* | Nota C a SS, arca melhor com nota melhor, conquistas de maestria |

---

## 5. Fontes

**Game feel e risco e recompensa**
- https://dev.to/kfiradut/a-near-miss-is-a-design-decision-not-just-a-collision-check-14ab
- https://steamcommunity.com/discussions/forum/12/558747922977198377/
- https://reigncreativellc.com/blog/history-of-shoot-em-up-games/
- https://en.wikipedia.org/wiki/Near-miss_effect
- https://medienwissenschaft.uni-bayreuth.de/wp-content/uploads/GxD-10-Game-Feel.pdf
- https://gamedeveloper.com/design/6-mistakes-that-ll-drain-the-juice-out-of-your-game
- https://www.wayline.io/learn/game-feel/1
- https://eastondev.com/blog/en/posts/dev/20260521-game-feedback-feel/
- https://bugnet.io/blog/game-feel-why-juice-matters-and-how-to-add-it
- https://www.timeextension.com/reviews/pc/devil-blade-reboot
- https://dengekionline.com/article/202405/6314

**Recompensa variável e rejogabilidade**
- https://mechanicsofmagic.com/?p=31948
- https://researchportal.port.ac.uk/en/publications/vampire-survivors-how-developers-used-gambling-psychology-to-crea/
- https://benjaminglover.substack.com/p/how-a-game-rife-with-gambling-mechanics
- https://jboger.substack.com/p/the-secret-sauce-of-vampire-survivors
- https://www.kokutech.com/blog/gamedev/design-patterns/power-fantasy/vampire-survivors
- https://tkvalentineblog.wordpress.com/2024/10/29/balatro/
- https://maxroll.gg/hades-2/guides/hades-2-boons-and-gods-guide
- https://primagames.com/tips/hades-what-are-duo-boons-how-get-duo-boons
- https://www.cgmagonline.com/review/game/brotato-pc-review/
- https://bugnet.io/blog/how-to-design-a-roguelike-item-and-synergy-system
- https://www.thesixthaxis.com/2017/03/03/ghost-blade-hd-review/
- https://opencritic.com/game/3999/view

**Retenção e primeira sessão**
- https://segwise.ai/blog/mobile-gaming-app-user-retention-strategies
- https://blog.playio.co/mobile-game-onboarding-retention
- https://gamegrowthadvisor.com/blog/2026-03-17-mobile-game-retention-strategies-2026/
- https://medium.com/@amol346bhalerao/mobile-game-onboarding-top-ux-strategies-that-boost-retention-6ef266f433cb

**Vibração**
- https://developer.android.com/develop/ui/views/haptics
- https://m2.material.io/design/platform-guidance/android-haptics.html
- https://developer.apple.com/design/human-interface-guidelines/playing-haptics
