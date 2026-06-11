extends PlayerState

# Carry: несём бревно на плече. Скорость/прыжок режутся по весу. E — глядя на тачку (или бревно в
# её кузове) положить в кузов (если влезет по ДЛИНЕ; перегруз по весу разрешён); иначе бросить на землю.
func physics_update(delta: float) -> void:
	_player.walk_locomotion(delta, _player.carry_speed_mult(), true, true, _player.carry_jump_mult())


func prompt_text() -> String:
	# Навёл на свободное бревно — подсказка «доложить ещё» (если влезает в остаток грузоподъёмности),
	# иначе «руки заняты» курсивом (#carry-multi).
	var aim := _player._aim_target()
	if aim.get("type") == "log":
		var log := aim["log"] as FallingLog
		var w := log.get_weight()
		if _player.can_carry_more(w):
			return tr("PROMPT_PICKUP").format({"kg": "%.0f" % w})
		return "[i]%s[/i]" % tr("PROMPT_CARRY_FULL")
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
	# 1) Навёл на ПОСИЛЬНОЕ свободное бревно — доложить на то же плечо стопкой, если влезает в
	#    остаток грузоподъёмности (#carry-multi). Иначе (слишком тяжёлое в сумме) — ничего не делаем,
	#    чтобы случайно не уронить стопку.
	var aim := _player._aim_target()
	if aim.get("type") == "log":
		var log := aim["log"] as FallingLog
		var w := log.get_weight()
		if _player.can_carry_more(w):
			_player._add_carry(log, w)
		return
	# 2) Навёл на тачку — грузим ВЕРХНЕЕ бревно стопки (по длине; перегруз по весу разрешён, #2).
	var c := _player.carried_log()
	var lb := _player._aim_barrow_for_load()
	if lb != null:
		if lb.fits_length(c.get_length()):
			_player._load_into_barrow(lb)
		return
	# 3) Иначе (смотрим в пустоту/на землю) — кладём верхнее бревно стопки на землю.
	_player._drop_carried()
