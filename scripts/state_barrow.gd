extends PlayerState

# Barrow (тачка): полный override движения — ведём тачку напрямую WASD и приклеиваем игрока к ручкам
# (#3,#4,#5,#6). E — поставить тачку. Вес НЕ показываем (тачка в руках — загрузку видно при наведении
# на неё, когда она не в руках).
func physics_update(delta: float) -> void:
	_player._drive_barrow(delta)


func prompt_text() -> String:
	return tr("PROMPT_BARROW_DROP")


func handle_interact() -> void:
	_player._stop_barrow()
