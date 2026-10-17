extends Control
## Main menu: intro animation, background pines, keyboard/gamepad/mouse navigation.

const TREE_COUNT := 0  # the pixel-art background already has scenery
const TREE_COLOR := Color(0.15, 0.29, 0.14, 1)
const TREE_SEED := 1738
# Areas (base 1280x720) where trees must not be placed: title + buttons, footer.
const EXCLUDE_RECTS: Array[Rect2] = [
	Rect2(340, 60, 600, 560),
	Rect2(1060, 650, 220, 70),
]
const PLAY_AREA := Rect2(40, 60, 1200, 630)

@onready var trees: Node2D = $Trees
@onready var header: Control = $Header
@onready var new_game_button: Button = $Buttons/NewGameButton
@onready var continue_button: Button = $Buttons/ContinueButton
@onready var quit_button: Button = $Buttons/QuitButton

var _buttons: Array[Button] = []


func _ready() -> void:
	_buttons = [new_game_button, continue_button, quit_button]
	_spawn_trees()

	# "Continuar" is only available when a save exists.
	continue_button.disabled = not GameState.has_save()
	continue_button.focus_mode = Control.FOCUS_NONE if continue_button.disabled else Control.FOCUS_ALL

	new_game_button.pressed.connect(_on_new_game_pressed)
	continue_button.pressed.connect(_on_continue_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	for button in _buttons:
		button.mouse_entered.connect(_on_button_mouse_entered.bind(button))
		button.focus_entered.connect(_on_button_focus_changed.bind(button, true))
		button.focus_exited.connect(_on_button_focus_changed.bind(button, false))

	_play_intro()


func _unhandled_input(event: InputEvent) -> void:
	# W/S as extra navigation keys (arrows and gamepad use built-in ui_up/ui_down).
	if event.is_action_pressed("nav_up"):
		_move_focus(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("nav_down"):
		_move_focus(1)
		get_viewport().set_input_as_handled()


func _move_focus(direction: int) -> void:
	var enabled: Array[Button] = _buttons.filter(func(b: Button) -> bool: return not b.disabled)
	if enabled.is_empty():
		return
	var current := get_viewport().gui_get_focus_owner()
	var index := enabled.find(current)
	if index == -1:
		enabled[0].grab_focus()
		return
	enabled[wrapi(index + direction, 0, enabled.size())].grab_focus()


func _spawn_trees() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = TREE_SEED
	var placed: Array[Vector2] = []
	var attempts := 0
	while placed.size() < TREE_COUNT and attempts < 2000:
		attempts += 1
		var height := rng.randf_range(22.0, 42.0)
		var width := height * 0.6
		var base := Vector2(
			rng.randf_range(PLAY_AREA.position.x, PLAY_AREA.end.x),
			rng.randf_range(PLAY_AREA.position.y + height, PLAY_AREA.end.y))
		var bounds := Rect2(base.x - width * 0.5, base.y - height, width, height)
		if EXCLUDE_RECTS.any(func(r: Rect2) -> bool: return r.intersects(bounds)):
			continue
		if placed.any(func(p: Vector2) -> bool: return p.distance_to(base) < 45.0):
			continue
		placed.append(base)
		var tree := Polygon2D.new()
		tree.name = "Pine%d" % placed.size()
		tree.color = TREE_COLOR
		tree.polygon = PackedVector2Array([
			Vector2(0, -height), Vector2(width * 0.5, 0), Vector2(-width * 0.5, 0)])
		tree.position = base
		trees.add_child(tree)


func _play_intro() -> void:
	header.modulate.a = 0.0
	for button in _buttons:
		button.modulate.a = 0.0
	# Wait one frame so anchors/containers have their final layout.
	await get_tree().process_frame

	var final_y := header.position.y
	header.position.y = final_y - 120.0
	var tween := create_tween()
	tween.tween_property(header, "position:y", final_y, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(header, "modulate:a", 1.0, 0.4)
	for button in _buttons:
		tween.tween_property(button, "modulate:a", 1.0, 0.25)
	new_game_button.grab_focus()


func _on_button_mouse_entered(button: Button) -> void:
	# Mouse hover moves focus so hover and keyboard share the same highlight.
	if not button.disabled:
		button.grab_focus()


func _on_button_focus_changed(button: Button, focused: bool) -> void:
	button.pivot_offset = button.size * 0.5
	var tween := button.create_tween()
	tween.tween_property(button, "scale", Vector2.ONE * (1.06 if focused else 1.0), 0.1)


func _on_new_game_pressed() -> void:
	GameState.reset_run()
	SceneRouter.go_to_map()


func _on_continue_pressed() -> void:
	SceneRouter.go_to_map()


func _on_quit_pressed() -> void:
	get_tree().quit()
