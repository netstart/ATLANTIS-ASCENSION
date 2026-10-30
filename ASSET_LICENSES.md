# Licenças de assets e software

Gerado por `tools/build_license_index.py` a partir de `licenses/registry.json`. Não editar à mão.
Os componentes de terceiros do próprio Godot (FreeType, HarfBuzz, etc.) aparecem na tela
Licenças do jogo, lidos do motor exportado (`Engine.get_copyright_info()`).

| Componente | Autor | Licença | Versão | Uso comercial | Crédito exigido | Texto local | Origem |
|---|---|---|---|---|---|---|---|
| Godot Engine | Juan Linietsky, Ariel Manzur and Godot Engine contributors | MIT | 4.7.2-stable | sim | sim | `licenses/texts/MIT-Godot.txt` | https://godotengine.org/license |
| Android Jetpack (AndroidX) and Kotlin stdlib | The Android Open Source Project; JetBrains s.r.o. | Apache-2.0 | as bundled by the Godot 4.7.2 Android export template | sim | sim | `licenses/texts/Apache-2.0.txt` | https://developer.android.com/jetpack/androidx |
| Hyakki (código portado: escala, área segura, rolagem, save, idiomas, ferramentas) | Clayton K. N. Passos | MIT | main em 2026-10-30 | sim | sim | `licenses/texts/MIT-Hyakki.txt` | https://github.com/netstart/hyakki |
| Fusion Pixel Font (12px proportional) | TakWolf | OFL-1.1 | 2026.10.16 | sim | sim | `licenses/texts/OFL-1.1.txt` | https://github.com/TakWolf/fusion-pixel-font |
| Ark Pixel Font (Fusion Pixel upstream) | TakWolf | OFL-1.1 | included in Fusion Pixel 2026.10.16 | sim | sim | `licenses/texts/OFL-1.1.txt` | https://github.com/TakWolf/ark-pixel-font |
| Cubic 11 (Fusion Pixel upstream) | ACh-K | OFL-1.1 | included in Fusion Pixel 2026.10.16 | sim | sim | `licenses/texts/OFL-1.1.txt` | https://github.com/ACh-K/Cubic-11 |
| Galmuri (Fusion Pixel upstream) | Lee Minseo (quiple) | OFL-1.1 | included in Fusion Pixel 2026.10.16 | sim | sim | `licenses/texts/OFL-1.1.txt` | https://github.com/quiple/galmuri |
| Kenney — Pixel Shmup, Space Shooter Redux/Extension, Particle Pack, Smoke Particles, UI Pack Sci-fi, Game Icons, Input Prompts | Kenney (kenney.nl) | CC0-1.0 |  | sim | não | `licenses/texts/CC0-1.0.txt` | https://kenney.nl/assets/pixel-shmup |
| Kenney Fonts | Kenney (kenney.nl) | CC0-1.0 |  | sim | não | `licenses/texts/CC0-1.0.txt` | https://kenney.nl/assets/kenney-fonts |
| Kenney — Sci-fi Sounds, Impact Sounds, Interface Sounds, Digital Audio | Kenney (kenney.nl) | CC0-1.0 |  | sim | não | `licenses/texts/CC0-1.0.txt` | https://kenney.nl/assets/sci-fi-sounds |
| Kenney — Music Jingles | Kenney (kenney.nl) | CC0-1.0 |  | sim | não | `licenses/texts/CC0-1.0.txt` | https://kenney.nl/assets/music-jingles |
| Void — Main Ship | Foozle (foozle.io) | CC0-1.0 |  | sim | não | `licenses/texts/CC0-1.0.txt` | https://foozlecc.itch.io/void-main-ship |
| Void — Fleet Pack 1 (Kla'ed) | Foozle (foozle.io) | CC0-1.0 |  | sim | não | `licenses/texts/CC0-1.0.txt` | https://foozlecc.itch.io/void-fleet-pack-1 |
| Void — Fleet Pack 2 (Nairan) | Foozle (foozle.io) | CC0-1.0 |  | sim | não | `licenses/texts/CC0-1.0.txt` | https://foozlecc.itch.io/void-fleet-pack-2 |
| Void — Fleet Pack 3 (Nautolan) | Foozle (foozle.io) | CC0-1.0 |  | sim | não | `licenses/texts/CC0-1.0.txt` | https://foozlecc.itch.io/void-fleet-pack-3 |
| Void — Environment Pack | Foozle (foozle.io) | CC0-1.0 |  | sim | não | `licenses/texts/CC0-1.0.txt` | https://foozlecc.itch.io/void-environment-pack |
| Void — Pickups Pack | Foozle (foozle.io) | CC0-1.0 |  | sim | não | `licenses/texts/CC0-1.0.txt` | https://foozlecc.itch.io/void-pickups-pack |
| Ocean Creatures | michael-jay-rov | CC-BY-4.0 |  | sim | sim | `licenses/texts/CC-BY-4.0.txt` | https://michael-jay-rov.itch.io/ocean-creatures |
| 8-bit Epic Space Shooter Music | HydroGene | CC0-1.0 |  | sim | não | `licenses/texts/CC0-1.0.txt` | https://opengameart.org/content/8-bit-epic-space-shooter-music |
| Epic Boss Battle (Seamlessly Looping) | Juhani Junkala (SubspaceAudio) | CC0-1.0 |  | sim | não | `licenses/texts/CC0-1.0.txt` | https://opengameart.org/content/boss-battle-music |

Verificação: `python -I tools/check_licenses.py` (cobertura de todos os arquivos de `assets/`,
hash das cópias, licenças permitidas, data de verificação). Snapshots das páginas de origem em
`docs/licenses/` (fora do APK).
