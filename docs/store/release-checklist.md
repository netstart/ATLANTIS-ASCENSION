# Checklist de lançamento (Fase 4) — o que só o mantenedor pode fazer

O código da 1.0 está pronto e testado. Estes passos exigem contas, contratos, pagamentos ou aceite de termos em
nome do mantenedor, então ficam com ele. Ordem sugerida:

## 1. Ferramentas

1. `powershell -ExecutionPolicy Bypass -File tools\setup_android_sdk.ps1` — instala o Android SDK e **pede que
   você aceite as licenças do Google**. Depois disso o export Android (`.apk`/`.aab`) funciona.
2. Criar a keystore de release (guarde fora do repositório):
   `keytool -genkeypair -v -keystore atlantis-release.keystore -alias atlantis -keyalg RSA -keysize 2048 -validity 10000`
   e preencher `keystore/release*` no preset Android (ou nas variáveis `GODOT_ANDROID_KEYSTORE_RELEASE_*`).

## 2. Google Play

1. Criar a conta de desenvolvedor (taxa única) e o app com o pacote definitivo (hoje
   `io.github.netstart.atlantisascension`; trocar em `export_presets.cfg` se mudar).
2. Ficha da loja: textos de [listing.md](listing.md), capturas (`tests/screens_runner.tscn` e
   `tests/game_shots_runner.tscn` geram as telas), ícone 512 px, imagem de destaque 1024x500.
3. Política de privacidade publicada em URL pública: [privacy-policy.md](privacy-policy.md).
4. Classificação etária (IARC) e Segurança de dados: respostas em [listing.md](listing.md).
5. **Teste fechado com 20 testadores por 14 dias** (exigência da Play para contas pessoais novas).
6. AdMob: criar a conta, o app e o bloco de anúncio **recompensado**; publicar `app-ads.txt` no site do
   desenvolvedor (modelo em [app-ads.txt](app-ads.txt)); configurar a mensagem de consentimento UMP.
7. Play Billing: produtos `supporter` (compra única), `season_gold` (trilha dourada) e pinturas avulsas.
8. Ligar os plugins: com `GodotGooglePlayBilling` e `AdMob` presentes, `Store.simulated()` vira falso e a loja
   passa a cobrar de verdade (ver `scripts/core/store.gd` e `scripts/core/ads.gd`).

## 3. Steam

1. Conta Steamworks (taxa por app), página da loja, cápsulas, trailer.
2. Baixar o Steamworks SDK (aceitar a licença da Valve) e o GodotSteam (MIT) e registrar ambos em
   `licenses/registry.json` (o SDK como `LicenseRef-Steamworks`).
3. Conquistas: as 22 ids de `data/achievements.json` (o jogo já as concede localmente); placares a partir de
   `profile.boards`; Steam Cloud apontando para `user://save.json` e `user://replays/`.
4. Presets Windows/Linux já têm a feature `steam` (sem anúncios, cosméticos inclusos).
5. Steam Deck: o jogo já roda em 1280x800 com controle (testes de layout na resolução do Deck).

## 4. Antes de enviar

- `powershell -ExecutionPolicy Bypass -File tools\run_checks.ps1` → `TUDO OK`.
- Revisão das traduções por falantes nativos (10 idiomas além do pt-BR).
- Critérios da 1.0: aprovado nas duas lojas; crash-free ≥ 99,5% e D1 ≥ 40% no teste fechado.
