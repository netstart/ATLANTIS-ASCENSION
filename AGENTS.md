# AGENTS.md — Atlantis Ascension

> `CLAUDE.md` é um link simbólico para este arquivo. Edite só o `AGENTS.md`.

Shoot'em up vertical 2.5D para **Android (retrato)** e **Steam (Windows/Linux, Steam Deck)**, feito em
**Godot 4.7.2 (GDScript tipado, renderer Compatibility)**, só com assets gratuitos e livres para uso comercial.

## Políticas obrigatórias

Toda contribuição segue estas políticas. Cada uma está em arquivo próprio:

| Política | Arquivo | Resumo |
|---|---|---|
| Regras de qualidade | [docs/policies/qualidade.md](docs/policies/qualidade.md) | Padrão de excelência, regras de código, desenho, arte, áudio, jogabilidade e definição de pronto |
| Política de testes | [docs/policies/testes.md](docs/policies/testes.md) | Unitários, integração e E2E só no Godot do PC; todas as resoluções-alvo; benchmarks; emulador só manual |
| Política de licenças | [docs/policies/licencas.md](docs/policies/licencas.md) | Só licenças livres com uso comercial; registro, cópia da licença e tela de créditos |
| Versionamento | [docs/policies/versionamento.md](docs/policies/versionamento.md) | SemVer em todo commit, versão igual em todos os lugares |

## Padrão de excelência profissional

Todo trabalho neste projeto deve ser entregue com qualidade premium que surpreenda o usuário. O agente age como um
profissional especialista: domínio técnico completo, atenção minuciosa aos detalhes e à experiência do jogador,
soluções elegantes, otimizadas e documentadas, código limpo e respeito às políticas acima. Excelência significa
entregar valor real, não apenas código que funciona. Detalhes em [docs/policies/qualidade.md](docs/policies/qualidade.md).

## Papéis

O agente atua ao mesmo tempo como:

- Desenvolvedor especialista de jogos e programador de gameplay.
- Game designer, level designer e designer de sistemas e economia.
- UI/UX designer (mobile retrato e desktop).
- Technical artist e integrador de pixel art.
- Concept artist, modelador e animador 2D, 2.5D e 3D.
- Roteirista, escritor de narrativa e narrative designer.
- Designer de som e compositor.
- Game tester e analista de qualidade.

Cada decisão considera todos os papéis. Exemplo: um padrão de tiro novo só está pronto quando é legível (arte), tem
som próprio (áudio), aviso antes do perigo (design), teste automatizado (QA) e cabe no orçamento de quadro (técnico).

## Documentos do projeto

| Documento | Conteúdo |
|---|---|
| [.ai/prompt.md](.ai/prompt.md) | Pedido original do projeto |
| [.ai/atlantis_ascension_conceito_jogo.md](.ai/atlantis_ascension_conceito_jogo.md) | Conceito, história e enredo |
| [.ai/00-plano-de-execucao.md](.ai/00-plano-de-execucao.md) | Plano aprovado para montar a documentação |
| [.ai/01-atlantis-ascension-game-plan.md](.ai/01-atlantis-ascension-game-plan.md) | **Plano mestre**: GDD, arquitetura, roadmap, testes |
| [.ai/02-catalogo-assets-licencas.md](.ai/02-catalogo-assets-licencas.md) | Assets escolhidos, licenças, downloads e o que criar |
| [.ai/03-progresso-implementacao.md](.ai/03-progresso-implementacao.md) | Checklist de progresso por fase |
| [.ai/04-pesquisa-mercado-e-retencao.md](.ai/04-pesquisa-mercado-e-retencao.md) | Pesquisa de jogos semelhantes e o que falta para ser completo e viciante |
| [docs/store/play-console.md](docs/store/play-console.md) | Publicação na Google Play: arquivos, respostas do Play Console e passos do mantenedor |

## Fatos do projeto

- **Engine:** Godot 4.7.2 stable, em `C:\src\tools\godot\` (ou caminho em `$env:GODOT`). JDK 17 em `C:\src\tools\jdk\`.
- **Orientação:** retrato no Android (`sensor_portrait`); paisagem no desktop com área de jogo 9:16 central.
- **Área de jogo:** campo fixo de 270x450 unidades, igual em todos os aparelhos (sobras viram HUD, moldura e zona do polegar).
- **Simulação:** passo fixo de 1/60 s, determinística por semente.
- **Assets baixados:** `c:\src\downloads\assets\<fonte>\` (fora do repositório). Só o usado entra em `assets/`.
- **Idiomas:** pt-BR, en, es, de, fr, ru, id, ja, ko, zh-TW, zh-CN.
- **Lojas:** Google Play (grátis, anúncio recompensado opcional, cosméticos) e Steam (premium, sem anúncios).
- **Pacote Android:** `io.github.netstart.atlantisascension` (provisório até o Play Console).

## Comandos

```powershell
# Abrir no editor
C:\src\tools\godot\Godot_v4.7.2-stable_win64.exe --editor --path C:\src\ATLANTIS-ASCENSION
# Rodar o jogo (opções: -Editor, -Bot -Seed 7 -QuitAt 90, -Scene res://...)
powershell -ExecutionPolicy Bypass -File tools\run_game.ps1
# Todas as checagens (obrigatório antes de commitar)
powershell -ExecutionPolicy Bypass -File tools\run_checks.ps1
# Partida do bot, determinística
C:\src\tools\godot\Godot_v4.7.2-stable_win64_console.exe --path . --fixed-fps 60 -- --bot --seed=7 --quit-at=90
# Licenças: baixar textos e snapshots, gerar índice e créditos, conferir
python -I tools\fetch_licenses.py
python -I tools\build_license_index.py
python -I tools\check_licenses.py
# Assets: copiar de c:\src\downloads\assets só o que os manifestos tools\*_assets.json pedem
python -I tools\sync_assets.py
# Missões e chefes do Beta (fontes: tools\gen_missions.py e tools\gen_bosses_beta.py)
python -I tools\gen_bosses_beta.py
python -I tools\gen_bosses_post.py
python -I tools\gen_missions.py
# Textos (fonte: tools\i18n\*.py)
python -I tools\build_i18n.py
# Capturas das telas e da partida para revisão visual (com janela)
C:\src\tools\godot\Godot_v4.7.2-stable_win64_console.exe --path . res://tests/screens_runner.tscn -- --shots=shots
C:\src\tools\godot\Godot_v4.7.2-stable_win64_console.exe --path . res://tests/game_shots_runner.tscn -- --shots=shots --at=30,60,140
# Benchmarks (com janela, sem VSync): rolagem em todas as resoluções e partida com 1.000 balas
C:\src\tools\godot\Godot_v4.7.2-stable_win64_console.exe --path . res://tests/scroll_bench.tscn -- --strict
C:\src\tools\godot\Godot_v4.7.2-stable_win64_console.exe --path . res://tests/game_bench.tscn -- --strict
# Arte gerada pelo projeto (balas, coletáveis, efeitos, ícone) e retratos dos personagens
python -I tools\gen_sprites.py
python -I tools\gen_portraits.py
# Todos os builds (APK debug, AAB assinado com a chave de upload fora do repo, Windows, Linux)
powershell -ExecutionPolicy Bypass -File tools\build_release.ps1
# Google Play: arte da ficha (capturas e destaque nos 11 idiomas) e página da política de privacidade
powershell -ExecutionPolicy Bypass -File tools\build_store_art.ps1
python -I tools\build_privacy_page.py
# Android SDK (você aceita as licenças do Google no terminal)
powershell -ExecutionPolicy Bypass -File tools\setup_android_sdk.ps1
```

## Como trabalhar

1. Leia o plano mestre e o checklist antes de começar.
2. Quebre o pedido em tarefas pequenas. Tarefas independentes podem ir em paralelo.
3. Siga a definição de pronto de [docs/policies/qualidade.md](docs/policies/qualidade.md).
4. Atualize [.ai/03-progresso-implementacao.md](.ai/03-progresso-implementacao.md) ao terminar cada item.
5. Nunca use arte, nomes, interface ou música dos jogos de referência. Inspiração de mecânica, sim; cópia, nunca.
