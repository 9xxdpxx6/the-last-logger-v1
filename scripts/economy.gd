extends Node

## Кошелёк игрока и дневной прогресс сдачи древесины. АВТОЗАГРУЗКА (singleton "Economy") — узел живёт
## между сценами, поэтому деньги и накопленная норма не сбрасываются при смене уровня. Баланс
## (цены/норма/цель акта) держим в EconomyConfig (.tres), а здесь — только состояние и операции.
##
## Подключение в project.godot: [autoload] Economy="*res://scripts/economy.gd".

## Деньги изменились (после продажи) — для HUD-кошелька.
signal money_changed(money: float)
## Живой вес дров в поленнице изменился — для ВЫВЕСКИ бункера (что лежит на складе СЕЙЧАС).
signal quota_changed(delivered: float, quota: float)
## Дневной прогресс сдачи изменился (сдано за день / норма) — для HUD «Норма дня». В отличие от
## quota_changed, СБРАСЫВАЕТСЯ каждое утро (start_new_day) и растёт только при сдаче.
signal day_progress_changed(sold: float, quota: float)
## Разовая продажа: вес куска и сколько за него дали — для всплывающей обратной связи "+$N".
signal sold(weight: float, earned: float)

const CONFIG := preload("res://resources/economy_config.tres")

## Текущий баланс игрока (валюта). Начисляется при СДАЧЕ бревна и обратно НЕ списывается, даже если
## дрова потом вытащили из поленницы (деньги — «заработок», а не баланс склада).
var money: float = 0.0
## ЖИВОЙ вес дров, лежащих в поленнице ПРЯМО СЕЙЧАС (кг). Это НЕ накопитель: сдал — растёт, вытащил/
## срубил-и-унёс — падает. Считает зона сдачи (SellZone) по фактическому содержимому загона и шлёт сюда
## через set_pile_weight. По нему рисуется индикатор «Норма дня».
var day_delivered_kg: float = 0.0
## Заработано ДЕНЕГ за ТЕКУЩИЙ день (для экрана итогов). Накапливается при каждой продаже, обнуляется
## в start_new_day. Деньги в кошелёк всё равно идут сразу — это лишь дневной счётчик для отчёта.
var day_earned: float = 0.0
## Вес, фактически СДАННЫЙ за текущий день (кг, монотонно растёт). В отличие от day_delivered_kg (живой
## вес поленницы, который падает при выноске), это «сколько принесли за день» — по нему считаем норму.
var day_sold_kg: float = 0.0


## Начислить ДЕНЬГИ за сданное бревно весом kg (валюта = вес × цена/кг). Только доход — складской вес
## ведёт set_pile_weight отдельно. Возвращает заработанное (для всплывающей "+$N").
func add_income(kg: float) -> float:
	if kg <= 0.0:
		return 0.0
	var earned := kg * CONFIG.price_per_kg
	money += earned
	day_earned += earned
	day_sold_kg += kg
	money_changed.emit(money)
	day_progress_changed.emit(day_sold_kg, CONFIG.daily_quota_kg)
	sold.emit(kg, earned)
	return earned


## Задать ТЕКУЩИЙ вес дров в поленнице (кг). Зовёт зона сдачи при любом изменении содержимого загона
## (сдали/вытащили/срубили). Индикатор нормы показывает именно это «живое» число.
func set_pile_weight(kg: float) -> void:
	day_delivered_kg = maxf(kg, 0.0)
	quota_changed.emit(day_delivered_kg, CONFIG.daily_quota_kg)


## Новый день (зовёт DayNight при пробуждении): обнуляем ДНЕВНЫЕ счётчики (заработок и сданный вес).
## Номер дня ведёт DayNight. Вес поленницы НЕ трогаем (дрова на складе остаются — его перезадаёт зона
## по факту). Деньги и цель акта переносятся (это «банк», а не день).
func start_new_day() -> void:
	day_earned = 0.0
	day_sold_kg = 0.0
	day_progress_changed.emit(day_sold_kg, CONFIG.daily_quota_kg)


## Снимок для сохранения (SaveManager). Кладём только то, что переносится между запусками: деньги.
## Дневные счётчики не сохраняем — автосейв идёт после сна, когда они уже обнулены.
func to_dict() -> Dictionary:
	return {"money": money}


## Восстановить из сохранения. Зовёт SaveManager на старте/при загрузке. Дневные счётчики сбрасываем —
## загрузка = свежее утро того дня (живой вес склада перезадаст зона по факту мира).
func apply_dict(data: Dictionary) -> void:
	money = maxf(float(data.get("money", 0.0)), 0.0)
	day_earned = 0.0
	day_sold_kg = 0.0
	money_changed.emit(money)
	day_progress_changed.emit(0.0, CONFIG.daily_quota_kg)


## Полный сброс к началу новой игры: деньги и все дневные счётчики на ноль. Зовёт SaveManager.new_game.
func reset_all() -> void:
	money = 0.0
	day_earned = 0.0
	day_sold_kg = 0.0
	day_delivered_kg = 0.0
	money_changed.emit(money)
	day_progress_changed.emit(0.0, CONFIG.daily_quota_kg)
	quota_changed.emit(0.0, CONFIG.daily_quota_kg)


## Дневная норма (кг) из конфига — чтобы слушателям не лезть в CONFIG напрямую.
func daily_quota() -> float:
	return CONFIG.daily_quota_kg


## Доля выполнения дневной нормы 0..1 — для полосы прогресса.
func quota_fraction() -> float:
	if CONFIG.daily_quota_kg <= 0.0:
		return 1.0
	return clampf(day_delivered_kg / CONFIG.daily_quota_kg, 0.0, 1.0)


## Накопительная цель акта (деньги на эвакуацию) — задел на будущее.
func act_goal() -> float:
	return CONFIG.act_evac_goal


## Раз в сколько дней вывозят штабель (0 — не вывозят). Зона сдачи решает, когда чистить склад.
func collect_interval() -> int:
	return CONFIG.collect_interval_days
