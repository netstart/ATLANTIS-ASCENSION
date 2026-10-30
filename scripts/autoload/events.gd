extends Node
## Barramento de sinais globais (plano mestre 10.2). Sistemas emitem aqui; HUD, áudio, conquistas e
## telemetria escutam sem conhecer quem emitiu.

@warning_ignore("unused_signal")
signal screen_changed(screen: StringName)
@warning_ignore("unused_signal")
signal enemy_destroyed(enemy_id: StringName, position: Vector2, points: int)
@warning_ignore("unused_signal")
signal player_hit(hull_left: int)
@warning_ignore("unused_signal")
signal weapon_level_changed(weapon_id: StringName, level: int)
@warning_ignore("unused_signal")
signal pickup_collected(kind: StringName)
@warning_ignore("unused_signal")
signal boss_spawned(boss_id: StringName)
@warning_ignore("unused_signal")
signal boss_phase_changed(boss_id: StringName, phase: StringName)
@warning_ignore("unused_signal")
signal boss_defeated(boss_id: StringName)
@warning_ignore("unused_signal")
signal mission_finished(result: Dictionary)
@warning_ignore("unused_signal")
signal achievement_unlocked(achievement_id: StringName)
