# Godot Play Game Services pagination patch

Upstream: https://github.com/godot-sdk-integrations/godot-play-game-services
Base revision: 0563b5499c12cbd391ba0af94dde0031f534998b

The patch adds a loadTopScores100 native method backed by Google's loadMoreScores API.
The AARs in bin/debug and bin/release were built from this revision with D:\Programs\jdk\jdk-17.0.21+9 and D:\Programs\android-sdk.

## Atlantis Ascension: export_plugin.gd

The game id is read from `project.godot` (`[play_games] game_id`, next to `leaderboard_id`) instead of the
export option `godot_play_game_services/game_id`. With an empty id the export plugin adds nothing to the
Android build (no AAR, no Gradle dependency, no APP_ID meta-data, no strings.xml): the Play Games v2 SDK
initializes itself from the manifest APP_ID and would crash the app without it.
