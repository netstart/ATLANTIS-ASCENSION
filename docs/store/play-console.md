# Google Play Console — roteiro de publicação e respostas

Tudo o que o Play Console pede para publicar o Atlantis Ascension, na ordem das telas, com a resposta certa para a
versão atual (**grátis, jogável offline, com anúncios recompensados opcionais do AdMob e uma compra no app: o
Turbo**, produto `turbo`, compra única de US$ 1,99). O que só o titular da conta pode fazer
(pagar, aceitar termos, verificar identidade, enviar arquivos) está marcado com 👤.

## 0. Arquivos prontos

| O quê | Onde | Como gerar |
|---|---|---|
| App bundle assinado (AAB) | `build/atlantis-ascension-release.aab` | `powershell -ExecutionPolicy Bypass -File tools\build_release.ps1` |
| Capturas de celular 1080x1920 (8 por idioma, 11 idiomas) | `build/store/play/<idioma>/phone_01..08.png` | `powershell -ExecutionPolicy Bypass -File tools\build_store_art.ps1` |
| Imagem de destaque 1024x500 (por idioma) | `build/store/play/<idioma>/feature_graphic.png` | idem |
| Ícone 512x512 | `build/store/play/icon_512.png` | idem (cópia de `assets/art/generated/icon/icon_512.png`) |
| Textos da ficha e "Novidades" | [listing.md](listing.md) | limites conferidos por `tools/check_store_texts.py` |
| Política de privacidade (HTML) | `docs/privacy/index.html` | `python -I tools/build_privacy_page.py` (fonte: [privacy-policy.md](privacy-policy.md)) |

Dados técnicos do AAB (versão 1.18.0): pacote `io.github.netstart.atlantisascension`, versionCode 34, minSdk 24
(Android 7.0), targetSdk 36 (Android 16, acima do mínimo exigido pela Play), arm64-v8a + armeabi-v7a + x86_64,
bibliotecas de 64 bits alinhadas em 16 KB (exigência da Play para targetSdk 35+), OpenGL ES 3.0 obrigatório,
`debuggable` desligado, backup automático do Android ligado (o progresso volta ao trocar de aparelho). AdMob:
meta-data `com.google.android.gms.ads.APPLICATION_ID` = `ca-app-pub-6552169828297838~1447443371` e plugin
`PoingGodotAdMob` no pacote; Play Billing: plugin `GodotGooglePlayBilling` 3.3.0 (Billing Library 9.1.0) e a
permissão `com.android.vending.BILLING` (`python -I tools/check_release_ads.py` confere os dois;
`tools/build_release.ps1` o roda). Permissões do manifesto final: `VIBRATE` (do jogo); `com.android.vending.BILLING`
(Billing Library, compra do Turbo); `INTERNET`, `ACCESS_NETWORK_STATE`, `AD_ID` (as duas,
`android.` e `com.google.android.gms.`) e `READ_BASIC_PHONE_STATE` (SDK de anúncios); `WAKE_LOCK` e
`FOREGROUND_SERVICE` (WorkManager, dependência do SDK); `<pacote>.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION`
(AndroidX, interna). Nenhuma é "perigosa" (nenhum diálogo de permissão para o jogador).

Certificado da **chave de upload** (`D:\src\keys\atlantis-upload.keystore`, alias `atlantis-upload`):

- SHA-1: `79:EB:03:DD:FB:6F:FC:15:55:65:9D:F4:CE:91:71:ED:1A:71:40:24`
- SHA-256: `AE:81:89:73:F5:DE:7C:93:D6:F7:C9:AE:67:74:9D:A0:EC:81:6F:43:C3:D1:AC:83:C5:24:6B:88:90:F6:B0:3E`

Confira com `keytool -printcert -jarfile build\atlantis-ascension-release.aab`. Faça backup do keystore e do
`atlantis-upload.env` fora deste computador.

## 1. Conta 👤

1. Criar a conta de desenvolvedor em <https://play.google.com/console/signup> (conta **pessoal**), pagar a taxa
   única e concluir a verificação de identidade e do telefone.
2. Conta pessoal criada depois de 13/11/2023: a produção só libera depois de um **teste fechado com pelo menos 12
   testadores inscritos por 14 dias seguidos** (seção 6).

## 2. Criar o app 👤

| Campo | Resposta |
|---|---|
| Nome do app | Atlantis Ascension: Shmup |
| Idioma padrão | Português (Brasil) – pt-BR |
| App ou jogo | Jogo |
| Gratuito ou pago | Gratuito (⚠️ um app gratuito nunca pode virar pago depois) |
| Declarações | Aceitar as Políticas do programa para desenvolvedores e as leis de exportação dos EUA |

O pacote só é fixado no **primeiro envio** do AAB e nunca mais muda. Hoje é `io.github.netstart.atlantisascension`
(o domínio `netstart.github.io` é do mantenedor). Se quiser outro, troque `package/unique_name` nos dois presets
Android de `export_presets.cfg` **antes** do primeiro envio.

## 3. Configurar o app (Painel → "Configurar o app")

### Política de privacidade

URL pública em HTML. Opções, da melhor para a mais simples:

URL usada: `https://netstart.github.io/atlantis/privacy-policy.html` (publicada pelo site
`D:\src\netstart.github.io\atlantis\`, que tem a fonte `privacy-policy.md` ao lado). Ao mudar a política aqui,
gere com `python -I tools/build_privacy_page.py` e copie `docs/privacy/index.html` e `docs/store/privacy-policy.md`
para `netstart.github.io/atlantis/` (como `privacy-policy.html` e `privacy-policy.md`), depois commit e `git push` lá.

### Acesso ao app

"Todas as funcionalidades estão disponíveis sem acesso especial" (não há login).

### Anúncios

**"Sim, meu app contém anúncios."** (desde a 1.18: só anúncios recompensados opcionais do AdMob, pedidos pelo
jogador em reviver, dobrar créditos, dobrar as Pérolas do Diário e baú em dobro; sem intersticial, sem banner, sem
anúncio de abertura e nenhum anúncio durante a missão). Com "Sim", a Play mostra o selo "Contém anúncios" na
ficha. Declarar errado é violação de política.

### Classificação do conteúdo (questionário IARC)

| Pergunta | Resposta |
|---|---|
| E-mail de contato | o da conta de desenvolvedor |
| Categoria | Jogo (todos os outros tipos de jogo) |
| Violência | Sim: violência de fantasia, naves e máquinas/criaturas não humanas explodem; sem sangue, sem violência contra pessoas, sem mortes realistas |
| Medo / terror | Não (chefes grandes, sem cenas de terror) |
| Sexualidade, nudez | Não |
| Linguagem imprópria | Não |
| Drogas, álcool, tabaco | Não |
| Apostas / jogos de azar simulados | Não (o baú grátis dá recompensa fixa sem compra; não há loot box paga) |
| Interação entre usuários, chat, conteúdo gerado | Não |
| Compartilha localização | Não |
| Compras digitais | **Sim** (o Turbo, compra única opcional pela Google Play; não é loot box nem moeda) |
| Navegador / acesso irrestrito à internet | Não |

Resultado esperado: classificação baixa (ex.: PEGI 7, ESRB E10+, ClassInd 10). A Play mostra o resultado antes de
confirmar; se vier diferente, revise só a pergunta de violência.

### Público-alvo e conteúdo

- Faixas etárias: **13–15, 16–17 e 18+** (o jogo não é feito para crianças; marcar menores de 13 traz as regras
  do programa Famílias).
- "A ficha pode atrair crianças sem querer?": Não (shmup de ficção científica com desafio alto, sem personagens
  infantis).

### Segurança dos dados

Base: "coletar" é enviar dados para fora do aparelho, inclusive por SDKs de terceiros. O save, as opções e os
replays ficam só no aparelho (o Backup automático do Android é do sistema e não conta). O AAB traz o **SDK do
Google Mobile Ads** (plugin Poing AdMob) e o **UMP**; o SDK é iniciado na abertura e pré-carrega o recompensado,
então declare os tipos que o Google documenta para o SDK
([guia do Google](https://developers.google.com/admob/android/privacy/play-data-disclosure)):

| Pergunta | Resposta |
|---|---|
| O app coleta ou compartilha algum dos tipos de dados exigidos? | **Sim** |
| Todos os dados coletados são criptografados em trânsito? | **Sim** (o SDK usa TLS) |
| Você oferece uma forma de pedir a exclusão dos dados? | **Não** (não há conta nem servidor nosso; o ID de publicidade se redefine ou apaga nas configurações do Android e o consentimento se revê em Opções › Privacidade e anúncios) |

Tipos de dados, todos com **Coletado: Sim**, **Compartilhado: Sim**, **Processado de forma temporária: Não** e
**Obrigatório** (o jogador não desliga a coleta do SDK dentro do app):

| Categoria › tipo | Finalidades |
|---|---|
| Local › **Local aproximado** (pelo IP) | Publicidade ou marketing; Análise; Prevenção de fraudes, segurança e conformidade |
| Atividade no app › **Interações no app** (aberturas, toques, vídeos vistos) | Publicidade ou marketing; Análise; Prevenção de fraudes, segurança e conformidade |
| Informações e desempenho do app › **Diagnóstico** (tempo de carga, falhas do SDK) | Análise; Prevenção de fraudes, segurança e conformidade |
| IDs do dispositivo ou outros IDs › **IDs do dispositivo ou outros IDs** (ID de publicidade, ID do conjunto de apps) | Publicidade ou marketing; Análise; Prevenção de fraudes, segurança e conformidade |

A compra do Turbo **não acrescenta tipo de dado**: o pagamento é feito na tela da própria Google Play (o Google
é quem coleta, sob a política dele), e o jogo só recebe se a compra existe. Por isso **Informações financeiras ›
Histórico de compras** fica desmarcado, como no guia do Google para apps que só usam o Play Billing.

Não marque: informações pessoais, financeiras, saúde, mensagens, fotos, áudio, arquivos, agenda, contatos,
histórico de navegação, local exato, registros de falhas (o jogo não tem Crashlytics). Depois de salvar, confira
na prévia "Os dados são criptografados em trânsito" e os quatro tipos acima.

### ID de publicidade

O manifesto final (fundido pelo Gradle) tem `com.google.android.gms.permission.AD_ID`, trazida pelo SDK. Responda:

- "Seu app usa o ID de publicidade?" → **Sim**.
- Finalidades: **Publicidade ou marketing**, **Análise**, **Prevenção de fraudes, segurança e conformidade** (as
  mesmas da Segurança dos dados).

Responder "Não" com a permissão no manifesto faz a Play bloquear o envio.

### Outras declarações

| Declaração | Resposta |
|---|---|
| App governamental | Não |
| Recursos financeiros | Meu app não oferece recursos financeiros (a compra do Turbo pela Google Play não conta) |
| Saúde | Meu app não tem recursos de saúde |
| App de notícias | Não |
| Permissões sensíveis (fotos/vídeos, localização, SMS, chamadas, serviço em primeiro plano, intent em tela cheia, alarme exato) | nenhuma é usada pelo jogo. Se a Play pedir declaração de serviço em primeiro plano, responda que o app não usa: o `FOREGROUND_SERVICE` genérico vem da WorkManager (dependência do SDK de anúncios), sem nenhum `FOREGROUND_SERVICE_<tipo>` |

## 4. Ficha da loja principal

| Campo | Valor |
|---|---|
| Nome, descrição curta, descrição completa | [listing.md](listing.md) (pt-BR padrão; adicione en-US com "Gerenciar traduções" e os títulos/descrições curtas dos outros idiomas da tabela) |
| Ícone do app | `build/store/play/icon_512.png` (512x512, PNG 32 bits) |
| Imagem de destaque | `build/store/play/pt_BR/feature_graphic.png` (e a de cada idioma traduzido) |
| Capturas de tela de smartphone | `build/store/play/pt_BR/phone_01..08.png` (e as de cada idioma) |
| Tablet 7" e 10" | opcional; as mesmas capturas 9:16 são aceitas |
| Vídeo | opcional (URL do YouTube) |

Configurações da loja: categoria **Jogos → Arcade**; tags sugeridas: Arcade, Shoot 'em up, Ficção científica,
Pixel art, Um jogador, Offline. Detalhes de contato: e-mail obrigatório (👤 escolha um e-mail público de suporte);
site opcional (`https://github.com/netstart/ATLANTIS-ASCENSION`).

## 5. Assinatura e primeiro envio

1. Testes → Teste interno → Criar versão.
2. "Assinatura de apps pelo Google Play": aceitar o padrão (a Google gera e guarda a chave de assinatura; o
   `atlantis-upload.keystore` vira a chave de upload).
3. Enviar `build/atlantis-ascension-release.aab`; nome da versão `1.18.1 (35)` (a 1.18.0 (34) foi aprovada no teste fechado em 16/11/2026); notas: "Novidades" de
   [listing.md](listing.md).
4. Revisar avisos. Esperados e inofensivos: "Este App Bundle contém código nativo e você não enviou símbolos de
   depuração" (os modelos oficiais do Godot não trazem os símbolos).
5. Relatório de pré-lançamento: deixe ligado; ele roda o jogo em aparelhos reais da Google e mostra travamentos e
   capturas.

## 6. Teste fechado (obrigatório para conta pessoal nova) 👤

1. Testes → Teste fechado → criar a faixa, países, lista de testadores (e-mails ou Grupo do Google).
2. Promover a versão do teste interno para o fechado.
3. **12 ou mais testadores inscritos por 14 dias seguidos.** Roteiro de playtest: seção 13 do plano mestre.
4. Depois dos 14 dias: Painel → "Solicitar acesso à produção" (perguntas sobre o teste; responda com o que mudou).

## 7. Produção 👤

1. Produção → Países/regiões: todos (o jogo tem 11 idiomas e nenhum conteúdo regional).
2. Criar versão a partir do AAB já testado, lançamento gradual (ex.: 20%) e enviar para revisão.
3. A cada nova versão: subir a versão (SemVer + versionCode, `docs/policies/versionamento.md`), rodar
   `tools\build_release.ps1` e `tools\build_store_art.ps1` se a interface mudou.

## Publicação automática (GitHub Actions)

O workflow [`.github/workflows/android-play.yml`](../../.github/workflows/android-play.yml) roda no `windows-latest`:

- **Pull request na `main`:** só `tools\run_checks.ps1` (Godot 4.7.2 e templates baixados e guardados em cache).
- **Push na `main`:** checagens → AAB assinado (`tools\build_release.ps1 -PlayOnly`, que também roda
  `check_release_ads.py`) → AAB como artifact → envio ao **teste fechado** (`alpha`, status `completed`) com o nome
  `X.Y.Z (versionCode)`. Antes do build, `tools/play_publish.py has-version` consulta a Play: se o `version/code` do
  `export_presets.cfg` já está em alguma faixa, o build e o envio são pulados com um aviso e o job fica verde.
- **"Run workflow" (Actions → Android Play):** faixa `internal`, `alpha` ou `beta` faz o mesmo build e envio (com o
  status `completed` ou `draft`). Faixa **`production`** não roda checagens nem build: `tools/play_publish.py
  promote` pega a versão mais nova (maior versionCode) do `alpha` e a põe na produção com as mesmas notas e nome, em
  liberação gradual (`rollout`, fração de 0 a 1, padrão 0.2; `1` = `completed`). Para testar sem publicar:
  `python tools/play_publish.py --key D:\src\keys\atlantis-play-publisher.json promote --dry-run`.
- **Hoje a produção está bloqueada:** em 17/11/2026 a Play respondeu `FAILED_PRECONDITION` (a conta ainda não tem
  acesso à produção). Libera depois do teste fechado com 12 testadores por 14 dias e de "Solicitar acesso à
  produção" no Play Console.

Secrets do repositório (grave com `powershell -ExecutionPolicy Bypass -File tools\setup_ci_secrets.ps1
-ServiceAccountJson <arquivo.json>`, que lê `D:\src\keys\atlantis-upload.env` e nunca imprime valores):

| Secret | Conteúdo |
|---|---|
| `ANDROID_UPLOAD_KEYSTORE_BASE64` | `atlantis-upload.keystore` em base64 |
| `ANDROID_UPLOAD_KEYSTORE_ALIAS` | alias da chave de upload |
| `ANDROID_UPLOAD_KEYSTORE_PASSWORD` | senha do keystore |
| `PLAY_SERVICE_ACCOUNT_JSON` | `D:\src\keys\atlantis-play-publisher.json`: chave da conta de serviço `atlantis-play-publisher@gen-lang-client-0110100183.iam.gserviceaccount.com` (projeto do Google Cloud do Hyakki, API Google Play Android Developer ligada), com as permissões "Enviar para produção" e "Liberar apps para as faixas de teste" só neste app no Play Console |

A Play recusa um AAB com `version/code` já enviado: suba o versionCode a cada commit
(`docs/policies/versionamento.md`); commit sem subir só é pulado.

## Compras no app: o Turbo

O código está pronto: plugin `GodotGooglePlayBilling` 3.3.0 em `addons/GodotGooglePlayBilling` (ligado no
`project.godot`), `scripts/core/play_billing_provider.gd` (portado do hyakki) e `scripts/core/turbo.gd`. O Turbo
acelera a partida em 1,5x ou 2x (botão no HUD); deixa o jogo mais rápido, não mais fácil. Na Steam vem incluído.
Política de privacidade, ficha e as respostas acima (IARC "Compras digitais" = Sim) já estão atualizadas.

Fluxo no aparelho: ao abrir, o jogo conecta à Play, busca o preço e consulta as compras (`queryPurchases`): quem
reinstala ou troca de aparelho recupera o Turbo sozinho (e a Loja tem "Restaurar compras"). Comprar abre a tela da
Play; compra concluída libera e é confirmada (`acknowledge`, sem isso a Play estorna em 3 dias); compra
**pendente** (boleto, dinheiro em loja) não libera até a Play concluir; reembolso tira o Turbo na próxima abertura.

Faltam 👤, nesta ordem:

1. Play Console → Monetizar → Produtos → **Produtos no app** → Criar produto: ID **`turbo`** (não muda nunca),
   nome "Turbo", descrição "Acelera a partida em 1,5x ou 2x. Mais rápido, não mais fácil.", preço padrão
   **US$ 1,99** (a Play converte para cada país; revise o preço em reais) e **Ativar**. A Play só deixa criar
   produtos depois de um AAB com a permissão `BILLING` enviado a alguma faixa (o AAB novo já tem).
2. Configuração → Teste de licença: pôr os e-mails dos testadores (compram sem cobrança de verdade) e testar no
   teste interno: comprar, compra pendente ("Cartão de teste, aprovar depois"), cancelar, desinstalar e reinstalar.
3. Ficha da loja: a Play mostra "Compras no app" sozinha depois de o produto estar ativo; confira.

"Apoiar" (`supporter`) e o passe dourado (`season_gold`) **não** são vendidos: continuam só simulados no
desenvolvimento e escondidos no release (`Store.purchases_enabled`), mesmo com o plugin no pacote. Para vendê-los
um dia: criar os produtos aqui, ligá-los pelo `PlayBillingProvider` como o Turbo e atualizar a política e este
documento antes do envio.

## Ligar o anúncio recompensado (AdMob)

O código já está pronto (1.17): plugin Poing AdMob 5.1.0 em `addons/admob`, consentimento UMP na abertura,
"Privacidade e anúncios" nas Opções, conteúdo de anúncio limitado a "PG" e quatro pontos recompensados pedidos
pelo jogador (reviver, dobrar créditos, dobrar as Pérolas do Diário, baú em dobro). Sem intersticial e sem banner.
O APK de debug usa o app e o bloco de **teste** do Google. Release sem IDs reais ficaria no modo "off" (sem
anúncio, sem SDK). **Situação na 1.18.0:** passos 1, 2, 3 e 5 feitos (app
`ca-app-pub-6552169828297838~1447443371`, bloco recompensado `ca-app-pub-6552169828297838/1146567180`, editor
`pub-6552169828297838` já no `app-ads.txt` de `netstart.github.io`); no passo 6 a política, a ficha e as
respostas deste documento já estão atualizadas. Faltam 👤: o passo 4 no AdMob, publicar a política nova no site,
preencher as declarações no Play Console e enviar o AAB 1.18.0. Passos, nesta ordem:

1. No [AdMob](https://admob.google.com), criar o app Android (pacote `io.github.netstart.atlantisascension`,
   depois de publicado na Play ou como "ainda não publicado") e um bloco **Recompensado**.
2. Em `scripts/core/admob_provider.gd`, preencher `RELEASE_UNITS` com o ID do bloco
   (`{"rewarded": "ca-app-pub-XXXXXXXXXXXXXXXX/NNNNNNNNNN"}`).
3. No `project.godot` (Projeto › Configurações › AdMob), pôr em `admob/general/android/app_id` o ID real do app (hoje a linha não aparece: vale o padrão do plugin, o app de teste do Google)
   (`ca-app-pub-XXXXXXXXXXXXXXXX~NNNNNNNNNN`). Com os dois IDs reais, `AdMobProvider.has_release_ids()` liga o
   release sozinho (o teste "este jogo ainda não tem IDs reais" de `tests/beta_tests.gd` passa a falhar: inverta-o).
4. No AdMob, configurar a mensagem de consentimento (Privacidade e mensagens → GDPR/LGPD) para o app.
5. Publicar o `app-ads.txt` ([modelo](app-ads.txt)) com o ID de publisher real.
6. **Só então** atualizar a política de privacidade, a ficha ("Contém anúncios") e as declarações (Anúncios = Sim,
   ID de publicidade, Segurança dos dados) e enviar um AAB novo.
