class_name TDAudioDirector
extends Node

## Audio owner for a 3D run: a round-robin pool of SFX players on the SFX bus
## plus a looping ambient beacon on the Music bus. Modeled on the 2D build's
## RunAudioDirector (same pool pattern); volumes are owned by the TDSettings
## autoload via the bus layout — the director only plays, never mixes.

const SOUND_PATHS: Dictionary = {
	"turret_shot": "res://assets/audio/sfx/turret_shot.wav",
	"resonator_pulse": "res://assets/audio/sfx/resonator_pulse.wav",
	"tangle_cast": "res://assets/audio/sfx/tangle_cast.wav",
	"arc_burst": "res://assets/audio/sfx/arc_burst.wav",
	"hit": "res://assets/audio/sfx/hit.wav",
	"leak": "res://assets/audio/sfx/leak.wav",
	"breach": "res://assets/audio/sfx/breach.wav",
	"wave_horn": "res://assets/audio/sfx/wave_horn.wav",
	"build": "res://assets/audio/sfx/build.wav",
	"upgrade": "res://assets/audio/sfx/upgrade.wav",
	"sell": "res://assets/audio/sfx/sell.wav",
}
const MUSIC_PATH: String = "res://assets/audio/music/beacon_ambient_3d.wav"
const AMBIENT_DB: float = -12.0

var _players: Array[AudioStreamPlayer] = []
var _streams: Dictionary = {}
var _next_player: int = 0
var _music_player: AudioStreamPlayer


func _ready() -> void:
	# Headless test runs have no audio device; keep the director inert there.
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


## True when the director actually loaded playable assets this session.
func is_enabled() -> bool:
	return not _players.is_empty()


func play_sfx(key: String, pitch_jitter: float = 0.0, base_pitch: float = 1.0) -> void:
	if not _streams.has(key) or _players.is_empty():
		return
	var player: AudioStreamPlayer = _players[_next_player]
	_next_player = (_next_player + 1) % _players.size()
	player.stream = _streams[key]
	# Slight pitch variation avoids shot repetition fatigue; 0 keeps it exact.
	var jitter: float = randf_range(-pitch_jitter, pitch_jitter) if pitch_jitter > 0.0 else 0.0
	player.pitch_scale = base_pitch + jitter
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
	music_stream.loop_end = int(music_stream.data.size() / 2)  # frames for 16-bit mono
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = &"Music"
	_music_player.volume_db = AMBIENT_DB
	_music_player.stream = music_stream
	add_child(_music_player)
	_music_player.play()
