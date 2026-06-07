extends Node3D

## Вьюмодель топора. Управление: зажал ЛКМ — топор уходит в замах и ЖДЁТ (целишься камерой),
## отпустил — резкий удар, голова топора падает В ПЕРЕКРЕСТЬЕ (центр экрана). Логику попадания/урона
## делает игрок по сигналу impact.
##
## ВАЖНО (#9g): топор — ДОЧЕРНИЙ узел Camera3D (пространство камеры). Все позы/смещения заданы так,
## чтобы конец удара сходился в ЦЕНТР экрана при любом угле (A/D/мышь лишь смещают ЗАХОД и силу, но
## impact_offset.x возвращает лезвие в центр). Руку player.gd каждый кадр НАВОДИТ на топор, поэтому
## он выглядит зажатым в руке и рука машет вместе с ним — но «прицельность» даёт именно камера-спейс.

## Поза покоя топора относительно КАМЕРЫ (м). Тут топор «висит» между ударами справа-снизу.
@export var rest_position: Vector3 = Vector3(0.33, -0.34, -0.62)
## Наклон топора в покое (градусы): голова чуть отведена назад и вбок — готовность.
@export var rest_rotation_deg: Vector3 = Vector3(15, -8, 10)
## Масштаб топора (в камера-спейсе родной размер — 1).
@export var hand_scale: float = 1.0

## Время ухода в замах при зажатии ЛКМ (с).
@export var windup_time: float = 0.22
## Доворот во взводе ВЕРТИКАЛЬНОГО руба (+X = голова уходит назад-вверх, над плечом).
@export var windup_rotation_deg: Vector3 = Vector3(48, 0, 0)
## Смещение во взводе (м, поверх позы покоя) — вверх и чуть к себе.
@export var windup_offset: Vector3 = Vector3(0.0, 0.08, 0.10)
## Куда заносится ГОЛОВА топора во взводе ВЕРТИКАЛЬНОГО удара (точка в пр-ве камеры отн. центра, м):
## вверх и чуть назад к себе — топор над плечом перед рубом вниз.
@export var windup_head_offset: Vector3 = Vector3(0.0, 0.45, 0.18)
## Боковой занос ГОЛОВЫ во взводе ГОРИЗОНТАЛЬНОГО удара (м). Голова уходит вбок на высоте центра, а
## удар сводит её в перекрестье — получается горизонтальный мах поперёк, а не «дёрганье» кистью (#2).
@export var windup_sweep: float = 0.55

## Быстрая фаза удара (с) — мах вперёд-вниз.
@export var strike_time: float = 0.11
## Возврат в покой (с).
@export var recover_time: float = 0.24
## Доворот в момент удара (−X = резкий мах вперёд-вниз, лезвием в дерево).
@export var impact_rotation_deg: Vector3 = Vector3(-100, 0, 0)
## КУДА должна прийти ГОЛОВА топора в момент удара — точка в пространстве камеры (м). x=0,y=0 = центр
## экрана (перекрестье), z<0 = вперёд по взгляду. Позицию топора считаем ОБРАТНО от этой точки через
## поворот удара (см. release_strike), поэтому голова попадает в прицел при ЛЮБОМ угле захода (#9h).
@export var impact_center: Vector3 = Vector3(0.0, 0.0, -0.85)
## Доп. подстройка точки удара (м) поверх impact_center — обычно 0.
@export var impact_offset: Vector3 = Vector3(0.0, 0.0, 0.0)
## Центр ГОЛОВЫ топора в его ЛОКАЛЬНЫХ координатах (м) — из axe.tscn (Head на (0,0.56,-0.07)). По нему
## вычисляем позицию топора так, чтобы голова села в impact_center независимо от поворота лезвия.
@export var head_local_offset: Vector3 = Vector3(0.0, 0.56, -0.07)
## С какой готовности удара (0..1) разрешаем прервать его новым замахом. Клик раньше этого порога
## ИГНОРИРУЕТСЯ — топор доигрывает удар (без дёрганья при частых кликах, #2). Прерывание у самого
## конца (≥0.9) даёт «прерывающий» удар чуть слабее (силу считает player.gd).
@export var interrupt_progress: float = 0.9

## Нормализованная фаза замаха для РУКИ, которую читает player.gd и качает всё предплечье:
## 0 — покой, −1 — взвод (рука назад-вверх), +1 — момент удара (рука вперёд-вниз). Это главное
## движение: рука несёт топор, а не топор болтается в неподвижной кисти.
var swing_amount: float = 0.0

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
## Время старта удара (мс) — по нему считаем готовность анимации strike_progress() (#2).
var _strike_start_ms: int = 0


func _ready() -> void:
	position = rest_position
	_rest_rotation = _deg(rest_rotation_deg)
	rotation = _rest_rotation
	scale = Vector3.ONE * hand_scale


## Идёт ли сейчас удар/возврат (анимация не завершена). Игрок по этому решает, что новый удар —
## «прерывающий» (рубим раньше окончания), и снижает его силу (#4).
func is_busy() -> bool:
	return _busy


## Готовность текущего удара 0..1 (1 — анимация завершена/нет удара). Считаем по времени с старта
## удара относительно полной длительности (мах + возврат). Нужно, чтобы решить, можно ли прерывать.
func strike_progress() -> float:
	if not _busy:
		return 1.0
	var total := maxf(strike_time + recover_time, 0.001)
	return clampf((Time.get_ticks_msec() - _strike_start_ms) / 1000.0 / total, 0.0, 1.0)


## ЛКМ зажата — уводим топор в замах. Возвращает true, если замах ПРИНЯТ. Пока предыдущий удар
## доигрывает и не дошёл до interrupt_progress — клик ИГНОРИРУЕМ (false): топор спокойно доигрывает
## удар, без дёрганья при частых кликах (#2). У самого конца удара (≥порога) — прерываем новым замахом.
func begin_windup(aim_hint: Vector2 = Vector2.ZERO) -> bool:
	if _busy and strike_progress() < interrupt_progress:
		return false
	_charging = true
	_busy = false
	if _tween and _tween.is_valid():
		_tween.kill()
	# Поза взвода зависит от стороны (A/D, известно на нажатии): вертикальный руб заносит топор над
	# плечом, боковой — уводит голову ВБОК на высоту центра, чтобы потом смести её поперёк в перекрестье.
	var w := _strike_pose(aim_hint, false)
	_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "rotation", w["rot"], windup_time)
	_tween.parallel().tween_property(self, "position", w["pos"], windup_time)
	return true


## ЛКМ отпущена — бьём. aim (x: лево/право, y: низ/верх) задаёт СТИЛЬ удара: |x|→1 — горизонтальный
## мах поперёк (топор почти горизонтально), x≈0 — вертикальный руб сверху. ГОЛОВА в любом случае
## сходится в перекрестье (центр экрана), угол лишь меняет ЗАХОД (#2).
func release_strike(aim: Vector2) -> void:
	if not _charging:
		return
	_charging = false
	_busy = true
	_strike_start_ms = Time.get_ticks_msec()
	if _tween and _tween.is_valid():
		_tween.kill()

	var hit := _strike_pose(aim, true)

	_tween = create_tween().set_trans(Tween.TRANS_SINE)
	# Мах в удар: голова идёт В перекрестье (сверху при рубе, поперёк при боковом).
	_tween.tween_property(self, "rotation", hit["rot"], strike_time).set_ease(Tween.EASE_IN)
	_tween.parallel().tween_property(self, "position", hit["pos"], strike_time) \
		.set_ease(Tween.EASE_IN)
	# Момент контакта: рейкаст/урон/кик/щепки делает игрок.
	_tween.tween_callback(func() -> void: impact.emit())
	# Возврат в покой.
	_tween.tween_property(self, "rotation", _rest_rotation, recover_time) \
		.set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(self, "position", rest_position, recover_time) \
		.set_ease(Tween.EASE_OUT)
	_tween.tween_callback(func() -> void: _busy = false)


## Поза топора для взвода (is_impact=false) или удара (is_impact=true) при заданном прицеле aim.
## Возвращает {"pos","rot"} в пространстве камеры. Считаем ДВА стиля и смешиваем по |aim.x|:
##  • ВЕРТИКАЛЬНЫЙ руб (|x|≈0): взвод над плечом → удар вниз, голова в центр.
##  • ГОРИЗОНТАЛЬНЫЙ мах (|x|≈1): топор почти горизонтально (крен ~side_roll_deg), голова заносится
##    вбок (windup_sweep) и сводится поперёк в центр. Поворот у взвода и удара ОДИНАКОВ → не «дёргает»
##    кистью, а ведёт ровный мах поперёк.
## Позицию в обоих стилях считаем ОБРАТНО от целевой точки головы (#9h): pos = head − Basis·(head·scale),
## поэтому ГОЛОВА топора садится ровно в нужную точку (в ударе — всегда перекрестье).
func _strike_pose(aim: Vector2, is_impact: bool) -> Dictionary:
	var s := clampf(aim.x, -1.0, 1.0)
	var horiz := absf(s)                 # 0 — вертикальный руб … 1 — горизонтальный боковой
	var steep := -aim.y

	# Поворот: смешиваем вертикальный руб (крутизна по W/S) и горизонтальный мах (крен к горизонту).
	var jz := randf_range(-jitter_deg, jitter_deg) if is_impact else 0.0
	var jx := randf_range(-jitter_deg, jitter_deg) if is_impact else 0.0
	var v_rot: Vector3
	if is_impact:
		v_rot = _rest_rotation + _deg(Vector3(impact_rotation_deg.x - steep * steep_deg + jx, 0.0, 0.0))
	else:
		v_rot = _rest_rotation + _deg(windup_rotation_deg)
	var h_rot := _rest_rotation + _deg(Vector3(0.0, s * side_yaw_deg, s * side_roll_deg + jz))
	var rot := v_rot.lerp(h_rot, horiz)
	var basis := Basis.from_euler(rot)

	if is_impact:
		# УДАР: привязываем ГОЛОВУ к перекрестью (#9h) — pos = center − Basis·(head·scale). Так лезвие
		# приходит ровно в центр экрана при любом угле, а голова «ведёт» удар туда.
		var pos := (impact_center + impact_offset) - basis * (head_local_offset * hand_scale)
		return {"pos": pos, "rot": rot}
	# ВЗВОД: привязываем за РУКОЯТЬ (origin топора = низ ручки, там кисть). Топор крутится вокруг
	# КОНЦА РУЧКИ, а не вокруг лезвия — кисть держит топор естественно, рука синхронна (#9i). Боковой
	# мах дополнительно уводит рукоять вбок (windup_sweep), чтобы из неё смести лезвие поперёк в центр.
	var v_pos := rest_position + windup_offset
	var h_pos := rest_position + windup_offset + Vector3(s * windup_sweep, 0.0, 0.0)
	var wpos := v_pos.lerp(h_pos, horiz)
	return {"pos": wpos, "rot": rot}


func _deg(v: Vector3) -> Vector3:
	return Vector3(deg_to_rad(v.x), deg_to_rad(v.y), deg_to_rad(v.z))
