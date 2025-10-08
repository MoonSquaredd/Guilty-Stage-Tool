class_name layer extends Resource

enum orgID {
	SPRITE = 1,
	LAYER = 2,
	BACKGROUND = 3,
	FOREGROUND = 4,
	ANIMATION = 6,
	ANIM_DURATION = 7,
	ANIM_LAYER_ON = 8,
	ANIM_LAYER_OFF = 9,
	ANIM_VAR_DURATION = 14
}

var address: int = 0
var index: int = 0
var priority: int = 0
var scrollrate: int = 1000
var xoffset: int = 0
var yoffset: int = 0
var background: bool = false
var foreground: bool = false
