class_name sprite extends Resource

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

var address: int = 0
var colorCnt: int = 256
var gg_ver: GG_VER = GG_VER.XX
var decompressed = false

var layersUsing = []
var cachedTexture: ImageTexture

var mode: MODE = MODE.UNCOMPRESSED
var clut: int = 32
var bpp: int = 8
var width: int = 128
var height: int = 128
var tw: int = 7
var th: int = 7
var hash: int = 0xFFFF
var pal: PackedColorArray
var tex: PackedByteArray

var compSpr = preload("res://images/comp.png")

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
	tex = out

func palReindex():
	var newBuf = PackedColorArray()
	newBuf.resize(colorCnt)
	
	for i in range(colorCnt):
		if i%32 > 7 and i%32 < 16:
			newBuf[i] = pal[i+8]
		elif i%32 > 15 and i%32 < 24:
			newBuf[i] = pal[i-8]
		else:
			newBuf[i] = pal[i]
	
	pal = newBuf

func build_sprite():
	var img = Image.create_empty(width,height,false,Image.FORMAT_RGBA8)
	if mode == MODE.COMPRESSED && decompressed == false:
		img = compSpr
		img.resize(width,height,Image.INTERPOLATE_NEAREST)
		cachedTexture = ImageTexture.create_from_image(img)
		return
	
	var p = 0
	
	if bpp == 8:
		for y in height:
			for x in width:
				var index = tex.decode_u8(p)
				img.set_pixel(x,y,pal[index])
				p += 1
	elif bpp == 4:
		for y in height:
			for x in width:
				var index = tex.decode_u8(floor(p/2.0))
				if p & 0x1 == 1:
					index = (index & 0xF0) >> 4
				else:
					index &= 0x0F
				img.set_pixel(x,y,pal[index])
				p += 1
	
	cachedTexture = ImageTexture.create_from_image(img)

func assemble():
	var buf = PackedByteArray()
	buf.resize(16+(colorCnt*4))
	if decompressed == true:
		buf.encode_u16(0,MODE.UNCOMPRESSED)
	else:
		buf.encode_u16(0,mode)
	buf.encode_u16(2,clut)
	buf.encode_u16(4,bpp)
	buf.encode_u16(6,width)
	buf.encode_u16(8,height)
	buf.encode_u16(10,tw)
	buf.encode_u16(12,th)
	buf.encode_u16(14,hash)
	if bpp == 8:
		palReindex()
	for i in range(colorCnt):
		var col = pal[i]
		buf.encode_u8(16+(i*4),col.r8)
		buf.encode_u8(17+(i*4),col.g8)
		buf.encode_u8(18+(i*4),col.b8)
		buf.encode_u8(19+(i*4),(col.a8+1)/2)
	if bpp == 8:
		palReindex()
	buf.append_array(tex)
	return buf

func _init(buf, addr):
	if buf == null && addr == null:
		return
	mode = buf.decode_u16(addr)
	
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
		width = buf.decode_u16(addr+2)
		height = buf.decode_u16(addr+4)
		tw = 0
		th = 0
		hash = 0
	else:
		clut = buf.decode_u16(addr+2)
		bpp = buf.decode_u16(addr+4)
		width = buf.decode_u16(addr+6)
		height = buf.decode_u16(addr+8)
		tw = buf.decode_u16(addr+10)
		th = buf.decode_u16(addr+12)
		hash = buf.decode_u16(addr+14)
	
	colorCnt = pow(16,bpp/4)
	if (clut == 16) && (bpp == 8):
		colorCnt /= 2
	pal.resize(colorCnt)
		
	for j in range(colorCnt):
		var red = buf.decode_u8(addr+16+(j*4))
		var green = buf.decode_u8(addr+17+(j*4))
		var blue = buf.decode_u8(addr+18+(j*4))
		var alpha = buf.decode_u8(addr+19+(j*4))
		var col = Color8(red,green,blue,clamp(alpha*2,0,255))
		pal[j] = col
	
	var pixsize
	if bpp == 8:
		palReindex()
		pixsize = width*height
	elif bpp == 4:
		pixsize = (width*height)/2
			
	var pixaddr = addr+16+(colorCnt*4)
	
	if mode == MODE.COMPRESSED:
		if gg_ver == GG_VER.X:
			ggx_decompress(buf,pixaddr,pixsize)
			return
		else:
			return
	tex = buf.slice(pixaddr,pixaddr+pixsize)
	decompressed = true
