extends RefCounted
class_name ChopSites

## Накопитель «точек рубки» на одном теле. Близкие удары сливаются в ОДНУ точку: она
## копит прогресс (силой удара, не штуками). На пороге точка считается «добитой» —
## там ствол ломается (а позже лежачее бревно раскалывается на полено). Геометрию
## зарубки рисует ProceduralTrunk по позиции и глубине точки — здесь только учёт.
##
## Позиции точек храним в ЛОКАЛЕ МЕША ствола (centered, Y от −H/2 до +H/2): ровно те
## координаты, что нужны генератору меша. Конвертацию мир→локаль делает вызывающий.

## Одна точка рубки.
class Site:
	## Позиция в локале меша ствола (centered). Фиксируется по ПЕРВОМУ удару.
	var local_pos: Vector3
	## Накопленный прогресс (сумма сил ударов).
	var progress: float = 0.0
	## Сумма единичных векторов направлений ударов (по углу вокруг ствола) и их число.
	## По ним считаем, рубили В ОДНУ сторону или РАВНОМЕРНО ПО КРУГУ (см. ring_factor).
	var dir_sum: Vector2 = Vector2.ZERO
	var hits: int = 0
	## Ориентация лезвия на поверхности (вдоль/поперёк ствола) последнего удара — по ней
	## генератор рисует прорезь зарубки повёрнутой как кромка топора.
	var blade: Vector2 = Vector2(1.0, 0.0)

## Все точки рубки на этом теле — генератор меша обходит их для построения зарубок.
var sites: Array[Site] = []

var _merge_radius: float
var _chops_needed: float


func _init(merge_radius: float, chops_needed: int) -> void:
	_merge_radius = merge_radius
	_chops_needed = float(chops_needed)


## Удар в точке local_point (в локале меша). power — вклад в прогресс. Возвращает
## точку рубки, в которую попал удар (новую или существующую рядом).
func add_hit(local_point: Vector3, power: float = 1.0,
		blade: Vector2 = Vector2(1.0, 0.0)) -> Site:
	var site := _find_near(local_point)
	if site == null:
		# Новая точка: позицию фиксируем по первому удару, дальше зарубка только растёт.
		site = Site.new()
		site.local_pos = local_point
		sites.append(site)
	site.progress += power
	# Копим направление удара вокруг ствола (угол точки попадания) — взвешенно по силе.
	var ang := atan2(local_point.z, local_point.x)
	site.dir_sum += Vector2(cos(ang), sin(ang)) * power
	site.hits += 1
	# Ориентацию прорези задаёт последний удар (куда повёрнуто лезвие сейчас).
	site.blade = blade
	return site


## Точка добита до порога — здесь ствол ломается / бревно раскалывается.
func is_felled(site: Site) -> bool:
	return site.progress >= _chops_needed


## Доля прогресса 0..1 — её генератор переводит в глубину вдавливания зарубки.
func depth_fraction(site: Site) -> float:
	return clampf(site.progress / _chops_needed, 0.0, 1.0)


## Насколько рубили РАВНОМЕРНО ПО КРУГУ: 0 — все удары в одну сторону (будет скос),
## 1 — равномерно вокруг (будет заострённый кол). Это длина среднего вектора: при
## разбросе по кругу он коротит до нуля, при ударах в одну точку близок к прогрессу.
func ring_factor(site: Site) -> float:
	if site.progress <= 0.0:
		return 0.0
	return clampf(1.0 - site.dir_sum.length() / site.progress, 0.0, 1.0)


## Преобладающая сторона рубки (угол вокруг ствола, рад) — куда направлять скос.
func mean_angle(site: Site) -> float:
	return atan2(site.dir_sum.y, site.dir_sum.x)


# Слияние по ВЫСОТЕ вдоль оси ствола (локальный Y), не по 3D-расстоянию: рубка по
# кругу на одной высоте копится в ОДИН разруб (как настоящая подрубка/опоясывание),
# а не в кучу отдельных точек по окружности.
func _find_near(local_point: Vector3) -> Site:
	for s in sites:
		if absf(s.local_pos.y - local_point.y) <= _merge_radius:
			return s
	return null
