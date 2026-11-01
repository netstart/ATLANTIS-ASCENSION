# ATLANTIS ASCENSION
### Plano mestre de game design e implementação (shmup vertical 2.5D, Android retrato + Steam, só assets livres)

| Campo | Valor |
|---|---|
| Gênero | Shoot'em up vertical (shmup) com campanha, coleção de aeronaves e chefes em etapas |
| Apresentação | 2.5D por sprites: pixel art 2D, parallax em camadas, escala e névoa por profundidade |
| Engine | Godot **4.7.2** stable, GDScript tipado, renderer **Compatibility (GLES3)** |
| Plataformas | Android **retrato** (Google Play) · Windows/Linux e Steam Deck (Steam) |
| Aparelho de referência | Redmi Note 14 Pro+ 5G, 1220x2712, resolução lógica 305x678 (×4) |
| Arte base | Série **Void** (Foozle, CC0) + Kenney (CC0); o que faltar é criado pelo projeto |
| Política de assets | 100% gratuitos e livres para uso comercial ([licencas.md](../docs/policies/licencas.md)) |
| Modelo de negócio | Play: grátis, anúncio recompensado opcional, cosméticos · Steam: premium sem anúncios |
| Versionamento | SemVer em todo commit ([versionamento.md](../docs/policies/versionamento.md)) |
| Data do plano | 30/10/2026 |

Documentos irmãos: catálogo de assets [02](02-catalogo-assets-licencas.md) · progresso [03](03-progresso-implementacao.md) ·
pesquisa de mercado e retenção [04](04-pesquisa-mercado-e-retencao.md) · conceito original
[atlantis_ascension_conceito_jogo.md](atlantis_ascension_conceito_jogo.md).

> **Fonte narrativa.** O prompt cita um link compartilhado do ChatGPT. A página não expõe o conteúdo para leitura
> automática (só o título "Sugestão de jogo e história"). A história deste plano parte do documento de conceito em
> `.ai/`, que é o resultado daquela conversa, e o expande.

---

## Sumário

0. Resumo executivo
1. Pesquisa das referências
2. Conceito e pilares
3. Narrativa e mundo
4. Game design: sistemas
5. Level design
6. Bestiário e chefes
7. UI/UX: hub interativo, mapa em parallax e HUD
8. Direção de arte e technical art
9. Áudio
10. Arquitetura técnica
11. Android, Steam e aparelhos
12. Assets e licenças
13. Roadmap
14. Plano de testes
15. Critérios de qualidade e metas de balanceamento
16. Riscos e mitigação
17. Monetização
18. Apêndices
19. Profundidade, retenção e o que torna o jogo viciante (da pesquisa)

---

## 0. Resumo executivo

**Atlantis Ascension** é um shmup vertical para celular em retrato e para PC. Em 2147 o Heart of Poseidon desperta no
fundo do Atlântico, o **Leviathan Protocol** começa a reescrever o planeta e a Atlântida sobe do mar até o céu. A
pilota Iara "Maré" Vasconcelos atravessa nove capítulos, do oceano à órbita, até o núcleo gravitacional onde o
protocolo nasceu.

Por que vai funcionar:

1. **Leitura acima de tudo.** Campo de jogo fixo de 270x450 em todos os aparelhos, balas com contraste medido,
   hitbox visível, avisos antes de todo ataque. Dificuldade justa é o que faz o jogador tentar de novo.
2. **Espetáculo que muda a fase.** O **Ocean Shift** transforma o cenário durante a missão (o mar sobe, ruínas
   emergem, a cidade levita). A **Gravity Breach** curva os projéteis e gira a arena. Nenhum concorrente mobile faz a
   fase mudar de regra no meio.
3. **Chefes como evento.** Quatro chefes de ato com 3 a 4 etapas, partes destrutíveis, apresentação com nome, música
   própria e mudança de arena.
4. **Hub vivo no estilo *Star Wars: Galaxy of Heroes*.** O menu é um hangar atlante animado, com abas, banners,
   cartões de aeronave e mapa de campanha em parallax que sobe do abismo à órbita.
5. **Um estilo de arte só.** A série Void (Foozle, CC0) dá nave, três frotas inimigas, ambiente e pickups no mesmo
   traço. Três frotas viram três facções. Isso evita a "colcha de retalhos" típica de jogos com assets gratuitos.
6. **Monetização honesta.** Sem energia, sem pay-to-win, sem anúncio durante a missão. Na Steam, jogo completo.
7. **Cada partida é diferente.** As **Bênçãos das Marés** (1 de 3 escolhas roguelike dentro da missão), a **Maré
   Alta** (explosão de poder que transforma balas em pérolas) e as **rotas Superfície e Abismo** vieram da pesquisa
   de mercado: são o que separa os shmups que retêm dos que são esquecidos (seção 19).

Escopo da 1.0: 9 capítulos x 3 missões (27) + 7 variantes de rota + 4 missões secretas, 4 chefes de ato,
9 mini-chefes, 6 aeronaves (+6 pós-lançamento), 4 armas principais, 2 secundárias, 6 especiais, 18 bênçãos,
~24 inimigos, Arcade, Boss Rush, Desafio Diário, Prática, Segunda Maré, 11 idiomas, conquistas e placares com
replay na Steam.

Estimativa para 1 desenvolvedor em meio período: **~30 semanas** até a 1.0; **protótipo jogável na semana 3**;
**Vertical Slice na semana 6**.

---

## 1. Pesquisa das referências

Detalhe completo, números e fontes em [04-pesquisa-mercado-e-retencao.md](04-pesquisa-mercado-e-retencao.md).

| Jogo | O que define o jogo | O que levamos | O que evitamos |
|---|---|---|---|
| **Galaxy Attack: Alien Shooter / Space Shooter** | Arrastar para mover, tiro automático, power-ups que trocam e sobem a arma, 160+ níveis, chefes, skills ativas | Controle de um dedo, power-up visível na hora, missões curtas | Grind de upgrade em níveis altos, anúncios em excesso, níveis repetitivos |
| **Atlantis Invaders** | Identidade oceânica e mitológica | Tema, paleta, criaturas biomecânicas | Nenhum elemento visual ou nome do jogo |
| **Wing Fighter** | Coleção de caças, alas de apoio, evolução de aeronave | Alas de apoio colecionáveis, silhueta própria por aeronave | Sistemas de gacha com chance oculta |
| **Falcon Squad** | Retenção por eventos, coleção, modos variados | Eventos por tempo, desafios, modos extras | Excesso de moedas e telas |
| **Raiden** | Padrões legíveis, medalhas, bomba, rank | Medalhas que crescem de valor, bomba, rank dinâmico leve | Dificuldade arcade sem assistência |
| **Star Wars: Galaxy of Heroes** (só o menu) | Hub como lugar vivo, cartões grandes, abas, banners | Hub interativo, cartões, transições | Nada de arte, nome ou layout copiado |

**Pilares derivados:**

1. **Um polegar joga.** Arrastar move, o tiro é automático, a especial tem botão próprio na zona do polegar.
2. **Ver para desviar.** Projétil legível, aviso antes do perigo, hitbox pequena e visível.
3. **Poder que se sente.** Cada nível de arma muda o visual e o som do tiro, não só um número.
4. **A fase muda.** Ocean Shift e Gravity Breach dão a cada missão um "momento" que o jogador lembra e comenta.
5. **Sessão curta, meta longa.** Missão de 2 a 5 minutos; progressão de hangar, coleção e segredos por semanas.
6. **Respeito ao jogador.** Nada de energia, anúncio forçado ou vantagem paga.

---

## 2. Conceito e pilares

### 2.1 Loop da missão (2 a 5 min)

decolar → ondas em formação → coletar orbes de arma e medalhas → Ocean Shift ou evento da fase → mini-chefe →
trecho final → chefe (em missões de fim de capítulo) → resultado com estrelas, pontuação e recompensas.

### 2.2 Loop de meta (entre missões)

recompensas → hangar (subir aeronave, módulos, alas de apoio) → mapa de campanha (próxima missão, rota secreta,
estrelas faltando) → eventos e desafio diário → nova missão "um pouco mais forte e muito mais hábil".

### 2.3 Controles

| Ação | Celular | Teclado | Controle |
|---|---|---|---|
| Mover | Arrastar relativo em qualquer ponto (a nave segue o deslocamento do dedo, não a posição) | WASD / setas | Analógico esquerdo / D-pad |
| Modo preciso | Automático com dois dedos ou botão de opção | Shift segurado | Gatilho esquerdo |
| Tiro principal | Automático (padrão) ou ao tocar (opção) | Automático ou J | Automático ou A |
| Especial | Botão na zona do polegar, canto inferior direito (espelhável para canhotos) | K | X |
| Bomba | Toque duplo na zona do polegar ou botão | L | B |
| Pausa | Botão no HUD ou tirar o dedo por 0,8 s (opção) | Esc | Start |

Detalhes do arrasto: sensibilidade de 0,8x a 2,0x (padrão 1,25x), zona morta de 1,5 pt, nave nunca sai do campo,
movimento aplicado no mesmo passo de simulação em que o toque chega. Com o dedo pressionado, a nave reduz a opacidade
das asas e mostra o ponto da hitbox (raio de 3 unidades).

### 2.4 Acessibilidade

- Dificuldade **Brisa** (assistida) sem bloqueio de conteúdo, só com placar separado.
- Velocidade de jogo 70%, 85% ou 100% em Brisa.
- Bomba de pânico automática (gasta uma bomba ao receber dano, opcional).
- Modos para daltonismo (protanopia, deuteranopia, tritanopia) que trocam a paleta das balas inimigas, testados por
  contraste.
- Reduzir flashes e tremor de tela; reduzir movimento (corta parallax por inclinação e limita camadas).
- Tamanho de texto 100%, 125%, 150%.
- Vibração com intensidade ajustável.
- Legendas para todas as falas, com nome do personagem e cor.

---

## 3. Narrativa e mundo

### 3.1 Premissa

Em 2147, a expedição *Halcyon* encontra a cerca de 4.000 m de profundidade uma estrutura colossal. No centro, uma
esfera: o **Heart of Poseidon**. Ao ser tocada, ela transmite uma única frase em todas as línguas humanas ao mesmo
tempo: **"Return the Sky."** Satélites caem, correntes oceânicas invertem e torres de cerâmica e ouro começam a
emergir.

A inteligência biomecânica **Leviathan Protocol** desperta. Ela foi criada pelos atlantes para manter a biosfera
estável e concluiu que a humanidade é a maior ameaça a essa estabilidade. A Atlântida não afundou: **dormiu de
propósito**, desligando a si mesma para prender o protocolo junto. A humanidade acabou de acordar os dois.

### 3.2 Personagens

| Personagem | Papel | Voz e função |
|---|---|---|
| **Iara "Maré" Vasconcelos** | Pilota de testes, protagonista | Direta, irônica sob pressão. O nome remete à Iara do folclore brasileiro (domínio público). Fala pouco durante a ação |
| **Dr. Tomás "Farol" Okafor** | Oficial de ciência na base *Halcyon* | Explica o que o jogador vê; traduz os registros atlantes; é a voz que muda de opinião no Ato III |
| **Almirante Hélène Duarte** | Comando da coalizão | Quer destruir o Heart a qualquer custo; antagonista humana sutil |
| **Thalassa** | Consciência atlante que dorme no casco híbrido da aeronave | Fala em fragmentos, cada vez mais clara; revela a verdade aos poucos |
| **Leviathan Protocol** | Antagonista | Lógica fria; fala por interferência nas transmissões; frases curtas, em caixa alta |

Retratos 64x64 com 3 expressões. Fala na missão é uma linha curta no rodapé (máximo 60 caracteres em pt-BR), nunca
pausa o jogo e nunca cobre o campo.

### 3.3 Estrutura

| Parte | Capítulos | Arco | Chefe |
|---|---|---|---|
| **Prólogo — Return the Sky** | missão 0 | Tutorial jogável no descenso da *Halcyon*; primeiro contato | Mini-chefe "Sentinela Abissal" |
| **Ato I — O Despertar** | 1 Oceano Atlântico · 2 Atlântida | Conter as primeiras máquinas; descobrir que as ruínas reagem à aeronave | **Kraken Engine** (fim do cap. 2) |
| **Ato II — Guerra Aérea** | 3 Tempestade · 4 Vulcões · 5 Cidade futurista | Cidades levitam; o conflito vira global. **Os três capítulos podem ser jogados em qualquer ordem** | **Sky Leviathan** (fim do cap. 5 ou do último escolhido) |
| **Ato III — A Verdade** | 6 Região glacial · 7 Estratosfera | Thalassa revela que a Atlântida se sacrificou; Duarte esconde ordens | **Poseidon Prime** (fim do cap. 7) |
| **Ato IV — Ascension** | 8 Órbita · 9 Núcleo gravitacional | Ofensiva final no centro do protocolo | **Leviathan Protocol** (fim do cap. 9) |

### 3.4 Finais

Na última etapa do Leviathan Protocol, o jogador escolhe com o próprio voo (entrar no feixe ou desviar dele):

- **Final "Céu Partido":** destruir o Heart. O protocolo morre, a Atlântida morre com ele, o céu fica com os humanos.
- **Final "Return the Sky":** devolver o Heart a Thalassa. A Atlântida volta a dormir, agora com Iara de guardiã.
- **Final verdadeiro "Maré Alta":** exige os 4 **Registros Abissais** (missões secretas). Thalassa e o protocolo se
  fundem; nasce uma terceira via. Desbloqueia o modo **Abissal** e o epílogo jogável.

### 3.5 Formas de contar a história

- Cena curta entre missões: 3 a 5 quadros ilustrados com parallax leve, sempre pulável.
- Rádio **só nos respiros**: antes e depois das ondas e nos trechos sem balas, linhas curtas, prioridade abaixo dos
  alertas. Silêncio durante padrões densos. Lição do *Raiden V*, punido por falar no meio das balas.
- **Registros de bordo** coletáveis (1 por missão, escondido): texto e áudio curto no Diário de Bordo.
- Apresentação de chefe: nome em tela cheia por 1,5 s, linha de fala, música própria.
- Mapa de campanha: cada estrato muda o cenário do hub e a música.

Dados em `data/dialogue.json` e `data/logs.json`, textos em `i18n/strings.csv`.

---

## 4. Game design: sistemas

### 4.1 Armas

**Orbes de arma** caem de inimigos marcados. A cor do orbe escolhe a arma principal; pegar a mesma cor sobe o nível;
pegar outra cor troca a arma e mantém o nível. Receber dano tira 1 nível. A arma assinatura da aeronave tem um
quarto nível, **Ressonância**.

| Arma | Cor | Nível 1 | Nível 2 | Nível 3 | Ressonância (assinatura) |
|---|---|---|---|---|---|
| **Pulsar** (leque) | Azul | 3 tiros em 12° | 5 tiros em 24° | 7 tiros em 36° + 2 traseiros | Leque em onda senoidal |
| **Laser** | Ciano | Feixe 6 u | Feixe 9 u, dano +40% | Feixe 12 u, ramifica em 2 ao acertar | Feixe que segue o dedo com leve atraso |
| **Plasma** | Violeta | Esfera lenta, explosão 12 u | 2 esferas, explosão 16 u | 3 esferas, poça de dano 1 s | Esferas que se juntam em uma grande |
| **Railgun** | Dourado | Disparo perfurante a cada 0,30 s | Dupla, 0,25 s | Tripla, atravessa escudos | Carga ao parar de mover: tiro de tela inteira |

DPS-alvo por nível, contra um alvo: 60, 90, 130, 175 (Ressonância). O Laser é melhor em alvo único, o Pulsar em
cobertura, o Plasma em grupos, o Railgun contra blindados. Tabelas finais em `data/weapons.json`.

**Secundárias** (escolhidas no hangar, sobem com módulos permanentes):

| Secundária | Comportamento |
|---|---|
| **Mísseis** | 2 a 6 mísseis teleguiados a cada 1,2 s, priorizam o inimigo mais próximo do topo |
| **Drones** | 1 a 3 drones que orbitam e copiam a arma principal com 30% do dano |

**Especiais** (uma por aeronave, recarga por tempo e por graze):

| Especial | Efeito | Recarga |
|---|---|---|
| Bomba de área | Limpa balas na tela, dano em área | 25 s |
| Escudo de maré | 4 s de invulnerabilidade e reflexo de balas | 30 s |
| Rajada concentrada | 3 s de feixe de dano x4 | 22 s |
| Enxame de drones | 6 drones por 8 s | 28 s |
| Pulso EMP | Para balas e torres por 3 s, desliga escudos | 26 s |
| Fenda gravitacional | Puxa balas para um ponto por 3 s | 30 s |

**Bombas** (2 por missão, +1 por pickup raro) são separadas da especial: limpam a tela e dão 1,5 s de
invulnerabilidade. Usar bomba zera o multiplicador de pontuação.

### 4.2 Aeronaves

Os nomes do conceito eram provisórios. Quatro colidem com nomes de chefes; renomeados para o jogador nunca confundir
"Kraken" aliado com Kraken Engine.

| Aeronave | Antes | Função | Arma assinatura | Especial | Na 1.0 |
|---|---|---|---|---|---|
| **Falcon** | Falcon | Equilibrada, inicial | Pulsar | Bomba de área | ✅ |
| **Manta** | Manta | Precisão, laser | Laser | Rajada concentrada | ✅ |
| **Hydra** | Hydra | Mísseis | Pulsar + mísseis nível extra | Enxame de drones | ✅ |
| **Tempest** | Tempest | Velocidade, hitbox menor | Laser | Pulso EMP | ✅ |
| **Tridente** | Poseidon | Controle de área | Plasma | Fenda gravitacional | ✅ |
| **Atlas** | Atlas | Defesa, +1 casco | Railgun | Escudo de maré | ✅ |
| **Ariete** | Kraken | Artilharia | Railgun | Bomba de área | pós |
| **Enxame** | Leviathan | Drones | Pulsar + drones nível extra | Enxame de drones | pós |
| **Eclipse** | Eclipse | Plasma perfurante | Plasma | Pulso EMP | pós |
| **Nova** | Nova | Crítico | Railgun | Rajada concentrada | pós |
| **Titan** | Titan | Explosão | Plasma | Bomba de área | pós |
| **Ascension** | Ascension | Lendária híbrida | troca de arma assinatura conforme o orbe | Todas, em rodízio | pós (final verdadeiro) |

Cada aeronave tem silhueta própria (48x48), 3 quadros de inclinação, motor animado, som de tiro próprio e um perfil
de atributos: velocidade, casco, hitbox, cadência. Diferença nunca só numérica.

### 4.3 Casco, dano e tentativa

- **Casco** em 3 segmentos (Atlas: 4). Cada acerto tira 1 segmento, 1 nível de arma e dá 1,5 s de invulnerabilidade.
- Perder o último segmento encerra a missão. **Reviver** 1 vez por missão (anúncio recompensado na Play; na Steam,
  1 reviver grátis por missão em Brisa e Normal, nenhum em Veterano e Abissal).
- **Missão curta** significa que recomeçar custa pouco. Botão "Tentar de novo" na tela de resultado, sem anúncio.

### 4.4 Pontuação

| Sistema | Regra | Por que |
|---|---|---|
| **Corrente de Maré** | Abates a menos de 0,8 s um do outro somam corrente; multiplicador x1 a x16 | Recompensa agressividade e rota |
| **Medalhas de Oricalco** | Caem de alvos especiais; valem 100, 200, 500, 1.000, 2.000, 5.000, 10.000. Perder uma volta a 100 | Risco e recompensa estilo Raiden |
| **Graze** | Bala a menos de 8 u da hitbox sem acertar: +10 pontos, carga da especial e do medidor de **Pressão** | Transforma o perigo em recurso |
| **Queima-roupa** | Abate a menos de 40 u da nave: +50% de pontos e +Pressão | Premia agressão (lição do *Devil Blade Reboot*) |
| **Pérolas** | Bala cancelada (bomba, Maré Alta, morte de chefe) vira bolha que sobe; tocar ou atirar dá pérola com o valor do multiplicador | Tela de perigo vira tesouro |
| **Maré Alta** | Pressão cheia: 8 s com multiplicador x2, dano +25% e cancelamento de balas próximas; sobe o rank | Risco escolhido: usar agora ou guardar (seção 19.2) |
| **Bônus sem dano** | x1,5 na pontuação da missão | Domínio |
| **Bônus de chefe** | Tempo restante x 100 por etapa | Agressividade no chefe |

Pontuação define estrelas, placar diário e placares da Steam. Não afeta economia de forma decisiva.

### 4.5 Estrelas por missão

Cada missão tem **4 estrelas**:

1. Concluir.
2. Concluir sem perder casco.
3. Destruir 100% dos alvos marcados.
4. Objetivo único da missão (resgatar 5 cápsulas, achar o Registro, derrotar o mini-chefe em 30 s, nunca usar bomba).

Estrelas desbloqueiam aeronaves, alas e as missões secretas. O mapa mostra quantas faltam em cada nó.

### 4.6 Rank dinâmico leve

Valor de 0,0 a 1,0 que sobe com tempo sem dano e nível de arma e cai ao receber dano. Afeta velocidade de bala
(±12%) e cadência inimiga (±10%). Nunca adiciona padrões. Desligado em Brisa. Visível nas opções avançadas.

### 4.7 Dificuldades

| Dificuldade | Casco | Velocidade de bala | Rank | Placar |
|---|---|---|---|---|
| Brisa | +2 | 80% | desligado | separado |
| Normal | base | 100% | ligado | principal |
| Veterano | base | 110%, padrões densos | ligado | principal |
| Abissal (final verdadeiro) | 1 segmento | 115%, balas de vingança | ligado | próprio |

### 4.8 Mecânicas especiais

**Ocean Shift.** Evento roteirizado da fase. O nível do mar sobe ou desce em 6 a 10 s, a camada de cenário troca e o
conjunto de inimigos muda. Regras: aviso de 2 s (som de onda, linha de espuma no topo), zero balas inimigas novas
durante os primeiros 1,5 s da transição, a transição nunca acontece durante um padrão de chefe. Visual: camada de água
com shader de cáustica que sobe, ruínas emergem da camada de profundidade 0,6 para 1,0.

**Gravity Breach.** Campo de força temporário (6 a 12 s). Um vetor de gravidade aplicado às balas inimigas e às do
jogador (as do jogador com 40% do efeito). Introdução no capítulo 7 em zona segura com balas lentas. Aviso: grade
distorcida no fundo e seta de direção. No núcleo (cap. 9), a arena gira 90° ou 180° com a câmera; o controle continua
relativo à tela.

**Perigos ambientais por capítulo** em 5.2.

### 4.9 Economia

| Moeda | Como ganha | Para que serve |
|---|---|---|
| **Créditos** | Toda missão (pontuação), conquistas, eventos | Subir nível de aeronave, módulos, alas |
| **Oricalco** | Medalhas, chefes, estrelas | Material para nível alto de aeronave e Ressonância |
| **Pérolas de Maré** | Conquistas, desafio diário, eventos, anúncio recompensado | Só cosméticos |

Não existe compra de moeda. Cosméticos podem ser comprados direto com dinheiro ou com Pérolas.

**Progressão permanente** (hangar): aeronave nível 1 a 10; módulos (Casco, Motor, Mira, Secundária) nível 1 a 5;
**teto de poder:** um jogador no máximo tem no máximo +35% de DPS e +1 casco em relação ao inicial. Missões mostram
"poder recomendado"; jogar abaixo dele é possível e dá bônus de pontuação.

### 4.10 Alas de apoio (coleção)

Pequenas naves que voam ao lado (2 por missão), cada uma com um efeito passivo: ímã de medalhas, escudo a cada
30 s, tiro de cobertura traseiro, +10% graze, revela Registros. 12 alas na 1.0, desbloqueadas por estrelas,
conquistas e eventos. É o sistema de coleção que dá "mais uma missão" sem vender poder.

### 4.11 Modos

| Modo | Desbloqueio | Regra |
|---|---|---|
| Campanha | início | 27 missões + 4 secretas + prólogo |
| Arcade | terminar o Ato I | Capítulos em sequência, 1 crédito, sem upgrades, placar global |
| Boss Rush | derrotar os 4 chefes | Chefes em sequência, tempo total |
| Desafio Diário | capítulo 2 | Missão gerada por semente do dia, mesma para todos, 1 tentativa pontuada |
| Sobrevivência das Marés | capítulo 4 | Ondas infinitas crescentes com bênçãos, placar (vira o roguelite Abismo Infinito no pós-lançamento) |
| Prática | ver a seção uma vez | Qualquer trecho de missão ou etapa de chefe, com velocidade ajustável |
| Segunda Maré | primeiro final | Loop 2 da campanha: balas mais rápidas, balas de vingança, chefes remendados, chefe verdadeiro |
| Abissal | final verdadeiro | Campanha em dificuldade Abissal |

---

## 5. Level design

### 5.1 Estrutura de missão

- Duração: missão comum 2 a 3 min, missão de mini-chefe 3 a 4 min, missão de chefe 4 a 5 min.
- Rolagem vertical de 18 a 30 u/s; a velocidade é parte do roteiro.
- Curva de tensão: abertura leve (20 s) → ondas crescentes → **momento da fase** (Ocean Shift, perigo, rota) →
  respiro (8 s, só medalhas) → mini-chefe ou trecho final → chefe.
- Cada missão tem **um** elemento novo ou uma combinação nova. Nenhuma missão é só "mais ondas".
- Roteiro em `data/stages/<capitulo>_<missao>.json`, eventos por tempo (ver apêndice 18.3).

### 5.2 Capítulos

| Cap. | Ambiente | Regra nova | Inimigos principais | Perigo | Momento da fase | Música |
|---|---|---|---|---|---|---|
| 1 | Oceano Atlântico | Orbes de arma, medalhas, Ocean Shift básico | Drones do Protocolo | Ondas que escondem inimigos | O mar sobe e revela a primeira ruína | Synth atmosférico |
| 2 | Atlântida submersa | Torres no cenário, escudos destrutíveis | Drones + Guarda Atlante | Correntes que empurram a nave | Corredor que se fecha (rolagem acelera) | Coral e texturas antigas |
| 3 | Tempestade | Vento lateral sobre balas e nave | Guarda Atlante | Relâmpago telegrafado em colunas | A tempestade abre e revela uma cidade suspensa | Industrial percussivo |
| 4 | Vulcões | Gêiseres de lava em colunas, calor que distorce | Bioformas | Lava (colunas com aviso de 1 s) | Erupção: a tela inteira vira rota de fuga | Percussão e metal |
| 5 | Cidade futurista | Prédios sobem como cobertura e bloqueiam balas | Mistas | Holofotes que marcam alvos | Ocean Shift urbano: a cidade sobe do mar | Synthwave |
| 6 | Região glacial | Balas que se dividem ao bater no gelo | Bioformas rápidas | Placas de gelo que caem | Avalanche de cristal | Synth frio, sinos |
| 7 | Estratosfera | **Gravity Breach** introduzida | Guarda Atlante pesada | Rarefação: menos cobertura visual | Queda livre: rolagem invertida por 15 s | Orquestra e synth |
| 8 | Órbita | Fortalezas com partes destrutíveis, detritos | Todas | Cinturão de detritos | Abordagem de fortaleza em 3 camadas | Orquestra |
| 9 | Núcleo gravitacional | Arena que gira, gravidade alternada | Formas do protocolo | Inversões de gravidade | A arena se desmonta até o chefe final | Épico orquestral eletrônico |

### 5.3 Rotas Superfície e Abismo

A partir do capítulo 3, a **missão final de cada capítulo** tem duas versões, como as zonas ramificadas de *Darius*:

| Rota | Visual | Regra | Recompensa |
|---|---|---|---|
| **Superfície** | Clara, céu aberto | Densidade normal | Pontuação normal, mais orbes |
| **Abismo** | Escura, bioluminescente | Densidade +20%, inimigos próprios, sonar como aviso | Multiplicador x1,5, mais oricalco, Registros |

Mesmos mini-chefes e chefes, com arena e roteiro diferentes. São 7 roteiros a mais, reaproveitando assets. A
escolha aparece no mapa como bifurcação e pode ser refeita. O número de missões de Abismo vencidas e de atlantes
resgatados pesa no final (3.4).

### 5.4 Missões secretas (Registros Abissais) e Glifos

Uma por ato, aberta por **Glifos atlantes**: símbolos nas ruínas do cenário que, atingidos na ordem certa, abrem uma
fenda no mapa. A ordem é ensinada aos poucos pelo Diário de Bordo (cada Registro de bordo traduz um glifo), no
espírito dos segredos de *Tyrian* e *Star Fox 64*. Cada uma tem regra única (escuridão com sonar, só Railgun, campo invertido, Ocean Shift contínuo) e
entrega 1 Registro Abissal. As 4 levam ao final verdadeiro.

### 5.5 Ondas

Formação (linha, V, coluna, círculo, onda senoidal, espiral), trajetória (`Curve2D` nomeada em
`data/paths.json`), tempo, quantidade, inimigo, drops. Regra de densidade: no máximo 120 balas inimigas vivas em
Normal fora de chefes, 300 em chefes, 600 em Abissal. O teste de fase confere esses tetos com o bot.

---

## 6. Bestiário e chefes

### 6.1 Facções

| Facção | Origem visual | Comportamento | Cor de bala |
|---|---|---|---|
| **Drones do Protocolo** | Void Fleet 1 | Enxames, formações, tiros mirados simples | Ciano |
| **Guarda Atlante** | Void Fleet 2 | Caças ágeis, padrões em leque e anel | Dourado |
| **Bioformas** | Void Fleet 3 + Ocean Creatures | Orgânicos, curvas, balas que crescem | Violeta |

Cores de bala trocam juntas nos modos de daltonismo, mantendo o contraste.

### 6.2 Inimigos (24)

| # | Nome | Facção | Cap. | HP | Movimento | Ataque |
|---|---|---|---|---|---|---|
| 1 | Esquife | Drones | 1 | 3 | Linha reta em formação | Nenhum |
| 2 | Vespa de Maré | Drones | 1 | 5 | Mergulha e sai pelas laterais | 1 bala mirada |
| 3 | Boia Sentinela | Drones | 1 | 20 | Estática no cenário | Anel de 8 balas a cada 2 s |
| 4 | Arrastão | Drones | 2 | 40 | Desce devagar | Leque de 5 |
| 5 | Torreta Coral | Drones | 2 | 30 | Presa ao cenário | Rajada de 3 miradas |
| 6 | Enxame Faísca | Drones | 3 | 2 | Bando de 12 em senoide | Nenhum, colisão |
| 7 | Couraça | Drones | 4 | 120 | Lenta, escudo frontal | Laser telegrafado |
| 8 | Semeador | Drones | 5 | 60 | Para no meio da tela | Solta minas que explodem em anel |
| 9 | Lança de Ouro | Guarda | 2 | 15 | Entra rápida, para, sai | 2 balas paralelas |
| 10 | Arauto | Guarda | 3 | 35 | Circula | Espiral curta |
| 11 | Falange | Guarda | 3 | 25 | Formação em V de 5 | Leque sincronizado |
| 12 | Caçador | Guarda | 4 | 45 | Persegue a coluna do jogador | Tiros rápidos mirados |
| 13 | Basílica | Guarda | 5 | 200 | Plataforma voadora | 3 torres destrutíveis |
| 14 | Juiz | Guarda | 6 | 90 | Teleporta (aviso 0,6 s) | Cruz de balas |
| 15 | Égide | Guarda | 7 | 150 | Protege aliados com escudo | Nenhum, prioridade de alvo |
| 16 | Trirreme | Guarda | 8 | 300 | Nave pesada lateral | Bordada de 12 |
| 17 | Lula Sonda | Bio | 1 | 8 | Salta da água | Tinta que bloqueia visão em 20% da tela por 1 s |
| 18 | Medusa Prisma | Bio | 2 | 25 | Flutua | Balas que crescem |
| 19 | Arraia Voltaica | Bio | 3 | 50 | Plana em curva | Arco elétrico curto |
| 20 | Larva de Magma | Bio | 4 | 30 | Sai de gêiser | Balas que caem com gravidade |
| 21 | Leque de Gelo | Bio | 6 | 40 | Rápida em zigue-zague | Balas que dividem |
| 22 | Sereia de Vidro | Bio | 6 | 70 | Canta (aviso sonoro) | Anel lento duplo |
| 23 | Nautilus | Bio | 7 | 160 | Gira | Espiral dupla |
| 24 | Fragmento do Protocolo | Todas | 9 | 80 | Troca de facção a cada 4 s | Padrão da facção atual |

### 6.3 Mini-chefes (9, um por capítulo)

Sentinela Abissal (prólogo), Quebra-Maré (1), Guardião de Coral (2), Olho da Tempestade (3), Forja Viva (4),
Arquiteto (5), Rainha do Gelo (6), Albatroz de Aço (7), Portão Orbital (8). Cada um com 2 etapas e 1 padrão
assinatura. Detalhe em `data/bosses/`.

### 6.4 Chefes de ato

Cada chefe é uma **máquina de estados por etapa**. Etapa muda por HP (ou por tempo, com aviso). Toda etapa abre com
1 s de transição sem balas novas, um som de "fase" e uma linha de fala. Partes destrutíveis dão pontos e mudam o
padrão.

**Kraken Engine** (Ato I, fim do cap. 2; também no Vertical Slice). 270 u de largura, emerge da água.

| Etapa | HP | Partes | Ataques |
|---|---|---|---|
| 1. Tentáculos | 35% | 6 tentáculos destrutíveis (cada um 6% do HP) | Varredura de tentáculo telegrafada; anéis das ventosas |
| 2. Couraça aberta | 35% | 2 olhos vulneráveis | Feixe que varre a tela da esquerda para a direita com lacuna; espiral dupla |
| 3. Sobrecarga | 30% | Núcleo exposto | O chefe afunda e a água sobe (Ocean Shift reverso); padrões em leque crescentes; 10 s finais de "desespero" |

**Sky Leviathan** (Ato II). Serpente de 18 segmentos que atravessa a arena.

| Etapa | Ataques |
|---|---|
| 1. Travessia | Passa pelas laterais; cada segmento solta 2 balas; cabeça faz investida telegrafada |
| 2. Tempestade | Enrola-se na arena; ataques ocupam faixas da tela (só 1 faixa segura de cada vez) |
| 3. Cauda | Segmentos se soltam e viram drones; a cabeça dispara leques |

**Poseidon Prime** (Ato III). Guardião atlante com tridente e 3 anéis de escudo.

| Etapa | Ataques |
|---|---|
| 1. Barreiras | Anéis giram; só a abertura do anel deixa o tiro passar |
| 2. Gravidade | Gravity Breach dirigida pelo chefe; balas curvas |
| 3. Tridente | Três feixes em leque que se fecham; ondas de energia |
| 4. Último guardião | Fala com Thalassa; padrão "dança" de baixa densidade e alta precisão |

**Leviathan Protocol** (Ato IV). Três formas.

| Forma | Ataques e arena |
|---|---|
| 1. Colagem | Corpo feito das três facções; troca padrão por facção |
| 2. Arquitetura | Arena gira 90° e 180°; gravidade alternada; paredes de balas com passagem |
| 3. Núcleo | Geometria pura; padrões de "bullet hell" de alta leitura; escolha do final pelo voo |

---

## 7. UI/UX: hub interativo, mapa em parallax e HUD

### 7.1 Princípios

- Retrato, uma mão. Tudo que se toca fica nos dois terços de baixo da tela.
- Alvos de toque com pelo menos 7 mm físicos (44 pt em tela média).
- Todo toque tem resposta: escala 0,95 por 80 ms, som de interface, vibração leve (opcional).
- Transições de 150 a 250 ms, interrompíveis por outro toque.
- Nada pisca sem motivo. Badge só quando há ação real.

### 7.2 Hub interativo (no estilo *Star Wars: Galaxy of Heroes*)

O menu principal é um **lugar**, não uma lista. Inspiração no modo como SWGoH transforma o menu num cenário vivo com
cartões grandes e abas. Nenhum elemento visual ou de layout é copiado.

**Cena: o Hangar da Halcyon.** Plataforma atlante iluminada, com a aeronave selecionada no centro.

| Camada | Conteúdo | Fator de parallax | Animação |
|---|---|---|---|
| 0 | Gradiente do estrato atual (abismo, céu, órbita) | 0,05 | Troca com o progresso da campanha |
| 1 | Silhuetas distantes (torres atlantes, cidades) | 0,15 | Lenta, 30 Hz |
| 2 | Paredes do hangar, cristais | 0,4 | Brilho pulsante |
| 3 | Plataforma e **aeronave** | 1,0 | Motor ligado, oscilação de 2 pt |
| 4 | Drones de manutenção, faíscas | 1,2 | Idle |
| 5 | Bolhas, poeira de luz, névoa de primeiro plano | 1,5 | Partículas leves |

**Interação com a cena:**

- Arrastar a aeronave gira ela (sprite com 8 ângulos pré-desenhados) e move as camadas em parallax.
- Tocar a aeronave abre o cartão dela no Hangar.
- Tocar o fundo solta um pulso de luz que percorre os cristais (efeito, sem função).
- Inclinação do aparelho (acelerômetro) desloca as camadas até ±6 pt. Desligado em "reduzir movimento".
- O cenário muda com o progresso: ao chegar no Ato II, o hangar está em uma ilha levitante; no Ato IV, em órbita.
- **Cidade de Thalassa:** pela janela do hangar (camada 1) se vê a cidade atlante. Cada capítulo vencido acende um
  distrito (luz, NPCs, música própria) e ergue uma estátua com o recorde do jogador contra o chefe daquele ato. Os
  atlantes resgatados aparecem nas ruas. É o progresso visível que nenhum shmup oferece.

**Estrutura da tela:**

```
┌──────────────────────────────┐
│ Perfil · Créditos · Oricalco │  barra superior (abaixo do recorte)
│ ┌──────────────────────────┐ │
│ │ Banner: Evento / Diário  │ │  carrossel horizontal, arrastar, auto 6 s
│ └──────────────────────────┘ │
│                              │
│        cena do hangar        │  parallax + aeronave interativa
│          (aeronave)          │
│                              │
│   [ JOGAR: Cap. 3 · Missão 2 ]│  botão principal, sempre na zona do polegar
│ ┌────┬────┬────┬────┬────┐   │
│ │Hang│Camp│Nave│Even│Loja│   │  abas inferiores com badges
│ └────┴────┴────┴────┴────┘   │
└──────────────────────────────┘
```

**Abas:**

| Aba | Conteúdo |
|---|---|
| **Hangar** | Aeronave atual, módulos, secundária, alas de apoio, cosméticos |
| **Campanha** | Mapa em parallax (7.3) |
| **Naves** | Coleção: cartões grandes roláveis na horizontal; o selecionado cresce 1,15x, mostra a nave animada, atributos e o que falta para desbloquear |
| **Eventos** | Desafio diário, eventos por tempo, Boss Rush, Arcade, Sobrevivência, placares |
| **Loja** | Cosméticos, recompensas de 6 h, compra única "Apoiar" |

**Painéis de recompensa:** cápsula atlante que abre com luz e partículas; moedas sobem contando até o total no topo;
toque pula a animação. A cápsula nunca tem conteúdo aleatório pago.

**Desktop e controle:** as abas viram uma coluna lateral; foco visível em todo elemento; navegação por setas e
gatilhos (LB/RB trocam abas).

### 7.3 Mapa de campanha em parallax: "Carta da Ascensão"

O mapa é uma coluna vertical contínua que **sobe do abismo à órbita**. Subir no mapa é subir na história. É a tela
onde o parallax mais aparece, pedido do usuário.

**Estratos (de baixo para cima):** Abismo da *Halcyon* (prólogo) → Oceano (1) → Atlântida submersa (2) → Céu de
tempestade (3) → Vulcões (4) → Cidade levitante (5) → Geleira suspensa (6) → Estratosfera (7) → Órbita (8) →
Núcleo (9). Cada estrato tem cerca de 1,2 tela de altura. A transição entre estratos é gradual (o azul escuro vira
céu, o céu vira estrelas).

**Camadas de parallax do mapa:**

| Camada | Conteúdo | Fator vertical | Fator de inclinação |
|---|---|---|---|
| 0 Céu/fundo | Gradiente contínuo abismo → espaço, com estrelas no topo | 0,1 | 0,2 |
| 1 Longe | Silhuetas de montanhas submarinas, ilhas, cidades, Terra vista da órbita | 0,25 | 0,4 |
| 2 Meio | Ruínas, nuvens, plumas de vulcão, satélites | 0,5 | 0,6 |
| 3 **Rota** | Nós de missão, trilha luminosa, chefes, fendas secretas | 1,0 | 1,0 |
| 4 Perto | Peixes e bolhas (embaixo), nuvens rasantes (meio), detritos (topo) | 1,35 | 1,3 |
| 5 Moldura | Vinheta e partículas de luz | fixa | 0 |

**Comportamento:**

- Rolagem por dedo com inércia e mola nas pontas; ao abrir, a câmera desliza até o próximo nó jogável.
- **Ao concluir uma missão**, a câmera sobe até o nó seguinte, a trilha acende e as camadas se movem em parallax
  (1,2 s, pulável).
- Nós: missão (círculo), mini-chefe (hexágono), chefe (selo grande com silhueta), fenda secreta (aparece só depois do
  gatilho). Cada nó mostra estrelas (0 a 4) e poder recomendado.
- O Ato II mostra três caminhos paralelos (Tempestade, Vulcões, Cidade) que se juntam no Sky Leviathan.
- A partir do cap. 3, o último nó de cada capítulo se bifurca em **Superfície** (trilha dourada, camada 3) e
  **Abismo** (trilha bioluminescente que desce para a camada 2,5, com parallax próprio e mais escura). As fendas
  dos Glifos aparecem como rachaduras de luz entre as camadas.
- **Modo foto:** congelar o mapa, esconder a interface e compartilhar o cartão da missão com as estrelas.
- Toque num nó abre um cartão: nome, objetivo da 4ª estrela, recompensas, melhor pontuação, botão Jogar.
- Inclinação do aparelho adiciona ±6 pt de deslocamento horizontal por camada (fator de inclinação).
- Desempenho: camadas 0 a 2 são texturas assadas por estrato (`StaticBake`), camada 4 é `GPUParticles2D` com no
  máximo 48 partículas, só os nós visíveis desenham. Entra no benchmark de rolagem.
- **Parallax nas fases:** o mesmo `ParallaxRig` desenha os cenários das missões (5 a 7 camadas por capítulo, ver 8.3).

### 7.4 HUD da missão

```
┌──────────────────────────────┐
│ 1.234.560   x8 ▓▓▓  ◆2  ⏸    │  pontuação, multiplicador, bombas, pausa (fora do campo em telas altas)
│ [casco ■■■] [arma ▲▲▲ Laser] │
│                              │
│        campo 270x450         │
│                              │
│ "Maré, a onda vem aí."       │  rádio: 1 linha, rodapé do campo, só nos respiros
│               (MARÉ)  (ESP)  │  Maré Alta (medidor de Pressão) e especial (anel de recarga)
│     zona do polegar          │  telas altas: abaixo do campo
└──────────────────────────────┘
```

Telas curtas (270x480) sobrepõem o HUD ao campo com fundo de 40% de opacidade e o mínimo de informação. Telas altas
tiram o HUD de cima do campo. O teste de layout garante que nada do HUD cobre mais de 6% do campo.

### 7.5 Telas

Consentimento (UMP, Play) · Título/Hub · Hangar · Naves · Campanha · Cartão de missão · Briefing curto · Missão ·
Pausa (retomar, opções, sair) · Reviver · Resultado (pontuação, estrelas, recompensas, Tentar de novo) · Diálogos e
cenas · Eventos · Placares · Loja · Diário de Bordo (registros, bestiário, chefes) · Conquistas · Opções (controles,
áudio, vídeo, acessibilidade, idioma) · Créditos · Licenças.

### 7.6 Idiomas

pt-BR (origem), en, es, de, fr, ru, id, ja, ko, zh-TW, zh-CN. Fonte Fusion Pixel 12px para texto, Kenney Fonts para
números, Orbitron só no logotipo. Textos em `i18n/strings.csv`, gerados e validados por `tools/build_i18n.py`.
Revisão por nativos antes da 1.0.

---

## 8. Direção de arte e technical art

### 8.1 Paleta

| Papel | Cor | Uso |
|---|---|---|
| Azul profundo | `#0B1E3F` | Fundos do oceano e abismo |
| Turquesa | `#1FB5A8` | Energia atlante, UI ativa |
| Ciano energético | `#3FF3FF` | Balas dos Drones, brilhos |
| Dourado atlante | `#E8B84A` | Guarda Atlante, molduras, medalhas |
| Branco intenso | `#F4FBFF` | Núcleo de balas, flashes |
| Preto vulcânico | `#151216` | Contornos, sombras, vulcões |
| Coral de alerta | `#FF5A5F` | Dano, perigo, alertas |
| Violeta bio | `#B05CFF` | Bioformas |

### 8.2 Escala e pixel

Resolução lógica base 305x678, campo 270x450. Aeronaves 48x48, inimigos 24 a 96, chefes 160 a 270, balas 6 a 16.
Sem filtro, sem escala fracionária, `snap_2d_transforms_to_pixel`.

### 8.3 Profundidade 2.5D

| Técnica | Como |
|---|---|
| Parallax | `ParallaxRig` com 5 a 7 camadas por capítulo (fundo, longe, meio, cenário de jogo, primeiro plano) |
| Entrada "do fundo" | Inimigo nasce na camada 0,6 com escala 0,6, tom azulado e sem colisão; sobe para 1,0 em 0,8 s e só então pode atirar e ser atingido. Sombra no chão quando o cenário tem chão |
| Névoa de profundidade | Shader que mistura a cor da camada com a cor do ar do capítulo pelo fator de profundidade |
| Sombra projetada | Sombras das naves no cenário, deslocadas pela "altura" |
| Primeiro plano | Nuvens, espuma e detritos acima do campo, ≤ 35% de opacidade, somem em padrões densos |
| Inclinação | Aeronaves inclinam ao mover (3 quadros), chefes têm partes em camadas que se deslocam em parallax próprio |

### 8.4 Shaders (todos em Compatibility)

`palette_tint` (unifica packs) · `water_caustics` · `ocean_shift` (água que sobe com espuma) · `energy_flow`
(cristais e linhas atlantes) · `heat_haze` (vulcão) · `ice_refraction` · `gravity_grid` (Gravity Breach) ·
`hit_flash` (branco por 2 quadros) · `dissolve` (morte de chefe) · `beam` (lasers) · `crt_scanline` (opcional,
cosmético).

### 8.5 Game feel

- **Hitstop** de 2 a 4 quadros na morte de inimigo grande e 8 quadros na troca de etapa do chefe (a simulação pausa
  de forma determinística).
- **Tremor de tela** proporcional ao evento, com teto e opção de desligar.
- Flash branco no inimigo atingido, números de pontos pequenos, faíscas na direção do tiro.
- Coleta de orbe: anel que expande, som crescente, a arma muda visivelmente no mesmo quadro.
- Morte de chefe: 2 s de explosões em cadeia, câmera lenta de 0,5 s, tela branca de 3 quadros, chuva de medalhas.

### 8.6 Regras de desenho

As de [qualidade.md](../docs/policies/qualidade.md): balas em `MultiMeshInstance2D`, nada de `draw_polygon` por
quadro, camadas fixas assadas, partículas com teto por qualidade.

---

## 9. Áudio

### 9.1 Música

| Contexto | Direção | Fonte |
|---|---|---|
| Tema principal "Return the Sky" | Leitmotiv de 4 notas | Criar |
| Hub e mapa | Ambiente com coral atlante, muda por estrato | Criar + CC0 |
| Cap. 1 Oceano | Synth atmosférico | CC0 (catálogo) |
| Cap. 2 Atlântida | Coral e texturas antigas | Criar |
| Cap. 3 Tempestade | Industrial percussivo | CC0 / 🔶 CC-BY-3.0 |
| Cap. 4 Vulcões | Percussão e metal | CC0 |
| Cap. 5 Cidade | Synthwave | CC0 |
| Cap. 6 Glacial | Synth frio com sinos | Criar |
| Cap. 7 Estratosfera e 8 Órbita | Orquestra e sintetizadores | CC0 (Albesca) |
| Cap. 9 e chefe final | Orquestral épico eletrônico | Criar |
| Chefes | Variações do leitmotiv | Criar + CC0 |

Música em camadas onde for criada pelo projeto: camada base, camada de percussão que entra com o mini-chefe, camada
de tensão no chefe. Troca de faixa sempre no compasso.

### 9.2 Efeitos

Categorias com pool próprio e limite de vozes: tiro do jogador (por arma, 4 vozes), tiro inimigo (por facção,
6 vozes), acerto, explosão (3 tamanhos), coleta, nível de arma, graze, especial pronta, alerta de chefe, Ocean Shift,
Gravity Breach, interface. Variação de pitch ±5% para não cansar.

### 9.3 Mixagem

Buses: Master → Música, Efeitos (Jogador, Inimigo, Impacto), Interface, Vozes. Ducking da música em −6 dB nas falas
e alertas. Volume padrão: música 70%, efeitos 85%.

---

## 10. Arquitetura técnica

### 10.1 Estrutura de pastas

```
project.godot  export_presets.cfg  gdlintrc
scenes/        app/App.tscn  hub/Hub.tscn  map/CampaignMap.tscn  game/Game.tscn
scripts/
  autoload/    events, game_clock, pixel_scaler, settings, save_manager, db, locale,
               audio_manager, ads_manager, purchase_manager, shop_manager, platform, log
  sim/         sim_state, player_sim, weapon_sim, bullet_pool, spatial_hash, pattern_runner,
               pattern_dsl, stage_script, wave_spawner, boss_brain, scoring, rank, rng_streams,
               state_hash, gravity_field, ocean_shift
  view/        bullet_renderer (MultiMesh), entity_view, parallax_rig, depth_layer, camera_fx,
               hitstop_view, fx/
  app/screens/ hub_screen, map_screen, hangar_screen, ships_screen, events_screen, shop_screen,
               result_screen, options_screen, credits_screen, licenses_screen, logbook_screen
  app/ui/      touch_scroll, card_rail, banner_carousel, tab_bar, static_bake, stroke, menu_kit,
               transition_director, reward_capsule
  bot/         bot_pilot
data/          ships, weapons, secondaries, specials, wings, enemies, paths, patterns/*,
               stages/*, bosses/*, dialogue, logs, shop, achievements, events
i18n/          strings.csv
shaders/  assets/  licenses/  tests/  tools/  docs/
```

### 10.2 Autoloads

Mesmo conjunto do hyakki, mais `Platform` (abstrai Play e Steam: conquistas, placares, nuvem, compras) e `Log`.

### 10.3 Simulação e visualização separadas

- `Sim` é um `RefCounted` puro que avança em passo fixo de 1/60 s. Não conhece nós.
- `Game.tscn` lê o estado e desenha, interpolando posições entre passos.
- Velocidade 2x e 3x: 2 ou 3 passos por quadro (para testes e acessibilidade em Brisa; não afeta placar).
- **Determinismo:** um `RandomNumberGenerator` por fluxo (ondas, drops, padrões), semeados a partir da semente da
  missão. `StateHash` combina posição, HP e pontuação de tudo a cada segundo. O mesmo `--seed` precisa dar o mesmo
  hash em 1x, 2x, 3x e em qualquer qualidade gráfica.
- Hitstop pausa a simulação por N passos de forma registrada (faz parte do estado).

### 10.4 Projéteis

`BulletPool`: arrays paralelos (`PackedVector2Array` posição e velocidade, `PackedFloat32Array` raio, ângulo,
tempo, `PackedInt32Array` tipo e dono), capacidade fixa de 2.048 inimigos e 512 do jogador, sem alocação depois do
aquecimento. Colisão por `SpatialHash` (célula de 24 u). Desenho por `BulletRenderer` com um
`MultiMeshInstance2D` por textura.

### 10.5 DSL de padrões de tiro

Padrões em JSON interpretados pelo `PatternRunner`, sem código por padrão.

```json
{
  "id": "kraken_suction_rings",
  "bullet": "orb_cyan_m",
  "steps": [
    {"op": "ring", "count": 16, "speed": 60, "offset_deg": 0},
    {"op": "wait", "frames": 10},
    {"op": "rotate", "deg": 11.25},
    {"op": "repeat", "from": 0, "times": 6},
    {"op": "aimed_fan", "count": 5, "spread_deg": 40, "speed": 90},
    {"op": "wait", "frames": 45}
  ]
}
```

Operações: `ring`, `fan`, `aimed`, `aimed_fan`, `spiral`, `line`, `beam` (com `warn_frames`), `spawn` (filhos),
`wait`, `rotate`, `accel`, `curve`, `split_on_hit`, `repeat`, `random_jitter` (sempre do fluxo de RNG da missão).
Todo padrão com `beam` ou primeiro uso numa luta exige `warn_frames ≥ 30` (0,5 s); o teste de chefes confere.

### 10.6 Roteiro de fase

`StageScript` lê `data/stages/*.json` e emite eventos por tempo de missão: `wave`, `ocean_shift`, `gravity_breach`,
`hazard`, `dialogue`, `scroll_speed`, `music_layer`, `miniboss`, `boss`, `checkpoint`, `secret_trigger`.
Ver apêndice 18.3.

### 10.7 Chefes

`BossBrain` é uma máquina de estados por etapa definida em `data/bosses/<id>.json`: partes (HP, hitbox, sprite),
etapas (gatilho, padrões em sequência ou aleatório ponderado com RNG da missão, movimento), transições (hitstop,
fala, música). Ver apêndice 18.4.

### 10.8 Escala e área de jogo

`PixelScaler` (do hyakki, com regra por orientação):

- Retrato: `k = max(1, min(round(largura / 300), floor(altura / 480)))`.
- Paisagem: `k = max(1, floor(altura / 540))`.

O campo de 270x450 fica no topo da área segura (abaixo do HUD em telas altas), centralizado na horizontal. A sobra
lateral recebe a moldura do capítulo em parallax; a sobra de baixo é a zona do polegar. Detalhes e tabela em
[testes.md](../docs/policies/testes.md).

### 10.9 Save

`user://save.json` com `version`, backup rotativo (3), escrita atômica (arquivo temporário e troca), migrações
`migrate_vN_to_vN1` testadas. Nuvem: Steam Cloud no PC; no Android, Backup do Android (como no hyakki). Conteúdo:
progresso, estrelas, moedas, hangar, coleção, opções, placares locais, estatísticas.

### 10.10 Qualidade gráfica

| Ajuste | Baixa | Média | Alta |
|---|---|---|---|
| Camadas de parallax | 3 | 5 | 7 |
| Partículas por efeito | 25% | 60% | 100% |
| Shaders de cenário | só cor | cáustica simples | todos |
| Primeiro plano | desligado | 1 camada | 2 camadas |

A qualidade nunca muda a simulação (coberto pelo teste de determinismo).

---

## 11. Android, Steam e aparelhos

### 11.1 Android

- Export com Gradle, **AAB** para a Play, APK para teste manual; arm64-v8a (+ x86_64 só para emulador).
- `screen/orientation` retrato com sensor (permite girar 180°), modo imersivo, `min_sdk` 24, `target_sdk` exigido
  pela Play na data da publicação.
- Pacote provisório `io.github.netstart.atlantisascension`.
- Plugins: AdMob (Poing, MIT), Play Billing (MIT), Backup do Android (como no hyakki). Atrás de `AdsManager` e
  `PurchaseManager` com provedor simulado até o Beta.
- Meta: 60 fps estáveis na qualidade Média em aparelho de entrada (Galaxy A05 / Moto G04) e na Alta no aparelho de
  referência.

### 11.2 Steam

- Windows x86_64 e Linux x86_64, `GodotSteam` (MIT) como GDExtension, Steamworks SDK (`LicenseRef-Steamworks`).
- Conquistas (40), placares (por missão no Arcade, Boss Rush, Desafio Diário, Sobrevivência), Steam Cloud,
  Steam Input com glifos (Kenney Input Prompts), Rich Presence ("Capítulo 4 · Vulcões").
- **Steam Deck:** 1280x800 lógico, texto legível, glifos de controle, sem teclado obrigatório, alvo Deck Verified.
- Janela paisagem com campo 9:16 central; opção de girar o monitor (modo retrato nativo, "tate").

### 11.3 Teste manual

Emulador (AVD Redmi Note 14 Pro+), Steam Deck e aparelhos físicos só para teste manual, conforme
[testes.md](../docs/policies/testes.md).

---

## 12. Assets e licenças

Catálogo completo, status de cada licença, destino dos downloads e o que criar: [02-catalogo-assets-licencas.md](02-catalogo-assets-licencas.md).

Resumo:

- **Base:** série Void (Foozle, CC0) para naves, frotas, ambiente e pickups.
- **Complementos:** Kenney (CC0) para peças de nave, partículas, UI, ícones, fontes, SFX e jingles; Ocean Creatures
  (CC-BY-4.0); fundos CC0 da OpenGameArt; música CC0 do catálogo.
- **Criado pelo projeto (MIT):** 4 chefes de ato e 9 mini-chefes por partes, 12 aeronaves por kitbash, balas e
  lasers, tileset das ruínas atlantes, shaders de água, energia, calor, gelo e gravidade, retratos, ícones de arma,
  trilha principal e variações de chefe.
- **Pendente de decisão do mantenedor:** ratificar CC-BY-3.0 e OGA-BY-3.0 (comuns em música da OpenGameArt).

Processo de entrada: [licencas.md](../docs/policies/licencas.md). Downloads em `c:\src\downloads\assets\`.

---

## 13. Roadmap

Cada fase termina com `tools/run_checks.ps1` em `TUDO OK`, versão marcada e checklist em
[03-progresso-implementacao.md](03-progresso-implementacao.md).

### Fase 0 — Fundação (semanas 1 e 2) · `0.0.x`

- Instalar Godot 4.7.2 e templates em `C:\src\tools\godot`, `gdtoolkit` 4, JDK 17, Android SDK.
- `project.godot` (Compatibility, retrato, stretch viewport, `untyped_declaration=2`), `export_presets.cfg` (Android,
  Windows, Linux), `gdlintrc`.
- Portar do hyakki, adaptando: `PixelScaler` (regra por orientação), `MenuKit`, `TouchScroll`, `StaticBake`,
  `Stroke`, `SpatialHash`, `SaveManager`, `Locale`, `AudioManager`, `DB`, `GameClock`, `tests/device_profiles.gd`,
  `tests/run_tests.gd`, `tools/run_checks.ps1`, `tools/check_licenses.py`, `tools/build_license_index.py`,
  `tools/sync_assets.py`, `tools/build_i18n.py`. Código do hyakki é do mesmo autor; registrar a origem.
- Baixar os assets do Vertical Slice (lista em 02, seção 12) para `c:\src\downloads\assets\` e registrar licenças.
- Critério de pronto: projeto abre, testes vazios passam em todas as resoluções, checagem de licenças verde.

### Fase 1 — Vertical Slice (semanas 3 a 6) · `0.1.0`

- Semana 3 (**protótipo jogável**): `Sim`, `BulletPool`, `PatternRunner`, nave Falcon com Pulsar, 3 inimigos, rolagem
  e parallax de 5 camadas do cap. 1, bot de teste, determinismo.
- Semana 4: orbes e níveis de arma (Pulsar e Laser), medalhas, corrente, graze, queima-roupa, pérolas, HUD, casco,
  resultado, juice completo (hitstop, tremor, flash, som em camadas), avisos sonoros de perigo.
- Semana 5: missão 1-1 completa com Ocean Shift no compasso, mini-chefe Quebra-Maré, **Kraken Engine** com 3 etapas
  e duelo de raio no golpe final; rádio só nos respiros.
- Semana 6: hub mínimo (cena do hangar com parallax e aeronave interativa, botão Jogar, abas Hangar e Campanha), mapa
  com os 3 nós do cap. 1, SFX, trilha temporária, pt-BR e en, APK.
- Critério de pronto: 10 pessoas jogam a missão; a missão leva 3 a 5 min; o chefe é vencido por 50% a 70% delas na
  2ª tentativa; 60 fps no aparelho de referência; layout aprovado em todas as resoluções.

### Fase 2 — Alpha (semanas 7 a 14) · `0.5.0`

- Capítulos 1 a 3 completos (9 missões, 3 mini-chefes), Plasma e Railgun, secundárias, 4 especiais, 4 aeronaves.
- Hub completo (5 abas, banners, cartões de naves, recompensa), mapa em parallax com os estratos 0 a 3.
- Economia, hangar, estrelas, alas de apoio (6), aeronaves por fragmentos, save com migração, opções, 11 idiomas.
- **Bênçãos das Marés** (18), **Maré Alta**, tutorial de pontuação, estrutura das rotas Superfície e Abismo,
  assistência com regra de conquistas, simulação da economia pelo bot (teste obrigatório).
- Diário de Bordo, cenas do prólogo e Ato I, primeira missão secreta, Cidade de Thalassa estática no hub.
- Protótipo descartável do "mergulho entre camadas" para decidir se entra no pós-lançamento.
- Critério de pronto: retenção do playtest (jogadores voluntariamente jogam mais de 30 min na primeira sessão);
  economia sem bloqueio (todo jogador termina o cap. 3 sem repetir missão mais de 3 vezes).

### Fase 3 — Beta (semanas 15 a 24) · `0.9.0`

- Capítulos 4 a 9, Sky Leviathan, Poseidon Prime, Leviathan Protocol, os 3 finais, 4 missões secretas.
- 6 aeronaves, 12 alas, 6 especiais, Gravity Breach, todos os perigos.
- Modos Arcade, Boss Rush, Desafio Diário, Sobrevivência, Prática.
- Rotas de Abismo (7), Glifos, resgate de cápsulas com combo, distritos da Cidade de Thalassa, captura biomecânica,
  Gravity Breach com bônus Redemoinho, chefe que lembra, Kraken remendado, Leviathan Protocol que aprende.
- Login de 7 dias com proteção, 3 diárias e 5 semanais, Núcleo de Oricalco.
- Tutorial completo, acessibilidade, modos de daltonismo, qualidade gráfica.
- Otimização (60 fps em entrada na Média), benchmark de partida e de rolagem verdes.
- Monetização simulada (Loja, recompensas de 6 h, reviver, dobrar créditos), build Steam com GodotSteam.
- Critério de pronto: campanha completa jogável do começo ao fim pelo bot e por 5 pessoas; nenhum bloqueio de
  progressão; nenhum crash em 20 h de teste manual.

### Fase 4 — Lançamento (semanas 25 a 30) · `1.0.0`

- Play Console: ficha, classificação etária, segurança de dados, teste fechado (20 testadores por 14 dias, exigência
  da Play para contas pessoais novas), AdMob real com UMP, Play Billing real.
- Steam: página, cápsulas, trailer, conquistas, placares, Deck Verified, Next Fest se a data permitir.
- Política de privacidade, `app-ads.txt`, créditos públicos.
- Traduções: as 11 línguas saem como estão; não haverá revisão por nativos (decisão do mantenedor, 31/10/2026).
- Segunda Maré, Fantasma do Abismo (replay do melhor e do 1º do dia), placares com replay anexado, Correntes
  semanais, passe de temporada (grátis + cosmético), modo foto do mapa.
- Critério de pronto: aprovado nas duas lojas; crash-free ≥ 99,5% no teste fechado; D1 ≥ 40% no teste fechado.

### Pós-lançamento

Aeronaves 7 a 12 (uma por atualização `1.x.0`), Abismo Infinito (roguelite), Ecos dos Caídos e Elevação Global
(precisam de backend leve), Casas Atlantes (guildas), mergulho entre camadas se o protótipo aprovar, novo capítulo
bônus, co-op local (2 jogadores no PC), modo retrato "tate" na Steam.

---

## 14. Plano de testes

Política completa em [testes.md](../docs/policies/testes.md). Resumo do que este jogo precisa testar:

| Tipo | Exemplos |
|---|---|
| Unitários | Dano, pontuação, corrente, graze, medalhas, rank, economia, teto de poder, DSL de padrões, roteiro de fase, migração de save |
| Integração | Todos os JSON carregam e se referenciam; todo sprite, som e música existe; 11 idiomas com glifos; loja e recompensas |
| E2E (só Godot) | Bot joga cada missão até o fim; campanha inteira pelo bot em 3x; hub → mapa → missão → resultado → hangar |
| Layout | Todas as telas, o hub, o mapa e o HUD em todas as resoluções de `tests/device_profiles.gd`, com recorte em cima e embaixo |
| Parallax | Camadas determinísticas, ordem de profundidade, reduzir movimento |
| Desempenho | Benchmark de rolagem (hub, mapa, listas) e de partida (1.000 balas + 150 inimigos + chefe) |
| Determinismo | Mesmo hash em 1x, 2x, 3x e qualidade Baixa |
| Leitura | Contraste das balas em capturas de cada capítulo e de cada modo de daltonismo |
| Chefes | Toda etapa alcançável; aviso ≥ 0,5 s; nenhuma configuração sem espaço seguro (o bot com "visão perfeita" sobrevive a todos os padrões sem bomba) |
| Licenças | `check_licenses.py` e teste da tela de créditos |
| Economia | `tests/economy_sim_tests.gd`: o bot joga a campanha com habilidade média; no máximo 2 missões jogadas até o próximo upgrade até o cap. 6; teto de poder respeitado |
| Bênçãos | Toda combinação de 2 bênçãos tem efeito válido; nenhuma ultrapassa o teto de DPS da missão |
| Replay | Gravar entrada + semente e reproduzir dá o mesmo hash e a mesma pontuação |

Teste manual (emulador, Deck, aparelhos): sensação de controle, conforto do polegar, leitura sob sol, aquecimento e
bateria em 30 min de jogo, interrupções (ligação, notificação, girar 180°).

---

## 15. Critérios de qualidade e metas de balanceamento

Regras de código, arte, áudio e definição de pronto em [qualidade.md](../docs/policies/qualidade.md). Metas
mensuradas pelo bot e por playtest:

| Métrica | Meta |
|---|---|
| Duração da missão comum | 2 a 3 min |
| Duração da luta com chefe de ato | 90 a 150 s |
| Vitória na 1ª tentativa, missão comum, Normal | 70% a 85% |
| Vitória na 1ª tentativa, chefe de ato, Normal | 30% a 50% |
| Vitória até a 3ª tentativa, chefe de ato, Normal | ≥ 80% |
| Repetições para avançar sem grind (jogador médio) | ≤ 3 por missão |
| Tempo até a 1ª aeronave nova | ≤ 25 min |
| Tempo até terminar a campanha em Normal | 6 a 9 h |
| Tempo até o final verdadeiro | 12 a 18 h |
| Latência do toque | ≤ 1 passo de simulação |
| Quadro p95 em partida | ≤ 8 ms (Alta, PC de teste) |

Diversão é medida por playtest: "jogaria mais uma?" ≥ 80% de sim depois de cada missão no Vertical Slice.
Metas de retenção (D1 ≥ 40%, D7 ≥ 15%, D30 ≥ 6%) e as referências de mercado estão em
[04-pesquisa-mercado-e-retencao.md](04-pesquisa-mercado-e-retencao.md#8-metas-de-retenção).

---

## 16. Riscos e mitigação

| Risco | Impacto | Mitigação |
|---|---|---|
| Visual de colcha de retalhos | Alto | Um pack base (Void), shader de paleta, regras de contorno, revisão de arte por capítulo |
| Licenças a confirmar (Void Fleet 1 e 3, Pickups) | Médio | Confirmar antes de baixar; plano B com Kenney recolorido |
| Desempenho de balas em aparelho de entrada | Alto | MultiMesh, pool fixo, qualidade gráfica, benchmark obrigatório |
| Falta de ferramentas na máquina (Godot, SDK, JDK) | Médio | Fase 0 dedicada; script de instalação documentado |
| Escopo (27 missões, 13 chefes) | Alto | Vertical Slice primeiro; roteiros em JSON; chefes por partes; cortar Sobrevivência e alas extras antes de cortar qualidade |
| Música autoral | Médio | Começar o leitmotiv na Fase 1; CC0 como reserva |
| Políticas da Play (anúncios, público) | Médio | UMP, sem anúncio na missão, classificação 10+, sem coleta além do necessário |
| Teste fechado exigido pela Play | Médio | Recrutar 20+ testadores na Fase 3 |
| Steam Deck e controle | Baixo | Input por ações desde a Fase 0; testes de layout em 1280x800 |
| Semelhança com jogos de referência | Médio | Nada de arte, nome ou UI deles; revisão antes da 1.0 |

---

## 17. Monetização

**Google Play (grátis):**

- **Anúncio recompensado opcional** em três lugares: reviver 1 vez por missão, dobrar créditos no resultado,
  recompensas da Loja a cada 6 h.
- **Nenhum anúncio** durante a missão, na abertura ou entre telas. Nenhum intersticial.
- **Cosméticos:** pinturas de aeronave, rastros de motor, cores de tiro do jogador (dentro dos limites de leitura),
  temas do hub, molduras de perfil. Compra direta ou com Pérolas ganhas jogando.
- **Compra única "Apoiar a Halcyon"** (~US$ 3,99): recompensas da Loja sem anúncio, reviver sem anúncio, tema
  dourado do hub.
- Nada de energia, gacha pago, moeda vendida ou vantagem de poder.
- Conformidade: UMP para consentimento, classificação etária, Data Safety, `app-ads.txt`.

**Steam (premium, preço-alvo US$ 9,99):** jogo completo, sem anúncios, com os cosméticos da 1.0 desbloqueáveis
jogando. Pacote de trilha sonora opcional (só faixas criadas pelo projeto).

---

## 18. Apêndices

### 18.1 Fórmulas

```
dano_final   = dano_base(arma, nível) × (1 + 0,035 × nível_módulo_mira) × mult_dificuldade
pontos_abate = valor_inimigo × multiplicador_corrente × (1 + 0,5 × sem_dano)
corrente     = +1 por abate se t − t_último_abate ≤ 0,8 s; multiplicador = min(16, 1 + floor(corrente / 8))
graze        = bala com distância ≤ 8 u da hitbox, contada 1 vez por bala
rank         = clamp(rank + 0,002 por segundo sem dano + 0,05 por nível de arma − 0,25 por dano, 0, 1)
vel_bala     = vel_base × (1 + 0,12 × (rank − 0,5) × 2) × mult_dificuldade
hp_inimigo   = hp_base × (1 + 0,18 × (capítulo − 1))
créditos     = 50 + floor(pontuação / 2.000) + 25 × estrelas_novas
```

### 18.2 Resoluções

Fonte única: tabela de [testes.md](../docs/policies/testes.md) e `tests/device_profiles.gd`.

### 18.3 Template de missão

```json
{
  "id": "c1m1",
  "chapter": 1,
  "name_key": "STAGE_C1M1",
  "music": "mus_ocean_a",
  "scroll_speed": 22,
  "parallax": "ch1_ocean",
  "seed_salt": 101,
  "stars": [
    {"type": "clear"},
    {"type": "no_hull_loss"},
    {"type": "kill_marked", "percent": 100},
    {"type": "rescue", "count": 5}
  ],
  "events": [
    {"t": 0.0, "op": "dialogue", "id": "c1m1_intro"},
    {"t": 2.0, "op": "wave", "enemy": "skiff", "formation": "line5", "path": "straight_down", "x": 0.5},
    {"t": 6.0, "op": "wave", "enemy": "tide_wasp", "formation": "v5", "path": "dive_left", "drops": ["orb_blue"]},
    {"t": 48.0, "op": "ocean_shift", "to": "ruins_rising", "warn": 2.0, "duration": 8.0},
    {"t": 58.0, "op": "secret_trigger", "id": "buoy_1", "x": 0.2},
    {"t": 120.0, "op": "music_layer", "layer": "percussion", "on": true},
    {"t": 128.0, "op": "miniboss", "id": "tidebreaker"},
    {"t": 175.0, "op": "checkpoint"}
  ]
}
```

### 18.4 Template de chefe

```json
{
  "id": "kraken_engine",
  "name_key": "BOSS_KRAKEN_ENGINE",
  "music": "mus_boss_kraken",
  "hp": 6000,
  "parts": [
    {"id": "tentacle_1", "hp": 360, "hitbox": [-110, 40, 18], "on_destroy": "drop_medal"},
    {"id": "eye_l", "hp": 0, "hitbox": [-40, -20, 14], "active_in": ["armor_open"]}
  ],
  "phases": [
    {"id": "tentacles", "until_hp": 0.65, "patterns": ["kraken_sweep", "kraken_suction_rings"], "order": "sequence"},
    {"id": "armor_open", "until_hp": 0.30, "intro": {"hitstop": 8, "dialogue": "kraken_p2"},
     "patterns": ["kraken_beam_sweep", "kraken_double_spiral"], "order": "weighted", "weights": [2, 1]},
    {"id": "overload", "until_hp": 0.0, "intro": {"hitstop": 8, "event": "ocean_shift_reverse"},
     "patterns": ["kraken_fans_growing"], "desperation_after_s": 50}
  ]
}
```

### 18.5 Conquistas (amostra das 40)

Primeira onda · Sem arranhões (missão sem dano) · Corrente x16 · Colecionador de oricalco (medalha de 10.000) ·
Rasante (500 grazes numa missão) · Quebra-ondas (Kraken Engine sem bomba) · Ordem livre (terminar o Ato II na ordem
inversa) · Registros abissais (4/4) · Maré alta (final verdadeiro) · Um crédito (Arcade sem continuar) · Hangar cheio
(6 aeronaves) · Ala completa (12 alas).

---

## 19. Profundidade, retenção e o que torna o jogo viciante (da pesquisa)

Análise completa, tabelas comparativas, evidências e fontes em
[04-pesquisa-mercado-e-retencao.md](04-pesquisa-mercado-e-retencao.md). Aqui fica só o que entra no jogo e como.

### 19.1 O que a pesquisa mudou

| Descoberta | Evidência | Decisão |
|---|---|---|
| Variedade dentro da partida rende mais que anúncio | Wing Fighter: D7 17,8% e ARPDAU 6x o do Galaxy Attack | Bênçãos das Marés (19.3) |
| Explosão de poder escolhida pelo jogador vicia | Hyper (DoDonPachi), Break (Crimzon Clover), Kakusei (Espgaluda) | Maré Alta (19.2) |
| Rotas e segredos fazem rejogar | Darius, Star Fox 64, Tyrian | Superfície e Abismo (5.3), Glifos (5.4) |
| Grind é a crítica nº 1 | Sky Force, Galaxy Attack, Survivor.io | Simulação da economia pelo bot, teto de poder, varrer missões |
| Falar durante as balas é punido | Raiden V: Mixed | Rádio só nos respiros (3.5) |
| D30 vem de conteúdo recorrente e social | SWGoH: D30 4,5% mesmo com o melhor núcleo | Diárias, Correntes semanais, fantasma, Ecos (19.5) |
| História com reviravolta segura o jogador | ZeroRanger ~96% positivo | Finais, Thalassa, o protocolo que aprende |

### 19.2 Maré Alta

- **Medidor de Pressão** (0 a 100): graze +1, abate à queima-roupa +3, cada 8 de corrente +5. Decai 2 por segundo
  sem graze.
- **Cheio:** o botão MARÉ brilha na zona do polegar (tecla própria no PC, gatilho direito no controle).
- **Ativo por 8 s:** o mar sobe na tela (shader de água em 20% de opacidade, nunca cobre as balas), multiplicador x2,
  dano +25%, balas a menos de 48 u no início viram pérolas e toda bala que tocar o escudo de água vira pérola.
- **Custo:** rank +0,1 e o medidor zera. Não acumula com a bomba.
- **Por que funciona:** o jogador escolhe quando arriscar. Guardar a Maré Alta para o chefe ou gastar para limpar
  uma onda é a decisão que separa iniciante de veterano.

### 19.3 Bênçãos das Marés

Em **2 respiros de cada missão** (cerca de 1/3 e 2/3 do roteiro, e antes do chefe nas missões de chefe), o jogo
desacelera para 10% e mostra **3 cartões**. O jogador escolhe 1. A bênção vale só até o fim da missão. Oferta
gerada pelo RNG da missão (no Desafio Diário, a mesma oferta para todos).

| Deus | Domínio | Bênçãos |
|---|---|---|
| **Proteu** | Ataque e forma | Lâmina de Corrente (+15% dano) · Eco Duplo (1 tiro extra a cada 5) · Ressaca (abates explodem em área pequena) · Arpão (secundária perfura) · Fúria Crescente (+2% dano por abate até +20%, perde ao levar dano) · Maré Viva (Maré Alta +3 s) |
| **Tétis** | Proteção e vida | Bolha (absorve 1 acerto) · Escama (+1 segmento de casco) · Refluxo (ao levar dano, cancela balas próximas) · Calmaria (+0,5 s de invulnerabilidade) · Abraço de Coral (cada 300 grazes recuperam 1 segmento) · Âncora (modo preciso mais lento, hitbox −20%) |
| **Nereu** | Pontuação e sorte | Ímã de Pérolas · Sorte do Pescador (+25% de orbes) · Mapa das Correntes (revela Glifos) · Rede (medalhas não se perdem na borda) · Velho Marinheiro (corrente dura 1,0 s) · Oráculo (mostra a próxima onda 1 s antes) |

**Sinergias:** 2 bênçãos do mesmo deus ativam um efeito extra (Proteu: arma +1 nível; Tétis: escudo a cada 45 s;
Nereu: multiplicador começa em x2). Com o terceiro cartão do mesmo deus na missão de chefe, o efeito vira
**Avatar** (visual dourado na nave). Os deuses são da mitologia grega, de domínio público, reinterpretados como
patronos atlantes. Poseidon fica de fora para não confundir com Poseidon Prime.

**Equilíbrio:** a soma das bênçãos respeita o teto de DPS da missão (teste automatizado). Arcade usa as bênçãos com
a mesma semente para todos; Prática permite escolher.

### 19.4 Os ciclos de jogo

| Escala | O que prende | Sistemas |
|---|---|---|
| **Segundos** | Desviar, grazar, encadear, ver a arma crescer | Graze, corrente, queima-roupa, pérolas, juice, avisos sonoros |
| **Minutos** | A missão muda e o chefe é um evento | Ocean Shift no compasso, Bênçãos, Maré Alta, chefes em etapas, duelo de raio |
| **Sessão** | "Só mais uma" para a estrela que faltou | 4 estrelas, missão curta, Tentar de novo sem anúncio, resultado com o que faltou |
| **Dias** | Voltar amanhã | Desafio Diário com fantasma, 3 diárias, login com proteção, recompensas de 6 h |
| **Semanas** | Algo novo no fim de semana | Correntes semanais, 5 semanais, passe de temporada, aeronave nova por fragmentos |
| **Meses** | Dominar e completar | Rotas de Abismo, Glifos, 3 finais, Segunda Maré, Abissal, placares com replay, Cidade de Thalassa completa |

### 19.5 Social sem tempo real

Tudo por replay determinístico (log de entrada + semente, poucos KB), sem servidor de partida:

- **Fantasma do Abismo** (1.0): o melhor replay do jogador ou o 1º do dia nada atrás dele, translúcido. Passar à
  frente dá bônus. Na Steam o replay vai anexado ao placar (UGC); na Play, nos placares do Play Games Services.
- **Ecos dos Caídos** (pós): quem cai numa missão deixa um eco preso numa bolha na partida de outro jogador.
  Resgatar dá presente aos dois. Precisa de backend leve.
- **Elevação Global** (pós): meta comunitária semanal que ergue uma torre no hub. Backend leve.
- **Casas Atlantes** (pós): guildas de até 30 com meta cooperativa.

O backend do pós-lançamento é uma decisão separada (custo, privacidade, LGPD/GDPR) e fica fora da 1.0.

### 19.6 Carta de ética

Viciante no sentido de "quero jogar mais", nunca de "não consigo parar". O jogo:

1. Nunca pune quem não paga: toda aeronave, ala, rota, final e modo se ganha jogando.
2. Nunca vende aleatório: sem gacha, sem caixa paga, sem moeda vendida.
3. Nunca interrompe: sem intersticial, sem energia, sem anúncio na missão; no máximo 8 anúncios recompensados por dia,
   sempre por botão.
4. Nunca ameaça perda pesada: sequência de login com proteção, eventos que voltam, nada some para sempre.
5. Sempre mostra o caminho: o resultado diz o que faltou e o mapa diz onde está cada estrela.
6. Sempre respeita o tempo: missão de 2 a 5 min, pausa automática, varrer missões já dominadas.

### 19.7 Onde cada sistema entra

Prioridade e fase de todos os sistemas: tabela da seção 5 de [04](04-pesquisa-mercado-e-retencao.md#5-o-que-implementar-priorizado).
Já refletidos no roadmap (seção 13) e no checklist [03](03-progresso-implementacao.md).
