class_name EnemyActionData
extends Resource
## One thing an enemy can do on its turn. New enemy actions are new .tres files, not code.

@export_enum("attack", "defend") var type: String = "attack"
@export var display_name: String = "Pancada de Casca"
## Damage for an attack; block gained for a defend.
@export var damage: int = 8
## HP the enemy heals itself when it uses this action.
@export var self_heal: int = 0
## Relative chance of this action being picked as the next intent.
@export var weight: int = 10
