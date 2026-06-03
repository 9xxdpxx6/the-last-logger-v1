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

var _jump_velocity: float = 0.0

@onready var camera: Camera3D = $Camera3D
@onready var chop_ray: RayCast3D = $Camera3D/ChopRay


func _ready() -> void:
	# Захватываем курсор при старте: мышь скрыта и привязана к окну.
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# v = sqrt(2*g*h): какая скорость вверх нужна, чтобы подняться на jump_height.
	var g: float = ProjectSettings.get_setting("physics/3d/default_gravity")
	_jump_velocity = sqrt(2.0 * g * jump_height)


func _unhandled_input(event: InputEvent) -> void:
	# Обзор мышью работает только когда курсор захвачен.
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		# Поворот тела влево/вправо (по оси Y).
		rotate_y(-event.relative.x * mouse_sensitivity)
		# Наклон только камеры вверх/вниз (по оси X), с ограничением.
		camera.rotate_x(-event.relative.y * mouse_sensitivity)
		camera.rotation.x = clampf(
			camera.rotation.x,
			deg_to_rad(-max_look_angle),
			deg_to_rad(max_look_angle)
		)

	# Esc отпускает курсор, клик по окну — снова захватывает.
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed \
			and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	# Рубка: удар по стволу, на который смотрим (только при захваченном курсоре).
	if event.is_action_pressed("chop") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_try_chop()


func _try_chop() -> void:
	chop_ray.force_raycast_update()
	if not chop_ray.is_colliding():
		return
	var target := chop_ray.get_collider()
	if target == null:
		return
	# Луч попадает в дочерний TrunkBody, метод chop() — на родительском узле дерева.
	if target.has_method("chop"):
		target.chop(global_position)
	elif target.get_parent() and target.get_parent().has_method("chop"):
		target.get_parent().chop(global_position)


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
