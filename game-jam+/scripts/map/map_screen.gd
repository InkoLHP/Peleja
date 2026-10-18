extends Control
## Route map: builds nodes/paths from a MapLayout, moves the marker and triggers node events.

signal node_reached(node_id: int)
signal node_event_finished(node_id: int)

const TYPE_NAMES := {
	"start": "Início", "combat": "Combate", "event": "Evento", "rest": "Fogueira", "boss": "Chefe",
}
const PATH_COLOR := Color(0.05, 0.04, 0.03, 1)
const PATH_WIDTH := 6.0
const DASH_LENGTH := 12.0
const GAP_LENGTH := 9.0
const WALK_TIME := 0.6
const REST_HEAL_RATIO := 0.3
const DECOR_AREA := Rect2(30, 70, 1220, 620)
## A click or hover counts as hitting a node when it lands this close to its center.
const MAX_NODE_CLICK_DISTANCE := 32.0
## Enemy fought by the current combat/boss node (data-driven, loaded from disk).
const COMBAT_ENEMY_PATH := "res://data/enemies/corpo_seco.tres"
## Design space the map is authored in; the layer is scaled to fit and kept centered.
const DESIGN_SIZE := Vector2(1280, 720)

## Fixed handcrafted map. A procedural generator only needs to return a MapLayout (see _get_layout).
@export var layout: MapLayout

@onready var decoration: Node2D = $MapLayer/Decoration
@onready var paths: Node2D = $MapLayer/Paths
@onready var nodes_root: Node2D = $MapLayer/Nodes
@onready var marker: Node2D = $MapLayer/Marker
@onready var hp_label: Label = $TopBar/HBox/HpLabel
@onready var ammo_label: Label = $TopBar/HBox/AmmoLabel
@onready var event_popup: Control = $EventPopup
@onready var event_title: Label = $EventPopup/Center/Panel/VBox/Title
@onready var event_body: Label = $EventPopup/Center/Panel/VBox/Body
@onready var event_button: Button = $EventPopup/Center/Panel/VBox/ContinueButton
@onready var pause_menu: Control = $PauseMenu

var _views: Dictionary = {}  # node_id -> MapNodeView
var _targets: Array[int] = []
var _selected_index := 0
var _busy := false
var _pending_combat := false
var _cursor_shape := Input.CURSOR_ARROW


func _ready() -> void:
	MainSoundtrack.play_menu()
	get_tree().paused = false
	# Opened without going through the menu: start a default run so the map begins at the start.
	GameState.ensure_run()
	layout = _get_layout()
	event_popup.hide()
	event_button.pressed.connect(_on_event_continue_pressed)
	GameState.hp_changed.connect(_on_hp_changed)
	GameState.ammo_changed.connect(_on_ammo_changed)
	_on_hp_changed(GameState.hp, GameState.max_hp)
	_on_ammo_changed(GameState.ammo, GameState.max_ammo)

	_build_map()
	_fit_layer_to_viewport()
	get_viewport().size_changed.connect(_fit_layer_to_viewport)
	_place_marker()
	_refresh_states()


## The saved position is only trusted while a run is in progress and the node id exists in
## this layout. Otherwise (new run, map opened from the editor, stale id) the marker starts
## on the "Início" node, which counts as already completed.
func _place_marker() -> void:
	var saved := GameState.current_map_node
	var valid := GameState.run_active and saved != -1 and layout.get_node_data(saved) != null
	if not valid:
		var start := layout.get_start_node()
		GameState.enter_map_node(start.id)
		GameState.complete_map_node(start.id)
	marker.position = _views[GameState.current_map_node].position


## Swap this for a procedural generator later; everything else reads only the MapLayout.
func _get_layout() -> MapLayout:
	return layout


## Keeps the whole map visible and centered whatever the window aspect ratio is.
func _fit_layer_to_viewport() -> void:
	var vp := get_viewport_rect().size
	var s := minf(vp.x / DESIGN_SIZE.x, vp.y / DESIGN_SIZE.y)
	$MapLayer.scale = Vector2(s, s)
	$MapLayer.position = (vp - DESIGN_SIZE * s) * 0.5


func _build_map() -> void:
	var node_points: Array[Vector3] = []
	var segments: Array = []
	for data in layout.nodes:
		var view := MapNodeView.new()
		nodes_root.add_child(view)
		view.setup(data)
		_views[data.id] = view
		node_points.append(Vector3(data.position.x, data.position.y, view.radius))
	for data in layout.nodes:
		for next_id in data.next_ids:
			var to_data := layout.get_node_data(next_id)
			if to_data == null:
				continue
			_add_dashed_path(data.position, to_data.position, _views[data.id].radius, _views[next_id].radius)
			segments.append([data.position, to_data.position])
	decoration.generate(node_points, segments, DECOR_AREA)


func _add_dashed_path(from: Vector2, to: Vector2, from_radius: float, to_radius: float) -> void:
	var dir := (to - from).normalized()
	var start := from + dir * (from_radius + 6.0)
	var end := to - dir * (to_radius + 6.0)
	var length := start.distance_to(end)
	var path := Node2D.new()
	var t := 0.0
	while t < length:
		var dash := Line2D.new()
		dash.width = PATH_WIDTH
		dash.default_color = PATH_COLOR
		dash.points = PackedVector2Array([start + dir * t, start + dir * minf(t + DASH_LENGTH, length)])
		path.add_child(dash)
		t += DASH_LENGTH + GAP_LENGTH
	paths.add_child(path)


func _refresh_states() -> void:
	var current := GameState.current_map_node
	var current_done := GameState.is_map_node_completed(current)
	_targets.clear()
	if current_done:
		_targets.assign(layout.get_node_data(current).next_ids)
	else:
		# Encounter not finished (e.g. fled from combat): only the current node can be retried.
		_targets.append(current)
	_targets.sort_custom(func(a: int, b: int) -> bool: return _views[a].position.x < _views[b].position.x)

	for id in _views:
		var view: MapNodeView = _views[id]
		if _targets.has(id):
			view.set_state(MapNodeView.State.AVAILABLE)
		elif id == current:
			view.set_state(MapNodeView.State.CURRENT)
		elif GameState.visited_nodes.has(id):
			view.set_state(MapNodeView.State.VISITED)
		else:
			view.set_state(MapNodeView.State.DIMMED)
	_selected_index = 0
	_update_selection()
	_update_hover(nodes_root.get_local_mouse_position())


func _update_selection() -> void:
	for id in _views:
		_views[id].set_selected(not _busy and not _targets.is_empty() and id == _targets[_selected_index])


func _unhandled_input(event: InputEvent) -> void:
	# The marker is walking, or an event panel / the pause menu is up: ignore everything.
	if _busy or event_popup.visible or pause_menu.visible:
		return
	if event is InputEventMouseMotion:
		_update_hover(_to_map_space(event.position))
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			# The map layer is scaled and centered, so the click has to be converted
			# into the node container's own space before hit testing.
			var clicked := _target_at(_to_map_space(event.position))
			if clicked != -1:
				_selected_index = clicked
				_update_selection()
				_confirm_selection()
		get_viewport().set_input_as_handled()
		return
	if _targets.is_empty():
		return
	if event.is_action_pressed("ui_left") or event.is_action_pressed("nav_left"):
		_selected_index = wrapi(_selected_index - 1, 0, _targets.size())
		_update_selection()
	elif event.is_action_pressed("ui_right") or event.is_action_pressed("nav_right"):
		_selected_index = wrapi(_selected_index + 1, 0, _targets.size())
		_update_selection()
	elif event.is_action_pressed("ui_accept"):
		_confirm_selection()
	else:
		return
	get_viewport().set_input_as_handled()


## Mouse hover drives the very same selection the keyboard uses, plus the hand cursor.
func _update_hover(local_point: Vector2) -> void:
	var hovered := _target_at(local_point)
	_set_cursor(hovered != -1)
	if hovered != -1 and hovered != _selected_index:
		_selected_index = hovered
		_update_selection()


func _set_cursor(pointing: bool) -> void:
	var shape := Input.CURSOR_POINTING_HAND if pointing else Input.CURSOR_ARROW
	if _cursor_shape == shape:
		return
	_cursor_shape = shape
	Input.set_default_cursor_shape(shape)


func _exit_tree() -> void:
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)


## Converts a viewport point (the raw input position) into the node container's space.
func _to_map_space(viewport_point: Vector2) -> Vector2:
	return nodes_root.get_global_transform().affine_inverse() * viewport_point


## The closest AVAILABLE node within MAX_NODE_CLICK_DISTANCE of the point, or -1.
## Dimmed, visited and the current node are never hit-testable.
func _target_at(local_point: Vector2) -> int:
	var best := -1
	var best_distance := MAX_NODE_CLICK_DISTANCE
	for i in _targets.size():
		var view: MapNodeView = _views[_targets[i]]
		if not view.is_available():
			continue
		var distance := local_point.distance_to(view.position)
		if distance <= best_distance:
			best_distance = distance
			best = i
	return best


func _confirm_selection() -> void:
	var target := _targets[_selected_index]
	if target == GameState.current_map_node:
		_trigger_node(target)
	else:
		_walk_to(target)


func _walk_to(target: int) -> void:
	_busy = true
	_set_cursor(false)
	_update_selection()
	var tween := create_tween()
	tween.tween_property(marker, "position", _views[target].position, WALK_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	GameState.enter_map_node(target)
	_busy = false
	_refresh_states()
	node_reached.emit(target)
	_trigger_node(target)


func _trigger_node(node_id: int) -> void:
	var data := layout.get_node_data(node_id)
	_pending_combat = false
	var body := ""
	match data.type:
		"combat":
			body = "Uma criatura corrompida pela Hecatombe bloqueia o caminho."
			_pending_combat = true
		"boss":
			body = "O Encourado aguarda no fim do caminho."
			_pending_combat = true
		"event":
			body = "Um evento acontece aqui..."
			GameState.complete_map_node(node_id)
		"rest":
			var amount := ceili(GameState.max_hp * REST_HEAL_RATIO)
			GameState.heal(amount)
			GameState.complete_map_node(node_id)
			body = "Fogueira do Bando: +%d vida" % amount
		_:
			return
	_show_popup(TYPE_NAMES.get(data.type, data.type), body)


func _show_popup(title: String, body: String) -> void:
	_set_cursor(false)
	event_title.text = title
	event_body.text = body
	event_popup.show()
	event_button.grab_focus()


func _on_event_continue_pressed() -> void:
	event_popup.hide()
	var node_id := GameState.current_map_node
	node_event_finished.emit(node_id)
	if _pending_combat:
		# The map decides who is fought; combat only reads GameState.current_enemy.
		GameState.current_enemy = load(COMBAT_ENEMY_PATH)
		GameState.final_battle = layout.get_node_data(node_id).type == "boss"
		SceneRouter.go_to_combat()
	else:
		_refresh_states()


func _on_hp_changed(current: int, maximum: int) -> void:
	hp_label.text = "Vida: %d/%d" % [current, maximum]


func _on_ammo_changed(current: int, maximum: int) -> void:
	ammo_label.text = "Munição: %d/%d" % [current, maximum]
