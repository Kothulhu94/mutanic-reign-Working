# res://Actors/Caravan.gd
# Godot 4.5 — Caravan Trading AI
# Spawns when home hub has surplus (200+ items over need)
# Buys preferred items at home, travels to other hubs to sell for profit
# Returns home to pay 10% tax and restock if surplus exists
extends Area2D
class_name Caravan

## Emitted when player clicks on this caravan to initiate chase
signal player_initiated_chase(caravan_actor: Caravan)

# Core state
var caravan_state: CaravanState = null
var home_hub: Hub = null
var current_target_hub: Hub = null
var _is_paused: bool = false

## Computed property for combat system compatibility
var charactersheet: CharacterSheet:
	get:
		if caravan_state != null:
			return caravan_state.leader_sheet
		return null

# Health visual
var _health_visual: Control

# Skill-based bonuses (calculated once at setup)
var _price_modifier_bonus: float = 0.0  # From NegotiationTactics skill
var _speed_bonus: float = 0.0           # From CaravanLogistics skill
var _capacity_bonus: float = 0.0        # From CaravanLogistics skill

# AI State machine
enum State {
	IDLE,              # Waiting at home hub
	BUYING_AT_HOME,    # Purchasing goods from home hub
	TRAVELING,         # Moving to destination
	EVALUATING_TRADE,  # At destination, checking prices
	SELLING,           # Selling goods at destination
	SEEKING_NEXT_HUB,  # Looking for another profitable hub
	RETURNING_HOME     # Going back to home hub
}
var current_state: State = State.IDLE

# Configuration (set from EconomyConfig)
@export var surplus_threshold: float = 200.0  # Items over need to trigger spawn
@export var home_tax_rate: float = 0.1        # 10% of carried money goes to hub

# Navigation
@export var movement_speed: float = 100.0
var nav_agent: NavigationAgent2D = null

# References
var item_db: ItemDB = null
var all_hubs: Array[Hub] = []
var visited_hubs: Array[Hub] = []

# Trade tracking
var purchase_prices: Dictionary = {}  # item_id -> price paid per unit

func _ready() -> void:
	add_to_group("caravans")

	# Get NavigationAgent2D reference
	nav_agent = get_node_or_null("NavigationAgent2D") as NavigationAgent2D

	# Connect input event signal for clicking
	input_event.connect(_on_input_event)

	# Connect to Timekeeper pause/resume signals
	var timekeeper: Node = get_node_or_null("/root/Timekeeper")
	if timekeeper != null:
		if timekeeper.has_signal("paused"):
			timekeeper.paused.connect(_on_timekeeper_paused)
		if timekeeper.has_signal("resumed"):
			timekeeper.resumed.connect(_on_timekeeper_resumed)

func setup(home: Hub, state: CaravanState, db: ItemDB, hubs: Array[Hub]) -> void:
	home_hub = home
	caravan_state = state
	item_db = db
	all_hubs = hubs

	# Initialize health for combat
	if caravan_state != null and caravan_state.leader_sheet != null:
		caravan_state.leader_sheet.initialize_health()

		# Set up health visual
		var health_visual_scene: PackedScene = preload("res://UI/ActorHealthVisual.tscn")
		_health_visual = health_visual_scene.instantiate() as Control
		if _health_visual != null:
			add_child(_health_visual)
			_health_visual.position = Vector2(-18, -35)
			caravan_state.leader_sheet.health_changed.connect(_on_health_changed)
			_on_health_changed(caravan_state.leader_sheet.current_health, caravan_state.leader_sheet.get_effective_health())

		# Apply skill bonuses if leader has skills
		_apply_skill_bonuses()

	# Configure navigation from CaravanType
	if caravan_state.caravan_type != null:
		movement_speed *= caravan_state.caravan_type.speed_modifier

		# Configure NavigationAgent2D from CaravanType
		if nav_agent != null:
			nav_agent.max_speed = movement_speed
			nav_agent.navigation_layers = caravan_state.caravan_type.navigation_layers

	# Position at home hub
	global_position = home.global_position

	# Start the AI
	_transition_to(State.BUYING_AT_HOME)

func _process(delta: float) -> void:
	# Don't process AI if paused
	if _is_paused:
		return

	match current_state:
		State.IDLE:
			_state_idle()
		State.BUYING_AT_HOME:
			_state_buying_at_home()
		State.TRAVELING:
			_state_traveling(delta)
		State.EVALUATING_TRADE:
			_state_evaluating_trade()
		State.SELLING:
			_state_selling()
		State.SEEKING_NEXT_HUB:
			_state_seeking_next_hub()
		State.RETURNING_HOME:
			_state_returning_home(delta)

# ============================================================
# State Machine
# ============================================================
func _transition_to(new_state: State) -> void:
	current_state = new_state
	match new_state:
		State.TRAVELING:
			_start_navigation_to(current_target_hub)
		State.RETURNING_HOME:
			_start_navigation_to(home_hub)

func _state_idle() -> void:
	# Check if home hub has surplus to trigger another trade run
	if _home_has_surplus_of_preferred_items():
		_transition_to(State.BUYING_AT_HOME)

func _state_buying_at_home() -> void:
	# Spend all money on preferred items with surplus
	var items_to_buy: Dictionary = _get_preferred_items_with_surplus(home_hub)

	var _total_bought: int = 0  # Track total items bought (reserved for future use)
	for item_id: StringName in items_to_buy.keys():
		var available: int = items_to_buy[item_id]
		var price: float = home_hub.get_item_price(item_id)
		var max_affordable: int = int(floor(float(caravan_state.money) / price))
		var amount_to_buy: int = mini(available, max_affordable)
		amount_to_buy = mini(amount_to_buy, caravan_state.get_max_capacity() - caravan_state.get_total_cargo_weight())

		if amount_to_buy > 0:
			var total_cost: int = int(ceil(price * float(amount_to_buy)))
			if home_hub.buy_from_hub(item_id, amount_to_buy, caravan_state):
				caravan_state.money -= total_cost
				caravan_state.add_item(item_id, amount_to_buy)
				purchase_prices[item_id] = price
				_total_bought += amount_to_buy

	# Find a destination hub
	if caravan_state.inventory.size() > 0:
		_find_next_destination()
		if current_target_hub != null:
			_transition_to(State.TRAVELING)
		else:
			# No destination found, return to idle
			_transition_to(State.IDLE)
	else:
		# Couldn't buy anything
		_transition_to(State.IDLE)

func _state_traveling(delta: float) -> void:
	if nav_agent == null:
		return

	# Check if we've reached the destination
	if nav_agent.is_navigation_finished():
		if current_target_hub != null:
			_transition_to(State.EVALUATING_TRADE)
		return

	# Move toward next path position
	var next_position: Vector2 = nav_agent.get_next_path_position()
	var direction: Vector2 = (next_position - global_position).normalized()
	global_position += direction * movement_speed * delta

func _state_evaluating_trade() -> void:
	# Check prices at current hub and decide whether to sell
	var has_profitable_items: bool = false

	for item_id: StringName in caravan_state.inventory.keys():
		var purchase_price: float = purchase_prices.get(item_id, 0.0)
		var base_sell_price: float = current_target_hub.get_item_price(item_id)

		# Apply skill bonus: better negotiation = higher effective sell price
		var price_modifier: float = 1.0 - _price_modifier_bonus
		var sell_price: float = base_sell_price / price_modifier

		if sell_price > purchase_price:
			has_profitable_items = true
			break

	if has_profitable_items:
		_transition_to(State.SELLING)
	else:
		# No profit here, look for another hub
		_transition_to(State.SEEKING_NEXT_HUB)

func _state_selling() -> void:
	# Sell all profitable items
	var items_to_sell: Array[StringName] = []

	# Build list first to avoid modifying dictionary during iteration
	for item_id: StringName in caravan_state.inventory.keys():
		items_to_sell.append(item_id)

	for item_id: StringName in items_to_sell:
		var purchase_price: float = purchase_prices.get(item_id, 0.0)
		var base_sell_price: float = current_target_hub.get_item_price(item_id)

		# Apply skill bonus: better negotiation = higher effective sell price
		var price_modifier: float = 1.0 - _price_modifier_bonus
		var sell_price: float = base_sell_price / price_modifier

		if sell_price > purchase_price:
			var amount: int = caravan_state.inventory.get(item_id, 0)
			if amount > 0:
				var revenue: int = int(floor(sell_price * float(amount)))
				if current_target_hub.sell_to_hub(item_id, amount, caravan_state):
					caravan_state.money += revenue
					caravan_state.profit_this_trip += revenue - int(purchase_price * float(amount))
					caravan_state.remove_item(item_id, amount)

	# Mark this hub as visited
	if not visited_hubs.has(current_target_hub):
		visited_hubs.append(current_target_hub)

	# Check if we still have inventory
	if caravan_state.inventory.size() > 0:
		_transition_to(State.SEEKING_NEXT_HUB)
	else:
		# All sold, return home
		_transition_to(State.RETURNING_HOME)

func _state_seeking_next_hub() -> void:
	# Try to find another hub to sell remaining goods
	_find_next_destination()

	if current_target_hub != null and current_target_hub != home_hub:
		_transition_to(State.TRAVELING)
	else:
		# No more hubs or only home hub left, return home
		_transition_to(State.RETURNING_HOME)

func _state_returning_home(delta: float) -> void:
	if nav_agent == null:
		return

	# Check if we've reached home
	if nav_agent.is_navigation_finished():
		_arrive_at_home()
		return

	# Move toward next path position
	var next_position: Vector2 = nav_agent.get_next_path_position()
	var direction: Vector2 = (next_position - global_position).normalized()
	global_position += direction * movement_speed * delta

# ============================================================
# AI Helpers
# ============================================================
func _home_has_surplus_of_preferred_items() -> bool:
	if home_hub == null or caravan_state == null or caravan_state.caravan_type == null:
		return false

	var items: Dictionary = _get_preferred_items_with_surplus(home_hub)
	return items.size() > 0

func _get_preferred_items_with_surplus(hub: Hub) -> Dictionary:
	var result: Dictionary = {}

	if hub == null or item_db == null or caravan_state == null or caravan_state.caravan_type == null:
		return result

	var preferred_tags: Array[StringName] = caravan_state.caravan_type.preferred_tags
	if preferred_tags.is_empty():
		return result

	for item_id: StringName in hub.state.inventory.keys():
		var stock: int = hub.state.inventory.get(item_id, 0)
		if stock <= 0:
			continue

		# Check if item has any preferred tag
		var has_preferred_tag: bool = false
		for tag: StringName in preferred_tags:
			if item_db.has_tag(item_id, tag):
				has_preferred_tag = true
				break

		if not has_preferred_tag:
			continue

		# Check if hub has surplus (stock > need + threshold)
		# For simplicity, we check if food_level or infrastructure_level is positive
		# and stock is above threshold
		var surplus: float = 0.0
		if item_db.has_tag(item_id, &"food"):
			surplus = hub.food_level
		elif item_db.has_tag(item_id, &"material"):
			surplus = hub.infrastructure_level

		# If hub has positive level and stock is above threshold, it's surplus
		if surplus > 0.0 and float(stock) > surplus_threshold:
			result[item_id] = stock - int(surplus_threshold)

	return result

func _find_next_destination() -> void:
	current_target_hub = null

	# Filter out visited hubs and home hub
	var available_hubs: Array[Hub] = []
	for hub: Hub in all_hubs:
		if hub == home_hub:
			continue
		if visited_hubs.has(hub):
			continue
		available_hubs.append(hub)

	# If no unvisited hubs remain, clear visited list and try again (allows ping-pong between 2 hubs)
	if available_hubs.is_empty():
		visited_hubs.clear()
		for hub: Hub in all_hubs:
			if hub != home_hub:
				available_hubs.append(hub)

	# Pick the first available hub
	if available_hubs.size() > 0:
		current_target_hub = available_hubs[0]

func _arrive_at_home() -> void:
	# Pay 10% tax on carried money
	if caravan_state.money > 0:
		var tax: int = int(ceil(float(caravan_state.money) * home_tax_rate))
		caravan_state.money -= tax
		home_hub.state.money += tax

	# Reset for next trip
	caravan_state.profit_this_trip = 0
	visited_hubs.clear()
	purchase_prices.clear()
	caravan_state.flip_leg()

	# Check if we can start another trade run
	_transition_to(State.IDLE)

# ============================================================
# Skill Effects Application
# ============================================================
## Apply all relevant Trading skill bonuses from leader's character sheet
func _apply_skill_bonuses() -> void:
	if caravan_state == null or caravan_state.leader_sheet == null:
		return

	var sheet: CharacterSheet = caravan_state.leader_sheet

	# Apply NegotiationTactics skill (affects trade prices)
	var negotiation_rank: int = sheet.get_skill_rank(&"negotiation_tactics")
	if negotiation_rank > 0:
		# Simplified: 1.5% better prices per rank
		# Full implementation would read base_effect_per_rank from SkillDatabase
		_price_modifier_bonus = float(negotiation_rank) * 0.015

	# Apply CaravanLogistics skill (affects speed + capacity)
	var logistics_rank: int = sheet.get_skill_rank(&"caravan_logistics")
	if logistics_rank > 0:
		# Simplified: 2.5% per rank (actual skill: 25-45% across ranks 1-10)
		var logistics_bonus: float = float(logistics_rank) * 0.025
		_speed_bonus = logistics_bonus
		_capacity_bonus = logistics_bonus

		# Apply speed bonus to movement_speed
		movement_speed *= (1.0 + _speed_bonus)

# ============================================================
# Navigation
# ============================================================
func _start_navigation_to(target_hub: Hub) -> void:
	if target_hub == null or nav_agent == null:
		return

	# Set NavigationAgent2D target (it will use the configured navigation_layers)
	nav_agent.target_position = target_hub.global_position

# ============================================================
# Public API
# ============================================================
func get_state_name() -> String:
	match current_state:
		State.IDLE: return "Idle"
		State.BUYING_AT_HOME: return "Buying"
		State.TRAVELING: return "Traveling"
		State.EVALUATING_TRADE: return "Evaluating"
		State.SELLING: return "Selling"
		State.SEEKING_NEXT_HUB: return "Seeking"
		State.RETURNING_HOME: return "Returning"
		_: return "Unknown"

# ============================================================
# Input & Health Handlers
# ============================================================
func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			player_initiated_chase.emit(self)
			get_viewport().set_input_as_handled()

func _on_health_changed(new_health: int, max_health: int) -> void:
	if _health_visual != null:
		_health_visual.update_health(new_health, max_health)

func _on_timekeeper_paused() -> void:
	_is_paused = true

func _on_timekeeper_resumed() -> void:
	_is_paused = false
