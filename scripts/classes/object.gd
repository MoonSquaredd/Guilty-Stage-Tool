class_name object extends Resource

var address: int
var cells = PackedByteArray()
var sprites = []
var scripts = PackedByteArray()
var palettes = PackedByteArray()

func parse_sprites(addr, buf:PackedByteArray):
	var i = 0
	while true:
		var sprAddr = buf.decode_u32(i)
		
		if sprAddr == 0xFFFFFFFF:
			break
		
		var spr = sprite.new(buf, sprAddr)
		spr.address = sprAddr+addr
		sprites.append(spr)
		i += 4

func _init(addr, end, buf:PackedByteArray):
	address = addr
	var celPtr = buf.decode_u32(addr)+addr
	var sprPtr = buf.decode_u32(addr+4)+addr
	var scrPtr = buf.decode_u32(addr+8)+addr
	var _palPtr = buf.decode_u32(addr+12)+addr
	cells = buf.slice(celPtr,sprPtr)
	parse_sprites(sprPtr, buf.slice(sprPtr,scrPtr))
	#if palPtr-addr != 0xFFFFFFFF:
	#	scripts = buf.slice(scrPtr,palPtr)
	#	palettes = buf.slice(palPtr,end)
	#else:
	scripts = buf.slice(scrPtr,end)

func separate(buf:PackedByteArray):
	var reminder = buf.size() % 16
	for i in range((16-reminder)):
		buf.append(0xFF)

func assemble():
	var buf = PackedByteArray()
	
	buf.resize(12)
	separate(buf)
	var celPtr = buf.size()
	buf.encode_u32(0,celPtr)
	buf.append_array(cells)
	
	var sprPtr = buf.size()
	buf.encode_u32(4,sprPtr)
	buf.resize(buf.size()+(sprites.size()*4))
	separate(buf)
	
	for i in range(sprites.size()):
		var spr = sprites[i]
		buf.encode_u32(sprPtr+(i*4),buf.size()-sprPtr)
		if spr == null:
			var fill = PackedByteArray()
			fill.resize(16)
			fill.fill(0)
			buf.append_array(fill)
		else:
			spr = spr.assemble()
			buf.append_array(spr)
	
	var scrPtr = buf.size()
	buf.encode_u32(8,scrPtr)
	buf.append_array(scripts)
	
	#if palettes != null:
		#var palPtr = buf.size()
		#buf.encode_u32(12,palPtr)
		#buf.append_array(palettes)
	
	return buf
