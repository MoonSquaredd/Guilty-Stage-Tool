extends Control

var compSpr = preload("res://comp.png")

@export var spriteList = []

enum file_save_mode {
	SAVE_STAGE = 0,
	EXPORT_TILE = 1,
	EXPORT_ALL_TILE = 2
}

var selected_colnode
var copiedCol
var curSpriteImg
var saveMode: file_save_mode
var undo_redo = UndoRedo.new()

func show_picker(event: InputEvent, node):
	if event.is_pressed():
		selected_colnode = node
		$hint.set_global_position(node.global_position)
		$hint.visible = true
		$ColorPicker.color = node.color
		$ColorPicker.visible = true

func load_pal(spr:sprite):
	var rowCnt = spr.colorCnt / 16.0
	var row = 1
	
	for node in ($"Properties/PalView".get_children()):
		node.visible = false
	
	for i in range(rowCnt):
		var rowNode = get_node_or_null("Properties/PalView/PalRow%d" % (i+1))
		if rowNode == null:
			rowNode = HBoxContainer.new()
			rowNode.name = "PalRow%d" % (i+1)
			rowNode.alignment = BoxContainer.ALIGNMENT_CENTER
			rowNode.custom_minimum_size = Vector2(0,16)
			$"Properties/PalView".add_child(rowNode)
		else:
			rowNode.visible = true
	
	for i in range(spr.colorCnt):
		if i % 16 == 0:
			row = i / 16.0
		var rowNode = get_node_or_null("Properties/PalView/PalRow%d" % (row+1))
		
		var col: ColorRect
		var colnode = rowNode.get_node_or_null("Color%d" % i)
		if colnode != null:
			col = colnode
			col.color = spr.pal[i]
		else:
			col = ColorRect.new()
			col.name = "Color%d" % i
			col.custom_minimum_size = Vector2(16,16)
			col.color = spr.pal[i]
			col.gui_input.connect(show_picker.bind(col))
			var border = ReferenceRect.new()
			border.border_color = Color()
			border.editor_only = false
			border.custom_minimum_size = col.custom_minimum_size
			border.mouse_filter = Control.MOUSE_FILTER_IGNORE
			col.add_child(border)
			rowNode.add_child(col)

func build_sprite(spr:sprite):
	if spr.mode == 1:
		return null
	
	var img = Image.create_empty(spr.width,spr.height,false,Image.FORMAT_RGBA8)
	var p = 0
	
	if spr.bpp == 8:
		for y in spr.height:
			for x in spr.width:
				var index = spr.tex.decode_u8(p)
				img.set_pixel(x,y,spr.pal[index])
				p += 1
	elif spr.bpp == 4:
		for y in spr.height:
			for x in spr.width:
				var index = spr.tex.decode_u8(floor(p/2.0))
				if p & 0x1 == 1:
					index = (index & 0xF0) >> 4
				else:
					index &= 0x0F
				img.set_pixel(x,y,spr.pal[index])
				p += 1
	
	return img

func draw_sprite(spr:sprite):
	var img = build_sprite(spr)
	if img == null:
		img = compSpr
	curSpriteImg = img
	var tex = ImageTexture.create_from_image(img)
	$"Sprite2D".texture = tex

func _on_index_value_changed(value: float) -> void:
	$hint.visible = false
	$ColorPicker.visible = false
	selected_colnode = null
	var spr = spriteList[value]
	$"Properties/Addr".text = " Address: 0x%08X" % spr.address
	$"Properties/Mode".selected = spr.mode
	$"Properties/pxData/Clut".value = spr.clut
	$"Properties/pxData/Bpp".value = spr.bpp
	$"Properties/sizing/Width".value = spr.width
	$"Properties/sizing/Height".value = spr.height
	$"Properties/vram/tw".value = spr.tw
	$"Properties/vram/th".value = spr.th
	$"Properties/vram/hash".text = " Hash: 0x%04X" % spr.hash
	load_pal(spr)
	draw_sprite(spr)

func change_color(node, color, idx, spr):
	node.color = color
	spr.pal[idx.to_int()] = color
	draw_sprite(spr)

func undo_color(node, color, idx, spr):
	node.color = color
	spr.pal[idx.to_int()] = color
	draw_sprite(spr)

func _on_color_picker_color_changed(color: Color) -> void:
	var idx = selected_colnode.name.trim_prefix("Color")
	var spr = spriteList[$"Properties/Index".value]
	undo_redo.create_action("Change Color")
	undo_redo.add_do_method(change_color.bind(selected_colnode,color,idx,spr))
	undo_redo.add_undo_method(undo_color.bind(selected_colnode,selected_colnode.color,idx,spr))
	undo_redo.commit_action()

func _on_import_pressed() -> void:
	$FileDialog.visible = true

func _on_export_pressed() -> void:
	saveMode = file_save_mode.EXPORT_TILE
	$SaveDialog.visible = true

func _on_export_all_pressed() -> void:
	saveMode = file_save_mode.EXPORT_ALL_TILE
	$SaveDialog.visible = true

func _on_save_dialog_dir_selected(dir: String) -> void:
	match saveMode:
		file_save_mode.EXPORT_TILE:
			var idx = $"Properties/Index".value
			curSpriteImg.save_png(dir + "/sprite_%03d.png" % idx)
		file_save_mode.EXPORT_ALL_TILE:
			for i in range($"Properties/Index".max_value):
				var img = build_sprite(spriteList[i])
				img.save_png(dir + "/sprite_%03d.png" % i)

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
	spriteList[$Properties/Index.value] = spr
	_on_index_value_changed($Properties/Index.value)

func undo_sprite(spr):
	spriteList[$Properties/Index.value] = spr
	_on_index_value_changed($Properties/Index.value)

func _on_file_dialog_file_selected(path: String) -> void:
	var img = Image.load_from_file(path)
	var oldSpr = spriteList[$Properties/Index.value]
	undo_redo.create_action("Import Sprite")
	undo_redo.add_do_method(make_sprite.bind(img))
	undo_redo.add_undo_method(undo_sprite.bind(oldSpr))
	undo_redo.commit_action()

func reset():
	undo_redo.clear_history()

func _ready() -> void:
	$"Properties/Index".max_value = spriteList.size()-1

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("undo"):
		undo_redo.undo()
	elif Input.is_action_just_pressed("redo"):
		undo_redo.redo()
	elif Input.is_action_just_pressed("copy"):
		if selected_colnode != null:
			copiedCol = selected_colnode.color
	elif Input.is_action_just_pressed("paste"):
		if (selected_colnode != null) && (copiedCol != null):
			var idx = selected_colnode.name.trim_prefix("Color")
			var spr = spriteList[$"Properties/Index".value]
			undo_redo.create_action("Paste Color")
			undo_redo.add_do_method(change_color.bind(selected_colnode,copiedCol,idx,spr))
			undo_redo.add_undo_method(undo_color.bind(selected_colnode,selected_colnode.color,idx,spr))
			undo_redo.commit_action()
