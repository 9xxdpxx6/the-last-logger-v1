extends Node

# Код-анимация конечностей игрока (#9.3, greybox). Раньше жила прямо в player.gd
# (_animate_body/_aim_arm/_swing_arm); вынесена в отдельный узел-компонент, чтобы Player
# остался «диспетчером», а презентация (которая ТОЛЬКО читает состояние и крутит меши, физику
# не трогает) — здесь. Своего AnimationPlayer/рига у игрока нет, поэтому крутим меши-примитивы
# напрямую вокруг локальных осей:
#  • РУКИ при волоке/тачке — наводятся на то, что держим (ручки тачки / торец бревна);
#  • НОГИ при ходьбе — шагают «ножницами» (одна вперёд, другая назад) по синусу _walk_phase;
#  • РУКИ при ходьбе налегке — машут в противофазе ногам; с топором — правая держит топор.
# Тело скрыто от FP-камеры (shadows_only), так что эффект виден по ТЕНИ игрока на земле.

# Игрок-родитель: у него читаем скорость/опору/что держим (через публичные held_barrow()/dragged_log()).
@onready var _player: Player = get_parent() as Player
@onready var _arm_l: Node3D = _player.get_node("Model/ArmL")
@onready var _arm_r: Node3D = _player.get_node("Model/ArmR")
@onready var _leg_l: Node3D = _player.get_node("Model/LegL")
@onready var _leg_r: Node3D = _player.get_node("Model/LegR")
@onready var _axe: Node3D = _player.get_node("Camera3D/Axe")

## Фаза шагательного цикла (рад): растёт, пока игрок идёт по земле; задаёт качание ног/рук.
var _walk_phase: float = 0.0


func _process(delta: float) -> void:
	if _leg_l == null:
		return
	var hv := Vector3(_player.velocity.x, 0.0, _player.velocity.z)
	var moving := _player.is_on_floor() and hv.length() > 0.5
	if moving:
		_walk_phase += delta * 9.0
	var swing := sin(_walk_phase) * deg_to_rad(22.0) if moving else 0.0
	var k := clampf(12.0 * delta, 0.0, 1.0)
	# Ноги «ножницами» (в противофазе друг другу); в покое плавно возвращаются к нулю.
	_leg_l.rotation.x = lerpf(_leg_l.rotation.x, swing, k)
	_leg_r.rotation.x = lerpf(_leg_r.rotation.x, -swing, k)
	# Руки НАВОДИМ на то, что держим, чтобы кисти реально сходились к предмету, а не висели рядом
	# в воздухе (#9c.3): тачка — каждая рука к своей рукоятке; бревно — обе руки в одну точку хвата;
	# топор — правая рука на рукоять вьюмодели (#9c.2). Свободные руки машут в противофазе ногам.
	var barrow := _player.held_barrow()
	var dragged := _player.dragged_log()
	var manip_grasp = _player.manip_grasp_world()  # Variant: Vector3 (телекинез) или null
	if manip_grasp != null:
		# Телекинез (#manip): обе руки тянутся к ТОЧКЕ ХВАТА держимого бревна — по тени видно, что персонаж
		# держит предмет перед собой на вытянутых руках (топор при этом убран).
		var right := _player.global_transform.basis.x
		_aim_arm(_arm_l, (manip_grasp as Vector3) - right * 0.18, k)
		_aim_arm(_arm_r, (manip_grasp as Vector3) + right * 0.18, k)
	elif barrow != null:
		var right := barrow.global_transform.basis.x
		var g := barrow.grab_point_world()
		_aim_arm(_arm_l, g - right * 0.32, k)
		_aim_arm(_arm_r, g + right * 0.32, k)
	elif dragged != null:
		# Наводим обе руки на РЕАЛЬНЫЙ торец бревна (grab_point_world), а не на вычисленную точку
		# хвата выше пояса (#9e.2): иначе кисти висели заметно выше бревна. Так руки сходятся к месту,
		# где бревно действительно лежит.
		var g := dragged.grab_point_world()
		var right := _player.global_transform.basis.x
		_aim_arm(_arm_l, g - right * 0.18, k)
		_aim_arm(_arm_r, g + right * 0.18, k)
	elif _axe.visible:
		# Топор — вьюмодель в пространстве камеры (его удар сходится в перекрестье, #9g). Чтобы он
		# выглядел зажатым в руке и рука махала вместе с ним, КАЖДЫЙ кадр наводим правую руку на
		# топор (его origin = низ рукояти): кисть тянется к рукояти, а когда топор уходит в удар —
		# рука следует за ним. k=1 (без сглаживания), чтобы рука не отставала от быстрого маха.
		_aim_arm(_arm_r, _axe.global_position, 1.0)
		_swing_arm(_arm_l, -swing, k)
	else:
		_swing_arm(_arm_l, -swing, k)
		_swing_arm(_arm_r, swing, k)


# Наводим руку-меш так, чтобы её «низ» (локальный −Y, конец-кисть) указывал на точку target в мире.
# Рука вращается вокруг плеча (центра меша): наклон вперёд/вниз (X) + разворот вбок (Y). Этого хватает,
# чтобы кисти сводились к одному бревну и тянулись к разнесённым ручкам тачки. target переводим в локаль
# узла Model (родитель руки), считаем направление от плеча и раскладываем на углы тангажа/рысканья.
func _aim_arm(arm: Node3D, target_world: Vector3, k: float) -> void:
	var model := arm.get_parent() as Node3D
	var t_local := model.global_transform.affine_inverse() * target_world
	var d := t_local - arm.position
	if d.length() < 0.01:
		return
	d = d.normalized()
	var pitch := acos(clampf(-d.y, -1.0, 1.0))
	var yaw := atan2(-d.x, -d.z)
	arm.rotation.x = lerp_angle(arm.rotation.x, pitch, k)
	arm.rotation.y = lerp_angle(arm.rotation.y, yaw, k)
	arm.rotation.z = lerp_angle(arm.rotation.z, 0.0, k)


# Качание свободной руки вперёд/назад вокруг плеча (X) с плавным обнулением бокового разворота/крена.
func _swing_arm(arm: Node3D, angle: float, k: float) -> void:
	arm.rotation.x = lerp_angle(arm.rotation.x, angle, k)
	arm.rotation.y = lerp_angle(arm.rotation.y, 0.0, k)
	arm.rotation.z = lerp_angle(arm.rotation.z, 0.0, k)
