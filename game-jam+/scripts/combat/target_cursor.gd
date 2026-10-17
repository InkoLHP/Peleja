class_name TargetCursor
extends Control
## Corner-bracket frame plus a pointing hand, drawn over the enemy while the
## player is picking a target for an offensive action.

const BRACKET_COLOR := Color(1, 0.86, 0.35, 1)
const BRACKET_LENGTH := 26.0
const BRACKET_WIDTH := 5.0
const HAND_TEXT := "\u261e"

var target_rect := Rect2()
var _active := false
var _hand: Label
var _time := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hand = Label.new()
	_hand.text = HAND_TEXT
	_hand.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hand.add_theme_font_size_override("font_size", 44)
	_hand.add_theme_color_override("font_color", BRACKET_COLOR)
	_hand.add_theme_color_override("font_outline_color", Color(0.06, 0.04, 0.03, 0.9))
	_hand.add_theme_constant_override("outline_size", 6)
	_hand.size = Vector2(60, 60)
	add_child(_hand)
	hide()


## Starts showing the frame around a rect in this control's local space.
func show_target(rect: Rect2) -> void:
	target_rect = rect
	_active = true
	show()
	queue_redraw()


func hide_target() -> void:
	_active = false
	hide()


func _process(delta: float) -> void:
	if not _active:
		return
	_time += delta
	# The hand bobs gently so the target reads as "alive".
	_hand.position = Vector2(target_rect.position.x - 54.0, target_rect.position.y + 24.0 + sin(_time * 5.0) * 5.0)


func _draw() -> void:
	if not _active:
		return
	var r := target_rect.grow(12.0)
	var corners := [
		[Vector2(r.position.x, r.position.y), Vector2(1, 0), Vector2(0, 1)],
		[Vector2(r.end.x, r.position.y), Vector2(-1, 0), Vector2(0, 1)],
		[Vector2(r.position.x, r.end.y), Vector2(1, 0), Vector2(0, -1)],
		[Vector2(r.end.x, r.end.y), Vector2(-1, 0), Vector2(0, -1)],
	]
	for corner in corners:
		var origin: Vector2 = corner[0]
		var horizontal: Vector2 = corner[1]
		var vertical: Vector2 = corner[2]
		draw_line(origin, origin + horizontal * BRACKET_LENGTH, BRACKET_COLOR, BRACKET_WIDTH, true)
		draw_line(origin, origin + vertical * BRACKET_LENGTH, BRACKET_COLOR, BRACKET_WIDTH, true)
