class_name Stage extends Resource

var tiles: Array[ggSprite] = []
var objects: Array[ggObject] = []
var layers: Array[ggLayer] = []
var animations: Array[ggLayerAnim] = []
var layer_defs: PackedByteArray

func _init(buffer: PackedByteArray, mode):
	var org = buffer.slice(buffer.decode_u32(0),buffer.decode_u32(4))
	layer_defs = org.slice(org.decode_u32(0),org.decode_u32(4))
	var p = 4
	while true:
		if org.decode_u32(p) >= buffer.size(): break
		tiles.append(ggSprite.new("buffer",org.slice(org.decode_u32(p),org.decode_u32(p+4))))
		p += 4
	#print("tiles: ",tiles)
	p = 4
	while true:
		if tiles[0].gg_ver == ggSprite.GG_VER.X && buffer.decode_u32(p+4) >= buffer.size(): break
		if buffer.decode_u32(p) >= buffer.size(): break
		objects.append(ggObject.new(buffer.slice(buffer.decode_u32(p),buffer.decode_u32(p+4)),buffer.decode_u32(p)))
		p += 4
	#print("objects: ",objects)
	make_layers()
	#print("layers: ",layers)

func make_layers():
	var p = 0
	var currentLayer = -1
	var currentAnim = -1
	var currentAnimFrame = -1
	while true:
		if layer_defs.decode_u32(p) >= 0xFFFFFFFF: break
		match layer_defs.decode_u16(p):
			ggLayer.orgID.SPRITE:
				if currentLayer < 0: print("no layer defined!!!"); p += 8; continue
				var index = layer_defs.decode_u16(p+2)
				var xoff = layer_defs.decode_u16(p+4)
				var yoff = layer_defs.decode_u16(p+6)
				layers[currentLayer].tiles.append({
					idx = index,
					x = xoff,
					y = yoff
				})
				tiles[index].use.append(currentLayer)
				if xoff + tiles[index].width > layers[currentLayer].highest_x:
					layers[currentLayer].highest_x = xoff + tiles[index].width
				if yoff > layers[currentLayer].highest_y:
					layers[currentLayer].highest_y = yoff
				p += 8
			ggLayer.orgID.LAYER:
				currentLayer += 1
				var newLayer = ggLayer.new()
				newLayer.index = layer_defs.decode_u16(p+2)
				newLayer.priority = layer_defs.decode_u16(p+4)
				newLayer.scrollrate = layer_defs.decode_u16(p+6)
				newLayer.xoffset = layer_defs.decode_u16(p+8)
				newLayer.yoffset = layer_defs.decode_u16(p+10)
				layers.append(newLayer)
				p += 12
			ggLayer.orgID.BACKGROUND: layers[currentLayer].background = true; p += 4
			ggLayer.orgID.FOREGROUND: layers[currentLayer].foreground = true; p += 4
			ggLayer.orgID.ANIMATION:
				var newAnim = ggLayerAnim.new()
				animations.append(newAnim)
				currentAnim += 1
				currentAnimFrame = -1
				p += 4
			ggLayer.orgID.WATER: layers[currentLayer].water = true; p += 4
			ggLayer.orgID.FLIP_HORIZONTAL: layers[currentLayer].flip = true; p += 4
			ggLayer.orgID.BLENDING_ADD: layers[currentLayer].blend = true; p += 4
			ggLayer.orgID.UNK_13: layers[currentLayer].unk13 = true; p += 4
			ggLayer.orgID.ANIM_DURATION:
				var animFrame = {
					duration = layer_defs.decode_u16(p+2),
					dur_min = layer_defs.decode_u16(p+2),
					dur_max = layer_defs.decode_u16(p+2),
					active_layers = [],
					inactive_layers = []
				}
				animations[currentAnim].frames.append(animFrame)
				currentAnimFrame += 1
				p += 4
			ggLayer.orgID.ANIM_VAR_DURATION:
				var mind = layer_defs.decode_u16(p+2)
				var maxd = layer_defs.decode_u16(p+4)
				var rd = randi_range(mind,maxd)
				var animFrame = {
					duration = rd,
					dur_min = mind,
					dur_max = maxd,
					active_layers = [],
					inactive_layers = []
				}
				animations[currentAnim].frames.append(animFrame)
				currentAnimFrame += 1
				p += 6
			ggLayer.orgID.ANIM_LAYER_ON:
				animations[currentAnim].frames[currentAnimFrame].active_layers.append(layer_defs.decode_u16(p+2))
				p += 4
			ggLayer.orgID.ANIM_LAYER_OFF:
				animations[currentAnim].frames[currentAnimFrame].inactive_layers.append(layer_defs.decode_u16(p+2))
				p += 4
			0xFFFF:
				break
			_:
				printerr("stage.gd/make_layers() - UNKNOWN ORGID FOUND AT 0x%8X: %d" % [p,layer_defs.decode_u16(p)])
				break
