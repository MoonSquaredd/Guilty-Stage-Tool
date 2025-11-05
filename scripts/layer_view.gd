extends Control

@export var layerList = []
@export var tileList = []
@export var moveNode: Control
@export var highlight: ReferenceRect

var selSprNode: TextureRect
var selSprSize
var selTile
var released = true

func reset():
	for node in moveNode.get_children():
		node.free()

func spr_properties(event:InputEvent,node,lyr,index,sprSize):
	var tile = lyr.tiles[index]
	if event is InputEventMouseButton && event.is_pressed():
		released = false
		selTile = tile
		highlight.visible = true
		highlight.global_position = node.global_position
		highlight.size = sprSize
		
		selSprNode = node
		selSprSize = sprSize
		$SprProperties/tile.value = tile.i
		$SprProperties/xpos.value = tile.x
		$SprProperties/ypos.value = tile.y
		$SprProperties.visible = true
	elif event is InputEventMouseButton && event.is_released():
		# i hate this, but its the only way to make it work :jamBall:
		released = true
		tile.x = (node.position.x-640)+(selSprSize.x/2)
		tile.y = (720-node.position.y)-(selSprSize.y/2)
		$SprProperties/xpos.value = tile.x
		$SprProperties/ypos.value = tile.y
	elif event is InputEventMouseMotion && released == false:
		node.global_position = Vector2i(get_global_mouse_position())-Vector2i((selSprSize/2))
		highlight.global_position = node.global_position

# Selected Tile Properties
# [
func _on_tile_value_changed(value: float) -> void:
	selTile.i = value
	var spr = tileList[value]
	if spr.cachedTexture == null:
		spr.build_sprite()
	selSprNode.texture = spr.cachedTexture

func _on_xpos_value_changed(value: float) -> void:
	selTile.x = value
	selSprNode.position.x = 640+value-(selSprSize.x/2)
	highlight.global_position = selSprNode.global_position

func _on_ypos_value_changed(value: float) -> void:
	selTile.y = value
	selSprNode.position.y = 720-value-(selSprSize.y/2)
	highlight.global_position = selSprNode.global_position
# ]

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
		var sprNode = TextureRect.new()
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
		var sprSize = Vector2(spr.width,spr.height)
		sprNode.position -= sprSize/2
		sprNode.connect("gui_input",spr_properties.bind(sprNode,lyr,i,sprSize))
		layerNode.add_child(sprNode)

# Properties Change
# [
func _on_id_value_changed(value: float) -> void:
	var lyr = layerList[$Properties/Index.value]
	lyr.index = value

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

func _on_back_toggled(toggled_on: bool) -> void:
	var lyr = layerList[$Properties/Index.value]
	lyr.background = toggled_on

func _on_fore_toggled(toggled_on: bool) -> void:
	var lyr = layerList[$Properties/Index.value]
	lyr.foreground = toggled_on

func _on_blend_toggled(toggled_on: bool) -> void:
	var lyr = layerList[$Properties/Index.value]
	lyr.blend = toggled_on

func _on_flip_toggled(toggled_on: bool) -> void:
	var lyr = layerList[$Properties/Index.value]
	lyr.flip = toggled_on

func _on_unk_10_toggled(toggled_on: bool) -> void:
	var lyr = layerList[$Properties/Index.value]
	lyr.a = toggled_on

func _on_unk_13_toggled(toggled_on: bool) -> void:
	var lyr = layerList[$Properties/Index.value]
	lyr.d = toggled_on
# ]

func _on_index_value_changed(value: float) -> void:
	if layerList.size() == 0:
		return
	highlight.visible = false
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
	$"Properties/options2/flip".button_pressed = lyr.flip
	$"Properties/options2/unk10".button_pressed = lyr.a
	$"Properties/options2/unk13".button_pressed = lyr.d
	draw_layer(value)
