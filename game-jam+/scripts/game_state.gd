extends Node
## Global run state for the current journey (autoload: GameState).

signal hp_changed(current: int, maximum: int)
signal ammo_changed(current: int, maximum: int)
signal malandragem_changed(current: int, maximum: int)
signal inventory_changed
signal run_reset
signal moedas_changed(current: int)

const SAVE_PATH := "user://save_run.json"
const SAVE_VERSION := 1
const DEFAULT_MAX_HP := 100
const DEFAULT_MAX_AMMO := 6
const DEFAULT_MAX_MALANDRAGEM := 100
const STARTING_ITEMS := [
	"res://data/items/garrafada_de_ervas.tres",
	"res://data/items/garrafada_de_ervas.tres"
]

# Cangaceiro stats
var max_hp: int = DEFAULT_MAX_HP
var hp: int = DEFAULT_MAX_HP
var max_ammo: int = DEFAULT_MAX_AMMO
var ammo: int = DEFAULT_MAX_AMMO
var max_malandragem: int = DEFAULT_MAX_MALANDRAGEM
var malandragem: int = 0
var moedas: int = 0

var is_tutorial: bool = true

# Run progress. The inventory holds one entry per unit,
# so duplicates mean "two units".
var inventory: Array = []

## True once a run has been started (Nova Jornada) or
## initialised by a scene opened directly.
var run_active: bool = false

var current_map_node: int = -1
var visited_nodes: Array[int] = []
var completed_nodes: Array[int] = []
var current_enemy: Resource = null

## True while the fight in progress is the last one (the boss node).
## Winning it ends the run.
var final_battle: bool = false

signal map_node_changed(node_id: int)
signal map_node_completed(node_id: int)


## Resets everything to the start of a new journey.
func reset_run() -> void:
	is_tutorial = true
	run_active = true

	# Restore the initial maximum values.
	max_hp = DEFAULT_MAX_HP
	max_ammo = DEFAULT_MAX_AMMO
	max_malandragem = DEFAULT_MAX_MALANDRAGEM

	# Restore the starting inventory.
	inventory.clear()

	for path in STARTING_ITEMS:
		inventory.append(path)

	# Reset the map and encounter progress.
	current_map_node = -1
	visited_nodes.clear()
	completed_nodes.clear()
	current_enemy = null
	final_battle = false

	# Restore the player's initial resources.
	set_hp(max_hp)
	set_ammo(max_ammo)
	set_malandragem(0)

	# NEW: reset the coins when starting a new journey.
	set_moedas(0)

	# Notify the rest of the game that the run was reset.
	run_reset.emit()
	inventory_changed.emit()


## Makes sure a run exists. Scenes opened straight from the editor
## call this so they get a default run instead of stale or empty state.
func ensure_run() -> void:
	if not run_active:
		reset_run()


func set_hp(value: int) -> void:
	hp = clampi(value, 0, max_hp)
	hp_changed.emit(hp, max_hp)


func set_moedas(value: int) -> void:
	moedas = maxi(value, 0)
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


## Spends Malandragem only when there is enough of it.
## Returns true when it was spent.
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


## Removes one unit of an item. Returns true when a unit was removed.
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


## --- save / load -----------------------------------------------------------------

## True when a saved run exists on disk.
func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


## Writes the current run to disk. Returns true when it was saved.
## Combat is never saved mid-fight: the save always describes the map.
func save_game() -> bool:
	if not run_active or hp <= 0:
		return false

	var data := {
		"version": SAVE_VERSION,
		"hp": hp,
		"max_hp": max_hp,
		"ammo": ammo,
		"max_ammo": max_ammo,
		"malandragem": malandragem,
		"max_malandragem": max_malandragem,
		"moedas": moedas,
		"is_tutorial": is_tutorial,
		"inventory": inventory,
		"current_map_node": current_map_node,
		"visited_nodes": visited_nodes,
		"completed_nodes": completed_nodes,
	}

	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("GameState: could not write the save (error %d)." % FileAccess.get_open_error())
		return false

	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	return true


## Restores a run from disk. Returns false (and changes nothing) when the file
## is missing, unreadable or corrupted.
func load_game() -> bool:
	if not has_save():
		return false

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return false

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()

	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("GameState: the save file is corrupted.")
		return false

	var data: Dictionary = parsed

	# Stats: clamp everything so an edited or old save can never break the HUD.
	max_hp = maxi(_save_int(data, "max_hp", DEFAULT_MAX_HP), 1)
	max_ammo = maxi(_save_int(data, "max_ammo", DEFAULT_MAX_AMMO), 1)
	max_malandragem = maxi(_save_int(data, "max_malandragem", DEFAULT_MAX_MALANDRAGEM), 1)

	run_active = true
	is_tutorial = bool(data.get("is_tutorial", false))
	current_enemy = null
	final_battle = false

	inventory.clear()
	var saved_items: Variant = data.get("inventory", [])
	if typeof(saved_items) == TYPE_ARRAY:
		for item in saved_items:
			if typeof(item) == TYPE_STRING and item.begins_with("res://data/items/") and ResourceLoader.exists(item):
				inventory.append(item)

	current_map_node = _save_int(data, "current_map_node", -1)
	visited_nodes.clear()
	completed_nodes.clear()
	_load_id_list(data.get("visited_nodes", []), visited_nodes)
	_load_id_list(data.get("completed_nodes", []), completed_nodes)

	# A run is never saved dead, so a save with 0 HP can only be a broken file.
	set_hp(maxi(_save_int(data, "hp", max_hp), 1))
	set_ammo(_save_int(data, "ammo", max_ammo))
	set_malandragem(_save_int(data, "malandragem", 0))
	set_moedas(_save_int(data, "moedas", 0))

	inventory_changed.emit()
	return true


## Removes the save file (used when the journey is over).
func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


## JSON numbers come back as floats; this reads one safely as an int.
func _save_int(data: Dictionary, key: String, fallback: int) -> int:
	var value: Variant = data.get(key, fallback)
	if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
		return int(value)
	return fallback


func _load_id_list(source: Variant, target: Array[int]) -> void:
	if typeof(source) != TYPE_ARRAY:
		return
	for value in source:
		if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
			var id := int(value)
			if not target.has(id):
				target.append(id)
