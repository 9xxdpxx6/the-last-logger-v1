extends PlayerState

# Drag (волок): тащим бревно. Медленно (коэффициент по массе и направлению — drag_speed_factor),
# без бега/прыжка. ПОСЛЕ движения тянем бревно к рукам и подтягиваем игрока к застрявшему бревну
# (кламп через move_and_collide — НЕ протаскивает сквозь препятствия). E — отпустить волок.
func physics_update(delta: float) -> void:
	_player.walk_locomotion(delta, _player.drag_speed_factor(), false, false, 1.0)
	# Волок: тянем бревно ПОСЛЕ перемещения игрока — по его свежей позиции.
	_player._update_drag()
	_player._clamp_to_dragged()


func prompt_text() -> String:
	return tr("PROMPT_DROP").format({"kg": "%.0f" % _player.dragged_log().get_weight()})


func handle_interact() -> void:
	_player._stop_drag()
