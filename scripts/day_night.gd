extends Node

## Менеджер суток (АВТОЗАГРУЗКА "DayNight"). Хранит номер дня, время суток и длину дня; ведёт
## переход «день → сон → новый день». Сам НИЧЕГО не рисует и не платит — только время и события;
## слушатели (DayUI — экран итогов, day_sky — освещение, SaveManager — автосейв) реагируют на сигналы.
## Так легко доращивать: усталость/рассудок/погода/ночные события подпишутся на те же сигналы.
##
## Подключение в project.godot: [autoload] DayNight="*res://scripts/day_night.gd" (ПОСЛЕ Economy).

## Время суток сдвинулось — для драйвера неба/освещения и часов в HUD.
signal time_changed(time_of_day: float)
## День завершён (легли спать). Несёт номер ЗАВЕРШЁННОГО дня — DayUI поднимает экран итогов.
signal day_ended(day_index: int)
## Начался новый день (подтвердили итоги). Несёт номер НОВОГО дня — SaveManager делает автосейв.
signal new_day_started(day_index: int)

## Доля СУТОК на которой просыпаемся (после сна / в новой игре): 0.25 = 06:00 (утро).
const MORNING_T := 0.25

## Номер текущего дня (1, 2, …). Источник истины здесь, а не в Economy.
var day_index: int = 1
## Доля прошедших СУТОК [0..1): 0.0 = полночь 00:00, 0.5 = полдень 12:00, →1.0 = снова полночь. Растёт
## сама в _process и заворачивается через полночь (сутки идут по кругу). Старт/после сна — с утра (0.25).
var time_of_day: float = MORNING_T
## Длительность активного дня в секундах (ТЮНИНГ). За это время time_of_day идёт 0 → 1.
var day_length: float = 240.0
## Идут ли часы. Снимаем на паузу/в катсценах при необходимости.
var running: bool = true

## День завершён, ждём подтверждения итогов (begin_new_day). На это время часы стоят.
var _sleeping: bool = false


func _process(delta: float) -> void:
	if not running or _sleeping:
		return
	time_of_day += delta / maxf(day_length, 1.0)
	# Прошли полночь — сутки заворачиваются и день МОЛЧА сменяется (часы и календарь идут дальше, без
	# экрана итогов). Итоги показываем ТОЛЬКО когда легли спать в кровать (request_sleep).
	if time_of_day >= 1.0:
		time_of_day -= 1.0
		_advance_day_silent()
	time_changed.emit(time_of_day)


## Лечь спать (кровать): завершает текущий день и просит показать итоги. Повторные вызовы гасим.
func request_sleep() -> void:
	if _sleeping:
		return
	_sleeping = true
	day_ended.emit(day_index)


## Подтвердить итоги и проснуться в 06:00. Сон = прыжок вперёд к утру (MORNING_T). День прибавляем
## ТОЛЬКО если прыжок переваливает за полночь (время было ≥ 06:00). Если уже ранние часы (00:00–06:00,
## день уже сменился тихим перекатом в полночь) — просто досыпаем до 06:00 без лишнего +дня и без
## повторного сброса дневных счётчиков. Зовёт DayUI по кнопке «Продолжить».
func begin_new_day() -> void:
	if not _sleeping:
		return
	_sleeping = false
	if time_of_day >= MORNING_T:
		# Спим до утра СЛЕДУЮЩЕГО дня — прыжок через полночь: календарь +1, дневные счётчики сброс.
		day_index += 1
		Economy.start_new_day()
		new_day_started.emit(day_index)
	time_of_day = MORNING_T
	time_changed.emit(time_of_day)


## Тихая смена дня в полночь (без сна/итогов): только календарь и сброс дневных счётчиков.
func _advance_day_silent() -> void:
	day_index += 1
	Economy.start_new_day()
	new_day_started.emit(day_index)


## Строка часов для UI: полные сутки 00:00 → 24:00 раскладываем по time_of_day.
func clock_string() -> String:
	var h := clampf(time_of_day, 0.0, 1.0) * 24.0
	var hh := int(h) % 24
	var mm := int((h - floorf(h)) * 60.0)
	return "%02d:%02d" % [hh, mm]


## Снимок для сохранения (SaveManager): переносим только номер дня (время начинаем со свежего утра).
func to_dict() -> Dictionary:
	return {"day_index": day_index}


## Восстановить из сохранения. Время сбрасываем на рассвет — новый запуск = начало дня.
func apply_dict(data: Dictionary) -> void:
	day_index = maxi(int(data.get("day_index", 1)), 1)
	time_of_day = MORNING_T
	_sleeping = false


## Сброс к началу новой игры: день 1, утро. Зовёт SaveManager.new_game.
func reset() -> void:
	day_index = 1
	time_of_day = MORNING_T
	_sleeping = false
	time_changed.emit(time_of_day)
