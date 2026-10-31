# Google Play Console — roteiro de publicação e respostas

Tudo o que o Play Console pede para publicar o Atlantis Ascension, na ordem das telas, com a resposta certa para a
versão atual (**grátis, offline, sem anúncios, sem compras no app**). O que só o titular da conta pode fazer
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

Dados técnicos do AAB (versão 1.6.1): pacote `io.github.netstart.atlantisascension`, versionCode 14, minSdk 24
(Android 7.0), targetSdk 36 (Android 16, acima do mínimo exigido pela Play), arm64-v8a + armeabi-v7a + x86_64,
bibliotecas de 64 bits alinhadas em 16 KB (exigência da Play para targetSdk 35+), OpenGL ES 3.0 obrigatório,
única permissão: `VIBRATE`, `debuggable` desligado, backup automático do Android ligado (o progresso volta ao
trocar de aparelho).

Certificado da **chave de upload** (`C:\src\tools\keys\atlantis-upload.keystore`, alias `atlantis-upload`):

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

1. GitHub Pages: no repositório, Settings → Pages → Deploy from a branch → `main` / `/docs`. URL:
   `https://netstart.github.io/ATLANTIS-ASCENSION/privacy/`
2. Sem Pages: `https://github.com/netstart/ATLANTIS-ASCENSION/blob/main/docs/store/privacy-policy.md`
   (o repositório é público).

### Acesso ao app

"Todas as funcionalidades estão disponíveis sem acesso especial" (não há login).

### Anúncios

"Não, meu app não contém anúncios." (sem o plugin do AdMob, o build de release não mostra anúncio nenhum: a
recompensa de "reviver" e "dobrar" sai direto.)

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
| Compras digitais | Não |
| Navegador / acesso irrestrito à internet | Não |

Resultado esperado: classificação baixa (ex.: PEGI 7, ESRB E10+, ClassInd 10). A Play mostra o resultado antes de
confirmar; se vier diferente, revise só a pergunta de violência.

### Público-alvo e conteúdo

- Faixas etárias: **13–15, 16–17 e 18+** (o jogo não é feito para crianças; marcar menores de 13 traz as regras
  do programa Famílias).
- "A ficha pode atrair crianças sem querer?": Não (shmup de ficção científica com desafio alto, sem personagens
  infantis).

### Segurança dos dados

| Pergunta | Resposta |
|---|---|
| O app coleta ou compartilha algum dos tipos de dados exigidos? | **Não** |
| (Com "Não", o formulário termina) | "Nenhum dado coletado" e "Nenhum dado compartilhado" aparecem na ficha |

Fundamento: sem permissão de internet, sem SDK de terceiros (só o Godot e as AndroidX do modelo de build), save
apenas local. O Backup automático do Android é do próprio sistema e não conta como coleta do app.

### ID de publicidade

"Seu app usa o ID de publicidade?" → **Não** (o manifesto não tem `com.google.android.gms.permission.AD_ID`).

### Outras declarações

| Declaração | Resposta |
|---|---|
| App governamental | Não |
| Recursos financeiros | Meu app não oferece recursos financeiros |
| Saúde | Meu app não tem recursos de saúde |
| App de notícias | Não |
| Permissões sensíveis (fotos/vídeos, localização, SMS, chamadas, serviço em primeiro plano, intent em tela cheia, alarme exato) | nenhuma é usada; a Play não pergunta |

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
3. Enviar `build/atlantis-ascension-release.aab`; nome da versão `1.6.1 (14)`; notas: "Novidades" de
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

## Quando ligar anúncios ou compras (Fase 4)

Antes de enviar um build com os plugins `AdMob` ou `GodotGooglePlayBilling`:

1. Atualizar [privacy-policy.md](privacy-policy.md) (e gerar a página) e as respostas acima: Anúncios = Sim; ID de
   publicidade = Sim (finalidade: publicidade); Segurança dos dados = coleta de ID do dispositivo, dados de uso e
   diagnóstico pelo SDK do Google, compartilhados para publicidade, criptografados em trânsito; IARC: compras
   digitais = Sim; ficha: "Contém anúncios" e "Compras no app".
2. Criar no Play Console os produtos `supporter` (compra única), `season_gold` e as pinturas avulsas.
3. Publicar o `app-ads.txt` ([modelo](app-ads.txt)) na raiz do site informado na ficha.
