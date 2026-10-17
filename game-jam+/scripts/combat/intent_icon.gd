class_name IntentIcon
extends Control
## Placeholder icon for the enemy's next action: a fist for attacks, a shield for defending.

enum Kind { ATTACK, DEFEND }

const ICON_COLOR := Color(0.95, 0.9, 0.78, 1)
const OUTLINE_COLOR := Color(0.08, 0.06, 0.05, 1)

var kind: int = Kind.ATTACK


func set_kind(new_kind: int) -> void:
	kind = new_kind
	queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	if kind == Kind.ATTACK:
		_draw_fist(center)
	else:
		_draw_shield(center)


func _draw_fist(center: Vector2) -> void:
	draw_rect(Rect2(center + Vector2(-16, -2), Vector2(32, 20)), ICON_COLOR, true)
	for i in 4:
		draw_circle(center + Vector2(-12 + i * 8, -6), 5.5, ICON_COLOR)
	draw_rect(Rect2(center + Vector2(-21, 2), Vector2(9, 13)), ICON_COLOR, true)
	draw_arc(center, 25.0, 0.0, TAU, 32, OUTLINE_COLOR, 2.0, true)


func _draw_shield(center: Vector2) -> void:
	var points := PackedVector2Array([
		center + Vector2(0, -22),
		center + Vector2(16, -12),
		center + Vector2(16, 8),
		center + Vector2(0, 22),
		center + Vector2(-16, 8),
		center + Vector2(-16, -12),
	])
	draw_colored_polygon(points, ICON_COLOR)
	var closed := points.duplicate()
	closed.append(points[0])
	draw_polyline(closed, OUTLINE_COLOR, 2.0, true)
