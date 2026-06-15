extends CharacterBody3D
class_name Player

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
## Скорость возврата камеры после кика (1/с): больше — быстрее успокаивается. Сам кик (отдачу при
## ударе) задаёт компонент ChopController; здесь — только скорость её затухания в _process.
@export var kick_recover_speed: float = 12.0
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
## Поза несомой связки брёвен в локале тела (#carry-level): вбок от центра (X), высота плеча (Y),
## сдвиг назад (Z, +Z = за спину). Сбоку держим связку дальше радиуса бревна, чтобы она не лезла в
## камеру. Брёвна лежат горизонтально и поворачиваются с телом (не с камерой).
@export var carry_side: float = 0.45
@export var carry_height: float = 1.45
@export var carry_back: float = 0.3
# Сила удара/заряд/боковой штраф и отдача камеры переехали на компонент ChopController (его и крути).
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
## Глубина проверки опоры (м) под игроком при ВЗЯТИИ бревна на ВОЛОК (#reach). Волок ставит игрока
## у схваченного торца — если там под ногами нет твёрдой земли в пределах этой глубины (бревно
## свисает одним концом с обрыва), волок не начинаем: иначе игрок «брал» свисающий конец, стоя на
## краю в воздухе, и тащил бревно вниз. Луч прицела бьёт дальше опоры, поэтому проверка нужна.
@export var drag_ground_drop: float = 1.2
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
## Плавность следования за тачкой (#barrow-follow). Раньше игрок «закрывал» отставание за один кадр
## (скорость = слэк/delta) — выходил рывок «как провод». Теперь скорость = слэк·gain (пружина, с
## потолком), и ведётся к цели ПЛАВНО (smooth). Жёсткую подтяжку тоже смягчили (leash_pull — доля/с).
@export var barrow_follow_gain: float = 25.0
@export var barrow_follow_smooth: float = 16.0
## Наклон камеры «тачка тянет» (#barrow-drag): рад на метр отставания (вперёд/вбок), предел и плавность.
## Маленький базовый — занос едва заметен пустой тачкой; с грузом домножается до ×1.5 (см. _drive_barrow).
@export var barrow_lean_gain: float = 0.12
@export var barrow_lean_max: float = 0.14
@export var barrow_lean_smooth: float = 9.0
## Доля хода/поворота, остающаяся при упоре в непроходимое (#barrow-struggle): 0 — глухой стоп (как
## раньше), 0.15 — застрявшую тачку можно медленно продавить/вытолкать с усилием.
@export var barrow_struggle_mult: float = 0.15
## РЕЕЛ-ИН (#barrow-reel): держим тачку за ручки — если хват ПРОВАЛИЛСЯ ниже рук больше slack (тачка
## упала с уступа/в яму), тянем её к рукам (gain — сила, max — потолок). Триггер по вертикали, чтобы
## подъём В ГОРКУ не дёргало. Так упавшую тачку можно выволочь, а не обходить/пинать топором.
@export var barrow_reel_slack: float = 0.5
@export var barrow_reel_gain: float = 6.0
@export var barrow_reel_max: float = 4.0
## СПОТЫКАНИЕ при авто-отпускании тачки (#barrow-stumble): тачку «вырвало» из рук — игрок по инерции
## клюёт вперёд. stumble_speed — рывок вперёд (м/с), dip/forward — просадка камеры (м), pitch/roll —
## клевок/шатание взгляда (град). Всё затухает штатно (_kick / _step_offset).
@export var stumble_speed: float = 1.0
@export var stumble_dip: float = 0.22
@export var stumble_forward: float = 0.08
@export var stumble_pitch_deg: float = 5.0
@export var stumble_roll_deg: float = 9.0
## Потолок скорости инерции (м/с) в момент спотыкания: сохранённую скорость следования зажимаем,
## иначе глайд слишком быстрый и читается как рывок, а не «несёт» (#barrow-inertia).
@export var stumble_max_speed: float = 3.0
## Окно «потери управления» при спотыкании (с): пока идёт, ВВОД НЕ перебивает скорость, инерция
## сохраняется и плавно гаснет (stumble_friction) — игрока реально несёт вперёд, как при спотыкании.
@export var stumble_time: float = 0.9
@export var stumble_friction: float = 1.4
## Во сколько раз спотыкание СИЛЬНЕЕ при сбросе тачки с ОБРЫВА (#barrow-stumble), чем при обычном
## отставании: падение в пропасть дёргает резче. Итог ещё домножается на (0.6 + доля груза).
@export var barrow_stumble_cliff_mult: float = 1.8

@export_group("Телекинез (захват на расстоянии)")
## Сколько держать E, чтобы вместо «взять в руки» ЗАФИКСИРОВАТЬ режим таскания (как Z-захват в Skyrim):
## по истечении этого времени бревно «защёлкивается» и висит уже без зажатой E, повторное нажатие E —
## отпустить. Короткий тап (короче этого) по бревну — взять на плечо, как раньше.
@export var manip_hold_time: float = 0.4
## Максимальный «рабочий» вес бревна (кг), которое можно таскать телекинезом. Тяжёлые — никак.
@export var manip_capacity: float = 70.0
## Дистанция удержания (м) перед камерой: на ней висит точка хвата. Зажали ближе/дальше — зажимаем сюда.
@export var manip_distance_min: float = 1.2
@export var manip_distance_max: float = 3.0
## Жёсткость пружины, тянущей точку хвата к цели (1/с²): больше — резче «прилипает» и меньше провисает.
@export var manip_stiffness: float = 90.0
## Демпфирование пружины (1/с): гасит колебания у точки хвата, чтобы бревно не «пружинило».
@export var manip_damping: float = 14.0
## Потолок ускорения пружины (м/с²): не даёт бревну «выстрелить», если цель далеко (рывком мышью).
@export var manip_max_accel: float = 140.0
## Угловое демпфирование бревна на время захвата (1/с): стабилизирует «висящее» бревно. Взятое за край
## всё равно стабильно (ЦМ висит ниже), за центр — болтается (момента нет) — это и есть нужное поведение.
@export var manip_angular_damp: float = 2.0
## Физ-масса (кг) держимого бревна на время захвата. Маленькая → мал импульс удара (не таранит тяжёлые
## брёвна; их к тому же держит трение). Отклик пружины от массы не зависит (сила = ускорение × масса),
## держится/разворачивается так же. Тачку телекинезом не катаем отдельной логикой (см. wheelbarrow).
@export var manip_hold_mass: float = 2.0
## Разрыв (м) между точкой хвата и целью, ПОДОЗРИТЕЛЬНЫЙ на упор. Сам по себе не рвёт захват — нужно,
## чтобы при этом бревно ещё и почти НЕ ДВИГАЛОСЬ (см. manip_break_progress): иначе это просто таскание.
@export var manip_break_distance: float = 0.6
## Насколько (м) точка хвата должна СДВИНУТЬСЯ за окно времени, чтобы считать «бревно тащится, не упор».
## Меньше этого за manip_break_time при сохраняющемся отставании = бревно дрожит на месте (упёрлось в
## стену/застряло под ногами) → срываем захват. Резкий мах двигает хват сильно → таймер сбрасывается.
@export var manip_break_progress: float = 0.3
## Окно (с): столько бревно должно «дрожать на месте» в отставании, чтобы захват сорвался.
@export var manip_break_time: float = 0.3

# Здоровье (max_hp, урон, полоска, смерть) — на компоненте Health (узел-ребёнок). Player —
# фасад: take_damage() пересылает туда. Тунинг max_hp крути на узле Health.

var _jump_velocity: float = 0.0
## Несомые на плече брёвна (стек, #carry-multi). Несём несколько — на ТОМ ЖЕ плече, что и первое,
## стопкой; суммарный вес ограничен carry_capacity. Топор виден только пока несём ОДНО бревно на
## левом плече; от двух и более — убран (заняты оба плеча). Скорость/прыжок режутся по сумме веса.
var _carried_logs: Array[FallingLog] = []
## Суммарный «рабочий» вес несомого (кг) — для лимита грузоподъёмности и замедления.
var _carry_total: float = 0.0
## Плечо несомой стопки (true — левое): задаёт ПЕРВОЕ бревно, остальные кладутся туда же.
var _carry_on_left: bool = true
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
## Бревно, которое таскаем ТЕЛЕКИНЕЗОМ (или null). Висит перед игроком, тянется к точке за прицелом.
var _manip_log: FallingLog = null
## Точка хвата В ЛОКАЛЕ бревна (куда смотрел прицел при захвате): от неё (относительно ЦМ) пляшет физика.
var _manip_grasp_local: Vector3 = Vector3.ZERO
## Дистанция удержания точки хвата перед камерой (м), зафиксирована при захвате.
var _manip_distance: float = 2.0
## Накопленное время «упора» (с): растёт, пока бревно отстало и почти не двигается; на пороге рвём захват.
var _manip_stuck_time: float = 0.0
## Где была точка хвата в начале окна подозрения на упор — по сдвигу от неё отличаем таскание от упора.
var _manip_stuck_anchor: Vector3 = Vector3.ZERO
## Множители скорости/прыжка от веса держимого телекинезом бревна (та же кривая, что у переноски):
## тащить «на расстоянии» тяжёлое так же тяжело — игрок медленнее и прыгает ниже.
var _manip_speed_mult: float = 1.0
var _manip_jump_mult: float = 1.0
## Удержание E для входа в телекинез (#manip): копим время с нажатия, на пороге берём бревно «на
## расстоянии». _e_consumed — порог уже сработал (отпускание E НЕ должно вызвать обычный тап-подбор).
var _e_holding: bool = false
var _e_hold_timer: float = 0.0
var _e_consumed: bool = false
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
## Топор убран (несём тяжёлое бревно на правом плече) — рубить нельзя.
var _axe_stowed: bool = false
## Наклон камеры от тяги тачки (#barrow-drag): x — тангаж (вперёд/назад), y — крен (вбок). Цель
## задаётся в _drive_barrow по отставанию, плавно сходится в _process.
var _barrow_lean: Vector2 = Vector2.ZERO
var _barrow_lean_target: Vector2 = Vector2.ZERO
## Наклон взгляда вверх/вниз (рад). Храним отдельно, чтобы кик камеры можно было
## накладывать поверх, не ломая ограничение обзора.
var _look_pitch: float = 0.0
## Текущая отдача камеры (рад): x — тангаж, y — рыскание, z — крен. Затухает к нулю в _process.
## Импульс отдачи при ударе добавляет компонент ChopController через add_camera_kick().
var _kick: Vector3 = Vector3.ZERO
## Остаток окна спотыкания (с): пока > 0, walk_locomotion ведёт игрока ПО ИНЕРЦИИ (#barrow-stumble).
var _stumble_timer: float = 0.0

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
## Компонент здоровья (узел-ребёнок Health): фасад take_damage() шлёт урон сюда.
@onready var _health: Node = $Health
## Машина состояний (узел-ребёнок): ей делегируем подсказку и контекстное E активного состояния.
@onready var _state_machine: Node = $StateMachine
## Корень меша-тела игрока: его позицию гасим вместе с камерой при переступе (см. _process).
## Сами конечности (руки/ноги) анимирует отдельный узел-компонент LimbAnimator (#9.3) — он
## читает состояние игрока через held_barrow()/dragged_log(). Тело скрыто от FP-камеры
## (shadows_only), поэтому анимацию видно по ТЕНИ игрока (и через фрикам, если вернуть видимость).
@onready var _model: Node3D = $Model
## База позиции тела — от неё гасим переступ так же, как камеру (#1: иначе торс «прыгал» в кадр).
var _model_base: Vector3 = Vector3.ZERO


func _ready() -> void:
	# Захватываем курсор при старте: мышь скрыта и привязана к окну.
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# v = sqrt(2*g*h): какая скорость вверх нужна, чтобы подняться на jump_height.
	var g: float = ProjectSettings.get_setting("physics/3d/default_gravity")
	_jump_velocity = sqrt(2.0 * g * jump_height)
	# Запоминаем «родную» локальную позицию камеры — от неё сглаживаем переступ (смещаем/возвращаем).
	_cam_base = camera.position
	_model_base = _model.position


## Фасад урона: внешний код (бревно при ударе, falling_log.gd) зовёт player.take_damage(),
## а считает HP/смерть компонент Health. Так публичный API игрока не изменился при выносе HP.
func take_damage(amount: float) -> void:
	_health.take_damage(amount)


# --- Публичный read-API для дочерних компонентов (LimbAnimator и будущих узлов). ---
# Player остаётся «диспетчером»: компоненты НЕ лезут в его приватные _barrow/_dragged напрямую,
# а спрашивают через эти геттеры — так состояние инкапсулировано и его легко переносить.

## Тачка в руках (или null).
func held_barrow() -> Wheelbarrow:
	return _barrow


## Бревно, которое таскаем телекинезом (или null) — по нему машина состояний включает режим захвата.
func manipulated_log() -> FallingLog:
	return _manip_log


## Бревно на волоке (или null).
func dragged_log() -> FallingLog:
	return _dragged


## Несомое на плече бревно (или null) — рубка бьёт слабее, если рука занята им.
func carried_log() -> FallingLog:
	if _carried_logs.is_empty():
		return null
	return _carried_logs.back()


## Сколько брёвен несём сейчас.
func carried_count() -> int:
	return _carried_logs.size()


## Влезет ли ещё одно бревно весом w в остаток грузоподъёмности (и мы уже что-то несём).
func can_carry_more(w: float) -> bool:
	return not _carried_logs.is_empty() and _carry_total + w <= carry_capacity


## Можно ли сейчас рубить топором: топор в руке (не убран) и мы не на волоке. Решает Player,
## т.к. зависит от его состояния; ChopController спрашивает это перед началом замаха.
func can_chop() -> bool:
	return not _axe_stowed and _dragged == null


## Добавить импульс отдачи к камере (зовёт ChopController при попадании). Накопление и затухание
## _kick, и его наложение на камеру — в _process игрока (вместе с наклоном взгляда и free-look тачки).
func add_camera_kick(delta_kick: Vector3) -> void:
	_kick += delta_kick


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

	# E — контекстное действие. Если целимся в ЛЁГКОЕ бревно налегке, нажатие НЕ срабатывает сразу:
	# короткий тап → взять на плечо (как раньше), удержание → телекинез (#manip, см. _process/release).
	# Во всех прочих случаях (тачка, тяжёлое бревно, занятые руки) E действует сразу по нажатию.
	if event.is_action_pressed("interact") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if _manip_log != null:
			# Захват ЗАФИКСИРОВАН (висит без зажатой E) — нажатие E его ОТПУСКАЕТ.
			_stop_manipulate()
		elif _can_begin_manip_hold():
			_e_holding = true
			_e_hold_timer = 0.0
			_e_consumed = false
		else:
			_toggle_carry()
	elif event.is_action_released("interact") and _e_holding:
		# Отпустили активирующее удержание: успели захватить (порог прошёл) → ФИКСИРУЕМ, бревно остаётся
		# висеть и без кнопки; не дошли до порога → это был быстрый тап = взять на плечо.
		if _manip_log == null and not _e_consumed:
			_toggle_carry()
		_e_holding = false
		_e_consumed = false
		_e_hold_timer = 0.0

	# Esc открывает меню паузы — этим ведает DayUI (перехватывает ui_cancel до игрока). Здесь только
	# повторный захват курсора кликом по окну (например, после Alt-Tab), когда игра НЕ на паузе.
	if event is InputEventMouseButton and event.pressed \
			and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	# Рубка (зажать/отпустить ЛКМ) обрабатывает компонент ChopController в своём _unhandled_input.


func _process(delta: float) -> void:
	# Отдача затухает к нулю; итоговый наклон камеры = взгляд + кик. С тачкой добавляем free-look
	# по рысканью (камера осматривается в секторе ±barrow_yaw_limit вокруг носа тачки, #5); без
	# тачки рысканье камеры = только кик (тело уже повёрнуто мышью).
	_kick = _kick.lerp(Vector3.ZERO, clampf(kick_recover_speed * delta, 0.0, 1.0))
	# Наклон «тачка тянет» (#barrow-drag): пока держим тачку и отстаём — кренимся в сторону тяги,
	# будто она волочёт за собой. Без тачки цель — 0, наклон плавно уходит. Это реализм вместо рывков.
	if _barrow == null:
		_barrow_lean_target = Vector2.ZERO
	_barrow_lean = _barrow_lean.lerp(_barrow_lean_target, clampf(barrow_lean_smooth * delta, 0.0, 1.0))
	var cam_yaw := _barrow_cam_yaw if _barrow != null else 0.0
	camera.rotation = Vector3(_look_pitch + _kick.x + _barrow_lean.x,
			cam_yaw + _kick.y, _kick.z + _barrow_lean.y)

	# Сглаживание переступа: в момент телепорта тела на уступ камеру визуально оставили на месте
	# (накопили смещение, обратное прыжку — и вверх, и вперёд), теперь плавно гасим его к нулю. Так
	# подъём выглядит как мягкое всплытие, а не рывок-«склейка кадров» ни по высоте, ни вперёд (#4).
	_step_offset = _step_offset.lerp(Vector3.ZERO, clampf(step_smooth_speed * delta, 0.0, 1.0))
	camera.position = _cam_base + _step_offset
	# То же смещение даём ТЕЛУ: иначе при телепорте на уступ торс прыгает вверх вместе с телом, а
	# камеру держим внизу — и торс на пару кадров перекрывает пол-экрана (#1). Сдвигая Model на тот же
	# _step_offset, тело визуально остаётся на месте рядом с камерой и «всплывает» так же мягко.
	_model.position = _model_base + _step_offset

	_update_prompt()

	# Удержание E → телекинез (#manip): копим время с нажатия; на пороге, если всё ещё целимся в лёгкое
	# бревно налегке — берём его «на расстоянии». Порог отмечаем _e_consumed, чтобы отпускание E потом НЕ
	# вызвало обычный тап-подбор (тап = только быстрое нажатие-отпускание короче manip_hold_time).
	if _e_holding and not _e_consumed and _manip_log == null:
		_e_hold_timer += delta
		if _e_hold_timer >= manip_hold_time:
			_e_consumed = true
			var fl := _look_pickup_log(true)
			if fl != null and fl.get_weight() <= manip_capacity and _is_idle():
				_start_manipulate(fl)


# Подсказка под прицелом: что сделает E прямо сейчас. Тексты — через tr() (ключи в
# localization/translations.csv), {kg} подставляется форматированием — легко переводить.
func _update_prompt() -> void:
	if not prompt:
		return
	# Текст подсказки даёт активное состояние (Idle/Carry/Drag/Barrow), Player только центрирует.
	_set_prompt(_state_machine.active().prompt_text())


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


# E (interact): контекстное действие активного состояния (взять/положить/бросить). Сам разбор —
# в узле состояния (handle_interact), Player только освежает луч прицела и делегирует.
func _toggle_carry() -> void:
	# Один пересчёт луча на всё контекстное E (и бревно, и тачка под прицелом — свежие).
	chop_ray.force_shapecast_update()
	_state_machine.active().handle_interact()


## Руки свободны и ничего не держим (idle) — для выбора, действовать по нажатию или по тапу/удержанию.
func _is_idle() -> bool:
	return _barrow == null and _dragged == null and _carried_logs.is_empty() and _manip_log == null


## Лечь спать (E по кровати, см. state_idle). Завершает день — DayNight поднимет экран итогов.
func request_sleep() -> void:
	DayNight.request_sleep()


# Стоит ли ОТЛОЖИТЬ нажатие E (тап/удержание): только если налегке целимся в ЛЁГКОЕ бревно. Тогда тап
# = взять на плечо, удержание = телекинез. Иначе (тачка/тяжёлое/занятые руки) E срабатывает сразу.
func _can_begin_manip_hold() -> bool:
	if not _is_idle():
		return false
	var fl := _look_pickup_log(true)
	return fl != null and fl.get_weight() <= manip_capacity


# Включаем телекинез: точка хвата = куда смотрел прицел (тонкий луч в бревно). Запоминаем её В ЛОКАЛЕ
# бревна и дистанцию удержания; дальше update_manipulation каждый физкадр тянет её к цели за прицелом.
func _start_manipulate(fl: FallingLog) -> void:
	var origin := camera.global_position
	var dir := -camera.global_transform.basis.z
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(origin, origin + dir * 4.0)
	q.exclude = [get_rid()]
	q.collision_mask = 4  # только бревно (слой falling_tree)
	var hit := space.intersect_ray(q)
	var hit_point: Vector3 = (hit["position"] as Vector3) if (not hit.is_empty() and hit.get("collider") == fl) else fl.global_position
	_manip_log = fl
	_manip_grasp_local = fl.global_transform.affine_inverse() * hit_point
	_manip_distance = clampf(origin.distance_to(hit_point), manip_distance_min, manip_distance_max)
	_manip_stuck_time = 0.0
	# Вес держимого бревна замедляет/сажает прыжок так же, как при переноске (та же кривая по весу).
	var w := fl.get_weight()
	_manip_speed_mult = _carry_speed_for(w)
	_manip_jump_mult = _carry_jump_for(w)
	# Топор в руках не нужен (и рубить во время захвата нельзя): _axe_stowed заодно гасит can_chop.
	_axe_stowed = true
	axe.visible = false
	fl.begin_manipulate(self, manip_angular_damp, manip_hold_mass)


# Отпускаем телекинез: бревно снова обычное физтело (упадёт/осядет), коллизию с игроком возвращаем.
func _stop_manipulate() -> void:
	if _manip_log != null and is_instance_valid(_manip_log):
		_manip_log.end_manipulate(self)
	_manip_log = null
	# Возвращаем топор в руку (и рубку).
	_axe_stowed = false
	axe.visible = true


## Мировая точка хвата держимого телекинезом бревна (или null) — к ней аниматор тянет кисти рук.
func manip_grasp_world() -> Variant:
	if _manip_log == null or not is_instance_valid(_manip_log):
		return null
	return _manip_log.to_global(_manip_grasp_local)


## Множитель скорости от веса держимого телекинезом бревна (1 — налегке).
func manip_speed_mult() -> float:
	return _manip_speed_mult


## Множитель высоты прыжка от веса держимого телекинезом бревна (1 — налегке).
func manip_jump_mult() -> float:
	return _manip_jump_mult


# Физика захвата (#manip): тянем точку хвата к цели перед камерой пружиной В ТОЧКЕ ХВАТА. Силу прикладываем
# как центральную + момент r×F относительно ЦМ — поэтому взятое за край бревно гравитация разворачивает
# центром вниз (висит стабильно), а взятое за центр (r≈0, момента нет) — свободно болтается. Зовёт состояние.
func update_manipulation(delta: float) -> void:
	var fl := _manip_log
	if fl == null or not is_instance_valid(fl):
		_stop_manipulate()
		return
	var target := camera.global_position + (-camera.global_transform.basis.z) * _manip_distance
	var com := fl.to_global(Vector3(0.0, fl.body_center_y(), 0.0))
	var grasp := fl.to_global(_manip_grasp_local)
	var r := grasp - com
	var vel_at := fl.linear_velocity + fl.angular_velocity.cross(r)
	var to_t := target - grasp
	var dist := to_t.length()
	# Срыв захвата ТОЛЬКО при реальном упоре: бревно отстало от цели (dist) И за окно времени почти не
	# сдвинулось (дрожит на месте у стены/под ногами). Резкий мах/таскание двигают хват на manip_break_progress
	# и больше → окно сбрасывается, из рук не выпадает. Стоячий упор за manip_break_time → отпускаем.
	if dist > manip_break_distance:
		if _manip_stuck_time <= 0.0:
			_manip_stuck_anchor = grasp
		_manip_stuck_time += delta
		if grasp.distance_to(_manip_stuck_anchor) >= manip_break_progress:
			_manip_stuck_time = 0.0       # заметно продвинулись — это таскание, не упор
		elif _manip_stuck_time >= manip_break_time:
			_stop_manipulate()
			return
	else:
		_manip_stuck_time = 0.0
	var accel := to_t * manip_stiffness - vel_at * manip_damping
	accel = accel.limit_length(manip_max_accel)
	var force := accel * fl.mass
	fl.sleeping = false
	fl.apply_central_force(force)
	fl.apply_torque(r.cross(force))


# Берём бревно в руки на плечо. Лёгкое (< доли предела) — на левое, топор в правой руке;
# тяжёлое — на правое, топор убираем (рубить нельзя, пока несём).
func _start_carry(log: FallingLog, weight: float) -> void:
	# ПЕРВОЕ бревно стопки: оно задаёт плечо (лёгкое — левое, топор в правой руке; тяжёлое — правое).
	_carried_logs.clear()
	_carry_total = 0.0
	_carry_on_left = weight < carry_capacity * shoulder_left_fraction
	_add_carry(log, weight)


# Докладываем ЕЩЁ одно бревно на ТО ЖЕ плечо стопкой (#carry-multi). Вызывается из Carry, когда
# навёлся на посильное свободное бревно и оно влезает в остаток грузоподъёмности (can_carry_more).
func _add_carry(log: FallingLog, weight: float) -> void:
	# Вешаем на ТЕЛО (не на камеру, #carry-level): тело только рыщет → бревно остаётся горизонтальным
	# при взгляде вверх/вниз и не наклоняется в камеру. Реальную позу зададим в _reposition_carried.
	log.pick_up(self, Transform3D.IDENTITY)
	_carried_logs.append(log)
	_carry_total += weight
	_reposition_carried()
	_refresh_carry_visuals()


# Раскладка несомых брёвен по СЕЧЕНИЮ связки на плече (#carry-multi): 1 — по центру, 2 — рядом,
# 3 — ТРЕУГОЛЬНИКОМ (два снизу, одно сверху), 4+ — рядами по два. Пересобираем ВСЮ стопку при каждом
# добавлении/снятии, чтобы связка всегда была симметрична на плече, а не «лесенкой».
func _reposition_carried() -> void:
	# Раскладку считаем по РЕАЛЬНЫМ радиусам брёвен (#carry-spacing): тонкие — близко, толстые —
	# раздвинуты, чтобы соседние касались, а не висели с зазором / не влезали друг в друга.
	var radii: Array = []
	for log in _carried_logs:
		radii.append((log as FallingLog).get_radius())
	var layout := _carry_layout(radii)
	for i in _carried_logs.size():
		var log := _carried_logs[i] as FallingLog
		log.transform = _shoulder_pose(_carry_on_left, layout[i], log.body_center_y())


# Смещения (вбок, вверх) в сечении связки для каждого бревна, считая по их РАДИУСАМ (#carry-spacing):
# соседние брёвна касаются (расстояние центров = сумма радиусов), поэтому тонкие лежат плотно, а
# толстые раздвинуты, а не влезают друг в друга.
func _carry_layout(radii: Array) -> Array:
	var n := radii.size()
	if n <= 1:
		return [Vector2.ZERO]
	if n == 2:
		# Два бревна — ОДНО НАД ДРУГИМ (#1): центры по вертикали на сумму радиусов (касаются).
		var d: float = (float(radii[0]) + float(radii[1])) * 0.5
		return [Vector2(0.0, -d), Vector2(0.0, d)]
	# Для треугольника/рядов берём средний радиус (брёвна обычно близкой толщины).
	var r := 0.0
	for rr in radii:
		r += float(rr)
	r = r / float(n)
	if n == 3:
		# Треугольник: два снизу (центры на 2r по горизонтали), одно сверху в ложбинке. Центроид
		# опускаем, чтобы связка сидела на плече серединой. Высота — r·√3, центроид — на трети.
		var c := r * 0.5774  # r/√3
		return [Vector2(-r, -c), Vector2(r, -c), Vector2(0.0, 2.0 * c)]
	# 4 и больше — ряды по два, снизу вверх, шаг = диаметр.
	var arr: Array = []
	for i in n:
		var col := -r if (i % 2 == 0) else r
		var row := i / 2
		arr.append(Vector2(col, float(row) * 2.0 * r))
	return arr


# Пересчёт замедления/прыжка по суммарному весу и видимости топора. Топор в руке только когда несём
# РОВНО ОДНО бревно на ЛЕВОМ плече; от двух брёвен (или одно на правом) — убран (заняты оба плеча).
func _refresh_carry_visuals() -> void:
	_carry_speed_mult = _carry_speed_for(_carry_total)
	_carry_jump_mult = _carry_jump_for(_carry_total)
	var axe_in_hand := _carried_logs.size() == 1 and _carry_on_left
	_axe_stowed = not axe_in_hand
	axe.visible = axe_in_hand


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
		if (c as Node).is_in_group("bed"):
			return {"type": "bed", "bed": c}
		if c is Wheelbarrow:
			return {"type": "barrow", "barrow": c}
		if c is FallingLog and (c as Node).is_in_group("pickup_log"):
			var fl := c as FallingLog
			# «Накрытое» бревно (сверху лежит другой кусок) обычно брать нельзя — иначе тащили бы всю
			# кучу. НО лёгкое, влезающее в руку (≤ carry_capacity), достаём даже из-под низа кучи —
			# мелкие полешки можно выдёргивать снизу. Тяжёлое (только волоком) — по-прежнему лишь сверху.
			if fl.is_covered() and fl.get_weight() > carry_capacity:
				continue
			# ВОЛОК (тяжёлое бревно) ставит игрока у схваченного торца — если там нет опоры (бревно
			# свисает концом с обрыва), не предлагаем взять: иначе игрок «брал» висящий конец с края и
			# тащил вниз (#reach). Лёгкое (в руки на плечо) игрока не двигает — его не проверяем.
			if fl.get_weight() > carry_capacity and not _drag_lands_on_ground(fl):
				continue
			return {"type": "log", "log": fl}
	return {}


# Будет ли игрок на ТВЁРДОЙ земле, если возьмёт это бревно на волок (#reach). Волок ставит игрока у
# БЛИЖНЕГО торца, отступив на длину рук вдоль бревна (та же поза, что в _start_drag) — там и щупаем
# опору лучом вниз. Нет земли в пределах drag_ground_drop под этой точкой → бревно свисает над
# обрывом, волок начинать нельзя.
func _drag_lands_on_ground(fl: FallingLog) -> bool:
	var a := fl.global_position                                   # один торец (локальный 0)
	var b := fl.to_global(Vector3(0.0, fl.get_length(), 0.0))     # другой торец
	var near := a if global_position.distance_to(a) <= global_position.distance_to(b) else b
	var far := b if near == a else a
	var dir := far - near
	dir.y = 0.0
	if dir.length() > 0.01:
		dir = dir.normalized()
	var stand := Vector3(near.x - dir.x * drag_grab_distance, global_position.y,
			near.z - dir.z * drag_grab_distance)
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(stand + Vector3.UP * 0.3,
			stand - Vector3.UP * drag_ground_drop, 1 | 4 | 16)
	q.exclude = [get_rid(), fl.get_rid()]
	return not space.intersect_ray(q).is_empty()


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
	# ПРИВОДИМ ТАЧКУ К ИГРОКУ (#barrow-grab): где бы она ни застряла (на боку, заклинило в геометрии,
	# откуда не достать — только пинать топором), при взятии ставим её ПЕРЕД игроком по его взгляду и
	# плавно выпрямляем носом ОТ игрока. Игрок остаётся на месте, где нажал E. Раньше телепортировали
	# ИГРОКА к тачке — и он сам оказывался в недоступном месте вместе с ней.
	var pf := -global_transform.basis.z
	pf.y = 0.0
	if pf.length() < 0.01:
		pf = Vector3.FORWARD
	pf = pf.normalized()
	# Ставим тачку на УРОВЕНЬ ИГРОКА перед ним (#barrow-grab). Игрок стоит на твёрдой земле, поэтому
	# его высота — заведомо досягаемое место. НЕ ищем землю лучом вниз: у края обрыва он нашёл бы землю
	# ВНИЗУ за уступом и ронял тачку под обрыв (откуда её снова не достать). Лёгкий подъём — сядет на
	# колёса; телепорт через _integrate_forces (надёжно для Jolt-тела), затем выпрямление носом от игрока.
	var spot := global_position + pf * (barrow.grab_distance + 0.5)
	barrow.teleport_to(Vector3(spot.x, global_position.y + 0.3, spot.z))
	barrow.grab(atan2(-pf.x, -pf.z))
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


# Спотыкание (#barrow-stumble): когда тачку «вырвало» из рук (авто-отпускание), игрок по инерции
# клюёт ВПЕРЁД (в сторону dir). Даём рывок скорости + просадку/клевок камеры — всё через штатные
# затухающие системы (_step_offset для позиции камеры, _kick для наклона), поэтому само сглаживается.
# Есть ли земля впереди по направлению dir на расстоянии dist (луч вниз из точки впереди). Нужно
# спотыканию (#barrow-inertia): чтобы инерция не унесла игрока ЗА ТАЧКОЙ с обрыва — у края гасим ход.
func _ground_ahead(dir: Vector3, dist: float) -> bool:
	var space := get_world_3d().direct_space_state
	var from := global_position + dir * dist + Vector3.UP * 0.3
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 1.2)
	q.exclude = [get_rid()]
	q.collision_mask = 1 | 4 | 16
	return not space.intersect_ray(q).is_empty()


func _stumble(dir: Vector3, strength: float = 1.0) -> void:
	strength = maxf(strength, 0.1)
	var f := Vector3(dir.x, 0.0, dir.z)
	if f.length() > 0.01:
		f = f.normalized()
		velocity.x += f.x * stumble_speed * strength
		velocity.z += f.z * stumble_speed * strength
	# ПОТОЛОК инерции (#barrow-inertia): сохранённая скорость следования могла быть большой (до ~8 м/с),
	# и глайд читался как резкий рывок. Зажимаем горизонт до stumble_max_speed — «несёт», но не швыряет.
	var hv := Vector3(velocity.x, 0.0, velocity.z)
	if hv.length() > stumble_max_speed:
		hv = hv.normalized() * stumble_max_speed
		velocity.x = hv.x
		velocity.z = hv.z
	# Окно потери управления: пока идёт, walk_locomotion не сбрасывает скорость по вводу — инерция несёт.
	_stumble_timer = stumble_time
	# Клевок ВПЕРЁД (позиция −Z и взгляд вниз), масштаб по силе рывка. БЕЗ вертикального подброса (−Y) и
	# случайного крена — они читались как «тряска смерти» (#barrow-drag). В _process гасятся к нулю.
	_step_offset += Vector3(0.0, 0.0, -stumble_forward * strength)
	_kick += Vector3(-deg_to_rad(stumble_pitch_deg * strength), 0.0, 0.0)


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
	# Грузим ВЕРХНЕЕ бревно стопки и снимаем его с плеча; остальные продолжаем нести (#carry-multi).
	var top := _carried_logs.pop_back() as FallingLog
	_carry_total = maxf(0.0, _carry_total - top.get_weight())
	barrow.deposit_log(top, _barrow_aim_point(barrow), lay)
	_after_carry_removed()


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
		# Тачка ухнула с обрыва — игрока РЕЗКО клюёт вперёд (#barrow-stumble). Сила больше обычного
		# (cliff_mult) и растёт с грузом: гружёная тачка, срываясь вниз, дёргает сильнее. Груз берём
		# ДО _stop_barrow (она обнулит ссылку).
		var cliff_str := barrow_stumble_cliff_mult * (0.6 + _barrow.load_factor())
		_stop_barrow()
		_stumble(bfwd, cliff_str)
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
			# НЕ глушим ход в ноль, а оставляем МАЛУЮ долю (#barrow-struggle): застрявшую тачку можно
			# медленно «выработать» с усилием (продавить/вытолкать), а не просто встать намертво.
			fwd_in *= barrow_struggle_mult
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
				# Поворот тоже не глушим, а оставляем долю (#barrow-struggle) — рулём можно медленно
				# выкручивать застрявшую тачку.
				yaw_in *= barrow_struggle_mult
	# Тачку ведём с ИНЕРЦИЕЙ: разгон/торможение/доворот считает сама drive() по delta (#5b).
	_barrow.drive(fwd_in, yaw_in, spd, turn_spd, delta)
	# РЕЕЛ-ИН (#barrow-reel): тянем тачку к рукам, если она отстала/упала с уступа. При нормальной езде
	# точка хвата у рук → зазор мал → тяги нет; срабатывает, только когда тачку «потеряли» — тогда её
	# можно выволочь назад/вверх (а не обходить или пинать топором).
	var hand := global_position + bfwd * _barrow.grab_distance + Vector3.UP * 0.88
	_barrow.reel_toward(hand, barrow_reel_gain, barrow_reel_max, barrow_reel_slack)

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
	# Наклон «тачка тянет» (#barrow-drag): цель тангажа/крена по ОТСТАВАНИЮ в локале тела. Тачка ушла
	# вперёд (−Z) → клюём вперёд; вбок → крен (это и есть «занос» в поворотах). База МАЛЕНЬКАЯ и с
	# грузом растёт лишь до 150% (а не в максимум): пустая — еле заметно, полная — в 1.5 раза сильнее.
	var lt := global_transform.basis.inverse() * to_t
	var lean_w := 1.0 + 0.5 * _barrow.load_factor()  # база … 1.5×база на полном грузе
	_barrow_lean_target = Vector2(
			clampf(lt.z * barrow_lean_gain * lean_w, -barrow_lean_max, barrow_lean_max),
			clampf(lt.x * barrow_lean_gain * lean_w, -barrow_lean_max, barrow_lean_max))
	# Цель скорости ПРОПОРЦИОНАЛЬНА избытку люфта (пружина с потолком), а НЕ «закрыть слэк за один
	# кадр» (#barrow-follow): мгновенное закрытие давало рывки «как провод». В пределах люфта цель — 0.
	var desired_v := Vector3.ZERO
	if dist > 0.0001 and slack > 0.0:
		desired_v = (to_t / dist) * minf(slack * barrow_follow_gain, spd + 4.0)
	# Скорость к цели ведём ПЛАВНО (демпфирование) — без скачков «полный газ ↔ ноль».
	var fk := clampf(barrow_follow_smooth * delta, 0.0, 1.0)
	velocity.x = lerpf(velocity.x, desired_v.x, fk)
	velocity.z = lerpf(velocity.z, desired_v.z, fk)
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

	# Жёсткий поводок move_and_collide УБРАН (#barrow-drag): второе перемещение за кадр поверх
	# move_and_slide давало вертикальный джиттер/подброс («тряска смерти»). Теперь игрок тянется за
	# тачкой ТОЛЬКО плавной пружиной по скорости (выше) + честным move_and_slide. Упёрся и отстал на
	# barrow_max_gap — отпускаем тачку (ниже), как и раньше.
	# АВТО-ОТПУСКАНИЕ при отставании (#2): если игрок ДАЛЬШЕ barrow_max_gap
	# от точки за ручками — значит он упёрся (уступ/препятствие), а тачка уехала вперёд по WASD. Чтобы
	# она не «убегала на дистанционном управлении», отпускаем её — игрок остаётся стоять, тачка свободна.
	var final_gap := Vector3(target.x - global_position.x, 0.0,
			target.z - global_position.z).length()
	# Пока тачка ВЫПРЯМЛЯЕТСЯ (#2), грабпойнт сильно гуляет (доворот на 90°) — НЕ отпускаем её по
	# разрыву поводка, иначе плавное вставание на колёса срывалось бы на полпути.
	if final_gap > barrow_max_gap and not _barrow.is_righting():
		# Тачку «вырвало» из рук (игрок отстал) — споткнулись ВПЕРЁД, к ушедшей тачке (#barrow-stumble).
		# Сила растёт с грузом (тяжёлая тачка дёргает сильнее). Груз берём ДО _stop_barrow.
		var over_str := 0.6 + _barrow.load_factor()
		var stumble_dir := Vector3(target.x - global_position.x, 0.0, target.z - global_position.z)
		_stop_barrow()
		_stumble(stumble_dir, over_str)


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
	# Кладём на землю ВЕРХНЕЕ бревно стопки; остальные продолжаем нести (#carry-multi).
	var top := _carried_logs.pop_back() as FallingLog
	_carry_total = maxf(0.0, _carry_total - top.get_weight())
	top.drop(get_tree().current_scene, drop_pos, forward)
	_after_carry_removed()


# Общий хвост после снятия одного бревна со стопки (брошено/погружено): если что-то ещё несём —
# пересчитываем замедление/топор, иначе сбрасываем переноску в «налегке».
func _after_carry_removed() -> void:
	if _carried_logs.is_empty():
		_carry_total = 0.0
		_carry_speed_mult = 1.0
		_carry_jump_mult = 1.0
		_axe_stowed = false
		axe.visible = true
	else:
		_reposition_carried()  # пересобрать оставшиеся (#carry-multi): снова центр/ряд/треугольник
		_refresh_carry_visuals()


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
	var ex: Array[RID] = [get_rid()]
	for cl in _carried_logs:
		ex.append(cl.get_rid())
	q.exclude = ex
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
# Поза несомого бревна В ЛОКАЛЕ ТЕЛА (а не камеры, #carry-level): тело только рыщет, не наклоняется,
# поэтому бревно лежит ГОРИЗОНТАЛЬНО (параллельно земле) при любом взгляде вверх/вниз и не «въезжает»
# в камеру. Лежит вдоль тела, заброшено за плечо назад. offset (м) — смещение в СЕЧЕНИИ связки
# (вбок X / вверх Y тела) для раскладки нескольких брёвен. center_y — Y центра меша в локале бревна.
func _shoulder_pose(on_left: bool, offset: Vector2, center_y: float) -> Transform3D:
	var side := -carry_side if on_left else carry_side
	var basis := Basis(Vector3(1.0, 0.0, 0.0), deg_to_rad(90.0))  # ось бревна (Y) → назад тела, горизонт
	# Точка, где должен оказаться ЦЕНТР бревна: у плеча, сбоку (X тела) и вверх (Y тела) по offset.
	var anchor := Vector3(side, carry_height, carry_back) + Vector3(offset.x, offset.y, 0.0)
	# origin тела бревна — у нижнего торца; сдвигаем так, чтобы ЦЕНТР меша (center_y) попал в anchor.
	return Transform3D(basis, anchor - basis * Vector3(0.0, center_y, 0.0))


# ТОНКИЙ примитив наземной локомоции: гравитация, WASD, бег/прыжок, move_and_slide, степ-ап,
# расталкивание тел. ЧТО разрешено и насколько медленно — решает вызывающее состояние и передаёт
# параметрами (поэтому здесь больше нет проверок _dragged/_carried):
#  • speed_mult — итоговый множитель скорости (вес переноски / коэффициент волока / 1.0 налегке);
#  • can_run    — разрешён ли бег (Shift); волок — нет;
#  • can_jump   — разрешён ли прыжок; волок — нет;
#  • jump_mult  — множитель высоты прыжка (просадка от веса; 1.0 налегке).
# Тачка сюда НЕ заходит — у неё свой полный режим _drive_barrow (BarrowState). Волок после движения
# ещё тянет/клампит бревно — это делает сам DragState, тут общего кода нет.
func walk_locomotion(delta: float, speed_mult: float, can_run: bool,
		can_jump: bool, jump_mult: float) -> void:
	var on_floor := is_on_floor()

	# СПОТЫКАНИЕ (#barrow-stumble): тачку только что «вырвало» из рук. Пока идёт окно, ВВОД НЕ перебивает
	# горизонтальную скорость — игрока несёт по инерции вперёд, и она ПЛАВНО гаснет (stumble_friction),
	# а не обнуляется за кадр жёстким move_toward обычной ходьбы. Так чувствуется рывок/потеря равновесия.
	if _stumble_timer > 0.0:
		_stumble_timer -= delta
		if not on_floor:
			velocity += get_gravity() * delta
		var hv := Vector3(velocity.x, 0.0, velocity.z)
		# НЕ даём сорваться ЗА ТАЧКОЙ В ПРОПАСТЬ (#barrow-inertia): если по ходу инерции впереди НЕТ
		# земли (обрыв), резко гасим горизонт — игрок «ловит равновесие» у края, но инерция уже пронесла
		# его чуть вперёд. На ровной земле инерция плавно затухает (stumble_friction) — ощущение «несёт».
		if on_floor and hv.length() > 0.1 and not _ground_ahead(hv.normalized(), 0.5):
			velocity.x = 0.0
			velocity.z = 0.0
		else:
			var fr := clampf(stumble_friction * delta, 0.0, 1.0)
			velocity.x = lerpf(velocity.x, 0.0, fr)
			velocity.z = lerpf(velocity.z, 0.0, fr)
		_pre_move_pos = global_position
		_wish_speed = 0.0
		move_and_slide()
		return

	# Гравитация в воздухе (значение из настроек проекта).
	if not on_floor:
		velocity += get_gravity() * delta

	var direction := _wish_move_dir()

	var speed := walk_speed
	if can_run and Input.is_action_pressed("run"):
		speed *= run_multiplier
	speed *= speed_mult

	if on_floor:
		# На земле — мгновенная отзывчивость, прыжок.
		if direction:
			velocity.x = direction.x * speed
			velocity.z = direction.z * speed
		else:
			velocity.x = move_toward(velocity.x, 0.0, speed)
			velocity.z = move_toward(velocity.z, 0.0, speed)
		# is_action_PRESSED (а не just_pressed): пока пробел зажат, прыжок повторяется
		# сразу в первый кадр на земле — автопрыжок без паузы между прыжками (как в Minecraft).
		if can_jump and Input.is_action_pressed("jump"):
			velocity.y = _jump_velocity * jump_mult
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


# Желаемое направление хода из WASD в мировых координатах (нормализованное; ноль = нет ввода).
func _wish_move_dir() -> Vector3:
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	return (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()


## Множители переноски (вес бревна на плече) — состояние Carry передаёт их в walk_locomotion.
func carry_speed_mult() -> float:
	return _carry_speed_mult


func carry_jump_mult() -> float:
	return _carry_jump_mult


## Итоговый множитель скорости ВОЛОКА с учётом направления (для DragState). Толкать бревно ВДОЛЬ
## него от себя (гнать дальний конец вперёд) — почти нельзя (drag_push_speed_mult). ВАЖНО: «толкание»
## считаем по ОСИ БРЕВНА, а не по взгляду — ось берём из самого бревна, поэтому поворот камеры
## проверку не обманет. Иначе — обычный коэффициент волока по массе (_drag_speed_mult).
func drag_speed_factor() -> float:
	if _dragged == null:
		return 1.0
	var dir := _wish_move_dir()
	var axis := _dragged.tail_point_world() - _dragged.grab_point_world()
	axis.y = 0.0
	if dir.length() > 0.01 and axis.length() > 0.01 and dir.dot(axis.normalized()) > 0.3:
		return drag_push_speed_mult
	return _drag_speed_mult


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
