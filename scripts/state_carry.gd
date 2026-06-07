extends PlayerState

# Carry: несём бревно на плече. Скорость/прыжок режутся по весу. E — глядя на тачку (или бревно в
# её кузове) положить в кузов (если влезет по ДЛИНЕ; перегруз по весу разрешён); иначе бросить на землю.
func physics_update(delta: float) -> void:
	_player.walk_locomotion(delta, _player.carry_speed_mult(), true, true, _player.carry_jump_mult())


func prompt_text() -> String:
	var c := _player.carried_log()
	var b := _player._aim_barrow_for_load()
	if b != null:
		var add := c.get_weight()
		# Бревно длиннее кузова (#2: торчало бы сквозь борта — E его не положит). Вместо веса
		# показываем КУРСИВОМ «Не влезет по размеру»: понятно, что мешает именно длина, а не вес.
		if not b.fits_length(c.get_length()):
			return "[i]%s[/i]" % tr("PROMPT_BARROW_TOO_LONG")
		# По длине влезает: показываем загрузку. Цвет добавляемого веса — зелёный (влезает) / красный (перегруз).
		var col := "44ff44" if b.can_load(add) else "ff4040"
		return tr("PROMPT_BARROW_LOAD").format({
			"cur": "%.0f" % b.current_load(),
			"add": "%.0f" % add,
			"col": col,
			"cap": "%.0f" % b.max_load_kg})
	return tr("PROMPT_DROP").format({"kg": "%.0f" % c.get_weight()})


func handle_interact() -> void:
	var c := _player.carried_log()
	var lb := _player._aim_barrow_for_load()
	if lb != null:
		# Грузим, если влезает ПО ДЛИНЕ. Перегруз по ВЕСУ разрешён (#2) — тачка тогда еле толкается.
		if lb.fits_length(c.get_length()):
			_player._load_into_barrow(lb)
		return
	_player._drop_carried()
