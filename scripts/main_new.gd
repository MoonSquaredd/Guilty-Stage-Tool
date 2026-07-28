extends Node

const MAX_LOADED_STAGES = 8

var spriteView = preload("res://scenes/sprite_view.tscn")

var stage_buffers: Array[PackedByteArray] = []
var loaded_stages: Array[Stage] = []

func getFreeStageSlot() -> int:
	for i in range(MAX_LOADED_STAGES):
		if loaded_stages[i] == null:
			return i
	return -1

func reset():
	stage_buffers.clear()
	stage_buffers.resize(MAX_LOADED_STAGES)
	loaded_stages.clear()
	loaded_stages.resize(MAX_LOADED_STAGES)

func _ready() -> void:
	reset()
	$HUD/menus/fileMenu.get_popup().id_pressed.connect(_on_file_menu_pressed)
	$HUD/menus/editMenu.get_popup().id_pressed.connect(_on_edit_menu_pressed)
	$HUD/menus/viewMenu.get_popup().id_pressed.connect(_on_view_menu_pressed)

func _on_file_menu_pressed(id: int):
	match id:
		0: #Open
			$HUD/info.modulate = Color.WHITE
			$openStageFD.visible = true

func _on_edit_menu_pressed(id: int):
	pass

func _on_view_menu_pressed(id: int):
	pass

func _on_open_stage_fd_file_selected(path: String) -> void:
	$HUD/info.text = "Opening stage from %s ..." % path
	var f = FileAccess.open(path,FileAccess.READ)
	if f == null:
		$HUD/info.modulate = Color.RED
		$HUD/info.text = "Error %d!" % FileAccess.get_open_error()
		return
	var stgID = getFreeStageSlot()
	if stgID == -1:
		$HUD/info.modulate = Color.RED
		$HUD/info.text = "Maximum amount of stages loaded!"
		return
	stage_buffers[stgID] = f.get_buffer(f.get_length())
	loaded_stages[stgID] = Stage.new(stage_buffers[stgID],"AC")
	var stgTab = TabContainer.new()
	stgTab.name = path.get_slice("/",path.get_slice_count("/")-1)
	stgTab.self_modulate = Color(1,1,1,0.5)
	f.close()
	for i in range(1+loaded_stages[stgID].objects.size()):
		var objTab = TabContainer.new()
		objTab.self_modulate = Color(1,1,1,0.5)
		if i == 0:
			objTab.name = "Tileset Data"
			var sprVw = spriteView.instantiate()
			sprVw.spriteList = loaded_stages[stgID].tiles
			sprVw.get_node_or_null("properties").get_node_or_null("index").max_value = loaded_stages[stgID].tiles.size()-1
			sprVw.get_node_or_null("properties").get_node_or_null("index").emit_signal("value_changed",0)
			objTab.add_child(sprVw)
		else:
			objTab.name = "Object %d" % i
			var sprVw = spriteView.instantiate()
			sprVw.spriteList = loaded_stages[stgID].objects[i-1].sprites
			sprVw.get_node_or_null("properties").get_node_or_null("index").max_value = loaded_stages[stgID].objects[i-1].sprites.size()-1
			sprVw.get_node_or_null("properties").get_node_or_null("index").emit_signal("value_changed",0)
			objTab.add_child(sprVw)
		stgTab.add_child(objTab)
	$HUD/FileTabs.add_child(stgTab)
	$HUD/FileTabs.current_tab = $HUD/FileTabs.get_tab_idx_from_control(stgTab)
	$HUD/info.text = "Stage loaded!"
