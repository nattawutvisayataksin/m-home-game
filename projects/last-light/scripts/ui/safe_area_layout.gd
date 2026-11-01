extends RefCounted
class_name SafeAreaLayout


static func apply(container: MarginContainer, minimum_margin: int = 12) -> void:
	var left: int = minimum_margin
	var top: int = minimum_margin
	var right: int = minimum_margin
	var bottom: int = minimum_margin
	var window_size: Vector2i = DisplayServer.window_get_size()
	if window_size.x > 0 and window_size.y > 0:
		var window_position: Vector2i = DisplayServer.window_get_position()
		var window_rect := Rect2i(window_position, window_size)
		var safe_rect: Rect2i = DisplayServer.get_display_safe_area()
		var usable_rect: Rect2i = safe_rect.intersection(window_rect)
		if usable_rect.size.x > 0 and usable_rect.size.y > 0:
			var scale: Vector2 = container.get_viewport_rect().size / Vector2(window_size)
			left += int(float(usable_rect.position.x - window_position.x) * scale.x)
			top += int(float(usable_rect.position.y - window_position.y) * scale.y)
			right += int(float(window_rect.end.x - usable_rect.end.x) * scale.x)
			bottom += int(float(window_rect.end.y - usable_rect.end.y) * scale.y)
	container.add_theme_constant_override("margin_left", left)
	container.add_theme_constant_override("margin_top", top)
	container.add_theme_constant_override("margin_right", right)
	container.add_theme_constant_override("margin_bottom", bottom)
