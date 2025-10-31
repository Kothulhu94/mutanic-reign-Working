class_name BeastDen extends StaticBody2D

## Beast spawning building with health, emergency spawning, and combat integration
## Blocks caravan/bus movement via StaticBody2D collision
## Spawns beasts on a tick-based interval

@export var den_type: BeastDenType
@export var obstacle_size: Vector2 = Vector2(64, 64)

## Combat integration - allows dens to be attacked
var charactersheet: CharacterSheet

## Spawn progress accumulator (like ProcessorBuilding's work_progress)
var spawn_progress: float = 0.0

## Track spawned beasts for cleanup and max limit enforcement
var active_beasts: Array[Node] = []

## Track if emergency spawn has been triggered for current health tier
var emergency_triggered: bool = false

## Reference to overworld for spawning beasts into scene
var overworld: Node = null

signal den_destroyed(den: BeastDen)

func _ready() -> void:
	add_to_group("beast_den")
	_initialize_charactersheet()

	if charactersheet != null:
		charactersheet.health_changed.connect(_on_health_changed)

	overworld = get_tree().current_scene

	var tk: Node = get_node_or_null("/root/Timekeeper")
	if tk != null and tk.has_signal("tick"):
		if not tk.is_connected("tick", Callable(self, "_on_timekeeper_tick")):
			tk.connect("tick", Callable(self, "_on_timekeeper_tick"))

	_create_navigation_obstacle()

func _initialize_charactersheet() -> void:
	if den_type == null:
		return

	charactersheet = CharacterSheet.new()
	charactersheet.base_health = den_type.base_health
	charactersheet.base_damage = den_type.base_damage
	charactersheet.base_defense = den_type.base_defense
	charactersheet.initialize_health()

func _create_navigation_obstacle() -> void:
	var collision_shape: CollisionShape2D = get_node_or_null("CollisionShape2D")
	var nav_region: NavigationRegion2D = get_node_or_null("NavigationRegion2D")

	if nav_region == null:
		return

	if collision_shape != null and collision_shape.shape is RectangleShape2D:
		var rect_shape: RectangleShape2D = collision_shape.shape as RectangleShape2D
		rect_shape.size = obstacle_size

	var navpoly: NavigationPolygon = NavigationPolygon.new()
	navpoly.resource_local_to_scene = true
	navpoly.agent_radius = 0.0
	navpoly.add_outline(PackedVector2Array([
		Vector2(-obstacle_size.x / 2.0, -obstacle_size.y / 2.0),
		Vector2(obstacle_size.x / 2.0, -obstacle_size.y / 2.0),
		Vector2(obstacle_size.x / 2.0, obstacle_size.y / 2.0),
		Vector2(-obstacle_size.x / 2.0, obstacle_size.y / 2.0)
	]))
	navpoly.make_polygons_from_outlines()
	nav_region.navigation_polygon = navpoly

## Called automatically by Timekeeper each game tick
func _on_timekeeper_tick(_dt: float) -> void:
	if den_type == null:
		return

	if den_type.normal_beast_scene == null:
		return

	if charactersheet == null or charactersheet.current_health <= 0:
		_remove_den()
		return

	if _at_max_capacity():
		return

	spawn_progress += 1.0 / den_type.spawn_interval_ticks

	if spawn_progress >= 1.0:
		spawn_progress = 0.0
		_spawn_beast(den_type.normal_beast_scene)

func _at_max_capacity() -> bool:
	if den_type.max_active_beasts <= 0:
		return false

	_cleanup_dead_beasts()
	return active_beasts.size() >= den_type.max_active_beasts

func _spawn_beast(beast_scene: PackedScene) -> void:
	if beast_scene == null:
		return

	if overworld == null:
		overworld = get_tree().current_scene

	var beast: Node2D = beast_scene.instantiate() as Node2D
	if beast == null:
		return

	beast.name = "%s_Beast_%d" % [name, active_beasts.size()]

	var spawn_offset: Vector2 = Vector2(randf_range(-32.0, 32.0), randf_range(-32.0, 32.0))
	beast.global_position = global_position + spawn_offset

	overworld.add_child(beast)
	active_beasts.append(beast)

	if beast.has_signal("tree_exited"):
		beast.tree_exited.connect(_on_beast_removed.bind(beast))

func _on_beast_removed(beast: Node) -> void:
	var idx: int = active_beasts.find(beast)
	if idx >= 0:
		active_beasts.remove_at(idx)

func _cleanup_dead_beasts() -> void:
	var to_remove: Array[int] = []

	for i: int in range(active_beasts.size()):
		var beast: Node = active_beasts[i]
		if not is_instance_valid(beast) or not beast.is_inside_tree():
			to_remove.append(i)

	for i: int in range(to_remove.size() - 1, -1, -1):
		active_beasts.remove_at(to_remove[i])

func _on_health_changed(new_health: int, max_health: int) -> void:
	if den_type == null:
		return

	if new_health <= 0:
		_remove_den()
		return

	var health_percent: float = float(new_health) / float(max_health)

	if health_percent <= den_type.emergency_health_threshold and not emergency_triggered:
		_trigger_emergency_spawn()
		emergency_triggered = true
	elif health_percent > den_type.emergency_health_threshold:
		emergency_triggered = false

func _trigger_emergency_spawn() -> void:
	if den_type == null:
		return

	var spawn_scene: PackedScene = den_type.emergency_beast_scene
	if spawn_scene == null:
		spawn_scene = den_type.normal_beast_scene

	if spawn_scene == null:
		return

	var spawn_count: int = den_type.emergency_spawn_count

	for i: int in range(spawn_count):
		if _at_max_capacity():
			break
		_spawn_beast(spawn_scene)

func _remove_den() -> void:
	den_destroyed.emit(self)
	queue_free()
