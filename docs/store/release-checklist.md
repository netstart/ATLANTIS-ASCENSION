# Checklist de lançamento (Fase 4) — o que só o mantenedor pode fazer

O código da 1.0 está pronto e testado. Estes passos exigem contas, contratos, pagamentos ou aceite de termos em
nome do mantenedor, então ficam com ele. Ordem sugerida:

## 1. Ferramentas

1. ✅ Android SDK instalado (`tools\setup_android_sdk.ps1`, licenças do Google aceitas pelo mantenedor).
2. ✅ Chave de upload criada fora do repositório: `D:\src\keys\atlantis-upload.keystore` (RSA 4096,
   alias `atlantis-upload`) e `atlantis-upload.env` com as variáveis `GODOT_ANDROID_KEYSTORE_RELEASE_*`. **Faça
   backup dos dois arquivos** (cofre de senhas ou mídia offline). Na Play, ative a Assinatura de apps pelo Google
   Play e envie esta chave como chave de upload: se ela se perder, a Play permite trocar a chave de upload.
3. Todos os builds: `powershell -ExecutionPolicy Bypass -File tools\build_release.ps1` gera em `build/` o APK de
   debug, o AAB de release assinado (`atlantis-ascension-release.aab`, preset "Android Play"), o zip do Windows e o
   tar.gz do Linux.

## 2. Google Play

Roteiro completo, tela a tela, com todas as respostas do Play Console: [play-console.md](play-console.md).

Já pronto no repositório:

- ✅ AAB assinado com a chave de upload (preset "Android Play"): targetSdk 36, 64 bits alinhado em 16 KB,
  permissões `VIBRATE` (do jogo) e `INTERNET`, `ACCESS_NETWORK_STATE`, `AD_ID` (do SDK de anúncios), backup
  automático do save ligado. `python -I tools/check_release_ads.py` confere o AdMob real no AAB.
- ✅ Anúncio recompensado real (1.18.0, IDs do AdMob do mantenedor). Build de release sem plugin de pagamento não
  finge cobrança: a loja paga some (`Store.simulated`/`Store.purchases_enabled`). Com o Turbo, ficha, política e
  declarações dizem "contém anúncios (recompensados, opcionais)" e "compras no app" (só o Turbo).
- ✅ Arte da ficha: `toolsuild_store_art.ps1` (8 capturas 1080x1920 e a imagem de destaque 1024x500 em cada
  um dos 11 idiomas, ícone 512).
- ✅ Textos da ficha em [listing.md](listing.md) (pt-BR e en completos; título e descrição curta nos 11 idiomas),
  com limites conferidos por `tools/check_store_texts.py`.
- ✅ Política de privacidade em [privacy-policy.md](privacy-policy.md) e em HTML (`docs/privacy/index.html`).

Só o mantenedor pode fazer:

1. Criar a conta de desenvolvedor (taxa única, verificação de identidade) e o app; confirmar o pacote
   `io.github.netstart.atlantisascension` antes do primeiro envio (ele fica fixo para sempre).
2. Publicar a política de privacidade numa URL pública (GitHub Pages da pasta `docs/` ou o link do GitHub).
3. Preencher as declarações com as respostas de [play-console.md](play-console.md) e enviar o AAB no teste interno.
4. **Teste fechado com 12 testadores por 14 dias seguidos** (exigência da Play para contas pessoais novas) e pedir
   acesso à produção.
5. Anúncio recompensado (IDs reais ligados na 1.18.0): configurar a mensagem de consentimento GDPR/LGPD no AdMob,
   publicar a política nova em `netstart.github.io/atlantis/` e declarar "contém anúncios", ID de publicidade e
   Segurança dos dados (seção "Ligar o anúncio recompensado" de [play-console.md](play-console.md)).
6. Turbo (Play Billing real, plugin `GodotGooglePlayBilling` no AAB): criar o produto no app `turbo` (US$ 1,99),
   pôr testadores de licença e testar compra, pendente e reinstalação (seção "Compras no app: o Turbo" de
   [play-console.md](play-console.md)). Política, ficha e IARC "compras digitais = Sim" já estão atualizados.
   `supporter` e pinturas avulsas continuam só simulados (`Store.purchases_enabled`). O passe `season_gold`
   (US$ 4,99) passou a ser produto real: criar e testar com `tools/play_products.py`, como os demais.

## 3. Steam

1. Conta Steamworks (taxa por app), página da loja, cápsulas, trailer.
2. Baixar o Steamworks SDK (aceitar a licença da Valve) e o GodotSteam (MIT) e registrar ambos em
   `licenses/registry.json` (o SDK como `LicenseRef-Steamworks`).
3. Conquistas: as 28 ids de `data/achievements.json` (o jogo já as concede localmente); placares a partir de
   `profile.boards`; Steam Cloud apontando para `user://save.json` e `user://replays/`.
4. Presets Windows/Linux já têm a feature `steam` (sem anúncios, cosméticos inclusos).
5. Steam Deck: o jogo já roda em 1280x800 com controle (testes de layout na resolução do Deck).

## 4. Antes de enviar

- `powershell -ExecutionPolicy Bypass -File tools\run_checks.ps1` → `TUDO OK`.
- Critérios da 1.0: aprovado nas duas lojas; crash-free ≥ 99,5% e D1 ≥ 40% no teste fechado.
