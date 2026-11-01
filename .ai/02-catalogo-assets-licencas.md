# Atlantis Ascension — Catálogo de assets e licenças

> Data: 30/10/2026. Fonte principal: catálogo [awsome-free-assets-to-games](https://github.com/netstart/awsome-free-assets-to-games)
> (`assets/*.md`) e pesquisa complementar nesta data. Regras: [docs/policies/licencas.md](../docs/policies/licencas.md).

## Legenda

- ✅ **Confirmada**: licença lida na página de origem ou no catálogo com verificação registrada.
- ⚠️ **Confirmar ao baixar**: licença provável, mas a página não foi lida nesta pesquisa ou o catálogo não registra.
  Só entra no jogo depois de virar ✅.
- 🔶 **A ratificar**: licença permissiva fora da lista base (CC-BY-3.0, OGA-BY-3.0, `LicenseRef-`). Depende de
  decisão do mantenedor.
- ❌ **Rejeitado**: fora da política.

Destino de todo download: `c:\src\downloads\assets\<fonte>\<pack>.zip`, com o snapshot PDF da página ao lado
(`<pack>_<data>.pdf`). Só os arquivos usados vão para `assets/` via `tools/sync_assets.py`.

## Estratégia de arte

**Um pack base dita o estilo.** A série **Void** da Foozle (pixel art espacial, CC0) cobre nave do jogador com
motores, escudos e armas animados, três frotas inimigas com efeitos, ambiente e pickups, tudo no mesmo traço. As três
frotas viram as três facções do jogo. Tudo o que vier de outros packs passa pelo shader de paleta unificada
(`shaders/palette_tint.gdshader`) para casar com a paleta atlante (azul profundo, turquesa, ciano, dourado, branco,
preto vulcânico).

| Facção no jogo | Frota Void | Leitura temática |
|---|---|---|
| **Drones do Protocolo** | Fleet Pack 1 — Kla'ed | Máquinas oceânicas do Leviathan Protocol |
| **Guarda Atlante** | Fleet Pack 2 — Nairan | Caças de cerâmica e ouro da Atlântida desperta |
| **Bioformas** | Fleet Pack 3 — Nautolan | Criaturas biomecânicas, orgânicas e luminosas |

## 1. Nave do jogador e aeronaves

| Asset | Autor | URL | Licença | Status | Destino | Uso |
|---|---|---|---|---|---|---|
| Void — Main Ship | Foozle | https://foozlecc.itch.io/void-main-ship | CC0-1.0 | ✅ baixado 30/10 | `foozle/void-main-ship.zip` | Falcon (nave inicial): casco, motores, escudo e armas animados |
| Pixel Shmup | Kenney | https://kenney.nl/assets/pixel-shmup | CC0-1.0 | ✅ baixado 30/10 (License.txt CC0) | `kenney/pixel-shmup.zip` | Bases para recolorir e montar as aeronaves 2 a 12, power-ups, ícones de HUD |
| Space Shooter Redux (Remastered) | Kenney | https://kenney.nl/assets/space-shooter-remastered | CC0-1.0 | ✅ baixado 30/10 (License.txt CC0) | `kenney/space-shooter-remastered.zip` | Partes de nave (asas, cockpits, motores) para kitbash das 12 aeronaves |
| Space Shooter Extension | Kenney | https://kenney.nl/assets/space-shooter-extension | CC0-1.0 | ✅ baixado 30/10 (License.txt CC0) | `kenney/space-shooter-extension.zip` | Partes extras, estações, peças de chefe |
| Space Pack | Odi Studio | https://odistudio-games.itch.io/space-pack | CC-BY-4.0 | ✅ catálogo | `odistudio/space-pack.zip` | Reserva de naves 8/16-bit (crédito obrigatório) |

**Criar:** as 12 aeronaves não existem prontas num estilo só. Montar por **kitbash** (peças Kenney + Void) em
Aseprite/LibreSprite, 48x48 px, 3 quadros de inclinação (esquerda, centro, direita) + 4 quadros de motor. Cada
aeronave ganha silhueta própria (ver seção 4.2 do plano mestre). Arte original do projeto, MIT.

## 2. Inimigos

| Asset | Autor | URL | Licença | Status | Destino | Uso |
|---|---|---|---|---|---|---|
| Void — Fleet Pack 1 (Kla'ed) | Foozle | https://foozlecc.itch.io/void-fleet-pack-1 | CC0-1.0 | ✅ baixado 30/10 | `foozle/void-fleet-pack-1.zip` | 8 inimigos dos Drones do Protocolo |
| Void — Fleet Pack 2 (Nairan) | Foozle | https://foozlecc.itch.io/void-fleet-pack-2 | CC0-1.0 | ✅ baixado 30/10 | `foozle/void-fleet-pack-2.zip` | 8 inimigos da Guarda Atlante |
| Void — Fleet Pack 3 (Nautolan) | Foozle | https://foozlecc.itch.io/void-fleet-pack-3 | CC0-1.0 | ✅ baixado 30/10 | `foozle/void-fleet-pack-3.zip` | 8 inimigos das Bioformas |
| Alien UFO Pack | Kenney | https://kenney.nl/assets/alien-ufo-pack | CC0-1.0 | ✅ catálogo | `kenney/alien-ufo-pack.zip` | Variações de drones, cápsulas de resgate |
| Ocean Creatures | michael-jay-rov | https://michael-jay-rov.itch.io/ocean-creatures | CC-BY-4.0 | ✅ baixado 30/10 | `michael-jay-rov/ocean-creatures.zip` | Fauna do capítulo 1, partes orgânicas do Kraken Engine |

As seis páginas Void declaram CC0 e "No generative AI was used" (snapshots em `docs/licenses/`). Os zips não trazem arquivo de licença; vale a página.

## 3. Chefes

Nenhum pack gratuito traz os quatro chefes do conceito. **Criar todos**, montados por partes:

| Chefe | Base | Técnica |
|---|---|---|
| Kraken Engine | Casco das peças Space Shooter Extension + olhos e ventosas de Ocean Creatures | Corpo em sprites; 6 tentáculos como cadeias de segmentos (`Line2D` assada não, `Sprite2D` por segmento com cinemática inversa simples), pontos fracos como nós próprios |
| Sky Leviathan | Segmentos de Void Fleet 3 repetidos | Serpente de 18 segmentos seguindo uma curva; cabeça e cauda únicas |
| Poseidon Prime | Peças douradas da Void Fleet 2 + tridente desenhado | Figura central + 3 anéis orbitais de escudo; barreiras por shader |
| Leviathan Protocol | Colagem das três facções | 3 formas; a última é um núcleo geométrico com distorção de shader |

Escala: 160 a 270 px de largura (60% a 100% da largura do campo).

## 4. Projéteis e efeitos visuais

| Asset | Autor | URL | Licença | Status | Destino | Uso |
|---|---|---|---|---|---|---|
| Particle Pack | Kenney | https://kenney.nl/assets/particle-pack | CC0-1.0 | ✅ baixado 30/10 (License.txt CC0) | `kenney/particle-pack.zip` | Faíscas, brilhos, rastros, impactos |
| Smoke Particles | Kenney | https://kenney.nl/assets/smoke-particles | CC0-1.0 | ✅ baixado 30/10 (License.txt CC0) | `kenney/smoke-particles.zip` | Fumaça de dano, vapor, explosões |
| Void — Pickups Pack | Foozle | https://foozlecc.itch.io/void-pickups-pack | CC0-1.0 | ✅ baixado 30/10 | `foozle/void-pickups-pack.zip` | Power-ups, medalhas de oricalco, cristais |
| Five Free Pixel Explosions | Untied Games | https://untiedgames.itch.io/five-free-pixel-explosions | CC-BY com cláusula "não revender o asset" | ⚠️ | `untiedgames/five-free-pixel-explosions.zip` | Explosões grandes (só se a cláusula for compatível) |

**Criar:** balas inimigas (6 formas x 4 cores, 8 a 16 px, contorno claro e núcleo saturado), lasers contínuos
(shader de feixe), explosões de chefe (sequência de sprites + partículas + flash), efeito de graze, ondas do Ocean
Shift, distorção do Gravity Breach. Balas e lasers são desenhados pelo projeto, MIT, para garantir a leitura.

## 5. Cenários e parallax

| Asset | Autor | URL | Licença | Status | Destino | Uso |
|---|---|---|---|---|---|---|
| Void — Environment Pack | Foozle | https://foozlecc.itch.io/void-environment-pack | CC0-1.0 | ✅ catálogo | `foozle/void-environment-pack.zip` | Estruturas espaciais, capítulos 7 a 9 |
| Simple Space | Kenney | https://kenney.nl/assets/simple-space | CC0-1.0 | ✅ catálogo | `kenney/simple-space.zip` | Módulos de base e corredor (fortalezas, núcleo) |
| Planets | Kenney | https://kenney.nl/assets/planets | CC0-1.0 | ✅ catálogo | `kenney/planets.zip` | Terra vista da órbita, luas, camadas de fundo |
| Background Elements (e Remastered) | Kenney | https://kenney.nl/assets/background-elements | CC0-1.0 | ✅ catálogo | `kenney/background-elements.zip` | Nuvens, montanhas, props de parallax |
| Space Ship Shooter Pixel Art Assets | ansimuz | OpenGameArt (título no catálogo) | CC0-1.0 | ⚠️ URL exata a registrar | `ansimuz/space-ship-shooter.zip` | Fundos de parallax prontos para shmup vertical |
| Warped Caves Pixel Art Pack | ansimuz | OpenGameArt (título no catálogo) | CC0-1.0 | ⚠️ URL exata a registrar | `ansimuz/warped-caves.zip` | Ruínas submersas, cavernas do capítulo 2 |
| 3 Layer Parallax Star and Nebula Field | Screaming Brain Studios | OpenGameArt (título no catálogo) | CC0-1.0 | ⚠️ URL exata a registrar | `screamingbrain/parallax-star-nebula.zip` | Fundo dos capítulos 8 e 9 e do mapa |
| Planet Surface Backgrounds / Skyboxes | Screaming Brain Studios | OpenGameArt (título no catálogo) | CC0-1.0 | ⚠️ URL exata a registrar | `screamingbrain/planet-surface.zip` | Céus de tempestade, vulcão, glacial |

**Criar (shaders e procedural, MIT):** superfície do oceano com cáusticas, espuma e reflexo; água que sobe no Ocean
Shift; nuvens de tempestade com relâmpago; lava com calor; gelo com refração; aurora da estratosfera; malha
gravitacional do núcleo. Tiles das ruínas atlantes: desenhar 1 tileset de 32x32 (pedra, ouro, cristal) e recolorir.

## 6. Interface

| Asset | Autor | URL | Licença | Status | Destino | Uso |
|---|---|---|---|---|---|---|
| UI Pack Sci-fi | Kenney | https://kenney.nl/assets/ui-pack-sci-fi | CC0-1.0 | ✅ baixado 30/10 (License.txt CC0) | `kenney/ui-pack-sci-fi.zip` | Painéis, barras, botões do hub e do HUD |
| UI Pack | Kenney | https://kenney.nl/assets/ui-pack | CC0-1.0 | ✅ catálogo | `kenney/ui-pack.zip` | Controles genéricos |
| Game Icons (e Expansion) | Kenney | https://kenney.nl/assets/game-icons | CC0-1.0 | ✅ baixado 30/10 (License.txt CC0) | `kenney/game-icons.zip` | Ícones de menu, abas, opções |
| Input Prompts (e Pixel) | Kenney | https://kenney.nl/assets/input-prompts | CC0-1.0 | ✅ baixado 30/10 (License.txt CC0) | `kenney/input-prompts.zip` | Teclado, controle e Steam Deck |
| Cursor Pack | Kenney | https://kenney.nl/assets/cursor-pack | CC0-1.0 | ✅ catálogo | `kenney/cursor-pack.zip` | Cursor no desktop |

**Criar:** cartões do hub (moldura de cerâmica com filete dourado), banners de evento, ícones das 7 armas e das 12
aeronaves (renderizados a partir dos próprios sprites), retratos dos 3 personagens falantes (64x64, 3 expressões).
Alternativa para retratos: *Galaxy Legacy: Sci-Fi Pixel Portrait Pack* (SakPix,
https://sakpix.itch.io/galaxy-legacy-sci-fi-pixel-portrait-pack-free-may-the-4th-edition), licença custom com uso
comercial: 🔶, só com decisão registrada.

## 7. Fontes

| Fonte | Autor | URL | Licença | Status | Uso |
|---|---|---|---|---|---|
| Fusion Pixel 12px | TakWolf | https://github.com/TakWolf/fusion-pixel-font | OFL-1.1 | ✅ no jogo (release 2026.10.16) | Texto em todos os 11 idiomas (latim, cirílico, CJK, hangul) |
| Kenney Fonts | Kenney | https://kenney.nl/assets/kenney-fonts | CC0-1.0 | ✅ baixado 30/10 (License.txt CC0) | Números do HUD, pontuação |
| Orbitron | Matt McInerney | https://fonts.google.com/specimen/Orbitron | OFL-1.1 | ⚠️ | Título e logotipo (só latim) |

## 8. Efeitos sonoros

| Asset | Autor | URL | Licença | Status | Destino | Uso |
|---|---|---|---|---|---|---|
| Sci-fi Sounds | Kenney | https://kenney.nl/assets/sci-fi-sounds | CC0-1.0 | ✅ baixado 30/10 (License.txt CC0) | `kenney/sci-fi-sounds.zip` | Lasers, motores, escudo, especial |
| Impact Sounds | Kenney | https://kenney.nl/assets/impact-sounds | CC0-1.0 | ✅ baixado 30/10 (License.txt CC0) | `kenney/impact-sounds.zip` | Acertos, destruição, dano |
| Interface Sounds | Kenney | https://kenney.nl/assets/interface-sounds | CC0-1.0 | ✅ baixado 30/10 (License.txt CC0) | `kenney/interface-sounds.zip` | Toques, abas, cartões do hub |
| UI Audio | Kenney | https://kenney.nl/assets/ui-audio | CC0-1.0 | ✅ catálogo | `kenney/ui-audio.zip` | Confirmação, cancelamento |
| Digital Audio | Kenney | https://kenney.nl/assets/digital-audio | CC0-1.0 | ✅ baixado 30/10 (License.txt CC0) | `kenney/digital-audio.zip` | Power-up, nível de arma, alerta |
| Music Jingles | Kenney | https://kenney.nl/assets/music-jingles | CC0-1.0 | ✅ baixado 30/10 (License.txt CC0) | `kenney/music-jingles.zip` | Vitória, derrota, recompensa |
| Space Laser, Chunky Explosion | OpenGameArt | título no catálogo | CC0-1.0 | ⚠️ URL exata a registrar | `opengameart/` | Variações de tiro e explosão |
| Laser Fire | OpenGameArt | título no catálogo | CC-BY-3.0 | 🔶 | `opengameart/` | Só se CC-BY-3.0 for ratificada |
| rain and thunders | kindland | https://opengameart.org/content/rain-and-thunders | CC0-1.0 | ✅ baixado 01/11 (1.13) | `opengameart/rain-and-thunders/` | Três trovões recortados e a base da tempestade em laço (`tools/cut_weather_audio.py`) |
| Underwater Ambient Pad | isaiah658 | https://opengameart.org/content/underwater-ambient-pad | CC0-1.0 | ✅ baixado 01/11 (1.13) | `opengameart/underwater-ambient-pad/` | Pad grave da água turva e funda |
| 30 CC0 SFX loops (rain, noise_01, water_flowing) | rubberduck | https://opengameart.org/content/30-cc0-sfx-loops | CC0-1.0 | ✅ já registrado; 3 laços novos (1.13) | `opengameart/30-cc0-sfx-loops/` | Chuva fina, vento e água correndo do clima |

**Criar (sfxr/jsfxr, ChipTone, Audacity, MIT):** alerta de chefe "WARNING" sem voz, som de graze, carga da especial,
Ocean Shift (onda subindo), Gravity Breach (grave descendente), voz atlante (síntese granular sobre coral).

## 9. Música

| Faixa / pack | Autor | URL | Licença | Status | Uso |
|---|---|---|---|---|---|
| Outer Space Music Pack ("A Long Journey", "Starless Sky", "Barren Planets") | Albesca | https://albesca.itch.io/outer-space-music-pack | CC0-1.0 | ✅ catálogo | Estratosfera, órbita, mapa |
| 8-bit Epic Space Shooter Music | HydroGene | https://opengameart.org/content/8-bit-epic-space-shooter-music | CC0-1.0 | ✅ baixado 30/10 | Missões dos capítulos 1 a 3 (Vertical Slice) |
| Space Shooter (Loop) | Pro Sensory | OpenGameArt (título no catálogo) | CC0-1.0 | ⚠️ URL a registrar | Missões |
| futureshmup | OpenGameArt | título no catálogo | CC0-1.0 | ⚠️ URL a registrar | Cidade futurista |
| Epic Boss Battle (Seamlessly Looping) | Juhani Junkala (SubspaceAudio) | https://opengameart.org/content/boss-battle-music | CC0-1.0 | ✅ baixado 30/10 | Kraken Engine (Vertical Slice) |
| Battle Music, Massive Battle, War Theme | OpenGameArt | títulos no catálogo | CC0-1.0 | ⚠️ URL a registrar | Chefes e mini-chefes |
| Another space background track, Outer Space Loop, Space 5 | OpenGameArt | títulos no catálogo | CC0-1.0 | ⚠️ URL a registrar | Hub e menus |
| Space Dimensions (Techno) | Matthew Pablo | OpenGameArt | CC-BY-3.0 | 🔶 | Tempestade |
| Space Boss Battle Theme | OpenGameArt | título no catálogo | CC-BY-3.0 | 🔶 | Leviathan Protocol |

**Criar (compor, MIT):** tema principal "Return the Sky" (leitmotiv de 4 notas que volta em todo capítulo), coral
atlante para as ruínas e o hub, e as variações de cada chefe a partir do leitmotiv. Ferramentas livres: LMMS,
Surge XT, BeepBox. A trilha original é o maior ganho de identidade e o item de áudio com maior prioridade de criação.

## 10. Tecnologia e lojas

| Componente | URL | Licença | Status |
|---|---|---|---|
| Godot Engine 4.7.2 | https://godotengine.org/license | MIT | ✅ (mesma entrada do hyakki) |
| Android Jetpack (AndroidX) | https://developer.android.com/jetpack/androidx | Apache-2.0 | ✅ (mesma entrada do hyakki) |
| Poing Godot AdMob | registro do hyakki | MIT | ✅ (Beta em diante) |
| GodotGooglePlayBilling | registro do hyakki | MIT | ✅ (Beta em diante) |
| Google Mobile Ads SDK, Play Billing Library | registro do hyakki | `LicenseRef-` | 🔶 decisão já tomada no hyakki; copiar |
| GodotSteam | https://github.com/GodotSteam/GodotSteam | MIT | ⚠️ |
| Steamworks SDK | partner.steamgames.com | `LicenseRef-Steamworks` | 🔶 |

## 10b. Chefes de meio de fase (pesquisa de 31/10/2026, versão 1.10)

Licença conferida na página de cada asset; baixados em `c:\src\downloads\assets\opengameart\<pack>\` e extraídos
em `x/`. Todos CC0.

| Asset | Autor | URL | Uso |
|---|---|---|---|
| Animated Explosions | Luis Zuno (ansimuz) | https://opengameart.org/content/animated-explosions | ✅ Explosões 80/128/192 px nas peças e quedas de chefe |
| 80 CC0 creature SFX (1 e 2) | rubberduck | https://opengameart.org/content/80-cc0-creature-sfx | ✅ Rugido e rosnado dos chefes criatura |
| 30 CC0 SFX loops | rubberduck | https://opengameart.org/content/30-cc0-sfx-loops | ✅ Alarme dos chefes de meio de fase |
| Electricity Game Sound Pack | faxcorp | https://opengameart.org/content/electricity-game-sound-pack | ✅ Estrondo de queda de chefe |
| NES Shooter Music | SketchyLogic | https://opengameart.org/content/nes-shooter-music-5-tracks-3-jingles | ✅ Tema do chefe intermediário |
| Alien / SpaceShip / UFO Boss Sets | The_Scientist___ | https://opengameart.org/content/alien-boss-set | ⏸️ Baixados, não usados: desenho liso, destoa da pixel art Void |
| Dragon 1 | Master484 | https://opengameart.org/content/dragon-1 | ⏸️ Vista lateral, não serve à câmera de cima |
| Explosion Sets 1 e 2 | Master484 | https://opengameart.org/content/explosion-set-1-m484-games | ⏸️ Reserva para explosões menores |
| Top Down Tentacle Creature | Sean Noonan | https://opengameart.org/content/top-down-tentacle-creature | ⏸️ Reserva para um chefe criatura futuro |
| Underwater Diving Pack (só a arte) | ansimuz | https://opengameart.org/content/underwater-diving-pack | ⏸️ Reserva (minas); a música do pacote não tem licença |
| Boss Battle #2, Doomsday Laser Cannon, "!" HUD | nene, TAD, Hazmat Harry | ver `asset_research` da sessão | ⏸️ Reserva |

## 11. Rejeitados

| Asset | Motivo |
|---|---|
| CraftPix freebies (ex.: https://free-game-assets.itch.io/ocean-and-clouds-free-pixel-art-backgrounds, explosões) | Licença custom "não revender", fora da lista |
| https://disruptorart.itch.io/tiny-ships-free-spaceships | Custom, proíbe revenda e NFT |
| https://axassets.itch.io/spaceship-simple-assets | Custom, proíbe revenda |
| https://xyezawr.itch.io/free-pixel-effects-pack-4-explosions | Custom, "não revender" |
| https://greatdocbrown.itch.io/1bitspace | CC-BY-SA-4.0 (viral) |
| https://doranarasi.itch.io/shmup-bgm-pack, https://kosmocat.itch.io/space-train-journey | "Livre comercial" sem licença padrão |
| Páginas itch do ansimuz *Space Backgrounds* e *Spaceship Shooter Environment* | Sem licença declarada (usar as versões CC0 da OpenGameArt) |
| Starship Pilot, Science Officer e semelhantes (Justin Nichol) | CC-BY-SA-3.0 / GPL |
| StendhalGame Kraken, anglerfish/jellies de rapidpunches, kit de naves do Skorpio | CC-BY-SA / GPL |
| BDragon1727 effects | Custom, proíbe redistribuição |
| "12 Public Domain Boss Sprites" | Feitos com transferência de estilo, origem incerta |
| Remastered Tyrian | Arte de jogo comercial |
| Qualquer asset de Galaxy Attack, Star Wars: Galaxy of Heroes, Raiden e demais referências | Propriedade intelectual de terceiros |

## 12. Ordem de download

**Estado em 30/10/2026:** itens 1 a 5 baixados e registrados em `licenses/registry.json` (20 componentes).

Para o Vertical Slice, só estes, na ordem:

1. Void — Main Ship, Fleet Pack 1, Fleet Pack 2, Pickups Pack, Environment Pack (confirmar licença de cada um).
2. Kenney: Pixel Shmup, Space Shooter Remastered, Particle Pack, Smoke Particles, UI Pack Sci-fi, Game Icons,
   Input Prompts, Kenney Fonts, Sci-fi Sounds, Impact Sounds, Interface Sounds, Digital Audio, Music Jingles.
3. Ocean Creatures (CC-BY-4.0, crédito obrigatório).
4. Fusion Pixel (copiar do hyakki com a entrada de registro).
5. Duas faixas CC0 da OpenGameArt para missão e chefe, com URL exata registrada.
