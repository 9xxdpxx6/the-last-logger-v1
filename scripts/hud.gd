extends CanvasLayer

## HUD игрока. Здесь — только ЭКОНОМИКА (кошелёк + дневная норма): слушаем сигналы синглтона Economy
## и обновляем виджеты. Остальные элементы HUD (Crosshair, Prompt, HpBar) ведёт player.gd напрямую —
## этот скрипт их не трогает.
##
## Контракт сцены: дочерние Label "Money" и ProgressBar "QuotaBar" c дочерним Label "Label".

@onready var _money: Label = get_node_or_null("Money")
@onready var _quota: ProgressBar = get_node_or_null("QuotaBar")
@onready var _quota_label: Label = get_node_or_null("QuotaBar/Label")


func _ready() -> void:
	Economy.money_changed.connect(_on_money_changed)
	# «Норма дня» = ДНЕВНОЙ прогресс сдачи (сбрасывается утром), а не живой вес склада.
	Economy.day_progress_changed.connect(_on_quota_changed)
	# Сразу показать стартовые значения (синглтон мог накопить деньги до загрузки этой сцены).
	_on_money_changed(Economy.money)
	_on_quota_changed(Economy.day_sold_kg, Economy.daily_quota())


func _on_money_changed(money: float) -> void:
	if _money:
		_money.text = tr("HUD_MONEY").format({"money": "%d" % int(round(money))})


func _on_quota_changed(delivered: float, quota: float) -> void:
	if _quota:
		_quota.max_value = maxf(quota, 1.0)
		_quota.value = delivered
	if _quota_label:
		_quota_label.text = tr("HUD_QUOTA").format({
			"cur": "%d" % int(round(delivered)), "goal": "%d" % int(round(quota))})
