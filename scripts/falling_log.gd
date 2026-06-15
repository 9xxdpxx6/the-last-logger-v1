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
var damage_scale: float = 0.15
var hit_cooldown: float = 0.6
# Скорость в расчёте урона обрезаем сверху — иначе разовый «выброс» скорости при
# раскладке/расталкивании кусков (penetration) даёт фиктивный мгновенный смертельный удар.
var max_damage_speed: float = 10.0
# После спавна/укладки/броска бревно НЕ наносит урон столько секунд: гасит мнимые удары
# от оседания (бревно дёрнулось на 1 кадр у самых ног — это не должно убивать).
var damage_arm_delay: float = 0.4
# Отступ (м) от КАЖДОГО торца, в пределах которого бревно НЕ наносит урон. Стоя вплотную к
# рубящемуся стволу, игрок касается края сруба (нижний торец) — этот край при падении задевает
# его и убивает. Урезаем «смертельный» отрезок с концов: торцы (включая срез) не бьют, а опасная
# СЕРЕДИНА/верх падающего бревна — бьют как раньше.
var hit_end_margin: float = 0.35
# Трение бревна НА ВРЕМЯ ВОЛОКА (обычное — 1.0). Меньше — легче тащить (лежащий конец
# скользит); слишком мало — бревно «катается» само. По end_drag вернётся к исходному.
var drag_friction: float = 0.3
# Максимальная скорость ПОДЪЁМА (м/с) схваченного торца при волоке. Низкая — торец встаёт к
# рукам плавно, без «прыжка наверх», когда из-под бревна убрали груз кучи.
var drag_max_rise: float = 1.2

enum State { FALLING, DOWN }
var _state: State = State.FALLING
var _active: bool = false
# Ось падения (горизонталь, перпендикулярна направлению) и само направление.
var _fall_axis: Vector3 = Vector3.ZERO
var _fall_direction: Vector3 = Vector3.ZERO
# Сколько ствол почти не вращается — признак, что он лёг/упёрся.
var _rest_timer: float = 0.0
# Отсчёт паузы между ударами по игроку (см. hit_cooldown).
var _dmg_cd: float = 0.0
# Отсчёт «взвода» урона после спавна/укладки (см. damage_arm_delay).
var _dmg_arm_timer: float = 0.0
# Бревно тащат волоком: игрок прикладывает к нему тянущую силу, физика остаётся живой.
var _dragging: bool = false
# Какой торец схвачен при волоке: 0 (низ) или _length (верх) в локале тела.
var _grab_end: float = 0.0
# Исходное трение бревна (физматериал): на время волока временно занижаем, чтобы
# лежащий конец скользил и бревно реально тащилось, а не «прилипало» к земле.
var _saved_friction: float = 1.0
# Длина бревна по локальному Y (0.._length) и масса — для смертельной зоны/урона.
var _length: float = 1.0
var _log_mass: float = 1.0
# Радиус бревна (полутолщина) — чтобы при волоке торец «лежал» на земле поверхностью, а не
# проваливался центром (см. _drag_ground_clamp).
var _radius: float = 0.15

# Лежачее бревно можно рубить (растить зарубки) — тем же генератором/накопителем, что и
# стоячий ствол. Добитая точка раскалывает бревно на две половины (см. _split).
var _gen: ProceduralTrunk
var _sites: ChopSites
var _mesh: MeshInstance3D
var _notch_max_depth: float = 0.3
# Зарубки, УНАСЛЕДОВАННЫЕ от исходного тела при сломе/расколе (#notch-keep): уже «замороженные»
# (своя глубина/угол), больше не растут и не валят — просто рисуются вместе со свежими. Пересчитаны
# в локаль ЭТОГО куска фабрикой spawn (через ProceduralTrunk.slice_carves).
var _inherited_carves: Array = []
var _chips_scene: PackedScene

# Балансовые данные бревна (плотность/вес/замедление) и полный конфиг для пересоздания
# кусков при расколе — чтобы половинки наследовали все настройки родителя.
var _log_item: LogItem
var _spawn_cfg: Dictionary = {}
# Какие торцы этого бревна — рваный СЛОМ (а не гладкий природный/распил). Нужно при расколе:
# у половинок исходные сломанные торцы должны ОСТАТЬСЯ рваными, а гладким стать только новый
# срез по центру (иначе старые зарубки «затираются» в гладь — см. _split).
var _break_bottom: bool = false
var _break_top: bool = false

# Бревно сдано в ПОЛЕННИЦУ (#woodpile): остаётся динамическим (укладывается/рассыпается физикой), но не
# подбирается/не рубится и повторно НЕ продаётся. _no_resell держит это навсегда (даже если раскатилось).
var _stockpiled: bool = false
var _no_resell: bool = false

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
# На сколько радиус коллизии бревна МЕНЬШЕ видимого меша (#log-gap). Компенсирует margin Jolt и
# то, что плоские грани низкополигонального цилиндра лежат внутри номинального радиуса — иначе
# бревно «висит» над землёй/соседним бревном на пару см. Поверхность меша слегка утапливается.
const COLLISION_SHRINK := 0.015
# На сколько метров ВЫШЕ прицельной поверхности спавним брошенное бревно (#woodpile-drop): падает и
# само укладывается физикой, не застревая в бортах загона/соседних брёвнах. Мало — не успевает обойти
# препятствие, много — роняем «с неба» и оно скачет.
const DROP_FALL_HEIGHT := 0.4


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

	# Слой 1|4: лежачее/падающее бревно — это и «обычное твёрдое» (1, видит игрок/рейкасты),
	# и «бревно» (4). Маска сканирует всё твёрдое: пол/кубы (1), стволы/брёвна (4), пни (16) —
	# бревно само со всем сталкивается и валится как надо.
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
	_dmg_arm_timer = damage_arm_delay
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


## Балансовые данные бревна (вес/замедление) и полный конфиг для пересоздания кусков при
## расколе. Зовётся фабрикой spawn() — после него бревно знает свой вес и умеет делиться.
func setup_item(item: LogItem, cfg: Dictionary, length: float,
		bottom_r: float, top_r: float) -> void:
	_log_item = item
	_spawn_cfg = cfg
	_length = length
	var r_avg := (bottom_r + top_r) * 0.5
	_radius = maxf(bottom_r, top_r)
	if item:
		_log_mass = item.mass_for(length, r_avg)
	else:
		_log_mass = 850.0 * PI * r_avg * r_avg * length
	mass = _log_mass


## ОТОБРАЖАЕМЫЙ вес бревна (кг) — для HUD и грузоподъёмности (нести/тащить/тачка). Это НЕ
## физическая масса (mass): реальное бревно слишком тяжёлое, чтобы его носил человек, поэтому
## игроку показываем «рабочий» вес в несколько раз меньше (см. LogItem.display_weight). Физику
## (удар/инерцию/толкание) считает настоящая mass — этот множитель её не трогает.
func get_weight() -> float:
	if _log_item:
		return _log_item.display_weight(_log_mass)
	return _log_mass * 0.2


## Длина бревна по локальной оси Y (м) — для укладки в кузов тачки.
func get_length() -> float:
	return _length


## Радиус (полутолщина, м) — для шага стопки брёвен в кузове.
func get_radius() -> float:
	return _radius


## Y геометрического ЦЕНТРА видимого меша в локале тела (м). У ровного бревна это length/2, но у
## СЛОМАННОГО торца меш выступает за номинал на ~tip_cone·1.3 (конус/щепки) — у короткого куска это
## заметная доля, и положенное «по length/2» бревно выглядело сдвинутым (#carry-center). Считаем центр
## по фактическим габаритам меша, чтобы на плече бревно лежало серединой.
func body_center_y() -> float:
	var over := (_gen.tip_cone * 1.3) if _gen != null else 0.0
	var over_b := over if _break_bottom else 0.0
	var over_t := over if _break_top else 0.0
	return _length * 0.5 + (over_t - over_b) * 0.5


# Удар по ЛЕЖАЧЕМУ бревну: растим зарубку в точке попадания (тот же путь, что у ствола).
# Добитая точка — место будущего РАСКОЛА на полено (пока только сообщение).
func chop(chopper_position: Vector3, hit_point: Vector3 = Vector3.INF,
		hit_normal: Vector3 = Vector3.UP, power: float = 1.0,
		edge_dir: Vector3 = Vector3.ZERO) -> void:
	if _gen == null or _sites == null or _mesh == null:
		return
	if not hit_point.is_finite():
		return
	_spawn_chips(hit_point, hit_normal)
	# Зарубку поворачиваем по лезвию топора в момент удара (вдоль/поперёк лежачего бревна).
	var local_point := _mesh.to_local(hit_point)
	var local_edge := _mesh.global_transform.basis.inverse() * edge_dir
	var blade := ProceduralTrunk.surface_blade_dir(local_point, local_edge)
	var site := _sites.add_hit(local_point, power, blade)
	_rebuild()
	# Рубка сама по себе толкает бревно (импульс топора) — это НЕ «удар бревна по игроку».
	# Взводим паузу урона, чтобы дрожь от рубки в упор не списывала HP стоящему рядом игроку.
	_dmg_arm_timer = damage_arm_delay
	if _sites.is_felled(site):
		_split(site)


func _rebuild() -> void:
	_mesh.mesh = _gen.build(_all_carves())


# Полный список зарубок этого куска: УНАСЛЕДОВАННЫЕ (замороженные, со слома/раскола) + СВЕЖИЕ
# (растущие точки рубки). Их рисует генератор; добитие считают только свежие (_sites).
func _all_carves() -> Array:
	var carves: Array = _inherited_carves.duplicate()
	for s in _sites.sites:
		carves.append({
			"pos": s.local_pos,
			"depth": _sites.depth_fraction(s) * _notch_max_depth,
			"blade": s.blade,
		})
	return carves


func _spawn_chips(point: Vector3, surface_normal: Vector3) -> void:
	if _chips_scene == null:
		return
	var chips := _chips_scene.instantiate()
	get_tree().current_scene.add_child(chips)
	chips.global_position = point
	chips.look_at(point + chip_spray_dir(surface_normal), Vector3.UP)
	# Залп — ТОЛЬКО после установки позиции/ориентации (см. chips.gd: иначе щепки летят из 0,0,0).
	chips.burst()


## Направление вылета щепок: НАРУЖУ из зарубки (по нормали поверхности), уведённое В СТОРОНУ и
## чуть ВВЕРХ — так щепки летят от топора вбок, а не в лицо игроку (#2). Сторона и углы случайны,
## поэтому каждый удар выглядит по-своему. Статик — тем же пользуется и стоячее дерево (tree.gd).
static func chip_spray_dir(surface_normal: Vector3) -> Vector3:
	var base := surface_normal
	base.y = 0.0
	if base.length() < 0.01:
		base = Vector3.FORWARD
	base = base.normalized()
	# Горизонтальная «вбок» ось (перпендикулярно нормали) — главное направление разлёта.
	var side := base.cross(Vector3.UP)
	if side.length() < 0.01:
		side = Vector3.RIGHT
	side = side.normalized()
	# В случайную сторону + немного вверх (от земли) + чуть наружу из зарубки. Доля наружу мала,
	# поэтому в лицо (вдоль нормали к игроку) щепки практически не идут.
	var dir := side * (1.0 if randf() < 0.5 else -1.0)
	dir += Vector3.UP * randf_range(0.3, 1.0)
	dir += base * randf_range(0.0, 0.5)
	return dir.normalized()


# Фабрика бревна: строит RigidBody с мешом/коллизией, формует слом на нужных торцах,
# вешает рубку и балансовые данные, ставит в мир по world_xf. НЕ запускает падение —
# вызывающий сам решает (launch() для падающего, place_resting() для лежащего куска).
# cfg — словарь параметров (см. tree._log_cfg): материал, зарубки, форма слома, тюнинг.
static func spawn(parent: Node, cfg: Dictionary, world_xf: Transform3D,
		length: float, bottom_r: float, top_r: float,
		ring_factor: float, chop_angle: float,
		break_bottom: bool, break_top: bool,
		inherited: Array = []) -> FallingLog:
	var gen := ProceduralTrunk.new()
	gen.height = length
	gen.bottom_radius = bottom_r
	gen.top_radius = top_r
	gen.material = cfg.get("material", null)
	gen.notch_long = cfg.get("notch_long", 0.22)
	gen.notch_thick = cfg.get("notch_thick", 0.12)
	if break_bottom or break_top:
		gen.jagged_bottom = break_bottom
		gen.jagged_top = break_top
		gen.jagged_seed = randf() * 100.0
		gen.rim_bias_angle = chop_angle
		gen.rim_bias = (1.0 - ring_factor) * cfg.get("break_slant_max", 0.12)
		gen.tip_cone = ring_factor * cfg.get("break_cone_max", 0.18)
		gen.splinter_height = cfg.get("break_splinter", 0.14)
		gen.jagged_amount = cfg.get("break_jagged", 0.04)
		gen.break_span = cfg.get("break_span", 0.55)
	var sm := gen.material as StandardMaterial3D
	if sm:
		sm.vertex_color_use_as_albedo = true

	var body := FallingLog.new()
	var pm := PhysicsMaterial.new()
	pm.friction = 1.0
	pm.rough = true
	pm.bounce = 0.15
	body.physics_material_override = pm

	var mi := MeshInstance3D.new()
	# Свежесозданный кусок уже несёт УНАСЛЕДОВАННЫЕ зарубки (со слома/раскола) — рисуем их сразу.
	mi.mesh = gen.build(inherited)
	mi.position.y = length * 0.5
	body.add_child(mi)

	var col := CollisionShape3D.new()
	var cs := CylinderShape3D.new()
	# Видимый меш в местах СЛОМА выступает за номинальный цилиндр: конус-вершина (tip_cone) и
	# щепки (splinter_height) торчат за торец, рваность (jagged_amount) — за радиус. Если коллизию
	# оставить ровно по номиналу, эти выступы протыкают тонкий борт тачки и видны «сквозь стенку»
	# (#2). Поэтому расширяем цилиндр коллизии до фактических габаритов меша: торец сломанного
	# конца отодвигается от стенки, и просвет пропадает.
	var over_b := (gen.tip_cone * 1.3 + gen.splinter_height * 0.5) if break_bottom else 0.0
	var over_t := (gen.tip_cone * 1.3 + gen.splinter_height * 0.5) if break_top else 0.0
	cs.height = length + over_b + over_t
	cs.radius = maxf(0.03, maxf(bottom_r, top_r) - COLLISION_SHRINK)
	col.shape = cs
	# Центр цилиндра смещаем, если торцы расширены несимметрично (рваный только один конец).
	col.position.y = length * 0.5 + (over_t - over_b) * 0.5
	body.add_child(col)

	# Следим за контактами: нужно, чтобы при подъёме/волоке бревна разбудить лежащие НА нём
	# куски (спящий RigidBody без толчка зависает в воздухе — см. _wake_resting_bodies).
	body.contact_monitor = true
	body.max_contacts_reported = 8

	parent.add_child(body)
	body.global_transform = world_xf
	# Запоминаем, какие торцы — рваный слом: при будущем расколе их нельзя «сгладить».
	body._break_bottom = break_bottom
	body._break_top = break_top
	# Унаследованные зарубки — чтобы при следующем расколе/рубке они остались на куске.
	body._inherited_carves = inherited

	# Тюнинг падения/лежания — из конфига (одно место правки на все куски).
	body.initial_tip_speed = cfg.get("initial_tip_speed", 0.5)
	body.fall_gravity_scale = cfg.get("fall_gravity_scale", 1.3)
	body.launch_assist_torque = cfg.get("launch_assist_torque", 20000.0)
	body.down_angular_damp = cfg.get("down_angular_damp", 0.5)
	body.down_linear_damp = cfg.get("down_linear_damp", 0.5)
	body.roll_damp = cfg.get("roll_damp", 6.0)
	body.kill_radius = cfg.get("kill_radius", 1.1)
	body.kill_speed = cfg.get("kill_speed", 2.5)
	body.damage_scale = cfg.get("damage_scale", 0.15)
	body.hit_cooldown = cfg.get("hit_cooldown", 0.6)
	body.max_damage_speed = cfg.get("max_damage_speed", 10.0)
	body.damage_arm_delay = cfg.get("damage_arm_delay", 0.4)

	body.setup_choppable(gen, mi, cfg.get("chops_needed", 5),
			cfg.get("merge_radius", 0.2), cfg.get("notch_max_depth", 0.3),
			cfg.get("chips_scene", null))
	body.setup_item(cfg.get("log_item", null), cfg, length, bottom_r, top_r)
	return body


# Раскол лежачего бревна по добитой точке на ДВА бревна (вдоль длины). Каждая половинка —
# новое лежачее бревно (тоже рубится и поднимается). Кусок короче min_length исчезает.
func _split(site) -> void:
	var total := _length
	# Высота реза вдоль тела (origin тела — у нижнего торца, ось длины — локальный Y).
	var cut_y := clampf(total * 0.5 + site.local_pos.y, 0.0, total)
	var br := _gen.bottom_radius
	var tr := _gen.top_radius
	var r_cut := lerpf(br, tr, cut_y / total)
	var ring := _sites.ring_factor(site)
	var ang := _sites.mean_angle(site)
	var min_len := _log_item.min_length if _log_item else 0.18

	# Совсем маленький обрубок делить уже бессмысленно (любой рез даст огрызки короче
	# min_len, размер почти не убывает) — рассыпаем его в щепки ЦЕЛИКОМ.
	if total < min_len * 2.0:
		queue_free()
		return

	var parent := get_parent()
	var xf := global_transform
	var axis_y := xf.basis.y.normalized()

	# Все текущие зарубки бревна (унаследованные + свежие) — разнесём по половинам, чтобы они
	# не «затёрлись в гладь» при расколе (#notch-keep). Зарубку у самого реза слом поглощает.
	var carves := _all_carves()

	# Нижняя половина: от торца тела до реза. Низ — ИСХОДНЫЙ торец (сохраняем его рваность,
	# если он был сломом), верх — СВЕЖИЙ рез по центру (всегда рваный).
	var len_a := cut_y
	if len_a >= min_len:
		var keep_a := ProceduralTrunk.slice_carves(carves, total, 0.0, cut_y, len_a)
		var pa := FallingLog.spawn(parent, _spawn_cfg, xf, len_a, br, r_cut,
				ring, ang, _break_bottom, true, keep_a)
		# Куски «оплаченного» (складского) бревна тоже непродаваемы — иначе из штабеля можно было бы
		# нарубить бесплатных денег (#woodpile). _stockpiled НЕ наследуем: кусок — свободное полено
		# (его можно возить тачкой без авто-сброса), просто продать его уже нельзя.
		pa._no_resell = _no_resell
		pa.place_resting()

	# Верхняя половина: от реза до верха. Origin сдвигаем на cut_y вдоль оси (+ зазор,
	# чтобы половинки не пересекались коллизией и не расталкивались). Низ — СВЕЖИЙ рез (рваный),
	# верх — ИСХОДНЫЙ торец (сохраняем его рваность).
	var len_b := total - cut_y
	if len_b >= min_len:
		var xf_b := xf
		xf_b.origin = xf * Vector3(0.0, cut_y, 0.0) + axis_y * 0.03
		var keep_b := ProceduralTrunk.slice_carves(carves, total, cut_y, total, len_b)
		var pb := FallingLog.spawn(parent, _spawn_cfg, xf_b, len_b, r_cut, tr,
				ring, ang, true, _break_top, keep_b)
		pb._no_resell = _no_resell
		pb.place_resting()

	queue_free()


# Ставит кусок СРАЗУ лежать (после раскола): без падения, но рубится и поднимается.
func place_resting() -> void:
	_state = State.DOWN
	collision_layer = 1 | 4
	collision_mask = 1 | 4 | 16
	continuous_cd = true
	freeze = false
	gravity_scale = 1.0
	angular_damp = down_angular_damp
	linear_damp = down_linear_damp
	add_to_group("choppable_log")
	add_to_group("pickup_log")
	_dmg_arm_timer = damage_arm_delay
	_active = true


# Физ-масса (кг) держимого бревна ДО телекинеза — чтобы вернуть её на отпускании.
var _pre_manip_mass: float = 1.0
# Бревно держат телекинезом: пока true — оно НЕ наносит урон игроку (он сам его держит/машет им, см.
# _apply_impact_damage). Иначе резкий мах держимым бревном «бил» бы игрока, который его и держит.
var _manipulated: bool = false

# Включаем режим ТЕЛЕКИНЕЗА (#manip): бревно остаётся свободным физтелом в мире (игрок тянет его
# силой в точке хвата — см. player.update_manipulation), но мы стабилизируем его и убираем коллизию с
# игроком, чтобы «висящее перед лицом» бревно не толкало капсулу. holder — игрок (для исключения пары).
# hold_mass — НИЗКАЯ физ-масса на время захвата: отклик пружины от массы не зависит (сила = ускорение ×
# масса), но ИМПУЛЬС (масса × скорость) падает в сотни раз → держимым бревном НЕЛЬЗЯ таранить тачку и
# тяжёлые брёвна (закрыли багоюз обхода грузоподъёмности). На отпускании массу возвращаем.
func begin_manipulate(holder: Node3D, angular_damp_hold: float, hold_mass: float) -> void:
	_active = true
	freeze = false
	sleeping = false
	can_sleep = false               # пока держим, не давать заснуть (иначе перестанет реагировать на силу)
	angular_damp = angular_damp_hold
	_pre_manip_mass = mass
	mass = hold_mass
	_manipulated = true
	add_collision_exception_with(holder)


# Отпускаем телекинез: возвращаем обычные массу/демпфирование/сон и коллизию с игроком.
func end_manipulate(holder: Node3D) -> void:
	can_sleep = true
	angular_damp = down_angular_damp
	mass = _pre_manip_mass
	_manipulated = false
	sleeping = false
	remove_collision_exception_with(holder)


# Берём бревно на плечо: вешаем на держатель (камеру), глушим физику и коллизию.
# hold_xf — поза относительно держателя (левое/правое плечо считает игрок по весу).
func pick_up(holder: Node3D, hold_xf: Transform3D) -> void:
	# Сначала будим всё, что лежит НА этом бревне: убираем опору — куски должны посыпаться,
	# а не висеть в воздухе спящими, пока их кто-нибудь не заденет.
	_wake_resting_bodies()
	_active = false
	freeze = true
	sleeping = true
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	# Несомое бревно ни с чем не сталкивается и больше не цель для рубки/подбора.
	collision_layer = 0
	collision_mask = 0
	remove_from_group("pickup_log")
	remove_from_group("choppable_log")
	remove_from_group("falling_log")
	get_parent().remove_child(self)
	holder.add_child(self)
	transform = hold_xf


# Кладём бревно обратно в мир (бросок перед игроком). new_parent — узел сцены,
# world_pos — куда положить нижний торец, forward — горизонтальное направление длины.
func drop(new_parent: Node, world_pos: Vector3, forward: Vector3) -> void:
	get_parent().remove_child(self)
	new_parent.add_child(self)
	var y := forward
	if y.length() < 0.01:
		y = Vector3.FORWARD
	y = y.normalized()
	var x := Vector3.UP.cross(y).normalized()
	var z := x.cross(y).normalized()
	# Спавним НЕ впритык к поверхности, а чуть ВЫШЕ (радиус + запас) — бревно ПАДАЕТ и САМО укладывается
	# физикой, обходя соседние стенки/брёвна (борта загона поленницы, соседние полешки). Жёсткая укладка
	# впритык не учитывала соседей: длинное бревно появлялось внутри борта, проникало сквозь него и
	# застревало. С падением солвер расталкивает его на место (или оно ложится поверх), без застреваний.
	var r := maxf(_gen.bottom_radius, _gen.top_radius) if _gen else 0.3
	global_transform = Transform3D(Basis(x, y, z), world_pos + Vector3.UP * (r + DROP_FALL_HEIGHT))
	freeze = false
	sleeping = false
	place_resting()


## Лежит ли бревно в штабеле поленницы (#woodpile). Тачке нужно, чтобы ОТПУСТИТЬ из приморозки груз,
## который заехал в зону сдачи и продался прямо из кузова (иначе тачка дёргала бы его обратно).
func is_stockpiled() -> bool:
	return _stockpiled


## Держат ли бревно телекинезом прямо сейчас. Тачке нужно, чтобы ИГНОРИРОВАТЬ толчки от такого бревна
## (иначе им можно катать тачку в обход механики «взять за ручки», #manip-exploit).
func is_manipulated() -> bool:
	return _manipulated


## Можно ли это бревно продать в зоне сдачи. Один раз продали (ушло в штабель) — больше нельзя,
## иначе осыпавшееся из поленницы бревно, закатившись обратно в зону, продалось бы повторно (#woodpile).
func can_be_sold() -> bool:
	return not _no_resell


## Помечаем бревно как СКЛАДСКОЕ — продано в поленницу (#woodpile). Остаётся ПОЛНОЦЕННЫМ бревном:
## его так же можно РУБИТЬ (расколется на куски) и ВЫТАСКИВАТЬ (подобрать/увезти) — поэтому держим в
## группах choppable/pickup, НЕ замораживаем и массу не трогаем (укладывается/рассыпается обычной
## физикой в загоне). Единственное ограничение — «уже оплачено»: повторно продать нельзя (_no_resell),
## и это свойство наследуют все куски при расколе, чтобы нельзя было нарубить из штабеля «бесплатных
## денег». Вес каждого куска считается как обычно (по размерам), экономику это не трогает.
func stockpile() -> void:
	_stockpiled = true
	_no_resell = true
	add_to_group("choppable_log")
	add_to_group("pickup_log")
	# Складское бревно — кандидат на «вывоз раз в N дней» (#collect): по группе зона despawn'ит штабель.
	add_to_group("stockpiled")


func _physics_process(delta: float) -> void:
	if not _active:
		return
	if _dmg_cd > 0.0:
		_dmg_cd -= delta
	if _dmg_arm_timer > 0.0:
		_dmg_arm_timer -= delta
	if _state == State.FALLING:
		_process_fall(delta)
		_apply_impact_damage()
	else:
		_damp_roll(delta)
		# Лежачее, но катящееся с горы бревно тоже опасно — проверяем по скорости.
		_apply_impact_damage()


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
	# Улёгшееся бревно можно поднять (E). Раскол на брёвна — рубкой (chop → _split).
	add_to_group("pickup_log")


# Гасим ТОЛЬКО качение вокруг длинной оси бревна (его локальный Y) — цилиндр-каток
# перестаёт укатываться как бильярд, но наклон-качели (другие оси) не трогаем.
func _damp_roll(delta: float) -> void:
	var w := angular_velocity
	if w.length_squared() < 1e-6:
		return
	var axis := global_transform.basis.y.normalized()
	var roll := axis * w.dot(axis)
	angular_velocity = w - roll * clampf(roll_damp * delta, 0.0, 1.0)


# Урон игроку = масса × скорость бревна В ТОЧКЕ у игрока × damage_scale. Большое+быстрое
# бьёт насмерть (>100 HP), лёгкое или медленное — почти безвредно. Ниже kill_speed урона
# нет вовсе. Между ударами одного бревна — пауза hit_cooldown, чтоб не списывало HP покадрово.
func _apply_impact_damage() -> void:
	# Бревно на волоке игрок держит сам — оно его не "бьёт"; пауза между ударами и «взвод»
	# после спавна/укладки тоже глушат урон (иначе оседание куска у ног = мнимая смерть).
	if _dragging or _manipulated or _dmg_cd > 0.0 or _dmg_arm_timer > 0.0:
		return
	# Концы бревна: коллизия в локале тела тянется по Y от 0 до _length. «Смертельный» отрезок
	# урезаем с обоих концов на hit_end_margin — торцы (в т.ч. край сруба у ног) не бьют.
	var margin := clampf(hit_end_margin, 0.0, _length * 0.45)
	var a := to_global(Vector3(0.0, margin, 0.0))
	var b := to_global(Vector3(0.0, _length - margin, 0.0))
	var com := to_global(Vector3(0.0, _length * 0.5, 0.0))
	for player in get_tree().get_nodes_in_group("player"):
		if not (player is Node3D):
			continue
		# Берём точку примерно в середине роста игрока, а не у ступней.
		var p: Vector3 = (player as Node3D).global_position + Vector3.UP * 0.9
		var closest := _closest_point_on_segment(p, a, b)
		var to_player := p - closest
		if to_player.length() > kill_radius:
			continue
		# Игрок СТОИТ НА бревне: ближайшая точка бревна заметно НИЖЕ игрока (вектор к игроку
		# смотрит вверх). Это опора, а не удар — бревно может оседать/наклоняться под ногой и
		# слегка дёргаться, но давить игрока сверху оно при этом не может. Бьют только удары
		# сбоку (вектор горизонтален) и сверху (вектор вниз) — их пропускаем дальше.
		if to_player.length() > 0.01 and to_player.normalized().y > 0.4:
			continue
		# Скорость бревна именно в ближайшей к игроку точке оси.
		var vel := linear_velocity + angular_velocity.cross(closest - com)
		# «Давящая» скорость: бревно давит ВНИЗ и ВБОК (гравитация работает вниз). Удар СНИЗУ
		# ВВЕРХ (бревно перевешивает и поднимает свободный конец в игрока) не крушит —
		# поэтому вертикальную составляющую ВВЕРХ обнуляем.
		var crush := vel
		if crush.y > 0.0:
			crush.y = 0.0
		# Урон только если давящее движение направлено К игроку, а не ОТ него (стоишь НА конце,
		# он проваливается вниз ОТ тебя → не бьёт; падает СВЕРХУ / катится В тебя → бьёт).
		if crush.dot(to_player) <= 0.0:
			continue
		var speed := crush.length()
		if speed < kill_speed:
			continue
		# Обрезаем сверху: разовые «выбросы» от расталкивания не должны мгновенно убивать.
		speed = minf(speed, max_damage_speed)
		# Урон считаем по ОТОБРАЖАЕМОМУ («рабочему») весу, а не по реальной массе: иначе утроение
		# плотности (для инерции/толкания) утроило бы и урон — лёгкое катящееся бревно убивало бы
		# мгновенно. Большое падающее бревно всё равно бьёт насмерть, мелкое — терпимо.
		var damage := get_weight() * speed * damage_scale
		if player.has_method("take_damage"):
			player.take_damage(damage)
			_dmg_cd = hit_cooldown


func _closest_point_on_segment(p: Vector3, a: Vector3, b: Vector3) -> Vector3:
	var ab := b - a
	var len_sq := ab.length_squared()
	if len_sq < 1e-6:
		return a
	var t := clampf((p - a).dot(ab) / len_sq, 0.0, 1.0)
	return a + ab * t


## Будит все динамические тела, КАСАЮЩИЕСЯ этого бревна (что лежит на нём сверху). Зовётся
## перед тем, как убрать опору (подъём/волок): спящий RigidBody игнорирует гравитацию и без
## толчка «зависает» в воздухе, когда из-под него забрали бревно. Разбуженные — падают.
func _wake_resting_bodies() -> void:
	for other in get_colliding_bodies():
		if other is RigidBody3D and not (other as RigidBody3D).freeze:
			(other as RigidBody3D).sleeping = false


## Лежит ли на этом бревне сверху другой (незамороженный) кусок? Частые лучи вверх вдоль всего
## бревна (каждые ~12 см), иначе тонкий верхний кусок проскочит между ними. Маска 4 — только брёвна;
## стоячий ствол (freeze) отсеиваем. Если да — бревно не «верхнее»: подобрать/тащить его нельзя.
func is_covered() -> bool:
	var space := get_world_3d().direct_space_state
	var reach := _radius * 2.0 + 0.2
	var n := maxi(4, int(_length / 0.12))
	for i in range(n + 1):
		var pt := to_global(Vector3(0.0, _length * float(i) / float(n), 0.0))
		var q := PhysicsRayQueryParameters3D.create(pt, pt + Vector3.UP * reach)
		q.exclude = [get_rid()]
		q.collision_mask = 4
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			continue
		var col = hit.get("collider")
		if col is RigidBody3D and (col as RigidBody3D).freeze:
			continue  # стоячий ствол рядом — это не «лежит сверху»
		return true
	return false


## Мировая точка схваченного при волоке торца (за неё игрок «держит» бревно).
func grab_point_world() -> Vector3:
	return to_global(Vector3(0.0, _grab_end, 0.0))


## Мировая точка ДАЛЬНЕГО (лежащего на земле) торца — противоположного схваченному.
func tail_point_world() -> Vector3:
	return to_global(Vector3(0.0, _length - _grab_end, 0.0))


## Начинает волок: запоминаем БЛИЖНИЙ к игроку торец. Слой 8 — маска игрока его не видит
## (бревно не толкает игрока), маска 1|4|16 — со всем твёрдым сталкивается.
func begin_drag(from_world: Vector3) -> void:
	var a := to_global(Vector3.ZERO)
	var b := to_global(Vector3(0.0, _length, 0.0))
	_grab_end = 0.0 if from_world.distance_to(a) <= from_world.distance_to(b) else _length
	_dragging = true
	_state = State.DOWN
	freeze = false
	sleeping = false
	gravity_scale = 1.0
	angular_damp = down_angular_damp
	linear_damp = down_linear_damp
	collision_layer = 8
	collision_mask = 1 | 4 | 16
	# Трение занижаем на время волока: лежащий конец должен скользить (по end_drag вернём).
	var pm := physics_material_override as PhysicsMaterial
	if pm != null:
		_saved_friction = pm.friction
		pm.friction = drag_friction
	remove_from_group("pickup_log")
	remove_from_group("choppable_log")
	_dmg_arm_timer = damage_arm_delay
	_active = true


## Тянущая «рука»: подтягиваем схваченный торец к target_world (точка у рук игрока). Поводок
## ограничивает длину рук, тяга идёт силой за ближний торец, tail_grip «якорит» дальний конец,
## чтобы бревно поворачивало по радиусу.
func drag_pull(target_world: Vector3, stiffness: float, damping: float,
		max_force: float, max_reach: float, tail_grip: float) -> void:
	if not _dragging:
		return
	sleeping = false
	var origin := to_global(Vector3.ZERO)
	var com := to_global(Vector3(0.0, _length * 0.5, 0.0))
	var grab := grab_point_world()
	var pivot := to_global(Vector3(0.0, _length - _grab_end, 0.0))

	# Тяга к точке у рук — только силой (телепорт таскал бы бревно сквозь препятствия мимо решателя).
	var v := linear_velocity + angular_velocity.cross(grab - com)
	var to_t := target_world - grab
	# СХВАЧЕННЫЙ ТОРЕЦ УПЁРСЯ по направлению тяги (#drag-stuck): луч от торца вдоль to_t во что-то
	# твёрдое (мир/бревно/пень; себя и игрока маска не видит) — НЕ тянем. Иначе рычаг (сила в 1/3 к
	# торцу) раскручивал дальний конец вокруг застрявшего ближнего и бревно «продавливалось» сквозь
	# препятствие на другую сторону (руки будто сквозные). Гасим скорость — бревно стоит. Освободить:
	# повернуться/отойти, тогда to_t сменит направление и проба очистится.
	if to_t.length() > 0.05:
		var space := get_world_3d().direct_space_state
		var q := PhysicsRayQueryParameters3D.create(grab, grab + to_t.normalized() * 0.3)
		q.exclude = [get_rid()]
		q.collision_mask = 1 | 4 | 16
		if not space.intersect_ray(q).is_empty():
			linear_velocity = linear_velocity.lerp(Vector3.ZERO, 0.5)
			angular_velocity = angular_velocity.lerp(Vector3.ZERO, 0.5)
			_drag_ground_clamp()
			return
	var force := (to_t * stiffness - v * damping) * mass
	if force.length() > max_force:
		force = force.normalized() * max_force
	# Силу прикладываем в точку 1/3 пути от центра масс к торцу, а не в сам торец: иначе рычаг
	# гонит дальний конец в землю (ускорение 2·F/m). Здесь дальний конец вниз не идёт, ближний — вверх.
	var apply_pt := com + (grab - com) / 3.0
	apply_force(force, apply_pt - origin)

	# Поводок: торец дальше длины рук — гасим скорость «наружу» (позицию не трогаем, коллизии целы).
	if to_t.length() > max_reach:
		var out_dir := -to_t.normalized()
		var v_out := linear_velocity.dot(out_dir)
		if v_out > 0.0:
			linear_velocity -= out_dir * v_out

	# Якорь дальнего торца: гасим только ПОПЕРЕЧНУЮ скорость лежащего конца (вдоль оси не трогаем,
	# иначе бревно нельзя утащить вдоль себя) — бревно поворачивает по радиусу вокруг него.
	var axis_h := global_transform.basis.y
	axis_h.y = 0.0
	var v_tail := linear_velocity + angular_velocity.cross(pivot - com)
	v_tail.y = 0.0
	if axis_h.length() > 0.01:
		axis_h = axis_h.normalized()
		v_tail -= axis_h * v_tail.dot(axis_h)
	if v_tail.length() > 0.001:
		var tail_force := -v_tail * tail_grip * mass
		var tail_max := max_force * 0.5
		if tail_force.length() > tail_max:
			tail_force = tail_force.normalized() * tail_max
		apply_force(tail_force, pivot - origin)

	# Лимиты скорости — бревно не должно «выстреливать» (выглядит как телепорт). Вверх режем жёстче.
	var max_lin := 2.0
	if linear_velocity.length() > max_lin:
		linear_velocity = linear_velocity.normalized() * max_lin
	if linear_velocity.y > drag_max_rise:
		linear_velocity.y = drag_max_rise
	var max_ang := 3.0
	if angular_velocity.length() > max_ang:
		angular_velocity = angular_velocity.normalized() * max_ang

	_drag_ground_clamp()


## Не даёт торцам свободного волочимого бревна провалиться под землю: луч вниз от каждого торца,
## если поверхность бревна (центр − радиус) ниже земли — выталкиваем вверх и гасим скорость вниз.
func _drag_ground_clamp() -> void:
	var space := get_world_3d().direct_space_state
	var com := to_global(Vector3(0.0, _length * 0.5, 0.0))
	var worst_lift := 0.0
	var pen_point := Vector3.ZERO
	for local_y in [0.0, _length]:
		var pt := to_global(Vector3(0.0, local_y, 0.0))
		var q := PhysicsRayQueryParameters3D.create(pt + Vector3.UP * 0.6, pt + Vector3.DOWN * 1.0)
		q.exclude = [get_rid()]
		q.collision_mask = 1 | 4 | 16
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			continue
		var ground_y := (hit["position"] as Vector3).y
		var lift := ground_y + _radius - pt.y
		if lift > worst_lift:
			worst_lift = lift
			pen_point = pt
	if worst_lift <= 0.0:
		return
	global_position.y += worst_lift
	var v_pt := linear_velocity + angular_velocity.cross(pen_point - com)
	if v_pt.y < 0.0:
		linear_velocity.y -= v_pt.y


## Завершает волок: бревно остаётся ТАМ ЖЕ, где было (без телепорта) и снова становится
## обычным лежачим телом — его можно подобрать/рубить.
func end_drag() -> void:
	_dragging = false
	sleeping = false
	# Возвращаем исходное трение, заниженное на время волока.
	var pm := physics_material_override as PhysicsMaterial
	if pm != null:
		pm.friction = _saved_friction
	place_resting()
