extends CharacterBody2D
class_name Bus

## Emitted when the bus collides with a chase target
signal encounter_initiated(attacker: Node2D, defender: Node2D)
## Emitted when chase starts
signal chase_started()

@onready var agent: NavigationAgent2D = $NavigationAgent2D
@export var move_speed := 200.0
var charactersheet: CharacterSheet
var _is_paused: bool = false
var inventory: Dictionary = {}
var money: int = 1000
@export var max_unique_stacks: int = 16
@export var max_stack_size: int = 100
var _health_visual: Control
var _chase_target: Node2D = null
const ENCOUNTER_DISTANCE: float = 60.0
## Checks if a specific amount of an item can be added without exceeding limits.
func can_add_item(item_id: StringName, amount: int) -> bool:
	if amount <= 0:
		return true # Adding zero or negative is always "possible" logically

	var current_amount: int = inventory.get(item_id, 0)
	var is_new_stack: bool = not inventory.has(item_id) or current_amount == 0

	# Check 1: Max stack size for this specific item
	if current_amount + amount > max_stack_size:
		print("Cannot add %d %s: Exceeds max stack size (%d)." % [amount, item_id, max_stack_size])
		return false

	# Check 2: Max unique stacks if this is a new item type
	if is_new_stack and inventory.size() >= max_unique_stacks:
		print("Cannot add %s: Exceeds max unique stacks (%d)." % [item_id, max_unique_stacks])
		return false

	# If checks pass, it's possible to add
	return true


## Adds a specified amount of an item to the inventory, respecting limits.
## Returns true if successful, false otherwise.
func add_item(item_id: StringName, amount: int) -> bool:
	if amount <= 0:
		push_warning("add_item: Cannot add zero or negative amount.")
		return false # Or true? Depends on desired behavior for zero/negative.

	if can_add_item(item_id, amount):
		inventory[item_id] = inventory.get(item_id, 0) + amount
		print("Added %d %s. New total: %d" % [amount, item_id, inventory[item_id]])
		# TODO: Emit a signal if UI needs to update inventory display
		# inventory_changed.emit()
		return true
	else:
		# can_add_item already printed the reason
		return false


## Removes a specified amount of an item from the inventory.
## Returns true if successful, false otherwise (e.g., not enough items).
func remove_item(item_id: StringName, amount: int) -> bool:
	if amount <= 0:
		push_warning("remove_item: Cannot remove zero or negative amount.")
		return false

	var current_amount: int = inventory.get(item_id, 0)

	if current_amount < amount:
		print("Cannot remove %d %s: Only have %d." % [amount, item_id, current_amount])
		return false
	else:
		inventory[item_id] = current_amount - amount
		print("Removed %d %s. Remaining: %d" % [amount, item_id, inventory[item_id]])
		# Remove the key if the amount becomes zero (optional, keeps inventory clean)
		if inventory[item_id] == 0:
			inventory.erase(item_id)
		# TODO: Emit a signal if UI needs to update inventory display
		# inventory_changed.emit()
		return true   
 
func _ready() -> void:
	charactersheet = CharacterSheet.new()
	charactersheet.initialize_health()

	# Create and add health visual
	var health_visual_scene: PackedScene = preload("res://UI/ActorHealthVisual.tscn")
	_health_visual = health_visual_scene.instantiate() as Control
	if _health_visual != null:
		add_child(_health_visual)
		_health_visual.position = Vector2(-18, -35)
		charactersheet.health_changed.connect(_on_health_changed)
		_on_health_changed(charactersheet.current_health, charactersheet.get_effective_health())

	# Connect to Timekeeper pause/resume signals
	var timekeeper: Node = get_node_or_null("/root/Timekeeper")
	if timekeeper != null:
		if timekeeper.has_signal("paused"):
			timekeeper.paused.connect(_on_timekeeper_paused)
		if timekeeper.has_signal("resumed"):
			timekeeper.resumed.connect(_on_timekeeper_resumed)

func _physics_process(_delta: float) -> void:
	# Don't move if paused
	if _is_paused:
		velocity = Vector2.ZERO
		return

	# Check if we've reached the chase target
	if _chase_target != null:
		var distance_to_target: float = global_position.distance_to(_chase_target.global_position)
		if distance_to_target <= ENCOUNTER_DISTANCE:
			var target: Node2D = _chase_target
			_chase_target = null
			velocity = Vector2.ZERO
			print("[Bus] Encounter triggered! Distance: %.1f" % distance_to_target)
			encounter_initiated.emit(self, target)
			return

		# Update navigation target if chasing
		if agent != null:
			agent.target_position = _chase_target.global_position

	if agent:
		var next := agent.get_next_path_position()
		var to_next := next - global_position
		if to_next.length() > 1.0:
			velocity = to_next.normalized() * move_speed
		else:
			velocity = Vector2.ZERO
	else:
		velocity = Vector2.ZERO

	move_and_slide()

func _on_timekeeper_paused() -> void:
	_is_paused = true

func _on_timekeeper_resumed() -> void:
	_is_paused = false

func _on_health_changed(new_health: int, max_health: int) -> void:
	if _health_visual != null:
		_health_visual.update_health(new_health, max_health)

## Initiates chase of a target node
func chase_target(target: Node2D) -> void:
	_chase_target = target
	chase_started.emit()

## Returns the current chase target, or null if not chasing
func get_chase_target() -> Node2D:
	return _chase_target
