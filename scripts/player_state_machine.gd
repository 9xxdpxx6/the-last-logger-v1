extends Node

# Машина состояний игрока. Гоняет физику активного состояния каждый физкадр. Сами состояния —
# дочерние узлы (Idle/Carry/Drag/Barrow). Player остаётся «диспетчером»: владеет примитивами
# движения, а ЧЕМ из них рулить в этом кадре — решает здесь.
#
# (Этап 4a) Активное состояние пока ВЫВОДИМ из того, что игрок держит — ровно та же приоритезация,
# что была в старом _physics_process (тачка → волок → перенос → налегке). В под-шаге 4c это станет
# явными переходами (_start_*/_stop_* будут переключать состояние), а флаги уйдут.

@onready var _player: Player = get_parent() as Player
@onready var _idle: PlayerState = $Idle
@onready var _carry: PlayerState = $Carry
@onready var _drag: PlayerState = $Drag
@onready var _barrow: PlayerState = $Barrow
@onready var _manipulate: PlayerState = $Manipulate


func _physics_process(delta: float) -> void:
	active().physics_update(delta)


# Активное состояние (его дёргает и Player для подсказки/E). Публичное.
func active() -> PlayerState:
	if _player.manipulated_log() != null:
		return _manipulate
	if _player.held_barrow() != null:
		return _barrow
	if _player.dragged_log() != null:
		return _drag
	if _player.carried_log() != null:
		return _carry
	return _idle
