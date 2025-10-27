# res://Economy/EconomyConfig.gd
extends Resource
class_name EconomyConfig

@export_group("Food System")
@export var servings_tick_interval: float = 60.0   # ticks between consumption checks
@export var servings_per_10_pops: float = 1.0      # servings needed per 10 cap per check

# Units consumed per 1 serving (stage costs)
@export var cost_units_ingredient: float = 5.0
@export var cost_units_processed: float  = 2.5
@export var cost_units_meal: float       = 1.0
@export_group("Infrastructure System")
@export var infra_tick_interval: float = 60.0      # ticks between infrastructure demand
@export var infra_units_per_hub: float = 10.0     # flat base cost per settlement per interval
@export var infra_units_per_building_level: float = 5.0  # extra cost per building level per interval

# Units consumed per 1 infrastructure unit (tier costs: ingredient → processed → component)
@export var infra_cost_ingredient: float = 5.0    # raw materials (Stone, Scrap)
@export var infra_cost_processed: float  = 2.5    # refined materials (Steel Ingot, Concrete)
@export var infra_cost_component: float  = 1.0    # finished components (Girder, Circuit Board)

@export_group("Trading System")
@export var caravan_surplus_threshold: float = 200.0  # Items over need to trigger caravan spawn/trading
@export var caravan_home_tax_rate: float = 0.1        # Percentage of money caravans pay to home hub on return
