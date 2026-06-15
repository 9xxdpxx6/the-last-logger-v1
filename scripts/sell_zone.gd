extends Area3D

## Точка сдачи древесины = ПОЛЕННИЦА-загон (#woodpile): бревно (FallingLog), ЦЕЛИКОМ оказавшееся в зоне,
## продаётся (деньги по весу → Economy) и ОСТАЁТСЯ лежать в загоне как складское — пирамидится физикой со
## стенками. Раз в N дней (Economy.collect_interval) штабель «вывозят» — складские дрова исчезают (по
## сюжету за ними приезжают, потому деньги и платят). Зона ловит брёвна по физслою "falling_tree".
##
## Контракт сцены sell_zone.tscn: корень Area3D + CollisionShape3D "Zone" (объём загона, по нему же
## считаем «бревно целиком внутри») + (необязательно) Label3D "Sign". Стенки — отдельный StaticBody "Bin".

@onready var _sign: Label3D = get_node_or_null("Sign")
@onready var _zone: CollisionShape3D = get_node_or_null("Zone")

# Период пересчёта живого веса + досдачи осевших брёвен (с): опрашиваем периодически, чтобы поймать и
# подбор (ушло из зоны), и раскол, и медленно доезжающее бревно, которое только теперь влезло целиком.
const RECOMPUTE_PERIOD := 0.2
var _recompute_accum := 0.0


func _ready() -> void:
	# Вход тела — повод сразу попробовать продать (если бревно сразу легло целиком) и пересчитать склад.
	body_entered.connect(_on_zone_changed)
	# Табличку держим в актуальном состоянии: на старте и при каждом изменении живого веса.
	if Economy.quota_changed.connect(_on_quota_changed) != OK:
		push_warning("SellZone: не удалось подключиться к Economy.quota_changed")
	# Вывоз штабеля на старте нового дня (раз в N дней).
	DayNight.new_day_started.connect(_on_new_day)
	_process_zone()
	_refresh_sign()


func _physics_process(delta: float) -> void:
	_recompute_accum += delta
	if _recompute_accum >= RECOMPUTE_PERIOD:
		_recompute_accum = 0.0
		_process_zone()


func _on_zone_changed(_body: Node) -> void:
	_process_zone()


# Один проход по содержимому загона: продаём то, что лежит ЦЕЛИКОМ внутри, и пересчитываем живой вес.
func _process_zone() -> void:
	_sell_contained()
	_recompute_pile()


# Продаём ещё не оплаченные брёвна, которые ЦЕЛИКОМ внутри зоны. Торчащее наполовину (#sell-partial) не
# продаём и в вес не считаем — нужно дотолкать/дорубить, чтобы влезло. Оплаченное помечаем складским.
func _sell_contained() -> void:
	for b in get_overlapping_bodies():
		if not (b is FallingLog):
			continue
		var fl := b as FallingLog
		if fl.can_be_sold() and _is_fully_inside(fl):
			Economy.add_income(fl.get_weight())
			# TODO(полировка): звук кассы + всплывающее "+$N" над табличкой.
			fl.stockpile()


# Бревно целиком в объёме зоны: оба торца (локальные Y=0 и Y=length) внутри бокса "Zone". Так длинное
# бревно, торчащее за край загона, не засчитывается, пока его не дотолкнуть/дорубить.
func _is_fully_inside(fl: FallingLog) -> bool:
	if _zone == null:
		return true
	var box := _zone.shape as BoxShape3D
	if box == null:
		return true
	var half := box.size * 0.5
	var inv := _zone.global_transform.affine_inverse()
	var a := inv * fl.global_position
	var b := inv * fl.to_global(Vector3(0.0, fl.get_length(), 0.0))
	return _point_in_box(a, half) and _point_in_box(b, half)


func _point_in_box(p: Vector3, half: Vector3) -> bool:
	return absf(p.x) <= half.x and absf(p.y) <= half.y and absf(p.z) <= half.z


# Живой вес поленницы = сумма ОТОБРАЖАЕМЫХ весов всех ОПЛАЧЕННЫХ брёвен (и их кусков), лежащих в загоне
# прямо сейчас. Сдал — вырастет; вытащил/унёс кусок — упадёт; срубил внутри — куски остались, вес тот же.
func _recompute_pile() -> void:
	var total := 0.0
	for b in get_overlapping_bodies():
		if b is FallingLog and not (b as FallingLog).can_be_sold():
			total += (b as FallingLog).get_weight()
	Economy.set_pile_weight(total)


# Новый день: раз в N дней штабель вывозят — складские дрова исчезают. Деньги уже начислены при сдаче,
# поэтому ничего не доплачиваем — это лишь физическая «забрали со склада».
func _on_new_day(day_index: int) -> void:
	var interval := Economy.collect_interval()
	if interval > 0 and (day_index - 1) % interval == 0:
		_collect_pile()


func _collect_pile() -> void:
	for n in get_tree().get_nodes_in_group("stockpiled"):
		(n as Node).queue_free()
	# Пересчёт после вывоза сделает следующий тик; живой вес сразу обнуляем для отзывчивой таблички.
	Economy.set_pile_weight(0.0)


func _on_quota_changed(_delivered: float, _quota: float) -> void:
	_refresh_sign()


func _refresh_sign() -> void:
	if _sign == null:
		return
	var amount := tr("SELL_AMOUNT").format({
		"cur": "%d" % int(round(Economy.day_delivered_kg)),
		"goal": "%d" % int(round(Economy.daily_quota()))})
	_sign.text = "%s\n%s" % [tr("SELL_TITLE"), amount]
