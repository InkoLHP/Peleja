class_name MapNodeData
extends Resource
## One node of the route map: its encounter type, position and outgoing links.

@export var id: int = 0
@export_enum("start", "combat", "event", "rest", "boss") var type: String = "combat"
@export var position: Vector2 = Vector2.ZERO
@export var next_ids: Array[int] = []
