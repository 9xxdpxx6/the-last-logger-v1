extends Node

## Драйвер неба и освещения по времени суток. Висит на узле DayCycle в world.tscn, слушает
## DayNight.time_changed и каждый сдвиг времени крутит солнце + красит небо/окружение. Чисто
## визуальный слой: вся логика дня — в DayNight. Все «крутилки» вынесены в @export для Инспектора.

## Узлы сцены, которыми крутим (задаются в Инспекторе DayCycle).
@export var sun_path: NodePath
@export var env_path: NodePath

## Высота солнца над горизонтом в ПОЛДЕНЬ (градусы). Ночью солнце уходит под горизонт (−эта высота).
@export var noon_angle_deg: float = 70.0
## Яркость солнца днём и ночью (ночью — слабый «лунный» свет, чтобы не было кромешной тьмы).
@export var day_energy: float = 1.8
@export var night_energy: float = 0.15
## Цвет верха неба: день / сумерки (рассвет-закат) / ночь.
@export var day_sky_top: Color = Color(0.38, 0.55, 0.85)
@export var dusk_sky_top: Color = Color(0.85, 0.45, 0.22)
@export var night_sky_top: Color = Color(0.03, 0.04, 0.09)
## Энергия рассеянного света (ambient) днём / ночью.
@export var day_ambient: float = 0.4
@export var night_ambient: float = 0.12

@onready var _sun: DirectionalLight3D = get_node_or_null(sun_path)
@onready var _env_holder: WorldEnvironment = get_node_or_null(env_path)
var _sky_mat: ProceduralSkyMaterial = null


func _ready() -> void:
	if _env_holder != null and _env_holder.environment != null and _env_holder.environment.sky != null:
		_sky_mat = _env_holder.environment.sky.sky_material as ProceduralSkyMaterial
	DayNight.time_changed.connect(_apply)
	_apply(DayNight.time_of_day)


func _apply(t: float) -> void:
	t = clampf(t, 0.0, 1.0)
	# Полные сутки: day_factor = −1 в полночь, +1 в полдень. Восход ~06:00 (t=0.25), закат ~18:00 (0.75).
	var day_factor := sin((t - 0.25) * TAU)
	# Доля «светлоты» 0..1: 0 глубокой ночью, 1 днём, с плавным рассветом/закатом у горизонта.
	var light_amt := smoothstep(-0.15, 0.25, day_factor)
	# Солнце двигаем ПЛАВНО каждый кадр. Дрожь теней лечим не остановкой солнца, а мягкими тенями
	# высокого разрешения (см. DirectionalLight3D + project.godot: размер атласа и soft-фильтр).
	if _sun != null:
		var elev := day_factor * deg_to_rad(noon_angle_deg)  # высота над горизонтом (ночью < 0 — под землёй)
		var yaw := t * TAU                                    # азимут по кругу за сутки
		_sun.rotation = Vector3(-elev, yaw, 0.0)
		_sun.light_energy = lerpf(night_energy, day_energy, light_amt)
	# Цвет неба: ночь → сумерки → день (симметрично на рассвете и закате).
	var sky_col: Color
	if light_amt < 0.5:
		sky_col = night_sky_top.lerp(dusk_sky_top, smoothstep(0.05, 0.5, light_amt))
	else:
		sky_col = dusk_sky_top.lerp(day_sky_top, smoothstep(0.5, 0.85, light_amt))
	if _sky_mat != null:
		_sky_mat.sky_top_color = sky_col
		_sky_mat.sky_horizon_color = sky_col.lerp(Color(0.7, 0.7, 0.7), 0.3)
	if _env_holder != null and _env_holder.environment != null:
		_env_holder.environment.ambient_light_energy = lerpf(night_ambient, day_ambient, light_amt)
