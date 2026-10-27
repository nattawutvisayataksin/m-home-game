extends Node
## Autoload "Game": โหมดของเกม — เมนูเรียก start_mode(), รันเทสผ่าน cmd ได้ด้วย
##   Godot.exe --path . res://scenes/arena.tscn -- training|easy|normal|hard

var mode := "local"   # local / easy / normal / hard / training / online / online_host
var ai_level := 0     # 0 = คนเล่นจริง, 1..3 = AI (ง่าย → ยาก)

const VALID_MODES := ["local", "easy", "normal", "hard", "training"]

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0 and VALID_MODES.has(args[0]):
		mode = args[0]
	_set_ai_level()

func start_mode(m: String) -> void:
	mode = m
	_set_ai_level()
	get_tree().change_scene_to_file("res://scenes/arena.tscn")

func _set_ai_level() -> void:
	ai_level = {"easy": 1, "normal": 2, "hard": 3, "training": 0}.get(mode, 0)

func difficulty_name() -> String:
	match mode:
		"easy": return "EASY"
		"normal": return "NORMAL"
		"hard": return "HARD"
	return ""
