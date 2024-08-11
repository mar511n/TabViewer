extends Node

class_name NoteScale

signal on_playing_finished()
signal progress(p)

var is_playing = false
var currently_playing_sounds = []
var current_note_idx = 0
var time_counter = 0.0
var time_for_minus_sign = 0.1
var is_playing_sounds_with_uniform_length = false
var sounds_uniform_length = 0.0

func _process(delta):
	if is_playing:
		time_counter += delta
		var current_note_length = sounds_uniform_length
		if !is_playing_sounds_with_uniform_length:
			current_note_length = float(currently_playing_sounds[current_note_idx-1][1])*time_for_minus_sign
		if time_counter >= current_note_length:
			if current_note_idx >= currently_playing_sounds.size():
				is_playing = false
				emit_signal("on_playing_finished")
				return
			time_counter = 0.0
			play_audio_stream_from_sounds(currently_playing_sounds[current_note_idx])
			current_note_idx += 1
			emit_signal("progress", get_progress())

func pause_playing():
	is_playing = false

func resume_playing():
	is_playing = true

func play_sounds_with_uniform_length(sounds, tfms):
	sounds_uniform_length = tfms*4
	play_sounds(sounds, tfms)
	is_playing_sounds_with_uniform_length = true

func play_sounds(sounds, tfms):
	is_playing_sounds_with_uniform_length = false
	time_for_minus_sign = tfms
	is_playing = true
	currently_playing_sounds = sounds
	current_note_idx = 1
	time_counter = 0.0
	play_audio_stream_from_sounds(currently_playing_sounds[current_note_idx-1])
	emit_signal("progress", get_progress())

func get_progress():
	return float(current_note_idx)/float(currently_playing_sounds.size())

#var volume_for_notes = [0.0, -3.0, -7.0, -7.0, -8.0, -9.0]
func play_audio_stream_from_sounds(sound):
	#AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), volume_for_notes[sound[0].size()-1])
	for i in range(sound[0].size()):
		play_audio_stream(sound[0][i][0], sound[0][i][1])

var audio_source_note = ["c", 2, ""]
var audio_source_note_freq = 0.0
func play_audio_stream(string_idx, freq):
	var effect = audio_effects[string_idx]
	effect.set_pitch_scale(freq/audio_source_note_freq)
	stream_players[string_idx].play(0.0)

var stream_players =  []
var audio_effects = []
func initialize(audiostreamplayer_original):
	audio_source_note_freq = get_note_frequency(audio_source_note)
	for i in range(guitar_strings):
		var stream_player = audiostreamplayer_original.duplicate()
		stream_player.set_bus("String"+String(i+1))
		audio_effects.append(AudioServer.get_bus_effect(AudioServer.get_bus_index("String"+String(i+1)), 0))
		stream_players.append(stream_player)
		add_child(stream_player)

const note_scale = ["a","b","c","d","e","f","g","a"]
const base_note_ref = ["c", 0, ""]

const guitar_max_frets = 20
const guitar_strings = 6
const guitar_standard_open_notes = [["e",2,""],["b",1,""],["g",1,""],["d",1,""],["a",0,""],["e",0,""]]
const guitar_string_tunings = 	[
								{"e":["e",2,""], "d":["d",2,""], "f":["f",2,""]},
								{"b":["b",1,""], "a":["a",1,""], "c":["c",2,""]},
								{"g":["g",1,""], "f":["f",1,""], "a":["a",1,""]},
								{"d":["d",1,""], "c":["c",1,""], "e":["e",1,""]},
								{"a":["a",0,""], "g":["g",0,""], "b":["b",0,""]},
								{"e":["e",0,""], "d":["d",0,""], "f":["f",0,""]},
								]

const fret_char_to_int = {"0":0, "1":1, "2":2, "3":3, "4":4, "5":5, "6":6, "7":7, "8":8, "9":9}

const example_tab_str = "e||--0----------------0----------------|--0----------------0----------------|\nB||------------1h--3------------1h--3--|------------1h--3------------1h--3--|\nG||-------2----------------2-----------|-------2----------------2-----------|\nD||------------------------------------|------------------------------------|\nA||--0----------------0----------------|--0----------------0----------------|\nE||------------------------------------|------------------------------------|\n"

static func get_next_tabline_sounds(tabstr, tab_line_idx):
	tabstr = tabstr.to_lower()
	
	for i in range(tab_line_idx):
		tabstr = tabstr.right(tabstr.find("|"))
		for i2 in range(guitar_strings):
			tabstr = tabstr.right(tabstr.find("\n")+1)
	
	tabstr = tabstr.right(tabstr.find("|")-1).replace("|", "-")
	var lines = tabstr.split("\n", false, 6)
	lines.resize(6)
	
	var tuning = []
	var sounds = [] # [[freq1, freq2, ...], duration]
	for line in range(guitar_strings):
		var key = lines[line].substr(0,1).to_lower()
		if !guitar_string_tunings[line].has(key):
			return ["Error line not found", ""]
		tuning.append(guitar_string_tunings[line][key])
		lines[line] = lines[line].right(1)
	var current_duration = 0
	var current_freq = []
	for idx in range(lines[0].length()):
		var has_no_note = true
		for line_idx in range(guitar_strings):
			var character = lines[line_idx].substr(idx, 1)
			if character_is_number(character):
				if idx > 0:
					if !character_is_number(lines[line_idx].substr(idx-1, 1)):
						has_no_note = false
						break
		current_duration += 1
		if !has_no_note:
			if current_freq.size() > 0:
				sounds.append([current_freq, current_duration])
			current_duration = 0
			current_freq = []
			for line_idx in range(guitar_strings):
				var character = lines[line_idx].substr(idx, 1)
				if character_is_number(character):
					var character2 = lines[line_idx].substr(idx+1, 1)
					if character_is_number(character2):
						character += character2
					var note = half_steps_up(copy_note(tuning[line_idx]), int(character))
					current_freq.append([line_idx, get_note_frequency(note)])
	sounds.append([current_freq, current_duration+2])
	#print(sounds)
	return ["", sounds]

static func character_is_number(c):
	return "0123456789".find(c) >= 0

static func half_steps_from_base_note(note):
	var steps = note[1]*12
	if note[2] == "f":
		steps -= 1
	elif note[2] == "s":
		steps += 1
	if note[0] == "d":
		steps += 2
	elif note[0] == "e":
		steps += 4
	elif note[0] == "f":
		steps += 5
	elif note[0] == "g":
		steps += 7
	elif note[0] == "a":
		steps += 9
	elif note[0] == "b":
		steps += 11
	return steps

static func get_note_frequency(note):
	var n = 16 + half_steps_from_base_note(note)
	var freq = pow(2.0, (n-49.0)/12.0)*440.0
	return freq

static func half_steps_up(note, steps):
	for i in range(steps):
		note = half_step_up(note)
	return note

static func half_steps_down(note, steps):
	for i in range(steps):
		note = half_step_down(note)
	return note

static func half_step_up(note):
	if note[2] == "f":
		note[2] = ""
	elif note[2] == "s":
		note[2] = ""
		note[0] = get_next_note(note[0])
		if note[0] == "c":
			note[1] = note[1]+1
	elif note[0] == "b":
		note[0] = "c"
		note[1] = note[1]+1
	elif note[0] == "e":
		note[0] = "f"
	else:
		note[2] = "s"
	return note

static func half_step_down(note):
	if note[2] == "s":
		note[2] = ""
	elif note[2] == "f":
		note[2] = ""
		note[0] = get_last_note(note[0])
		if note[0] == "b":
			note[1] = note[1]-1
	elif note[0] == "c":
		note[0] = "b"
		note[1] = note[1]-1
	elif note[0] == "f":
		note[0] = "e"
	else:
		note[2] = "f"
	return note

static func half_steps_dif(from, to):
	return half_steps_from_base_note(to) - half_steps_from_base_note(from)

static func note_to_string(note):
	if note.size() == 0:
		return ""
	var ns = note[0]
	for i in range(note[1]):
		ns += "'"
	if note[2] == "f":
		ns += "b"
	elif note[2] == "s":
		ns += "#"
	return ns

static func copy_note(n1):
	return [n1[0], n1[1], n1[2]]

static func note_equal(n1,n2):
	return n1[0]==n2[0] and n1[1]==n2[1] and n1[2]==n2[2]

static func get_next_note(note):
	return note_scale[note_scale.find(note)+1]
static func get_last_note(note):
	return note_scale[note_scale.find_last(note)-1]
