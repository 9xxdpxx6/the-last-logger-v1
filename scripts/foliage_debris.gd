extends Node

## Лежачий «мусор» от срезанных зарослей (АВТОЗАГРУЗКА "FoliageDebris"). Срезал куст → на земле
## остаётся плоский ворох. ТАЙМЕРА НЕТ: ворохи держатся, пока не упрутся в ЛИМИТ количества —
## тогда вытесняется САМЫЙ СТАРЫЙ (кольцевой буфер). Та же идея, что «память по количеству» у
## зарубок: копим до порога, дальше старое уходит. Так мир не засоряется бесконечно.
##
## Подключение: [autoload] FoliageDebris="*res://scripts/foliage_debris.gd". Ворохи — чисто
## визуальные (без коллизии): не блокируют и не тормозят, просто лежат «следом» от вырубки.

## Сколько срезанных ворохов держим в мире одновременно. Превысили — старейший исчезает.
@export var max_clumps: int = 24

## Ворохи в порядке появления (старые в начале) — для вытеснения старейшего за лимитом.
var _clumps: Array[Node3D] = []


## Уронить ворох на месте срезанной заросли. xf — её мировой трансформ, ext — полуразмеры (под размер
## ворха), density — плотность (на оттенок). Зовётся из Foliage._cut().
func spawn(xf: Transform3D, density: int, ext: Vector3) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var clump := MeshInstance3D.new()
	var bm := BoxMesh.new()
	# Плоский расплющенный ворох: широкий по XZ, низкий по Y — «свежескошено».
	bm.size = Vector3(ext.x * 2.2, 0.12, ext.z * 2.2)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.16, 0.5 - 0.1 * float(density), 0.12)
	bm.material = mat
	clump.mesh = bm
	scene.add_child(clump)
	clump.global_transform = xf
	clump.position.y += 0.07  # лежит прямо на земле
	_clumps.append(clump)
	_evict_overflow()


# Держим не больше max_clumps: лишние (и невалидные) убираем с начала — старейшие исчезают первыми.
func _evict_overflow() -> void:
	while _clumps.size() > maxi(max_clumps, 1):
		var old: Node3D = _clumps.pop_front()
		if is_instance_valid(old):
			old.queue_free()
