class_name ggSprite extends Resource

var mode = 0
var clut = 32
var bpp = 8
var width = 64
var height = 64
var tw = 0
var th = 0
var hash = 0xFFFF
var palette: PackedColorArray
var src: PackedByteArray

var raw: PackedByteArray
var texture: ImageTexture
var use = []

func _init(kind: String, input):
	match kind:
		"buffer",_:
			raw = input
			mode = input.decode_u16(0)
			clut = input.decode_u16(2)
			bpp = input.decode_u16(4)
			width = input.decode_u16(6)
			height = input.decode_u16(8)
			tw = input.decode_u16(10)
			th = input.decode_u16(12)
			hash = input.decode_u16(14)
			if clut == 32:
				decode_palette(input.slice(16,(pow(16,bpp/4)*4)+16))
			if bpp == 8: reindex_palette()
			src = input.slice((pow(16,bpp/4)*4)+16)

func make_texture():
	var img = Image.create_empty(width,height,false,Image.FORMAT_RGBA8)
	if bpp == 8:
		for y in range(height):
			for x in range(width):
				img.set_pixel(x,y,palette[src[(y*width)+x]])
	if bpp == 4:
		var nibble = 0x0F
		for y in range(height):
			for x in range(width):
				img.set_pixel(x,y,palette[(src[(y*(width/2))+(x/2)] & nibble) >> (4 if nibble == 0xF0 else 0)])
				nibble = 0xF if nibble == 0xF0 else 0xF0
	texture = ImageTexture.create_from_image(img)

func decode_palette(buffer:PackedByteArray):
	var p = 0
	while true:
		if p >= buffer.size(): break
		var red = buffer.decode_u8(p)
		var green = buffer.decode_u8(p+1)
		var blue = buffer.decode_u8(p+2)
		var alpha = (buffer.decode_u8(p+3)*2)
		palette.append(Color8(red,green,blue,alpha))
		p += 4

func reindex_palette():
	var newpalette = PackedColorArray()
	newpalette.resize(palette.size())
	for i in range(palette.size()):
		var r = i%32
		if r > 7 && r < 16:
			newpalette[i] = palette[i+8]
		elif r > 15 && r < 24:
			newpalette[i] = palette[i-8]
		else:
			newpalette[i] = palette[i]
	palette = newpalette
