extends Node
## Global run state for the current journey (autoload: GameState).

signal hp_changed(current: int, maximum: int)
signal ammo_changed(current: int, maximum: int)
signal malandragem_changed(current: int, maximum: int)
signal inventory_changed
signal run_reset
signal moedas_changed(current: int)

const SAVE_PATH := "user://save_run.json"
const DEFAULT_MAX_HP := 100
const DEFAULT_MAX_AMMO := 6
const DEFAULT_MAX_MALANDRAGEM := 100
const STARTING_ITEMS := ["res://data/items/garrafada_de_ervas.tres", "res://data/items/garrafada_de_ervas.tres"]

# Cangaceiro stats
var max_hp: int = DEFAULT_MAX_HP
var hp: int = DEFAULT_MAX_HP
var max_ammo: int = DEFAULT_MAX_AMMO
var ammo: int = DEFAULT_MAX_AMMO
var max_malandragem: int = DEFAULT_MAX_MALANDRAGEM
var malandragem: int = 0
var moedas: int = 0

var is_tutorial: bool = true

# Run progress. The inventory holds one entry per unit, so duplicates mean "two units".
var inventory: Array = []
## True once a run has been started (Nova Jornada) or initialised by a scene opened directly.
var run_active: bool = false
var current_map_node: int = -1
var visited_nodes: Array[int] = []
var completed_nodes: Array[int] = []
var current_enemy: Resource = null
## True while the fight in progress is the last one (the boss node). Winning it ends the run.
var final_battle: bool = false

signal map_node_changed(node_id: int)
signal map_node_completed(node_id: int)


## Resets everything to the start of a new journey.
func reset_run() -> void:
	is_tutorial = true
	run_active = true
	max_hp = DEFAULT_MAX_HP
	max_ammo = DEFAULT_MAX_AMMO
	max_malandragem = DEFAULT_MAX_MALANDRAGEM
	inventory.clear()
	for path in STARTING_ITEMS:
		inventory.append(path)
	current_map_node = -1
	visited_nodes.clear()
	completed_nodes.clear()
	current_enemy = null
	final_battle = false
	set_hp(max_hp)
	set_ammo(max_ammo)
	set_malandragem(0)
	run_reset.emit()
	inventory_changed.emit()


## Makes sure a run exists. Scenes opened straight from the editor (no menu) call this
## so they get a default run (full HP, ammo and items) instead of stale or empty state.
func ensure_run() -> void:
	if not run_active:
		reset_run()


func set_hp(value: int) -> void:
	hp = clampi(value, 0, max_hp)
	hp_changed.emit(hp, max_hp)

func set_moedas(value: int) -> void:
	moedas = value
	moedas_changed.emit(moedas)


func spend_moedas(amount: int) -> bool:
	if moedas < amount:
		return false
	set_moedas(moedas - amount)
	return true

func add_moedas(amount: int) -> void:
	set_moedas(moedas + amount)

func set_ammo(value: int) -> void:
	ammo = clampi(value, 0, max_ammo)
	ammo_changed.emit(ammo, max_ammo)


func heal(amount: int) -> void:
	set_hp(hp + amount)


func set_malandragem(value: int) -> void:
	malandragem = clampi(value, 0, max_malandragem)
	malandragem_changed.emit(malandragem, max_malandragem)


func add_malandragem(amount: int) -> void:
	set_malandragem(malandragem + amount)


## Spends Malandragem only when there is enough of it. Returns true when it was spent.
func spend_malandragem(amount: int) -> bool:
	if malandragem < amount:
		return false
	set_malandragem(malandragem - amount)
	return true


func spend_ammo(amount: int) -> bool:
	if ammo < amount:
		return false
	set_ammo(ammo - amount)
	return true


func reload_ammo() -> void:
	set_ammo(max_ammo)


## Adds one unit of an item (a res:// path to a SkillData).
func add_item(item_path: String) -> void:
	inventory.append(item_path)
	inventory_changed.emit()


## Removes one unit of an item. Returns true when a unit was actually removed.
func consume_item(item_path: String) -> bool:
	var index := inventory.find(item_path)
	if index == -1:
		return false
	inventory.remove_at(index)
	inventory_changed.emit()
	return true


## The distinct item paths currently carried, in first-seen order.
func distinct_items() -> Array[String]:
	var result: Array[String] = []
	for path in inventory:
		if not result.has(path):
			result.append(path)
	return result


func item_count(item_path: String) -> int:
	var count := 0
	for path in inventory:
		if path == item_path:
			count += 1
	return count


## Moves the Cangaceiro onto a map node and records it as visited.
func enter_map_node(node_id: int) -> void:
	current_map_node = node_id
	if not visited_nodes.has(node_id):
		visited_nodes.append(node_id)
	map_node_changed.emit(node_id)


## Marks a map node's encounter as finished, unlocking the next nodes.
func complete_map_node(node_id: int) -> void:
	if node_id < 0:
		return
	if not completed_nodes.has(node_id):
		completed_nodes.append(node_id)
	map_node_completed.emit(node_id)


func is_map_node_completed(node_id: int) -> bool:
	return completed_nodes.has(node_id)


## True when a saved run exists on disk.
func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)
