extends Node3D

## Стоячее дерево: его рубят, оно копит зарубки и при добитии ОДНОЙ точки ломается на
## этой высоте. Падающая часть улетает свободным бревном (FallingLog), а нижняя остаётся
## СТОЯЧИМ ПНЁМ — и это снова «то же самое дерево», только короче: его рубят тем же путём,
## снова ломают, снова отлетает бревно. Так пень и ствол — ОДНА реализация, без отдельной
## ветки кода под пень.
##
## trunk_body (RigidBody3D, заморожен) — всегда «текущая стоячая часть». _trunk — её
## генератор меша, _sites — накопитель ударов по ней. Меш центрирован по Y; origin тела
## стоит на земле, меш и коллизия подняты на половину текущей высоты.

## Срабатывает в момент, когда от дерева отламывается падающее бревно.
signal chopped_through(fall_direction: Vector3)

## Сколько ударов нужно, чтобы добить одну точку рубки (HP рубки в ударах).
@export var chops_to_fell: int = 5
## Радиус (м) слияния ударов в одну точку рубки — ВЫСОТНАЯ полоса вдоль оси: удары в её
## пределах копятся в один разруб независимо от стороны (рубка по кругу = один руб).
@export var chop_merge_radius: float = 0.2
## Максимальная глубина вдавливания зарубки (м) у добитой точки. Радиус ствола ~0.14–0.3 м,
## поэтому почти добитая зарубка прорезает его на бо́льшую часть толщины (#notch-V).
@export var notch_max_depth: float = 0.12
## Полудлина прорези ВДОЛЬ лезвия топора (м) — ширина горизонтального зареза клина.
@export var notch_blade_reach: float = 0.18
## Полуширина прорези ПОПЕРЁК лезвия (м) — вертикальный размах V-клина (вверх+вниз от ребра).
@export var notch_thickness: float = 0.13

@export_group("Падение бревна")
## Начальный толчок (рад/с), задающий сторону падения. Дальше валит гравитация.
@export var initial_tip_speed: float = 0.5
## Множитель гравитации НА ВРЕМЯ ПАДЕНИЯ — ускоряет падение целиком, не меняя траекторию.
@export var fall_gravity_scale: float = 1.3
## "Дожим" (Н·м) у самой вертикали: спасает от зависания, если стартовый толчок потерялся.
@export var launch_assist_torque: float = 20000.0
## Гашение вращения лежачего бревна — низкое, чтобы не мешать игроку перевешивать.
@export var down_angular_damp: float = 0.5
## Гашение линейного скольжения лежачего бревна.
@export var down_linear_damp: float = 0.5
## Скорость гашения КАЧЕНИЯ вокруг длинной оси бревна (1/с) — чтобы не катилось как шар.
@export var roll_damp: float = 6.0
## Радиус (м) вокруг оси бревна, в котором бревно может травмировать игрока.
@export var kill_radius: float = 1.1
## Минимальная скорость бревна (м/с) в точке у игрока, ниже которой урона нет вовсе.
@export var kill_speed: float = 2.5
## Множитель урона: HP = масса(кг) × скорость(м/с) × это. Тяжёлое+быстрое — насмерть,
## лёгкое или медленное — почти безвредно. Удобная ручка баланса смертоносности брёвен.
@export var damage_scale: float = 0.25
## Пауза (с) между ударами одного бревна по игроку — чтоб одно падение не списало HP
## за десяток кадров подряд, а нанесло один ощутимый удар.
@export var hit_cooldown: float = 0.6

@export_group("Форма слома")
## Макс. заострение торца «в кол» (м), когда рубили РАВНОМЕРНО ПО КРУГУ.
@export var break_cone_max: float = 0.09
## Макс. скос торца (м), когда рубили В ОДНУ СТОРОНУ.
@export var break_slant_max: float = 0.06
## Высота торчащих щепок на сломе (м).
@export var break_splinter: float = 0.08
## Сила «рваности» обода слома (м): дрожание радиуса/высоты на самом крайнем кольце.
## Тело ствола остаётся гладким — морщин по боковине нет.
@export var break_jagged: float = 0.025
## На какую глубину от торца (м) тянется формовка слома (конус/скос/щепки).
@export var break_span: float = 0.4

@export_group("Разнообразие леса")
## Случайно разбрасывать толщину/высоту/наклон при старте — каждое дерево чуть своё (#2).
@export var randomize_shape: bool = true
## Во сколько раз меняется ТОЛЩИНА ствола (мин..макс): <1 — тоньше, >1 — толще исходного.
@export var radius_scale_min: float = 0.7
@export var radius_scale_max: float = 1.7
## Во сколько раз меняется ВЫСОТА ствола (мин..макс).
@export var height_scale_min: float = 0.8
@export var height_scale_max: float = 1.25
## Доля деревьев (0..1), выросших «криво» — с наклоном ствола от вертикали.
@export var lean_chance: float = 0.25
## Диапазон наклона кривых деревьев (градусы) от вертикали, в случайную сторону.
@export var lean_min_deg: float = 10.0
@export var lean_max_deg: float = 30.0

## Накопитель точек рубки (кластеры ударов) текущей стоячей части.
var _sites: ChopSites
## Генератор процедурного меша текущей стоячей части (ствол → пень → ниже).
var _trunk: ProceduralTrunk
## Горизонтальное направление от ствола к рубящему — "сторона рубки".
var last_chop_direction: Vector3 = Vector3.ZERO
## Дерево спилено под корень — больше не рубится (узел вот-вот удалится).
var _depleted: bool = false
## Верхний торец ТЕКУЩЕЙ стоячей части — рваный слом, а не гладкая природная вершина.
## У целого дерева вершина гладкая (false); как только дерево сломали и остался пень, его
## новая верхушка — слом (true). Нужно, чтобы при ПОВТОРНОМ сломе пня у отлетающего бревна
## верхний торец остался рваным (раньше он всегда «сглаживался» — см. _spawn_falling_log).
var _top_is_break: bool = false

# Ниже этой высоты пень спиливается «под корень» и исчезает (на этапе графики — щепками).
const MIN_STUMP_HEIGHT := 0.18
# Короче этой длины падающая часть не спавнится как физтело (балансировала бы/дрожала),
# а просто исчезает — позже разлетится щепками.
const MIN_FALL_PIECE := 0.6

# Сцена щепок — всплеск частиц в точке удара.
const CHIPS_SCENE := preload("res://scenes/chips.tscn")
# Балансовые данные брёвен (плотность → вес → замедление переноски). Правится в .tres.
const LOG_ITEM := preload("res://resources/log_item.tres")

@onready var trunk_body: RigidBody3D = $TrunkBody
@onready var mesh: MeshInstance3D = $TrunkBody/MeshInstance3D
@onready var trunk_collision: CollisionShape3D = $TrunkBody/CollisionShape3D
@onready var stump: StaticBody3D = $Stump


func _ready() -> void:
	# Старый отдельный узел-пень больше не нужен: пнём становится сам trunk_body.
	if stump:
		stump.queue_free()

	# Накопитель кластеров ударов (позиции — в локале меша стоячей части).
	_sites = ChopSites.new(chop_merge_radius, chops_to_fell)

	# Берём размеры и материал из исходного CylinderMesh, заданного в редакторе, — дальше
	# меш строим сами в коде, чтобы вдавливать настоящие зарубки.
	_trunk = ProceduralTrunk.new()
	var cyl := mesh.mesh as CylinderMesh
	if cyl:
		_trunk.height = cyl.height
		_trunk.bottom_radius = cyl.bottom_radius
		_trunk.top_radius = cyl.top_radius
	_trunk.material = mesh.mesh.surface_get_material(0) if mesh.mesh.get_surface_count() > 0 else null
	_trunk.notch_long = notch_blade_reach
	_trunk.notch_thick = notch_thickness
	# Чтобы тёмная гашь зарубки (vertex color) была видна, материал должен умножать albedo.
	var sm := _trunk.material as StandardMaterial3D
	if sm:
		sm.vertex_color_use_as_albedo = true

	# Разброс толщины/высоты/наклона — ДО первой сборки меша, чтобы он сразу был нужного размера.
	if randomize_shape:
		_apply_random_shape()

	# Сразу подменяем меш на процедурный (пока без зарубок — выглядит так же).
	_rebuild_trunk()


# Делает каждое дерево чуть своим (#2): случайная толщина и высота ствола, у части — наклон.
func _apply_random_shape() -> void:
	var rs := randf_range(radius_scale_min, radius_scale_max)
	var hs := randf_range(height_scale_min, height_scale_max)
	_trunk.bottom_radius *= rs
	_trunk.top_radius *= rs
	_trunk.height *= hs
	# Меш строит _rebuild_trunk из _trunk.* — его трогать не нужно, но коллизию-цилиндр и высоты
	# узлов выставляем под новый размер. Форма коллизии в сцене — ОБЩИЙ ресурс на все деревья,
	# поэтому ДУБЛИРУЕМ её, иначе изменим радиус сразу у всех.
	var sh := trunk_collision.shape
	if sh is CylinderShape3D:
		var cs := (sh as CylinderShape3D).duplicate() as CylinderShape3D
		cs.radius = maxf(_trunk.bottom_radius, _trunk.top_radius)
		cs.height = _trunk.height
		trunk_collision.shape = cs
	mesh.position.y = _trunk.height * 0.5
	trunk_collision.position.y = _trunk.height * 0.5
	# Кривое дерево: с вероятностью lean_chance наклоняем ВЕСЬ узел вокруг основания на случайный
	# угол в случайную сторону. Поворот идёт через origin (он на земле), поэтому низ остаётся на
	# месте, а ствол кренится — «выросло криво».
	if randf() < lean_chance:
		var ang := deg_to_rad(randf_range(lean_min_deg, lean_max_deg))
		var dir := randf() * TAU
		rotate(Vector3(cos(dir), 0.0, sin(dir)), ang)


# Пересобирает меш текущей стоячей части под её точки рубки: каждая даёт вдавленную ямку
# глубиной по своему прогрессу (+ форма слома, если это уже пень). Зовём только на удар.
func _rebuild_trunk() -> void:
	var carves: Array = []
	for site in _sites.sites:
		carves.append({
			"pos": site.local_pos,
			"depth": _sites.depth_fraction(site) * notch_max_depth,
			"blade": site.blade,
		})
	mesh.mesh = _trunk.build(carves)


# Удар по стоячей части (стволу ИЛИ пню — путь один). Растим зарубку в точке попадания;
# при добитии ОДНОЙ точки ломаем на её высоте.
func chop(chopper_position: Vector3, hit_point: Vector3 = Vector3.INF,
		hit_normal: Vector3 = Vector3.UP, power: float = 1.0,
		edge_dir: Vector3 = Vector3.ZERO) -> void:
	if _depleted:
		return
	# Нужна точка попадания (куда класть зарубку).
	if not hit_point.is_finite():
		return

	_spawn_chips(hit_point, hit_normal)
	# Удар идёт в КОНКРЕТНУЮ точку рубки (позиция в локале меша). Зарубка растёт там,
	# повёрнутая по лезвию топора в момент удара (вдоль/поперёк/наискось ствола).
	var local_point := mesh.to_local(hit_point)
	var local_edge := mesh.global_transform.basis.inverse() * edge_dir
	var blade := ProceduralTrunk.surface_blade_dir(local_point, local_edge)
	var site := _sites.add_hit(local_point, power, blade)
	_rebuild_trunk()

	var dir := chopper_position - global_position
	dir.y = 0.0
	if dir.length() > 0.01:
		last_chop_direction = dir.normalized()

	# Ломается, только когда ОДНА точка добита — именно на её высоте. Форму слома задаёт,
	# как рубили: по кругу → кол, в одну сторону → скос.
	if _sites.is_felled(site):
		_fell(site.local_pos.y, _sites.ring_factor(site), _sites.mean_angle(site))


# Всплеск щепок в точке удара. Летят из зарубки ВБОК и вверх — от топора, а не в лицо (#2).
func _spawn_chips(point: Vector3, surface_normal: Vector3) -> void:
	var chips := CHIPS_SCENE.instantiate()
	get_tree().current_scene.add_child(chips)
	chips.global_position = point
	# look_at направляет локальный -Z на цель; в chips.tscn частицы летят по -Z. Направление —
	# общий со свободным бревном расчёт (вбок от нормали, случайная сторона/углы).
	chips.look_at(point + FallingLog.chip_spray_dir(surface_normal), Vector3.UP)
	# Залп — ТОЛЬКО после установки позиции/ориентации (см. chips.gd: иначе летят из 0,0,0).
	chips.burst()


# Ломаем текущую стоячую часть на высоте cut_local_y (локаль меша, centered). Верхняя
# часть улетает свободным бревном, нижняя остаётся СТОЯЧИМ ПНЁМ (тем же объектом).
# ring_factor — как рубили (0 в одну сторону → скос, 1 по кругу → кол),
# chop_angle — преобладающая сторона рубки (для направления скоса).
func _fell(cut_local_y: float, ring_factor: float = 0.0, chop_angle: float = 0.0) -> void:
	var total := _trunk.height
	# Высота слома над основанием (0..total).
	var cut_h := clampf(total * 0.5 + cut_local_y, 0.05, total - 0.05)
	var r_cut := lerpf(_trunk.bottom_radius, _trunk.top_radius, cut_h / total)
	var mat := _trunk.material
	var base_r := _trunk.bottom_radius
	var top_r := _trunk.top_radius
	var piece_len := total - cut_h
	var stump_too_low := cut_h < MIN_STUMP_HEIGHT
	# Верхний торец отлетающего бревна = верхний торец ТЕКУЩЕЙ стоячей части. Если рубим пень
	# (его верх уже слом) — бревно должно сохранить рваный верх. Берём флаг ДО того, как ниже
	# назначим новой стоячей части (укоротившемуся пню) свежий слом сверху.
	var piece_top_break := _top_is_break

	# 1) СНАЧАЛА разбираемся со стоячей частью (укорачиваем пень / убираем коллизию), чтобы
	#    у падающего бревна не было пересечения с коллизией стоячей части (иначе их
	#    «расталкивает», бревно дёргается и встаёт обратно вертикально).
	if stump_too_low:
		# Спилено под корень — пня не остаётся, весь объект уберём ниже.
		_depleted = true
		trunk_collision.disabled = true
		mesh.visible = false
	else:
		var gen := ProceduralTrunk.new()
		gen.height = cut_h
		gen.bottom_radius = base_r
		gen.top_radius = r_cut
		gen.material = mat
		_shape_break(gen, true, ring_factor, chop_angle)
		mesh.mesh = gen.build([])
		mesh.position.y = cut_h * 0.5
		var sh := CylinderShape3D.new()
		sh.height = cut_h
		sh.radius = maxf(base_r, r_cut)
		trunk_collision.shape = sh
		trunk_collision.position.y = cut_h * 0.5
		# Пень — это снова «стоячая часть»: тот же генератор, новый накопитель ударов.
		_trunk = gen
		_sites = ChopSites.new(chop_merge_radius, chops_to_fell)
		# Верх укоротившегося пня — теперь свежий слом: при следующем сломе бревно унаследует его.
		_top_is_break = true

	# 2) Падающая часть: достаточно длинная — свободное бревно; короткий обломок исчезает.
	if piece_len >= MIN_FALL_PIECE:
		_spawn_falling_log(cut_h, piece_len, r_cut, top_r, mat,
				ring_factor, chop_angle, piece_top_break)

	var fall_dir := -last_chop_direction
	if fall_dir.length() < 0.01:
		fall_dir = Vector3.FORWARD
	chopped_through.emit(fall_dir.normalized())

	if _depleted:
		# Пень ниже минимума — убираем всё дерево (падающее бревно уже отдельный объект).
		queue_free()


# Настраивает форму слома у генератора: рваный обод, скос/конус по тому, КАК рубили.
# top=true — слом сверху (пень), false — снизу (торец падающего бревна).
func _shape_break(gen: ProceduralTrunk, top: bool, ring_factor: float, chop_angle: float) -> void:
	if top:
		gen.jagged_top = true
	else:
		gen.jagged_bottom = true
	gen.jagged_seed = randf() * 100.0
	gen.rim_bias_angle = chop_angle
	# Рубили в одну сторону → скос; по кругу → заострение «в кол».
	gen.rim_bias = (1.0 - ring_factor) * break_slant_max
	gen.tip_cone = ring_factor * break_cone_max
	gen.splinter_height = break_splinter
	gen.jagged_amount = break_jagged
	gen.break_span = break_span
	gen.notch_long = notch_blade_reach
	gen.notch_thick = notch_thickness


# Собирает конфиг для фабрики бревна (FallingLog.spawn): материал, зарубки, форма слома,
# тюнинг падения, балансовый ресурс. Одно место — и для падающего, и для расколотых кусков.
func _log_cfg(mat: Material) -> Dictionary:
	return {
		"material": mat,
		"notch_long": notch_blade_reach,
		"notch_thick": notch_thickness,
		"notch_max_depth": notch_max_depth,
		"chops_needed": chops_to_fell,
		"merge_radius": chop_merge_radius,
		"chips_scene": CHIPS_SCENE,
		"log_item": LOG_ITEM,
		"break_cone_max": break_cone_max,
		"break_slant_max": break_slant_max,
		"break_splinter": break_splinter,
		"break_jagged": break_jagged,
		"break_span": break_span,
		"initial_tip_speed": initial_tip_speed,
		"fall_gravity_scale": fall_gravity_scale,
		"launch_assist_torque": launch_assist_torque,
		"down_angular_damp": down_angular_damp,
		"down_linear_damp": down_linear_damp,
		"roll_damp": roll_damp,
		"kill_radius": kill_radius,
		"kill_speed": kill_speed,
		"damage_scale": damage_scale,
		"hit_cooldown": hit_cooldown,
	}


# Создаёт свободное падающее бревно (FallingLog) и запускает его падение. cut_h — высота слома
# над основанием ВДОЛЬ ствола (локальный Y); слом (рваный торец) у низа бревна.
func _spawn_falling_log(cut_h: float, length: float, bottom_r: float,
		top_r: float, mat: Material, ring_factor: float, chop_angle: float,
		top_break: bool = false) -> void:
	var cfg := _log_cfg(mat)
	# Реальная мировая точка и ОРИЕНТАЦИЯ слома: у наклонного дерева ствол повёрнут, поэтому берём
	# их из самого узла. У прямого дерева basis = единичный, origin = (x, y+cut_h, z) — поведение
	# в точности прежнее.
	var basis := global_transform.basis.orthonormalized()
	var origin := to_global(Vector3(0.0, cut_h, 0.0))
	var xf := Transform3D(basis, origin)
	# Слом (рваный торец) — снизу падающего бревна. Верх рваный, если рубили пень (top_break).
	var body := FallingLog.spawn(get_tree().current_scene, cfg, xf, length,
			bottom_r, top_r, ring_factor, chop_angle, true, top_break)

	# Направление падения: у НАКЛОННОГО дерева — в сторону наклона (куда выросло криво), у прямого —
	# ПРОТИВОПОЛОЖНУЮ стороне рубки (от рубящего, как раньше).
	var lean := basis.y
	lean.y = 0.0
	var fall_dir: Vector3
	if lean.length() > 0.08:
		fall_dir = lean.normalized()
	else:
		fall_dir = -last_chop_direction
		if fall_dir.length() < 0.01:
			fall_dir = Vector3.FORWARD
		fall_dir = fall_dir.normalized()

	# Короткие куски стоят на торце в МЕТАСТАБИЛЬНОМ равновесии: чтобы повалиться, их центр
	# тяжести должен переехать кромку торца — а на пне они вместо этого «прилипают» и дрожат.
	# Поэтому короткий кусок сразу наклоняем ЗА точку опрокидывания и приподнимаем над пнём
	# (зазор), чтобы гравитация мгновенно его повалила — как ощущается первый сруб.
	if length < 2.0:
		var tilt := minf(atan2(2.0 * bottom_r, length) + deg_to_rad(10.0), deg_to_rad(45.0))
		var tilt_axis := Vector3.UP.cross(fall_dir).normalized()
		var lift := bottom_r * sin(tilt) + 0.05
		body.global_position = origin + Vector3.UP * lift
		var bxf := body.global_transform
		bxf.basis = Basis(tilt_axis, tilt) * bxf.basis
		body.global_transform = bxf

	body.launch(fall_dir, length, body.mass)
	# Короткому даём ещё лёгкий толчок в сторону падения — чтобы точно сошёл с пня.
	if length < 2.0:
		body.linear_velocity = fall_dir * 1.0
