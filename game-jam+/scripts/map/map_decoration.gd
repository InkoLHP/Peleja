extends Node2D
## Scatters pine trees and mountains on the map, never touching nodes or paths.

const TREE_COUNT := 120
const MOUNTAIN_COUNT := 3
const DECOR_SEED := 4242
const TREE_COLOR := Color(0.14, 0.24, 0.12, 1)
const MOUNTAIN_COLOR := Color(0.27, 0.26, 0.25, 1)
const MOUNTAIN_SHADE := Color(0.2, 0.19, 0.19, 1)
const NODE_CLEARANCE := 22.0
const PATH_CLEARANCE := 16.0


## points: node centers with radius in z of a Vector3(x, y, r); segments: Array of [from, to].
func generate(nodes: Array[Vector3], segments: Array, area: Rect2) -> void:
	for child in get_children():
		child.queue_free()
	var rng := RandomNumberGenerator.new()
	rng.seed = DECOR_SEED
	var occupied: Array[Rect2] = []

	var placed := 0
	var attempts := 0
	while placed < MOUNTAIN_COUNT and attempts < 500:
		attempts += 1
		var w := rng.randf_range(130.0, 180.0)
		var h := rng.randf_range(80.0, 110.0)
		var base := Vector2(rng.randf_range(area.position.x + w * 0.5, area.end.x - w * 0.5),
			rng.randf_range(area.position.y + h, area.end.y))
		var bounds := Rect2(base.x - w * 0.5, base.y - h, w, h)
		if not _is_free(bounds, nodes, segments, occupied):
			continue
		occupied.append(bounds.grow(6.0))
		_add_mountain(base, w, h, rng)
		placed += 1

	placed = 0
	attempts = 0
	while placed < TREE_COUNT and attempts < 6000:
		attempts += 1
		var th := rng.randf_range(12.0, 22.0)
		var tw := th * 0.65
		var tbase := Vector2(rng.randf_range(area.position.x, area.end.x),
			rng.randf_range(area.position.y + th, area.end.y))
		var tbounds := Rect2(tbase.x - tw * 0.5, tbase.y - th, tw, th)
		if not _is_free(tbounds, nodes, segments, occupied):
			continue
		occupied.append(tbounds.grow(2.0))
		var tree := Polygon2D.new()
		tree.color = TREE_COLOR
		tree.polygon = PackedVector2Array([Vector2(0, -th), Vector2(tw * 0.5, 0), Vector2(-tw * 0.5, 0)])
		tree.position = tbase
		add_child(tree)
		placed += 1


func _add_mountain(base: Vector2, w: float, h: float, rng: RandomNumberGenerator) -> void:
	var peak_x := rng.randf_range(-w * 0.15, w * 0.15)
	var body := Polygon2D.new()
	body.color = MOUNTAIN_COLOR
	body.polygon = PackedVector2Array([
		Vector2(-w * 0.5, 0), Vector2(-w * 0.25, -h * 0.55), Vector2(peak_x, -h),
		Vector2(w * 0.2, -h * 0.6), Vector2(w * 0.32, -h * 0.72), Vector2(w * 0.5, 0)])
	body.position = base
	add_child(body)
	var shade := Polygon2D.new()
	shade.color = MOUNTAIN_SHADE
	shade.polygon = PackedVector2Array([Vector2(peak_x, -h), Vector2(w * 0.2, -h * 0.6),
		Vector2(w * 0.32, -h * 0.72), Vector2(w * 0.5, 0), Vector2(peak_x + w * 0.05, 0)])
	shade.position = base
	add_child(shade)


func _is_free(bounds: Rect2, nodes: Array[Vector3], segments: Array, occupied: Array[Rect2]) -> bool:
	for rect in occupied:
		if rect.intersects(bounds):
			return false
	var corners := [bounds.position, Vector2(bounds.end.x, bounds.position.y), bounds.end,
		Vector2(bounds.position.x, bounds.end.y), bounds.get_center()]
	for node in nodes:
		var center := Vector2(node.x, node.y)
		var closest := Vector2(clampf(center.x, bounds.position.x, bounds.end.x), clampf(center.y, bounds.position.y, bounds.end.y))
		if closest.distance_to(center) < node.z + NODE_CLEARANCE:
			return false
	for seg in segments:
		var a: Vector2 = seg[0]
		var b: Vector2 = seg[1]
		for corner in corners:
			if Geometry2D.get_closest_point_to_segment(corner, a, b).distance_to(corner) < PATH_CLEARANCE:
				return false
		# Also reject rects the segment passes through.
		if Geometry2D.segment_intersects_segment(a, b, bounds.position, bounds.end) != null \
				or Geometry2D.segment_intersects_segment(a, b, Vector2(bounds.end.x, bounds.position.y), Vector2(bounds.position.x, bounds.end.y)) != null:
			return false
	return true
