extends PlayerState

# Телекинез (#manip): бревно «висит» перед игроком и тянется к точке за прицелом. Игрок при этом ходит
# как обычно (налегке) — вся «магия» в физике захвата, которую ведёт Player.update_manipulation. Вход в
# режим — удержанием E по лёгкому бревну (см. player.gd), выход — отпусканием E (player._stop_manipulate).
func physics_update(delta: float) -> void:
	# Скорость и прыжок режутся по весу держимого бревна (как при переноске): тяжёлое тащить «на
	# расстоянии» так же тяжело.
	_player.walk_locomotion(delta, _player.manip_speed_mult(), true, true, _player.manip_jump_mult())
	_player.update_manipulation(delta)


func prompt_text() -> String:
	return tr("PROMPT_MANIP_HOLD")


# Тап E в этом режиме не используется: отпускание E роняет бревно (обрабатывается в Player по release).
func handle_interact() -> void:
	pass
