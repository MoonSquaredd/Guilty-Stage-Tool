extends Control

@export var layerList = []
@export var tileList = []
@export var moveNode: Control
@export var camera: Camera2D
@export var highlight: ReferenceRect

var missingSpr = preload("res://images/miss.png")

var selSprNode: TextureRect
var selSprSize
var selTile
var released = true
var undo_redo = UndoRedo.new()

func reset():
	undo_redo.clear_history()
	$SprProperties/tile.max_value = tileList.size()
	for node in moveNode.get_children():
		node.free()

func update_tile(tile,pos,size,node):
	node.position = pos
	highlight.global_position = node.global_position
	tile.x = (pos.x-640)+(size.x/2)
	tile.y = (720-pos.y)-(size.y/2)
	$SprProperties/xpos.value = selTile.x
	$SprProperties/ypos.value = selTile.y

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
		var oldPos = Vector2(tile.x+640,720-tile.y)-Vector2(selSprSize.x/2,selSprSize.y/2)
		undo_redo.create_action("Move tile %d" % tile.i)
		undo_redo.add_do_method(update_tile.bind(tile,node.position,sprSize,node))
		undo_redo.add_undo_method(update_tile.bind(tile,oldPos,sprSize,node))
		undo_redo.commit_action()
		released = true
	elif event is InputEventMouseMotion && released == false:
		# fixed thanks to sAlt @saltern
		node.global_position += Vector2(Vector2i(event.relative))
		highlight.global_position = node.global_position

# Selected Tile Properties
# [
func _on_tile_value_changed(value: float) -> void:
	selTile.i = value
	if selTile.i >= tileList.size():
		selSprNode.texture = ImageTexture.create_from_image(missingSpr)
		return
	var spr = tileList[value]
	if spr == null:
		selSprNode.texture = ImageTexture.create_from_image(missingSpr)
		return
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
		layerNode.set_anchors_preset(Control.PRESET_CENTER)
		moveNode.add_child(layerNode)
	else:
		layerNode.visible = true
		return
	
	for i in range(lyr.tiles.size()):
		var tile = lyr.tiles[i]
		var spr
		var sprNode = TextureRect.new()
		var sprSize
		if (tile.i >= tileList.size()) or tileList[tile.i] == null:
			sprNode.texture = ImageTexture.create_from_image(missingSpr)
			sprSize = Vector2(128,128)
		else:
			spr = tileList[tile.i]
			if spr.cachedTexture == null:
				spr.build_sprite()
			sprNode.texture = spr.cachedTexture
			sprSize = Vector2(spr.width,spr.height)
		var posx
		if lyr.flip == false:
			posx = 640+tile.x
		else:
			posx = 640-tile.x + spr.width
			sprNode.flip_h = true
		var posy = 720-tile.y
		sprNode.position = Vector2(posx,posy)
		sprNode.position -= sprSize/2
		sprNode.connect("gui_input",spr_properties.bind(sprNode,lyr,i,sprSize))
		layerNode.add_child(sprNode)

func apply_scroll():
	var center = Vector2(640,360)
	var off = camera.offset-center
	for node in moveNode.get_children():
		var id = int(node.name.trim_prefix("Layer "))
		for lyr in layerList:
			if lyr.index == id:
				var displace = lyr.scrollrate / 100.0
				node.position = Vector2(-lyr.xoffset,-lyr.yoffset)-Vector2(off*displace)
				node.scale = camera.zoom+Vector2(1-(displace/10.0),1-(displace/10.0)) #10 = 1 5 = 1.5 1 = 2
				node.position = center + (node.position-center) * node.scale

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
	$"Properties/id".value = lyr.index
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
	$SprProperties/tile.max_value = tileList.size()
	draw_layer(value)

func _on_import_pressed() -> void:
	$FileDialog.visible = true

func _on_export_pressed() -> void:
	$SaveDialog.visible = true

func _on_file_dialog_file_selected(path: String) -> void:
	var img = Image.load_from_file(path)
	var lyr = layer.new()
	lyr.index = layerList.size()
	lyr.slice_n_dice(img,tileList)
	layerList.append(lyr)
	$Properties/Index.max_value += 1
	$SprProperties/tile.max_value = tileList.size()

func _on_save_dialog_file_selected(path: String) -> void:
	var id = $Properties/Index.value
	var lyr = layerList[id]
	var img = lyr.pngify(tileList)
	img.save_png(path)

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("undo"):
		undo_redo.undo()
	elif Input.is_action_just_pressed("redo"):
		undo_redo.redo()
