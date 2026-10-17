class_name MapNodeView
extends Node2D
## Visual for one map node: black circle with a parchment symbol built from Polygon2D/Label.

enum State { DIMMED, AVAILABLE, VISITED, CURRENT }

const CIRCLE_COLOR := Color(0.05, 0.04, 0.03, 1)
const SYMBOL_COLOR := Color(0.784, 0.627, 0.416, 1)
const SELECT_COLOR := Color(1, 0.86, 0.35, 1)
const RING_COLOR := Color(0.54, 0.4, 0.2, 1)
const CROSS_COLOR := Color(0.6, 0.08, 0.06, 1)
## Minimum click/hover radius, so every node answers the mouse over at least 56x56 px.
const MIN_HIT_RADIUS := 28.0

var node_id: int = -1
var node_type: String = ""
var radius: float = 22.0

var _state: int = State.DIMMED
var _selected := false
var _pulse: Tween
var _select_tween: Tween
var _cross: Node2D
var _visual: Node2D


func setup(data: MapNodeData) -> void:
	node_id = data.id
	node_type = data.type
	position = data.position
	radius = 30.0 if node_type == "boss" else 22.0
	# Art sits on a child so the availability pulse and the selection scale never fight.
	_visual = Node2D.new()
	add_child(_visual)
	_build_symbol()
	_build_cross()
	queue_redraw()


func set_state(new_state: int) -> void:
	_state = new_state
	if _pulse:
		_pulse.kill()
		_pulse = null
	scale = Vector2.ONE
	_visual.scale = Vector2.ONE
	_cross.visible = new_state == State.VISITED
	match new_state:
		State.DIMMED:
			modulate = Color(1, 1, 1, 0.4)
		State.VISITED:
			modulate = Color(0.8, 0.75, 0.7, 0.9)
		State.CURRENT:
			modulate = Color.WHITE
		State.AVAILABLE:
			modulate = Color.WHITE
			_pulse = create_tween().set_loops()
			_pulse.tween_property(_visual, "scale", Vector2.ONE * 1.12, 0.45).set_trans(Tween.TRANS_SINE)
			_pulse.tween_property(_visual, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_SINE)


## The same highlight is used by keyboard selection and by mouse hover.
func set_selected(value: bool) -> void:
	_selected = value
	if _select_tween:
		_select_tween.kill()
	_select_tween = create_tween()
	_select_tween.tween_property(self, "scale", Vector2.ONE * (1.08 if value else 1.0), 0.12) \
		.set_trans(Tween.TRANS_SINE)
	queue_redraw()


func is_available() -> bool:
	return _state == State.AVAILABLE


func contains_point(local_point: Vector2) -> bool:
	return local_point.distance_to(position) <= maxf(radius + 6.0, MIN_HIT_RADIUS)


func _draw() -> void:
	if _selected:
		draw_arc(Vector2.ZERO, radius + 8.0, 0.0, TAU, 40, SELECT_COLOR, 4.0, true)
	draw_circle(Vector2.ZERO, radius + 3.0, RING_COLOR)
	draw_circle(Vector2.ZERO, radius, CIRCLE_COLOR)


const ICONS := {
	"combat": preload("res://art/icon_combat.png"),
	"boss": preload("res://art/icon_boss.png"),
	"event": preload("res://art/icon_event.png"),
	"rest": preload("res://art/icon_rest.png"),
	"start": preload("res://art/icon_start.png"),
}


## Pixel-art symbol (16x16) centred on the node disc; the boss gets a bigger one.
func _build_symbol() -> void:
	if not ICONS.has(node_type):
		return
	var icon := Sprite2D.new()
	icon.texture = ICONS[node_type]
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.scale = Vector2.ONE * (3.0 if node_type == "boss" else 2.0)
	_visual.add_child(icon)


func _build_cross() -> void:
	_cross = Node2D.new()
	_cross.visible = false
	var d := radius * 0.75
	for points in [[Vector2(-d, -d), Vector2(d, d)], [Vector2(d, -d), Vector2(-d, d)]]:
		var line := Line2D.new()
		line.points = PackedVector2Array(points)
		line.width = 5.0
		line.default_color = CROSS_COLOR
		line.begin_cap_mode = Line2D.LINE_CAP_ROUND
		line.end_cap_mode = Line2D.LINE_CAP_ROUND
		_cross.add_child(line)
	_visual.add_child(_cross)
