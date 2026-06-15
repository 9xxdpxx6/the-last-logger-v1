extends Node

## Сохранение/загрузка прогресса (АВТОЗАГРУЗКА "SaveManager"). Каждое сохранение — отдельный JSON-файл
## в user://saves/, подписанный датой-временем до секунды. Ручное «Сохранить» из меню создаёт новый файл;
## сон делает автосейв (отдельный файл autosave.json, перезаписывается). На старте грузим САМОЕ свежее.
##
## Подключение: [autoload] SaveManager="*res://scripts/save_manager.gd" (ПОСЛЕ Economy и DayNight).

const SAVE_DIR := "user://saves"
const SAVE_EXT := ".json"
const AUTOSAVE_NAME := "autosave"
const SAVE_VERSION := 1

## Апгрейды игрока (id → уровень) — задел под прокачку, сохраняется/грузится как есть.
var upgrades: Dictionary = {}
## Прочие глобальные данные на будущее (фазы акта, флаги событий) — переживут перезапуск.
var globals: Dictionary = {}


func _ready() -> void:
	_ensure_dir()
	load_latest()
	DayNight.new_day_started.connect(_on_new_day)


func _on_new_day(_day_index: int) -> void:
	autosave()


func _ensure_dir() -> void:
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		DirAccess.make_dir_recursive_absolute(SAVE_DIR)


# Текущая дата-время как человекочитаемая подпись «ГГГГ-ММ-ДД ЧЧ:ММ:СС».
func _now_label() -> String:
	var t := Time.get_datetime_dict_from_system()
	return "%04d-%02d-%02d %02d:%02d:%02d" % [t.year, t.month, t.day, t.hour, t.minute, t.second]


# То же время для ИМЕНИ файла (без двоеточий/пробелов — они нелегальны в путях).
func _now_filestamp() -> String:
	var t := Time.get_datetime_dict_from_system()
	return "%04d-%02d-%02d_%02d-%02d-%02d" % [t.year, t.month, t.day, t.hour, t.minute, t.second]


# Слепок состояния. В файл кладём ЧИСТУЮ дату (saved_label) + время (saved_at) для сортировки и флаг
# auto (автосейв ли) — подпись для UI строится переводом на стороне меню, а не хранится готовой строкой.
func _collect(label: String, auto: bool) -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"saved_at": Time.get_unix_time_from_system(),
		"saved_label": label,
		"auto": auto,
		"day": DayNight.to_dict(),
		"economy": Economy.to_dict(),
		"upgrades": upgrades,
		"globals": globals,
	}


func _write(path: String, data: Dictionary) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("SaveManager: не открыть %s на запись" % path)
		return false
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	return true


func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var text := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


## Ручное сохранение в НОВЫЙ файл с меткой времени. Возвращает дату-время («ГГГГ-ММ-ДД ЧЧ:ММ:СС») или "".
func quick_save() -> String:
	_ensure_dir()
	var label := _now_label()
	var path := "%s/save_%s%s" % [SAVE_DIR, _now_filestamp(), SAVE_EXT]
	return label if _write(path, _collect(label, false)) else ""


## Автосохранение (после сна) — отдельный файл, перезаписывается. В списке UI помечает как «Автосейв».
func autosave() -> void:
	_ensure_dir()
	_write("%s/%s%s" % [SAVE_DIR, AUTOSAVE_NAME, SAVE_EXT], _collect(_now_label(), true))


## Список сохранений, НОВЕЙШИЕ сверху: массив словарей {path, label (дата-время), auto}.
func list_saves() -> Array:
	var out: Array = []
	var d := DirAccess.open(SAVE_DIR)
	if d == null:
		return out
	for fn in d.get_files():
		if not fn.ends_with(SAVE_EXT):
			continue
		var path := "%s/%s" % [SAVE_DIR, fn]
		var meta := _read(path)
		if meta.is_empty():
			continue
		out.append({
			"path": path,
			"label": str(meta.get("saved_label", fn)),
			"auto": bool(meta.get("auto", false)),
			"at": float(meta.get("saved_at", 0.0)),
		})
	out.sort_custom(func(a, b): return a["at"] > b["at"])
	return out


## Загрузить самое свежее сохранение (старт игры). true — загрузили, false — сохранений нет.
func load_latest() -> bool:
	var saves := list_saves()
	if saves.is_empty():
		return false
	return load_path(saves[0]["path"])


## Загрузить конкретный файл. Раскладывает данные по синглтонам (мир обновит перезагрузка сцены в DayUI).
func load_path(path: String) -> bool:
	var data := _read(path)
	if data.is_empty():
		return false
	DayNight.apply_dict(data.get("day", {}))
	Economy.apply_dict(data.get("economy", {}))
	upgrades = data.get("upgrades", {})
	globals = data.get("globals", {})
	return true


## Новая игра: сброс глобального состояния к началу (сцену перезагружает DayUI). Сохранения НЕ трогаем.
func new_game() -> void:
	upgrades = {}
	globals = {}
	Economy.reset_all()
	DayNight.reset()
