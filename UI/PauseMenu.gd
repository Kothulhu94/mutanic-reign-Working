# PauseMenu.gd
extends CanvasLayer

@onready var resume_button: Button = %ResumeButton # Use %UniqueName syntax if you set it up
@onready var character_sheet_button: Button = %CharacterSheetButton # Or use get_node("path/to/button")
@export var character_sheet_scene: PackedScene
var character_sheet_instance: Control = null# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	print("=== PauseMenu Debug Info ===")
	print("PauseMenu _ready() called - PauseMenu is active")
	print("PauseMenu process_mode: ", process_mode)
	print("'pause' action exists in InputMap: ", InputMap.has_action("pause"))
	if InputMap.has_action("pause"):
		var events = InputMap.action_get_events("pause")
		print("'pause' action has ", events.size(), " event(s)")
		for event in events:
			if event is InputEventKey:
				print("  - Key event: keycode=", event.keycode, " physical=", event.physical_keycode)
	print("============================")

	# Don't hide the CanvasLayer - instead hide the ColorRect child
	# CanvasLayers need to stay visible to receive input
	$ColorRect.hide()
	# Connect button signals
	resume_button.pressed.connect(_on_resume_pressed)
	character_sheet_button.pressed.connect(_on_character_sheet_pressed)
	print("PauseMenu buttons connected successfully")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	# Use Input polling instead of _input() event handling
	# This is more reliable for autoloaded CanvasLayers
	if Input.is_action_just_pressed("pause"):
		print("Pause action detected via Input polling!")
		if get_tree().paused:
			_resume_game()
		else:
			_pause_game()


func _pause_game() -> void:
	# Pause the scene tree
	get_tree().paused = true
	# Show the pause menu (show the ColorRect, not the CanvasLayer)
	$ColorRect.show()


func _resume_game() -> void:
	# Resume the scene tree
	get_tree().paused = false
	# Hide the pause menu (hide the ColorRect, not the CanvasLayer)
	$ColorRect.hide()
	# Hide the Character Sheet UI if it's open
	if character_sheet_instance != null:
		character_sheet_instance.hide()


func _on_resume_pressed() -> void:
	_resume_game()


func _on_character_sheet_pressed() -> void:
	# Find the player in the scene
	var player: Node = get_tree().get_first_node_in_group("player")
	if player == null:
		push_error("PauseMenu: No player found in 'player' group")
		return

	# Get the player's character sheet (Godot 4 uses "property" in player instead of has())
	if not "charactersheet" in player:
		push_error("PauseMenu: Player does not have a 'charactersheet' property")
		return

	var character_sheet: CharacterSheet = player.charactersheet
	if character_sheet == null:
		push_error("PauseMenu: Player's charactersheet is null")
		return

	# Instantiate the character sheet UI if needed
	if character_sheet_instance == null and character_sheet_scene:
		character_sheet_instance = character_sheet_scene.instantiate()
		add_child(character_sheet_instance)

	# Display the character sheet
	if character_sheet_instance != null and character_sheet_instance.has_method("display_sheet"):
		character_sheet_instance.display_sheet(character_sheet)
