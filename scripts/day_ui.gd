extends CanvasLayer

## Интерфейс суток + МЕНЮ ПАУЗЫ (АВТОЗАГРУЗКА-СЦЕНА "DayUI"). Висит над всеми сценами:
##  • часы «День N — HH:MM» (всегда видны);
##  • экран итогов дня (по DayNight.day_ended) — пауза + «Продолжить»;
##  • меню по Esc — Продолжить / Сохранить / Новая игра / Загрузить (список по дате-времени).
##
## process_mode = ALWAYS (в сцене), чтобы и Esc, и кнопки работали во время паузы игры.

@onready var _clock: Label = $Clock

@onready var _summary: Control = $Summary
@onready var _title: Label = $Summary/Panel/Margin/VBox/Title
@onready var _body: Label = $Summary/Panel/Margin/VBox/Body
@onready var _continue: Button = $Summary/Panel/Margin/VBox/Continue

@onready var _menu: Control = $Menu
@onready var _status: Label = $Menu/Panel/Margin/VBox/Status

@onready var _loadlist: Control = $LoadList
@onready var _items: VBoxContainer = $LoadList/Panel/Margin/VBox/Scroll/Items

@onready var _confirm: Control = $Confirm
@onready var _confirm_msg: Label = $Confirm/Panel/Margin/VBox/Message
@onready var _confirm_yes: Button = $Confirm/Panel/Margin/VBox/Buttons/Yes

# Действие, которое выполнится по «Подтвердить», и куда вернуться по «Отмена» ("menu" / "loadlist").
var _pending: Callable = Callable()
var _confirm_back: String = "menu"


func _ready() -> void:
	DayNight.time_changed.connect(_on_time_changed)
	DayNight.new_day_started.connect(_on_new_day)
	DayNight.day_ended.connect(_on_day_ended)
	_continue.pressed.connect(_on_continue)
	$Menu/Panel/Margin/VBox/Resume.pressed.connect(_resume)
	$Menu/Panel/Margin/VBox/Save.pressed.connect(_on_save)
	$Menu/Panel/Margin/VBox/NewGame.pressed.connect(_on_new_game)
	$Menu/Panel/Margin/VBox/Load.pressed.connect(_show_loadlist)
	$LoadList/Panel/Margin/VBox/Back.pressed.connect(_back_to_menu)
	_confirm_yes.pressed.connect(_on_confirm_yes)
	$Confirm/Panel/Margin/VBox/Buttons/No.pressed.connect(_on_confirm_no)
	_summary.visible = false
	_menu.visible = false
	_loadlist.visible = false
	_confirm.visible = false
	_localize_static()
	_refresh_clock()


# Статичные подписи меню — через переводы (tr). Динамические тексты (итоги, часы, подпись сейва,
# сообщение подтверждения) выставляются в своих местах тоже через tr.
func _localize_static() -> void:
	_continue.text = tr("SUMMARY_CONTINUE")
	$Menu/Panel/Margin/VBox/Title.text = tr("MENU_TITLE")
	$Menu/Panel/Margin/VBox/Resume.text = tr("MENU_RESUME")
	$Menu/Panel/Margin/VBox/Save.text = tr("MENU_SAVE")
	$Menu/Panel/Margin/VBox/NewGame.text = tr("MENU_NEW_GAME")
	$Menu/Panel/Margin/VBox/Load.text = tr("MENU_LOAD")
	$LoadList/Panel/Margin/VBox/Title.text = tr("LOAD_TITLE")
	$LoadList/Panel/Margin/VBox/Back.text = tr("LOAD_BACK")
	$Confirm/Panel/Margin/VBox/Buttons/No.text = tr("CONFIRM_CANCEL")


# Esc: открыть/закрыть меню. Из списка загрузки — назад в меню. Во время итогов дня — игнор.
func _input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if _summary.visible:
		return
	if _confirm.visible:
		_on_confirm_no()
	elif _loadlist.visible:
		_back_to_menu()
	elif _menu.visible:
		_resume()
	else:
		_open_menu()
	get_viewport().set_input_as_handled()


# --- Часы / итоги дня ----------------------------------------------------------------------------

func _on_time_changed(_t: float) -> void:
	_refresh_clock()


func _on_new_day(_day_index: int) -> void:
	_refresh_clock()


func _refresh_clock() -> void:
	_clock.text = tr("HUD_DAY").format({"day": DayNight.day_index, "time": DayNight.clock_string()})


# Прицел игрока (группа "crosshair") прячем на паузе/в оверлеях и возвращаем при выходе в игру.
func _set_crosshair(show: bool) -> void:
	get_tree().call_group("crosshair", "set_visible", show)


func _on_day_ended(day_index: int) -> void:
	var sold := Economy.day_sold_kg
	var quota := Economy.daily_quota()
	var met := sold >= quota
	var met_str := tr("SUMMARY_MET_YES") if met else tr("SUMMARY_MET_NO")
	_title.text = tr("SUMMARY_TITLE").format({"day": day_index})
	_body.text = "\n".join([
		tr("SUMMARY_SOLD").format({"kg": "%d" % int(round(sold))}),
		tr("SUMMARY_QUOTA").format({"goal": "%d" % int(round(quota)), "status": met_str}),
		tr("SUMMARY_EARNED").format({"money": "%d" % int(round(Economy.day_earned))}),
		tr("SUMMARY_BALANCE").format({"money": "%d" % int(round(Economy.money))}),
	])
	_summary.visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_set_crosshair(false)


func _on_continue() -> void:
	_summary.visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_set_crosshair(true)
	DayNight.begin_new_day()


# --- Меню паузы ----------------------------------------------------------------------------------

func _open_menu() -> void:
	_status.text = ""
	_loadlist.visible = false
	_menu.visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_set_crosshair(false)


func _resume() -> void:
	_menu.visible = false
	_loadlist.visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_set_crosshair(true)


func _on_save() -> void:
	var label := SaveManager.quick_save()
	_status.text = tr("SAVE_DONE").format({"time": label}) if label != "" else tr("SAVE_FAILED")


func _on_new_game() -> void:
	_ask_confirm(
		tr("CONFIRM_NEW_Q") + "\n" + tr("CONFIRM_WARN"),
		tr("CONFIRM_NEW_YES"), "menu",
		func() -> void:
			SaveManager.new_game()
			_reload_world())


func _show_loadlist() -> void:
	_menu.visible = false
	_loadlist.visible = true
	_populate_saves()


func _back_to_menu() -> void:
	_loadlist.visible = false
	_menu.visible = true


# Перестраиваем список сохранений: кнопка на каждый файл (подпись = дата-время), новейшие сверху.
func _populate_saves() -> void:
	for c in _items.get_children():
		c.queue_free()
	var saves := SaveManager.list_saves()
	if saves.is_empty():
		var empty := Label.new()
		empty.text = tr("LOAD_EMPTY")
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_items.add_child(empty)
		return
	for s in saves:
		var b := Button.new()
		var label := str(s["label"])
		b.text = tr("SAVE_AUTOSAVE").format({"time": label}) if bool(s["auto"]) else label
		var path := str(s["path"])
		b.pressed.connect(func() -> void: _load(path))
		_items.add_child(b)


func _load(path: String) -> void:
	_ask_confirm(
		tr("CONFIRM_LOAD_Q") + "\n" + tr("CONFIRM_WARN"),
		tr("CONFIRM_LOAD_YES"), "loadlist",
		func() -> void:
			if SaveManager.load_path(path):
				_reload_world())


# --- Диалог подтверждения ------------------------------------------------------------------------

# Показать вопрос. yes_text — подпись кнопки подтверждения; back — куда вернуть по «Отмена».
func _ask_confirm(message: String, yes_text: String, back: String, on_yes: Callable) -> void:
	_pending = on_yes
	_confirm_back = back
	_confirm_msg.text = message
	_confirm_yes.text = yes_text
	_menu.visible = false
	_loadlist.visible = false
	_confirm.visible = true


func _on_confirm_yes() -> void:
	var action := _pending
	_pending = Callable()
	_confirm.visible = false
	if action.is_valid():
		action.call()


func _on_confirm_no() -> void:
	_pending = Callable()
	_confirm.visible = false
	if _confirm_back == "loadlist":
		_show_loadlist()
	else:
		_menu.visible = true


# Применили состояние в синглтоны — обновляем мир перезагрузкой текущей сцены (деревья/брёвна свежие).
func _reload_world() -> void:
	_menu.visible = false
	_loadlist.visible = false
	_summary.visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_set_crosshair(true)
	get_tree().call_deferred("reload_current_scene")
