extends Node

const MENU_TRACK := preload("res://audio/Outlaw Loops - Modern Western Music/Outlaw Loops - Modern Western Music/Rambling 154 BPM Loop.wav")
const COMBAT_TRACKS := [
	preload("res://audio/Outlaw Loops - Modern Western Music/Outlaw Loops - Modern Western Music/End of the Rope B 172 BPM Loop.wav"),
	preload("res://audio/Outlaw Loops - Modern Western Music/Outlaw Loops - Modern Western Music/End of the Rope C 172 BPM Loop.wav"),
	preload("res://audio/Outlaw Loops - Modern Western Music/Outlaw Loops - Modern Western Music/End of the Rope A 172 BPM Loop.wav"),
]

var _player := AudioStreamPlayer.new()
var _last_combat_track: AudioStream


func _ready() -> void:
	add_child(_player)
	# The .wav files are imported without looping, so replay the track when it ends.
	_player.finished.connect(_on_track_finished)


func play_track(track: AudioStream) -> void:
	if _player.stream == track and _player.playing:
		return
	_player.stream = track
	_player.play()


func _on_track_finished() -> void:
	if _player.stream != null:
		_player.play()


func play_menu() -> void:
	play_track(MENU_TRACK)


func play_combat() -> void:
	# Sorteia uma faixa, evitando repetir a do combate anterior.
	var options := COMBAT_TRACKS.filter(func(t): return t != _last_combat_track)
	_last_combat_track = options.pick_random()
	play_track(_last_combat_track)
