extends Node

## Кошелёк игрока и дневной прогресс сдачи древесины. АВТОЗАГРУЗКА (singleton "Economy") — узел живёт
## между сценами, поэтому деньги и накопленная норма не сбрасываются при смене уровня. Баланс
## (цены/норма/цель акта) держим в EconomyConfig (.tres), а здесь — только состояние и операции.
##
## Подключение в project.godot: [autoload] Economy="*res://scripts/economy.gd".

## Деньги изменились (после продажи) — для HUD-кошелька.
signal money_changed(money: float)
## Вес дров в поленнице изменился — для индикатора нормы (в поленнице / норма).
signal quota_changed(delivered: float, quota: float)
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
## Номер дня (1, 2, …) — пока просто счётчик, под будущий цикл день/ночь.
var day_index: int = 1


## Начислить ДЕНЬГИ за сданное бревно весом kg (валюта = вес × цена/кг). Только доход — складской вес
## ведёт set_pile_weight отдельно. Возвращает заработанное (для всплывающей "+$N").
func add_income(kg: float) -> float:
	if kg <= 0.0:
		return 0.0
	var earned := kg * CONFIG.price_per_kg
	money += earned
	money_changed.emit(money)
	sold.emit(kg, earned)
	return earned


## Задать ТЕКУЩИЙ вес дров в поленнице (кг). Зовёт зона сдачи при любом изменении содержимого загона
## (сдали/вытащили/срубили). Индикатор нормы показывает именно это «живое» число.
func set_pile_weight(kg: float) -> void:
	day_delivered_kg = maxf(kg, 0.0)
	quota_changed.emit(day_delivered_kg, CONFIG.daily_quota_kg)


## Новый день: пока сбрасывает счётчик дня. Вес поленницы НЕ трогаем (дрова на складе остаются —
## его перезадаёт зона по факту). Деньги и цель акта переносятся (это «банк», а не день).
func start_new_day() -> void:
	day_index += 1


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
