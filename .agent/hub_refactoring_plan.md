# Hub.gd Refactoring Implementation Plan

## Overview

Split Hub.gd (692 lines) into modular, focused components while preserving all functionality and dependencies.

### Current State

**File:** [Hub.gd](file:///d:/MutantReign-codex-initialize-godot-4-project-skeleton/MRCF/mutanic-reign-Working/Hub/Hub.gd)
- **692 lines** of tightly coupled code
- **8 functional areas** mixed together
- **Multiple external dependencies:** Bus, TroopDatabase, Timekeeper, ProgressionManager, UI components
- **Central coordinator** for economy, trading, UI, troops, buildings

### Functional Areas Identified

| Area | Lines | Functions | Description |
|------|-------|-----------|-------------|
| Economy System | ~170 | 12 | Tick processing, inventory delta, engine wiring |  
| Trading API | ~70 | 3 | Buy/sell from hub, price queries (caravan interface) |
| Pricing System | ~90 | 7 | EMA-based consumption tracking, dynamic pricing |
| Troop Production | ~160 | 9 | Tier upgrades, spawning, pity system |
| UI Management | ~130 | 10 | Menu/market/recruitment signals, Bus lookup |
| Building Management | ~40 | 4 | Place/clear buildings, dependency injection |
| Governor Bonuses | ~20 | part of tick | Skill-based productivity/efficiency calculation |
| Initialization | ~50 | _ready + helpers | State setup, signal connections |

### Dependencies

**Consumed By Hub.gd:**
- `HubStates` - state data class
- `HubEconomy` - engine instance
- `ItemDB` - item definitions
- `EconomyConfig` - economy parameters
- `BuildSlots` - building grid management
- `TroopDatabase` (autoload) - troop definitions
- `Timekeeper` (autoload) - tick signal
- `ProgressionManager` (autoload) - governor stats
- `Bus` - player reference via scene tree
- UI components: `HubMenuUI`, `MarketUI`, `RecruitmentUI`

**Provided By Hub.gd:**
- Trading API: `buy_from_hub()`, `sell_to_hub()`, `get_item_price()`
- Building API: `place_building()`, `clear_building()`
- State management

---

## Proposed Component Architecture

### Component 1: HubEconomyManager

**Responsibilities:**
- Economy tick processing
- Inventory delta application
- Resource level tracking (food, infra, medical, luxury)
- Engine wiring and configuration
- Governor bonus calculation

**New File:** [HubEconomyManager.gd](file:///d:/MutantReign-codex-initialize-godot-4-project-skeleton/MRCF/mutanic-reign-Working/Hub/HubEconomyManager.gd)

```gdscript
extends Node
class_name HubEconomyManager

signal economy_tick_processed(results: Dictionary)

var state: HubStates
var item_db: ItemDB
var economy_config: EconomyConfig
var building_manager: HubBuildingManager

# Internal
var _engine: HubEconomy = HubEconomy.new()
var _inventory_float: Dictionary = {}

# Resource levels (exported for visibility)
var food_level: float = 0.0
var infrastructure_level: float = 0.0
var medical_level: float = 0.0
var luxury_level: float = 0.0

func setup(s: HubStates, db: ItemDB, config: EconomyConfig, bldg_mgr: HubBuildingManager):
    state = s
    item_db = db
    economy_config = config
    building_manager = bldg_mgr
    _refresh_engine()

func process_tick(dt: float, governor_id: StringName) -> Dictionary:
    var buildings: Array[Node] = building_manager.get_buildings()
    var cap: int = building_manager.get_population_cap()
    var bonuses: Dictionary = _calc_governor_bonuses(governor_id)
    
    var r: Dictionary = _engine.tick(
        dt, cap, state.inventory, _inventory_float, buildings,
        bonuses.get("productivity", 0.0),
        bonuses.get("efficiency", 0.0)
    )
    
    _apply_delta((r.get("delta", {}) as Dictionary))
    _update_resource_levels(r)
    
    economy_tick_processed.emit(r)
    return r

func _apply_delta(delta: Dictionary):
    # ... existing logic

func _calc_governor_bonuses(governor_id: StringName) -> Dictionary:
    # ... extract from Hub._on_timekeeper_tick

func _update_resource_levels(results: Dictionary):
    food_level = float(results.get("food_level", 0.0))
    # ...
```

**Lines Saved:** ~170 → Reduces Hub.gd to ~522 lines

---

### Component 2: HubTradingSystem

**Responsibilities:**
- Dynamic pricing (EMA-based)
- Buy/sell API for caravans
- Price queries
- Consumption telemetry tracking

**New File:** [HubTradingSystem.gd](file:///d:/MutantReign-codex-initialize-godot-4-project-skeleton/MRCF/mutanic-reign-Working/Hub/HubTradingSystem.gd)

```gdscript
extends Node
class_name HubTradingSystem

var state: HubStates
var item_db: ItemDB
var economy_manager: HubEconomyManager

# Pricing state
var item_prices: Dictionary = {}
var _consumption_ema: Dictionary = {}
var _last_consumed: Dictionary = {}
var _last_produced: Dictionary = {}
const PRICE_ALPHA: float = 0.2

func setup(s: HubStates, db: ItemDB, econ_mgr: HubEconomyManager):
    state = s
    item_db = db
    economy_manager = econ_mgr
    economy_manager.economy_tick_processed.connect(_on_economy_tick)

func get_item_price(item_id: StringName) -> float:
    # ... existing logic

func buy_from_hub(item_id: StringName, amount: int, caravan_state: CaravanState) -> bool:
    # ... existing logic, uses economy_manager for inventory delta

func sell_to_hub(item_id: StringName, amount: int, caravan_state: CaravanState) -> bool:
    # ... existing logic

func _on_economy_tick(results: Dictionary):
    _last_consumed = results.get("consumed", {})
    _last_produced = results.get("produced", {})
    _ingest_consumption_telemetry(_last_consumed)
    _update_item_prices()

# Private helpers for pricing
func _ingest_consumption_telemetry(consumed: Dictionary):
    # ...

func _calculate_item_price(...):
    # ...
```

**Lines Saved:** ~160 → Reduces Hub.gd to ~362 lines

---

### Component 3: HubTroopProduction

**Responsibilities:**
- Troop production timer
- Tier upgrade logic
- T1 spawning with pity system
- Troop counting/queries

**New File:** [HubTroopProduction.gd](file:///d:/MutantReign-codex-initialize-godot-4-project-skeleton/MRCF/mutanic-reign-Working/Hub/HubTroopProduction.gd)

```gdscript
extends Node
class_name HubTroopProduction

var state: HubStates
var economy_manager: HubEconomyManager
var building_manager: HubBuildingManager

var _production_timer: float = 0.0

func setup(s: HubStates, econ_mgr: HubEconomyManager, bldg_mgr: HubBuildingManager):
    state = s
    economy_manager = econ_mgr
    building_manager = bldg_mgr

func process(dt: float):
    _production_timer += dt
    if _production_timer >= state.troop_production_interval:
        _production_timer -= state.troop_production_interval
        _produce_troops()

func _produce_troops():
    var troop_db: TroopDatabase = _get_troop_db()
    if troop_db == null:
        return
    
    var cap: int = building_manager.get_population_cap()
    var food: float = economy_manager.food_level
    var infra: float = economy_manager.infrastructure_level
    # ... existing production logic
    
# Extract all troop helper functions
func _count_total_troops() -> int:
    # ...
```

**Lines Saved:** ~160 → Reduces Hub.gd to ~202 lines

---

### Component 4: HubUIController

**Responsibilities:**
- UI signal handling  
- Menu/market/recruitment flow
- Bus reference lookup
- Transaction processing

**New File:** [HubUIController.gd](file:///d:/MutantReign-codex-initialize-godot-4-project-skeleton/MRCF/mutanic-reign-Working/Hub/HubUIController.gd)

```gdscript
extends Node
class_name HubUIController

var hub_menu_ui: HubMenuUI
var market_ui: MarketUI
var recruitment_ui: RecruitmentUI

var trading_system: HubTradingSystem
var troop_production: HubTroopProduction
var hub_node: Hub  # Reference back to main hub for state access

func setup(hub: Hub, menu: HubMenuUI, market: MarketUI, recruit: RecruitmentUI):
    hub_node = hub
    hub_menu_ui = menu
    market_ui = market
    recruitment_ui = recruit
    _connect_signals()

func _connect_signals():
    if hub_menu_ui:
        hub_menu_ui.menu_closed.connect(_on_menu_closed)
        hub_menu_ui.market_opened.connect(_on_market_opened)
        hub_menu_ui.recruitment_opened.connect(_on_recruitment_opened)
    # ...

func show_hub_menu():
    # ... existing _show_hub_menu logic

func _on_market_opened():
    # ... existing logic

func _on_transaction_confirmed(cart: Array[Dictionary]):
    # ... existing logic, delegates to trading_system for price/inventory

func _get_bus_from_scene_tree() -> Bus:
    # ... existing logic
```

**Lines Saved:** ~120 → Reduces Hub.gd to ~82 lines

---

### Component 5: HubBuildingManager

**Responsibilities:**
- Building placement/removal
- Population cap calculation
- Item DB injection for processors
- Building list queries

**New File:** [HubBuildingManager.gd](file:///d:/MutantReign-codex-initialize-godot-4-project-skeleton/MRCF/mutanic-reign-Working/Hub/HubBuildingManager.gd)

```gdscript
extends Node
class_name HubBuildingManager

var state: HubStates
var item_db: ItemDB
var slots: BuildSlots

func setup(s: HubStates, db: ItemDB, build_slots: BuildSlots):
    state = s
    item_db = db
    slots = build_slots

func place_building(slot_id: int, ps: PackedScene, slot_state: BuildSlotState) -> Node:
    # ... existing logic

func clear_building(slot_id: int):
    # ... existing logic

func get_buildings() -> Array[Node]:
    if slots == null:
        return []
    return slots.iter_buildings()

func get_population_cap() -> int:
    # ... existing _compute_population_cap_now logic

func inject_item_db():
    # ... existing _inject_building_dependencies logic
```

**Lines Saved:** ~40 → Reduces Hub.gd to ~42 lines

---

### Final Hub.gd Structure

**Remaining in Hub.gd (~ 80-100 lines):**

```gdscript
extends Node2D
class_name Hub

@export var state: HubStates

# Component references
var economy_manager: HubEconomyManager
var trading_system: HubTradingSystem
var troop_production: HubTroopProduction
var ui_controller: HubUIController
var building_manager: HubBuildingManager

# External refs (assigned in editor)
@export var item_db: ItemDB
@export var economy_config: EconomyConfig
@export var hub_menu_ui: HubMenuUI
@export var market_ui: MarketUI
@export var recruitment_ui: RecruitmentUI

@onready var click_and_fade: Area2D = $ClickAndFade
@onready var slots: BuildSlots = $BuildSlots

func _ready():
    _initialize_components()
    _connect_timekeeper()
    _connect_proximity_signals()

func _initialize_components():
    # Create components
    building_manager = HubBuildingManager.new()
    add_child(building_manager)
    building_manager.setup(state, item_db, slots)
    
    economy_manager = HubEconomyManager.new()
    add_child(economy_manager)
    economy_manager.setup(state, item_db, economy_config, building_manager)
    
    trading_system = HubTradingSystem.new()
    add_child(trading_system)
    trading_system.setup(state, item_db, economy_manager)
    
    troop_production = HubTroopProduction.new()
    add_child(troop_production)
    troop_production.setup(state, economy_manager, building_manager)
    
    ui_controller = HubUIController.new()
    add_child(ui_controller)
    ui_controller.setup(self, hub_menu_ui, market_ui, recruitment_ui)
    ui_controller.trading_system = trading_system
    ui_controller.troop_production = troop_production

func _on_timekeeper_tick(dt: float):
    economy_manager.process_tick(dt, state.governor_id)
    troop_production.process(dt)

# Public API (delegates to components)
func get_item_price(item_id: StringName) -> float:
    return trading_system.get_item_price(item_id)

func buy_from_hub(item_id: StringName, amount: int, caravan: CaravanState) -> bool:
    return trading_system.buy_from_hub(item_id, amount, caravan)

func sell_to_hub(item_id: StringName, amount: int, caravan: CaravanState) -> bool:
    return trading_system.sell_to_hub(item_id, amount, caravan)

func place_building(slot_id: int, ps: PackedScene, s: BuildSlotState) -> Node:
    return building_manager.place_building(slot_id, ps, s)

func clear_building(slot_id: int):
    building_manager.clear_building(slot_id)
```

---

## Implementation Order

### Phase 1: Create Component Files
1. Create `HubBuildingManager.gd` (simplest, no dependencies on other components)
2. Create `HubEconomyManager.gd` (depends on HubBuildingManager)
3. Create `HubTradingSystem.gd` (depends on HubEconomyManager)
4. Create `HubTroopProduction.gd` (depends on HubEconomyManager + HubBuildingManager)
5. Create `HubUIController.gd` (depends on HubTradingSystem)

### Phase 2: Extract Functions
**For each component:**
1. Copy functions from Hub.gd
2. Update to use component state (`state`, `item_db`, etc.)
3. Replace internal calls with component references
4. Leave original functions in Hub.gd temporarily (for safety)

### Phase 3: Integrate Components
1. Update Hub.gd `_ready()` to create components
2. Delegate public API to components
3. Update `_on_timekeeper_tick()` to call component methods
4. Test each component individually

### Phase 4: Cleanup
1. Remove old functions from Hub.gd
2. Verify all functionality works
3. Clean up any duplicate code

---

## Dependency Verification Checklist

### External Dependencies (Ensure Preserved)
- [ ] `TroopDatabase` autoload → Used by HubTroopProduction
- [ ] `Timekeeper` autoload → Connected in Hub._ready
- [ ] `ProgressionManager` autoload → Used by HubEconomyManager for governor bonuses
- [ ] `Bus` scene reference → Looked up by HubUIController
- [ ] `BuildSlots` child node → Passed to HubBuildingManager
- [ ] `ClickAndFade` Area2D → Signals connected in Hub._ready
- [ ] UI exports (HubMenuUI, MarketUI, RecruitmentUI) → Passed to HubUIController

### Component Dependencies (Cross-References)
- [ ] HubEconomyManager needs HubBuildingManager (for building list, pop cap)
- [ ] HubTradingSystem needs HubEconomyManager (for inventory delta, tick results)
- [ ] HubTroopProduction needs HubEconomyManager (for resource levels)
- [ ] HubTroopProduction needs HubBuildingManager (for pop cap)
- [ ] HubUIController needs HubTradingSystem (for transactions)
- [ ] All components need `state: HubStates` reference

### Public API Preservation
- [ ] `get_item_price()` → Delegates to HubTradingSystem
- [ ] `buy_from_hub()` → Delegates to HubTradingSystem
- [ ] `sell_to_hub()` → Delegates to HubTradingSystem
- [ ] `place_building()` → Delegates to HubBuildingManager
- [ ] `clear_building()` → Delegates to HubBuildingManager

---

## Testing Plan

### Unit Testing (Per Component)

**HubBuildingManager:**
- [ ] Place building in empty slot
- [ ] Clear building from slot
- [ ] Calculate correct population cap with bonuses
- [ ] Inject ItemDB into processors

**HubEconomyManager:**
- [ ] Process economy tick
- [ ] Apply inventory deltas correctly
- [ ] Calculate governor bonuses
- [ ] Track resource levels (food, infra, medical, luxury)

**HubTradingSystem:**
- [ ] Calculate dynamic prices based on stock/consumption
- [ ] Buy from hub (reduce inventory, update telemetry)
- [ ] Sell to hub (increase inventory, update telemetry)
- [ ] Update EMA consumption tracking

**HubTroopProduction:**
- [ ] Spawn T1 troops when empty
- [ ] Upgrade T1 → T2 with food
- [ ] Upgrade T2 → T3 with food + infra
- [ ] Upgrade T3 → T4 with all resources
- [ ] Respect population cap
- [ ] Pity system cycles through archetypes

**HubUIController:**
- [ ] Show hub menu when Bus enters
- [ ] Open market UI
- [ ] Open recruitment UI
- [ ] Process transaction cart (buy/sell items)
- [ ] Award XP to Bus for trades

### Integration Testing

- [ ] Full economy tick → affects troop production
- [ ] Trading affects pricing (EMA updates)
- [ ] Building placement affects pop cap → affects troops
- [ ] Governor assignment affects production bonuses
- [ ] UI transactions affect inventory → affects pricing

### Regression Testing

- [ ] Save/load hub state preserves all data
- [ ] Multiple hubs in scene don't interfere
- [ ] Caravan trading still works
- [ ] Bus interaction (menu/market/recruitment) still works

---

## Benefits

✅ **Reduced complexity:** 692 lines → ~100 lines in Hub.gd + 5 focused components  
✅ **Easier testing:** Each component can be tested independently  
✅ **Better maintainability:** Clear separation of concerns  
✅ **Reusability:** Components could be used in other contexts  
✅ **Safer changes:** Modifications isolated to relevant component  
✅ **Preserved functionality:** All existing features maintained

---

## Risks & Mitigations

**Risk:** Breaking dependencies during refactor  
**Mitigation:** Extract incrementally, keep old code until tests pass

**Risk:** Lost functionality  
**Mitigation:** Comprehensive testing checklist, compare before/after behavior

**Risk:** Performance overhead from components  
**Mitigation:** Components are lightweight Node children, minimal overhead

**Risk:** Difficulty tracking cross-component state  
**Mitigation:** Clear data flow: state always owned by Hub, passed to components
