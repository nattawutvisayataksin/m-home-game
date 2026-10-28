extends Area2D
class_name FieldItem
## ไอเทมลอยกลางสนาม — ใครเดินชนก่อนได้ก่อน (DESIGN.md §ระบบพิเศษ)
## arena เป็นคนปล่อยตามเวลา / อยู่บนพื้นได้ LIFETIME วินาที แล้วหายเอง
## เก็บแล้วไปอยู่ใน hero.held_item — กด X (P1) / J (P2) เพื่อใช้

signal picked(hero: Hero, kind: StringName)

const LIFETIME := 12.0   # วินาทีที่ลอยอยู่ก่อนหายไป

var kind := &"speed"
var _t := 0.0
var _base_y := 0.0

func setup(k: StringName, tex: Texture2D, pos: Vector2) -> void:
	kind = k
	position = pos
	_base_y = pos.y
	$Icon.texture = tex

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	_t += delta
	position.y = _base_y + sin(_t * 3.0) * 3.0   # ลอยขึ้นลงเบา ๆ ให้เห็นว่าหยิบได้
	if _t >= LIFETIME:
		if DisplayServer.get_name() == "headless":
			print("[ITEM] expire — %s (ไม่มีใครเก็บ)" % kind)
		queue_free()

func _on_body_entered(body: Node2D) -> void:
	var h := body as Hero
	if h == null:
		return
	if h.held_item != &"":
		return   # ถือของอยู่ — เก็บไม่ได้
	h.receive_item(kind)
	picked.emit(h, kind)
	queue_free()
