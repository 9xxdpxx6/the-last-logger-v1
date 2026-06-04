extends Node3D

## Вьюмодель топора в руках. Управление: зажал ЛКМ — топор уходит в замах и ЖДЁТ
## (целишься камерой), отпустил — резкий удар в сторону недавнего движения мыши.
## Логику попадания/урона делает игрок по сигналу impact.

## Поза покоя топора относительно камеры (м). Тут топор «висит» между ударами.
@export var rest_position: Vector3 = Vector3(0.33, -0.34, -0.62)
## Наклон топора в покое (градусы): голова чуть отведена назад и вбок — готовность.
@export var rest_rotation_deg: Vector3 = Vector3(15, -8, 10)

## Время ухода в замах при зажатии ЛКМ (с).
@export var windup_time: float = 0.22
## Доворот во взводе (+X = голова уходит назад-вверх, над плечом).
@export var windup_rotation_deg: Vector3 = Vector3(48, 0, 0)
## Смещение во взводе (м, поверх позы покоя) — вверх и чуть к себе.
@export var windup_offset: Vector3 = Vector3(0.0, 0.08, 0.10)

## Быстрая фаза удара (с) — мах вперёд-вниз.
@export var strike_time: float = 0.11
## Возврат в покой (с).
@export var recover_time: float = 0.24
## Доворот в момент удара (−X = резкий мах вперёд-вниз, лезвием в дерево).
@export var impact_rotation_deg: Vector3 = Vector3(-100, 0, 0)
## Смещение в момент удара (м). X сводит лезвие к ЦЕНТРУ экрана (прицелу), −Z —
## вперёд, вниз. Подобрано так, чтобы голова топора падала в перекрестье.
@export var impact_offset: Vector3 = Vector3(-0.33, -0.20, -0.30)

## Боковой увод удара при горизонтальном прицеле (рыскание, град).
@export var side_yaw_deg: float = 45.0
## Крен топора при боковом замахе (град) — задаёт ПЛОСКОСТЬ лезвия (диагональ руба).
@export var side_roll_deg: float = 80.0
## Влияние вертикального прицела на крутизну удара (град).
@export var steep_deg: float = 60.0
## Случайный разброс угла каждого удара (град).
@export var jitter_deg: float = 6.0

## Лезвие «кусает» — здесь игрок делает рейкаст, урон, кик и щепки.
signal impact

var _rest_rotation: Vector3 = Vector3.ZERO
var _charging: bool = false
var _busy: bool = false
var _tween: Tween


func _ready() -> void:
	position = rest_position
	_rest_rotation = _deg(rest_rotation_deg)
	rotation = _rest_rotation


## ЛКМ зажата — уводим топор в замах и держим там (целимся камерой).
func begin_windup() -> void:
	if _busy:
		return
	_charging = true
	if _tween and _tween.is_valid():
		_tween.kill()
	var wrot := _rest_rotation + _deg(windup_rotation_deg)
	var wpos := rest_position + windup_offset
	_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "rotation", wrot, windup_time)
	_tween.parallel().tween_property(self, "position", wpos, windup_time)


## ЛКМ отпущена — бьём. aim (x: лево/право, y: низ/верх) задаёт сторону/крутизну и
## ПЛОСКОСТЬ лезвия. Можно бить и без замаха (короткий тап) — стартуем из текущей позы.
func release_strike(aim: Vector2) -> void:
	if not _charging:
		return
	_charging = false
	_busy = true
	if _tween and _tween.is_valid():
		_tween.kill()

	# Знак инвертирован — топор наклоняется В сторону прицела.
	var side := -aim.x
	var steep := -aim.y
	var jx := randf_range(-jitter_deg, jitter_deg)
	var jz := randf_range(-jitter_deg, jitter_deg)

	# Удар: крутизна от W/S, крен (плоскость лезвия) от A/D и протяжки мыши. Боковой
	# увод оставляем малым (×0.3), чтобы лезвие всё равно падало в центр прицела.
	var impact_rot := _rest_rotation + _deg(Vector3(
		impact_rotation_deg.x - steep * steep_deg + jx * 0.3,
		side * side_yaw_deg * 0.3,
		side * side_roll_deg + jz
	))
	var impact_pos := rest_position + impact_offset

	_tween = create_tween().set_trans(Tween.TRANS_SINE)
	# Резкий мах вперёд-вниз.
	_tween.tween_property(self, "rotation", impact_rot, strike_time).set_ease(Tween.EASE_IN)
	_tween.parallel().tween_property(self, "position", impact_pos, strike_time) \
		.set_ease(Tween.EASE_IN)
	# Момент контакта: рейкаст/урон/кик/щепки делает игрок.
	_tween.tween_callback(func() -> void: impact.emit())
	# Возврат в покой.
	_tween.tween_property(self, "rotation", _rest_rotation, recover_time) \
		.set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(self, "position", rest_position, recover_time) \
		.set_ease(Tween.EASE_OUT)
	_tween.tween_callback(func() -> void: _busy = false)


func _deg(v: Vector3) -> Vector3:
	return Vector3(deg_to_rad(v.x), deg_to_rad(v.y), deg_to_rad(v.z))
