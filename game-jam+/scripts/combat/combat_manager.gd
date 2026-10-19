extends Control
## Turn-based side-view battle.
## Flow is Slay the Spire (player turn, then enemy turn, and the enemy always shows
## its next intent) but the player picks a COMMAND from a Chrono Trigger style menu
## instead of playing cards. Framing: the Cangaceiro on the left, the enemy on the right.

enum State { PLAYER_TURN, PLAYER_ACTING, ENEMY_TURN, ENEMY_ACTING, VICTORY, DEFEAT }
enum MenuMode { COMMAND, SUBMENU, TARGETING }

const SKILL_DIR := "res://data/skills/"
const DEFAULT_ENEMY_PATH := "res://data/enemies/corpo_seco.tres"
const BOSS_TEXTURE_PATH := "res://art/Corpo_seco_final.png"

## Fúria do chefe: ganha +2 de dano por turno inimigo, até +8.
const BOSS_FURY_PER_TURN := 2
const BOSS_FURY_MAX_BONUS := 8

const PLAYER_NAME := "Cangaceiro"
const STEP_DELAY := 0.45
const ZERO_AP_PAUSE := 0.6
const PURIFY_DELAY := 1.5
const SPRITE_HEIGHT := 256.0
const READOUT_HEIGHT := 150.0
const MENU_ENTRY_SIZE := Vector2(0, 36)

const SFX_SHOT := preload("res://audio/9mm Single.mp3")
const SFX_RELOAD := preload("res://audio/Slide1.ogg")
const SFX_SWORD := preload("res://audio/universfield-sword-blade-slicing-flesh-352708.mp3")
const SFX_DRINK := preload("res://audio/freesound_community-juicy-splash-104642.mp3")

var _sfx := AudioStreamPlayer.new()

const COL_DAMAGE := Color(1, 0.35, 0.28, 1)
const COL_BLOCKED := Color(0.75, 0.78, 0.85, 1)
const COL_HEAL := Color(0.5, 0.95, 0.55, 1)
const COL_MALANDRAGEM := Color(0.82, 0.62, 1, 1)
const COL_AP_FILLED := Color(1, 0.86, 0.35, 1)
const COL_AP_EMPTY := Color(0.33, 0.35, 0.4, 1)
const COL_ENEMY_PURIFIED := Color(0.6, 0.95, 0.6, 1)

const COMMANDS := [
	{"key": "attack", "label": "Atacar", "skill": SKILL_DIR + "atacar.tres", "submenu": ""},
	{"key": "technique", "label": "Técnica", "skill": "", "submenu": "technique"},
	{"key": "item", "label": "Item", "skill": "", "submenu": "item"},
	{"key": "defend", "label": "Defender", "skill": SKILL_DIR + "defender.tres", "submenu": ""},
]

const TECHNIQUE_PATHS := [
	SKILL_DIR + "tiro_de_bacamarte.tres",
	SKILL_DIR + "recarregar.tres",
	SKILL_DIR + "rasteira_de_malandro.tres",
]

@export var actions_per_turn: int = 2
@export var floating_text_font: Font = preload("res://ui/xilosa_.ttf")

@onready var arena: Control = $Arena
@onready var player_sprite: PlaceholderCharacter = $Arena/PlayerSprite
@onready var enemy_sprite: PlaceholderCharacter = $Arena/EnemySprite
@onready var enemy_art: Sprite2D = $Arena/EnemySprite/Body/Art
@onready var enemy_name_label: Label = $Arena/EnemyNameLabel
@onready var enemy_hp_bar: Control = $Arena/EnemyHpBar
@onready var info_moedas: Label = $BottomPanel/Margin/Row/InfoBox/StatusGrid/Moedas
@onready var enemy_hp_fill: ColorRect = $Arena/EnemyHpBar/Fill
@onready var intent_icon: IntentIcon = $Arena/EnemyIntent/IntentRow/IntentIcon
@onready var intent_value: Label = $Arena/EnemyIntent/IntentRow/IntentValue
@onready var floating_layer: Control = $Arena/FloatingLayer
@onready var target_cursor: TargetCursor = $Arena/TargetCursor
@onready var purified_label: Label = $Arena/PurifiedLabel

@onready var command_panel: PanelContainer = $BottomPanel/Margin/Row/CommandPanel
@onready var command_buttons: Array[Button] = [
	$BottomPanel/Margin/Row/CommandPanel/Stack/MainView/CommandGrid/AtacarButton,
	$BottomPanel/Margin/Row/CommandPanel/Stack/MainView/CommandGrid/TecnicaButton,
	$BottomPanel/Margin/Row/CommandPanel/Stack/MainView/CommandGrid/ItemButton,
	$BottomPanel/Margin/Row/CommandPanel/Stack/MainView/CommandGrid/DefenderButton,
]
@onready var end_turn_button: Button = $BottomPanel/Margin/Row/CommandPanel/Stack/MainView/EndTurnButton
@onready var pointer: Label = $Pointer
@onready var info_hp: Label = $BottomPanel/Margin/Row/InfoBox/StatusGrid/InfoHp
@onready var info_block: Label = $BottomPanel/Margin/Row/InfoBox/StatusGrid/InfoBlock
@onready var ap_box: HBoxContainer = $BottomPanel/Margin/Row/InfoBox/StatusGrid/ApRow/ApBox
@onready var ammo_value: Label = $BottomPanel/Margin/Row/InfoBox/StatusGrid/AmmoRow/AmmoValue
@onready var mal_fill: ColorRect = $BottomPanel/Margin/Row/InfoBox/MalRow/MalBar/Fill
@onready var mal_value: Label = $BottomPanel/Margin/Row/InfoBox/MalRow/MalValue

@onready var main_view: VBoxContainer = $BottomPanel/Margin/Row/CommandPanel/Stack/MainView
@onready var sub_panel: VBoxContainer = $BottomPanel/Margin/Row/CommandPanel/Stack/SubView
@onready var sub_title: Label = $BottomPanel/Margin/Row/CommandPanel/Stack/SubView/Title
@onready var sub_entries: VBoxContainer = $BottomPanel/Margin/Row/CommandPanel/Stack/SubView/Scroll/Entries
@onready var sub_back_button: Button = $BottomPanel/Margin/Row/CommandPanel/Stack/SubView/BackButton

@onready var end_panel: Control = $EndPanel
@onready var result_label: Label = $EndPanel/Center/Panel/VBox/ResultLabel
@onready var menu_button: Button = $EndPanel/Center/Panel/VBox/MenuButton
@onready var return_game_button: Button = $EndPanel/Center/Panel/VBox/ReturnGame

@onready var combat_tutorial: Control = $CombatTutorial if has_node("CombatTutorial") else null

var _state: int = State.PLAYER_TURN
var _menu_mode: int = MenuMode.COMMAND
var _player: Combatant
var _enemy: Combatant
var _enemy_data: EnemyData
var _intent: EnemyActionData
var _intent_cancelled := false
var _last_intent: EnemyActionData
var _repeat_count := 0
var _pending_skill: SkillData
var _action_points := 0
var _ap_dots: Array[Panel] = []
var _sub_buttons: Array[Button] = []
var rng = RandomNumberGenerator.new()

## Bônus acumulado de dano da Fúria Crescente.
var _boss_fury_bonus: int = 0

var _skill_cache: Dictionary = {}


func _ready() -> void:
	MainSoundtrack.play_combat()
	add_child(_sfx)
	end_panel.hide()
	purified_label.hide()
	_set_submenu_visible(false)
	pointer.hide()
	target_cursor.hide_target()

	for i in command_buttons.size():
		command_buttons[i].pressed.connect(_on_command_pressed.bind(i))
		command_buttons[i].mouse_entered.connect(command_buttons[i].grab_focus)

	end_turn_button.pressed.connect(_on_end_turn_pressed)
	end_turn_button.mouse_entered.connect(end_turn_button.grab_focus)

	sub_back_button.pressed.connect(_close_submenu)
	sub_back_button.mouse_entered.connect(sub_back_button.grab_focus)

	menu_button.pressed.connect(_on_menu_pressed)
	return_game_button.pressed.connect(_on_return_game_pressed)

	arena.resized.connect(_layout_arena)
	enemy_hp_bar.resized.connect(_update_enemy_bar)
	GameState.ammo_changed.connect(_on_ammo_changed)
	GameState.malandragem_changed.connect(_on_malandragem_changed)

	_setup_combatants()
	_build_action_points()
	_layout_arena()

	_roll_intent()
	_begin_player_turn()
	_show_command_labels()

	_on_ammo_changed(GameState.ammo, GameState.max_ammo)
	_on_malandragem_changed(GameState.malandragem, GameState.max_malandragem)

	if GameState.is_tutorial and combat_tutorial != null:
		combat_tutorial.start_tutorial(self)
	elif combat_tutorial != null:
		combat_tutorial.hide()
		combat_tutorial.queue_free()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_down") or event.is_action_pressed("nav_down"):
		_move_focus(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_up") or event.is_action_pressed("nav_up"):
		_move_focus(-1)
		get_viewport().set_input_as_handled()

func _play_sfx(stream: AudioStream) -> void:
	_sfx.stream = stream
	_sfx.play()

func _unhandled_input(event: InputEvent) -> void:
	if _state == State.VICTORY or _state == State.DEFEAT:
		return

	if _menu_mode == MenuMode.TARGETING:
		if event.is_action_pressed("ui_accept"):
			_confirm_target()
			get_viewport().set_input_as_handled()
			return

		if _is_back_event(event):
			_cancel_targeting()
			get_viewport().set_input_as_handled()
			return

		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if _enemy_rect().has_point(_to_arena_space(event.position)):
				_confirm_target()
				get_viewport().set_input_as_handled()
			return
		return

	if _is_back_event(event):
		if _menu_mode == MenuMode.SUBMENU:
			_close_submenu()
			get_viewport().set_input_as_handled()
		return


func _is_back_event(event: InputEvent) -> bool:
	if event.is_action_pressed("ui_cancel"):
		return true
	return event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_BACKSPACE


func _process(_delta: float) -> void:
	_update_pointer()


## --- setup ------------------------------------------------------------------------

func _setup_combatants() -> void:
	GameState.ensure_run()
	_boss_fury_bonus = 0

	_enemy_data = GameState.current_enemy as EnemyData
	if _enemy_data == null:
		_enemy_data = load(DEFAULT_ENEMY_PATH) as EnemyData

	_player = Combatant.new()
	_player.setup(PLAYER_NAME, GameState.hp, GameState.max_hp)
	_player.hp_changed.connect(_on_player_hp_changed)
	_player.block_changed.connect(_on_player_block_changed)
	_player.damaged.connect(_on_player_damaged)

	_enemy = Combatant.new()
	var enemy_hp := _enemy_data.hp_max if _enemy_data else 40
	var enemy_name := _enemy_data.display_name if _enemy_data else "Corpo-Seco"

	_enemy.setup(enemy_name, enemy_hp, enemy_hp)
	_enemy.hp_changed.connect(_on_enemy_hp_changed)
	_enemy.damaged.connect(_on_enemy_damaged)
	_enemy.block_changed.connect(_on_enemy_block_changed)

	enemy_name_label.text = enemy_name

	if GameState.final_battle:
		_apply_boss_visual()

	info_moedas.text = "Moedas: %d" % [GameState.moedas]
	info_hp.text = "HP %d/%d" % [_player.hp, _player.max_hp]
	info_block.text = "Bloqueio: %d" % _player.block


func _apply_boss_visual() -> void:
	var boss_texture := load(BOSS_TEXTURE_PATH) as Texture2D

	if boss_texture == null:
		push_error("Não foi possível carregar o sprite do chefe: " + BOSS_TEXTURE_PATH)
		return

	var target_height := 220.0
	var scale_factor := target_height / float(boss_texture.get_height())

	enemy_art.texture = boss_texture
	enemy_art.scale = Vector2.ONE * scale_factor
	enemy_art.position = Vector2(0.0, -target_height * 0.5)
	enemy_art.offset = Vector2.ZERO


func _layout_arena() -> void:
	var area := arena.size
	if area.x <= 0.0 or area.y <= 0.0:
		return

	var ground := area.y - 34.0
	var fit := clampf((area.y - 34.0 - READOUT_HEIGHT) / SPRITE_HEIGHT, 0.5, 1.2)

	player_sprite.scale = Vector2.ONE * fit
	enemy_sprite.scale = Vector2.ONE * fit

	player_sprite.position = Vector2(area.x * 0.25, ground)
	enemy_sprite.position = Vector2(area.x * 0.75, ground)

	var top := enemy_sprite.position.y - SPRITE_HEIGHT * fit
	var center_x := enemy_sprite.position.x

	$Arena/EnemyIntent.position = Vector2(center_x - 120.0, top - 70.0)
	$Arena/EnemyIntent.size = Vector2(240.0, 64.0)

	enemy_hp_bar.position = Vector2(center_x - 120.0, top - 96.0)
	enemy_hp_bar.size = Vector2(240.0, 20.0)

	enemy_name_label.position = Vector2(center_x - 150.0, top - 136.0)
	enemy_name_label.size = Vector2(300.0, 36.0)

	_update_enemy_bar()


func _enemy_rect() -> Rect2:
	var fit: float = enemy_sprite.scale.x
	var box := Vector2(150.0, 250.0) * fit
	var center := enemy_sprite.position + Vector2(0.0, -125.0 * fit)
	return Rect2(center - box * 0.5, box)


func _to_arena_space(viewport_point: Vector2) -> Vector2:
	return arena.get_global_transform().affine_inverse() * viewport_point


## --- turn flow --------------------------------------------------------------------

func _begin_player_turn() -> void:
	_state = State.PLAYER_TURN
	_action_points = actions_per_turn
	_player.reset_block()
	_refresh_hud()
	_open_command_menu()


func _end_player_turn() -> void:
	if _state != State.PLAYER_TURN:
		return

	_state = State.ENEMY_TURN
	_close_submenu()
	_clear_focus()
	_refresh_hud()

	await get_tree().create_timer(STEP_DELAY * 0.6).timeout

	_state = State.ENEMY_ACTING
	await _run_enemy_action()

	if _player.hp <= 0:
		_lose()
		return

	_begin_player_turn()


func _run_enemy_action() -> void:
	# Like the player, the enemy's block never carries over between turns.
	_enemy.reset_block()

	if _intent_cancelled:
		_intent_cancelled = false
		_show_float(enemy_sprite, "cancelado", COL_BLOCKED)

		await get_tree().create_timer(STEP_DELAY).timeout

		_increase_boss_fury()
		_roll_intent()
		return

	if _intent == null:
		_roll_intent()
		return

	var action := _intent

	if action.type == "defend":
		await enemy_sprite.sway_act()
		_enemy.add_block(action.damage)
		_show_float(enemy_sprite, "+%d bloqueio" % action.damage, COL_BLOCKED)
	else:
		await enemy_sprite.step_forward()
		player_sprite.react_to_hit()

		var incoming_damage := _effective_enemy_damage(action)
		_player.take_damage(incoming_damage)

		if action.self_heal > 0:
			var healed := _enemy.heal(action.self_heal)
			if healed > 0:
				_show_float(enemy_sprite, "+%d" % healed, COL_HEAL)

	_refresh_hud()

	await get_tree().create_timer(STEP_DELAY).timeout

	_increase_boss_fury()
	_roll_intent()


## Retorna o dano real que o inimigo causará.
## O bônus só é aplicado na batalha final.
func _effective_enemy_damage(action: EnemyActionData) -> int:
	var damage: int = action.damage

	if GameState.final_battle and action.type != "defend":
		damage += _boss_fury_bonus

	return damage


## Aumenta a Fúria depois do turno do chefe.
## O limite evita que o combate fique progressivamente impossível.
func _increase_boss_fury() -> void:
	if not GameState.final_battle:
		return

	if _boss_fury_bonus >= BOSS_FURY_MAX_BONUS:
		return

	_boss_fury_bonus = mini(
		_boss_fury_bonus + BOSS_FURY_PER_TURN,
		BOSS_FURY_MAX_BONUS
	)

	_show_float(
		enemy_sprite,
		"FÚRIA: +%d DANO" % _boss_fury_bonus,
		COL_MALANDRAGEM
	)


## --- commands ---------------------------------------------------------------------

func _show_command_labels() -> void:
	for i in COMMANDS.size():
		var skill := _load_skill(COMMANDS[i].skill)

		if skill != null:
			command_buttons[i].text = "%s (%d)" % [COMMANDS[i].label, skill.ap_cost]
		else:
			command_buttons[i].text = COMMANDS[i].label

		command_buttons[i].tooltip_text = skill.description if skill != null else ""


func _on_command_pressed(index: int) -> void:
	if _state != State.PLAYER_TURN or _menu_mode == MenuMode.TARGETING:
		return

	var command: Dictionary = COMMANDS[index]

	if combat_tutorial != null and combat_tutorial.visible:
		combat_tutorial.advance_if_action_matches(command.key)

	if command.submenu == "technique":
		_open_submenu("Técnica", _technique_skills())
		return

	if command.submenu == "item":
		_open_submenu("Item", _item_skills())
		return

	var skill := _load_skill(command.skill)

	if skill == null or not _can_use(skill):
		return

	if skill.needs_target:
		_begin_targeting(skill)
	else:
		_perform_skill(skill)


func _technique_skills() -> Array[SkillData]:
	var skills: Array[SkillData] = []

	for path in TECHNIQUE_PATHS:
		var skill := _load_skill(path)
		if skill != null:
			skills.append(skill)

	return skills


func _item_skills() -> Array[SkillData]:
	var skills: Array[SkillData] = []

	for path in GameState.distinct_items():
		var skill := _load_skill(path)
		if skill != null:
			skills.append(skill)

	return skills


func _load_skill(path: String) -> SkillData:
	if path.is_empty():
		return null

	if _skill_cache.has(path):
		return _skill_cache[path]

	var skill := load(path) as SkillData
	_skill_cache[path] = skill
	return skill


func _can_use(skill: SkillData) -> bool:
	if _state != State.PLAYER_TURN:
		return false

	if _action_points < skill.ap_cost:
		return false

	if GameState.ammo < skill.ammo_cost:
		return false

	if GameState.malandragem < skill.malandragem_cost:
		return false

	if skill.effect == "heal" and _player.hp >= _player.max_hp:
		return false

	return true


func _skill_label(skill: SkillData) -> String:
	var costs: Array[String] = ["%d AP" % skill.ap_cost]

	if skill.ammo_cost > 0:
		costs.append("%d munição" % skill.ammo_cost)

	if skill.malandragem_cost > 0:
		costs.append("%d Malandragem" % skill.malandragem_cost)

	var text := "%s (%s)" % [skill.display_name, ", ".join(costs)]

	if skill.effect == "heal":
		text += " x%d" % GameState.item_count(_skill_path(skill))

	return text


func _skill_path(skill: SkillData) -> String:
	for path in _skill_cache:
		if _skill_cache[path] == skill:
			return path

	# Skills triggered from outside (the tutorial) are not in the cache yet.
	return skill.resource_path


## --- performing an action ---------------------------------------------------------

func _perform_skill(skill: SkillData) -> void:
	if _state != State.PLAYER_TURN or not _can_use(skill):
		return

	var skill_path := _skill_path(skill)

	if combat_tutorial != null and combat_tutorial.visible:
		if "atacar" in skill_path:
			combat_tutorial.advance_if_action_matches("attack")
		elif "defender" in skill_path:
			combat_tutorial.advance_if_action_matches("defend")
		elif skill.effect == "heal":
			combat_tutorial.advance_if_action_matches("use_item")
		elif "tiro_de_bacamarte" in skill_path or "recarregar" in skill_path or "rasteira" in skill_path:
			combat_tutorial.advance_if_action_matches("technique")

	_state = State.PLAYER_ACTING
	_close_submenu()
	target_cursor.hide_target()
	_clear_focus()
	_pay_costs(skill)
	_refresh_hud()

	await player_sprite.step_forward()

	if "atacar" in skill_path:
		_play_sfx(SFX_SWORD)
	elif "tiro_de_bacamarte" in skill_path:
		_play_sfx(SFX_SHOT)

	if skill.damage > 0:
		var spread := maxi(skill.damage_variance, 0)
		var damage := maxi(skill.damage + randi_range(-spread, spread), 0)

		_enemy.take_damage(damage)
		enemy_sprite.react_to_hit()

	if skill.block > 0:
		_player.add_block(skill.block)
		_show_float(player_sprite, "+%d bloqueio" % skill.block, COL_BLOCKED)

	if skill.effect == "heal" and skill.heal > 0:
		_play_sfx(SFX_DRINK)
		var healed := _player.heal(skill.heal)

		if healed > 0:
			_show_float(player_sprite, "+%d" % healed, COL_HEAL)

		GameState.consume_item(skill_path)

	if skill.effect == "reload_ammo":
		_play_sfx(SFX_RELOAD)
		GameState.reload_ammo()
		_show_float(player_sprite, "munição cheia", COL_MALANDRAGEM)

	if skill.effect == "cancel_intent":
		_cancel_intent()
		_show_float(enemy_sprite, "intenção cancelada", COL_MALANDRAGEM)

	if skill.malandragem_gain > 0:
		GameState.add_malandragem(skill.malandragem_gain)
		_show_float(player_sprite, "+%d malandragem" % skill.malandragem_gain, COL_MALANDRAGEM)

	_refresh_hud()

	await get_tree().create_timer(STEP_DELAY).timeout

	if _enemy.hp <= 0:
		_win()
		return

	if _action_points <= 0:
		_state = State.PLAYER_TURN
		_refresh_hud()

		await get_tree().create_timer(ZERO_AP_PAUSE).timeout
		_end_player_turn()
		return

	_state = State.PLAYER_TURN
	_refresh_hud()
	_open_command_menu()


func _pay_costs(skill: SkillData) -> void:
	_action_points = maxi(_action_points - skill.ap_cost, 0)

	if skill.ammo_cost > 0:
		GameState.spend_ammo(skill.ammo_cost)

	if skill.malandragem_cost > 0:
		GameState.spend_malandragem(skill.malandragem_cost)


func _on_end_turn_pressed() -> void:
	if _state != State.PLAYER_TURN:
		return

	_end_player_turn()


## --- menu -------------------------------------------------------------------------

func _open_command_menu() -> void:
	if _state != State.PLAYER_TURN:
		return

	_menu_mode = MenuMode.COMMAND
	_close_submenu()
	_show_command_labels()
	_refresh_command_buttons()
	_focus_first_enabled(command_buttons)


func _open_submenu(title: String, skills: Array[SkillData]) -> void:
	_menu_mode = MenuMode.SUBMENU
	sub_title.text = title

	for child in sub_entries.get_children():
		sub_entries.remove_child(child)
		child.queue_free()

	_sub_buttons.clear()

	if skills.is_empty():
		var empty := Button.new()
		empty.text = "Nada aqui"
		empty.disabled = true
		empty.focus_mode = Control.FOCUS_NONE
		sub_entries.add_child(empty)
		_sub_buttons.append(empty)
	else:
		for skill in skills:
			var button := Button.new()
			button.text = _skill_label(skill)
			button.tooltip_text = skill.description
			button.custom_minimum_size = MENU_ENTRY_SIZE
			button.disabled = not _can_use(skill)
			button.focus_mode = Control.FOCUS_ALL if not button.disabled else Control.FOCUS_NONE
			button.pressed.connect(_on_sub_entry_pressed.bind(skill))
			button.mouse_entered.connect(button.grab_focus)

			sub_entries.add_child(button)
			_sub_buttons.append(button)

	_set_submenu_visible(true)
	_focus_first_enabled(_sub_buttons)


func _set_submenu_visible(value: bool) -> void:
	sub_panel.visible = value
	main_view.visible = not value


func _close_submenu() -> void:
	_set_submenu_visible(false)
	_menu_mode = MenuMode.COMMAND

	if _state == State.PLAYER_TURN:
		_focus_first_enabled(command_buttons)


func _on_sub_entry_pressed(skill: SkillData) -> void:
	if _state != State.PLAYER_TURN or not _can_use(skill):
		return

	if skill.needs_target:
		_begin_targeting(skill)
	else:
		_perform_skill(skill)


## --- target picking ---------------------------------------------------------------

func _begin_targeting(skill: SkillData) -> void:
	_pending_skill = skill
	_menu_mode = MenuMode.TARGETING
	_set_submenu_visible(false)
	_clear_focus()
	_set_command_buttons_enabled(false)
	target_cursor.show_target(_enemy_rect())


func _confirm_target() -> void:
	if _menu_mode != MenuMode.TARGETING or _pending_skill == null:
		return

	var skill := _pending_skill
	_pending_skill = null
	target_cursor.hide_target()
	_menu_mode = MenuMode.COMMAND

	if combat_tutorial != null and combat_tutorial.visible:
		combat_tutorial.advance_if_action_matches("attack")

	_perform_skill(skill)


func _cancel_targeting() -> void:
	_pending_skill = null
	target_cursor.hide_target()
	_open_command_menu()


func _enemy_intent_cancelled() -> bool:
	return _intent_cancelled


## --- enemy intent -----------------------------------------------------------------

func _roll_intent() -> void:
	_intent = null
	_intent_cancelled = false

	if _enemy_data == null or _enemy_data.actions.is_empty():
		_refresh_intent()
		return

	var pool: Array = []

	for action in _enemy_data.actions:
		if action == _last_intent and _repeat_count >= 2:
			continue
		pool.append(action)

	if pool.is_empty():
		pool = _enemy_data.actions.duplicate()

	_intent = _pick_weighted(pool)

	if _intent == _last_intent:
		_repeat_count += 1
	else:
		_last_intent = _intent
		_repeat_count = 1

	_refresh_intent()


func _pick_weighted(actions: Array) -> EnemyActionData:
	var total := 0

	for action in actions:
		total += maxi(action.weight, 1)

	var roll := randi() % maxi(total, 1)

	for action in actions:
		roll -= maxi(action.weight, 1)
		if roll < 0:
			return action

	return actions[0]


func _cancel_intent() -> void:
	_intent = null
	_intent_cancelled = true
	_refresh_intent()


func _refresh_intent() -> void:
	if _intent == null:
		intent_icon.hide()
		intent_value.add_theme_font_size_override("font_size", 22)
		intent_value.text = "cancelada" if _intent_cancelled else ""
		return

	intent_value.add_theme_font_size_override("font_size", 40)
	intent_icon.show()

	if _intent.type == "defend":
		intent_icon.set_kind(IntentIcon.Kind.DEFEND)
		intent_value.text = str(_intent.damage)
	else:
		intent_icon.set_kind(IntentIcon.Kind.ATTACK)

		# Mostra o dano previsto já incluindo a Fúria do chefe.
		var text := str(_effective_enemy_damage(_intent))

		if _intent.self_heal > 0:
			text += "+%d" % _intent.self_heal

		intent_value.text = text


## --- outcome ----------------------------------------------------------------------

func _win() -> void:
	GameState.add_moedas(rng.randi_range(4, 13))

	_state = State.VICTORY
	_menu_mode = MenuMode.COMMAND
	_close_submenu()
	target_cursor.hide_target()
	_clear_focus()
	_refresh_hud()

	GameState.is_tutorial = false

	enemy_sprite.modulate = Color.WHITE
	await get_tree().create_timer(0.24).timeout
	enemy_sprite.modulate = COL_ENEMY_PURIFIED
	_show_purified()

	await get_tree().create_timer(PURIFY_DELAY).timeout

	GameState.complete_map_node(GameState.current_map_node)

	if GameState.final_battle:
		SceneRouter.go_to_ending()
	else:
		SceneRouter.go_to_map()

func _lose() -> void:
	_state = State.DEFEAT
	_close_submenu()
	target_cursor.hide_target()

	result_label.text = "A Hecatombe venceu..."
	menu_button.text = "Voltar ao menu"
	return_game_button.text = "Recomeçar jornada"

	end_panel.show()
	return_game_button.grab_focus()


func _show_purified() -> void:
	purified_label.modulate.a = 0.0
	purified_label.pivot_offset = purified_label.size * 0.5
	purified_label.scale = Vector2(0.8, 0.8)
	purified_label.show()

	var tween := create_tween().set_parallel(true)

	tween.tween_property(purified_label, "modulate:a", 1.0, 0.25)
	tween.tween_property(purified_label, "scale", Vector2(1.06, 1.06), 0.4) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## MenuButton: volta ao menu principal.
func _on_menu_pressed() -> void:
	var tutorial_estava_ativo: bool = GameState.is_tutorial

	GameState.reset_run()
	GameState.set_moedas(0)
	GameState.is_tutorial = tutorial_estava_ativo

	SceneRouter.go_to_menu()


## ReturnGame: reinicia a jornada.
func _on_return_game_pressed() -> void:
	var tutorial_estava_ativo: bool = GameState.is_tutorial

	GameState.reset_run()
	GameState.set_moedas(0)
	GameState.is_tutorial = tutorial_estava_ativo

	SceneRouter.go_to_map()


## --- presentation -----------------------------------------------------------------

func _refresh_hud() -> void:
	info_hp.text = "HP %d/%d" % [_player.hp, _player.max_hp]
	info_block.text = "Bloqueio: %d" % _player.block
	info_moedas.text = "Moedas: %d" % [GameState.moedas]

	_refresh_command_buttons()
	end_turn_button.disabled = _state != State.PLAYER_TURN
	_update_action_points()
	_update_enemy_bar()

	_on_ammo_changed(GameState.ammo, GameState.max_ammo)
	_on_malandragem_changed(GameState.malandragem, GameState.max_malandragem)


func _refresh_command_buttons() -> void:
	for i in COMMANDS.size():
		var skill := _load_skill(COMMANDS[i].skill)
		var usable := skill == null or _can_use(skill)

		command_buttons[i].disabled = _state != State.PLAYER_TURN or not usable
		command_buttons[i].focus_mode = Control.FOCUS_ALL if not command_buttons[i].disabled else Control.FOCUS_NONE


func _set_command_buttons_enabled(value: bool) -> void:
	for button in command_buttons:
		button.disabled = not value
		button.focus_mode = Control.FOCUS_ALL if value else Control.FOCUS_NONE


func _build_action_points() -> void:
	for dot in _ap_dots:
		dot.queue_free()

	_ap_dots.clear()

	for i in actions_per_turn:
		var dot := Panel.new()
		dot.custom_minimum_size = Vector2(24, 24)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ap_box.add_child(dot)
		_ap_dots.append(dot)


func _update_action_points() -> void:
	for i in _ap_dots.size():
		var filled := i < _action_points

		_ap_dots[i].add_theme_stylebox_override(
			"panel",
			_dot_style(COL_AP_FILLED if filled else COL_AP_EMPTY)
		)


func _dot_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_right = 12
	style.corner_radius_bottom_left = 12
	return style


func _update_enemy_bar() -> void:
	var ratio := 0.0 if _enemy == null or _enemy.max_hp <= 0 else float(_enemy.hp) / float(_enemy.max_hp)
	var inner := maxf(enemy_hp_bar.size.x - 4.0, 0.0)

	enemy_hp_fill.offset_right = 2.0 + inner * ratio


func _show_float(target: Node2D, text: String, color: Color) -> void:
	if target == null:
		return

	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.z_index = 100
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.custom_minimum_size = Vector2(300, 50)
	label.size = Vector2(300, 50)

	if floating_text_font != null:
		label.add_theme_font_override("font", floating_text_font)

	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.02, 1.0))
	label.add_theme_constant_override("outline_size", 6)

	var parent_node: Node = floating_layer if floating_layer != null else self
	parent_node.add_child(label)

	var fit: float = target.scale.y if "scale" in target else 1.0
	var target_pos := target.global_position

	var start_pos := Vector2(
		target_pos.x - (label.size.x * 0.5),
		target_pos.y - (140.0 * fit)
	)

	if target == enemy_sprite:
		start_pos.x += 20.0

	label.global_position = start_pos

	var tween := create_tween()
	tween.set_parallel(true)

	tween.tween_property(label, "global_position:y", start_pos.y - 60.0, 0.8) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	tween.tween_property(label, "modulate:a", 0.0, 0.4).set_delay(0.4)

	tween.chain().tween_callback(label.queue_free)


## --- focus and pointer -------------------------------------------------------------

func _menu_entries() -> Array[Button]:
	if _menu_mode == MenuMode.SUBMENU:
		return _sub_buttons

	var entries: Array[Button] = []
	entries.assign(command_buttons)
	entries.append(end_turn_button)
	return entries


func _focus_first_enabled(buttons: Array[Button]) -> void:
	for button in buttons:
		if not button.disabled and button.is_visible_in_tree():
			button.grab_focus()
			return


func _clear_focus() -> void:
	get_viewport().gui_release_focus()


func _move_focus(step: int) -> void:
	if _state != State.PLAYER_TURN or _menu_mode == MenuMode.TARGETING:
		return

	var entries: Array[Button] = []

	for button in _menu_entries():
		if not button.disabled and button.is_visible_in_tree():
			entries.append(button)

	if entries.is_empty():
		return

	var current := get_viewport().gui_get_focus_owner()
	var index := entries.find(current)
	index = 0 if index == -1 else wrapi(index + step, 0, entries.size())

	entries[index].grab_focus()


func _update_pointer() -> void:
	if _menu_mode == MenuMode.TARGETING or _state == State.VICTORY or _state == State.DEFEAT:
		pointer.hide()
		return

	var owner := get_viewport().gui_get_focus_owner()

	if owner == null or not (owner is Button) or not _menu_entries().has(owner):
		pointer.hide()
		return

	var entry := owner as Control

	if not entry.is_visible_in_tree():
		pointer.hide()
		return

	var rect := entry.get_global_rect()
	var parent := pointer.get_parent() as Control
	var local := parent.get_global_transform().affine_inverse() * rect.position

	pointer.position = local + Vector2(-pointer.size.x - 6.0, (rect.size.y - pointer.size.y) * 0.5)
	pointer.show()


## --- signal handlers ---------------------------------------------------------------

func _on_player_hp_changed(current: int, _maximum: int) -> void:
	GameState.set_hp(current)


func _on_player_block_changed(_block: int) -> void:
	if _player:
		info_block.text = "Bloqueio: %d" % _player.block


func _on_player_damaged(amount: int) -> void:
	if amount > 0:
		_show_float(player_sprite, str(amount), COL_DAMAGE)
	else:
		_show_float(player_sprite, "bloqueado", COL_BLOCKED)


func _on_enemy_hp_changed(_current: int, _maximum: int) -> void:
	_update_enemy_bar()


func _on_enemy_block_changed(_block: int) -> void:
	_update_enemy_bar()


func _on_enemy_damaged(amount: int) -> void:
	if amount > 0:
		_show_float(enemy_sprite, str(amount), COL_DAMAGE)
	else:
		_show_float(enemy_sprite, "bloqueado", COL_BLOCKED)

	_update_enemy_bar()


func _on_ammo_changed(current: int, maximum: int) -> void:
	ammo_value.text = "%d/%d" % [current, maximum]


func _on_malandragem_changed(current: int, maximum: int) -> void:
	var ratio := 0.0 if maximum <= 0 else float(current) / float(maximum)
	var inner := maxf(mal_fill.get_parent().size.x - 4.0, 0.0)

	mal_fill.offset_right = 2.0 + inner * ratio
	mal_value.text = "%d/%d" % [current, maximum]
