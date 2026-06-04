extends RigidBody3D
class_name FallingLog

## Свободно падающее бревно — ЕДИНСТВЕННАЯ реализация падающего куска: и первый сруб
## ствола, и любой дорубленный остаток пня спавнят именно такой объект (раньше это были
## две разные ветки кода). Валится честной физикой через кромку слома, потом ложится;
## пока летит/катится быстро — давит игрока.
##
## Узлы (MeshInstance3D, CollisionShape3D) создаёт и наполняет тот, кто спавнит (tree.gd):
## меш центрирован по Y, origin тела стоит у НИЖНЕГО (сломанного) торца, коллизия тянется
## по локальному Y от 0 до _length. После настройки вызывается launch().

# Тюнинг падения — значения по умолчанию повторяют прежнее поведение ствола. tree.gd
# прокидывает сюда свои @export-настройки, чтобы всё крутилось из одного места.
var initial_tip_speed: float = 0.5
var fall_gravity_scale: float = 1.3
var launch_assist_torque: float = 20000.0
var down_angular_damp: float = 0.5
var down_linear_damp: float = 0.5
var roll_damp: float = 6.0
var kill_radius: float = 1.1
var kill_speed: float = 2.5

enum State { FALLING, DOWN }
var _state: State = State.FALLING
var _active: bool = false
# Ось падения (горизонталь, перпендикулярна направлению) и само направление.
var _fall_axis: Vector3 = Vector3.ZERO
var _fall_direction: Vector3 = Vector3.ZERO
# Сколько ствол почти не вращается — признак, что он лёг/упёрся.
var _rest_timer: float = 0.0
var _player_killed: bool = false
# Длина бревна по локальному Y (0.._length) и масса — для смертельной зоны/урона.
var _length: float = 1.0
var _log_mass: float = 1.0

# Лежачее бревно можно рубить (растить зарубки) — тем же генератором/накопителем, что и
# стоячий ствол. Раскол на поленья по добитой точке — пока TODO.
var _gen: ProceduralTrunk
var _sites: ChopSites
var _mesh: MeshInstance3D
var _notch_max_depth: float = 0.3
var _chips_scene: PackedScene

# Гашение вращения на ВРЕМЯ падения — низкое, чтобы гравитация свободно валила.
const FALL_ANGULAR_DAMP := 0.1
# Ниже этого наклона (рад) и при почти нулевом вращении считаем, что ствол "завис"
# у вертикали — включаем дожим.
const LAUNCH_STALL_ANGLE := 4.0
const LAUNCH_STALL_SPEED := 0.15
# Наклон (от вертикали), при котором падение считаем завершённым. Почти горизонталь.
const DETACH_ANGLE := 80.0
# Если ствол упёрся и завис под углом без вращения столько секунд — тоже считаем, что лёг.
const REST_DETACH_TIME := 0.5


## Запускает падение. fall_direction — горизонтальное направление падения; length и
## log_mass — длина и масса этого куска. Узлы уже добавлены, тело — уже в сцене.
func launch(fall_direction: Vector3, length: float, log_mass: float) -> void:
	_length = length
	_log_mass = log_mass
	mass = log_mass
	_fall_direction = fall_direction
	if _fall_direction.length() < 0.01:
		_fall_direction = Vector3.FORWARD
	_fall_direction = _fall_direction.normalized()
	# Ось поворота — горизонтальная, перпендикулярная направлению падения.
	_fall_axis = Vector3.UP.cross(_fall_direction).normalized()

	# Сталкивается со всем твёрдым (пол, стволы, лежащие брёвна, кубы) и с пнями (слой 16/4).
	collision_layer = 1 | 4
	collision_mask = 1 | 4 | 16
	continuous_cd = true
	freeze = false
	angular_damp = FALL_ANGULAR_DAMP
	gravity_scale = fall_gravity_scale
	# Малый толчок с вертикали задаёт сторону падения — дальше валит гравитация. Короткие
	# куски спавнер заранее наклоняет за точку опрокидывания (см. tree._spawn_falling_log),
	# поэтому здесь для всех одинаково.
	angular_velocity = _fall_axis * initial_tip_speed
	add_to_group("falling_log")
	_active = true


## Включает рубку этого бревна: gen — его генератор меша (со сломом), mesh_node — узел
## меша, остальное — параметры зарубок (как у стоячего ствола в tree.gd).
func setup_choppable(gen: ProceduralTrunk, mesh_node: MeshInstance3D, chops_needed: int,
		merge_radius: float, notch_depth: float, chips_scene: PackedScene) -> void:
	_gen = gen
	_mesh = mesh_node
	_sites = ChopSites.new(merge_radius, chops_needed)
	_notch_max_depth = notch_depth
	_chips_scene = chips_scene


# Удар по ЛЕЖАЧЕМУ бревну: растим зарубку в точке попадания (тот же путь, что у ствола).
# Добитая точка — место будущего РАСКОЛА на полено (пока только сообщение).
func chop(chopper_position: Vector3, hit_point: Vector3 = Vector3.INF,
		hit_normal: Vector3 = Vector3.UP, power: float = 1.0,
		edge_dir: Vector3 = Vector3.ZERO) -> void:
	if _gen == null or _sites == null or _mesh == null:
		return
	if not hit_point.is_finite():
		return
	_spawn_chips(hit_point, chopper_position)
	# Зарубку поворачиваем по лезвию топора в момент удара (вдоль/поперёк лежачего бревна).
	var local_point := _mesh.to_local(hit_point)
	var local_edge := _mesh.global_transform.basis.inverse() * edge_dir
	var blade := ProceduralTrunk.surface_blade_dir(local_point, local_edge)
	var site := _sites.add_hit(local_point, power, blade)
	_rebuild()
	if _sites.is_felled(site):
		print("Точка на лежачем бревне добита — тут раскол на полено (TODO).")


func _rebuild() -> void:
	var carves: Array = []
	for s in _sites.sites:
		carves.append({
			"pos": s.local_pos,
			"depth": _sites.depth_fraction(s) * _notch_max_depth,
			"blade": s.blade,
		})
	_mesh.mesh = _gen.build(carves)


func _spawn_chips(point: Vector3, chopper_position: Vector3) -> void:
	if _chips_scene == null:
		return
	var chips := _chips_scene.instantiate()
	get_tree().current_scene.add_child(chips)
	chips.global_position = point
	var dir := chopper_position - point
	dir.y = 0.0
	if dir.length() > 0.01:
		chips.look_at(point + dir.normalized(), Vector3.UP)


func _physics_process(delta: float) -> void:
	if not _active:
		return
	if _state == State.FALLING:
		_process_fall(delta)
		_check_kill()
	else:
		_damp_roll(delta)
		# Лежачее, но катящееся с горы бревно тоже опасно — проверяем по скорости.
		_check_kill()


func _process_fall(delta: float) -> void:
	# Текущий наклон бревна от вертикали (его длинная ось — локальный Y).
	var up_axis := global_transform.basis.y
	var tilt := acos(clampf(up_axis.dot(Vector3.UP), -1.0, 1.0))

	# Дожим у вертикали: завис в метастабильном равновесии — толкаем в сторону падения.
	if tilt < deg_to_rad(LAUNCH_STALL_ANGLE) \
			and angular_velocity.length() < LAUNCH_STALL_SPEED:
		apply_torque(_fall_axis * launch_assist_torque)

	# Держим падение В ОДНОЙ ПЛОСКОСТИ: оставляем только вращение вокруг оси падения.
	angular_velocity = _fall_axis * angular_velocity.dot(_fall_axis)

	# Дошли почти до горизонтали — падение закончено.
	if tilt >= deg_to_rad(DETACH_ANGLE):
		_detach()
		return

	# Или бревно упёрлось во что-то и зависло (почти не вращается) — тоже отпускаем.
	if tilt > deg_to_rad(20.0) and angular_velocity.length() < 0.2:
		_rest_timer += delta
		if _rest_timer >= REST_DETACH_TIME:
			_detach()
	else:
		_rest_timer = 0.0


# Падение завершено: возвращаем нормальную гравитацию и сильное гашение — бревно
# спокойно оседает, но всё ещё может скатиться под уклон.
func _detach() -> void:
	_state = State.DOWN
	gravity_scale = 1.0
	angular_damp = down_angular_damp
	linear_damp = down_linear_damp
	add_to_group("choppable_log")


# Гасим ТОЛЬКО качение вокруг длинной оси бревна (его локальный Y) — цилиндр-каток
# перестаёт укатываться как бильярд, но наклон-качели (другие оси) не трогаем.
func _damp_roll(delta: float) -> void:
	var w := angular_velocity
	if w.length_squared() < 1e-6:
		return
	var axis := global_transform.basis.y.normalized()
	var roll := axis * w.dot(axis)
	angular_velocity = w - roll * clampf(roll_damp * delta, 0.0, 1.0)


# Смерть = игрок близко к оси бревна И бревно В ЭТОЙ ТОЧКЕ движется быстро.
func _check_kill() -> void:
	# Концы бревна: коллизия в локале тела тянется по Y от 0 до _length.
	var a := to_global(Vector3.ZERO)
	var b := to_global(Vector3(0.0, _length, 0.0))
	var com := to_global(Vector3(0.0, _length * 0.5, 0.0))
	for player in get_tree().get_nodes_in_group("player"):
		if not (player is Node3D):
			continue
		# Берём точку примерно в середине роста игрока, а не у ступней.
		var p: Vector3 = (player as Node3D).global_position + Vector3.UP * 0.9
		var closest := _closest_point_on_segment(p, a, b)
		if p.distance_to(closest) > kill_radius:
			continue
		# Скорость бревна именно в ближайшей к игроку точке оси.
		var vel := linear_velocity + angular_velocity.cross(closest - com)
		if vel.length() >= kill_speed:
			# Будущий урон ∝ кинетике удара (масса × скорость в точке). Пока заглушка.
			var impact_force := _log_mass * vel.length()
			_kill_player(impact_force)


func _closest_point_on_segment(p: Vector3, a: Vector3, b: Vector3) -> Vector3:
	var ab := b - a
	var len_sq := ab.length_squared()
	if len_sq < 1e-6:
		return a
	var t := clampf((p - a).dot(ab) / len_sq, 0.0, 1.0)
	return a + ab * t


# impact_force — заглушка под будущую систему урона (масса × скорость). Сейчас любой
# удар бревна = мгновенная смерть; позже здесь будет вычет HP.
func _kill_player(impact_force: float = 0.0) -> void:
	if _player_killed:
		return
	_player_killed = true
	print("СМЕРТЬ: игрок под бревном (масса %.0f кг, сила удара %.0f — TODO урон по HP). Перезапуск." \
		% [_log_mass, impact_force])
	get_tree().reload_current_scene()
