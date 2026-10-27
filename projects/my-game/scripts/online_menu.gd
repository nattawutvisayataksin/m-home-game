extends Control
## Online 1v1: Host = เปิดเกมฝั่งเรารอเพื่อน (ws://IP:8910), Join = ใส่ IP ของเพื่อน
## (ถ้า browser เล่นผ่าน http://... จะต่อ ws ได้ตรง ๆ; https ต้อง wss — ตั้ง Host ทีหลัง)

const PORT := 8910

func _ready() -> void:
	$Menu/BtnHost.pressed.connect(_on_host)
	$Menu/BtnJoin.pressed.connect(_on_join)
	$BtnBack.pressed.connect(_on_back)
	$Menu/IpEdit.text = "ws://localhost:%d" % PORT
	$Menu/BtnHost.grab_focus()

func _status(text: String) -> void:
	$Status.text = text

func _on_host() -> void:
	var peer := WebSocketMultiplayerPeer.new()
	var err := peer.create_server(PORT)
	if err != OK:
		_status("เปิด Host ไม่ได้ (port %d)" % PORT)
		return
	multiplayer.multiplayer_peer = peer
	Game.mode = "online_host"
	_status("Host แล้ว — กำลังเริ่มสนาม รอเพื่อนเข้ามา...")
	get_tree().change_scene_to_file("res://scenes/arena.tscn")

func _on_join() -> void:
	var url := $Menu/IpEdit.text.strip_edges()
	var peer := WebSocketMultiplayerPeer.new()
	var err := peer.create_client(url)
	if err != OK:
		_status("โครง IP ไม่ถูกต้อง")
		return
	multiplayer.multiplayer_peer = peer
	Game.mode = "online"
	_status("กำลังเชื่อมต่อ %s ..." % url)
	# รอ connected_to_server แล้วเข้าสนาม
	await multiplayer.connected_to_server
	_status("เชื่อมต่อแล้ว! เข้าสนาม...")
	get_tree().change_scene_to_file("res://scenes/arena.tscn")

func _on_back() -> void:
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
