extends CharacterBody3D

## Скорость обычной ходьбы, м/с.
@export var walk_speed: float = 4.0
## Во сколько раз быстрее игрок двигается при беге (Shift).
@export var run_multiplier: float = 1.6
## Чувствительность мыши (радиан на пиксель движения).
@export var mouse_sensitivity: float = 0.003
## Ограничение наклона взгляда вверх/вниз, в градусах.
@export var max_look_angle: float = 89.0
## Высота прыжка в метрах. Скорость толчка считается из неё и гравитации.
@export var jump_height: float = 1.2
## Управление в воздухе: 0 — нет (полная инерция), 1 — почти как на земле.
@export var air_control: float = 0.5
## Сила (Н), с которой игрок давит на физтела при контакте — по сути вес лесоруба.
## Прикладывается честно в точку под ногой, поэтому хватает реалистичного значения
## (~вес тела). Больше — резче перевешивает; слишком много швыряет бревно.
@export var push_force: float = 2000.0
## Отдача камеры вверх при попадании топором (градусы) — «весомость» удара.
@export var kick_pitch_deg: float = 1.2
## Случайный крен камеры при попадании (градусы, в обе стороны).
@export var kick_roll_deg: float = 0.5
## Случайный рывок камеры вбок при попадании (градусы) — разнообразит отдачу.
@export var kick_yaw_deg: float = 0.8
## Скорость возврата камеры после кика (1/с): больше — быстрее успокаивается.
@export var kick_recover_speed: float = 12.0
## Чувствительность «протяжки» топора мышью: сколько прицела даёт пиксель движения
## мыши, пока зажата ЛКМ. Двигаешь мышь поперёк дерева — топор бьёт в ту сторону.
@export var drag_sensitivity: float = 0.012
## Затухание накопленной протяжки (1/с): прицел от мыши плавно сбрасывается к нулю,
## так удар идёт по СВЕЖЕМУ движению руки, а не по всей истории.
@export var drag_decay: float = 5.0
## Импульс (Н·с), которым лезвие толкает свободные физтела при попадании. Скорость от
## него = импульс / масса: лёгкие поленья сдвигаются заметно, тяжёлые брёвна — еле-еле.
@export var axe_push_impulse: float = 112.0
## На сколько метров перед игроком кладётся брошенное бревно.
@export var drop_distance: float = 1.2

@export_group("Переноска брёвен")
## Грузоподъёмность (кг): бревно тяжелее поднять нельзя (позже добавим прогрессию).
@export var carry_capacity: float = 70.0
## Множитель скорости при бревне НА ПРЕДЕЛЕ грузоподъёмности (1 — без замедления).
## Лёгкое бревно почти не тормозит, у предела — вот настолько медленно.
@export var carry_min_speed_mult: float = 0.45
## Доля грузоподъёмности, ниже которой бревно несут на ЛЕВОМ плече (топор в правой руке),
## а на/выше — на правом плече (топор убран в карман до сброса).
@export var shoulder_left_fraction: float = 0.4
## Сила удара топором, когда бревно лежит на ЛЕВОМ плече (топор в правой руке) — рубим
## слабее, рука занята. 1 — без штрафа, 0.5 — вдвое слабее.
@export var carry_chop_power_mult: float = 0.5
## Предел ВОЛОКА (кг): бревно тяжелее грузоподъёмности, но не тяжелее этого, можно тащить
## волоком. Тяжелее — никак (позже: тачка/прокачка). 170.49: бревно, показывающее «170 кг»
## (т.е. вес ≤170.49 после округления), ещё тащится; «171 кг» (≥170.5) — уже слишком тяжёлое.
@export var drag_capacity: float = 170.49
## Множитель скорости волока для ЛЁГКОГО бревна (чуть тяжелее грузоподъёмности). Бежать нельзя.
## ВАЖНО: физика волока сама ограничивает скорость ~1.3 м/с, поэтому реально различие лёгкого
## и тяжёлого задаёт НИЖНИЙ множитель — чем он меньше, тем заметнее тяжёлое медленнее.
@export var drag_speed_mult: float = 0.75
## Множитель скорости волока для САМОГО ТЯЖЁЛОГО бревна (у предела волока). Между лёгким и
## тяжёлым скорость интерполируется по массе — тяжёлое тащить ощутимо медленнее.
@export var drag_speed_heavy_mult: float = 0.24
## Множитель скорости, когда игрок ТОЛКАЕТ бревно перед собой (идёт на него). Толкать почти
## нельзя — тащат назад/вбок. 0.04 = в 25 раз медленнее, чем тащить.
@export var drag_push_speed_mult: float = 0.04
## На сколько метров ПЕРЕД игроком «рука» держит схваченный торец бревна.
@export var drag_grab_distance: float = 0.8
## Высота (м), на которую «рука» поднимает схваченный торец над землёй — вид «в руке».
## Вдавливание дальнего конца в землю лечит НЕ это, а точка приложения силы (см. drag_pull).
@export var drag_grab_lift: float = 1.3
## Предел длины рук (м): дальше этого схваченный торец от точки рук не отпускается (поводок).
@export var drag_arm_reach: float = 0.35
## «Сцепление» дальнего конца с землёй при волоке: гасит ГОРИЗОНТАЛЬНУЮ скорость лежащего
## на земле торца. Больше — дальний конец сильнее «якорится»: при тяге вбок бревно поворачивает
## ПО РАДИУСУ (ближний конец в руках водит, дальний почти стоит), а не едет целиком.
@export var drag_tail_grip: float = 8.0
## Жёсткость «руки» при волоке: больше — резче подтягивает торец к точке у рук. Должна быть
## достаточной, чтобы тяга пересиливала трение лежащего конца (иначе бревно «не едет» назад).
@export var drag_stiffness: float = 24.0
## Гашение в «руке»: гасит рывки/раскачку торца. Больше — спокойнее, инертнее тянется.
@export var drag_damping: float = 6.0
## Потолок тянущей силы (Н) — чтобы тяжёлое бревно не «выстреливало» и оставалось инертным.
@export var drag_max_force: float = 20000.0
## Замедление поворота камеры при волоке (инертнее): 1 — как обычно, 0.8 — на 20% медленнее.
@export var drag_look_mult: float = 0.8
## Ограничение поворота тела при волоке в каждую сторону от исходного направления (градусы):
## ~82° → обзор ~164°, обойти вокруг бревна нельзя (надо бросить и взять заново).
@export var drag_yaw_limit: float = 82.0

@export_group("Здоровье")
## Максимум HP. Урон от брёвен считается как масса × скорость × damage_scale (в дереве).
@export var max_hp: float = 100.0

var _jump_velocity: float = 0.0
## Несомое бревно (или null). Несёшь — медленнее ходишь, тяжёлое — сильнее.
var _carried: FallingLog = null
## Текущий множитель скорости от веса в руках (1 — налегке).
var _carry_speed_mult: float = 1.0
## Бревно, которое тащим волоком (или null). Пока тащим — медленно, без бега, без рубки.
var _dragged: FallingLog = null
## Множитель скорости текущего волока (зависит от массы бревна; считается в _start_drag).
var _drag_speed_mult: float = 1.0
## Направление тела (yaw, рад) в момент начала волока — от него считаем ограничение поворота.
var _drag_yaw_center: float = 0.0
## Текущее здоровье. Падает от ударов брёвен; на нуле — смерть (перезапуск сцены).
var _hp: float = 100.0
## Топор убран (несём тяжёлое бревно на правом плече) — рубить нельзя.
var _axe_stowed: bool = false
## Наклон взгляда вверх/вниз (рад). Храним отдельно, чтобы кик камеры можно было
## накладывать поверх, не ломая ограничение обзора.
var _look_pitch: float = 0.0
## Текущая отдача камеры (рад): x — тангаж, y — рыскание, z — крен. Затухает к нулю.
var _kick: Vector3 = Vector3.ZERO
## Прицел последнего замаха (x: лево/право, y: верх/низ) — для варьирования кика.
var _last_aim: Vector2 = Vector2.ZERO
## ЛКМ зажата — топор в замахе, целимся. Удар будет на отпускании.
var _charging: bool = false
## Недавнее движение мыши (x: лево/право, y: низ/верх) — задаёт угол/плоскость удара
## на отпускании. Копится во время замаха, плавно затухает → важно движение У САМОГО
## отпускания («двинул камеру и ударил»).
var _aim_drag: Vector2 = Vector2.ZERO

@onready var camera: Camera3D = $Camera3D
@onready var chop_ray: ShapeCast3D = $Camera3D/ChopRay
@onready var axe: Node3D = $Camera3D/Axe
@onready var prompt: Label = $HUD/Prompt
@onready var hp_bar: ProgressBar = $HUD/HpBar
@onready var hp_label: Label = $HUD/HpBar/HpLabel


func _ready() -> void:
	# Захватываем курсор при старте: мышь скрыта и привязана к окну.
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# v = sqrt(2*g*h): какая скорость вверх нужна, чтобы подняться на jump_height.
	var g: float = ProjectSettings.get_setting("physics/3d/default_gravity")
	_jump_velocity = sqrt(2.0 * g * jump_height)
	# Топор сообщает момент укуса лезвия — тогда и считаем попадание.
	axe.impact.connect(_on_axe_impact)
	# Полное здоровье на старте + сразу отрисовать полоску.
	_hp = max_hp
	_update_hp_bar()


## Вычесть урон по HP (зовётся бревном при ударе). На нуле — смерть.
func take_damage(amount: float) -> void:
	if amount <= 0.0 or _hp <= 0.0:
		return
	_hp = clampf(_hp - amount, 0.0, max_hp)
	_update_hp_bar()
	if _hp <= 0.0:
		_die()


func _die() -> void:
	print("СМЕРТЬ: HP кончились. Перезапуск сцены.")
	get_tree().reload_current_scene()


# Красная полоска HP слева снизу: заполнение по доле здоровья, цифра — целые HP.
func _update_hp_bar() -> void:
	if hp_bar:
		hp_bar.value = _hp / maxf(max_hp, 0.01) * 100.0
	if hp_label:
		hp_label.text = "%.0f" % _hp


func _unhandled_input(event: InputEvent) -> void:
	# Обзор мышью работает только когда курсор захвачен.
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		# На волоке камера инертнее (медленнее) — обе руки заняты бревном.
		var look_mult := drag_look_mult if _dragged != null else 1.0
		# Поворот тела влево/вправо (по оси Y).
		rotate_y(-event.relative.x * mouse_sensitivity * look_mult)
		# На волоке нельзя крутиться вокруг бревна: держим тело в пределах ±drag_yaw_limit
		# от направления, с которым взяли (за спиной волочится бревно).
		if _dragged != null:
			var off := angle_difference(_drag_yaw_center, rotation.y)
			var lim := deg_to_rad(drag_yaw_limit)
			if absf(off) > lim:
				rotation.y = _drag_yaw_center + clampf(off, -lim, lim)
		# Наклон взгляда вверх/вниз копим отдельно — кик камеры наложим в _process.
		_look_pitch -= event.relative.y * mouse_sensitivity * look_mult
		_look_pitch = clampf(
			_look_pitch,
			deg_to_rad(-max_look_angle),
			deg_to_rad(max_look_angle)
		)
		# Во время замаха то же движение мыши копим как угол будущего удара: камера
		# крутится, А топор «прицеливается». Право/вверх мыши = право/вверх удара.
		if _charging:
			_aim_drag.x += event.relative.x * drag_sensitivity
			_aim_drag.y += -event.relative.y * drag_sensitivity

	# E — поднять бревно, на которое смотрим / бросить то, что несём.
	if event.is_action_pressed("interact") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_toggle_carry()

	# Esc отпускает курсор, клик по окну — снова захватывает.
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed \
			and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	# Рубка: зажал ЛКМ — топор в замах (целимся); отпустил — удар под текущим углом.
	if event.is_action_pressed("chop") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED \
			and not _axe_stowed and _dragged == null:
		_charging = true
		_aim_drag = Vector2.ZERO
		axe.begin_windup()
	elif event.is_action_released("chop") and _charging:
		var move := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		var aim := Vector2(move.x, -move.y) + _aim_drag
		aim.x = clampf(aim.x, -1.0, 1.0)
		aim.y = clampf(aim.y, -1.0, 1.0)
		_last_aim = aim
		_charging = false
		axe.release_strike(aim)


func _process(delta: float) -> void:
	# Отдача затухает к нулю; итоговый наклон камеры = взгляд + кик.
	_kick = _kick.lerp(Vector3.ZERO, clampf(kick_recover_speed * delta, 0.0, 1.0))
	camera.rotation = Vector3(_look_pitch + _kick.x, _kick.y, _kick.z)

	# Прицел затухает, пока целимся — важно движение мыши У САМОГО отпускания.
	if _charging:
		_aim_drag = _aim_drag.lerp(Vector2.ZERO, clampf(drag_decay * delta, 0.0, 1.0))

	_update_prompt()


# Подсказка под прицелом: что сделает E прямо сейчас. Тексты — через tr() (ключи в
# localization/translations.csv), {kg} подставляется форматированием — легко переводить.
func _update_prompt() -> void:
	if not prompt:
		return
	# Уже что-то несём/тащим — подсказка про сброс (E).
	if _carried != null:
		prompt.text = tr("PROMPT_DROP").format({"kg": "%.0f" % _carried.get_weight()})
		return
	if _dragged != null:
		prompt.text = tr("PROMPT_DROP").format({"kg": "%.0f" % _dragged.get_weight()})
		return
	var log := _look_pickup_log(false)
	if log == null:
		prompt.text = ""
		return
	var w := log.get_weight()
	# Посильное — берём в руки; тяжелее, но в пределах волока — тащим; ещё тяжелее — никак.
	if w <= carry_capacity:
		prompt.text = tr("PROMPT_PICKUP").format({"kg": "%.0f" % w})
	elif w <= drag_capacity:
		prompt.text = tr("PROMPT_DRAG").format({"kg": "%.0f" % w})
	else:
		prompt.text = tr("PROMPT_TOO_HEAVY").format({"kg": "%.0f" % w})


# Бревно под прицелом (в группе pickup_log) или null. force — пересчитать луч сейчас.
# Бревно, на котором СВЕРХУ что-то лежит (не «верхнее»), пропускаем: его нельзя ни поднять, ни
# тащить, пока не убрать верхний кусок. Если под прицелом есть и оно само сверху — вернём его.
func _look_pickup_log(force: bool) -> FallingLog:
	if force:
		chop_ray.force_shapecast_update()
	for i in chop_ray.get_collision_count():
		var c := chop_ray.get_collider(i)
		if c is FallingLog and (c as Node).is_in_group("pickup_log"):
			if (c as FallingLog).is_covered():
				continue
			return c as FallingLog
	return null


# E: несём/тащим — бросаем; иначе смотрим на бревно — берём в руки или тащим волоком.
func _toggle_carry() -> void:
	if _carried != null:
		_drop_carried()
		return
	if _dragged != null:
		_stop_drag()
		return
	var log := _look_pickup_log(true)
	if log == null:
		return
	var weight := log.get_weight()
	if weight <= carry_capacity:
		_start_carry(log, weight)
	elif weight <= drag_capacity:
		_start_drag(log)
	# Тяжелее предела волока — никак (позже прокачаем грузоподъёмность/тачку).


# Берём бревно в руки на плечо. Лёгкое (< доли предела) — на левое, топор в правой руке;
# тяжёлое — на правое, топор убираем (рубить нельзя, пока несём).
func _start_carry(log: FallingLog, weight: float) -> void:
	var on_left := weight < carry_capacity * shoulder_left_fraction
	_axe_stowed = not on_left
	axe.visible = on_left
	_carried = log
	log.pick_up(camera, _shoulder_pose(on_left))
	_carry_speed_mult = _carry_speed_for(weight)


# Берём бревно на волок: оно остаётся на земле, мы тянем ближний торец. Обе руки заняты —
# топор убираем; скорость падает, бежать нельзя (см. _physics_process и _update_drag).
func _start_drag(log: FallingLog) -> void:
	_dragged = log
	_axe_stowed = true
	axe.visible = false
	# begin_drag сам выбирает БЛИЖНИЙ к игроку торец как точку хвата.
	log.begin_drag(global_position)
	# Скорость волока зависит от массы: лёгкое — почти как ходьба, у предела — заметно медленнее.
	var t := clampf(log.get_weight() / maxf(drag_capacity, 0.01), 0.0, 1.0)
	_drag_speed_mult = lerpf(drag_speed_mult, drag_speed_heavy_mult, t)
	# Единая поза хвата: где бы ни взяли — встаём у БЛИЖНЕГО торца и разворачиваемся ВДОЛЬ бревна
	# (смотрим на него, дальний конец впереди). Так не нужно куче анимаций «взять сбоку/посередине».
	var near := log.grab_point_world()
	var far := log.tail_point_world()
	var dir := far - near
	dir.y = 0.0
	if dir.length() > 0.01:
		dir = dir.normalized()
		# forward игрока (-Z) направляем ВДОЛЬ бревна к дальнему концу.
		rotation.y = atan2(-dir.x, -dir.z)
		# Встаём так, чтобы ближний торец был перед нами на длину рук.
		global_position = Vector3(
			near.x - dir.x * drag_grab_distance,
			global_position.y,
			near.z - dir.z * drag_grab_distance
		)
	# От этого направления ограничиваем поворот камеры при волоке.
	_drag_yaw_center = rotation.y


# Отпускаем волок: бревно снова просто лежит, топор возвращаем в руку.
func _stop_drag() -> void:
	_dragged.end_drag()
	_dragged = null
	_axe_stowed = false
	axe.visible = true


# Каждый физкадр тянем схваченный торец к точке у рук игрока (перед ним, чуть приподнято).
# Бревно — живое физтело: проседает под весом, дальний конец волочится по земле, инерция
# своя. Идём/поворачиваемся — торец следует за «рукой» с задержкой (см. FallingLog.drag_pull).
func _update_drag() -> void:
	if _dragged == null:
		return
	var fwd := -global_transform.basis.z  # направление взгляда (вперёд)
	fwd.y = 0.0
	if fwd.length() < 0.01:
		return
	fwd = fwd.normalized()
	# Точка «в руках»: перед игроком на длину рук, приподнята — бревно тянется ВПЕРЕДИ, видно.
	var hold := global_position + fwd * drag_grab_distance + Vector3.UP * drag_grab_lift
	_dragged.drag_pull(hold, drag_stiffness, drag_damping, drag_max_force,
			drag_arm_reach, drag_tail_grip)


# Кладём несомое бревно перед игроком и возвращаем топор в руку.
func _drop_carried() -> void:
	var forward := -camera.global_transform.basis.z
	forward.y = 0.0
	if forward.length() < 0.01:
		forward = -global_transform.basis.z
	forward = forward.normalized()
	var drop_pos := global_position + forward * drop_distance
	_carried.drop(get_tree().current_scene, drop_pos, forward)
	_carried = null
	_carry_speed_mult = 1.0
	_axe_stowed = false
	axe.visible = true


# Множитель скорости от веса в руках: 1 у лёгкого, carry_min_speed_mult у предела.
func _carry_speed_for(weight: float) -> float:
	var t := clampf(weight / maxf(carry_capacity, 0.01), 0.0, 1.0)
	return lerpf(1.0, carry_min_speed_mult, t)


# Поза бревна на плече относительно камеры: лежит вдоль взгляда, смещено на нужное плечо,
# чуть ниже глаз. Левое плечо — топор в правой руке; правое — топор убран.
func _shoulder_pose(on_left: bool) -> Transform3D:
	var side := -0.32 if on_left else 0.32
	# Поворот вокруг X кладёт длинную ось бревна (локальный Y) почти вдоль взгляда (за спину),
	# с лёгким наклоном — будто закинуто на плечо.
	var basis := Basis(Vector3(1.0, 0.0, 0.0), deg_to_rad(95.0))
	return Transform3D(basis, Vector3(side, -0.05, -0.15))


# Вызывается топором в момент удара лезвия. Тут решаем, попали ли по стволу.
# ShapeCast — «толстый луч» (сфера r=0.15): прицел прощающий, у лезвия есть толщина.
func _on_axe_impact() -> void:
	chop_ray.force_shapecast_update()
	if not chop_ray.is_colliding():
		return
	# Что-то задели лезвием — даём варьирующуюся отдачу камере.
	_apply_kick()

	# Индекс 0 — ближайшее попадание (результаты идут от близких к дальним).
	var target := chop_ray.get_collider(0)
	if target == null:
		return
	var point := chop_ray.get_collision_point(0)
	var normal := chop_ray.get_collision_normal(0)

	# Сила удара = насколько он ПЕРПЕНДИКУЛЯРЕН стволу. В лоб (взгляд против нормали) —
	# полный урон/глубокая зарубка; вскользь — слабо. perp: 0 (касательно)..1 (в лоб).
	var forward := -camera.global_transform.basis.z
	var perp := clampf(forward.dot(-normal), 0.0, 1.0)
	var power := lerpf(0.35, 1.3, perp)
	# Несём бревно на левом плече (топор в правой руке) — бьём слабее, рука занята.
	if _carried != null:
		power *= carry_chop_power_mult

	# Плоскость лезвия в момент удара — ось X топора (вдоль режущей кромки). По ней
	# ориентируем зарубку (диагональный руб даёт диагональную зарубку).
	var edge := axe.global_transform.basis.x

	# Толкаем свободные физтела лезвием: лёгкие поленья сдвигаются заметно, тяжёлые брёвна
	# почти нет (скорость = импульс/масса). Замороженные (стволы/пни) пропускаем — их не
	# сдвинуть, только рубить. Импульс — в точку удара, поэтому полено ещё и подкручивается.
	if target is RigidBody3D and not (target as RigidBody3D).freeze:
		var rb := target as RigidBody3D
		rb.apply_impulse(forward * axe_push_impulse * power, point - rb.global_position)

	# Луч попадает в дочерний TrunkBody, метод chop() — на родительском узле дерева.
	if target.has_method("chop"):
		target.chop(global_position, point, normal, power, edge)
	elif target.get_parent() and target.get_parent().has_method("chop"):
		target.get_parent().chop(global_position, point, normal, power, edge)


# Отдача камеры от удара: тангаж в основном вверх, но с разбросом; крен/рыскание
# случайны и слегка зависят от стороны замаха — так каждый удар ощущается иначе.
func _apply_kick() -> void:
	var pitch := deg_to_rad(kick_pitch_deg) * randf_range(0.5, 1.3)
	var roll := deg_to_rad(kick_roll_deg) * randf_range(0.4, 1.0) * (1.0 if randf() < 0.5 else -1.0)
	roll -= deg_to_rad(kick_roll_deg) * 0.5 * _last_aim.x
	var yaw := deg_to_rad(kick_yaw_deg) * randf_range(-1.0, 1.0)
	_kick += Vector3(pitch, yaw, roll)


func _physics_process(delta: float) -> void:
	var on_floor := is_on_floor()

	# Гравитация в воздухе (значение из настроек проекта).
	if not on_floor:
		velocity += get_gravity() * delta

	# Считываем WASD как вектор и переводим в мировое направление.
	var input_dir := Input.get_vector(
		"move_left", "move_right", "move_forward", "move_back"
	)
	var direction := (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()

	var speed := walk_speed
	# Бежать можно только налегке: не во время волока.
	if Input.is_action_pressed("run") and _dragged == null:
		speed *= run_multiplier
	# Несомое бревно замедляет: множитель зависит от веса (из ресурса LogItem).
	speed *= _carry_speed_mult
	# Волок медленнее обычной ходьбы. Толкать бревно ВДОЛЬ него от себя (гнать дальний конец
	# вперёд) — почти нельзя. ВАЖНО: «толкание» считаем по ОСИ БРЕВНА, а не по взгляду игрока —
	# иначе можно повернуть камеру и быстро толкать бревно «боком». Ось берём из самого бревна
	# (от схваченного торца к дальнему), поэтому поворот взгляда обмануть проверку не может.
	if _dragged != null:
		var axis := _dragged.tail_point_world() - _dragged.grab_point_world()
		axis.y = 0.0
		if direction.length() > 0.01 and axis.length() > 0.01 \
				and direction.dot(axis.normalized()) > 0.3:
			speed *= drag_push_speed_mult
		else:
			speed *= _drag_speed_mult

	if on_floor:
		# На земле — мгновенная отзывчивость, прыжок.
		if direction:
			velocity.x = direction.x * speed
			velocity.z = direction.z * speed
		else:
			velocity.x = move_toward(velocity.x, 0.0, speed)
			velocity.z = move_toward(velocity.z, 0.0, speed)
		# Во время волока прыгать нельзя (обе руки заняты бревном).
		if Input.is_action_just_pressed("jump") and _dragged == null:
			velocity.y = _jump_velocity
	else:
		# В воздухе — ограниченное руление: инерция сохраняется, но подправить можно.
		if direction:
			var accel := 16.0 * air_control * delta
			velocity.x = move_toward(velocity.x, direction.x * speed, accel)
			velocity.z = move_toward(velocity.z, direction.z * speed, accel)

	move_and_slide()
	_push_bodies()
	# Волок: тянем бревно ПОСЛЕ перемещения игрока — по его свежей позиции.
	_update_drag()
	_clamp_to_dragged()


# Нельзя уйти от ЗАСТРЯВШЕГО бревна. Если схваченный торец отстал дальше предела (бревно
# упёрлось в препятствие, а игрок продолжил идти) — подтягиваем игрока обратно к бревну. Так
# при упоре игрок встаёт намертво, пока не бросит бревно (E) или не обойдёт препятствие.
func _clamp_to_dragged() -> void:
	if _dragged == null:
		return
	var grab := _dragged.grab_point_world()
	var to_grab := grab - global_position
	to_grab.y = 0.0
	var max_d := drag_grab_distance + drag_arm_reach + 0.1
	if to_grab.length() > max_d:
		global_position += to_grab.normalized() * (to_grab.length() - max_d)


# Кинематический игрок сам по себе не толкает RigidBody. Передаём ему ВЕС вниз. Где именно
# приложить вес — решаем по ОПОРЕ под ногой (луч вниз сквозь само бревно):
#  • есть опора (пол/куб/другое бревно прямо под точкой) → давим в ЦЕНТР МАСС, БЕЗ момента:
#    бревно на ровной/опёртой поверхности НЕ должно раскручиваться от игрока;
#  • под точкой ПУСТОТА (конец свисает за краем) → давим весом ИМЕННО в эту точку: свисающий
#    конец перевешивает и падает через край, как и должно. Так нет «раскрутки» на ровном, но
#    есть честное опрокидывание нависшего конца.
func _push_bodies() -> void:
	var space := get_world_3d().direct_space_state
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		# Нормаль вверх => мы поверх тела. Боковые/нижние касания игнорируем.
		if c.get_normal().y <= 0.5:
			continue
		var body := c.get_collider()
		if not (body is RigidBody3D) or body.freeze:
			continue
		var rb := body as RigidBody3D
		# Бревно, улёгшись, "засыпает" (sleep) и тогда ИГНОРИРУЕТ силы. Будим на кадр давления.
		rb.sleeping = false

		var contact := c.get_position()
		# Есть ли опора ПОД точкой давления? Луч вниз, СКВОЗЬ само бревно (его исключаем).
		var from := contact + Vector3.UP * 0.05
		var q := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 3.0)
		q.exclude = [rb.get_rid()]
		q.collision_mask = 1 | 4 | 16
		var hit := space.intersect_ray(q)
		var supported := not hit.is_empty() and (from.y - (hit["position"] as Vector3).y) < 0.6
		if supported:
			rb.apply_central_force(Vector3.DOWN * push_force)
		else:
			rb.apply_force(Vector3.DOWN * push_force, contact - rb.global_position)
