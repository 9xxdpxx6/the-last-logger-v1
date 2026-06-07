extends PlayerState

# Idle: руки свободны. Ходьба налегке (бег/прыжок разрешены). E — взять то, на что смотрим:
# тачку (взяться), посильное бревно (в руки), тяжёлое в пределах волока (тащить).
func physics_update(delta: float) -> void:
	_player.walk_locomotion(delta, 1.0, true, true, 1.0)


func prompt_text() -> String:
	# Навёлся на тачку — взять/толкать (с грузом показываем сколько лежит/влезет).
	var aim := _player._aim_target()
	if aim.get("type") == "barrow":
		var ab := aim["barrow"] as Wheelbarrow
		var load := ab.current_load()
		if load > 0.5:
			# Перегруз — показываем текущий вес КРАСНЫМ (#1): сразу видно, что тачка набита сверх нормы.
			var kg_str := "%.0f" % load
			if ab.is_overloaded():
				kg_str = "[color=#ff4040]%s[/color]" % kg_str
			return tr("PROMPT_BARROW_GRAB_LOADED").format({"kg": kg_str, "cap": "%.0f" % ab.max_load_kg})
		return tr("PROMPT_BARROW_GRAB")
	if aim.get("type") != "log":
		return ""
	# Навёлся на бревно: посильное — берём в руки; тяжелее, но в пределах волока — тащим; ещё тяжелее — никак.
	var log := aim["log"] as FallingLog
	var w := log.get_weight()
	if w <= _player.carry_capacity:
		return tr("PROMPT_PICKUP").format({"kg": "%.0f" % w})
	elif w <= _player.drag_capacity:
		return tr("PROMPT_DRAG").format({"kg": "%.0f" % w})
	return tr("PROMPT_TOO_HEAVY").format({"kg": "%.0f" % w})


func handle_interact() -> void:
	var aim := _player._aim_target()
	if aim.get("type") == "barrow":
		_player._start_barrow(aim["barrow"])
		return
	if aim.get("type") != "log":
		return
	var log := aim["log"] as FallingLog
	var weight := log.get_weight()
	if weight <= _player.carry_capacity:
		_player._start_carry(log, weight)
	elif weight <= _player.drag_capacity:
		_player._start_drag(log)
	# Тяжелее предела волока — только тачкой (прокачку добавим позже): остаётся «никак».
