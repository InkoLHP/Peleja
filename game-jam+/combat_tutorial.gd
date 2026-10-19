class_name CombatTutorial
extends Control

@onready var balloon_panel: PanelContainer = $BalloonPanel
@onready var title_label: Label = $BalloonPanel/Margin/VBox/TitleLabel
@onready var body_label: Label = $BalloonPanel/Margin/VBox/BodyLabel
@onready var next_button: Button = $BalloonPanel/Margin/VBox/NextButton
@onready var highlight_rect: ReferenceRect = $HighlightRect

var current_step := 0
var combat_ref: Node = null

var steps := [
	{"title": "Conhecendo o campo de batalha", "text": "Esse é você: o Cangaceiro.", "target_node": "PlayerSprite", "auto_advance": false, "require_action": ""},
	{"title": "Conhecendo o campo de batalha", "text": "E esse é o seu inimigo. Parece que você vai ter que resolver isso do jeito difícil...", "target_node": "EnemySprite", "auto_advance": false, "require_action": ""},
	{"title": "Conhecendo seus recursos", "text": "Aqui ficam suas ações. É por aqui que você escolhe o que fazer durante o combate.", "target_node": "CommandPanel", "auto_advance": false, "require_action": ""},
	{"title": "Conhecendo seus recursos", "text": "Já aqui ficam as estatísticas do seu Cangaceiro. Vamos dar uma olhada nelas.", "target_node": "InfoBox", "auto_advance": false, "require_action": ""},
	{"title": "Conhecendo seus recursos", "text": "Primeiro, temos o Bloqueio. Ele determina quanto dano você consegue reduzir ao se defender de um ataque.", "target_node": "InfoBlock", "auto_advance": false, "require_action": ""},
	{"title": "Conhecendo seus recursos", "text": "O Bacamarte mostra sua munição. Algumas técnicas gastam munição, então fique de olho para não ficar sem balas na hora errada.", "target_node": "AmmoRow", "auto_advance": false, "require_action": ""},
	{"title": "Conhecendo seus recursos", "text": "A Malandragem representa sua capacidade de se virar na situação e tirar vantagem dela. Algumas técnicas gastam esse recurso, então use-o com inteligência.", "target_node": "MalRow", "auto_advance": false, "require_action": ""},
	{"title": "Conhecendo seus recursos", "text": "Por último, temos as Ações. Repare nas duas bolinhas: elas representam as duas ações que você pode realizar durante o seu turno.", "target_node": "ApRow", "auto_advance": false, "require_action": ""},
	{"title": "Atacando o inimigo", "text": "Vamos começar pelo básico: Atacar.\nClique nessa ação e confirme com a barra de espaço.", "target_node": "AtacarButton", "auto_advance": true, "require_action": "attack"},
	{"title": "Atacando o inimigo", "text": "Muito bem! Você acabou de realizar seu primeiro ataque. Mas nem sempre partir para cima é a melhor opção...", "target_node": "EnemySprite", "auto_advance": false, "require_action": ""},
	{"title": "Defendendo-se", "text": "Agora, vamos testar a Defesa. Selecione essa ação e confirme.", "target_node": "DefenderButton", "auto_advance": true, "require_action": "defend"},
	{"title": "Defendendo-se", "text": "Ao se defender, você aumenta seu Bloqueio e ganha Malandragem.\nSaber se defender pode ser tão importante quanto atacar.", "target_node": "InfoBlock", "auto_advance": false, "require_action": ""},
	{"title": "Usando itens", "text": "Se estiver ferido, selecione Item e escolha a Garrafa de Ervas.", "target_node": "ItemButton", "auto_advance": true, "require_action": "use_item"},
	{"title": "Usando itens", "text": "Pronto! Só não se esqueça de que usar um item consome uma ação.", "target_node": "InfoHp", "auto_advance": false, "require_action": ""},
	{"title": "Usando técnicas", "text": "As Técnicas realizam ações especial. Selecione Tiro de Bacamarte.", "target_node": "TecnicaButton", "auto_advance": true, "require_action": "technique"},
	{"title": "Usando técnicas", "text": "Um belo disparo! Só não se esqueça de conferir sua munição antes de puxar o gatilho.", "target_node": "AmmoRow", "auto_advance": false, "require_action": ""},
	{"title": "Hora de lutar!", "text": "Muito bem, agora você já conhece o básico. O resto é com você!", "target_node": "", "auto_advance": false, "is_final": true}
]


func _ready() -> void:
	next_button.pressed.connect(_on_next_pressed)
	_setup_balloon_style()


## Garante que o painel tenha o fundo marrom escuro e a borda dourada via código
func _setup_balloon_style() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.18, 0.11, 0.08, 0.95) # Marrom escuro tipo couro/madeira
	style.border_color = Color(0.85, 0.68, 0.35, 1.0) # Dourado
	style.set_border_width_all(3)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(16)
	
	balloon_panel.add_theme_stylebox_override("panel", style)


func start_tutorial(combat_scene: Node) -> void:
	combat_ref = combat_scene
	current_step = 0
	show()
	_show_step(current_step)


func _show_step(index: int) -> void:
	if index >= steps.size():
		_finish_tutorial()
		return

	var step_data: Dictionary = steps[index]
	title_label.text = step_data["title"]
	body_label.text = step_data["text"]

	# Adapta o texto do botão de acordo com a ação necessária
	var required: String = step_data.get("require_action", "")
	if required == "attack":
		next_button.text = "Atacar!"
	elif required == "defend":
		next_button.text = "Defender!"
	elif required != "":
		next_button.text = "Usar!"
	else:
		next_button.text = "Entendi" if step_data.get("is_final", false) else "Avançar"

	next_button.show()

	var target_name: String = step_data["target_node"]
	if target_name != "" and combat_ref != null:
		var target_control = combat_ref.find_child(target_name, true, false)
		if target_control != null:
			_highlight_node(target_control)
		else:
			highlight_rect.hide()
	else:
		highlight_rect.hide()


func _highlight_node(target: CanvasItem) -> void:
	highlight_rect.show()

	var rect: Rect2
	if target is Control:
		rect = target.get_global_rect()
	elif target is Node2D:
		var pos = target.global_position
		var fit: float = target.scale.x if "scale" in target else 1.0
		
		# Ajustado para envolver perfeitamente o personagem desde os pés até o chapéu/cabeça
		var width := 160.0 * fit
		var height := 270.0 * fit
		
		rect = Rect2(
			pos.x - (width * 0.5),
			pos.y - height,
			width,
			height
		)

	# Aplica a posição do retângulo com uma margem de folga
	highlight_rect.global_position = rect.position - Vector2(8, 8)
	highlight_rect.size = rect.size + Vector2(16, 16)

	var screen_size = get_viewport_rect().size

	# Configura a largura horizontal larga do balão
	balloon_panel.custom_minimum_size = Vector2(520, 0)
	title_label.custom_minimum_size = Vector2(480, 0)
	body_label.custom_minimum_size = Vector2(480, 0)
	balloon_panel.reset_size()

	# Posiciona o balão no topo superior centralizado da tela para não cobrir ninguém
	var balloon_pos = Vector2(
		(screen_size.x - 520.0) * 0.5, # Centralizado horizontalmente
		35.0 # Fica fixo no topo superior com margem agradável
	)

	balloon_panel.global_position = balloon_pos


func advance_if_action_matches(action_name: String) -> void:
	if current_step >= steps.size():
		return
	var required = steps[current_step].get("require_action", "")
	if required != "" and required == action_name:
		_next_step()


func _on_next_pressed() -> void:
	if current_step >= steps.size():
		_finish_tutorial()
		return

	var step_data: Dictionary = steps[current_step]
	var required_action: String = step_data.get("require_action", "")

	# Se a etapa exigir uma ação (ex: "attack", "defend"), executa no combate e avança
	if required_action != "" and combat_ref != null:
		var step_before := current_step
		_execute_tutorial_action(required_action)

		# A própria ação já avança o tutorial (advance_if_action_matches); só avançamos
		# aqui se isso não aconteceu, senão o passo seguinte seria pulado.
		if current_step != step_before:
			return

		# Se não é a vez do jogador, espera a vez dele em vez de pular a etapa.
		if combat_ref.get("_state") != 0: # State.PLAYER_TURN
			return

		_next_step()
		return

	if step_data.get("is_final", false):
		_finish_tutorial()
	else:
		_next_step()


func _execute_tutorial_action(action_name: String) -> void:
	if combat_ref == null:
		return
		
	match action_name:
		"attack":
			if combat_ref.has_method("_on_command_pressed"):
				combat_ref._on_command_pressed(0) # Comando Atacar
				if combat_ref.get("_menu_mode") == 2: # MenuMode.TARGETING
					combat_ref._confirm_target()
		"defend":
			if combat_ref.has_method("_on_command_pressed"):
				combat_ref._on_command_pressed(3) # Comando Defender
		"use_item":
			var item_path := "res://data/items/garrafada_de_ervas.tres"
			var item_skill = load(item_path) as SkillData
			if item_skill != null and combat_ref.has_method("_perform_skill"):
				# Se o HP estiver cheio (100/100), reduz 15 de HP temporariamente
				# para permitir que o efeito de cura (+30) seja aplicado e mostrado na tela
				if combat_ref._player.hp >= combat_ref._player.max_hp:
					combat_ref._player.hp = maxi(combat_ref._player.hp - 15, 1)
					combat_ref._refresh_hud()
				
				combat_ref._perform_skill(item_skill)
		"technique":
			var tech_path := "res://data/skills/tiro_de_bacamarte.tres"
			var tech_skill = load(tech_path) as SkillData
			if tech_skill != null and combat_ref.has_method("_perform_skill"):
				combat_ref._perform_skill(tech_skill)
				if combat_ref.get("_menu_mode") == 2:
					combat_ref._confirm_target()


func _next_step() -> void:
	current_step += 1
	_show_step(current_step)


func _finish_tutorial() -> void:
	hide()
	GameState.is_tutorial = false
	
	if combat_ref and combat_ref.has_method("on_tutorial_finished"):
		combat_ref.on_tutorial_finished()
