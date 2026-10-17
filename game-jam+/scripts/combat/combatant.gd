class_name Combatant
extends RefCounted
## One side of a battle: name, HP and block, plus the signals the HUD listens to.

signal hp_changed(current: int, maximum: int)
signal block_changed(block: int)
## Emitted after damage is resolved; the amount is what actually reached the HP.
signal damaged(amount: int)


var display_name := ""
var max_hp := 1
var hp := 1
var block := 0


func setup(new_name: String, current_hp: int, new_max_hp: int) -> void:
	display_name = new_name
	max_hp = maxi(new_max_hp, 1)
	hp = clampi(current_hp, 0, max_hp)
	block = 0


## Block absorbs damage first. Returns how much damage reached the HP.
func take_damage(amount: int) -> int:
	var absorbed := mini(block, maxi(amount, 0))
	if absorbed > 0:
		block -= absorbed
		block_changed.emit(block)
	var through := maxi(amount, 0) - absorbed
	if through > 0:
		hp = maxi(hp - through, 0)
		hp_changed.emit(hp, max_hp)
	damaged.emit(through)
	return through


func add_block(amount: int) -> void:
	block += maxi(amount, 0)
	block_changed.emit(block)


## Restores HP up to the maximum. Returns how much was actually healed.
func heal(amount: int) -> int:
	var healed := mini(maxi(amount, 0), max_hp - hp)
	if healed <= 0:
		return 0
	hp += healed
	hp_changed.emit(hp, max_hp)
	return healed


## Called at the start of the player's turn: block never carries over.
func reset_block() -> void:
	if block == 0:
		return
	block = 0
	block_changed.emit(block)
