extends Control

@export var layerList = []
@export var tileList = []
@export var moveNode: Control

func reset():
	for node in moveNode.get_children():
		node.free()

func draw_layer(lyr):
	lyr = layerList[lyr]
	for node in moveNode.get_children():
		node.visible = false
	
	var layerNode = moveNode.get_node_or_null("Layer %d" % lyr.index)
	if layerNode == null:
		layerNode = Control.new()
		layerNode.name = "Layer %d" % lyr.index
		layerNode.z_index = -1 - lyr.priority
		layerNode.position.x = -lyr.xoffset
		layerNode.position.y = -lyr.yoffset
		moveNode.add_child(layerNode)
	else:
		layerNode.visible = true
		return
	
	for i in range(lyr.tiles.size()):
		var tile = lyr.tiles[i]
		var spr = tileList[tile.i]
		var sprNode = Sprite2D.new()
		if spr.cachedTexture == null:
			spr.build_sprite()
		sprNode.texture = spr.cachedTexture
		var posx
		if lyr.flip == false:
			posx = 640+tile.x
		else:
			posx = 640-tile.x + spr.width
			sprNode.flip_h = true
		var posy = 720-tile.y
		sprNode.position = Vector2(posx,posy)
		layerNode.add_child(sprNode)

# Properties Change
# [
func _on_prio_value_changed(value: float) -> void:
	var lyr = layerList[$Properties/Index.value]
	lyr.priority = value
	var layerNode = moveNode.get_node_or_null("Layer %d" % lyr.index)
	if layerNode != null:
		layerNode.z_index = -1 - lyr.priority

func _on_scroll_value_changed(value: float) -> void:
	var lyr = layerList[$Properties/Index.value]
	lyr.scrollrate = value

func _on_xoff_value_changed(value: float) -> void:
	var lyr = layerList[$Properties/Index.value]
	lyr.xoffset = value
	var layerNode = moveNode.get_node_or_null("Layer %d" % lyr.index)
	if layerNode != null:
		layerNode.position.x = -value

func _on_yoff_value_changed(value: float) -> void:
	var lyr = layerList[$Properties/Index.value]
	lyr.yoffset = value
	var layerNode = moveNode.get_node_or_null("Layer %d" % lyr.index)
	if layerNode != null:
		layerNode.position.y = -value

func _on_blend_toggled(toggled_on: bool) -> void:
	var lyr = layerList[$Properties/Index.value]
	lyr.blend = toggled_on
# ]

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
	$"Properties/options/blend".button_pressed = lyr.blend
	draw_layer(value)
