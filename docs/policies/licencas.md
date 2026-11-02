# Política de licenças

> Referenciado por [AGENTS.md](../../AGENTS.md). Origem: seção "Política de licença" do `AGENTS.md` do projeto
> [hyakki](https://github.com/netstart/hyakki/blob/main/AGENTS.md), adaptada para Atlantis Ascension.
> **Obrigatório para qualquer contribuição.**

**Tudo neste jogo precisa ser de licença livre para uso comercial e livre distribuição.** O jogo será vendido e
monetizado na Google Play e na Steam.

Qualquer código, asset, fonte, áudio, shader, plugin ou dependência adicionado ao repositório deve:

1. Permitir **uso comercial** (venda, monetização, anúncios, compras in-app, venda na Steam).
2. Permitir **distribuição livre** (redistribuição do jogo e de seus ativos, sem custo ou por valor).
3. Permitir **modificações** (editar, recortar, recolorir, redimensionar, recompilar, integrar ao Godot).
4. Permitir **sub-licenciamento ou incorporação** no binário do jogo (APK/AAB Android, PCK e executáveis
   Windows/Linux da Steam).

Licenças que exigem "compartilha-igual" viral sobre o jogo inteiro (GPL, AGPL, LGPL, CC-BY-SA), que proíbem uso
comercial (NC) ou obras derivadas (ND) **não são aceitas**.

## Licenças permitidas

| Licença | SPDX | Uso comercial | Distribuição | Modificações | Atribuição | Observações |
|---|---|---|---|---|---|---|
| MIT | `MIT` | ✅ | ✅ | ✅ | ✅ Obrigatória | Código e assets |
| Apache 2.0 | `Apache-2.0` | ✅ | ✅ | ✅ | ✅ Obrigatória | Código e assets; inclui patentes |
| CC0 1.0 | `CC0-1.0` | ✅ | ✅ | ✅ | ❌ Não exigida | Domínio público; **preferência absoluta** |
| Open Font License 1.1 | `OFL-1.1` | ✅ | ✅ | ✅ | ✅ Obrigatória | Apenas fontes |
| CC-BY 4.0 | `CC-BY-4.0` | ✅ | ✅ | ✅ | ✅ Obrigatória | Crédito ao autor |
| BSD 2/3 cláusulas | `BSD-2-Clause`, `BSD-3-Clause` | ✅ | ✅ | ✅ | ✅ Obrigatória | Código |
| Zlib | `Zlib` | ✅ | ✅ | ✅ | ✅ Obrigatória | Código |
| CC-BY 3.0 | `CC-BY-3.0` | ✅ | ✅ | ✅ | ✅ Obrigatória | **A ratificar pelo mantenedor** (comum na OpenGameArt) |
| OGA-BY 3.0 | `LicenseRef-OGA-BY-3.0` | ✅ | ✅ | ✅ | ✅ Obrigatória | **A ratificar pelo mantenedor** (CC-BY sem cláusula anti-DRM) |

As duas últimas linhas ampliam a lista do hyakki. Até o mantenedor ratificar, assets nessas licenças podem ser
baixados e avaliados, mas não entram em `assets/` nem em build.

Licenças próprias de SDKs obrigatórios das lojas (Google Mobile Ads SDK, Play Billing Library, Steamworks SDK) entram
como `LicenseRef-<nome>`, com o texto copiado e a confirmação de que permitem distribuição no binário. Cada uma exige
decisão registrada no `licenses/registry.json` (campo `decision`).

## Licenças NÃO permitidas (exemplos)

- GPL, AGPL, LGPL e CC-BY-SA (virais sobre o jogo).
- CC-BY-NC, CC-BY-ND e qualquer variante NC ou ND.
- "Todos os direitos reservados" sem permissão explícita por escrito.
- Licenças com restrição de campo de uso ("não para jogos com anúncios", "não para militares").
- Licenças custom de itch.io do tipo "grátis para uso comercial, proibida revenda/redistribuição/treino de IA". Elas
  não estão na lista acima. Só entram como `LicenseRef-` depois de decisão registrada do mantenedor.
- "Free" sem licença declarada na página. Grátis não significa livre para uso comercial.
- Qualquer elemento de propriedade intelectual dos jogos de referência (Galaxy Attack, Atlantis Invaders, Wing
  Fighter, Falcon Squad, Raiden, Star Wars: Galaxy of Heroes): arte, nomes, interface, músicas, fases.

## Assets gerados por IA

Não entram sem decisão registrada do mantenedor. Prefira assets feitos à mão, assets livres verificados ou arte
procedural feita por código do próprio projeto (MIT).

Quando o mantenedor decide usar um asset gerado por IA, a entrada em `licenses/registry.json` leva:

- `ai_generated: true` e o campo `decision`, não vazio, com a data, quem pediu, a ferramenta e o modelo, por que os
  termos da ferramenta permitem uso comercial e se há marca d'água (ex.: SynthID). Sem `decision`, o
  `check_licenses.py` reprova. Uma decisão vale para aquele asset, não para a ferramenta.
- `author`: o mantenedor "com" a ferramenta (ex.: "Clayton K. N. Passos com Google Flow Music"), que aparece
  assim nos créditos.
- `license_id` `LicenseRef-<termos>` com o resumo local dos termos em `licenses/texts/` (campo `license_source`),
  o aviso de autoria em `licenses/notices/` e o snapshot datado dos termos em `docs/licenses/`.
- O script que prepara o arquivo (corte, laço, normalização) fica em `tools/`, e o original gerado fica em
  `c:\src\downloads\assets\<ferramenta>\`, como qualquer download.

Primeiro caso: o tema do menu (`flow_tide_rising_music`), gerado pelo mantenedor no Google Flow Music em
2026-11-01.

## Onde ficam os downloads

- Pacotes originais baixados ficam **fora do repositório** em `c:\src\downloads\assets\<fonte>\<pack>.zip`
  (ex.: `c:\src\downloads\assets\foozle\void-main-ship.zip`), com a página de origem salva ao lado em PDF.
- Só os arquivos realmente usados são copiados para `assets/` por `tools/sync_assets.py`, guiado por
  `tools/asset_manifest.json`. Cada cópia grava o SHA-256 em `assets/asset_index.json`.

## Processo para adicionar um novo asset ou dependência

1. Verifique a licença na página oficial do upstream e confirme que está na lista permitida.
2. Salve o pacote em `c:\src\downloads\assets\<fonte>\` e um snapshot PDF da página em `docs/licenses/<id>_<data>.pdf`.
3. Adicione a entrada em `licenses/registry.json` (campos: `id`, `name`, `category`, `author`, `version`,
   `license_id`, `commercial_use: true`, `attribution_required`, `source_url`, `license_file`, `notice_file`,
   `snapshot_file`, `files`, `sha256`, `downloaded_at`, `verified_at`, `verified_by`).
4. Copie o texto da licença para `licenses/texts/<id>.<spdx>.txt`.
5. Copie o aviso/copyright do autor para `licenses/notices/<id>_<nome>.txt`.
6. Declare os arquivos usados em `tools/asset_manifest.json` e rode `python -I tools/sync_assets.py`.
   Nenhum asset entra no jogo sem sua licença acompanhando.
7. Atualize `tools/check_licenses.py` se houver categoria ou validação nova.
8. Rode `python -I tools/check_licenses.py` antes de commitar.
9. Regenere `licenses/index.json`, `ASSET_LICENSES.md` e `CREDITS.md` com `python -I tools/build_license_index.py`
   e confirme que o asset aparece na tela de créditos, na seção certa.
10. Registre o asset no catálogo do projeto, [.ai/02-catalogo-assets-licencas.md](../../.ai/02-catalogo-assets-licencas.md),
    mudando o status de ⚠️ para ✅.

`tools/check_licenses.py` reprova o build se: um arquivo de `assets/` ou `addons/` não tem entrada no registro; a
cópia da licença falta ou o SHA-256 não confere; a licença está fora da lista; o componente exige crédito e não
aparece no `CREDITS.md`; a verificação tem mais de 180 dias; a entrada está `needs_review`; a entrada é gerada por IA
(`ai_generated`) ou usa `LicenseRef-` sem `decision`; os arquivos gerados
estão desatualizados.

## Tela de créditos (obrigatório em toda versão)

A tela de créditos (`scripts/app/screens/credits_screen.gd`) e o `CREDITS.md` listam **todo** autor, asset e software
de `licenses/index.json`, em **toda** versão. Nenhum autor fica de fora, nem os CC0.

- A tela lê `licenses/index.json` em tempo de execução. O que não é arte, áudio ou fonte (motor, Android, Steam,
  plugins) cai em Tecnologia. Não filtre entradas.
- O teste `tests/credits_screen_tests.gd` confere que todo nome e autor do índice está visível na tela e no
  `CREDITS.md`. Ele precisa passar antes de qualquer commit.
- A página da Steam e a ficha da Google Play linkam a mesma lista (`docs/credits.html`, gerado pelo mesmo script).

## Dúvidas

Antes de adicionar algo com licença incerta, pergunte ao mantenedor. Não adicione o arquivo ao repositório sem
confirmação de que a licença está na lista permitida.
