extends CanvasLayer
## Switches between game scenes with a short black fade (autoload: SceneRouter).

signal transition_started(target_path: String)
signal transition_finished(target_path: String)

const MENU_SCENE := "res://scenes/main_menu.tscn"
const MAP_SCENE := "res://scenes/map.tscn"
const COMBAT_SCENE := "res://scenes/combat.tscn"
const ENDING_SCENE := "res://scenes/ending.tscn"
const FADE_TIME := 0.3

var _fade_rect: ColorRect
var _is_transitioning := false


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_fade_rect = ColorRect.new()
	_fade_rect.color = Color.BLACK
	_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade_rect.modulate.a = 0.0
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade_rect)


func is_transitioning() -> bool:
	return _is_transitioning


func go_to_menu() -> void:
	change_scene(MENU_SCENE)


func go_to_map() -> void:
	change_scene(MAP_SCENE)


func go_to_ending() -> void:
	change_scene(ENDING_SCENE)


func go_to_combat() -> void:
	change_scene(COMBAT_SCENE)


## Fades to black, swaps the scene, then fades back in.
func change_scene(path: String) -> void:
	if _is_transitioning:
		return
	if not ResourceLoader.exists(path):
		push_error("SceneRouter: scene not found: %s" % path)
		return
	_is_transitioning = true
	transition_started.emit(path)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP

	var fade_out := create_tween()
	fade_out.tween_property(_fade_rect, "modulate:a", 1.0, FADE_TIME)
	await fade_out.finished

	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	await get_tree().process_frame

	var fade_in := create_tween()
	fade_in.tween_property(_fade_rect, "modulate:a", 0.0, FADE_TIME)
	await fade_in.finished

	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_is_transitioning = false
	transition_finished.emit(path)
