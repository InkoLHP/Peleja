class_name MapLayout
extends Resource
## A full route map. Can come from a handcrafted .tres or, later, a procedural generator
## that simply builds and returns a MapLayout instance.

@export var nodes: Array = []


func get_node_data(node_id: int) -> MapNodeData:
	for node in nodes:
		if node.id == node_id:
			return node
	return null


func get_start_node() -> MapNodeData:
	for node in nodes:
		if node.type == "start":
			return node
	return nodes[0] if not nodes.is_empty() else null
