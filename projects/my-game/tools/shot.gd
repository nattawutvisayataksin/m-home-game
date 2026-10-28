extends Node
## เครื่องมือ dev: แคปหน้าจอเกมจริง 3 จังหวะไว้ทำหน้า itch.io
## รัน: godot --path . res://tools/shot.tscn -- normal
## เซฟที่ OUT_DIR (นอกโปรเจกต์) — ไม่แตะ assets

const OUT_DIR := "C:/Users/Administrator/Desktop/opencode/m-home-game/assets-library/marketing"

func _ready() -> void:
	var arena: Node = load("res://scenes/arena.tscn").instantiate()
	add_child(arena)
	var times := [3.0, 6.5, 10.0]
	for i in times.size():
		await get_tree().create_timer(times[i]).timeout
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.save_png("%s/shot_%d.png" % [OUT_DIR, i + 1])
		print("[SHOT] saved ", i + 1, " (", img.get_width(), "x", img.get_height(), ")")
	get_tree().quit()
