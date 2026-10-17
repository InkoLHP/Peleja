class_name PlaceholderCharacter
extends Node2D
## Animates a placeholder character built from shapes.
## Everything animates the "Body" child, so the scene root's position stays free
## for the combat layout and the shadow never moves.

## Vertical breathing amplitude in pixels.
@export var idle_bob := 4.0
## Seconds for one half of the breathing cycle.
@export var idle_period := 0.9
## Sideways sway in radians (0 = no sway, just the bob).
@export var idle_sway := 0.0
## +1 when the character faces right, -1 when it faces left.
@export var forward_sign := 1.0
## How far it steps forward when acting.
@export var step_distance := 46.0

@onready var body: Node2D = $Body

var _idle_tween: Tween
var _motion_tween: Tween


func _ready() -> void:
	body.position = Vector2.ZERO
	body.rotation = 0.0
	_start_idle()


## Looping breathing/bobbing so the character never looks frozen.
func _start_idle() -> void:
	if _idle_tween:
		_idle_tween.kill()
	_idle_tween = create_tween().set_loops()
	_idle_tween.tween_property(body, "position:y", -idle_bob, idle_period) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if not is_zero_approx(idle_sway):
		_idle_tween.parallel().tween_property(body, "rotation", idle_sway, idle_period) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_idle_tween.tween_property(body, "position:y", 0.0, idle_period) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if not is_zero_approx(idle_sway):
		_idle_tween.parallel().tween_property(body, "rotation", -idle_sway, idle_period) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## Steps toward the opponent and back. Await it to time the action with the hit.
func step_forward() -> void:
	_kill_motion()
	_motion_tween = create_tween()
	_motion_tween.tween_property(body, "position:x", forward_sign * step_distance, 0.14) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_motion_tween.tween_property(body, "position:x", 0.0, 0.2) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await _motion_tween.finished


## White flash plus a short shake: the character was hit.
func react_to_hit() -> void:
	_flash()
	_kill_motion()
	_motion_tween = create_tween()
	for i in 4:
		var offset := 9.0 if i % 2 == 0 else -9.0
		_motion_tween.tween_property(body, "position:x", offset, 0.05)
	_motion_tween.tween_property(body, "position:x", 0.0, 0.07)
	await _motion_tween.finished


## Sways in place: the character is acting without moving forward.
func sway_act() -> void:
	_kill_motion()
	_motion_tween = create_tween()
	_motion_tween.tween_property(body, "rotation", forward_sign * 0.14, 0.16) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_motion_tween.tween_property(body, "rotation", 0.0, 0.24) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await _motion_tween.finished


func _flash() -> void:
	var tween := create_tween()
	tween.tween_property(body, "modulate", Color(2.4, 2.4, 2.4, 1), 0.06)
	tween.tween_property(body, "modulate", Color.WHITE, 0.14)


func _kill_motion() -> void:
	if _motion_tween:
		_motion_tween.kill()
		_motion_tween = null
