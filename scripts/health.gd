extends Node

# Здоровье игрока: запас HP, урон, полоска в HUD, смерть. Раньше жило в player.gd
# (take_damage/_die/_update_hp_bar); вынесено в узел-компонент. Player остаётся фасадом —
# его take_damage() просто пересылает сюда, поэтому внешние вызовы (бревно бьёт игрока:
# falling_log.gd → player.take_damage) менять не нужно.

@export_group("Здоровье")
## Максимум HP. Урон от брёвен считается как масса × скорость × damage_scale (в дереве).
@export var max_hp: float = 100.0

# Полоска HP живёт в HUD игрока (сосед по дереву) — берём по пути от родителя.
@onready var _hp_bar: ProgressBar = get_parent().get_node("HUD/HpBar")
@onready var _hp_label: Label = get_parent().get_node("HUD/HpBar/HpLabel")

## Текущее здоровье. Падает от ударов брёвен; на нуле — смерть (перезапуск сцены).
var _hp: float = 100.0


func _ready() -> void:
	# Полное здоровье на старте + сразу отрисовать полоску.
	_hp = max_hp
	_update_bar()


## Вычесть урон по HP (через фасад Player.take_damage зовётся бревном при ударе). На нуле — смерть.
func take_damage(amount: float) -> void:
	if amount <= 0.0 or _hp <= 0.0:
		return
	_hp = clampf(_hp - amount, 0.0, max_hp)
	_update_bar()
	if _hp <= 0.0:
		_die()


func _die() -> void:
	print("СМЕРТЬ: HP кончились. Перезапуск сцены.")
	get_tree().reload_current_scene()


# Красная полоска HP слева снизу: заполнение по доле здоровья, цифра — целые HP.
func _update_bar() -> void:
	if _hp_bar:
		_hp_bar.value = _hp / maxf(max_hp, 0.01) * 100.0
	if _hp_label:
		_hp_label.text = "%.0f" % _hp
