extends Area3D

## Точка сдачи древесины = ПОЛЕННИЦА-загон (#woodpile): бревно (FallingLog), попавшее в зону, продаётся
## (деньги по весу → Economy) и ОСТАЁТСЯ лежать в загоне как складское — не исчезает и не телепортируется,
## а пирамидится физикой с другими (стенки загона держат кучу от раскатывания). Зона ловит брёвна по
## физслою "falling_tree" (collision_mask Area3D в сцене).
##
## Контракт сцены sell_zone.tscn: корень Area3D с этим скриптом + CollisionShape3D (объём загона внутри
## стенок) + (необязательно) Label3D "Sign" с прогрессом нормы. Стенки загона — отдельный StaticBody.

@onready var _sign: Label3D = get_node_or_null("Sign")

# Период пересчёта живого веса загона (с): пересчитываем по таймеру (а не только на enter/exit), чтобы
# учесть и подбор бревна (ушло из зоны), и его раскол/уничтожение — надёжно при любом способе убытия.
const RECOMPUTE_PERIOD := 0.2
var _recompute_accum := 0.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	# Табличку держим в актуальном состоянии: на старте и при каждом изменении нормы.
	if Economy.quota_changed.connect(_on_quota_changed) != OK:
		push_warning("SellZone: не удалось подключиться к Economy.quota_changed")
	_recompute_pile()
	_refresh_sign()


func _physics_process(delta: float) -> void:
	# Живой вес поленницы пересчитываем периодически: дрова уходят из загона по-разному (подобрал,
	# срубил-и-куски укатились, уничтожил), и ловить каждый случай сигналом ненадёжно — проще опросить.
	_recompute_accum += delta
	if _recompute_accum >= RECOMPUTE_PERIOD:
		_recompute_accum = 0.0
		_recompute_pile()


func _on_body_entered(body: Node) -> void:
	# Продаём только брёвна. Прочие тела (игрок сюда не попадёт — другой слой, тачка) игнорируем.
	if not (body is FallingLog):
		return
	var fl := body as FallingLog
	# Свежее (ещё не оплаченное) бревно — начисляем ДЕНЬГИ один раз и помечаем складским. Уже оплаченное
	# (вкатилось обратно/кусок раскола) денег не даёт — но в вес поленницы всё равно войдёт (ниже).
	if fl.can_be_sold():
		Economy.add_income(fl.get_weight())
		# TODO(полировка): звук кассы + всплывающее "+$N" над табличкой.
		fl.stockpile()
	# Содержимое загона изменилось — сразу обновляем живой вес (не ждём таймер).
	_recompute_pile()


# Живой вес поленницы = сумма ОТОБРАЖАЕМЫХ весов всех ОПЛАЧЕННЫХ брёвен (и их кусков), лежащих в загоне
# прямо сейчас. Сдал — вырастет; вытащил/унёс кусок — упадёт; срубил внутри — куски остались, вес тот же.
func _recompute_pile() -> void:
	var total := 0.0
	for b in get_overlapping_bodies():
		if b is FallingLog and not (b as FallingLog).can_be_sold():
			total += (b as FallingLog).get_weight()
	Economy.set_pile_weight(total)


func _on_quota_changed(_delivered: float, _quota: float) -> void:
	_refresh_sign()


func _refresh_sign() -> void:
	if _sign == null:
		return
	var amount := tr("SELL_AMOUNT").format({
		"cur": "%d" % int(round(Economy.day_delivered_kg)),
		"goal": "%d" % int(round(Economy.daily_quota()))})
	_sign.text = "%s\n%s" % [tr("SELL_TITLE"), amount]
