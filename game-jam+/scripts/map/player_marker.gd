extends Node2D
## Pixel-art hat pin that marks the Cangaceiro on the map. It floats just above the node.

const TEXTURE := preload("res://art/marker.png")
const PIXEL_SCALE := 3.0
const HOVER_HEIGHT := 28.0

var _sprite: Sprite2D


func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.texture = TEXTURE
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.scale = Vector2.ONE * PIXEL_SCALE
	# Bottom tip of the pin points at the node centre.
	_sprite.position = Vector2(0.0, -HOVER_HEIGHT - TEXTURE.get_height() * PIXEL_SCALE * 0.5)
	add_child(_sprite)
	var bob := create_tween().set_loops()
	bob.tween_property(_sprite, "position:y", _sprite.position.y - 5.0, 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	bob.tween_property(_sprite, "position:y", _sprite.position.y, 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
