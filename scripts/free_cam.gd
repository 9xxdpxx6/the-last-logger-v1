extends Camera3D

## Отладочная СВОБОДНАЯ КАМЕРА (#3). Включается клавишей ` (на русской раскладке Ё — клавиша под
## Escape) из player.gd: тот ставит сцену на ПАУЗУ (get_tree().paused = true) и создаёт эту камеру в
## позиции игровой. Здесь летаем WASD + Q/E (вниз/вверх) + мышь, Shift — быстрее. Камера НЕ физтело,
## поэтому свободно проходит сквозь препятствия. Повторное нажатие ` снимает паузу, возвращает игровую
## камеру и удаляет эту. process_mode = ALWAYS — чтобы жить и ловить ввод, пока дерево на паузе.

## Игровая камера, к которой вернёмся при выходе. Ставит player при создании (до добавления в дерево).
var restore_camera: Camera3D = null
## Скорость полёта (м/с) и ускоренная (зажат Shift/run).
@export var fly_speed: float = 6.0
@export var fly_fast: float = 18.0
## Чувствительность мыши (рад/пиксель).
@export var sensitivity: float = 0.0025

var _yaw: float = 0.0
var _pitch: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var e := global_transform.basis.get_euler()
	_yaw = e.y
	_pitch = e.x
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _input(event: InputEvent) -> void:
	# Повторное ` — выход из режима свободной камеры.
	if event is InputEventKey and (event as InputEventKey).physical_keycode == KEY_QUOTELEFT \
			and event.pressed and not (event as InputEventKey).echo:
		# ВАЖНО: помечаем ввод обработанным. _exit() снимает паузу (paused=false) — без этой пометки
		# то же нажатие ` долетит до player._unhandled_input и СРАЗУ снова включит фрикам, и выход
		# не сработает (камера вернётся, но режим не сменится) (#5).
		get_viewport().set_input_as_handled()
		_exit()
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var mm := event as InputEventMouseMotion
		_yaw -= mm.relative.x * sensitivity
		_pitch = clampf(_pitch - mm.relative.y * sensitivity, deg_to_rad(-89.0), deg_to_rad(89.0))


func _process(delta: float) -> void:
	global_transform.basis = Basis.from_euler(Vector3(_pitch, _yaw, 0.0))
	var dir := Vector3.ZERO
	var f := -global_transform.basis.z
	var r := global_transform.basis.x
	if Input.is_action_pressed("move_forward"):
		dir += f
	if Input.is_action_pressed("move_back"):
		dir -= f
	if Input.is_action_pressed("move_right"):
		dir += r
	if Input.is_action_pressed("move_left"):
		dir -= r
	# Вверх/вниз — E/Q (по физической позиции клавиш, как и WASD).
	if Input.is_physical_key_pressed(KEY_E):
		dir += Vector3.UP
	if Input.is_physical_key_pressed(KEY_Q):
		dir -= Vector3.UP
	var sp := fly_fast if Input.is_action_pressed("run") else fly_speed
	if dir.length() > 0.001:
		global_position += dir.normalized() * sp * delta


func _exit() -> void:
	get_tree().paused = false
	if restore_camera != null and is_instance_valid(restore_camera):
		restore_camera.make_current()
	queue_free()
