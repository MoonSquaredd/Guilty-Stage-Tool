extends Control

@export var org: PackedByteArray
@export var orgAddr: int
@export var layerList = []
@export var tileList = []

func draw_layer(lyr:layer):
	for sprNode in $viewer.get_children():
		sprNode.free()
	var p = 12
	while p > 0:
		var point = lyr.address-orgAddr+p
		var id = org.decode_u16(point)
		match id:
			layer.orgID.SPRITE:
				var spr = tileList[org.decode_u16(point+2)]
				var sprNode = Sprite2D.new()
				var img = spr.build_sprite()
				sprNode.texture = ImageTexture.create_from_image(img)
				var posx = 640+org.decode_s16(point+4) - lyr.xoffset
				var posy = 720-org.decode_s16(point+6) - lyr.yoffset
				sprNode.position = Vector2(posx,posy)
				$viewer.add_child(sprNode)
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
	draw_layer(lyr)
