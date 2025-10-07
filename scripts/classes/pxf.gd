class_name sprite extends Resource

enum MODE {
	UNCOMPRESSED = 0,
	COMPRESSED = 1,
	COMPRESSED_ALT = 2,
	PALETTE = 3
}

var address: int = 0
var colorCnt: int = 256

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

func assemble():
	var buf = PackedByteArray()
	buf.resize(16+(colorCnt*4))
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
	if buf && addr == null:
		return
	mode = buf.decode_u16(addr)
	
	if mode > 3:
		if mode & 0xf00 == 0:
			clut = 32
		else:
			clut = 16
		
		if mode & 0xf == 3:
			bpp = 8
		else:
			bpp = 4
		
		if mode & 0xf0 == 0:
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
	if clut == 16:
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
		return
	tex = buf.slice(pixaddr,pixaddr+pixsize)
