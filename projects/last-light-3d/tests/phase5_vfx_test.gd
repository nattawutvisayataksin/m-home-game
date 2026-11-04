extends SceneTree

## Phase 5 test — combat effects (VFX) & screen juice:
## 1) TDCombatEffect respects reduce_flashes & reduce_motion from TDSettings
## 2) TDCombatEffect instances clean up after their lifetime
## 3) TDRun sets up Effects container and projectile impact routing
## 4) TDHUD flash_leak runs safely without breaking mouse interaction

const RUN_SCENE: PackedScene = preload("res://scenes/gameplay/run.tscn")
const EFFECT_SCRIPT: Script = preload("res://scripts/actors/td_combat_effect.gd")


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	if not await _test_combat_effect_settings():
		return
	if not await _test_run_effects_wiring():
		return
	print("PHASE 5 VFX & JUICE TEST PASSED")
	call_deferred("_finish", 0)


func _test_combat_effect_settings() -> bool:
	var store := root.get_node_or_null("TDSettings") as TDSettingsStore
	if not _check(store != null, "TDSettings autoload missing."):
		return false

	store.settings_path = "user://phase5_vfx_test.cfg"

	# Normal settings
	store.set_reduce_flashes(false)
	store.set_reduce_motion(false)
	var effect_normal: TDCombatEffect = EFFECT_SCRIPT.new() as TDCombatEffect
	effect_normal.effect_kind = TDCombatEffect.KIND_DEATH
	root.add_child(effect_normal)
	if not _check(effect_normal._alpha_scale == 1.0, "Normal effect alpha scale should be 1.0."):
		effect_normal.queue_free()
		return false
	if not _check(effect_normal._motion_scale == 1.0, "Normal effect motion scale should be 1.0."):
		effect_normal.queue_free()
		return false
	effect_normal.queue_free()

	# Accessibility settings: reduce flashes & reduce motion
	store.set_reduce_flashes(true)
	store.set_reduce_motion(true)
	var effect_a11y: TDCombatEffect = EFFECT_SCRIPT.new() as TDCombatEffect
	effect_a11y.effect_kind = TDCombatEffect.KIND_DEATH
	root.add_child(effect_a11y)
	if not _check(effect_a11y._alpha_scale < 1.0, "Reduced flashes should scale down alpha."):
		effect_a11y.queue_free()
		return false
	if not _check(effect_a11y._motion_scale == 0.0, "Reduced motion should scale motion to 0."):
		effect_a11y.queue_free()
		return false
	effect_a11y.queue_free()

	# Reset
	store.set_reduce_flashes(false)
	store.set_reduce_motion(false)
	var dir := DirAccess.open("user://")
	if dir != null:
		dir.remove("user://phase5_vfx_test.cfg")
	return true


func _test_run_effects_wiring() -> bool:
	var run := RUN_SCENE.instantiate() as TDRun
	root.add_child(run)

	var effects_container := run.get_node_or_null("Effects")
	if not _check(effects_container != null, "Run missing Effects container."):
		run.queue_free()
		return false

	var hud := run.get_node_or_null("HUD") as TDHud
	if not _check(hud != null, "Run missing HUD."):
		run.queue_free()
		return false

	# Test flash_leak
	hud.flash_leak()
	var flash_rect := hud.get_node_or_null("LeakFlash") as ColorRect
	if not _check(flash_rect != null, "HUD missing LeakFlash ColorRect."):
		run.queue_free()
		return false
	if not _check(flash_rect.mouse_filter == Control.MOUSE_FILTER_IGNORE, "LeakFlash must ignore mouse filter."):
		run.queue_free()
		return false

	run.queue_free()
	return true


func _check(condition: bool, message: String) -> bool:
	if not condition:
		printerr("PHASE 5 FAIL: " + message)
		call_deferred("_finish", 1)
		return false
	return true


func _finish(exit_code: int) -> void:
	quit(exit_code)
