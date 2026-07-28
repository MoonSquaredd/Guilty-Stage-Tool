extends Control

@export var spriteList: Array[ggSprite] = []
var export: String = "single"
var importF: FileAccess
var importExt: String
var importPath: String
var deletion: bool = false
var selected_colnode: ColorRect
var copiedCol: Color
var undo_redo = UndoRedo.new()

func show_picker(event: InputEvent, node):
	if event.is_pressed():
		selected_colnode = node
		$hint.set_global_position(node.global_position)
		$hint.visible = true
		$ColorPicker.color = node.color
		$ColorPicker.visible = true

func load_pal(spr:ggSprite):
	if spr.palette.size() == 0:
		return
	var colorCnt = (256 if spr.bpp == 8 else 16)
	var rowCnt = clamp(colorCnt / 16.0,1,16)
	var row = 1
	
	for node in ($"properties/PalView".get_children()):
		node.visible = false
	
	for i in range(rowCnt):
		var rowNode = get_node_or_null("properties/PalView/PalRow%d" % (i+1))
		if rowNode == null:
			rowNode = HBoxContainer.new()
			rowNode.name = "PalRow%d" % (i+1)
			rowNode.alignment = BoxContainer.ALIGNMENT_CENTER
			rowNode.custom_minimum_size = Vector2(0,16)
			$"properties/PalView".add_child(rowNode)
		else:
			rowNode.visible = true
	
	for i in range(colorCnt):
		if i % 16 == 0:
			row = i / 16.0
		var rowNode = get_node_or_null("properties/PalView/PalRow%d" % (row+1))
		
		var col: ColorRect
		var colnode = rowNode.get_node_or_null("Color%d" % i)
		if colnode != null:
			col = colnode
			col.color = spr.palette[i]
		else:
			col = ColorRect.new()
			col.name = "Color%d" % i
			col.custom_minimum_size = Vector2(16,16)
			col.color = spr.palette[i]
			col.gui_input.connect(show_picker.bind(col))
			var border = ReferenceRect.new()
			border.border_color = Color()
			border.editor_only = false
			border.custom_minimum_size = col.custom_minimum_size
			border.mouse_filter = Control.MOUSE_FILTER_IGNORE
			col.add_child(border)
			rowNode.add_child(col)

func _on_index_value_changed(value: float) -> void:
	$hint.visible = false
	$ColorPicker.visible = false
	selected_colnode = null
	var spr = spriteList[value]
	if spr.texture == null:
		spr.make_texture()
	$sprite.texture = spr.texture
	$properties/mode.selected = spr.mode
	$properties/pix/clut.value = spr.clut
	$properties/pix/bpp.value = spr.bpp
	$properties/siz/width.value = spr.width
	$properties/siz/height.value = spr.height
	$properties/mem/tw.value = spr.tw
	$properties/mem/th.value = spr.th
	$properties/mem/hash.text = "Hash: 0x%4X" % spr.hash
	if spr.width > 256 || spr.height > 256: $sprite.scale = Vector2(1,1)
	else: $sprite.scale = Vector2(2,2)
	load_pal(spr)

func _on_export_pressed() -> void:
	$exportFD.visible = true
	export = "single"

func _on_export_all_pressed() -> void:
	$exportFD.visible = true
	export = "all"

func _on_import_pressed() -> void:
	$importFD.visible = true

func _on_export_fd_dir_selected(dir: String) -> void:
	match export:
		"single":
			var spr = spriteList[$properties/index.value]
			match $exportFormat.selected:
				0:
					spr.texture.get_image().save_png("%s/Sprite_%04d.png" % [dir,$properties/index.value])
				1:
					var f = FileAccess.open("%s/Sprite_%04d.bin" % [dir,$properties/index.value],FileAccess.WRITE)
					f.store_buffer(spr.raw)
					f.close()
				2:
					#TODO convert 4 bpp sprites to 8 bpp before saving as raw
					var f = FileAccess.open("%s/Sprite_%04d-W-%d-H-%d.raw" % [dir,$properties/index.value,spr.width,spr.height],FileAccess.WRITE)
					f.store_buffer(spr.src)
					f.close()
		"all":
			for i in range(spriteList.size()):
				var spr = spriteList[i]
				if spr.texture == null: spr.make_texture()
				match $exportFormat.selected:
					0:
						spr.texture.get_image().save_png("%s/Sprite_%04d.png" % [dir,i])
					1:
						var f = FileAccess.open("%s/Sprite_%04d.bin" % [dir,i],FileAccess.WRITE)
						f.store_buffer(spr.raw)
						f.close()
					2:
						#TODO convert 4 bpp sprites to 8 bpp before saving as raw
						var f = FileAccess.open("%s/Sprite_%04d-W-%d-H-%d.raw" % [dir,i,spr.width,spr.height],FileAccess.WRITE)
						f.store_buffer(spr.src)
						f.close()
		_:
			return

func import_sprite_sub(type) -> void:
	var spr: ggSprite
	match importExt:
		"png":
			spr = ggSprite.new("image",importPath)
		"bin":
			spr = ggSprite.new("buffer",importF.get_buffer(importF.get_length()))
	match type:
		0:
			spriteList[$properties/index.value] = spr
			spr.make_texture()
			_on_index_value_changed($properties/index.value)
	importF.close()

func _on_import_fd_file_selected(path: String) -> void:
	importF = FileAccess.open(path,FileAccess.READ)
	importExt = path.get_slice(".",path.get_slice_count(".")-1)
	importExt = importExt.to_lower()
	importPath = path
	if !importF:
		#rpint the rror
		pass
	import_sprite_sub(0)

func _on_delete_pressed() -> void:
	var spr = spriteList[$properties/index.value]
	if spr.use.size() > 0:
		var txt = "Cannot delete sprite because it is being used by layer(s) "
		for i in range(spr.use.size()):
			if i > 0:
				txt += ", "
			txt += str(spr.use[i])
		$ConfirmationDialog.dialog_text = txt
		deletion = false
	elif spriteList.size() <= 1:
		$ConfirmationDialog.dialog_text = "Cannot delete sprite. Must have at least one"
		deletion = false
	else:
		$ConfirmationDialog.dialog_text = "Are you sure you want to delete this sprite?"
		deletion = true
	$ConfirmationDialog.visible = true

func _on_confirmation_dialog_confirmed() -> void:
	if deletion == true:
		spriteList.pop_at($properties/index.value)
		$properties/index.max_value -= 1
		if $properties/index.value > 0:
			_on_index_value_changed($properties/index.value-1)
		else:
			_on_index_value_changed(0)

func change_color(node, color, idx, spr):
	node.color = color
	spr.palette[idx.to_int()] = color
	spr.texture = null
	spr.make_texture()
	$sprite.texture = spr.texture

func undo_color(node, color, idx, spr):
	node.color = color
	spr.palette[idx.to_int()] = color
	spr.texture = null
	spr.make_texture()
	$sprite.texture = spr.texture

func _on_color_picker_color_changed(color: Color) -> void:
	var idx = selected_colnode.name.trim_prefix("Color")
	var spr = spriteList[$"properties/index".value]
	undo_redo.create_action("Change Color")
	undo_redo.add_do_method(change_color.bind(selected_colnode,color,idx,spr))
	undo_redo.add_undo_method(undo_color.bind(selected_colnode,selected_colnode.color,idx,spr))
	undo_redo.commit_action()

func _process(_delta: float) -> void:
	if get_parent().visible == false || visible == false:
		return
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
			var spr = spriteList[$"properties/index".value]
			undo_redo.create_action("Paste Color")
			undo_redo.add_do_method(change_color.bind(selected_colnode,copiedCol,idx,spr))
			undo_redo.add_undo_method(undo_color.bind(selected_colnode,selected_colnode.color,idx,spr))
			undo_redo.commit_action()
