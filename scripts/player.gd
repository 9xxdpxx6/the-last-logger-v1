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
@export var axe_push_impulse: float = 150.0

var _jump_velocity: float = 0.0
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


func _ready() -> void:
	# Захватываем курсор при старте: мышь скрыта и привязана к окну.
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# v = sqrt(2*g*h): какая скорость вверх нужна, чтобы подняться на jump_height.
	var g: float = ProjectSettings.get_setting("physics/3d/default_gravity")
	_jump_velocity = sqrt(2.0 * g * jump_height)
	# Топор сообщает момент укуса лезвия — тогда и считаем попадание.
	axe.impact.connect(_on_axe_impact)


func _unhandled_input(event: InputEvent) -> void:
	# Обзор мышью работает только когда курсор захвачен.
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		# Поворот тела влево/вправо (по оси Y).
		rotate_y(-event.relative.x * mouse_sensitivity)
		# Наклон взгляда вверх/вниз копим отдельно — кик камеры наложим в _process.
		_look_pitch -= event.relative.y * mouse_sensitivity
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

	# Esc отпускает курсор, клик по окну — снова захватывает.
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed \
			and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	# Рубка: зажал ЛКМ — топор в замах (целимся); отпустил — удар под текущим углом.
	if event.is_action_pressed("chop") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
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
	if Input.is_action_pressed("run"):
		speed *= run_multiplier

	if on_floor:
		# На земле — мгновенная отзывчивость, прыжок.
		if direction:
			velocity.x = direction.x * speed
			velocity.z = direction.z * speed
		else:
			velocity.x = move_toward(velocity.x, 0.0, speed)
			velocity.z = move_toward(velocity.z, 0.0, speed)
		if Input.is_action_just_pressed("jump"):
			velocity.y = _jump_velocity
	else:
		# В воздухе — ограниченное руление: инерция сохраняется, но подправить можно.
		if direction:
			var accel := 16.0 * air_control * delta
			velocity.x = move_toward(velocity.x, direction.x * speed, accel)
			velocity.z = move_toward(velocity.z, direction.z * speed, accel)

	move_and_slide()
	_push_bodies()


# Кинематический игрок сам по себе не толкает RigidBody. Передаём ему ВЕС вниз.
# ВАЖНО: момент считаем САМИ относительно ЦЕНТРА МАСС (apply_central_force +
# apply_torque), а не через apply_force(force, pos) — у того точка отсчитывается от
# origin тела, а у бревна origin в торце (4.5 м от центра масс), и сила всегда
# уезжала к одному концу.
# Рычаг берём ТОЛЬКО вдоль длины бревна под ногой; боковую часть смещения (которая
# катит круглое бревно) выкидываем. Это эквивалентно честной силе в точку на осевой
# линии бревна: на качелях конец под игроком опускается, бревно целиком на полу не
# вращается (низ держит пол), а качения от игрока нет.
func _push_bodies() -> void:
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		# Нормаль вверх => мы поверх тела. Боковые/нижние касания игнорируем.
		if c.get_normal().y <= 0.5:
			continue
		var body := c.get_collider()
		if not (body is RigidBody3D) or body.freeze:
			continue
		var state := PhysicsServer3D.body_get_direct_state(body.get_rid())
		if not state:
			continue

		# Бревно, улёгшись, "засыпает" (sleep) и тогда ИГНОРИРУЕТ силы/моменты.
		# Будим его на каждом кадре давления — иначе наклон просто не применяется.
		(body as RigidBody3D).sleeping = false

		var force := Vector3.DOWN * push_force
		var offset := c.get_position() - state.center_of_mass

		# Оставляем в рычаге только горизонтальную часть ВДОЛЬ длины бревна.
		var log_axis := (body as RigidBody3D).global_transform.basis.y
		var log_h := Vector3(log_axis.x, 0.0, log_axis.z)
		var lever := Vector3.ZERO
		if log_h.length() > 0.01:
			log_h = log_h.normalized()
			var offset_h := Vector3(offset.x, 0.0, offset.z)
			lever = log_h * offset_h.dot(log_h)

		body.apply_central_force(force)
		body.apply_torque(lever.cross(force))
