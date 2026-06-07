extends RefCounted
class_name ProceduralTrunk

## Процедурный меш ствола: генерируем цилиндр (кольца по высоте × сегменты по кругу)
## и для каждой зарубки ВДАВЛИВАЕМ вершины внутрь в её секторе/высоте. Это настоящая
## деформация — видно с любого угла, углубляется с ударами. Пересобираем меш только
## когда зарубка изменилась (на удар), а не каждый кадр — поэтому дёшево.
##
## Меш центрирован по Y (от −height/2 до +height/2) — под узел MeshInstance, сдвинутый
## на половину высоты (как было у CylinderMesh). В местах зарубки красим вершины темнее
## (vertex color) — без текстур видно, что дерево вырублено.

## Кольца по высоте и сегменты по кругу. Больше — глаже зарубка, но тяжелее меш.
const RINGS := 32
const SEGMENTS := 24

var height: float = 9.0
var bottom_radius: float = 0.3
var top_radius: float = 0.25
var material: Material
## Зарубка — ОРИЕНТИРОВАННАЯ ПО ЛЕЗВИЮ прорезь: длинная вдоль кромки топора, тонкая
## поперёк. notch_long — полудлина вдоль лезвия (м), notch_thick — полуширина поперёк (м).
## Ориентацию (вдоль/поперёк ствола или наискось) задаёт blade каждой зарубки.
var notch_long: float = 0.22
var notch_thick: float = 0.12
## На какой глубине вдавливания зарубка уже полностью «тёмная» (м). Маленькое значение
## — цвет проявляется даже у мелкого заруба, сразу видно, что рубишь.
var notch_color_depth: float = 0.05
## Рваная кромка слома: дёргаем вершины нижнего/верхнего обода — край пня и бревна
## выглядит отколотым, а не ровно отрезанным.
var jagged_bottom: bool = false
var jagged_top: bool = false
var jagged_amount: float = 0.05
## Сдвиг хэша — у каждого пня/бревна СВОЙ рисунок скола (а не один на всех).
var jagged_seed: float = 0.0
## Привязка формы слома к зарубке: с какой стороны рубили (угол вокруг ствола, рад) и
## насколько сильнее там «вырвано» (м). Скос получается перекошенным к месту рубки —
## игрок видит, что форму задал он, а не генератор.
var rim_bias_angle: float = 0.0
var rim_bias: float = 0.0
## Заострение торца «в кол» (м): рубили равномерно по кругу → торец сужается к вершине.
var tip_cone: float = 0.0
## Высота торчащих щепок-заусенцев на самом сломе (м).
var splinter_height: float = 0.0
## На какую глубину от торца (м) тянется формовка слома (конус/скос/щепки).
var break_span: float = 1.0

# Цвет вырубленной древесины (множитель к albedo материала). Тёмный — гашь в зарубе.
const CUT_COLOR := Color(0.4, 0.32, 0.22)


## Строит меш с учётом списка зарубок. carves: Array словарей {pos: Vector3 (в локале
## меша), depth: float (насколько вдавить в центре, м)}.
func build(carves: Array) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var cols := SEGMENTS
	var rows := RINGS + 1

	# Вершины боковой поверхности. Бревно может иметь слом на ОБОИХ торцах одновременно
	# (например, после раскола середины — у половинок старый рваный конец И свежий рез).
	# Поэтому форму слома считаем для каждого торца НЕЗАВИСИМО, а не одним break_dir.
	for r in rows:
		var t := float(r) / float(RINGS)
		var y := -height * 0.5 + t * height
		var base_r := lerpf(bottom_radius, top_radius, t)
		for c in cols:
			var ang := TAU * float(c) / float(cols)
			var red := _reduction(carves, y, ang)
			var rad := base_r - red
			var vy := y
			var cut := clampf(red / notch_color_depth, 0.0, 1.0)
			# Обрабатываем нижний и верхний торцы по очереди — какой активен (jagged_*), тот и
			# формуем (конус/скос/щепки). Для нормального бревна торцы дальше break_span друг
			# от друга и не пересекаются; у короткого куска оба вклада просто складываются.
			for end_top in [false, true]:
				var active := jagged_top if end_top else jagged_bottom
				if not active:
					continue
				var bdir := 1.0 if end_top else -1.0
				var d_end := (height * 0.5 - y) if end_top else (y + height * 0.5)
				if d_end >= break_span:
					continue
				var f := 1.0 - d_end / break_span
				var is_end_ring := (r == RINGS) if end_top else (r == 0)
				# Конус «в кол»: к торцу сужаем радиус и тянем вершины к острию.
				rad -= f * f * tip_cone * 0.7
				vy += bdir * f * tip_cone
				# Скос к месту рубки: плоскость торца наклонена.
				if rim_bias != 0.0:
					var sidef := cos(ang - rim_bias_angle)   # +1 на стороне рубки
					vy += -bdir * sidef * rim_bias * f
					rad -= maxf(sidef, 0.0) * rim_bias * 0.5 * f
				# Рваность/щепки — только на самом ободе торца (не вдоль ствола).
				if is_end_ring:
					rad += (_hash01(c * 31 + 5) - 0.5) * 2.0 * jagged_amount
					vy += bdir * pow(_hash01(c * 53 + 7), 3.0) * splinter_height
					vy += (_hash01(c * 71 + 13) - 0.5) * 2.0 * jagged_amount
				# Свежий срез у торца — темнее, читается как древесина.
				cut = maxf(cut, f * 0.85)
			rad = maxf(rad, 0.02)
			st.set_color(Color.WHITE.lerp(CUT_COLOR, cut))
			st.set_uv(Vector2(float(c) / float(cols), t))
			st.add_vertex(Vector3(rad * cos(ang), vy, rad * sin(ang)))

	# Центры крышек (низ/верх). У сломанного торца поднимаем центр к острию конуса.
	var cb := rows * cols
	var ct := cb + 1
	var bc := Color.WHITE if not jagged_bottom else Color.WHITE.lerp(CUT_COLOR, 0.85)
	var tc := Color.WHITE if not jagged_top else Color.WHITE.lerp(CUT_COLOR, 0.85)
	var by := -height * 0.5 - (tip_cone * 1.3 if jagged_bottom else 0.0)
	var ty := height * 0.5 + (tip_cone * 1.3 if jagged_top else 0.0)
	st.set_color(bc)
	st.set_uv(Vector2(0.5, 0.0))
	st.add_vertex(Vector3(0.0, by, 0.0))
	st.set_color(tc)
	st.set_uv(Vector2(0.5, 1.0))
	st.add_vertex(Vector3(0.0, ty, 0.0))

	# Треугольники боковой поверхности.
	for r in RINGS:
		for c in cols:
			var c2 := (c + 1) % cols
			var i0 := r * cols + c
			var i1 := r * cols + c2
			var i2 := (r + 1) * cols + c
			var i3 := (r + 1) * cols + c2
			# Обход по часовой (лицевая сторона в Godot) — нормали наружу.
			st.add_index(i0)
			st.add_index(i1)
			st.add_index(i2)
			st.add_index(i1)
			st.add_index(i3)
			st.add_index(i2)

	# Крышки: низ нормалью вниз, верх — вверх.
	for c in cols:
		var c2 := (c + 1) % cols
		st.add_index(cb)
		st.add_index(c2)
		st.add_index(c)
		st.add_index(ct)
		st.add_index(RINGS * cols + c)
		st.add_index(RINGS * cols + c2)

	st.generate_normals()
	if material:
		st.set_material(material)
	return st.commit()


# Насколько вдавить вершину (y, ang): берём максимум по всем зарубкам. Каждая зарубка —
# ориентированная по лезвию прорезь: переводим смещение вершины от центра зарубки в
# систему «вдоль лезвия (u) / поперёк (w)» и вдавливаем линейным «шатром» в этих осях.
# Линейный спад даёт острую грань в центре — след топора, а не вмятина в трубе.
func _reduction(carves: Array, y: float, ang: float) -> float:
	var red := 0.0
	for carve in carves:
		var cpos: Vector3 = carve["pos"]
		var depth: float = carve["depth"]
		var blade: Vector2 = carve.get("blade", Vector2(1.0, 0.0))
		var cang := atan2(cpos.z, cpos.x)
		# Радиус на высоте центра зарубки — чтобы угловое смещение перевести в метры дуги.
		var r_ref := lerpf(bottom_radius, top_radius, (cpos.y + height * 0.5) / height)
		var dy := y - cpos.y                      # вертикальное смещение (м)
		var dh := _ang_diff(ang, cang) * r_ref    # горизонтальное смещение по дуге (м)
		# Поворачиваем (dh, dy) в оси лезвия: u — вдоль кромки, w — поперёк.
		var u := dh * blade.x + dy * blade.y
		var w := -dh * blade.y + dy * blade.x
		if absf(u) >= notch_long or absf(w) >= notch_thick:
			continue
		var uf := 1.0 - absf(u) / notch_long
		var wf := 1.0 - absf(w) / notch_thick
		red = maxf(red, depth * uf * wf)
	return red


## Направление лезвия НА ПОВЕРХНОСТИ ствола (2D): x — вдоль окружности (азимут), y — вверх.
## local_point — точка удара в локале меша, local_edge — направление кромки топора в том же
## локале. Проецируем кромку на касательную плоскость цилиндра в точке удара.
static func surface_blade_dir(local_point: Vector3, local_edge: Vector3) -> Vector2:
	var cang := atan2(local_point.z, local_point.x)
	# Касательная к окружности (азимутальное направление) в точке удара.
	var t_azi := Vector3(-sin(cang), 0.0, cos(cang))
	var v := Vector2(local_edge.dot(t_azi), local_edge.y)
	if v.length() < 0.01:
		return Vector2(1.0, 0.0)
	return v.normalized()


# Разница углов в диапазоне [−PI, PI] (учёт перехода через 0/2PI).
func _ang_diff(a: float, b: float) -> float:
	var d := fmod(a - b + PI, TAU)
	if d < 0.0:
		d += TAU
	return d - PI


# Детерминированный псевдослучай 0..1 по целому — рваная кромка стабильна между
# пересборками меша (не «дрожит» с каждым ударом).
func _hash01(i: int) -> float:
	var x := sin((float(i) + jagged_seed) * 12.9898) * 43758.5453
	return x - floor(x)
