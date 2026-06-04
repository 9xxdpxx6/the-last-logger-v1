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
## Максимальная глубина вдавливания зарубки (м) у добитой точки.
@export var notch_max_depth: float = 0.3
## Полудлина прорези ВДОЛЬ лезвия топора (м) — насколько широкий разруб делает кромка.
@export var notch_blade_reach: float = 0.22
## Полуширина прорези ПОПЕРЁК лезвия (м) — толщина зарубки.
@export var notch_thickness: float = 0.12

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
## Радиус (м) вокруг оси бревна, в котором игрок считается задавленным.
@export var kill_radius: float = 1.1
## Минимальная скорость бревна (м/с) в точке у игрока, при которой оно убивает.
@export var kill_speed: float = 2.5

@export_group("Форма слома")
## Макс. заострение торца «в кол» (м), когда рубили РАВНОМЕРНО ПО КРУГУ.
@export var break_cone_max: float = 0.18
## Макс. скос торца (м), когда рубили В ОДНУ СТОРОНУ.
@export var break_slant_max: float = 0.12
## Высота торчащих щепок на сломе (м).
@export var break_splinter: float = 0.14
## Сила «рваности» обода слома (м): дрожание радиуса/высоты на самом крайнем кольце.
## Тело ствола остаётся гладким — морщин по боковине нет.
@export var break_jagged: float = 0.04
## На какую глубину от торца (м) тянется формовка слома (конус/скос/щепки).
@export var break_span: float = 0.55

## Накопитель точек рубки (кластеры ударов) текущей стоячей части.
var _sites: ChopSites
## Генератор процедурного меша текущей стоячей части (ствол → пень → ниже).
var _trunk: ProceduralTrunk
## Горизонтальное направление от ствола к рубящему — "сторона рубки".
var last_chop_direction: Vector3 = Vector3.ZERO
## Дерево спилено под корень — больше не рубится (узел вот-вот удалится).
var _depleted: bool = false

# Плотность «древесины» подобрана так, что полный ствол ≈ исходной массе ~1800 кг.
const LOG_DENSITY := 850.0
# Ниже этой высоты пень спиливается «под корень» и исчезает (на этапе графики — щепками).
const MIN_STUMP_HEIGHT := 0.18
# Короче этой длины падающая часть не спавнится как физтело (балансировала бы/дрожала),
# а просто исчезает — позже разлетится щепками.
const MIN_FALL_PIECE := 0.6

# Сцена щепок — всплеск частиц в точке удара.
const CHIPS_SCENE := preload("res://scenes/chips.tscn")

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

	# Сразу подменяем меш на процедурный (пока без зарубок — выглядит так же).
	_rebuild_trunk()


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

	_spawn_chips(hit_point, chopper_position)
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
		print("Точка добита (%d ударов) — часть валится." % chops_to_fell)
		_fell(site.local_pos.y, _sites.ring_factor(site), _sites.mean_angle(site))
	else:
		print("Удар засчитан (сторона: %s)." % last_chop_direction)


# Всплеск щепок в точке удара. Летят наружу из ствола, в сторону рубящего.
func _spawn_chips(point: Vector3, chopper_position: Vector3) -> void:
	var chips := CHIPS_SCENE.instantiate()
	get_tree().current_scene.add_child(chips)
	chips.global_position = point
	var dir := chopper_position - point
	dir.y = 0.0
	if dir.length() > 0.01:
		# look_at направляет локальный -Z на цель; в chips.tscn частицы летят по -Z.
		chips.look_at(point + dir.normalized(), Vector3.UP)


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

	# 2) Падающая часть: достаточно длинная — свободное бревно; короткий обломок исчезает.
	if piece_len >= MIN_FALL_PIECE:
		_spawn_falling_log(global_position.y + cut_h, piece_len, r_cut, top_r, mat,
				ring_factor, chop_angle)

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


# Создаёт свободное падающее бревно (FallingLog) и запускает его падение. base_world_y —
# мировая высота НИЗА бревна (на уровне слома); слом (рваный торец) у его низа.
func _spawn_falling_log(base_world_y: float, length: float, bottom_r: float,
		top_r: float, mat: Material, ring_factor: float, chop_angle: float) -> void:
	var gen := ProceduralTrunk.new()
	gen.height = length
	gen.bottom_radius = bottom_r
	gen.top_radius = top_r
	gen.material = mat
	_shape_break(gen, false, ring_factor, chop_angle)
	# Свежий слом снизу должен темнеть (vertex color × albedo) — как у пня.
	var sm := mat as StandardMaterial3D
	if sm:
		sm.vertex_color_use_as_albedo = true

	var body := FallingLog.new()
	# Трение/упругость как у прежнего бревна — чтобы лежачее не скользило по полу.
	var pm := PhysicsMaterial.new()
	pm.friction = 1.0
	pm.rough = true
	pm.bounce = 0.15
	body.physics_material_override = pm

	var mi := MeshInstance3D.new()
	# Меш центрирован по Y → поднимаем на половину длины над origin тела (его низом).
	mi.mesh = gen.build([])
	mi.position.y = length * 0.5
	body.add_child(mi)

	var col := CollisionShape3D.new()
	var cs := CylinderShape3D.new()
	cs.height = length
	cs.radius = maxf(bottom_r, top_r)
	col.shape = cs
	col.position.y = length * 0.5
	body.add_child(col)

	get_tree().current_scene.add_child(body)

	# Масса по объёму (конус-цилиндр) — для будущей системы урона.
	var r_avg := (bottom_r + top_r) * 0.5
	var log_mass := LOG_DENSITY * PI * r_avg * r_avg * length

	# Прокидываем настройки падения из дерева — одно место правки на все падающие куски.
	body.initial_tip_speed = initial_tip_speed
	body.fall_gravity_scale = fall_gravity_scale
	body.launch_assist_torque = launch_assist_torque
	body.down_angular_damp = down_angular_damp
	body.down_linear_damp = down_linear_damp
	body.roll_damp = roll_damp
	body.kill_radius = kill_radius
	body.kill_speed = kill_speed

	# Лежачее бревно тоже рубится (зарубки) — отдаём ему генератор и параметры зарубок.
	body.setup_choppable(gen, mi, chops_to_fell, chop_merge_radius, notch_max_depth, CHIPS_SCENE)

	# Валим в сторону, ПРОТИВОПОЛОЖНУЮ стороне рубки (от рубящего).
	var fall_dir := -last_chop_direction
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
		body.global_position = Vector3(global_position.x, base_world_y + lift, global_position.z)
		var xf := body.global_transform
		xf.basis = Basis(tilt_axis, tilt) * xf.basis
		body.global_transform = xf
	else:
		body.global_position = Vector3(global_position.x, base_world_y, global_position.z)

	body.launch(fall_dir, length, log_mass)
	# Короткому даём ещё лёгкий толчок в сторону падения — чтобы точно сошёл с пня.
	if length < 2.0:
		body.linear_velocity = fall_dir * 1.0
