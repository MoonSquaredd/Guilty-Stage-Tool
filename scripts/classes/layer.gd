class_name layer extends Resource

enum orgID {
	SPRITE = 1,
	LAYER = 2,
	BACKGROUND = 3,
	FOREGROUND = 4,
	ANIMATION = 6,
	ANIM_DURATION = 7,
	ANIM_LAYER_ON = 8,
	ANIM_LAYER_OFF = 9,
	UNK_10 = 10,
	FLIP_HORIZONTAL = 11,
	BLENDING_ADD = 12,
	UNK_13 = 13,
	ANIM_VAR_DURATION = 14
}

var address: int = 0
var index: int = 0
var priority: int = 0
var scrollrate: int = 1000
var xoffset: int = 0
var yoffset: int = 0
var background: bool = false
var foreground: bool = false
var blend: bool = false
var a: bool = false #??
var flip: bool = false
var d: bool = false #??
var tiles = []
var highest_x = 0
var highest_y = 0

func assemble():
	var buf = PackedByteArray()
	var p = 12
	buf.resize(12+(tiles.size()*8))
	buf.encode_u16(0, orgID.LAYER)
	buf.encode_u16(2, index)
	buf.encode_u16(4, priority)
	buf.encode_u16(6, scrollrate)
	buf.encode_s16(8, xoffset)
	buf.encode_s16(10,yoffset)
	
	if background == true:
		buf.resize(buf.size()+4)
		buf.encode_u32(p,orgID.BACKGROUND)
		p += 4
	elif foreground == true:
		buf.resize(buf.size()+4)
		buf.encode_u32(p,orgID.FOREGROUND)
		p += 4
	
	if a == true:
		buf.resize(buf.size()+4)
		buf.encode_u32(p,orgID.UNK_10)
		p += 4
	
	if flip == true:
		buf.resize(buf.size()+4)
		buf.encode_u32(p,orgID.FLIP_HORIZONTAL)
		p += 4
	
	if blend == true:
		buf.resize(buf.size()+4)
		buf.encode_u32(p,orgID.BLENDING_ADD)
		p += 4
	
	if d == true:
		buf.resize(buf.size()+4)
		buf.encode_u32(p,orgID.UNK_13)
		p += 4
	
	for i in range(tiles.size()):
		var tile = tiles[i]
		buf.encode_u16(p,orgID.SPRITE)
		buf.encode_u16(p+2,tile.i)
		buf.encode_s16(p+4,tile.x)
		buf.encode_s16(p+6,tile.y)
		p += 8
	
	return buf

func pngify(tileList):
	var img = Image.create_empty(highest_x,highest_y,false,Image.FORMAT_RGBA8)
	for i in range(tiles.size()):
		var tile = tiles[i]
		var spr = tileList[tile.i]
		var x = tile.x
		var y = tile.y
		var sprImg = spr.cachedTexture.get_image() 
		img.blit_rect(sprImg,Rect2i(0,0,spr.width,spr.height),Vector2i(x,highest_y-y))
	return img

func make_sprite(img):
	var spr = sprite.new(null,null)
	spr.mode = 0
	spr.clut = 32
	spr.bpp = 8
	spr.width = img.get_width()
	spr.height = img.get_height()
	spr.tw = ceil(log(spr.width)/log(2))
	spr.th = ceil(log(spr.height)/log(2))
	if spr.tw > 9:
		spr.tw = 0
	if spr.th > 9:
		spr.th = 0
	spr.hash = randi_range(0,0xFFFF)
	spr.tex.resize(spr.width*spr.height)
	
	var cnt = 0
	for y in spr.height:
		for x in spr.width:
			var col = img.get_pixel(x,y)
			var idx = spr.pal.find(col)
			if idx != -1:
				spr.tex.encode_u8((y*spr.width)+x,idx)
			else:
				if cnt > 255:
					break
				cnt += 1
				spr.pal.append(col)
				spr.tex.encode_u8((y*spr.width)+x,spr.pal.size()-1)
	spr.pal.resize(256)
	return spr

func slice_n_dice(img:Image, tileList):
	var htiles = (img.get_width() / 64) + 1
	var vtiles = (img.get_height() / 64) + 1
	for v in range(vtiles):
		for h in range(htiles):
			var newTile = img.get_region(Rect2i(h*64,v*64,64,64))
			var spr = make_sprite(newTile)
			var tile = {
				i = tileList.size(),
				x = h*64,
				y = (vtiles-v)*64
			}
			tiles.append(tile)
			tileList.append(spr)
