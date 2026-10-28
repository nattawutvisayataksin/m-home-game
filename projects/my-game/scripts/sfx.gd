extends Node
## Sfx — ระบบเสียงของเกม (autoload) — โหลด WAV ครั้งเดียว เล่นผ่านพูล 10 ช่องกันเสียงตัดกัน
## pitch สุ่มเล็กน้อยต่อการเล่น = SFX variation (เสียงเตะ/เด้งไม่ซ้ำแบบเดิมทุกครั้ง)
## เสียงประจำ: kick เตะ, bounce เด้ง, whistle นกหวีดเริ่ม/จบ, goal เชียร์, ooh เสียงคนอุ้ย,
## pickup เก็บไอเทม, gate กำแพงเวท, power ใช้ไอเทม, crowd เสียงแฟนบอลลูปพื้นหลัง

const PATHS := {
	&"kick": "res://assets/sfx/kick.wav",
	&"bounce": "res://assets/sfx/bounce.wav",
	&"whistle": "res://assets/sfx/whistle_start.wav",
	&"whistle_end": "res://assets/sfx/whistle_end.wav",
	&"goal": "res://assets/sfx/goal.wav",
	&"ooh": "res://assets/sfx/ooh.wav",
	&"pickup": "res://assets/sfx/pickup.wav",
	&"gate": "res://assets/sfx/gate.wav",
	&"power": "res://assets/sfx/power.wav",
}
const VOLUME := {
	&"kick": -4.0, &"bounce": -9.0, &"whistle": -8.0, &"whistle_end": -8.0,
	&"goal": -2.0, &"ooh": -6.0, &"pickup": -7.0, &"gate": -8.0, &"power": -7.0,
}
const POOL_SIZE := 10
const CROWD_DB := -16.0

var _streams := {}
var _pool: Array[AudioStreamPlayer] = []
var _next := 0
var _crowd: AudioStreamPlayer = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for k in PATHS:
		var s: AudioStream = load(PATHS[k])
		if s != null:
			_streams[k] = s
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = &"Master"
		add_child(p)
		_pool.append(p)

## เล่นเสียงแบบสุ่ม pitch เล็กน้อย (jitter=0.0 เพื่อคงระดับ เช่น นกหวีด/ดิ้ง)
func play(k: StringName, jitter := 0.05) -> void:
	var s: AudioStream = _streams.get(k)
	if s == null:
		return
	var p := _pool[_next]
	_next = (_next + 1) % POOL_SIZE
	p.stop()
	p.stream = s
	p.volume_db = float(VOLUME.get(k, -6.0))
	p.pitch_scale = 1.0 + randf_range(-jitter, jitter)
	p.play()

## เสียงแฟนบอลพื้นหลัง — เรียกตอนเข้าสนาม (กันซ้ำเอง)
func start_crowd() -> void:
	if _crowd != null:
		return
	var s: AudioStream = load("res://assets/sfx/crowd.wav")
	if s == null:
		return
	if s is AudioStreamWAV:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = int(s.get_length() * s.mix_rate)
	_crowd = AudioStreamPlayer.new()
	_crowd.stream = s
	_crowd.volume_db = CROWD_DB
	add_child(_crowd)
	_crowd.play()

## หยุดเสียงแฟนบอล — เรียกตอนออกจากสนาม
func stop_crowd() -> void:
	if _crowd != null and is_instance_valid(_crowd):
		_crowd.queue_free()
	_crowd = null
