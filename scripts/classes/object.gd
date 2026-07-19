class_name ggObject extends Resource

var cells = []
var sprites: Array[ggSprite] = []
var ggscript
var palettes = []

func _init(buffer:PackedByteArray,addr:int):
	cells = buffer.decode_u32(0)
	#sprites = buffer.decode_u32(4)
	var spr = buffer.slice(buffer.decode_u32(4),buffer.decode_u32(8))
	var p = 0
	while true:
		if spr.decode_u32(p) >= buffer.size(): break
		sprites.append(ggSprite.new("buffer",spr.slice(spr.decode_u32(p),spr.decode_u32(p+4))))
		p += 4
	ggscript = buffer.decode_u32(8)
	palettes = buffer.decode_u32(12)
