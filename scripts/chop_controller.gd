extends Node

# Рубка топором: заряд по удержанию ЛКМ, прицел мышью/A-D, попадание по сигналу топора, отдача
# камеры. Раньше жила в player.gd (_compute_chop_power/_on_axe_impact/_apply_kick + обработка ввода
# «chop»); вынесена в узел-компонент, чтобы Player остался «диспетчером». Физику движения игрока не
# трогает — только бьёт лучом, толкает свободные физтела и просит игрока качнуть камеру (add_camera_kick).
#
# Тунинг рубки/отдачи теперь живёт на ЭТОМ узле (а не на Player) — крути в Инспекторе узла ChopController.

@export_group("Рубка")
## ЗАРЯД УДАРА (#4): чем дольше зажата ЛКМ (замах), тем сильнее удар — от 100% до chop_power_max.
## chop_charge_time — за сколько секунд удержания заряд доходит до максимума.
@export var chop_charge_time: float = 0.7
## Потолок силы удара от заряда (1.5 = +50% к базовой при полном замахе).
@export var chop_power_max: float = 1.5
## Множитель силы при БОКОВОМ ударе (A/D): косой руб слабее прямого. Масштабируется по |aim.x|.
@export var chop_side_power_mult: float = 0.9
## Множитель силы ПРЕРЫВАЮЩЕГО удара (#4): начали новый замах, пока прошлый ещё доигрывал (~90-95%)
## — спешка, удар слабее (0.87 ≈ 87% силы).
@export var chop_interrupt_power_mult: float = 0.87
## Сила удара топором, когда бревно лежит на ЛЕВОМ плече (топор в правой руке) — рубим слабее,
## рука занята. 1 — без штрафа, 0.5 — вдвое слабее.
@export var carry_chop_power_mult: float = 0.5
## Импульс (Н·с), которым лезвие толкает свободные физтела при попадании. Скорость от него =
## импульс / масса: лёгкие поленья сдвигаются заметно, тяжёлые брёвна — еле-еле.
@export var axe_push_impulse: float = 112.0
## Чувствительность «протяжки» топора мышью: сколько прицела даёт пиксель движения мыши, пока
## зажата ЛКМ. Двигаешь мышь поперёк дерева — топор бьёт в ту сторону.
@export var drag_sensitivity: float = 0.012
## Затухание накопленной протяжки (1/с): прицел от мыши плавно сбрасывается к нулю, так удар идёт
## по СВЕЖЕМУ движению руки, а не по всей истории.
@export var drag_decay: float = 5.0

@export_group("Отдача камеры")
## Отдача камеры вверх при попадании топором (градусы) — «весомость» удара.
@export var kick_pitch_deg: float = 1.2
## Случайный крен камеры при попадании (градусы, в обе стороны).
@export var kick_roll_deg: float = 0.5
## Случайный рывок камеры вбок при попадании (градусы) — разнообразит отдачу.
@export var kick_yaw_deg: float = 0.8

# Игрок-родитель и его дочерние узлы, нужные рубке (камера/луч/топор — под Camera3D).
@onready var _player: Player = get_parent() as Player
@onready var _camera: Camera3D = _player.get_node("Camera3D")
@onready var _chop_ray: ShapeCast3D = _player.get_node("Camera3D/ChopRay")
@onready var _axe: Node3D = _player.get_node("Camera3D/Axe")

## ЛКМ зажата — топор в замахе, целимся. Удар будет на отпускании.
var _charging: bool = false
## Момент начала замаха (сек) — по нему считаем длительность удержания → силу удара (#4).
var _charge_start_s: float = 0.0
## Текущий замах начат ПОВЕРХ недоигравшего удара (прерывающий, спешка) → удар слабее (#4).
var _chop_charging_interrupted: bool = false
## Множитель силы текущего удара (заряд × бок × прерывание). Применяется в _on_axe_impact (#4).
var _chop_power_mult: float = 1.0
## Недавнее движение мыши (x: лево/право, y: низ/верх) — задаёт угол/плоскость удара на отпускании.
## Копится во время замаха, плавно затухает → важно движение У САМОГО отпускания.
var _aim_drag: Vector2 = Vector2.ZERO
## Прицел последнего замаха (x: лево/право, y: верх/низ) — для варьирования кика.
var _last_aim: Vector2 = Vector2.ZERO


func _ready() -> void:
	# Топор сообщает момент укуса лезвия — тогда и считаем попадание.
	_axe.impact.connect(_on_axe_impact)


func _process(delta: float) -> void:
	# Прицел затухает, пока целимся — важно движение мыши У САМОГО отпускания.
	if _charging:
		_aim_drag = _aim_drag.lerp(Vector2.ZERO, clampf(drag_decay * delta, 0.0, 1.0))


func _unhandled_input(event: InputEvent) -> void:
	# Во время замаха движение мыши копим как угол будущего удара: камера крутится (её ведёт Player),
	# А топор «прицеливается». Право/вверх мыши = право/вверх удара.
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and _charging:
		_aim_drag.x += event.relative.x * drag_sensitivity
		_aim_drag.y += -event.relative.y * drag_sensitivity

	# Рубка: зажал ЛКМ — топор в замах (целимся); отпустил — удар под текущим углом.
	# Можно ли рубить (топор в руке, не на волоке/тачке) — решает сам Player через can_chop().
	if event.is_action_pressed("chop") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED \
			and _player.can_chop():
		# Прерывающий удар (#4): начали замах, пока прошлый ещё доигрывал. begin_windup вернёт false,
		# если удар ещё рано прерывать — тогда клик игнорируем (топор доигрывает удар, без дёрганья #2).
		var was_busy: bool = _axe.is_busy()
		# Сторону взвода берём из текущего A/D (#2): если зажат A/D — топор сразу заносится для
		# горизонтального маха в нужную сторону, а не дёргается на месте при отпускании.
		var move0 := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		if _axe.begin_windup(Vector2(move0.x, -move0.y)):
			_charging = true
			_chop_charging_interrupted = was_busy
			_charge_start_s = Time.get_ticks_msec() / 1000.0
			_aim_drag = Vector2.ZERO
	elif event.is_action_released("chop") and _charging:
		var move := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		var aim := Vector2(move.x, -move.y) + _aim_drag
		aim.x = clampf(aim.x, -1.0, 1.0)
		aim.y = clampf(aim.y, -1.0, 1.0)
		_last_aim = aim
		_charging = false
		_chop_power_mult = _compute_chop_power(aim)
		_axe.release_strike(aim)


# Сила удара (#4) на отпускании ЛКМ: заряд от длительности замаха (100%→chop_power_max),
# штраф за боковой удар A/D (масштаб по |aim.x|) и за прерывающий удар (новый замах поверх
# недоигравшего). Итог ограничиваем потолком chop_power_max.
func _compute_chop_power(aim: Vector2) -> float:
	var hold := Time.get_ticks_msec() / 1000.0 - _charge_start_s
	var charge := lerpf(1.0, chop_power_max, clampf(hold / chop_charge_time, 0.0, 1.0))
	var side := lerpf(1.0, chop_side_power_mult, clampf(absf(aim.x), 0.0, 1.0))
	var interrupt := chop_interrupt_power_mult if _chop_charging_interrupted else 1.0
	return clampf(charge * side * interrupt, 0.0, chop_power_max)


# Вызывается топором в момент удара лезвия. Тут решаем, попали ли по стволу.
# ShapeCast — «толстый луч» (сфера r=0.15): прицел прощающий, у лезвия есть толщина.
func _on_axe_impact() -> void:
	_chop_ray.force_shapecast_update()
	if not _chop_ray.is_colliding():
		return
	# Что-то задели лезвием — даём варьирующуюся отдачу камере.
	_apply_kick()

	# Индекс 0 — ближайшее попадание (результаты идут от близких к дальним).
	var target := _chop_ray.get_collider(0)
	if target == null:
		return
	var point := _chop_ray.get_collision_point(0)
	var normal := _chop_ray.get_collision_normal(0)

	var forward := -_camera.global_transform.basis.z

	# Точку зарубки уточняем ТОНКИМ лучом ровно через центр экрана (прицел). «Толстый»
	# ShapeCast (сфера r=0.15) прощает прицеливание, но его точка контакта лежит на сфере и
	# при взгляде сверху вниз проецируется ЧУТЬ ВЫШЕ перекрестия. Тонкий луч из камеры вперёд
	# попадает ровно в прицел; если он задел то же тело — берём его точку, иначе остаёмся на
	# прощающей точке ShapeCast (тонкий луч мог промахнуться мимо тонкого ствола с краю).
	var cam_o := _camera.global_position
	var space := _camera.get_world_3d().direct_space_state
	var rq := PhysicsRayQueryParameters3D.create(cam_o, cam_o + forward * 3.0, _chop_ray.collision_mask)
	rq.exclude = [_player.get_rid()]
	var hit := space.intersect_ray(rq)
	if not hit.is_empty() and hit.get("collider") == target:
		point = hit["position"]
		normal = hit["normal"]

	# Сила удара = насколько он ПЕРПЕНДИКУЛЯРЕН стволу. В лоб (взгляд против нормали) —
	# полный урон/глубокая зарубка; вскользь — слабо. perp: 0 (касательно)..1 (в лоб).
	var perp := clampf(forward.dot(-normal), 0.0, 1.0)
	var power := lerpf(0.35, 1.3, perp)
	# Сила замаха (#4): дольше держал ЛКМ → сильнее (до chop_power_max); боковой удар A/D и
	# прерывающий удар — слабее. Множитель посчитан на отпускании в _compute_chop_power.
	power *= _chop_power_mult
	# Несём бревно на левом плече (топор в правой руке) — бьём слабее, рука занята.
	if _player.carried_log() != null:
		power *= carry_chop_power_mult

	# Плоскость лезвия в момент удара — ось X топора (вдоль режущей кромки). По ней
	# ориентируем зарубку (диагональный руб даёт диагональную зарубку).
	var edge := _axe.global_transform.basis.x

	# Толкаем свободные физтела лезвием: лёгкие поленья сдвигаются заметно, тяжёлые брёвна
	# почти нет (скорость = импульс/масса). Замороженные (стволы/пни) пропускаем — их не
	# сдвинуть, только рубить. Импульс — в точку удара, поэтому полено ещё и подкручивается.
	if target is RigidBody3D and not (target as RigidBody3D).freeze:
		var rb := target as RigidBody3D
		# Будим тело перед толчком: лежащее бревно (на земле ИЛИ в кузове тачки) спит и без
		# пробуждения игнорирует импульс — по бревну в тачке «не было толчка» (#3).
		rb.sleeping = false
		rb.apply_impulse(forward * axe_push_impulse * power, point - rb.global_position)

	# Луч попадает в дочерний TrunkBody, метод chop() — на родительском узле дерева.
	var origin := _player.global_position
	if target.has_method("chop"):
		target.chop(origin, point, normal, power, edge)
	elif target.get_parent() and target.get_parent().has_method("chop"):
		target.get_parent().chop(origin, point, normal, power, edge)


# Отдача камеры от удара: тангаж в основном вверх, но с разбросом; крен/рыскание случайны и слегка
# зависят от стороны замаха — так каждый удар ощущается иначе. Само смещение копит и гасит камеру
# Player (add_camera_kick → его _kick), здесь только считаем импульс этого удара.
func _apply_kick() -> void:
	var pitch := deg_to_rad(kick_pitch_deg) * randf_range(0.5, 1.3)
	var roll := deg_to_rad(kick_roll_deg) * randf_range(0.4, 1.0) * (1.0 if randf() < 0.5 else -1.0)
	roll -= deg_to_rad(kick_roll_deg) * 0.5 * _last_aim.x
	var yaw := deg_to_rad(kick_yaw_deg) * randf_range(-1.0, 1.0)
	_player.add_camera_kick(Vector3(pitch, yaw, roll))
