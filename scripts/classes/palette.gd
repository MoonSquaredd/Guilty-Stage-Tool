class_name PaletteManager extends Resource

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
		r_min = min(col.r8,r_min)
		r_max = max(col.r8,r_max)
		g_min = min(col.g8,g_min)
		g_max = max(col.g8,g_max)
		b_min = min(col.b8,b_min)
		b_max = max(col.b8,b_max)
	
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

func generate_palette(img:Image,size,w,h) -> PackedColorArray:
	var newPal:PackedColorArray
	var result:PackedColorArray
	var lookup = {}
	result.append(Color(0,0,0,0))
	for y in range(h):
		for x in range(w):
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

func find_nearest(color:Color,palette:PackedColorArray):
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
