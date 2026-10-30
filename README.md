# Atlantis Ascension

*The ocean remembers. The sky belongs to whoever survives.*

Shoot'em up vertical 2.5D sobre a Atlântida que desperta em 2147. Feito em Godot 4.7.2 para Android (retrato) e
Steam, só com assets gratuitos e livres para uso comercial.

**Estado:** Fase 0 concluída (versão 0.0.1): projeto Godot, pipeline de licenças e testes em todas as
resoluções-alvo. Próximo passo: Vertical Slice. O export Android depende de `tools\setup_android_sdk.ps1`.

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

## Checagens

```powershell
powershell -ExecutionPolicy Bypass -File tools\run_checks.ps1
```

## Licença

Código sob licença MIT ([LICENSE](LICENSE)). Assets de terceiros com suas licenças em `licenses/`, listadas em
`CREDITS.md` e na tela de créditos do jogo.
