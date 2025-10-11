extends Node

var sprView = preload("res://scenes/sprite_view.tscn")

const SEPARATOR = 0xFFFFFFFF

var fileBuf = PackedByteArray()
var tiles: int
var org = PackedByteArray()
var orgAddr: int
var tileList = []
var objects = []

func reset():
	fileBuf.clear()
	objects.clear()
	tileList.clear()
	$HUD/TabContainer.current_tab = 0
	for tab in $HUD/TabContainer.get_children():
		if tab.name != "Tiles":
			tab.free()
	$"HUD/TabContainer/Tiles/Tile View".spriteList.clear()
	$"HUD/TabContainer/Tiles/Tile View".call("reset")
	$"HUD/TabContainer/Tiles/Layer View".moveNode = $"Layers"
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
	while p < org.size():
		var id = org.decode_u16(p)
		match id:
			layer.orgID.SPRITE:
				var spr = tileList[org.decode_u16(p+2)]
				spr.layersUsing.append(lastLayer)
				p += 8
			layer.orgID.LAYER:
				var lyr = layer.new()
				lyr.address = orgAddr+p
				lyr.index = org.decode_u16(p+2)
				print("layer %d" % lyr.index)
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
				p += 4
			layer.orgID.UNK_11: #only Reload and Slash Paris ever uses this
				$"HUD/TabContainer/Tiles/Layer View".layerList[lastLayer].b = true
				p += 4
			layer.orgID.ANIM_VAR_DURATION:
				p += 6
			0xffff:
				break
			_:
				p += 4

func separate(buf:PackedByteArray):
	var reminder = buf.size() % 16
	for i in range((16-reminder)):
		buf.append(0xFF)

func assembly_bg():
	var buf = PackedByteArray()
	buf.resize((objects.size()+2)*4)
	separate(buf)
	
	var newTiles = buf.size()
	buf.encode_u32(0,newTiles)
	buf.resize(buf.size()+(tileList.size()+1)*4)
	separate(buf)
	
	buf.encode_u32(newTiles,buf.size()-newTiles)
	buf.append_array(org)
	
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
			$"HUD/TabContainer/Tiles/Layer View".call("_on_index_value_changed",0)
		2:
			$Layers.visible = true
			for lyr in $"HUD/TabContainer/Tiles/Layer View".layerList:
				$"HUD/TabContainer/Tiles/Layer View".call("draw_layer",lyr)
			for lyr in $Layers.get_children():
				lyr.visible = true
		_: 
			$Layers.visible = false

func _on_tab_container_tab_changed(tab: int) -> void:
	if tab != 0:
		$Layers.visible = false
	else:
		_on_tiles_tab_changed($HUD/TabContainer/Tiles.current_tab)

func _on_open_bg_button_pressed() -> void:
	$FileDialog.file_mode = 0
	$FileDialog.visible = true

func _on_save_bg_button_pressed() -> void:
	$FileDialog.file_mode = 4
	$FileDialog.visible = true

func _on_file_dialog_file_selected(path: String) -> void:
	if $FileDialog.file_mode == 4:
		var buf = assembly_bg()
		var fw = FileAccess.open(path,FileAccess.WRITE)
		fw.store_buffer(buf)
		fw.close()
		return
	reset()
	print(path)
	var fr = FileAccess.open(path, FileAccess.READ)
	fileBuf = fr.get_buffer(fr.get_length())
	fr.close()
	
	tiles = fileBuf.decode_u32(0)
	print("Tiles:    0x%08X" % tiles)
	
	orgAddr = fileBuf.decode_u32(tiles)+tiles
	org = fileBuf.slice(orgAddr,fileBuf.decode_u32(tiles+4)+tiles)
	$"HUD/TabContainer/Tiles/Layer View".org = org
	$"HUD/TabContainer/Tiles/Layer View".orgAddr = orgAddr
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
			var tab = TabContainer.new()
			tab.name = "Object %d" % i
			var spriteView = sprView.instantiate()
			spriteView.spriteList = obj.sprites
			spriteView.call("_on_index_value_changed",0)
			tab.add_child(spriteView)
			$HUD/TabContainer.add_child(tab)
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

func _ready() -> void:
	reset()
	$"HUD/TabContainer/Tiles/Tile View/Properties/Buttons/Import".disabled = true
	$"HUD/TabContainer/Tiles/Tile View/Properties/Buttons/Export".disabled = true
	$"HUD/TabContainer/Tiles/Tile View/Properties/Buttons/ExportAll".disabled = true

func _process(delta: float) -> void:
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
