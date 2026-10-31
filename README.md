# Atlantis Ascension

*The ocean remembers. The sky belongs to whoever survives.*

Shoot'em up vertical 2.5D sobre a Atlântida que desperta em 2147. Feito em Godot 4.7.2 para Android (retrato) e
Steam, só com assets gratuitos e livres para uso comercial.

**Estado:** 1.0.0 (código de lançamento pronto; contas das lojas pendentes, ver
[docs/store/release-checklist.md](docs/store/release-checklist.md)): Segunda Maré, Correntes semanais, replays e
Fantasma do recorde, placares, Passe da Maré, 22 conquistas e modo foto, sobre a campanha completa de 9 capítulos (37 missões, 7 rotas de Abismo, 4 missões
secretas), 8 mini-chefes, 4 chefes de ato e 3 finais; 6 aeronaves, 12 asas, 18 Bênçãos, Maré Alta, Gravity Breach;
modos Arcade, Boss Rush, Desafio Diário, Sobrevivência e Prática; login, tarefas e Núcleo; Cidade de Thalassa; loja e
anúncios simulados; daltonismo e escala de texto; 11 idiomas. O export Android depende de
`tools\setup_android_sdk.ps1`.

## Documentação

- Plano mestre (GDD, arquitetura, roadmap, testes): [.ai/01-atlantis-ascension-game-plan.md](.ai/01-atlantis-ascension-game-plan.md)
- Catálogo de assets e licenças: [.ai/02-catalogo-assets-licencas.md](.ai/02-catalogo-assets-licencas.md)
- Progresso: [.ai/03-progresso-implementacao.md](.ai/03-progresso-implementacao.md)
- Pesquisa de mercado e retenção: [.ai/04-pesquisa-mercado-e-retencao.md](.ai/04-pesquisa-mercado-e-retencao.md)
- Regras para agentes e contribuidores: [AGENTS.md](AGENTS.md)

## Rodar no PC

```powershell
C:\src\tools\godot\Godot_v4.7.2-stable_win64.exe --path C:\src\ATLANTIS-ASCENSION
```

## Capturas para revisão visual

```powershell
C:\src\tools\godot\Godot_v4.7.2-stable_win64_console.exe --path . res://tests/screens_runner.tscn -- --shots=shots --res=305x678,960x540
```

## Jogar direto uma missão (você ou o bot)

```powershell
C:\src\tools\godot\Godot_v4.7.2-stable_win64.exe --path . -- --mission=c1m1
C:\src\tools\godot\Godot_v4.7.2-stable_win64.exe --path . -- --bot --seed=7
```

Controles no PC: arrastar com o mouse ou WASD/setas, Shift para modo preciso, K especial, L bomba, Esc pausa.

## Checagens

```powershell
powershell -ExecutionPolicy Bypass -File tools\run_checks.ps1
```

## Licença

Código sob licença MIT ([LICENSE](LICENSE)). Assets de terceiros com suas licenças em `licenses/`, listadas em
`CREDITS.md` e na tela de créditos do jogo.
