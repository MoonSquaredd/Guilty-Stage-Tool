extends Node

var sprView = preload("res://scenes/sprite_view.tscn")

@onready var conf = stageConfig.new()

const SEPARATOR = 0xFFFFFFFF

enum file_mode {
	OPEN_BG = 0,
	SAVE_BG = 1,
	IMPORT_OBJECT = 2,
	EXPORT_OBJECT = 3
}

var fileBuf = PackedByteArray()
var tiles: int
var org = PackedByteArray()
var orgAddr: int
var tileList = []
var objects = []
var animations = []
var fileMode

func reset():
	animations.clear()
	fileBuf.clear()
	objects.clear()
	tileList.clear()
	org.clear()
	$HUD/TabContainer.current_tab = 0
	for tab in $HUD/TabContainer.get_children():
		if tab.name != "Tiles":
			tab.free()
	$"HUD/TabContainer/Tiles/Tile View".spriteList.clear()
	$"HUD/TabContainer/Tiles/Tile View".call("reset")
	$"HUD/TabContainer/Tiles/Layer View".moveNode = $"Layers"
	$"HUD/TabContainer/Tiles/Layer View".highlight = $highlight
	$"HUD/TabContainer/Tiles/Layer View".layerList.clear()
	$"HUD/TabContainer/Tiles/Layer View".call("reset")

func parse_tiles():
	var i = 0
	while true:
		i += 1
		var addr = fileBuf.decode_u32(tiles+(i*4))
		if addr == SEPARATOR:
			break
		else:
			var spr = sprite.new(fileBuf,addr+tiles)
			spr.address = addr+tiles
			tileList.append(spr)

func parse_layers():
	var p = 0
	var lastLayer = -1
	var lastAnim = -1
	var lastAnimFrame = -1
	while p < org.size():
		var id = org.decode_u16(p)
		match id:
			layer.orgID.SPRITE:
				var tile = org.decode_u16(p+2)
				var xoff = org.decode_s16(p+4)
				var yoff = org.decode_s16(p+6)
				
				var entry = {
					i = tile,
					x = xoff,
					y = yoff
				}
				
				var spr = tileList[tile]
				
				if xoff < $"HUD/TabContainer/Tiles/Layer View".layerList[lastLayer].lowest_x:
					$"HUD/TabContainer/Tiles/Layer View".layerList[lastLayer].lowest_x = xoff
				elif xoff+spr.width > $"HUD/TabContainer/Tiles/Layer View".layerList[lastLayer].highest_x:
					$"HUD/TabContainer/Tiles/Layer View".layerList[lastLayer].highest_x = xoff+spr.width
				
				if yoff-spr.height < $"HUD/TabContainer/Tiles/Layer View".layerList[lastLayer].lowest_y:
					$"HUD/TabContainer/Tiles/Layer View".layerList[lastLayer].lowest_y = yoff-spr.height
				elif yoff > $"HUD/TabContainer/Tiles/Layer View".layerList[lastLayer].highest_y:
					$"HUD/TabContainer/Tiles/Layer View".layerList[lastLayer].highest_y = yoff
				
				$"HUD/TabContainer/Tiles/Layer View".layerList[lastLayer].tiles.append(entry)
				
				
				spr.layersUsing.append(lastLayer)
				p += 8
			layer.orgID.LAYER:
				var lyr = layer.new()
				lyr.address = orgAddr+p
				lyr.index = org.decode_u16(p+2)
				lyr.priority = org.decode_u16(p+4)
				lyr.scrollrate = org.decode_u16(p+6)
				lyr.xoffset = org.decode_s16(p+8)
				lyr.yoffset = org.decode_s16(p+10)
				$"HUD/TabContainer/Tiles/Layer View".layerList.append(lyr)
				$"HUD/TabContainer/Tiles/Layer View/Properties/Index".max_value = $"HUD/TabContainer/Tiles/Layer View".layerList.size()-1
				lastLayer += 1
				p += 12
			layer.orgID.BACKGROUND:
				$"HUD/TabContainer/Tiles/Layer View".layerList[lastLayer].background = true
				p += 4
			layer.orgID.FOREGROUND:
				$"HUD/TabContainer/Tiles/Layer View".layerList[lastLayer].foreground = true
				p += 4
			layer.orgID.ANIMATION:
				var anim = AnimLayer.new()
				animations.append(anim)
				lastAnimFrame = -1
				lastAnim += 1
				p += 4
			layer.orgID.UNK_10: 
				$"HUD/TabContainer/Tiles/Layer View".layerList[lastLayer].a = true
				p += 4
			layer.orgID.FLIP_HORIZONTAL: #only GGX, Reload and Slash Paris ever uses this
				$"HUD/TabContainer/Tiles/Layer View".layerList[lastLayer].flip = true
				p += 4
			layer.orgID.BLENDING_ADD:
				$"HUD/TabContainer/Tiles/Layer View".layerList[lastLayer].blend = true
				p += 4
			layer.orgID.UNK_13: 
				$"HUD/TabContainer/Tiles/Layer View".layerList[lastLayer].d = true
				p += 4
			layer.orgID.ANIM_DURATION:
				var animFrame = {
					duration = org.decode_u16(p+2),
					dur_min = org.decode_u16(p+2),
					dur_max = org.decode_u16(p+2),
					active_layers = [],
					inactive_layers = []
				}
				animations[lastAnim].frames.append(animFrame)
				lastAnimFrame += 1
				p += 4
			layer.orgID.ANIM_VAR_DURATION:
				var min = org.decode_u16(p+2)
				var max = org.decode_u16(p+4)
				var dur = randi_range(min,max)
				var animFrame = {
					duration = dur,
					dur_min = min,
					dur_max = max,
					active_layers = [],
					inactive_layers = []
				}
				animations[lastAnim].frames.append(animFrame)
				lastAnimFrame += 1
				p += 6
			layer.orgID.ANIM_LAYER_ON:
				animations[lastAnim].frames[lastAnimFrame].active_layers.append(org.decode_u16(p+2))
				p += 4
			layer.orgID.ANIM_LAYER_OFF:
				animations[lastAnim].frames[lastAnimFrame].inactive_layers.append(org.decode_u16(p+2))
				p += 4
			0xffff:
				break
			_:
				p += 4

func create_object_tab(obj):
	var tab = TabContainer.new()
	tab.name = "Object %d" % (objects.size()-1)
	var spriteView = sprView.instantiate()
	spriteView.spriteList = obj.sprites
	spriteView.call("_on_index_value_changed",0)
	tab.add_child(spriteView)
	$HUD/TabContainer.add_child(tab)

func separate(buf:PackedByteArray):
	var reminder = buf.size() % 16
	for i in range((16-reminder)):
		buf.append(0xFF)

func assemble_bg():
	var buf = PackedByteArray()
	buf.resize((objects.size()+2)*4)
	separate(buf)
	
	var newTiles = buf.size()
	buf.encode_u32(0,newTiles)
	buf.resize(buf.size()+(tileList.size()+1)*4)
	separate(buf)
	
	buf.encode_u32(newTiles,buf.size()-newTiles)
	var newOrg = PackedByteArray()
	var laylis = $"HUD/TabContainer/Tiles/Layer View".layerList
	for i in range(laylis.size()):
		var lyr = laylis[i]
		var lyBuf = lyr.assemble()
		newOrg.append_array(lyBuf)
	for i in range(animations.size()):
		var anim = animations[i]
		var aniBuf = anim.assemble()
		newOrg.append_array(aniBuf)
	separate(newOrg)
	buf.append_array(newOrg)
	
	for i in range(tileList.size()):
		var spr = tileList[i].assemble()
		buf.encode_u32(newTiles+((i+1)*4),buf.size()-newTiles)
		buf.append_array(spr)
	
	for i in range(objects.size()):
		var newObj = buf.size()
		buf.encode_u32((i+1)*4,newObj)
		var obj = objects[i].assemble()
		buf.append_array(obj)
	
	buf.encode_u32((objects.size()+1)*4,buf.size())
	return buf

func _on_tiles_tab_changed(tab: int) -> void:
	match tab:
		1:
			$Layers.visible = true
			$"HUD/TabContainer/Tiles/Layer View".call("_on_index_value_changed",$"HUD/TabContainer/Tiles/Layer View/Properties/Index".value)
		2:
			$Layers.visible = true
			for lyr in range($"HUD/TabContainer/Tiles/Layer View".layerList.size()):
				var id = $"HUD/TabContainer/Tiles/Layer View".layerList[lyr].index
				var layerNode = $Layers.get_node_or_null("Layer %d" % id)
				if layerNode == null:
					$"HUD/TabContainer/Tiles/Layer View".call("draw_layer",lyr)
			for lyr in $Layers.get_children():
				lyr.visible = true
		_: 
			$Layers.visible = false

func _on_tab_container_tab_changed(tab: int) -> void:
	if tab != 0:
		$Layers.visible = false
		$HUD/ExportObj.visible = true
		$HUD/DeleteObj.visible = true
	else:
		$HUD/ExportObj.visible = false
		$HUD/DeleteObj.visible = false
		_on_tiles_tab_changed($HUD/TabContainer/Tiles.current_tab)

func _on_open_bg_button_pressed() -> void:
	fileMode = file_mode.OPEN_BG
	$FileDialog.file_mode = 0
	$FileDialog.visible = true

func _on_save_bg_button_pressed() -> void:
	fileMode = file_mode.SAVE_BG
	$FileDialog.file_mode = 4
	$FileDialog.visible = true

func _on_import_obj_pressed() -> void:
	fileMode = file_mode.IMPORT_OBJECT
	$FileDialog.file_mode = 0
	$FileDialog.visible = true

func _on_export_obj_pressed() -> void:
	fileMode = file_mode.EXPORT_OBJECT
	$FileDialog.file_mode = 4
	$FileDialog.visible = true

func _on_delete_obj_pressed() -> void:
	var id = $HUD/TabContainer.current_tab - 1
	objects[id] = null
	var tab = $HUD/TabContainer.get_node_or_null("Object %d" % id)
	tab.free()
	$HUD/TabContainer.current_tab = id+1
	for i in range(objects.size()):
		if i > id:
			objects[i-1] = objects[i]
			tab = $HUD/TabContainer.get_node_or_null("Object %d" % i)
			tab.name = "Object %d" % (i-1)
		if i == objects.size()-1:
			objects[i] = null
			objects.resize(objects.size()-1)

func _on_file_dialog_file_selected(path: String) -> void:
	if $FileDialog.file_mode == 4:
		var buf
		match fileMode:
			file_mode.SAVE_BG:
				$HUD/Info.text = "Saved stage to " + path
				buf = assemble_bg()
			file_mode.EXPORT_OBJECT:
				var id = $HUD/TabContainer.current_tab - 1
				$HUD/Info.text = "Exported object %d to %s" % [id, path]
				buf = objects[id].assemble()
		var fw = FileAccess.open(path,FileAccess.WRITE)
		fw.store_buffer(buf)
		fw.close()
		return
	elif fileMode == file_mode.IMPORT_OBJECT:
		$HUD/Info.text = "Imported object from " + path
		var fr = FileAccess.open(path,FileAccess.READ)
		var buf = fr.get_buffer(fr.get_length())
		fr.close()
		var obj = object.new(0, buf.size(), buf)
		objects.append(obj)
		create_object_tab(obj)
		return
	reset()
	$HUD/Info.text = "Loaded stage from " + path
	var fr = FileAccess.open(path, FileAccess.READ)
	fileBuf = fr.get_buffer(fr.get_length())
	fr.close()
	
	tiles = fileBuf.decode_u32(0)
	print("Tiles:    0x%08X" % tiles)
	
	orgAddr = fileBuf.decode_u32(tiles)+tiles
	org = fileBuf.slice(orgAddr,fileBuf.decode_u32(tiles+4)+tiles)
	print("Orgaddr:  0x%08X" % orgAddr)
	
	for i in range(8):
		var addr = fileBuf.decode_u32((i+1)*4)
		if addr == SEPARATOR:
			break
		elif addr == fileBuf.size():
			break
		elif fileBuf.decode_u32(addr) == 0:
			break
		else:
			var obj = object.new(addr, fileBuf.decode_u32((i+2)*4), fileBuf)
			objects.append(obj)
			create_object_tab(obj)
			print("Object %d: 0x%08X" % [i, addr])
	parse_tiles()
	parse_layers()
	$"HUD/TabContainer/Tiles/Tile View".spriteList = tileList
	$"HUD/TabContainer/Tiles/Layer View".tileList = tileList
	$"HUD/TabContainer/Tiles/Tile View/Properties/Index".max_value = tileList.size()-1
	$"HUD/TabContainer/Tiles/Tile View".call("_on_index_value_changed",0)
	$"HUD/TabContainer/Tiles/Layer View".call("_on_index_value_changed",0)
	_on_tiles_tab_changed($HUD/TabContainer/Tiles.current_tab)
	$"HUD/TabContainer/Tiles/Tile View/Properties/Buttons/Import".disabled = false
	$"HUD/TabContainer/Tiles/Tile View/Properties/Buttons/Export".disabled = false
	$"HUD/TabContainer/Tiles/Tile View/Properties/Buttons/ExportAll".disabled = false

func _on_load_config_item_selected(index: int) -> void:
	if conf.loadedConfig != index:
		conf.load_config(index,$Layers.get_children(),animations,objects)

func _ready() -> void:
	reset()
	for i in range(conf.stages.size()):
		var name = conf.stages.keys()[i]
		name = name.replace_char("_".unicode_at(0)," ".unicode_at(0))
		var value = conf.stages.values()[i]
		$"HUD/TabContainer/Tiles/Stage View/Properties/LoadConfig".add_item(name,value)
	$"HUD/TabContainer/Tiles/Stage View/Properties/LoadConfig".selected = conf.stages.None
	$"HUD/TabContainer/Tiles/Tile View/Properties/Buttons/Import".disabled = true
	$"HUD/TabContainer/Tiles/Tile View/Properties/Buttons/Export".disabled = true
	$"HUD/TabContainer/Tiles/Tile View/Properties/Buttons/ExportAll".disabled = true

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("hide_hud"):
		$HUD.visible = !$HUD.visible
	if Input.is_action_pressed("reset_camera"):
		$Camera.offset = Vector2(640,360)
		$Camera.zoom = Vector2(1,1)
	
	if Input.is_action_pressed("camera_up"):
		$Camera.offset.y -= 8
	if Input.is_action_pressed("camera_left"):
		$Camera.offset.x -= 8
	if Input.is_action_pressed("camera_down"):
		$Camera.offset.y += 8
	if Input.is_action_pressed("camera_right"):
		$Camera.offset.x += 8
	if Input.is_action_pressed("camera_zoom_in"):
		$Camera.zoom += Vector2(2*delta,2*delta)
	if Input.is_action_pressed("camera_zoom_out"):
		$Camera.zoom -= Vector2(2*delta,2*delta)
		
	if $"HUD/TabContainer/Tiles/Stage View/Properties/animToggle".button_pressed == true && $HUD/TabContainer/Tiles.current_tab == 2:
		for i in range(animations.size()):
			var anim = animations[i]
			var frame = anim.frames[anim.current]
			
			if anim.frame > frame.duration:
				anim.frame = 0
				anim.current += 1
				if anim.current > anim.frames.size()-1:
					anim.current = 0
			else:
				for j in frame.active_layers:
					var lyr = $Layers.get_node_or_null("Layer %d" % j)
					if lyr != null:
						lyr.visible = anim.enabled
				for j in frame.inactive_layers:
					var lyr = $Layers.get_node_or_null("Layer %d" % j)
					if lyr != null:
						lyr.visible = false
				anim.frame += 1
