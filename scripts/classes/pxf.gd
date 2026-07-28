class_name ggSprite extends Resource

enum MODE {
	UNCOMPRESSED = 0,
	COMPRESSED = 1,
	COMPRESSED_ALT = 2,
	PALETTE = 3
}

enum GG_VER {
	ML = 0,
	X = 1,
	XX = 2
}

var mode: MODE = MODE.UNCOMPRESSED
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
var decompressed = true
var gg_ver: GG_VER = GG_VER.XX

var pm = PaletteManager.new()

func ggx_decompress(buf:PackedByteArray,addr,pixsize):
	var out = PackedByteArray()
	out.resize(pixsize)
	out.fill(0)
	
	var bytePtr = addr
	var pixPtr = 0
	var t1
	var t2
	
	while pixsize > 0:
		var byte = buf.decode_u8(bytePtr)
		bytePtr += 1
		if ((byte & 0xC0) == 0):
			var count = byte
			while (count >= 0):
				if ((pixPtr & 0x3) == 0):
					if ((bytePtr & 0x3) == 0):
						while (count >= 5):
							var pix32 = buf.decode_s32(bytePtr)
							count -= 0x4
							bytePtr += 0x4
							out.encode_s32(pixPtr,pix32)
							pixPtr += 0x4
							pixsize -= 4
					elif ((bytePtr & 0x1) == 0):
						while (count >= 0x3):
							var pix16 = buf.decode_u16(bytePtr)
							count -= 0x2
							bytePtr += 0x2
							out.encode_s16(pixPtr,pix16)
							pixPtr += 0x2
							pixsize -= 2
					while (count >= 0x5):
						var pix32 = 0
						for i in range(4):
							byte = buf.decode_u8(bytePtr)
							bytePtr += 1
							pix32 |= (byte << ((i*8) & 0x1F))
						out.encode_s32(pixPtr,pix32)
						count -= 4 
						pixPtr += 4
						pixsize -= 4
				byte = buf.decode_u8(bytePtr)
				count -= 1
				bytePtr += 1
				out.encode_s8(pixPtr,byte)
				pixPtr += 1
				pixsize -= 1
			t2 = buf.decode_u8(bytePtr-1)
		else:
			var count = (byte + 0xC3) & 0xFF	
			while ((pixPtr & 0x3) != 0) && (count >= 0):
				out.encode_s8(pixPtr,t2)
				count -= 1
				pixPtr += 1
				pixsize -= 1
			t1 = (t2 << 24) | (t2 << 16) | (t2 << 8) | t2
			while (count >= 0x4):
				out.encode_s32(pixPtr,t1)
				count -= 4
				pixPtr += 4
				pixsize -= 4
			count -= 1
			while count >= 0:
				out.encode_s8(pixPtr,t2)
				count -= 1
				pixPtr += 1
				pixsize -= 1
	decompressed = true
	src = out

func _init(kind: String, input):
	match kind:
		"buffer":
			raw = input
			mode = input.decode_u16(0)
			if mode > 3:
				gg_ver = GG_VER.X
				if (mode & 0xf00) >> 8 == 0:
					clut = 32
				else:
					clut = 16
				
				if mode & 0xf == 3:
					bpp = 8
				else:
					bpp = 4
				
				if (mode & 0xf000) >> 8 == 0:
					mode = MODE.UNCOMPRESSED
				else:
					mode = MODE.COMPRESSED
				width = input.decode_u16(2)
				height = input.decode_u16(4)
				tw = ceil(log(width)/log(2))
				th = ceil(log(height)/log(2))
				if tw > 9:
					tw = 0
				if th > 9:
					th = 0
				hash = randi_range(0,0xFFFF)
			else:
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
			if mode == MODE.COMPRESSED:
				if gg_ver == GG_VER.X:
					var pixsize = width*height if bpp == 8 else (width*height)/2
					var pixaddr = 16+(palette.size()*4)
					ggx_decompress(input,pixaddr,pixsize)
					return
				else:
					return
			src = input.slice((pow(16,bpp/4)*4)+16)
		"image":
			var img = Image.load_from_file(input)
			if !img:
				return
			width = img.get_width()
			height = img.get_height()
			tw = ceil(log(width)/log(2))
			th = ceil(log(height)/log(2))
			if tw > 9:
				tw = 0
			if th > 9:
				th = 0
			hash = randi_range(0,0xFFFF)
			src.resize(width*height)
			palette = pm.generate_palette(img,256,width,height)
			var lookup = {}
			var nearest_cache = {}
			for i in range(palette.size()):
				lookup[palette[i]] = i
			for y in range(height):
				for x in range(width):
					var col = img.get_pixel(x,y)
					if col.a < 0.5:
						src.encode_u8(y*width+x,0)
					elif lookup.has(col):
						src.encode_u8(y*width+x,lookup[col])
					else:
						if !nearest_cache.has(col):
							nearest_cache[col] = pm.find_nearest(col,palette)
						src.encode_u8(y*width+x,lookup[nearest_cache[col]])

func make_texture():
	if width == 0 || height == 0:
		return
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
