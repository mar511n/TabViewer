extends Control

export (DynamicFont) var TabFont
var orientation_portrait = true
const new_tab_name = "new_tab.txt"
var sort_by_name = false

var player = NoteScale.new()
var current_scrollbar = VScrollBar.new()

func _ready():
	#file_list_scrollbar = $TabContainer/Collection/TABCollection.get_v_scroll()
	update_collection()
	$HTTPRequest.connect("request_completed", self, "_on_request_completed")
	
	player.initialize($AudioStreamPlayer)
	player.connect("on_playing_finished", self, "on_playing_finished")
	player.connect("progress", self, "on_playing_progress")
	add_child(player)
	#player.play_sounds(NoteScale.get_next_tabline_sounds(NoteScale.example_tab_str), 0.05)


var currentContent = ""
func _on_LoadTab_pressed():
	$HTTPRequest.request_raw(OS.clipboard)

func _on_request_completed(result, response_code, headers, body):
	#print(result, ":", response_code, ":", headers, ":", body)
	if result != HTTPRequest.RESULT_SUCCESS:
		show_error("Error downloading html\nCode: "+String(result))
		return
	var content = format_ultimate_guitar_to_tab(body)
	$TabContainer/TabViewer/ScrollContainer/Label.text = content
	currentContent = content
	$TabContainer/Collection/LineEdit.text = new_tab_name
	

func format_ultimate_guitar_to_tab(body):
	var text = body.get_string_from_utf8()
	print(text.length())
	var content = ""
	var idx = text.find("&quot;content&quot;:&quot;")
	if idx >= 0:
		text = text.replace("[tab]", "")
		text = text.replace("[/tab]", "")
		text = text.right(idx+26)
		var end_1 = text.find("&quot;},&quot;")
		var end_2 = text.find("&quot;,&quot;")
		text = text.left(min(end_1, end_2))
		text = text.replace("&quot;", "\"".c_unescape())
		text = text.replace("[ch]", "")
		text = text.replace("[/ch]", "")
		text = text.replace("&rsquo;", "´")
		text = text.replace("&amp;", "&")
		text = text.replace("&auml;", "ä")
		text = text.replace("&szlig;", "ß")
		text = text.replace("&uuml;", "ü")
		text = text.replace("&ouml;", "ö")
		text = text.replace("&#039;", "'")
		text = text.replace("&lsquo;", "‘")
		text = text.c_unescape()
		var lines = text.split("\r\n".c_escape())
		for l in lines:
			content += l+"\n"
	return content

func _on_CopyTab_pressed():
	OS.clipboard = currentContent
	
	
func _on_TabTextSizeSlider_value_changed(value):
	TabFont.size = value
func _on_BackgroundColorPickerButton_color_changed(color):
	$ColorRect.color = color


func _on_SaveTABButton_pressed():
	if has_filename($TabContainer/Collection/LineEdit.text):
		$TabContainer/Collection/OverwriteDialog.dialog_text = "Do you really want to overwrite the file '{filename}'?".format({"filename":$TabContainer/Collection/LineEdit.text})
		$TabContainer/Collection/OverwriteDialog.popup_centered()
	else:
		_on_OverwriteDialog_confirmed()

func _on_OverwriteDialog_confirmed():
	var file = File.new()
	file.open("user://"+$TabContainer/Collection/LineEdit.text, File.WRITE)
	file.store_string(currentContent)
	file.close()
	update_collection()

func _on_LoadTABButton_pressed():
	var file = File.new()
	file.open("user://"+$TabContainer/Collection/LineEdit.text, File.READ)
	currentContent = file.get_as_text()
	file.close()
	$TabContainer/TabViewer/ScrollContainer/Label.text = currentContent

func update_collection():
	$TabContainer/Collection/TABCollection.clear()
	var dir = Directory.new()
	dir.open("user://")
	dir.list_dir_begin(true, true)
	var file_name = dir.get_next()
	while file_name != "":
		if file_name.is_valid_filename() and dir.file_exists(file_name) and !dir.current_is_dir() and file_name != "logs":
			$TabContainer/Collection/TABCollection.add_item(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	if sort_by_name:
		$TabContainer/Collection/TABCollection.sort_items_by_text()

func _on_TABCollection_item_selected(index):
	$TabContainer/Collection/LineEdit.text = $TabContainer/Collection/TABCollection.get_item_text(index)

func _on_DeleteTABButton_pressed():
	var dir = Directory.new()
	dir.remove("user://"+$TabContainer/Collection/LineEdit.text)
	update_collection()

func _on_PasteTab_pressed():
	currentContent = OS.clipboard
	$TabContainer/TabViewer/ScrollContainer/Label.text = currentContent
	$TabContainer/Collection/LineEdit.text = new_tab_name

func _on_OrientationChanger_pressed():
	orientation_portrait = !orientation_portrait
	if orientation_portrait:
		$TabContainer/Settings/VBoxContainer/OrientationChanger.text = "landscape"
		OS.set_screen_orientation(OS.SCREEN_ORIENTATION_PORTRAIT)
	else:
		$TabContainer/Settings/VBoxContainer/OrientationChanger.text = "portrait"
		OS.set_screen_orientation(OS.SCREEN_ORIENTATION_LANDSCAPE)

func _on_CopyCollectionButton_pressed():
	update_collection()
	var dict = {}
	var i = 0
	while i < $TabContainer/Collection/TABCollection.get_item_count():
		var fn = $TabContainer/Collection/TABCollection.get_item_text(i)
		var file = File.new()
		file.open("user://"+fn, File.READ)
		var text = file.get_as_text()
		file.close()
		dict[fn] = text
		i += 1
	var bytes = var2bytes(dict)
	#var content = Marshalls.variant_to_base64([bytes.size(), bytes.compress(File.COMPRESSION_FASTLZ)])
	#print("FASTLZ:"+str(len(content)))
	#content = Marshalls.variant_to_base64([bytes.size(), bytes.compress(File.COMPRESSION_DEFLATE)])
	#print("DEFLATE:"+str(len(content)))
	#content = Marshalls.variant_to_base64([bytes.size(), bytes.compress(File.COMPRESSION_ZSTD)])
	#print("ZSTD:"+str(len(content)))
	var content = Marshalls.variant_to_base64([bytes.size(), bytes.compress(File.COMPRESSION_GZIP)])
	#print("GZIP:"+str(len(content)))
	OS.clipboard = content
	

func _on_PasteCollectionButton_pressed():
	var parse_r = Marshalls.base64_to_variant(OS.clipboard)
	if typeof(parse_r) != TYPE_ARRAY:
		show_error("Error parsing JSON")
		return
	var dict = bytes2var(parse_r[1].decompress(parse_r[0], File.COMPRESSION_GZIP))
	for fn in dict:
		var file = File.new()
		file.open("user://"+fn, File.WRITE)
		file.store_string(dict[fn])
		file.close()
	update_collection()

func show_error(err):
	$ErrorDialog.dialog_text = "\n"+err
	$ErrorDialog.show()

var note_duration = 0.1
var note_equal_duration = true

func _on_LineUp_pressed():
	$TabContainer/TabViewer/HBoxContainer2/LineIdx.text = String(int($TabContainer/TabViewer/HBoxContainer2/LineIdx.text)+1)

func _on_LineDown_pressed():
	$TabContainer/TabViewer/HBoxContainer2/LineIdx.text = String(int($TabContainer/TabViewer/HBoxContainer2/LineIdx.text)-1)

func get_current_tab_line():
	return int($TabContainer/TabViewer/HBoxContainer2/LineIdx.text)-1

func _on_Play_pressed():
	var res = NoteScale.get_next_tabline_sounds(currentContent, get_current_tab_line())
	if res[0] == "":
		if note_equal_duration:
			player.play_sounds_with_uniform_length(res[1], note_duration)
		else:
			player.play_sounds(res[1], note_duration)
	else:
		$TabContainer/TabViewer/HBoxContainer2/LineIdx.text = "1"

func on_playing_finished():
	_on_LineUp_pressed()
	_on_Play_pressed()

func _on_Stop_pressed():
	player.pause_playing()

func on_playing_progress(p):
	$TabContainer/TabViewer/ProgressBar.value = p*100


func _on_NoteDuration_value_changed(value):
	note_duration = value


func _on_NoteEqualDuration_pressed():
	note_equal_duration = !note_equal_duration
	if note_equal_duration:
		$TabContainer/Settings/VBoxContainer/NoteEqualDuration.text = "off"
	else:
		$TabContainer/Settings/VBoxContainer/NoteEqualDuration.text = "on"

func has_filename(filename):
	for i in range($TabContainer/Collection/TABCollection.get_item_count()):
		if $TabContainer/Collection/TABCollection.get_item_text(i) == filename:
			return true
	return false

func _on_SortBy_toggled(button_pressed):
	sort_by_name = button_pressed
	update_collection()

var swipe_start_y = 0
var swipe_start_value = 0
var swipe_start_time = 0
var swiping = false
var passive_scrolling = false
var passive_scrolling_vel = 0.0
const min_passive_vel = 100
const passive_vel_mul = 0.97
func _on_gui_input(event):
	if event is InputEventMouseButton:
		if event.button_index == BUTTON_LEFT:
			if event.pressed and !swiping:
				swiping = true
				swipe_start_value = current_scrollbar.value
				swipe_start_y = event.global_position.y
				swipe_start_time = float(Time.get_ticks_msec())/1000.0
			elif !event.pressed and swiping:
				swiping = false
				passive_scrolling_vel = (event.global_position.y-swipe_start_y)/(float(Time.get_ticks_msec())/1000.0 - swipe_start_time)
				passive_scrolling = true
	elif swiping and event is InputEventMouseMotion:
		current_scrollbar.value = swipe_start_value-(event.global_position.y-swipe_start_y)
		#if !passive_scrolling:
		#	passive_scrolling_vel = float(event.speed.y)

func _process(delta):
	$TabContainer/Info/ClipboardText.text = OS.clipboard
	if passive_scrolling:
		if abs(passive_scrolling_vel) < min_passive_vel:
			passive_scrolling = false
		print("passive scrolling with "+str(passive_scrolling_vel))
		passive_scrolling_vel *= passive_vel_mul
		current_scrollbar.value -= passive_scrolling_vel*delta


func _on_TabContainer_tab_changed(tab):
	if tab == 2:
		current_scrollbar = $TabContainer/Chords/RichTextLabel.get_v_scroll()
	else:
		current_scrollbar = $TabContainer/Collection/TABCollection.get_v_scroll()
