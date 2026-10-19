extends Control
## "Loja" pop-up opened from the map button. The shop itself is not implemented yet:
## for now it shows the merchant and an "Em breve" notice, plus a close button.

signal opened
signal closed

@onready var close_button: Button = $Center/Panel/VBox/CloseButton


func _ready() -> void:
	hide()
	close_button.pressed.connect(close)


func _unhandled_input(event: InputEvent) -> void:
	# Esc closes the shop. This node sits above the pause menu in the scene tree,
	# so it receives the key first and the pause menu does not open at the same time.
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func open() -> void:
	if visible:
		return
	show()
	close_button.grab_focus()
	opened.emit()


func close() -> void:
	if not visible:
		return
	hide()
	closed.emit()
