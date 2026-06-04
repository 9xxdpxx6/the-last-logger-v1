extends CPUParticles3D

## Одноразовый всплеск щепок. Сам себя удаляет, когда залп отыграл, чтобы в сцене
## не копились отработанные узлы частиц.

func _ready() -> void:
	emitting = true
	finished.connect(queue_free)
