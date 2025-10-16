class_name stageConfig extends Resource

var loadedConfig: int = 0

enum stages {
	None = 0,
	AC_London = 1
}

func reset(_layers: Array, animations: Array, _objects: Array):
	for anim in animations:
		anim.enabled = true

func load_config(id: int, layers: Array, animations: Array, objects: Array):
	loadedConfig = id
	reset(layers,animations,objects)
	match id:
		stages.AC_London:
			if animations.size() >= 3:
				animations[2].enabled = false
		_:
			return
