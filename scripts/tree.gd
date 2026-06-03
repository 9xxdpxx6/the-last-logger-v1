extends Node3D

## Срабатывает в момент, когда дерево начинает падать.
signal chopped_through(fall_direction: Vector3)

## Сколько ударов нужно, чтобы дерево подрубилось.
@export var chops_to_fell: int = 5
## Начальный толчок (рад/с), задающий сторону падения. Дальше валит гравитация.
@export var initial_tip_speed: float = 0.5
## Множитель гравитации НА ВРЕМЯ ПАДЕНИЯ. >1 ускоряет падение целиком, не меняя
## траекторию (масштаб гравитации = масштаб времени). 1.3 ≈ на 12% быстрее.
@export var fall_gravity_scale: float = 1.3
## "Дожим" (Н·м) у самой вертикали: спасает от зависания/"танца", если стартовый
## толчок потерялся. Срабатывает только пока ствол почти вертикален и не крутится.
@export var launch_assist_torque: float = 20000.0
## Общее гашение вращения лежачего бревна — НИЗКОЕ, чтобы не мешать игроку
## перевешивать (наклон-качели). За остановку качения отвечает roll_damp ниже.
@export var down_angular_damp: float = 0.5
## Гашение линейного скольжения лежачего бревна.
@export var down_linear_damp: float = 0.5
## Скорость гашения КАЧЕНИЯ вокруг длинной оси бревна (1/с). Гасим только эту ось —
## цилиндр-каток перестаёт укатываться как бильярд, но наклон-качели не страдает.
## На уклоне гравитация всё равно пересиливает и бревно катится вниз.
@export var roll_damp: float = 6.0
## Радиус (м) вокруг оси падающего ствола, в котором игрок считается задавленным.
@export var kill_radius: float = 1.1

enum State { STANDING, FALLING, DOWN }

var _chop_count: int = 0
var is_chopped: bool = false
## Горизонтальное направление от ствола к рубящему — "сторона рубки".
var last_chop_direction: Vector3 = Vector3.ZERO
var _player_killed: bool = false

var _state: State = State.STANDING
# Падение настоящей физикой: ствол опрокидывается свободным телом через нижнюю
# кромку основания, как палка/дерево. Никаких шарниров — гравитация валит сама.
var _fall_axis: Vector3 = Vector3.ZERO
var _fall_direction: Vector3 = Vector3.ZERO
# Сколько времени ствол почти не вращается — признак, что он лёг/упёрся.
var _rest_timer: float = 0.0

# Геометрия ствола — для размещения смертельной зоны.
const TRUNK_LENGTH := 9.0
# Гашение вращения на время ПАДЕНИЯ — низкое, чтобы гравитация свободно валила.
const FALL_ANGULAR_DAMP := 0.1
# Ниже этого наклона (рад) и при почти нулевом вращении считаем, что ствол "завис"
# у вертикали — включаем дожим. Нормальное падение этот порог проскакивает мгновенно.
const LAUNCH_STALL_ANGLE := 4.0
const LAUNCH_STALL_SPEED := 0.15
# Наклон (от вертикали), при котором считаем падение завершённым: возвращаем
# нормальное гашение и коллизии. Почти горизонталь.
const DETACH_ANGLE := 80.0
# Если ствол упёрся во что-то раньше (завис под этим углом без вращения столько
# секунд) — тоже считаем, что лёг.
const REST_DETACH_TIME := 0.5
# Безопасные поля падения: первые и последние 10% угла никого не убивают.
const DANGER_START := 0.1
const DANGER_END := 0.9

@onready var trunk_body: RigidBody3D = $TrunkBody
@onready var mesh: MeshInstance3D = $TrunkBody/MeshInstance3D
@onready var stump: StaticBody3D = $Stump
@onready var danger_zone: Area3D = $DangerZone


func _physics_process(_delta: float) -> void:
	if _state == State.FALLING:
		_process_fall(_delta)
	elif _state == State.DOWN:
		_damp_roll(_delta)


func chop(chopper_position: Vector3) -> void:
	if is_chopped:
		return

	_chop_count += 1

	var dir := chopper_position - global_position
	dir.y = 0.0
	if dir.length() > 0.01:
		last_chop_direction = dir.normalized()

	print("Удар %d/%d, сторона рубки: %s" % [_chop_count, chops_to_fell, last_chop_direction])

	if _chop_count >= chops_to_fell:
		_fell()


func _fell() -> void:
	is_chopped = true

	# Падаем в сторону, ПРОТИВОПОЛОЖНУЮ стороне рубки (от рубящего).
	_fall_direction = -last_chop_direction
	if _fall_direction.length() < 0.01:
		_fall_direction = Vector3.FORWARD
	_fall_direction = _fall_direction.normalized()
	print("Дерево подрублено, валится в сторону: %s" % _fall_direction)

	# Greybox-пометка состояния.
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.12, 0.08)
	mesh.material_override = mat

	# Ось поворота — горизонтальная, перпендикулярная направлению падения.
	_fall_axis = Vector3.UP.cross(_fall_direction).normalized()

	# Ствол становится ЖИВЫМ телом и сталкивается со всем твёрдым (пол, стоячие
	# стволы, лежащие брёвна, кубы). Свой пень исключаем — иначе кромка основания
	# при опрокидывании цеплялась бы за него.
	trunk_body.collision_layer = 1 | 4
	trunk_body.collision_mask = 1 | 4
	trunk_body.add_collision_exception_with(stump)
	# На время падения занижаем гашение, иначе демпфер съедает старт у вертикали.
	trunk_body.angular_damp = FALL_ANGULAR_DAMP
	# Ускоряем падение целиком (та же траектория, меньше времени).
	trunk_body.gravity_scale = fall_gravity_scale
	trunk_body.freeze = false

	# Толчок в сторону падения ПРЯМО С ВЕРТИКАЛИ (без мгновенного доворота — иначе
	# виден "скачок" на стартовый угол). Этой угловой скорости хватает перевалить
	# ствол через точку опрокидывания (для нашего цилиндра барьер ~0.12 рад/с),
	# дальше его свободно валит гравитация через кромку основания.
	trunk_body.angular_velocity = _fall_axis * initial_tip_speed

	_rest_timer = 0.0
	_state = State.FALLING

	chopped_through.emit(_fall_direction)


func _process_fall(delta: float) -> void:
	# Текущий наклон ствола от вертикали (его длинная ось — локальный Y).
	var up_axis := trunk_body.global_transform.basis.y
	var tilt := acos(clampf(up_axis.dot(Vector3.UP), -1.0, 1.0))

	# Дожим у вертикали: если ствол почти не наклонён и почти не крутится — он завис
	# в метастабильном равновесии ("танцует"). Толкаем его в сторону падения, пока он
	# не сорвётся. Нормальное падение этот режим не задевает (там есть вращение).
	if tilt < deg_to_rad(LAUNCH_STALL_ANGLE) \
			and trunk_body.angular_velocity.length() < LAUNCH_STALL_SPEED:
		trunk_body.apply_torque(_fall_axis * launch_assist_torque)

	# Держим падение В ОДНОЙ ПЛОСКОСТИ: оставляем только вращение вокруг оси падения,
	# гасим боковые составляющие. Круглый торец иначе "укатывается" вбок и даёт
	# неестественную закрутку всегда в одну сторону.
	trunk_body.angular_velocity = _fall_axis * trunk_body.angular_velocity.dot(_fall_axis)

	# Убивает только середина падения (10%..90% от горизонтали). Края безопасны.
	var progress := tilt / (PI * 0.5)
	if progress >= DANGER_START and progress <= DANGER_END:
		_check_kill()

	# Дошли почти до горизонтали — падение закончено.
	if tilt >= deg_to_rad(DETACH_ANGLE):
		_detach()
		return

	# Или ствол упёрся во что-то и завис (почти не вращается) — тоже отпускаем.
	if tilt > deg_to_rad(20.0) and trunk_body.angular_velocity.length() < 0.2:
		_rest_timer += delta
		if _rest_timer >= REST_DETACH_TIME:
			_detach()
	else:
		_rest_timer = 0.0


# Падение завершено. Бревно и так уже свободное тело — просто возвращаем сильное
# гашение и нормальные коллизии. Физика всё разрешила контактами сама, поэтому ни
# лучей, ни ручной укладки больше не нужно.
func _detach() -> void:
	_state = State.DOWN

	# Возвращаем нормальную гравитацию и включаем сильное гашение — лежачее бревно
	# спокойно оседает и не катается как шар, но всё ещё может скатиться под уклон.
	trunk_body.gravity_scale = 1.0
	trunk_body.angular_damp = down_angular_damp
	trunk_body.linear_damp = down_linear_damp

	# Теперь лежачее бревно упирается и в чужие пни (свой остаётся исключён).
	trunk_body.collision_mask = 1 | 4 | 16
	trunk_body.add_to_group("choppable_log")

	print("Ствол лёг. Дальше свободная физика (качение/штабель).")


# Гасим ТОЛЬКО качение вокруг длинной оси бревна (его локальный Y). Наклон-качели
# (вращение вокруг других осей) не трогаем — иначе игрок не сможет перевесить конец.
func _damp_roll(delta: float) -> void:
	var w := trunk_body.angular_velocity
	if w.length_squared() < 1e-6:
		return
	var axis := trunk_body.global_transform.basis.y.normalized()
	var roll := axis * w.dot(axis)
	trunk_body.angular_velocity = w - roll * clampf(roll_damp * delta, 0.0, 1.0)


# Смерть проверяем по РЕАЛЬНОМУ текущему положению ствола, а не по заранее
# просчитанной траектории: меряем расстояние от игрока до отрезка-оси бревна.
func _check_kill() -> void:
	# Концы ствола: его коллизия в локальных координатах тела тянется по Y от 0 до 9.
	var a := trunk_body.to_global(Vector3.ZERO)
	var b := trunk_body.to_global(Vector3(0.0, TRUNK_LENGTH, 0.0))
	for player in get_tree().get_nodes_in_group("player"):
		if not (player is Node3D):
			continue
		# Берём точку примерно в середине роста игрока, а не у ступней.
		var p: Vector3 = (player as Node3D).global_position + Vector3.UP * 0.9
		if _point_segment_distance(p, a, b) <= kill_radius:
			_kill_player()


func _point_segment_distance(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab := b - a
	var len_sq := ab.length_squared()
	if len_sq < 1e-6:
		return p.distance_to(a)
	var t := clampf((p - a).dot(ab) / len_sq, 0.0, 1.0)
	return p.distance_to(a + ab * t)


func _kill_player() -> void:
	if _player_killed:
		return
	_player_killed = true
	print("СМЕРТЬ: игрок под падающим деревом. Перезапуск сцены.")
	get_tree().reload_current_scene()
