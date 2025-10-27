extends Control
class_name EncounterUI

## Emitted when combat concludes (win, loss, or retreat)
signal combat_ended(attacker: Node2D, defender: Node2D, winner: Node2D)
## Emitted when exit button is pressed
signal exit_pressed()

@onready var combat_label: Label = $Panel/VBoxContainer/CombatLabel
@onready var attack_button: Button = $Panel/VBoxContainer/AttackButton
@onready var exit_button: Button = $Panel/VBoxContainer/ExitButton

var _attacker: Node2D = null
var _defender: Node2D = null

func _ready() -> void:
	hide()
	if attack_button != null:
		attack_button.pressed.connect(_on_attack_pressed)
	if exit_button != null:
		exit_button.pressed.connect(_on_exit_pressed)

## Opens the encounter UI for manual combat
func open_encounter(attacker: Node2D, defender: Node2D) -> void:
	_attacker = attacker
	_defender = defender

	# Reset UI state for new encounter
	if attack_button != null:
		attack_button.disabled = false
	if combat_label != null:
		combat_label.text = "Encounter!"

	visible = true
	modulate = Color.WHITE
	z_index = 100

	var timekeeper: Node = get_node_or_null("/root/Timekeeper")
	if timekeeper != null and timekeeper.has_method("pause"):
		timekeeper.pause()

## Closes the encounter UI
func close_ui() -> void:
	hide()

	var timekeeper: Node = get_node_or_null("/root/Timekeeper")
	if timekeeper != null and timekeeper.has_method("resume"):
		timekeeper.resume()

func _on_attack_pressed() -> void:
	if _attacker == null or _defender == null:
		return

	# Disable button to prevent spam clicks
	attack_button.disabled = true

	# Resolve one combat round
	var combat_manager: Node = get_node_or_null("/root/CombatManager")
	if combat_manager != null and combat_manager.has_method("resolve_combat_round"):
		combat_manager.resolve_combat_round(_attacker, _defender)

	# Check if combat is over
	var attacker_sheet: CharacterSheet = _attacker.get("charactersheet")
	var defender_sheet: CharacterSheet = _defender.get("charactersheet")

	if attacker_sheet == null or defender_sheet == null:
		attack_button.disabled = false
		return

	# Update combat feedback
	combat_label.text = "Combat! HP: You %d/%d | Enemy %d/%d" % [
		attacker_sheet.current_health,
		attacker_sheet.get_effective_health(),
		defender_sheet.current_health,
		defender_sheet.get_effective_health()
	]

	if attacker_sheet.current_health <= 0:
		combat_ended.emit(_attacker, _defender, _defender)
		close_ui()
	elif defender_sheet.current_health <= 0:
		combat_ended.emit(_attacker, _defender, _attacker)
		close_ui()
	else:
		# Re-enable button for next round
		attack_button.disabled = false

func _on_exit_pressed() -> void:
	exit_pressed.emit()
	close_ui()
