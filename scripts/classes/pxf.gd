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

#perhaps i should separate all this palette mess to a class of its own
func color_channel_sort(a,b,channel):
	match channel:
		"red": return a.r8 < b.r8
		"green": return a.g8 < b.g8
		"blue": return a.b8 < b.b8
	return false

func average_color(pal:PackedColorArray):
	var r = 0
	var g = 0
	var b = 0
	
	for col in pal:
		r += col.r8
		g += col.g8
		b += col.b8
	
	var c = pal.size()
	return Color8(r/c,g/c,b/c)

func median_cut(root_palette:PackedColorArray,size):
	if size <= 1:
		return [average_color(root_palette)]
	var r_min = 255
	var r_max = 0
	var g_min = 255
	var g_max = 0
	var b_min = 255
	var b_max = 0
	var r_avg
	var g_avg
	var b_avg
	
	for col in root_palette:
		r_min = col.r8 if col.r8 < r_min else r_min
		r_max = col.r8 if col.r8 > r_max else r_max
		g_min = col.g8 if col.g8 < g_min else g_min
		g_max = col.g8 if col.g8 > g_max else g_max
		b_min = col.b8 if col.b8 < b_min else b_min
		b_max = col.b8 if col.b8 > b_max else b_max
	
	r_avg = r_max-r_min
	g_avg = g_max-g_min
	b_avg = b_max-b_min
	
	var copy = Array(root_palette)
	if r_avg >= g_avg && r_avg >= b_avg:
		copy.sort_custom(color_channel_sort.bind("red"))
	elif g_avg >= r_avg && g_avg >= b_avg:
		copy.sort_custom(color_channel_sort.bind("green"))
	elif b_avg >= r_avg && b_avg >= g_avg:
		copy.sort_custom(color_channel_sort.bind("blue"))
	var result = []
	var upper = size / 2
	var lower = size - upper
	result.append_array(median_cut(PackedColorArray(copy.slice(copy.size()/2)),upper))
	result.append_array(median_cut(PackedColorArray(copy.slice(0,copy.size()/2)),lower))
	return PackedColorArray(result)

func generate_palette(img:Image,size) -> PackedColorArray:
	var newPal:PackedColorArray
	var result:PackedColorArray
	var lookup = {}
	result.append(Color(0,0,0,0))
	for y in range(height):
		for x in range(width):
			var col = img.get_pixel(x,y)
			if col.a < 0.5:
				continue
			if !lookup.has(col):
				newPal.append(col)
				lookup[col] = 0
	if newPal.size() > size-1:
		result.append_array(median_cut(newPal,size-1))
	else:
		result.append_array(newPal)
	for i in range(size-result.size()):
		result.append(Color(0,0,0,1))
	return result

func find_nearest(color:Color):
	var smallest_distance = 0xFFFFFFFFFF
	var closest = 0
	for i in range(palette.size()):
		var col = palette[i]
		var distance = (
			((col.r8-color.r8)*(col.r8-color.r8)) + 
			((col.g8-color.g8)*(col.g8-color.g8)) + 
			((col.b8-color.b8)*(col.b8-color.b8))
		)
		if distance < smallest_distance:
			smallest_distance = distance
			closest = i
	return palette[closest]

func _init(kind: String, input):
	match kind:
		"buffer":
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
			var t = Time.get_ticks_msec()
			palette = generate_palette(img,256)
			print("generate_palette: %dms" % [Time.get_ticks_msec()-t])
			t = Time.get_ticks_msec()
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
							nearest_cache[col] = find_nearest(col)
						src.encode_u8(y*width+x,lookup[nearest_cache[col]])
			print("encoding: %dms" % [Time.get_ticks_msec()-t])

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
