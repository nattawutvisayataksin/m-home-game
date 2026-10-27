extends Control
## เมนูหลัก: เลือกโหมด — คุมด้วยลูกศร/เกมแพด + Enter

func _ready() -> void:
	var actions := {
		"BtnLocal": func() -> void: Game.start_mode("local"),
		"BtnEasy": func() -> void: Game.start_mode("easy"),
		"BtnNormal": func() -> void: Game.start_mode("normal"),
		"BtnHard": func() -> void: Game.start_mode("hard"),
		"BtnTraining": func() -> void: Game.start_mode("training"),
		"BtnOnline": func() -> void: get_tree().change_scene_to_file("res://scenes/online_menu.tscn"),
	}
	for btn_name in actions:
		get_node("Menu/" + btn_name).pressed.connect(actions[btn_name])
	$Menu/BtnLocal.grab_focus()
