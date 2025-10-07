extends Control

@export var layerList = []

func _on_index_value_changed(value: float) -> void:
	var lyr = layerList[value]
	$"Properties/Addr".text = " Address: 0x%08X" % lyr.address
	$Properties/id.value = lyr.index
	$"Properties/layData/prio".value = lyr.priority
	$"Properties/layData/scroll".value = lyr.scrollrate
	$"Properties/offsets/xoff".value = lyr.xoffset
	$"Properties/offsets/yoff".value = lyr.yoffset
	$"Properties/options/back".button_pressed = lyr.background
	$"Properties/options/fore".button_pressed = lyr.foreground
	#draw_layer(lyr)
