extends Area3D
class_name Foliage

## Заросли/трава/куст (greybox). Делают ДВЕ вещи:
##  • пока игрок ВНУТРИ — мягко ЗАМЕДЛЯЮТ его (зона ловит тело игрока, отдаёт множитель скорости);
##  • срубаются ТОПОРОМ (тот же путь, что у дерева: chop_controller зовёт chop() у этого узла) —
##    после среза падает лежачий «мусор» (FoliageDebris), а сама заросль исчезает.
## Это НЕ дрова: вес/экономика тут ни при чём, только помеха движению и расходник на земле.
##
## Узлы сцены: КОРЕНЬ Area3D (эта зона тормозит игрока: monitoring, mask=player). Дочерний
## StaticBody3D "Cut" на слое foliage(7) — по нему бьёт топор (ChopRay этот слой видит), а игрок
## (его маска слой 7 НЕ включает) проходит сквозь. Меш — greybox-бокс, строится в коде по плотности.

## Плотность: гуще → сильнее тормозит и больше ударов на срез. Несколько уровней, чтобы варьировать.
enum Density { GRASS, BRUSH, THICKET }

@export var density: Density = Density.GRASS:
	set(value):
		density = value
		if is_inside_tree():
			_rebuild()

@export_group("Замедление")
## Во сколько раз режется скорость игрока ВНУТРИ зарослей (на каждую плотность). Меньше — гуще тормоз.
@export var grass_speed_mult: float = 0.75
@export var brush_speed_mult: float = 0.5
@export var thicket_speed_mult: float = 0.3

@export_group("Срезание")
## Сколько ударов топора нужно, чтобы срезать (на каждую плотность).
@export var grass_chops: int = 1
@export var brush_chops: int = 1
@export var thicket_chops: int = 2

@export_group("Размер")
## Полуразмеры greybox-куста (X/Z — радиус по земле, Y — половина высоты). Задают и зону тормоза,
## и тело-цель топора, и меш. Гуще — крупнее.
@export var grass_extents: Vector3 = Vector3(0.6, 0.35, 0.6)
@export var brush_extents: Vector3 = Vector3(0.8, 0.6, 0.8)
@export var thicket_extents: Vector3 = Vector3(1.0, 1.0, 1.0)

@export_group("Скрытность")
## УКРЫТИЕ (0..1): насколько заросль прячет игрока ВИЗУАЛЬНО. Гуще — прячет сильнее. Стоя на месте
## укрывает полностью, на ходу — вдвое хуже (срыв укрытия движением считает сам игрок).
@export var grass_conceal: float = 0.5
@export var brush_conceal: float = 0.75
@export var thicket_conceal: float = 0.95
## ШОРОХ (0..1): сколько ШУМА ДОБАВЛЯЕТ движение сквозь заросль (продираешься — шумишь). Трава шумит
## громче кустов. На ходу/бегу прибавка полная (~+15…20%), в присяде сильно глушится (crouch_rustle_mult
## у игрока) — крадёшься аккуратно (трава ~+2%, кусты меньше). Берётся самый громкий шорох среди зон.
@export var grass_rustle: float = 0.2
@export var brush_rustle: float = 0.15
@export var thicket_rustle: float = 0.15

@export_group("Твёрдый ствол")
## Полутолщина ТВЁРДОГО центра (м): сквозь него не пройти, на нём строятся «стены» из кустов.
## 0 — ствола нет, заросль полностью проходима (для ТРАВЫ). Куст/заросли — твёрдый стволик в центре.
## Высота ствола = полная высота куста, поэтому игрок через него не переступает (выше step_height).
@export var grass_core_radius: float = 0.0
@export var brush_core_radius: float = 0.18
@export var thicket_core_radius: float = 0.28

@onready var _slow_shape: CollisionShape3D = $SlowShape
@onready var _cut_shape: CollisionShape3D = $Cut/CutShape
@onready var _core_shape: CollisionShape3D = $Core/CoreShape
@onready var _mesh: MeshInstance3D = $Mesh

## Осталось ударов до среза (считается от плотности).
var _chops_left: int = 1


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_rebuild()


# Перестроить зону/тело-цель/меш под текущую плотность. Зовём на старте и при смене density в Инспекторе.
func _rebuild() -> void:
	var ext := _extents()
	_chops_left = _chops()
	# Одна коробка на всё: зона торможения (Area) и тело-цель (Cut). Origin узла стоит на земле,
	# поэтому коробку и меш поднимаем на половину высоты (центр на ext.y).
	var box := BoxShape3D.new()
	box.size = ext * 2.0
	_slow_shape.shape = box
	_slow_shape.position = Vector3(0.0, ext.y, 0.0)
	_cut_shape.shape = box.duplicate()
	_cut_shape.position = Vector3(0.0, ext.y, 0.0)
	# Твёрдый ствол в центре (на слое environment — игрок упрётся, топор его не видит). У травы 0 → выкл.
	var cr := _core_radius()
	if cr > 0.0:
		var core := BoxShape3D.new()
		core.size = Vector3(cr * 2.0, ext.y * 2.0, cr * 2.0)
		_core_shape.shape = core
		_core_shape.position = Vector3(0.0, ext.y, 0.0)
		_core_shape.disabled = false
	else:
		_core_shape.disabled = true
	_mesh.mesh = _build_mesh(ext)
	_mesh.position = Vector3(0.0, ext.y, 0.0)


func _extents() -> Vector3:
	match density:
		Density.THICKET: return thicket_extents
		Density.BRUSH: return brush_extents
		_: return grass_extents


func _chops() -> int:
	match density:
		Density.THICKET: return thicket_chops
		Density.BRUSH: return brush_chops
		_: return grass_chops


func _core_radius() -> float:
	match density:
		Density.THICKET: return thicket_core_radius
		Density.BRUSH: return brush_core_radius
		_: return grass_core_radius


## Укрытие (визуальное) этой заросли — его берёт player._foliage_conceal (максимум среди зон).
func conceal() -> float:
	match density:
		Density.THICKET: return thicket_conceal
		Density.BRUSH: return brush_conceal
		_: return grass_conceal


## Шорох (добавка к шуму при движении) — его берёт player._foliage_rustle (максимум среди зон).
func rustle() -> float:
	match density:
		Density.THICKET: return thicket_rustle
		Density.BRUSH: return brush_rustle
		_: return grass_rustle


## Доля силуэта игрока (0..1, по вертикали), попавшая в объём заросли — её считает player._zone_coverage.
## Если центр игрока вне ПЯТНА заросли (задел краем/рукой) — 0: «рукой задел» не прячет. feet_y/head_y
## — низ/верх силуэта (присяд опускает верх), world_pos — мировая позиция игрока.
func coverage(feet_y: float, head_y: float, world_pos: Vector3) -> float:
	var ext := _extents()
	var local := global_transform.affine_inverse() * world_pos
	if absf(local.x) > ext.x or absf(local.z) > ext.z:
		return 0.0
	var box_bottom := global_position.y
	var box_top := global_position.y + 2.0 * ext.y
	var overlap := minf(head_y, box_top) - maxf(feet_y, box_bottom)
	return clampf(overlap / maxf(head_y - feet_y, 0.01), 0.0, 1.0)


## Множитель скорости игрока внутри (его собирает player._foliage_speed_mult).
func speed_mult() -> float:
	match density:
		Density.THICKET: return thicket_speed_mult
		Density.BRUSH: return brush_speed_mult
		_: return grass_speed_mult


# Greybox-меш: один зелёный бокс размером с куст (позже заменим на CC0-модель травы/кустарника).
# Гуще → темнее насыщенный зелёный, чтобы плотности различались на глаз.
func _build_mesh(ext: Vector3) -> Mesh:
	var bm := BoxMesh.new()
	bm.size = ext * 2.0
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.18, 0.62 - 0.13 * float(density), 0.16)
	bm.material = mat
	return bm


func _on_body_entered(body: Node) -> void:
	if body is Player:
		(body as Player).enter_foliage(self)


func _on_body_exited(body: Node) -> void:
	if body is Player:
		(body as Player).exit_foliage(self)


# Удар топором. chop_controller бьёт ShapeCast'ом по телу "Cut" и зовёт chop() у его РОДИТЕЛЯ (этот
# узел). Сигнатура совпадает с tree.chop(); заросли зарубки не копят — просто считаем удары до среза.
func chop(_chopper_position: Vector3, _hit_point: Vector3 = Vector3.INF,
		_hit_normal: Vector3 = Vector3.UP, _power: float = 1.0,
		_edge_dir: Vector3 = Vector3.ZERO) -> void:
	_chops_left -= 1
	if _chops_left > 0:
		return
	_cut()


# Срезано: снимаем игрока с зоны (иначе его множитель «залипнет» — queue_free не шлёт body_exited),
# роняем лежачий мусор и удаляемся.
func _cut() -> void:
	for b in get_overlapping_bodies():
		if b is Player:
			(b as Player).exit_foliage(self)
	FoliageDebris.spawn(global_transform, int(density), _extents())
	queue_free()
