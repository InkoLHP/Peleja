extends Control
## Esc pause menu for the map. Runs while the tree is paused.

signal resumed
signal quit_to_menu

@onready var continue_button: Button = $Center/Panel/VBox/ContinueButton
@onready var save_button: Button = $Center/Panel/VBox/SaveButton
@onready var save_status: Label = $Center/Panel/VBox/SaveStatus
@onready var menu_button: Button = $Center/Panel/VBox/MenuButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	continue_button.pressed.connect(close)
	save_button.pressed.connect(_on_save_pressed)
	menu_button.pressed.connect(_on_menu_pressed)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel") or SceneRouter.is_transitioning():
		return
	if visible:
		close()
	else:
		open()
	get_viewport().set_input_as_handled()


func open() -> void:
	save_status.text = ""
	show()
	get_tree().paused = true
	continue_button.grab_focus()


func close() -> void:
	hide()
	get_tree().paused = false
	resumed.emit()


func _on_save_pressed() -> void:
	if GameState.save_game():
		save_status.text = "Jogo salvo!"
	else:
		save_status.text = "Não foi possível salvar."


func _on_menu_pressed() -> void:
	if SceneRouter.is_transitioning():
		return
	get_tree().paused = false
	quit_to_menu.emit()
	SceneRouter.go_to_menu()
