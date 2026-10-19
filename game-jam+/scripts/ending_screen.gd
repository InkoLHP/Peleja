extends Control
## Final screen shown after the last enemy is purified.

const HILL_Y_RATIO := 0.8
const SPRITE_HEIGHT := 256.0

@onready var hero: Node2D = $Hero
@onready var title: Label = $Texts/Title
@onready var subtitle: Label = $Texts/Subtitle
@onready var stats: Label = $Texts/Stats
@onready var buttons: VBoxContainer = $Buttons
@onready var again_button: Button = $Buttons/AgainButton
@onready var menu_button: Button = $Buttons/MenuButton


func _ready() -> void:
	# The journey is over: "Continuar" must not drop the player back into the boss fight.
	GameState.delete_save()
	again_button.pressed.connect(_on_again_pressed)
	menu_button.pressed.connect(_on_menu_pressed)
	stats.text = "Vida restante: %d/%d   ·   Locais percorridos: %d" % [
		GameState.hp, GameState.max_hp, maxi(GameState.completed_nodes.size() - 1, 0)]
	resized.connect(_layout)
	_layout()
	_play_intro()


## The hero stands on the hill whatever the window shape is.
func _layout() -> void:
	var fit := clampf(size.y / 720.0, 0.6, 1.4)
	hero.scale = Vector2.ONE * fit
	hero.position = Vector2(size.x * 0.36, size.y * HILL_Y_RATIO)


func _play_intro() -> void:
	for node in [title, subtitle, stats, buttons]:
		node.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(title, "modulate:a", 1.0, 0.9)
	tween.tween_property(subtitle, "modulate:a", 1.0, 0.6)
	tween.tween_property(stats, "modulate:a", 1.0, 0.5)
	tween.tween_property(buttons, "modulate:a", 1.0, 0.4)
	await tween.finished
	again_button.grab_focus()


func _on_again_pressed() -> void:
	GameState.reset_run()
	# The player already knows how to fight: do not replay the tutorial.
	GameState.is_tutorial = false
	SceneRouter.go_to_map()


func _on_menu_pressed() -> void:
	GameState.reset_run()
	SceneRouter.go_to_menu()
