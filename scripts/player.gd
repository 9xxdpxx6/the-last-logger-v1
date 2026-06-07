extends CharacterBody3D

## Скорость обычной ходьбы, м/с.
@export var walk_speed: float = 4.0
## Во сколько раз быстрее игрок двигается при беге (Shift).
@export var run_multiplier: float = 1.6
## Чувствительность мыши (радиан на пиксель движения).
@export var mouse_sensitivity: float = 0.003
## Ограничение наклона взгляда вверх/вниз, в градусах.
@export var max_look_angle: float = 89.0
## Высота прыжка в метрах. Скорость толчка считается из неё и гравитации.
@export var jump_height: float = 1.2
## Управление в воздухе: 0 — нет (полная инерция), 1 — почти как на земле.
@export var air_control: float = 0.5
## Сила (Н), с которой игрок давит на физтела при контакте — по сути вес лесоруба.
## Прикладывается честно в точку под ногой, поэтому хватает реалистичного значения
## (~вес тела). Больше — резче перевешивает; слишком много швыряет бревно.
@export var push_force: float = 2000.0
## Высота (м), на которую игрок САМ всходит без прыжка: камни/брёвна/низкие пеньки ниже
## этого не становятся стеной — игрок «переступает» через них.
@export var step_height: float = 0.4
## Высота переступа именно через ТЯЖЁЛОЕ бревно (тяжелее push_log_capacity — сдвинуть нельзя).
## Лежачее бревно толще обычного уступа (верх ~два радиуса), поэтому через него разрешаем
## всходить выше, чем через камень/пень — иначе тяжёлое бревно становится глухой стеной.
@export var log_step_height: float = 0.75
## Скорость «сглаживания» переступа камерой (1/с). Сам переступ — это телепорт тела вверх за один
## кадр; чтобы он не выглядел как рывок-склейка кадров (#2), камеру в тот же миг опускаем на
## высоту шага и плавно возвращаем к нулю с этой скоростью. Больше — быстрее «довсплывает» камера
## (резче), меньше — мягче, но дольше «приседание». 14 — почти незаметный плавный подъём.
@export var step_smooth_speed: float = 18.0
## Зазор для гибкого степ-апа (м): сколько места ДОЛЖНО быть перед катящимся бревном, чтобы считать,
## что ему есть куда откатиться (#6). Если в сторону толчка ближе этого есть стена/другое бревно —
## бревну катиться некуда, и игрок переступает через него, а не толкает впустую. Больше — раньше
## «сдаёмся» и лезем; меньше — дольше пытаемся катить.
@export var log_roll_clearance: float = 0.6
## Перцептивный вес (кг), легче которого брёвна игрок РАСТАЛКИВАЕТ при ходьбе (по
## отображаемому весу). Тяжелее — стоят на месте. ~вес лесоруба.
@export var push_log_capacity: float = 90.0
## Ускорение расталкивания (1/с): жёсткость разгона бревна до целевой скорости. Больше —
## резче отлетает. Сила сама гаснет у целевой скорости, поэтому это не «постоянный толчок».
@export var push_log_accel: float = 8.0
## Максимальная скорость, до которой игрок РАЗГОНЯЕТ самое ЛЁГКОЕ бревно (м/с). Тяжёлое
## (ближе к push_log_capacity) разгоняется во столько раз медленнее, во сколько оно тяжелее —
## так разлёт явно зависит от веса: лёгкое улетает, тяжёлое еле ползёт.
@export var push_log_speed: float = 3.0
## Перцептивный вес (кг), до которого бревно ещё пинается, когда игрок подходит к нему С ТОРЦА
## (вдоль оси бревна). Легче — откатывается (но в end_shove_slowdown раз медленнее, чем сбоку);
## тяжелее — игрок ПЕРЕСТУПАЕТ через торец (#1). Сбоку порог другой — carry_capacity (что можно
## поднять): бревно «только под волок» (тяжелее carry_capacity) переступается и сбоку, и с торца.
@export var end_shove_capacity: float = 30.0
## Во сколько раз МЕДЛЕННЕЕ катится бревно, если пнуть его с ТОРЦА, а не сбоку (#1). Торец катить
## тяжелее, чем толкать бревно в бок: 3 — втрое медленнее.
@export var end_shove_slowdown: float = 3.0
## Порог «торцевого» подхода: |cos| между осью бревна и нормалью контакта. Выше — считаем, что
## игрок упёрся в ТОРЕЦ (подход вдоль бревна); ниже — в БОК. 0.55 ≈ конус ~57° вокруг оси.
@export var end_on_threshold: float = 0.55
## Отдача камеры вверх при попадании топором (градусы) — «весомость» удара.
@export var kick_pitch_deg: float = 1.2
## Случайный крен камеры при попадании (градусы, в обе стороны).
@export var kick_roll_deg: float = 0.5
## Случайный рывок камеры вбок при попадании (градусы) — разнообразит отдачу.
@export var kick_yaw_deg: float = 0.8
## Скорость возврата камеры после кика (1/с): больше — быстрее успокаивается.
@export var kick_recover_speed: float = 12.0
## Чувствительность «протяжки» топора мышью: сколько прицела даёт пиксель движения
## мыши, пока зажата ЛКМ. Двигаешь мышь поперёк дерева — топор бьёт в ту сторону.
@export var drag_sensitivity: float = 0.012
## Затухание накопленной протяжки (1/с): прицел от мыши плавно сбрасывается к нулю,
## так удар идёт по СВЕЖЕМУ движению руки, а не по всей истории.
@export var drag_decay: float = 5.0
## Импульс (Н·с), которым лезвие толкает свободные физтела при попадании. Скорость от
## него = импульс / масса: лёгкие поленья сдвигаются заметно, тяжёлые брёвна — еле-еле.
@export var axe_push_impulse: float = 112.0
## На сколько метров перед игроком кладётся брошенное бревно.
@export var drop_distance: float = 1.2

@export_group("Переноска брёвен")
## Грузоподъёмность (кг): бревно тяжелее поднять нельзя (позже добавим прогрессию).
@export var carry_capacity: float = 70.0
## Множитель скорости при бревне НА ПРЕДЕЛЕ грузоподъёмности (1 — без замедления).
## Лёгкое бревно почти не тормозит, у предела — вот настолько медленно.
@export var carry_min_speed_mult: float = 0.45
## Множитель ВЫСОТЫ ПРЫЖКА с бревном НА ПРЕДЕЛЕ грузоподъёмности (1 — прыгаем как налегке). Тяжёлый
## груз «прижимает к земле»: чем тяжелее бревно, тем ниже прыжок (как и скорость/ускорение, #1).
## Влияет на скорость толчка вверх: фактический подъём пропорционален квадрату множителя. 0.46 —
## груз давит на прыжок на ~10% слабее, чем 0.4 (просадка с 0.6 до 0.54 от полного хода).
@export var carry_jump_min_mult: float = 0.46
## Доля грузоподъёмности, ниже которой бревно несут на ЛЕВОМ плече (топор в правой руке),
## а на/выше — на правом плече (топор убран в карман до сброса).
@export var shoulder_left_fraction: float = 0.4
## Сила удара топором, когда бревно лежит на ЛЕВОМ плече (топор в правой руке) — рубим
## слабее, рука занята. 1 — без штрафа, 0.5 — вдвое слабее.
@export var carry_chop_power_mult: float = 0.5
## ЗАРЯД УДАРА (#4): чем дольше зажата ЛКМ (замах), тем сильнее удар — от 100% до chop_power_max.
## chop_charge_time — за сколько секунд удержания заряд доходит до максимума.
@export var chop_charge_time: float = 0.7
## Потолок силы удара от заряда (1.5 = +50% к базовой при полном замахе).
@export var chop_power_max: float = 1.5
## Множитель силы при БОКОВОМ ударе (A/D): косой руб слабее прямого. Масштабируется по |aim.x|.
@export var chop_side_power_mult: float = 0.9
## Множитель силы ПРЕРЫВАЮЩЕГО удара (#4): начали новый замах, пока прошлый ещё доигрывал (~90-95%)
## — спешка, удар слабее (0.87 ≈ 87% силы).
@export var chop_interrupt_power_mult: float = 0.87
## Предел ВОЛОКА (кг): бревно тяжелее грузоподъёмности, но не тяжелее этого, можно тащить
## волоком. Тяжелее — никак (позже: тачка/прокачка). 170.49: бревно, показывающее «170 кг»
## (т.е. вес ≤170.49 после округления), ещё тащится; «171 кг» (≥170.5) — уже слишком тяжёлое.
@export var drag_capacity: float = 170.49
## Множитель скорости волока для ЛЁГКОГО бревна (чуть тяжелее грузоподъёмности). Бежать нельзя.
## ВАЖНО: физика волока сама ограничивает скорость ~1.3 м/с, поэтому реально различие лёгкого
## и тяжёлого задаёт НИЖНИЙ множитель — чем он меньше, тем заметнее тяжёлое медленнее.
@export var drag_speed_mult: float = 0.75
## Множитель скорости волока для САМОГО ТЯЖЁЛОГО бревна (у предела волока). Между лёгким и
## тяжёлым скорость интерполируется по массе — тяжёлое тащить ощутимо медленнее.
@export var drag_speed_heavy_mult: float = 0.24
## Множитель скорости, когда игрок ТОЛКАЕТ бревно перед собой (идёт на него). Толкать почти
## нельзя — тащат назад/вбок. 0.04 = в 25 раз медленнее, чем тащить.
@export var drag_push_speed_mult: float = 0.04
## На сколько метров ПЕРЕД игроком «рука» держит схваченный торец бревна.
@export var drag_grab_distance: float = 0.8
## Высота (м), на которую «рука» поднимает схваченный торец над землёй — вид «в руке».
## Вдавливание дальнего конца в землю лечит НЕ это, а точка приложения силы (см. drag_pull).
@export var drag_grab_lift: float = 1.3
## Предел длины рук (м): дальше этого схваченный торец от точки рук не отпускается (поводок). Это же
## задаёт «свободное хождение» при волоке — насколько игрок может отойти от бревна, прежде чем его
## подтянет назад (#5: уменьшено вдвое с 0.35 — поводок короче, бревно держится плотнее).
@export var drag_arm_reach: float = 0.175
## «Сцепление» дальнего конца с землёй при волоке: гасит ГОРИЗОНТАЛЬНУЮ скорость лежащего
## на земле торца. Больше — дальний конец сильнее «якорится»: при тяге вбок бревно поворачивает
## ПО РАДИУСУ (ближний конец в руках водит, дальний почти стоит), а не едет целиком.
@export var drag_tail_grip: float = 8.0
## Жёсткость «руки» при волоке: больше — резче подтягивает торец к точке у рук. Должна быть
## достаточной, чтобы тяга пересиливала трение лежащего конца (иначе бревно «не едет» назад).
@export var drag_stiffness: float = 24.0
## Гашение в «руке»: гасит рывки/раскачку торца. Больше — спокойнее, инертнее тянется.
@export var drag_damping: float = 6.0
## Потолок тянущей силы (Н) — чтобы тяжёлое бревно не «выстреливало» и оставалось инертным.
@export var drag_max_force: float = 20000.0
## Замедление поворота камеры при волоке (инертнее): 1 — как обычно, 0.8 — на 20% медленнее.
@export var drag_look_mult: float = 0.8
## Ограничение поворота тела при волоке в каждую сторону от исходного направления (градусы):
## ~82° → обзор ~164°, обойти вокруг бревна нельзя (надо бросить и взять заново).
@export var drag_yaw_limit: float = 82.0

@export_group("Тачка")
## Множитель скорости ходьбы с ПУСТОЙ тачкой (бежать нельзя). Близко к обычной ходьбе —
## пустая тачка почти не мешает.
@export var barrow_speed_mult: float = 1.05
## Множитель скорости с тачкой НА ПРЕДЕЛЕ загрузки (max_load_kg). Между пустой и полной
## скорость интерполируется по доле груза — гружёная идёт ощутимо медленнее.
@export var barrow_speed_loaded_mult: float = 0.46
## Множитель скорости при ПЕРЕГРУЗЕ (груз > max_load_kg, #2): тачка еле толкается, но видимо едет.
@export var barrow_overload_mult: float = 0.08
## Скорость ПОВОРОТА тачки клавишами A/D (рад/с). A/D крутят ТАЧКУ вокруг оси её колёс (и стоя, и
## на ходу), игрок при этом обходит ось по дуге, держась за ручки. W/S — ход вперёд/назад.
@export var barrow_turn_speed: float = 2.0
## Ограничение обзора КАМЕРЫ при тачке в руках (градусы в каждую сторону от носа тачки). Камера
## свободно осматривается в этом секторе, но НА ход тачки это НЕ влияет — она едет ТОЛЬКО по WASD
## и за взглядом не тащится (#5). По умолчанию 82° → обзор ~164°.
@export var barrow_yaw_limit: float = 82.0
## СВОБОДНЫЙ ХОД тачки (м): насколько игрок может отстать от точки за ручками, прежде чем его
## подтянет. Чем меньше — тем плотнее игрок «приклеен» к ручкам (#4). 0.04 — еле заметный люфт.
## ИМЕННО ЭТО значение крути в Инспекторе игрока (группа «Тачка»), чтобы менять свободный ход.
@export var barrow_play: float = 0.04
## АВТО-ОТПУСКАНИЕ над обрывом (#4): на сколько ВПЕРЁД от ЦЕНТРА тачки щупаем землю (м). Примерно у
## переднего свеса кузова (~0.5): отпускаем, когда за край заходит НОС тачки (а не когда вся тачка уже
## свисает — было слишком поздно; и не когда щуп далеко за носом — было слишком рано, #4). Это среднее.
@export var barrow_cliff_probe: float = 0.5
## Глубина (м), глубже которой «нет земли под носом» считается ОБРЫВОМ. Пока тачку держат, она не
## может упасть сама (её держат ровно), поэтому ловим обрыв заранее — лучом вниз перед носом. Нашли
## пустоту глубже этого — отпускаем тачку (летит сама), игрок остаётся на краю. Больше нормальной
## ступеньки (~0.4), чтобы спуск с бордюра не отпускал тачку, но меньше настоящего обрыва. Меряется
## ВНИЗ от уровня колёс: земля глубже этого под носом = обрыв.
@export var barrow_cliff_drop: float = 0.8
## АВТО-ОТПУСКАНИЕ, когда игрок ОТСТАЛ от тачки (#2). Если тачка заехала на уступ (climb-assist), а
## игрок упёрся в него и не перелез — тачка продолжала ехать по WASD, «убегая» от игрока (он сам без
## степапа в режиме тачки), и она оказывалась «на дистанционном управлении». Теперь: если разрыв
## игрок↔ручки (по горизонтали, сверх свободного хода) превысил это — тачку отпускаем (игрок встаёт).
## Должно быть заметно больше grab_distance+barrow_play, чтобы обычная езда/доворот не отпускали.
@export var barrow_max_gap: float = 0.7

@export_group("Здоровье")
## Максимум HP. Урон от брёвен считается как масса × скорость × damage_scale (в дереве).
@export var max_hp: float = 100.0

var _jump_velocity: float = 0.0
## Несомое бревно (или null). Несёшь — медленнее ходишь, тяжёлое — сильнее.
var _carried: FallingLog = null
## Текущий множитель скорости от веса в руках (1 — налегке).
var _carry_speed_mult: float = 1.0
## Текущий множитель высоты прыжка от веса в руках (1 — налегке).
var _carry_jump_mult: float = 1.0
## Бревно, которое тащим волоком (или null). Пока тащим — медленно, без бега, без рубки.
var _dragged: FallingLog = null
## Множитель скорости текущего волока (зависит от массы бревна; считается в _start_drag).
var _drag_speed_mult: float = 1.0
## Тачка, которую сейчас толкаем (или null). Пока толкаем — медленнее, без бега/прыжка, топор убран.
var _barrow: Wheelbarrow = null
## Направление тела (yaw, рад) в момент начала волока — от него считаем ограничение поворота.
var _drag_yaw_center: float = 0.0
## Free-look камеры при тачке (yaw-смещение, рад) ОТНОСИТЕЛЬНО носа тачки. Мышь крутит ТОЛЬКО его
## (в пределах ±barrow_yaw_limit), на ход тачки не влияет (#5). Тело при этом смотрит по носу тачки.
var _barrow_cam_yaw: float = 0.0
## Базовая ЛОКАЛЬНАЯ позиция камеры относительно origin игрока — запоминаем в _ready, от неё считаем
## сглаживание переступа: camera.position = база + _step_offset.
var _cam_base: Vector3 = Vector3.ZERO
## Накопленное смещение камеры для сглаживания степапа (м, в ЛОКАЛЕ тела): при телепорте тела на
## уступ прибавляем сюда смещение, ОБРАТНОЕ прыжку (камера на миг остаётся там, где была), затем
## плавно гасим к нулю в _process. Сглаживаем ПОЛНЫЙ 3D-рывок (и вверх, и вперёд): так подъём
## читается как мягкое «всплытие», а не дёрганая склейка кадров (#8 — вертикаль-только дёргалась).
var _step_offset: Vector3 = Vector3.ZERO
## Позиция игрока и желаемая гор. скорость ПЕРЕД move_and_slide этого кадра — для анти-спидхака
## степ-апа (#2): если игрок и так свободно проехал вперёд (на верху бревна), он НЕ застрял и
## переступать не нужно; степ-ап включаем только при реальном упоре. См. _snap_up_step.
var _pre_move_pos: Vector3 = Vector3.ZERO
var _wish_speed: float = 0.0
## Текущее здоровье. Падает от ударов брёвен; на нуле — смерть (перезапуск сцены).
var _hp: float = 100.0
## Топор убран (несём тяжёлое бревно на правом плече) — рубить нельзя.
var _axe_stowed: bool = false
## Наклон взгляда вверх/вниз (рад). Храним отдельно, чтобы кик камеры можно было
## накладывать поверх, не ломая ограничение обзора.
var _look_pitch: float = 0.0
## Текущая отдача камеры (рад): x — тангаж, y — рыскание, z — крен. Затухает к нулю.
var _kick: Vector3 = Vector3.ZERO
## Прицел последнего замаха (x: лево/право, y: верх/низ) — для варьирования кика.
var _last_aim: Vector2 = Vector2.ZERO
## ЛКМ зажата — топор в замахе, целимся. Удар будет на отпускании.
var _charging: bool = false
## Момент начала замаха (сек) — по нему считаем длительность удержания → силу удара (#4).
var _charge_start_s: float = 0.0
## Текущий замах начат ПОВЕРХ недоигравшего удара (прерывающий, спешка) → удар слабее (#4).
var _chop_charging_interrupted: bool = false
## Множитель силы текущего удара (заряд × бок × прерывание). Применяется в _on_axe_impact (#4).
var _chop_power_mult: float = 1.0
## Недавнее движение мыши (x: лево/право, y: низ/верх) — задаёт угол/плоскость удара
## на отпускании. Копится во время замаха, плавно затухает → важно движение У САМОГО
## отпускания («двинул камеру и ударил»).
var _aim_drag: Vector2 = Vector2.ZERO

@onready var camera: Camera3D = $Camera3D
## «Руки»: второй коллайдер игрока, занимающий зазор между капсулой и схваченным торцом бревна.
## Включён ТОЛЬКО во время волока — иначе игрок был бы «шире» при обычной ходьбе. Лежит вдоль -Z
## на высоте хвата; бревно (слой 8) его не видит, препятствия (1|4|16) — да, поэтому в зазор «рук»
## больше ничего не заезжает: игрок упрётся, как если бы держал бревно настоящими руками.
@onready var arm_col: CollisionShape3D = $ArmCollision
## Тот же приём, что и arm_col, но под ТАЧКУ: коллайдер занимает зазор между капсулой и ручками
## (ниже и короче, чем у бревна — ручки на grab_height). Включён только пока тачку держим.
@onready var barrow_arm_col: CollisionShape3D = $BarrowArmCollision
@onready var chop_ray: ShapeCast3D = $Camera3D/ChopRay
@onready var axe: Node3D = $Camera3D/Axe
@onready var prompt: RichTextLabel = $HUD/Prompt
@onready var hp_bar: ProgressBar = $HUD/HpBar
@onready var hp_label: Label = $HUD/HpBar/HpLabel
## Меши конечностей для простой код-анимации (#9.3): руки тянутся к тачке/бревну при волоке/
## толкании, ноги шагают при ходьбе. Тело скрыто от камеры от 1-го лица (cast_shadow =
## shadows_only), поэтому анимацию видно по ТЕНИ игрока (и через фрикам, если вернуть видимость).
@onready var _model: Node3D = $Model
@onready var _arm_l: Node3D = $Model/ArmL
@onready var _arm_r: Node3D = $Model/ArmR
@onready var _leg_l: Node3D = $Model/LegL
@onready var _leg_r: Node3D = $Model/LegR
## База позиции тела — от неё гасим переступ так же, как камеру (#1: иначе торс «прыгал» в кадр).
var _model_base: Vector3 = Vector3.ZERO
## Фаза шагательного цикла (рад): растёт, пока игрок идёт по земле; задаёт качание ног/рук.
var _walk_phase: float = 0.0


func _ready() -> void:
	# Захватываем курсор при старте: мышь скрыта и привязана к окну.
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# v = sqrt(2*g*h): какая скорость вверх нужна, чтобы подняться на jump_height.
	var g: float = ProjectSettings.get_setting("physics/3d/default_gravity")
	_jump_velocity = sqrt(2.0 * g * jump_height)
	# Запоминаем «родную» локальную позицию камеры — от неё сглаживаем переступ (смещаем/возвращаем).
	_cam_base = camera.position
	_model_base = _model.position
	# Топор сообщает момент укуса лезвия — тогда и считаем попадание.
	axe.impact.connect(_on_axe_impact)
	# Полное здоровье на старте + сразу отрисовать полоску.
	_hp = max_hp
	_update_hp_bar()


## Вычесть урон по HP (зовётся бревном при ударе). На нуле — смерть.
func take_damage(amount: float) -> void:
	if amount <= 0.0 or _hp <= 0.0:
		return
	_hp = clampf(_hp - amount, 0.0, max_hp)
	_update_hp_bar()
	if _hp <= 0.0:
		_die()


func _die() -> void:
	print("СМЕРТЬ: HP кончились. Перезапуск сцены.")
	get_tree().reload_current_scene()


# Красная полоска HP слева снизу: заполнение по доле здоровья, цифра — целые HP.
func _update_hp_bar() -> void:
	if hp_bar:
		hp_bar.value = _hp / maxf(max_hp, 0.01) * 100.0
	if hp_label:
		hp_label.text = "%.0f" % _hp


func _unhandled_input(event: InputEvent) -> void:
	# ` (Ё, клавиша под Escape) — отладочная свободная камера: ставит сцену на паузу и даёт облететь
	# застывший мир (#3). Выход — повторное ` (его ловит сама free_cam). Эта проверка ВЫШЕ всего,
	# чтобы работала в любом режиме (несём бревно, тачка и т.д.).
	if event is InputEventKey and (event as InputEventKey).physical_keycode == KEY_QUOTELEFT \
			and event.pressed and not (event as InputEventKey).echo:
		_enter_free_cam()
		return

	# Обзор мышью работает только когда курсор захвачен.
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		# На волоке камера инертнее (медленнее) — обе руки заняты бревном (наклон взгляда тоже).
		var look_mult := drag_look_mult if _dragged != null else 1.0
		# С тачкой мышь НЕ поворачивает тело и НЕ двигает тачку: копим ТОЛЬКО free-look камеры
		# вокруг носа тачки, в пределах ±barrow_yaw_limit (#5). Тачка едет лишь по WASD.
		if _barrow != null:
			_barrow_cam_yaw -= event.relative.x * mouse_sensitivity
			var blim := deg_to_rad(barrow_yaw_limit)
			_barrow_cam_yaw = clampf(_barrow_cam_yaw, -blim, blim)
		else:
			# Поворот тела влево/вправо (по оси Y).
			rotate_y(-event.relative.x * mouse_sensitivity * look_mult)
			# На волоке нельзя крутиться вокруг бревна: держим тело в пределах ±drag_yaw_limit
			# от направления, с которым взяли (за спиной волочится бревно).
			if _dragged != null:
				var off := angle_difference(_drag_yaw_center, rotation.y)
				var lim := deg_to_rad(drag_yaw_limit)
				if absf(off) > lim:
					rotation.y = _drag_yaw_center + clampf(off, -lim, lim)
		# Наклон взгляда вверх/вниз копим отдельно — кик камеры наложим в _process.
		_look_pitch -= event.relative.y * mouse_sensitivity * look_mult
		_look_pitch = clampf(
			_look_pitch,
			deg_to_rad(-max_look_angle),
			deg_to_rad(max_look_angle)
		)
		# Во время замаха то же движение мыши копим как угол будущего удара: камера
		# крутится, А топор «прицеливается». Право/вверх мыши = право/вверх удара.
		if _charging:
			_aim_drag.x += event.relative.x * drag_sensitivity
			_aim_drag.y += -event.relative.y * drag_sensitivity

	# E — поднять бревно, на которое смотрим / бросить то, что несём.
	if event.is_action_pressed("interact") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_toggle_carry()

	# Esc отпускает курсор, клик по окну — снова захватывает.
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed \
			and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	# Рубка: зажал ЛКМ — топор в замах (целимся); отпустил — удар под текущим углом.
	if event.is_action_pressed("chop") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED \
			and not _axe_stowed and _dragged == null:
		# Прерывающий удар (#4): начали замах, пока прошлый ещё доигрывал. begin_windup вернёт false,
		# если удар ещё рано прерывать — тогда клик игнорируем (топор доигрывает удар, без дёрганья #2).
		var was_busy: bool = axe.is_busy()
		# Сторону взвода берём из текущего A/D (#2): если зажат A/D — топор сразу заносится для
		# горизонтального маха в нужную сторону, а не дёргается на месте при отпускании.
		var move0 := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		if axe.begin_windup(Vector2(move0.x, -move0.y)):
			_charging = true
			_chop_charging_interrupted = was_busy
			_charge_start_s = Time.get_ticks_msec() / 1000.0
			_aim_drag = Vector2.ZERO
	elif event.is_action_released("chop") and _charging:
		var move := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		var aim := Vector2(move.x, -move.y) + _aim_drag
		aim.x = clampf(aim.x, -1.0, 1.0)
		aim.y = clampf(aim.y, -1.0, 1.0)
		_last_aim = aim
		_charging = false
		_chop_power_mult = _compute_chop_power(aim)
		axe.release_strike(aim)


func _process(delta: float) -> void:
	# Отдача затухает к нулю; итоговый наклон камеры = взгляд + кик. С тачкой добавляем free-look
	# по рысканью (камера осматривается в секторе ±barrow_yaw_limit вокруг носа тачки, #5); без
	# тачки рысканье камеры = только кик (тело уже повёрнуто мышью).
	_kick = _kick.lerp(Vector3.ZERO, clampf(kick_recover_speed * delta, 0.0, 1.0))
	var cam_yaw := _barrow_cam_yaw if _barrow != null else 0.0
	camera.rotation = Vector3(_look_pitch + _kick.x, cam_yaw + _kick.y, _kick.z)

	# Сглаживание переступа: в момент телепорта тела на уступ камеру визуально оставили на месте
	# (накопили смещение, обратное прыжку — и вверх, и вперёд), теперь плавно гасим его к нулю. Так
	# подъём выглядит как мягкое всплытие, а не рывок-«склейка кадров» ни по высоте, ни вперёд (#4).
	_step_offset = _step_offset.lerp(Vector3.ZERO, clampf(step_smooth_speed * delta, 0.0, 1.0))
	camera.position = _cam_base + _step_offset
	# То же смещение даём ТЕЛУ: иначе при телепорте на уступ торс прыгает вверх вместе с телом, а
	# камеру держим внизу — и торс на пару кадров перекрывает пол-экрана (#1). Сдвигая Model на тот же
	# _step_offset, тело визуально остаётся на месте рядом с камерой и «всплывает» так же мягко.
	_model.position = _model_base + _step_offset

	# Прицел затухает, пока целимся — важно движение мыши У САМОГО отпускания.
	if _charging:
		_aim_drag = _aim_drag.lerp(Vector2.ZERO, clampf(drag_decay * delta, 0.0, 1.0))

	_animate_body(delta)
	_update_prompt()


# Простая код-анимация конечностей (#9.3, greybox). Своего AnimationPlayer/рига у игрока нет,
# поэтому крутим меши-примитивы напрямую вокруг локальной оси X:
#  • РУКИ при волоке/тачке — тянутся ВПЕРЁД (держат бревно/ручки), а не висят на месте;
#  • НОГИ при ходьбе — шагают «ножницами» (одна вперёд, другая назад) по синусу _walk_phase;
#  • РУКИ при ходьбе налегке — машут в противофазе ногам.
# Меши вращаются вокруг своего ЦЕНТРА (бедро/плечо не выделены) — для greybox этого хватает,
# движение читается. Тело скрыто от FP-камеры, так что эффект виден по ТЕНИ игрока на земле.
func _animate_body(delta: float) -> void:
	if _leg_l == null:
		return
	var hv := Vector3(velocity.x, 0.0, velocity.z)
	var moving := is_on_floor() and hv.length() > 0.5
	if moving:
		_walk_phase += delta * 9.0
	var swing := sin(_walk_phase) * deg_to_rad(22.0) if moving else 0.0
	var k := clampf(12.0 * delta, 0.0, 1.0)
	# Ноги «ножницами» (в противофазе друг другу); в покое плавно возвращаются к нулю.
	_leg_l.rotation.x = lerpf(_leg_l.rotation.x, swing, k)
	_leg_r.rotation.x = lerpf(_leg_r.rotation.x, -swing, k)
	# Руки НАВОДИМ на то, что держим, чтобы кисти реально сходились к предмету, а не висели рядом
	# в воздухе (#9c.3): тачка — каждая рука к своей рукоятке; бревно — обе руки в одну точку хвата;
	# топор — правая рука на рукоять вьюмодели (#9c.2). Свободные руки машут в противофазе ногам.
	if _barrow != null:
		var right := _barrow.global_transform.basis.x
		var g := _barrow.grab_point_world()
		_aim_arm(_arm_l, g - right * 0.32, k)
		_aim_arm(_arm_r, g + right * 0.32, k)
	elif _dragged != null:
		# Наводим обе руки на РЕАЛЬНЫЙ торец бревна (grab_point_world), а не на вычисленную точку
		# хвата выше пояса (#9e.2): иначе кисти висели заметно выше бревна. Так руки сходятся к месту,
		# где бревно действительно лежит.
		var g := _dragged.grab_point_world()
		var right := global_transform.basis.x
		_aim_arm(_arm_l, g - right * 0.18, k)
		_aim_arm(_arm_r, g + right * 0.18, k)
	elif axe.visible:
		# Топор — вьюмодель в пространстве камеры (его удар сходится в перекрестье, #9g). Чтобы он
		# выглядел зажатым в руке и рука махала вместе с ним, КАЖДЫЙ кадр наводим правую руку на
		# топор (его origin = низ рукояти): кисть тянется к рукояти, а когда топор уходит в удар —
		# рука следует за ним. k=1 (без сглаживания), чтобы рука не отставала от быстрого маха.
		_aim_arm(_arm_r, axe.global_position, 1.0)
		_swing_arm(_arm_l, -swing, k)
	else:
		_swing_arm(_arm_l, -swing, k)
		_swing_arm(_arm_r, swing, k)


# Наводим руку-меш так, чтобы её «низ» (локальный −Y, конец-кисть) указывал на точку target в мире.
# Рука вращается вокруг плеча (центра меша): наклон вперёд/вниз (X) + разворот вбок (Y). Этого хватает,
# чтобы кисти сводились к одному бревну и тянулись к разнесённым ручкам тачки. target переводим в локаль
# узла Model (родитель руки), считаем направление от плеча и раскладываем на углы тангажа/рысканья.
func _aim_arm(arm: Node3D, target_world: Vector3, k: float) -> void:
	var model := arm.get_parent() as Node3D
	var t_local := model.global_transform.affine_inverse() * target_world
	var d := t_local - arm.position
	if d.length() < 0.01:
		return
	d = d.normalized()
	var pitch := acos(clampf(-d.y, -1.0, 1.0))
	var yaw := atan2(-d.x, -d.z)
	arm.rotation.x = lerp_angle(arm.rotation.x, pitch, k)
	arm.rotation.y = lerp_angle(arm.rotation.y, yaw, k)
	arm.rotation.z = lerp_angle(arm.rotation.z, 0.0, k)


# Качание свободной руки вперёд/назад вокруг плеча (X) с плавным обнулением бокового разворота/крена.
func _swing_arm(arm: Node3D, angle: float, k: float) -> void:
	arm.rotation.x = lerp_angle(arm.rotation.x, angle, k)
	arm.rotation.y = lerp_angle(arm.rotation.y, 0.0, k)
	arm.rotation.z = lerp_angle(arm.rotation.z, 0.0, k)


# Плавно ставим руку в фиксированную позу (Эйлеры, рад) — для удержания топора и т.п.
func _set_arm(arm: Node3D, euler: Vector3, k: float) -> void:
	arm.rotation.x = lerp_angle(arm.rotation.x, euler.x, k)
	arm.rotation.y = lerp_angle(arm.rotation.y, euler.y, k)
	arm.rotation.z = lerp_angle(arm.rotation.z, euler.z, k)


# Подсказка под прицелом: что сделает E прямо сейчас. Тексты — через tr() (ключи в
# localization/translations.csv), {kg} подставляется форматированием — легко переводить.
func _update_prompt() -> void:
	if not prompt:
		return
	# Толкаем тачку — подсказка про то, что E поставит её. Вес НЕ показываем (тачка в руках —
	# загрузку видно, когда она НЕ в руках, при наведении на неё).
	if _barrow != null:
		_set_prompt(tr("PROMPT_BARROW_DROP"))
		return
	# Несём бревно: глядя на тачку (или на бревно в её кузове) — подсказка положить (с цветной
	# загрузкой); иначе — бросить.
	if _carried != null:
		var b := _aim_barrow_for_load()
		if b != null:
			var add := _carried.get_weight()
			# Бревно длиннее кузова (#2: торчало бы сквозь борта — E его не положит). Вместо веса
			# показываем КУРСИВОМ «Не влезет по размеру»: понятно, что мешает именно длина, а не вес.
			if not b.fits_length(_carried.get_length()):
				_set_prompt("[i]%s[/i]" % tr("PROMPT_BARROW_TOO_LONG"))
				return
			# По длине влезает: показываем загрузку. Цвет добавляемого веса — зелёный (влезает по весу)
			# или красный (перегруз по max_load_kg).
			var col := "44ff44" if b.can_load(add) else "ff4040"
			_set_prompt(tr("PROMPT_BARROW_LOAD").format({
				"cur": "%.0f" % b.current_load(),
				"add": "%.0f" % add,
				"col": col,
				"cap": "%.0f" % b.max_load_kg}))
			return
		_set_prompt(tr("PROMPT_DROP").format({"kg": "%.0f" % _carried.get_weight()}))
		return
	if _dragged != null:
		_set_prompt(tr("PROMPT_DROP").format({"kg": "%.0f" % _dragged.get_weight()}))
		return
	# Свободные руки. Навёлся на тачку — взять/толкать (с грузом показываем сколько лежит/влезет);
	# навёлся на бревно — поднять/тащить.
	var aim := _aim_target()
	if aim.get("type") == "barrow":
		var ab := aim["barrow"] as Wheelbarrow
		var load := ab.current_load()
		if load > 0.5:
			# Перегруз — показываем текущий вес КРАСНЫМ (#1): сразу видно, что тачка набита сверх нормы.
			var kg_str := "%.0f" % load
			if ab.is_overloaded():
				kg_str = "[color=#ff4040]%s[/color]" % kg_str
			_set_prompt(tr("PROMPT_BARROW_GRAB_LOADED").format(
				{"kg": kg_str, "cap": "%.0f" % ab.max_load_kg}))
		else:
			_set_prompt(tr("PROMPT_BARROW_GRAB"))
		return
	if aim.get("type") != "log":
		_set_prompt("")
		return
	var log := aim["log"] as FallingLog
	var w := log.get_weight()
	# Посильное — берём в руки; тяжелее, но в пределах волока — тащим; ещё тяжелее — никак.
	if w <= carry_capacity:
		_set_prompt(tr("PROMPT_PICKUP").format({"kg": "%.0f" % w}))
	elif w <= drag_capacity:
		_set_prompt(tr("PROMPT_DRAG").format({"kg": "%.0f" % w}))
	else:
		_set_prompt(tr("PROMPT_TOO_HEAVY").format({"kg": "%.0f" % w}))


# Текст подсказки в RichTextLabel по центру. Центрируем bbcode-тегом [center] (у RichTextLabel
# нет horizontal_alignment, как у Label). Пустую строку ставим без обёртки.
func _set_prompt(text: String) -> void:
	prompt.text = "[center]%s[/center]" % text if text != "" else ""


# Бревно под прицелом (в группе pickup_log) или null. force — пересчитать луч сейчас.
# Бревно, на котором СВЕРХУ что-то лежит (не «верхнее»), пропускаем: его нельзя ни поднять, ни
# тащить, пока не убрать верхний кусок. Если под прицелом есть и оно само сверху — вернём его.
func _look_pickup_log(force: bool) -> FallingLog:
	if force:
		chop_ray.force_shapecast_update()
	for i in chop_ray.get_collision_count():
		var c := chop_ray.get_collider(i)
		if c is FallingLog and (c as Node).is_in_group("pickup_log"):
			if (c as FallingLog).is_covered():
				continue
			return c as FallingLog
	return null


# E: несём/тащим — бросаем; иначе смотрим на бревно — берём в руки или тащим волоком.
func _toggle_carry() -> void:
	# Один пересчёт луча на всё контекстное E (и бревно, и тачка под прицелом — свежие).
	chop_ray.force_shapecast_update()
	# Толкаем тачку — ставим её.
	if _barrow != null:
		_stop_barrow()
		return
	# Несём бревно: глядя на тачку (или на бревно в её кузове) — кладём в кузов (если влезет по
	# весу); иначе бросаем на землю.
	if _carried != null:
		var lb := _aim_barrow_for_load()
		if lb != null:
			# Грузим, если влезает ПО ДЛИНЕ. Перегруз по ВЕСУ теперь разрешён (#2): тачку можно набить
			# сверх max_load_kg, но тогда она еле толкается (barrow_overload_mult в _drive_barrow).
			# Слишком длинное бревно по-прежнему не лезет (торчало бы сквозь борта).
			if lb.fits_length(_carried.get_length()):
				_load_into_barrow(lb)
			return
		_drop_carried()
		return
	# Тащим волоком — отпускаем.
	if _dragged != null:
		_stop_drag()
		return
	# Свободные руки. Навёлся на тачку — берёмся за неё; навёлся на бревно — поднимаем/тащим.
	var aim := _aim_target()
	if aim.get("type") == "barrow":
		_start_barrow(aim["barrow"])
		return
	if aim.get("type") != "log":
		return
	var log := aim["log"] as FallingLog
	var weight := log.get_weight()
	if weight <= carry_capacity:
		_start_carry(log, weight)
	elif weight <= drag_capacity:
		_start_drag(log)
	# Тяжелее предела волока — только тачкой (несколько раз поднести руками и сложить нельзя —
	# тяжёлое бревно само в руки не идёт; пока остаётся «никак», прокачку добавим позже).


# Берём бревно в руки на плечо. Лёгкое (< доли предела) — на левое, топор в правой руке;
# тяжёлое — на правое, топор убираем (рубить нельзя, пока несём).
func _start_carry(log: FallingLog, weight: float) -> void:
	var on_left := weight < carry_capacity * shoulder_left_fraction
	_axe_stowed = not on_left
	axe.visible = on_left
	_carried = log
	log.pick_up(camera, _shoulder_pose(on_left))
	_carry_speed_mult = _carry_speed_for(weight)
	_carry_jump_mult = _carry_jump_for(weight)


# Берём бревно на волок: оно остаётся на земле, мы тянем ближний торец. Обе руки заняты —
# топор убираем; скорость падает, бежать нельзя (см. _physics_process и _update_drag).
func _start_drag(log: FallingLog) -> void:
	_dragged = log
	_axe_stowed = true
	axe.visible = false
	# Включаем коллайдер «рук»: пока тащим, зазор перед игроком физически занят (см. arm_col).
	arm_col.disabled = false
	# begin_drag сам выбирает БЛИЖНИЙ к игроку торец как точку хвата.
	log.begin_drag(global_position)
	# Скорость волока зависит от массы: лёгкое — почти как ходьба, у предела — заметно медленнее.
	var t := clampf(log.get_weight() / maxf(drag_capacity, 0.01), 0.0, 1.0)
	_drag_speed_mult = lerpf(drag_speed_mult, drag_speed_heavy_mult, t)
	# Единая поза хвата: где бы ни взяли — встаём у БЛИЖНЕГО торца и разворачиваемся ВДОЛЬ бревна
	# (смотрим на него, дальний конец впереди). Так не нужно куче анимаций «взять сбоку/посередине».
	var near := log.grab_point_world()
	var far := log.tail_point_world()
	var dir := far - near
	dir.y = 0.0
	if dir.length() > 0.01:
		dir = dir.normalized()
		# forward игрока (-Z) направляем ВДОЛЬ бревна к дальнему концу.
		rotation.y = atan2(-dir.x, -dir.z)
		# Встаём так, чтобы ближний торец был перед нами на длину рук.
		global_position = Vector3(
			near.x - dir.x * drag_grab_distance,
			global_position.y,
			near.z - dir.z * drag_grab_distance
		)
	# От этого направления ограничиваем поворот камеры при волоке.
	_drag_yaw_center = rotation.y


# Отпускаем волок: бревно снова просто лежит, топор возвращаем в руку.
func _stop_drag() -> void:
	_dragged.end_drag()
	_dragged = null
	_axe_stowed = false
	axe.visible = true
	# Бросили бревно — руки свободны, коллайдер «рук» убираем (иначе мешал бы обычной ходьбе).
	arm_col.disabled = true


# Что под прицелом прямо сейчас (ближайшее): тачка ИЛИ верхнее посильное бревно. Возвращаем
# {"type":"barrow","barrow":...} или {"type":"log","log":...} или {} — по этому строится и
# подсказка, и действие E. Идём по попаданиям от ближнего к дальнему: что ближе, на то и навёл.
# Бревно учитываем только «непокрытое» (сверху ничего не лежит) — его и достаём из кузова.
func _aim_target() -> Dictionary:
	for i in chop_ray.get_collision_count():
		var c := chop_ray.get_collider(i)
		if c is Wheelbarrow:
			return {"type": "barrow", "barrow": c}
		if c is FallingLog and (c as Node).is_in_group("pickup_log"):
			var fl := c as FallingLog
			# «Накрытое» бревно (сверху лежит другой кусок) обычно брать нельзя — иначе тащили бы всю
			# кучу. НО лёгкое, влезающее в руку (≤ carry_capacity), достаём даже из-под низа кучи —
			# мелкие полешки можно выдёргивать снизу. Тяжёлое (только волоком) — по-прежнему лишь сверху.
			if fl.is_covered() and fl.get_weight() > carry_capacity:
				continue
			return {"type": "log", "log": fl}
	return {}


# Тачка под прицелом ДЛЯ ЗАГРУЗКИ (когда несём бревно). Годится либо сама тачка (попали по раме/
# дну), либо бревно, которое УЖЕ лежит в её кузове — целишься в торчащее бревно, а смысл всё равно
# «положить в тачку», а не «бросить» (#3). Сканируем ВСЕ попадания луча, не только ближнее: бревно
# в кузове часто ближе рамы и раньше перехватывало прицел, поэтому показывалось «бросить».
func _aim_barrow_for_load() -> Wheelbarrow:
	var log_hit: FallingLog = null
	for i in chop_ray.get_collision_count():
		var c := chop_ray.get_collider(i)
		if c is Wheelbarrow:
			return c
		if c is FallingLog and log_hit == null:
			log_hit = c
	# Прямо в тачку не попали, но попали в бревно — проверяем, не лежит ли оно в чьём-то кузове.
	if log_hit != null:
		for b in get_tree().get_nodes_in_group("wheelbarrow"):
			if b is Wheelbarrow and (b as Wheelbarrow).contains_cargo(log_hit):
				return b
	return null


# Берёмся за ручки тачки: топор убираем (обе руки заняты), встаём лицом по ходу тачки.
func _start_barrow(barrow: Wheelbarrow) -> void:
	_barrow = barrow
	_axe_stowed = true
	axe.visible = false
	# Пока держим — исключаем пару «игрок↔тачка» из столкновений (вместо смены слоя тачки).
	# Так капсула игрока не упирается в раму и не катит тачку сама, а ГЛАВНОЕ — слой тачки не
	# меняется, и лежащие в кузове брёвна не теряют опору и не проваливаются сквозь дно (#7).
	add_collision_exception_with(barrow)
	# Включаем коллайдер «рук» под тачку: зазор между игроком и ручками физически занят.
	barrow_arm_col.disabled = false
	barrow.grab()
	var bf := -barrow.global_transform.basis.z
	bf.y = 0.0
	if bf.length() > 0.01:
		bf = bf.normalized()
		rotation.y = atan2(-bf.x, -bf.z)
		# Встаём СРАЗУ за ручками (на длину рук), лицом по ходу тачки. Иначе, взяв тачку
		# вплотную (стоя у колеса/спереди), игрок «доходит» до ручек, упираясь в раму, и тачка
		# катится сама. Телепорт на правильную позицию убирает этот толчок.
		var grab := barrow.grab_point_world()
		global_position = Vector3(grab.x - bf.x * barrow.grab_distance,
				global_position.y, grab.z - bf.z * barrow.grab_distance)
	# Камера смотрит ровно по носу тачки (free-look обнуляем): дальше мышь крутит её в секторе
	# ±barrow_yaw_limit, не двигая тачку (#5).
	_barrow_cam_yaw = 0.0


# Ставим тачку: снова свободное тело, топор возвращаем.
func _stop_barrow() -> void:
	remove_collision_exception_with(_barrow)
	# Отпустили тачку — руки свободны, коллайдер «рук» под тачку убираем.
	barrow_arm_col.disabled = true
	_barrow.release()
	_barrow = null
	_axe_stowed = false
	axe.visible = true
	# Куда смотрел игрок (нос тачки + free-look) — складываем в поворот тела, чтобы при отпускании
	# камера не «прыгнула» обратно к носу тачки. Дальше мышь снова крутит тело как обычно.
	rotation.y += _barrow_cam_yaw
	_barrow_cam_yaw = 0.0


# Кладём несомое бревно в кузов и возвращаем топор/руки. Бревно становится обычным физтелом
# в тачке (упадёт в кузов поверх стопки). Доставать его потом — навестись и поднять как обычно.
func _load_into_barrow(barrow: Wheelbarrow) -> void:
	# Кладём бревно ТУДА, КУДА смотрит игрок: луч из камеры пересекаем с горизонтальной «плоскостью
	# кузова» (высота верха кузова), и эту точку отдаём тачке — она зажмёт её в габариты и положит
	# бревно туда (#4). Если смотрим выше горизонта (луч уходит вверх) — точки нет, ляжет по центру.
	# lay_dir — куда лечь длинной осью бревна: берём ГОРИЗОНТАЛЬНОЕ направление взгляда игрока, чтобы
	# бревно ложилось под углом подхода к тачке, а не всегда параллельно ей (#4).
	var lay := -camera.global_transform.basis.z
	lay.y = 0.0
	barrow.deposit_log(_carried, _barrow_aim_point(barrow), lay)
	_carried = null
	_carry_speed_mult = 1.0
	_carry_jump_mult = 1.0
	_axe_stowed = false
	axe.visible = true


# Точка прицела на «плоскости кузова»: луч из камеры (центр экрана) пересекаем с горизонтальной
# плоскостью на высоте верха кузова. Возвращаем мировую точку, КУДА смотрит игрок над тачкой —
# по ней решается, в какое место кузова лечь бревну (#4). Луч вверх/параллельно плоскости → INF.
func _barrow_aim_point(barrow: Wheelbarrow) -> Vector3:
	var origin := camera.global_position
	var dir := -camera.global_transform.basis.z
	if absf(dir.y) < 0.0001:
		return Vector3.INF
	var t := (barrow.cargo_top_y() - origin.y) / dir.y
	if t <= 0.0:
		return Vector3.INF  # плоскость кузова за спиной/выше взгляда — кладём по центру
	return origin + dir * t


# Включаем отладочную свободную камеру (#3): создаём Camera3D со скриптом free_cam в позиции игровой
# камеры, делаем её текущей и ставим ВСЮ сцену на паузу. free_cam живёт в режиме ALWAYS, летает по
# застывшему миру и по повторному ` сама снимает паузу и возвращает игровую камеру.
func _enter_free_cam() -> void:
	var cam := Camera3D.new()
	cam.set_script(load("res://scripts/free_cam.gd"))
	cam.transform = camera.global_transform  # добавляем в корень сцены → локальный = мировой
	cam.restore_camera = camera
	get_tree().current_scene.add_child(cam)
	cam.make_current()
	get_tree().paused = true


# Режим тачки (barrow-master): тачку ведём НАПРЯМУЮ клавишами (она задаёт ход), а игрока КАЖДЫЙ
# кадр приклеиваем за ручки. Так нет ни бокового сноса тачки, ни «погони за взглядом», ни зависания
# над склоном — всё это было у старой пружинной модели (#3,#5,#6).
func _drive_barrow(delta: float) -> void:
	var bfwd := -_barrow.global_transform.basis.z
	bfwd.y = 0.0
	if bfwd.length() < 0.01:
		# Вырожденная ориентация — просто стоим под гравитацией.
		if not is_on_floor():
			velocity += get_gravity() * delta
		move_and_slide()
		return
	bfwd = bfwd.normalized()
	# Ввод: W/S — ход (W=+1, S=−1), A/D — поворот тачки (D=+1, A=−1). Работают и стоя, и на ходу.
	var fwd_in := Input.get_axis("move_back", "move_forward")
	var yaw_in := Input.get_axis("move_left", "move_right")
	# АВТО-ОТПУСКАНИЕ над обрывом (#4, B). Лучом ВНИЗ перед носом тачки ищем землю; нет опоры на глубине
	# barrow_cliff_drop — впереди обрыв: отпускаем тачку (летит сама), игрок остаётся на краю.
	# ВАЖНО: проверяем ТОЛЬКО когда игрок реально ТОЛКАЕТ ВПЕРЁД (fwd_in > 0). Иначе застрявшую/
	# накренённую тачку (или только что взятую на склоне у края) отпускало мгновенно при простом
	# взятии — её нельзя было сдвинуть (B). Стоя/назад/поворачивая обрыв не проверяем: тачку держат
	# ровно, сама вниз она не уедет, а к краю игрок её толкнёт только вперёд.
	if fwd_in > 0.0 and _barrow_over_cliff(bfwd):
		_stop_barrow()
		if not is_on_floor():
			velocity += get_gravity() * delta
		move_and_slide()
		return
	# Руль инвертируем ТОЛЬКО на заднем ходу (S) — как у машины задним ходом. Стоя на месте (W/S не
	# зажаты) инверсию УБРАЛИ: она ощущалась «не в ту сторону», возвращаем поведение, как было до неё.
	if fwd_in < 0.0:
		yaw_in = -yaw_in
	# Скорость хода: пустая — почти как ходьба, гружёная — медленнее. По модулю одинакова вперёд и
	# назад (симметрия, #6). Бежать с тачкой нельзя.
	var spd := walk_speed * lerpf(barrow_speed_mult, barrow_speed_loaded_mult, _barrow.load_factor())
	# Перегруз (#2): груз сверх max_load_kg — тачка едет на пределе медленно, «еле-еле толкается».
	if _barrow.is_overloaded():
		spd = walk_speed * barrow_overload_mult
	# ЗАДНИЙ ХОД В ГОРКУ +50% (#9.4): заезжать на уклон задом удобнее (видно склон, тянешь на себя),
	# поэтому при S И когда направление движения (назад, -bfwd) идёт ВВЕРХ по склону — даём прибавку.
	# Уклон берём по нормали земли под тачкой: горизонтальная часть нормали смотрит ВНИЗ по склону,
	# значит «вверх по склону» = противоположное ей направление. На ровном/вперёд прибавки нет.
	if fwd_in < 0.0:
		var gn := _barrow.ground_normal()
		if gn.y < 0.985:
			var uphill := Vector3(-gn.x, 0.0, -gn.z)
			if uphill.length() > 0.001 and (-bfwd).dot(uphill.normalized()) > 0.3:
				spd *= 1.5
	# ВОРОТА ВВОДА ПО ПРОХОДИМОСТИ ИГРОКА (#barrow-block). Тачку ведёт игрок «руками»: если рукам
	# некуда двигаться (в зазор перед игроком — barrow_arm_col — заехало препятствие), тачку туда
	# вести нельзя. Иначе drive() жёстко выставлял тачке скорость и она уезжала/крутилась сама,
	# отрываясь от застрявшего игрока, а потом поводок «телепортировал» игрока к ней (баг #4).
	# Пробуем СОБСТВЕННЫМ коллайдером игрока (test_move учитывает arm box) два движения порознь:
	#  • ВПЕРЁД/НАЗАД вдоль носа на шаг этого кадра — упёрлись → не толкаем тачку ходом (fwd_in=0);
	#  • ОРБИТУ вокруг оси колёс на угол поворота этого кадра — упёрлись → не крутим тачку (yaw_in=0).
	# Движение ОТ препятствия (назад / поворот в другую сторону) проб не валит — так выехать можно.
	if fwd_in != 0.0:
		# Шаг-проба ВДОЛЬ СКЛОНА, а не строго горизонтально (#9b.2). Горизонтальная проба на подъёме
		# упиралась капсулой игрока в поднимающуюся землю → test_move=true → fwd_in обнулялся, и тачка
		# вставала на середине склона (а задом не ехала вовсе). Проецируем направление хода на плоскость
		# склона (нормаль земли под тачкой) — проба идёт ВВЕРХ по склону и не цепляет сам склон, но
		# настоящую стену/дерево впереди по-прежнему ловит.
		var travel_dir := bfwd * signf(fwd_in)
		var gn := _barrow.ground_normal()
		var slope_dir := travel_dir - gn * travel_dir.dot(gn)
		if slope_dir.length() > 0.01:
			slope_dir = slope_dir.normalized()
		else:
			slope_dir = travel_dir
		var fstep := slope_dir * (spd * delta + 0.02)
		# Блокируем ход ТОЛЬКО на непроходимой преграде (стена/дерево — нормаль почти вертикальна).
		# Проходимый СКЛОН (нормаль смотрит вверх) не блокирует — по нему тачку можно вести в горку,
		# как игрок сам туда заходит (#1: раньше любой контакт со склоном обнулял ход и тачка вставала).
		var fhit := KinematicCollision3D.new()
		if test_move(global_transform, fstep, fhit) and fhit.get_normal().y <= 0.5:
			fwd_in = 0.0
	# Скорость ПОВОРОТА: при перегрузе тачку и КРУТИТЬ тяжело, но штраф ВДВОЕ слабее, чем на ход (#3) —
	# крутиться на месте легче, чем толкать перегруз вперёд, поэтому ×2.
	var turn_spd := barrow_turn_speed
	if _barrow.is_overloaded():
		turn_spd *= barrow_overload_mult * 2.0
	if yaw_in != 0.0:
		var axle := _barrow.global_position
		axle.y = global_position.y
		var r := global_position - axle  # от оси колёс к игроку (плечо орбиты)
		var dyaw := -yaw_in * turn_spd * delta
		var orbit := r.rotated(Vector3.UP, dyaw) - r  # касательный сдвиг игрока за этот кадр
		# Как и у хода (#3): блокируем поворот ТОЛЬКО на непроходимой преграде (стена/дерево, нормаль
		# почти вертикальна). На проходимом склоне (нормаль вверх) орбита-проба раньше цеплялась за
		# поднимающуюся землю и обнуляла поворот — тачка переставала рулиться на горке.
		if orbit.length() > 0.0001:
			var ohit := KinematicCollision3D.new()
			if test_move(global_transform, orbit, ohit) and ohit.get_normal().y <= 0.5:
				yaw_in = 0.0
	# Тачку ведём с ИНЕРЦИЕЙ: разгон/торможение/доворот считает сама drive() по delta (#5b).
	_barrow.drive(fwd_in, yaw_in, spd, turn_spd, delta)

	# Тело смотрит ПО НОСУ тачки; камера докручивается отдельно (free-look ±barrow_yaw_limit, #5).
	rotation.y = atan2(-bfwd.x, -bfwd.z)

	# Приклеиваем игрока ЗА ручки: цель — точка хвата минус нос на длину рук. Игрок ходит ВОКРУГ
	# тачки (когда она крутится — обходит ось по дуге), а не крутится на месте (#7).
	var grab := _barrow.grab_point_world()
	var target := grab - bfwd * _barrow.grab_distance

	# Вертикаль — своя: гравитация + опора, чтобы игрок стоял на земле и всходил по рельефу.
	if not is_on_floor():
		velocity += get_gravity() * delta
	# СВОБОДНЫЙ ХОД (#5c): игрок держится за ручки НЕ намертво — ему позволено отставать от цели на
	# barrow_play метров, и он догоняет только ИЗБЫТОК сверх люфта. Раньше скорость выставлялась так,
	# чтобы «дойти до цели ровно за кадр», поэтому зазор всегда схлопывался в ноль и barrow_play ни на
	# что не влиял. Теперь меньше люфт — игрок плотнее «приклеен» к ручкам, больше — тачка свободнее
	# ходит перед ним. ИМЕННО это значение крути в Инспекторе (группа «Тачка»).
	var to_t := Vector3(target.x - global_position.x, 0.0, target.z - global_position.z)
	var dist := to_t.length()
	var slack := maxf(dist - barrow_play, 0.0)
	if dist > 0.0001 and slack > 0.0:
		var dir := to_t / dist
		# Догоняем только избыток люфта за кадр, но не быстрее разумного потолка (без «выстрела»).
		var follow_speed := minf(slack / delta, spd + 4.0)
		velocity.x = dir.x * follow_speed
		velocity.z = dir.z * follow_speed
	else:
		# В пределах люфта горизонтально не подтягиваемся — гасим инерцию.
		velocity.x = 0.0
		velocity.z = 0.0
	# ПЕРЕСТУП В РЕЖИМЕ ТАЧКИ (#barrow-step): раньше игрок при тачке НЕ умел перешагивать (степ-ап шёл
	# только в обычной ходьбе), а тачка через climb_assist переезжала бревно — игрок застревал, тачка
	# уезжала. Даём тот же степ-ап и здесь: запоминаем позу/скорость до move_and_slide и после упора
	# пробуем переступить в сторону хода. Степ игрока (0.4–0.75) ≥ climb тачки (0.24), так что игрок
	# всегда осилит то, что переехала тачка, и они идут вместе.
	var step_wish := Vector3(velocity.x, 0.0, velocity.z)
	_pre_move_pos = global_position
	_wish_speed = step_wish.length()
	move_and_slide()
	_snap_up_step(step_wish)

	# Жёсткий поводок: если после move_and_slide игрок всё ещё ДАЛЬШЕ barrow_play (упёрся в склон/
	# препятствие и не догнал) — подтягиваем ровно до края люфта. ВАЖНО: тянем через move_and_collide,
	# а НЕ прямым global_position += (тот протаскивал игрока СКВОЗЬ препятствия мимо коллизий — баг с
	# «руками»). move_and_collide упрётся в стену/дерево/коллайдер рук и остановит подтяжку на контакте.
	var gap := Vector3(target.x - global_position.x, 0.0, target.z - global_position.z)
	var gl := gap.length()
	if gl > barrow_play:
		move_and_collide(gap / gl * (gl - barrow_play))

	# АВТО-ОТПУСКАНИЕ при отставании (#2): если после всех подтяжек игрок всё равно ДАЛЬШЕ barrow_max_gap
	# от точки за ручками — значит он упёрся (уступ/препятствие), а тачка уехала вперёд по WASD. Чтобы
	# она не «убегала на дистанционном управлении», отпускаем её — игрок остаётся стоять, тачка свободна.
	var final_gap := Vector3(target.x - global_position.x, 0.0,
			target.z - global_position.z).length()
	if final_gap > barrow_max_gap:
		_stop_barrow()


# Есть ли впереди ОБРЫВ под носом тачки. Щуп ставим ВПЕРЕДИ носа: от ЦЕНТРА тачки идём по
# горизонтали (bfwd) на barrow_cliff_probe — так точка падает за передним бортом, у носа (раньше луч
# шёл от РУЧЕК, т.е. сзади, и срабатывал, только когда вся тачка уже свисала — отпускало слишком
# поздно, #4). Луч вертикальный: СТАРТ держим ВЫШЕ тачки (+1 м), чтобы при заезде В ГОРКУ земля
# впереди, поднимающаяся выше колёс, всё равно попадала в луч и НЕ принималась за обрыв (ложное
# отпускание в гору, #4). НИЗ луча — на barrow_cliff_drop НИЖЕ колёс: земля глубже этого = пропасть.
# Маска 1|4|16 (мир + физтела + рельеф). Тачку и игрока исключаем, чтоб луч не цеплялся за их коллизии.
func _barrow_over_cliff(bfwd: Vector3) -> bool:
	if _barrow == null or not is_instance_valid(_barrow):
		return false
	var bp := _barrow.global_position
	var nx := bp.x + bfwd.x * barrow_cliff_probe
	var nz := bp.z + bfwd.z * barrow_cliff_probe
	var top := Vector3(nx, bp.y + 1.0, nz)
	var bottom := Vector3(nx, bp.y - barrow_cliff_drop, nz)
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(top, bottom, 1 | 4 | 16)
	q.exclude = [_barrow.get_rid(), get_rid()]
	return space.intersect_ray(q).is_empty()


# Каждый физкадр тянем схваченный торец к точке у рук игрока (перед ним, чуть приподнято).
# Бревно — живое физтело: проседает под весом, дальний конец волочится по земле, инерция
# своя. Идём/поворачиваемся — торец следует за «рукой» с задержкой (см. FallingLog.drag_pull).
func _update_drag() -> void:
	if _dragged == null:
		return
	var fwd := -global_transform.basis.z  # направление взгляда (вперёд)
	fwd.y = 0.0
	if fwd.length() < 0.01:
		return
	fwd = fwd.normalized()
	# Точка «в руках»: перед игроком на длину рук, приподнята — бревно тянется ВПЕРЕДИ, видно.
	var hold := global_position + fwd * drag_grab_distance + Vector3.UP * drag_grab_lift
	_dragged.drag_pull(hold, drag_stiffness, drag_damping, drag_max_force,
			drag_arm_reach, drag_tail_grip)


# Кладём несомое бревно В МИРЕ по прицелу — так же, как в тачку (#4): луч из камеры (центр экрана)
# ищет твёрдую поверхность (земля/бревно/препятствие), и бревно ложится ТУДА, куда смотришь, вдоль
# горизонтального направления взгляда. Если прицел в воздух (луч никуда не упёрся) — бревно спавним
# В ВОЗДУХЕ по лучу прицела и отпускаем: оно падает под гравитацией. Целишься НАД собой — бревно
# падает на голову и бьёт (масса×скорость): фича «подкинул над головой → получил урон» (#H3).
func _drop_carried() -> void:
	var forward := -camera.global_transform.basis.z
	forward.y = 0.0
	if forward.length() < 0.01:
		forward = -global_transform.basis.z
	forward = forward.normalized()
	var drop_pos := _world_aim_point()
	_carried.drop(get_tree().current_scene, drop_pos, forward)
	_carried = null
	_carry_speed_mult = 1.0
	_carry_jump_mult = 1.0
	_axe_stowed = false
	axe.visible = true


# Точка спавна бревна по прицелу (#4, #H3): луч из камеры ищет твёрдую поверхность (слои 1|4|16:
# земля, брёвна, препятствия). Нашли — кладём бревно прямо туда (drop() само поднимет на радиус, так
# что оно ляжет на поверхность). Не нашли (целимся в небо/даль) — НЕ роняем у ног, а возвращаем точку
# В ВОЗДУХЕ вдоль ПОЛНОГО (с наклоном) направления взгляда: бревно появится там и упадёт сверху —
# хочешь подкинуть над головой и поймать урон → целься вверх.
func _world_aim_point() -> Vector3:
	var origin := camera.global_position
	var dir := -camera.global_transform.basis.z
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(origin, origin + dir * 4.0)
	q.exclude = [get_rid(), _carried.get_rid()]
	q.collision_mask = 1 | 4 | 16
	var hit := space.intersect_ray(q)
	if not hit.is_empty():
		return hit["position"]
	# Прицел в никуда — точка В ВОЗДУХЕ на 1.5 м по лучу взгляда (с учётом наклона: вверх → над собой).
	return origin + dir * 1.5


# Множитель скорости от веса в руках: 1 у лёгкого, carry_min_speed_mult у предела.
func _carry_speed_for(weight: float) -> float:
	var t := clampf(weight / maxf(carry_capacity, 0.01), 0.0, 1.0)
	return lerpf(1.0, carry_min_speed_mult, t)


# Множитель высоты прыжка от веса в руках: 1 у лёгкого, carry_jump_min_mult у предела (#1).
func _carry_jump_for(weight: float) -> float:
	var t := clampf(weight / maxf(carry_capacity, 0.01), 0.0, 1.0)
	return lerpf(1.0, carry_jump_min_mult, t)


# Поза бревна на плече относительно камеры: лежит вдоль взгляда, смещено на нужное плечо,
# чуть ниже глаз. Левое плечо — топор в правой руке; правое — топор убран.
func _shoulder_pose(on_left: bool) -> Transform3D:
	var side := -0.32 if on_left else 0.32
	# Поворот вокруг X кладёт длинную ось бревна (локальный Y) почти вдоль взгляда (за спину),
	# с лёгким наклоном — будто закинуто на плечо.
	var basis := Basis(Vector3(1.0, 0.0, 0.0), deg_to_rad(95.0))
	return Transform3D(basis, Vector3(side, -0.05, -0.15))


# Сила удара (#4) на отпускании ЛКМ: заряд от длительности замаха (100%→chop_power_max),
# штраф за боковой удар A/D (масштаб по |aim.x|) и за прерывающий удар (новый замах поверх
# недоигравшего). Итог ограничиваем потолком chop_power_max.
func _compute_chop_power(aim: Vector2) -> float:
	var hold := Time.get_ticks_msec() / 1000.0 - _charge_start_s
	var charge := lerpf(1.0, chop_power_max, clampf(hold / chop_charge_time, 0.0, 1.0))
	var side := lerpf(1.0, chop_side_power_mult, clampf(absf(aim.x), 0.0, 1.0))
	var interrupt := chop_interrupt_power_mult if _chop_charging_interrupted else 1.0
	return clampf(charge * side * interrupt, 0.0, chop_power_max)


# Вызывается топором в момент удара лезвия. Тут решаем, попали ли по стволу.
# ShapeCast — «толстый луч» (сфера r=0.15): прицел прощающий, у лезвия есть толщина.
func _on_axe_impact() -> void:
	chop_ray.force_shapecast_update()
	if not chop_ray.is_colliding():
		return
	# Что-то задели лезвием — даём варьирующуюся отдачу камере.
	_apply_kick()

	# Индекс 0 — ближайшее попадание (результаты идут от близких к дальним).
	var target := chop_ray.get_collider(0)
	if target == null:
		return
	var point := chop_ray.get_collision_point(0)
	var normal := chop_ray.get_collision_normal(0)

	# Сила удара = насколько он ПЕРПЕНДИКУЛЯРЕН стволу. В лоб (взгляд против нормали) —
	# полный урон/глубокая зарубка; вскользь — слабо. perp: 0 (касательно)..1 (в лоб).
	var forward := -camera.global_transform.basis.z
	var perp := clampf(forward.dot(-normal), 0.0, 1.0)
	var power := lerpf(0.35, 1.3, perp)
	# Сила замаха (#4): дольше держал ЛКМ → сильнее (до chop_power_max); боковой удар A/D и
	# прерывающий удар — слабее. Множитель посчитан на отпускании в _compute_chop_power.
	power *= _chop_power_mult
	# Несём бревно на левом плече (топор в правой руке) — бьём слабее, рука занята.
	if _carried != null:
		power *= carry_chop_power_mult

	# Плоскость лезвия в момент удара — ось X топора (вдоль режущей кромки). По ней
	# ориентируем зарубку (диагональный руб даёт диагональную зарубку).
	var edge := axe.global_transform.basis.x

	# Толкаем свободные физтела лезвием: лёгкие поленья сдвигаются заметно, тяжёлые брёвна
	# почти нет (скорость = импульс/масса). Замороженные (стволы/пни) пропускаем — их не
	# сдвинуть, только рубить. Импульс — в точку удара, поэтому полено ещё и подкручивается.
	if target is RigidBody3D and not (target as RigidBody3D).freeze:
		var rb := target as RigidBody3D
		# Будим тело перед толчком: лежащее бревно (на земле ИЛИ в кузове тачки) спит и без
		# пробуждения игнорирует импульс — по бревну в тачке «не было толчка» (#3).
		rb.sleeping = false
		rb.apply_impulse(forward * axe_push_impulse * power, point - rb.global_position)

	# Луч попадает в дочерний TrunkBody, метод chop() — на родительском узле дерева.
	if target.has_method("chop"):
		target.chop(global_position, point, normal, power, edge)
	elif target.get_parent() and target.get_parent().has_method("chop"):
		target.get_parent().chop(global_position, point, normal, power, edge)


# Отдача камеры от удара: тангаж в основном вверх, но с разбросом; крен/рыскание
# случайны и слегка зависят от стороны замаха — так каждый удар ощущается иначе.
func _apply_kick() -> void:
	var pitch := deg_to_rad(kick_pitch_deg) * randf_range(0.5, 1.3)
	var roll := deg_to_rad(kick_roll_deg) * randf_range(0.4, 1.0) * (1.0 if randf() < 0.5 else -1.0)
	roll -= deg_to_rad(kick_roll_deg) * 0.5 * _last_aim.x
	var yaw := deg_to_rad(kick_yaw_deg) * randf_range(-1.0, 1.0)
	_kick += Vector3(pitch, yaw, roll)


func _physics_process(delta: float) -> void:
	# Тачка в руках — отдельный режим управления (barrow-master): ведём тачку напрямую WASD и
	# приклеиваем игрока к ручкам. Обычную ходьбу/прыжок/степап при этом пропускаем (#3,#4,#5,#6).
	if _barrow != null:
		_drive_barrow(delta)
		return

	var on_floor := is_on_floor()

	# Гравитация в воздухе (значение из настроек проекта).
	if not on_floor:
		velocity += get_gravity() * delta

	# Считываем WASD как вектор и переводим в мировое направление.
	var input_dir := Input.get_vector(
		"move_left", "move_right", "move_forward", "move_back"
	)
	var direction := (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()

	var speed := walk_speed
	# Бежать можно только налегке: не во время волока.
	if Input.is_action_pressed("run") and _dragged == null:
		speed *= run_multiplier
	# Несомое бревно замедляет: множитель зависит от веса (из ресурса LogItem).
	speed *= _carry_speed_mult
	# Волок медленнее обычной ходьбы. Толкать бревно ВДОЛЬ него от себя (гнать дальний конец
	# вперёд) — почти нельзя. ВАЖНО: «толкание» считаем по ОСИ БРЕВНА, а не по взгляду игрока —
	# иначе можно повернуть камеру и быстро толкать бревно «боком». Ось берём из самого бревна
	# (от схваченного торца к дальнему), поэтому поворот взгляда обмануть проверку не может.
	if _dragged != null:
		var axis := _dragged.tail_point_world() - _dragged.grab_point_world()
		axis.y = 0.0
		if direction.length() > 0.01 and axis.length() > 0.01 \
				and direction.dot(axis.normalized()) > 0.3:
			speed *= drag_push_speed_mult
		else:
			speed *= _drag_speed_mult

	if on_floor:
		# На земле — мгновенная отзывчивость, прыжок.
		if direction:
			velocity.x = direction.x * speed
			velocity.z = direction.z * speed
		else:
			velocity.x = move_toward(velocity.x, 0.0, speed)
			velocity.z = move_toward(velocity.z, 0.0, speed)
		# Во время волока прыгать нельзя (обе руки заняты). С тачкой сюда не доходим (свой режим).
		if Input.is_action_just_pressed("jump") and _dragged == null:
			velocity.y = _jump_velocity * _carry_jump_mult
	else:
		# В воздухе — ограниченное руление: инерция сохраняется, но подправить можно.
		if direction:
			var accel := 16.0 * air_control * delta
			velocity.x = move_toward(velocity.x, direction.x * speed, accel)
			velocity.z = move_toward(velocity.z, direction.z * speed, accel)

	# Запоминаем позицию и желаемую скорость ДО move_and_slide — степ-ап по ним поймёт, застряли мы
	# или ехали свободно (анти-спидхак на верху бревна, #2).
	_pre_move_pos = global_position
	_wish_speed = speed
	move_and_slide()
	_snap_up_step(direction)
	_push_bodies()
	# Волок: тянем бревно ПОСЛЕ перемещения игрока — по его свежей позиции.
	_update_drag()
	_clamp_to_dragged()


# Нельзя уйти от ЗАСТРЯВШЕГО бревна. Если схваченный торец отстал дальше предела (бревно
# упёрлось в препятствие, а игрок продолжил идти) — подтягиваем игрока обратно к бревну. Так
# при упоре игрок встаёт намертво, пока не бросит бревно (E) или не обойдёт препятствие.
func _clamp_to_dragged() -> void:
	if _dragged == null:
		return
	var grab := _dragged.grab_point_world()
	var to_grab := grab - global_position
	to_grab.y = 0.0
	var max_d := drag_grab_distance + drag_arm_reach + 0.1
	if to_grab.length() > max_d:
		# Подтягиваем игрока к бревну ЧЕРЕЗ move_and_collide, а НЕ прямым global_position += : тот
		# протаскивал игрока СКВОЗЬ препятствия (пень/дерево/коллайдер рук) мимо коллизий — отсюда
		# баг «бревно за пнём, и игрока рывками протягивает сквозь пень к нему». move_and_collide
		# упрётся в препятствие и остановит подтяжку на контакте.
		move_and_collide(to_grab.normalized() * (to_grab.length() - max_d))


# Кинематический игрок сам по себе не толкает RigidBody. Передаём ему ВЕС вниз. Где именно
# приложить вес — решаем по ОПОРЕ под ногой (луч вниз сквозь само бревно):
#  • есть опора (пол/куб/другое бревно прямо под точкой) → давим в ЦЕНТР МАСС, БЕЗ момента:
#    бревно на ровной/опёртой поверхности НЕ должно раскручиваться от игрока;
#  • под точкой ПУСТОТА (конец свисает за краем) → давим весом ИМЕННО в эту точку: свисающий
#    конец перевешивает и падает через край, как и должно. Так нет «раскрутки» на ровном, но
#    есть честное опрокидывание нависшего конца.
# Auto step-up: после move_and_slide, если игрок упёрся в НИЗКОЕ препятствие (камень, бревно,
# край пня), «переступаем» через него без прыжка. Метод: упёрлись по горизонтали → поднимаемся
# на step_height, проверяем, что сверху путь свободен и под нами есть ровная опора, и ставим
# игрока на эту опору. Препятствие выше step_height остаётся стеной (проба сверху всё ещё упрётся).
func _snap_up_step(wish_dir: Vector3) -> void:
	if not is_on_floor():
		return
	# ВАЖНО: пробуем по ЖЕЛАЕМОМУ направлению (ввод WASD), а НЕ по velocity. При лобовом упоре
	# move_and_slide гасит скорость «в стену» почти в ноль (или разворачивает вдоль неё), и проба
	# по velocity либо отсекалась порогом, либо щупала вбок — поэтому step-up не срабатывал (#2).
	var dir := Vector3(wish_dir.x, 0.0, wish_dir.z)
	if dir.length() < 0.1:
		return
	# АНТИ-СПИДХАК (#2): степ-ап телепортирует игрока ВПЕРЁД (~0.25 м) ДОПОЛНИТЕЛЬНО к move_and_slide.
	# Стоя НА бревне капсула впереди постоянно цепляет скруглённый верх, и без этой проверки степ-ап
	# срабатывал бы каждый кадр — разгон по бревну быстрее ходьбы. Но если игрок этот кадр УЖЕ проехал
	# вперёд почти на полную (move_and_slide не упёрся), значит он НЕ застрял — переступать не нужно.
	# Степ-ап включаем ТОЛЬКО когда move_and_slide реально упёрся (горизонтальный прогресс просел).
	# Высоту/толщину бревна это НЕ учитывает (в отличие от старого порога, который ломал тонкие, #3).
	var moved := global_position - _pre_move_pos
	moved.y = 0.0
	var progress := moved.dot(dir.normalized())
	var intended := _wish_speed * get_physics_process_delta_time()
	if intended > 0.001 and progress > intended * 0.5:
		return
	# Щупаем заметно вперёд (больше радиуса капсулы 0.3 нерелевантно — нужен сам факт упора):
	# 0.25 м хватает поймать уступ, об который игрок упёрся, и не «перепрыгнуть» лишнего.
	var motion := dir.normalized() * 0.25
	# Упёрлись ли на уровне ног? Нет — идти не мешает, шагать не нужно.
	var hit := KinematicCollision3D.new()
	if not test_move(global_transform, motion, hit):
		return
	var obstacle := hit.get_collider()
	var is_log := obstacle is FallingLog
	# Пологий пол/склон (нормаль смотрит заметно вверх) — обычная ходьба справится, шагать не нужно.
	# НО для БРЕВНА этот выход ОТКЛЮЧАЕМ: подходя к боку лежачего цилиндра, капсула касается его
	# ВЕРХНЕГО плеча, и нормаль контакта наклонена вверх (y>0.2) — из-за этого ПОПЕРЁК бревна степ-ап
	# раньше не срабатывал вовсе (мы выходили здесь). Бревно climbable при любой нормали контакта (#H6).
	if not is_log and hit.get_normal().y > 0.2:
		return
	# Пинаем бревно или лезем на него (#1, #H6):
	#  • С ТОРЦА (end-on) — катить нельзя (цилиндр не катится вдоль своей оси, только скользит с
	#    трением), поэтому ВСЕГДА переступаем, независимо от веса — раньше торец «не пинался и не
	#    переступался», игрок застревал.
	#  • СБОКУ — лёгкое (≤ carry_capacity) обычно катим (_push_bodies); но если ему НЕКУДА катиться
	#    (упёрто в стену/бревно/склон — _log_blocked), всё равно переступаем. Тяжёлое — всегда лезем.
	# На бревно лезем с бОльшим запасом высоты (log_step_height) — оно толще обычного уступа.
	var step := step_height
	if is_log:
		var fl := obstacle as FallingLog
		var end_on := _is_end_on(fl, hit.get_normal())
		if not end_on and fl.get_weight() <= carry_capacity:
			if not _log_blocked(fl, dir.normalized()):
				return  # сбоку и есть куда катиться — пусть _push_bodies откатит
		# Высоту переступа подгоняем под ТОЛЩИНУ бревна, а не берём всегда максимум (#3/E). Верх
		# лежачего цилиндра ≈ 2 радиуса над землёй; +0.15 м запаса. У ТОНКОГО бревна так получается
		# низкий шаг (~step_height): игрок поднимается ровно настолько, чтобы оказаться на нём, и
		# опорный луч находит верх бревна, а не «промахивается» вниз/в дерево от лишнего подъёма на
		# 0.75 м (из-за этого тонкие брёвна у дерева/другого бревна не переступались). Толстое —
		# по-прежнему до log_step_height. Зажимаем в [step_height .. log_step_height].
		step = clampf(fl.get_radius() * 2.0 + 0.15, step_height, log_step_height)
	# Поднимаемся на step и проверяем тот же ход: если по-прежнему упёрлись — уступ
	# слишком высок, через него не переступить (остаётся стеной).
	var up_xf := global_transform.translated(Vector3.UP * step)
	if test_move(up_xf, motion):
		return
	# С поднятой позиции сдвигаемся вперёд и «опускаемся» на step в поисках опоры.
	var fwd_xf := up_xf.translated(motion)
	var down := KinematicCollision3D.new()
	if not test_move(fwd_xf, Vector3.DOWN * step, down):
		return  # под уступом нет опоры в пределах step — не телепортируем в воздух
	# Опора должна быть достаточно ровной, чтобы на ней стоять. У БРЕВНА верх скруглён: при заходе
	# ПОПЕРЁК (на бок цилиндра) капсула касается «плеча» бочки, и нормаль контакта наклонена — порог
	# 0.7 её отсекал, поэтому поперёк step-up не срабатывал, а с торца (плоский край) — да (#3).
	# Для бревна порог опоры ослабляем (на верх бревна влезть можно и по скруглению).
	var min_floor_y := 0.35 if obstacle is FallingLog else 0.7
	if down.get_normal().y < min_floor_y:
		return
	# Ставим игрока на верх уступа (вперёд + вниз до найденной опоры). Это телепорт тела за ОДИН кадр
	# — и ВВЕРХ, и ВПЕРЁД (на motion ≈0.25 м). Без сглаживания камера дёргается рывком-«склейкой» по
	# обеим осям (#4). Поэтому копим ПРОТИВОПОЛОЖНОЕ прыжку смещение камеры (в локале тела), а в
	# _process плавно гасим к нулю — тело прыгнуло, а взгляд «всплыл» мягко и не дёрнулся вперёд.
	var old_pos := global_position
	global_position = fwd_xf.origin + down.get_travel()
	var world_jump := global_position - old_pos
	# Сглаживаем ПОЛНЫЙ рывок телепорта (и вверх, и вперёд): камеру в момент скачка оставляем там, где
	# она была, накопив смещение, ОБРАТНОЕ прыжку (в локале тела), и в _process плавно гасим к нулю.
	# Так подъём = мягкое всплытие по обеим осям, а не дёрганая «склейка кадров» (#8: вертикаль-только
	# дёргалась из-за нескомпенсированного горизонтального рывка ~0.25 м).
	if world_jump.length() > 0.001:
		var cap := maxf(step_height, log_step_height) + 0.5
		# Мир → локаль тела: тело только рыскает (yaw), наклона нет, поэтому это чистый поворот.
		var local_jump := global_transform.basis.inverse() * world_jump
		_step_offset = (_step_offset - local_jump).limit_length(cap)


func _push_bodies() -> void:
	var space := get_world_3d().direct_space_state
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		var body := c.get_collider()
		if not (body is RigidBody3D) or body.freeze:
			continue
		var rb := body as RigidBody3D
		# Боковой контакт (не стоим сверху).
		if c.get_normal().y <= 0.5:
			if rb is FallingLog:
				var fl := rb as FallingLog
				# С какой стороны упёрлись (торец/бок). С ТОРЦА бревно не катим — цилиндр не катится
				# вдоль оси, игрок ПЕРЕСТУПАЕТ через него (см. _snap_up_step, #H6). СБОКУ тяжёлое
				# (> carry_capacity) тоже не катим — переступаем. В обоих случаях капсула, упираясь,
				# решателем чуть «продавливает» бревно, и оно ползёт, будто мы давим: гасим этот крип
				# (якорим малую горизонтальную скорость; настоящий удар/качение быстрее порога не трогаем,
				# чтоб скатывающееся с горы бревно жило).
				var end_on := _is_end_on(fl, c.get_normal())
				if end_on or fl.get_weight() > carry_capacity:
					var hv := rb.linear_velocity
					hv.y = 0.0
					if hv.length() < 0.6:
						rb.linear_velocity.x = 0.0
						rb.linear_velocity.z = 0.0
						rb.angular_velocity *= 0.5
					continue
				# Сбоку и достаточно лёгкое — будим (улёгшись, бревно «засыпает») и катим с дороги.
				rb.sleeping = false
				_shove_body(rb, c)
				continue
			# Прочее физтело (не бревно) — будим и пробуем сдвинуть (тяжёлое всё равно не поедет).
			rb.sleeping = false
			_shove_body(rb, c)
			continue

		# Стоим сверху — будим и давим весом вниз.
		rb.sleeping = false
		var contact := c.get_position()
		# Есть ли опора ПОД точкой давления? Луч вниз, СКВОЗЬ само бревно (его исключаем).
		var from := contact + Vector3.UP * 0.05
		var q := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 3.0)
		q.exclude = [rb.get_rid()]
		q.collision_mask = 1 | 4 | 16
		var hit := space.intersect_ray(q)
		var supported := not hit.is_empty() and (from.y - (hit["position"] as Vector3).y) < 0.6
		if supported:
			rb.apply_central_force(Vector3.DOWN * push_force)
		else:
			rb.apply_force(Vector3.DOWN * push_force, contact - rb.global_position)


# Боковой толчок физтела (бревна), в которое игрок упёрся при ходьбе. Лёгкое (по ОТОБРАЖАЕМОМУ
# весу) — разлетается, тяжёлое — стоит. Сила = масса×ускорение, поэтому результат зависит от
# перцептивного веса, а не от реальной (утроённой) массы: куча тонких поленьев расступается,
# толстый ствол не сдвинуть. Толкаем вдоль нормали контакта (от игрока в тело).
func _shove_body(rb: RigidBody3D, c: KinematicCollision3D, speed_scale: float = 1.0) -> void:
	var disp := 1.0e9
	if rb is FallingLog:
		disp = (rb as FallingLog).get_weight()
	if disp > push_log_capacity:
		return
	var k := 1.0 - disp / push_log_capacity  # 1 у лёгкого .. 0 у предела
	var dir := -c.get_normal()
	dir.y = 0.0
	if dir.length() < 0.01:
		return
	dir = dir.normalized()
	# Целевая скорость бревна вдоль толчка зависит от веса: лёгкое разгоняем до push_log_speed,
	# тяжёлое (у предела) — почти до нуля. speed_scale дополнительно режет цель, если толкаем С
	# ТОРЦА (катить торец тяжелее, #1). Сила тянет скорость к цели и ГАСНЕТ у неё, поэтому тяжёлое
	# не «доедет» до большой скорости даже за много кадров — вес виден явно.
	var target := push_log_speed * k * speed_scale
	var v_along := rb.linear_velocity.dot(dir)
	if v_along >= target:
		return
	rb.apply_central_force(dir * (target - v_along) * push_log_accel * rb.mass)


# Подошёл ли игрок к бревну С ТОРЦА (вдоль его оси) или С БОКА — по углу между осью бревна
# (локальный Y) и горизонтальной нормалью контакта. |cos| выше порога — торец, ниже — бок (#1).
func _is_end_on(fl: FallingLog, contact_normal: Vector3) -> bool:
	var axis := fl.global_transform.basis.y
	axis.y = 0.0
	var n := contact_normal
	n.y = 0.0
	if axis.length() < 0.01 or n.length() < 0.01:
		return false
	return absf(axis.normalized().dot(n.normalized())) > end_on_threshold


# Может ли бревно откатиться в сторону толчка (push_dir, горизонт)? Нет — если в пределах
# log_roll_clearance перед ним стена/другое бревно/склон. Тогда катить бесполезно и игрок
# переступает (#2,#6). Щупаем тремя лучами поперёк ОСИ бревна (центр + оба плеча), т.к. длинное
# бревно может упереться концом, а центр ещё свободен. Само бревно и игрока из проверки исключаем.
func _log_blocked(fl: FallingLog, push_dir: Vector3) -> bool:
	var space := get_world_3d().direct_space_state
	var axis := fl.global_transform.basis.y  # длинная ось бревна
	axis.y = 0.0
	if axis.length() > 0.01:
		axis = axis.normalized()
	else:
		axis = Vector3.ZERO
	var half := fl.get_length() * 0.5
	var offsets: Array[float] = [0.0, half * 0.8, -half * 0.8]
	for off in offsets:
		var from := fl.global_position + axis * off
		from.y = maxf(from.y, global_position.y + 0.1)  # на уровне голени, не под полом
		var q := PhysicsRayQueryParameters3D.create(from, from + push_dir * log_roll_clearance)
		q.exclude = [fl.get_rid(), get_rid()]
		q.collision_mask = 1 | 4 | 16
		if not space.intersect_ray(q).is_empty():
			return true
	return false
