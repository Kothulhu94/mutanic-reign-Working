# Hub.gd — Godot 4.5 (engine-split + live rewire + price/consumption EMA)
extends Node2D
class_name Hub

@export var state: HubStates

# UI references
@export var hub_menu_ui: HubMenuUI = null
@export var market_ui: MarketUI = null

# Backing fields for exported props
var _item_db: ItemDB
var _economy_config: EconomyConfig

# Track if hub has been visited by player (reserved for future use)
var _has_been_visited: bool = false

# Exported properties with setters so runtime/editor changes rewire the engine
@export var item_db: ItemDB:
	set(value):
		_item_db = value
		_on_item_db_changed()
	get:
		return _item_db

@export var economy_config: EconomyConfig:
	set(value):
		_economy_config = value
		_on_economy_config_changed()
	get:
		return _economy_config

@onready var click_and_fade: Area2D = get_node_or_null("ClickAndFade") as Area2D
@onready var slots: BuildSlots      = get_node_or_null("BuildSlots") as BuildSlots

# Fractional cache (floats). state.inventory stores whole ints.
var _inventory_float: Dictionary = {}

# Signed snapshots (mirrors engine output each tick)
@export var food_level: float = 0.0              # servings: +surplus / –deficit
@export var infrastructure_level: float = 0.0    # units: +surplus / –deficit

# -------- Dynamic prices --------
@export var item_prices: Dictionary = {}         # item_id(StringName)-> price(float)
var _consumption_ema: Dictionary = {}            # item_id -> smoothed units/tick
const PRICE_ALPHA: float = 0.2                   # EMA smoothing factor (0..1)
var _last_consumed: Dictionary = {}              # from engine tick telemetry
var _last_produced: Dictionary = {}

# Economy engine
var _engine: HubEconomy = HubEconomy.new()

func _ready() -> void:
	# Ensure hub state
	if state == null:
		state = HubStates.new()
	state.ensure_slots(9)

	# Realize placed buildings from state
	if slots != null:
		slots.realize_from_state(state)
		_inject_building_dependencies()  # uses _item_db

	# Ensure per-instance config (duplicate if a .tres)
	_ensure_unique_economy_config()

	# Initial engine wiring (handles nulls gracefully)
	_refresh_engine()

	# Timekeeper wiring
	var tk: Node = get_node_or_null("/root/Timekeeper")
	if tk == null:
		push_error("Timekeeper autoload not found at /root/Timekeeper")
	elif not tk.is_connected("tick", Callable(self, "_on_timekeeper_tick")):
		tk.connect("tick", Callable(self, "_on_timekeeper_tick"))

	# Optional area signals
	if click_and_fade != null:
		if click_and_fade.has_signal("actor_entered"):
			click_and_fade.actor_entered.connect(_on_actor_entered)
		if click_and_fade.has_signal("actor_exited"):
			click_and_fade.actor_exited.connect(_on_actor_exited)
		# NOTE: Removed hub_clicked connection - UI only shows on proximity entry

	# Connect UI signals
	if hub_menu_ui != null:
		if hub_menu_ui.has_signal("menu_closed"):
			hub_menu_ui.menu_closed.connect(_on_menu_closed)
		if hub_menu_ui.has_signal("market_opened"):
			hub_menu_ui.market_opened.connect(_on_market_opened)

	if market_ui != null:
		if market_ui.has_signal("market_closed"):
			market_ui.market_closed.connect(_on_market_closed)
		if market_ui.has_signal("transaction_confirmed"):
			market_ui.transaction_confirmed.connect(_on_transaction_confirmed)

func _on_timekeeper_tick(dt: float) -> void:
	# Gather buildings list
	var buildings: Array[Node] = []
	if slots != null:
		buildings = slots.iter_buildings()

	# Compute current population cap (we assume pop == cap)
	var cap: int = _compute_population_cap_now()

	# Calculate governor bonuses
	var governor_productivity_bonus: float = 0.0  # For ProducerBuildings
	var governor_efficiency_bonus: float = 0.0    # For ProcessorBuildings

	if state.governor_id != StringName():
		var pm: Node = get_node_or_null("/root/ProgressionManager")
		if pm != null and pm.has_method("get_character_sheet"):
			var governor_sheet: CharacterSheet = pm.get_character_sheet(state.governor_id)
			if governor_sheet != null:
				# QualityTools skill boosts producer output
				var quality_rank: int = governor_sheet.get_skill_rank(&"quality_tools")
				if quality_rank > 0:
					# Simplified: 2% per rank (actual: 20-40% across ranks)
					governor_productivity_bonus = float(quality_rank) * 0.02

				# IndustrialPlanning skill boosts processor efficiency
				var planning_rank: int = governor_sheet.get_skill_rank(&"industrial_planning")
				if planning_rank > 0:
					# Simplified: 3% per rank (actual: 30-60% across ranks)
					governor_efficiency_bonus = float(planning_rank) * 0.03

	# Run one economy tick via engine (pass bonuses)
	var r: Dictionary = _engine.tick(dt, cap, state.inventory, _inventory_float, buildings, governor_productivity_bonus, governor_efficiency_bonus)

	# Apply inventory delta (production, processing, consumption)
	var delta: Dictionary = (r.get("delta", {}) as Dictionary)
	if delta.size() > 0:
		_apply_inventory_delta(delta)

	# Mirror snapshots from engine
	food_level = float(r.get("food_level", 0.0))
	infrastructure_level = float(r.get("infrastructure_level", 0.0))

	# ---- Price pipeline: ingest telemetry -> update prices
	_last_consumed = (r.get("consumed", {}) as Dictionary)
	_last_produced = (r.get("produced", {}) as Dictionary)
	_ingest_consumption_telemetry(_last_consumed)
	_update_item_prices()

# -------------------------------------------------------------------
# Engine/config wiring
# -------------------------------------------------------------------
func _ensure_unique_economy_config() -> void:
	if _economy_config == null:
		_economy_config = EconomyConfig.new()
		return
	# If referencing a .tres on disk, duplicate so this Hub owns a private copy.
	if _economy_config.resource_path != "":
		_economy_config = _economy_config.duplicate(true)
		_economy_config.resource_name = "%s_LocalEconomy" % name

func _refresh_engine() -> void:
	# Safe to call anytime; engine will accept nulls but snapshots/consumption need DB.
	_engine.setup(_economy_config, _item_db)
	# Keep processors in sync with the DB if slots already exist.
	_inject_building_dependencies()

func _on_item_db_changed() -> void:
	_refresh_engine()  # re-setup engine + reinject processors

func _on_economy_config_changed() -> void:
	_refresh_engine()

# -------------------------------------------------------------------
# Inventory helpers
# -------------------------------------------------------------------
func _apply_inventory_delta(delta: Dictionary) -> void:
	for k in delta.keys():
		var key: StringName = (k if k is StringName else StringName(str(k)))
		var curf: float = float(_inventory_float.get(key, float(state.inventory.get(key, 0))))
		curf += float(delta[k])
		_inventory_float[key] = curf
		state.inventory[key] = int(floor(curf))

func _compute_population_cap_now() -> int:
	var cap: int = state.base_population_cap
	if slots != null:
		for n: Node in slots.iter_buildings():
			if n.has_method("get_population_cap_bonus"):
				cap += int(n.call("get_population_cap_bonus"))
	return cap

func _inject_building_dependencies() -> void:
	# Give processors access to the ItemDB for tag lookups.
	if slots == null or _item_db == null:
		return
	for n: Node in slots.iter_buildings():
		if n == null:
			continue
		if n.is_in_group("processor") or n.has_method("refine_tick"):
			n.set("item_db", _item_db)

# -------------------------------------------------------------------
# Public API
# -------------------------------------------------------------------
func place_building(slot_id: int, ps: PackedScene, s: BuildSlotState) -> Node:
	if slots == null:
		return null
	var node: Node = slots.place_building(slot_id, ps, s)
	if node != null:
		state.slots[slot_id] = s
		# Inject DB for newly placed processors
		if _item_db != null and (node.is_in_group("processor") or node.has_method("refine_tick")):
			node.set("item_db", _item_db)
	return node

func clear_building(slot_id: int) -> void:
	if slots == null:
		return
	slots.clear_slot(slot_id)
	state.slots[slot_id] = null

# -------------------------------------------------------------------
# Trading API (used by caravans)
# -------------------------------------------------------------------
func get_item_price(item_id: StringName) -> float:
	# Return current dynamic price, or calculate on-demand if not tracked
	if item_prices.has(item_id):
		return float(item_prices[item_id])
	# Calculate price on the fly if item exists but not tracked yet
	var stock: float = _current_amount(item_id)
	var rate: float = _estimate_consumption_rate(item_id)
	return _calculate_item_price(item_id, stock, rate)

func buy_from_hub(item_id: StringName, amount: int, _caravan_state: CaravanState) -> bool:
	# Caravan buys from hub (hub loses inventory, caravan gains)
	var available: int = state.inventory.get(item_id, 0)
	if available < amount:
		return false

	# Remove from hub inventory
	var cur_float: float = float(_inventory_float.get(item_id, float(state.inventory.get(item_id, 0))))
	cur_float -= float(amount)
	_inventory_float[item_id] = cur_float
	state.inventory[item_id] = int(floor(cur_float))
	if state.inventory[item_id] <= 0:
		state.inventory.erase(item_id)

	# Update telemetry: buying from hub counts as consumption (demand)
	_last_consumed[item_id] = _last_consumed.get(item_id, 0.0) + float(amount)
	_ingest_consumption_telemetry({item_id: float(amount)})

	return true

func sell_to_hub(item_id: StringName, amount: int, _caravan_state: CaravanState) -> bool:
	# Caravan sells to hub (hub gains inventory, caravan loses)

	# Add to hub inventory
	var delta: Dictionary = {item_id: amount}
	_apply_inventory_delta(delta)

	# Update telemetry: selling to hub counts as production (supply)
	_last_produced[item_id] = _last_produced.get(item_id, 0.0) + float(amount)

	return true

# -------------------------------------------------------------------
# Area callbacks (optional)
# -------------------------------------------------------------------
func _on_actor_entered(actor: Node) -> void:
	# Show hub menu when Bus enters proximity area
	if _is_bus(actor):
		_show_hub_menu()

func _on_actor_exited(_actor: Node) -> void:
	pass

func _on_hub_clicked() -> void:
	# Disabled: Hub UI now only shows when bus enters proximity area
	pass

# -------------------------------------------------------------------
# UI Management
# -------------------------------------------------------------------
func _is_bus(node: Node) -> bool:
	if node == null:
		return false
	return node.get_scene_file_path() == "res://Actors/Bus.tscn"

func _show_hub_menu() -> void:
	if hub_menu_ui == null:
		push_warning("Hub %s has no HubMenuUI assigned" % name)
		return

	hub_menu_ui.open_menu(self)

func _on_menu_closed() -> void:
	# Only respond if this hub was the one that opened the menu
	if hub_menu_ui != null and hub_menu_ui.current_hub == self:
		# Menu closed, game resumed automatically by HubMenuUI
		pass

func _on_market_opened() -> void:
	# Only respond if this hub was the one that opened the menu
	if hub_menu_ui == null or hub_menu_ui.current_hub != self:
		return

	if market_ui == null:
		push_warning("Hub %s has no MarketUI assigned" % name)
		return

	# Get bus reference from the overworld scene
	var bus_ref: Bus = _get_bus_from_scene_tree()
	if bus_ref == null:
		push_warning("Hub %s cannot find Bus in scene tree" % name)
		return

	market_ui.open(bus_ref, self)

func _on_market_closed() -> void:
	# Only respond if this hub was the one that opened the market
	if market_ui != null and market_ui.current_hub == self:
		# Market closed, game resumed automatically by MarketUI
		pass

func _get_bus_from_scene_tree() -> Bus:
	var root: Window = get_tree().root
	if root == null:
		return null

	var overworld: Node = root.get_node_or_null("Overworld")
	if overworld == null:
		return null

	var bus_node: Node = overworld.get("bus")
	if bus_node != null and bus_node is Bus:
		return bus_node as Bus

	return null

func _on_transaction_confirmed(cart: Array[Dictionary]) -> void:
	var bus_ref: Bus = _get_bus_from_scene_tree()
	if bus_ref == null:
		push_error("Hub %s: Cannot process transaction - Bus not found" % name)
		return

	for entry: Dictionary in cart:
		var item_id: StringName = entry.get("item_id", StringName())
		var buy_qty: int = int(entry.get("buy_qty", 0))
		var sell_qty: int = int(entry.get("sell_qty", 0))
		var unit_price: float = float(entry.get("unit_price", 0.0))

		if buy_qty > 0:
			var cost: int = int(ceil(float(buy_qty) * unit_price))

			if bus_ref.money < cost:
				push_warning("Hub %s: Player cannot afford to buy %d %s" % [name, buy_qty, item_id])
				continue

			if state.inventory.get(item_id, 0) < buy_qty:
				push_warning("Hub %s: Not enough %s in hub inventory" % [name, item_id])
				continue

			var cur_float: float = float(_inventory_float.get(item_id, float(state.inventory.get(item_id, 0))))
			cur_float -= float(buy_qty)
			_inventory_float[item_id] = cur_float
			state.inventory[item_id] = int(floor(cur_float))
			if state.inventory[item_id] <= 0:
				state.inventory.erase(item_id)

			if not bus_ref.add_item(item_id, buy_qty):
				push_warning("Hub %s: Failed to add %d %s to player inventory" % [name, buy_qty, item_id])
				continue

			bus_ref.money -= cost
			state.money += cost

		if sell_qty > 0:
			var revenue: int = int(floor(float(sell_qty) * unit_price))

			if bus_ref.inventory.get(item_id, 0) < sell_qty:
				push_warning("Hub %s: Player doesn't have %d %s to sell" % [name, sell_qty, item_id])
				continue

			if not bus_ref.remove_item(item_id, sell_qty):
				push_warning("Hub %s: Failed to remove %d %s from player inventory" % [name, sell_qty, item_id])
				continue

			var delta: Dictionary = {item_id: sell_qty}
			_apply_inventory_delta(delta)

			bus_ref.money += revenue
			state.money -= revenue

# -------------------------------------------------------------------
# Pricing helpers (EMA-based consumption -> dynamic prices)
# -------------------------------------------------------------------
func _ingest_consumption_telemetry(consumed: Dictionary) -> void:
	for k in consumed.keys():
		var id: StringName = (k if k is StringName else StringName(str(k)))
		var inst: float = float(consumed[k])  # positive magnitude (units eaten this tick)
		var prev: float = float(_consumption_ema.get(id, 0.0))
		_consumption_ema[id] = lerp(prev, inst, PRICE_ALPHA)

func _estimate_consumption_rate(item_id: StringName) -> float:
	return float(_consumption_ema.get(item_id, 0.0))

func _current_amount(item_id: StringName) -> float:
	return InventoryUtil.read_amount(item_id, state.inventory, _inventory_float)

func _get_tracked_items() -> Array[StringName]:
	var keys: Array[StringName] = InventoryUtil.union_keys(state.inventory, _inventory_float)
	for k in _last_consumed.keys():
		var id: StringName = (k if k is StringName else StringName(str(k)))
		if not keys.has(id):
			keys.append(id)
	for k in _last_produced.keys():
		var id2: StringName = (k if k is StringName else StringName(str(k)))
		if not keys.has(id2):
			keys.append(id2)
	return keys

func _calculate_item_price(item_id: StringName, current_stock: float, consumption_rate: float) -> float:
	if _item_db == null:
		return 0.0
	var base_price: float = 1.0
	if _item_db.has_method("price_of"):
		base_price = float(_item_db.price_of(item_id))
	else:
		# Fallback: try to read ItemDef.base_price from the DB's items map
		var def = _item_db.items.get(item_id, null)
		if def != null and def.has_method("get"):
			var bp = def.get("base_price")
			if bp != null:
				base_price = float(bp)
	# Simple supply/demand: more demand or lower stock -> higher price
	var supply_factor: float = max(1.0, current_stock)
	var demand_factor: float = max(1.0, consumption_rate * 10.0)
	return base_price * (demand_factor / supply_factor)

func _update_item_prices() -> void:
	if _item_db == null:
		return
	var tracked: Array[StringName] = _get_tracked_items()
	for id in tracked:
		var stock: float = _current_amount(id)
		var rate: float  = _estimate_consumption_rate(id)
		item_prices[id] = _calculate_item_price(id, stock, rate)
