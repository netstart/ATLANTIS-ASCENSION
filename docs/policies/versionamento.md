# Versionamento (SemVer, obrigatório em todo commit)

> Referenciado por [AGENTS.md](../../AGENTS.md). Origem: seção "Versionamento" do `AGENTS.md` do projeto
> [hyakki](https://github.com/netstart/hyakki/blob/main/AGENTS.md), adaptada para Android + Steam.

A versão do jogo segue o [Versionamento Semântico](https://semver.org/lang/pt-BR/) no formato
`MAIOR.MENOR.CORREÇÃO` (ex.: `1.4.12`).

## Onde fica a versão

Todos os lugares precisam ter sempre o mesmo valor:

- `project.godot`: `config/version="X.Y.Z"`.
- `export_presets.cfg`: `version/name="X.Y.Z"` no preset Android.
- `export_presets.cfg`: `version/code=N` no preset Android. É o versionCode do Android, um inteiro que só sobe.
- `export_presets.cfg`: `application/file_version` e `application/product_version` no preset Windows (formato
  `X.Y.Z.0`).
- Presets Linux e demais: o nome do arquivo exportado leva a versão (`build/atlantis-ascension-X.Y.Z-linux.x86_64`).

`tests/version_tests.gd` confere que todos os lugares concordam. Falha reprova o commit.

## Regra automática, em todo commit

1. Antes de cada commit, aumente o último número (`CORREÇÃO`) em 1 (ex.: `1.0.0` para `1.0.1`) e o `version/code`
   em 1.
2. Inclua essas alterações no próprio commit.
3. Faça isso **sem avisar e sem perguntar**: é rotina, não precisa de confirmação nem de menção na resposta.

## Quando mudar MAIOR ou MENOR

A IA pode decidir mudar esses números quando a mudança justificar, seguindo o SemVer:

- `MENOR` (ex.: `1.4.12` para `1.5.0`): conteúdo ou funcionalidade nova que mantém a compatibilidade, como um
  capítulo, uma aeronave, um chefe, um modo ou um sistema novo.
- `MAIOR` (ex.: `1.5.0` para `2.0.0`): mudança que quebra a compatibilidade, como um save antigo que não carrega mais
  sem migração, ou uma mudança grande de regras ou economia.
- Ao subir `MENOR`, a `CORREÇÃO` volta a 0. Ao subir `MAIOR`, `MENOR` e `CORREÇÃO` voltam a 0. O `version/code`
  continua subindo 1, sem zerar.

Nesse caso a IA **deve avisar** na resposta e na mensagem do commit qual número mudou (de, para) e por quê.

## Versões de marco (pré-1.0)

| Marco | Versão | Conteúdo |
|---|---|---|
| Fase 0 concluída | `0.0.x` | Projeto Godot, pipeline de licenças, testes e checagens rodando |
| Vertical Slice | `0.1.0` | 1 aeronave, 1 missão completa, Kraken Engine, hub mínimo, APK |
| Alpha | `0.5.0` | 3 capítulos, 4 aeronaves, hangar, economia, 11 idiomas |
| Beta | `0.9.0` | 9 capítulos, 4 chefes de ato, 6 aeronaves, build Steam, monetização simulada |
| Lançamento | `1.0.0` | Play Store e Steam |

## Mensagem de commit

Conventional Commits (`feat:`, `fix:`, `perf:`, `test:`, `docs:`, `chore:`, `refactor:`), em português, com a versão
no rodapé: `Versão: 0.1.3 (code 4)`.
