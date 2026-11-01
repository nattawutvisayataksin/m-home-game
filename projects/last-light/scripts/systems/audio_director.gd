extends Node
class_name RunAudioDirector

const SOUND_PATHS: Dictionary = {
	"shot": "res://assets/audio/sfx/shot.wav",
	"hit": "res://assets/audio/sfx/hit.wav",
	"charge": "res://assets/audio/sfx/charge.wav",
	"upgrade": "res://assets/audio/sfx/upgrade.wav",
	"pulse": "res://assets/audio/sfx/pulse.wav",
	"warning": "res://assets/audio/sfx/warning.wav",
	"breach": "res://assets/audio/sfx/breach.wav",
}
const MUSIC_PATH: String = "res://assets/audio/music/beacon_ambient.wav"

var _players: Array[AudioStreamPlayer] = []
var _streams: Dictionary = {}
var _next_player: int = 0
var _music_player: AudioStreamPlayer


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		return
	for key: String in SOUND_PATHS:
		var path: String = SOUND_PATHS[key]
		if not ResourceLoader.exists(path):
			push_warning("SFX asset is missing: %s" % path)
			continue
		_streams[key] = load(path) as AudioStream
	for _i: int in range(8):
		var player := AudioStreamPlayer.new()
		player.bus = &"SFX"
		player.max_polyphony = 2
		add_child(player)
		_players.append(player)
	_start_ambient_music()


func _exit_tree() -> void:
	for player: AudioStreamPlayer in _players:
		if is_instance_valid(player):
			player.stop()
	if is_instance_valid(_music_player):
		_music_player.stop()


func play_sfx(key: String) -> void:
	if not _streams.has(key) or _players.is_empty():
		return
	var player: AudioStreamPlayer = _players[_next_player]
	_next_player = (_next_player + 1) % _players.size()
	player.stream = _streams[key]
	player.play()


func _start_ambient_music() -> void:
	if not ResourceLoader.exists(MUSIC_PATH):
		push_warning("Ambient music asset is missing: %s" % MUSIC_PATH)
		return
	var music_stream := load(MUSIC_PATH) as AudioStreamWAV
	if music_stream == null or music_stream.data.is_empty():
		push_error("Ambient music asset could not be loaded as a non-empty WAV stream.")
		return
	music_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	music_stream.loop_begin = 0
	music_stream.loop_end = int(music_stream.data.size() / 2)
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = &"Music"
	_music_player.volume_db = -12.0
	_music_player.stream = music_stream
	add_child(_music_player)
	_music_player.play()
