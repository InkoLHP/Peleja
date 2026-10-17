class_name SkillData
extends Resource
## One command the Cangaceiro can pick in battle. Data-driven: new commands and items
## are new .tres files in res://data/skills/ and res://data/items/.

## Hook the combat manager runs after the costs are paid.
## none | reload_ammo | cancel_intent | heal
@export_enum("none", "reload_ammo", "cancel_intent", "heal") var effect: String = "none"

@export var display_name: String = "Atacar"
@export var description: String = ""

@export_group("Costs")
@export var ap_cost: int = 1
@export var ammo_cost: int = 0
@export var malandragem_cost: int = 0

@export_group("Results")
@export var damage: int = 0
## Random spread added to damage, e.g. 2 means damage +-2.
@export var damage_variance: int = 0
@export var block: int = 0
@export var heal: int = 0
@export var malandragem_gain: int = 0
## Offensive commands ask the player to pick the enemy first.
@export var needs_target: bool = false
