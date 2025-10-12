extends Control

@export var org: PackedByteArray
@export var orgAddr: int
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
	
	var layerNode = get_node_or_null("Layer %d" % lyr.index)
	if layerNode == null:
		layerNode = Control.new()
		layerNode.name = "Layer %d" % lyr.index
		layerNode.z_index = -1 - lyr.priority
		moveNode.add_child(layerNode)
	else:
		layerNode.visible = true
		return
	var p = 12
	while p > 0:
		var point = lyr.address-orgAddr+p
		var id = org.decode_u16(point)
		match id:
			layer.orgID.SPRITE:
				var spr = tileList[org.decode_u16(point+2)]
				var sprNode = Sprite2D.new()
				if spr.cachedTexture == null:
					spr.build_sprite()
				sprNode.texture = spr.cachedTexture
				var posx
				if lyr.b == false:
					posx = 640+org.decode_s16(point+4) - lyr.xoffset
				else:
					posx = 640+org.decode_s16(point+4) + (spr.width + lyr.xoffset)
				var posy = 720-org.decode_s16(point+6) - lyr.yoffset
				sprNode.position = Vector2(posx,posy)
				layerNode.add_child(sprNode)
				p += 8
			layer.orgID.LAYER,layer.orgID.ANIMATION,0xFFFF:
				p = -1
				break
			_:
				p += 4

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
	draw_layer(value)
