extends Node

const SAVE_DIR: String = "user://saves/"
const SAVE_EXTENSION: String = ".save"

func _ready() -> void:
	_ensure_save_directory()

func _ensure_save_directory() -> void:
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		DirAccess.make_dir_absolute(SAVE_DIR)

func save_game(slot_name: String) -> bool:
	var save_data: Dictionary = {}

	var player_node: Bus = _get_player_bus()
	if player_node == null:
		push_error("[SaveManager] Cannot save: Player Bus not found")
		return false

	_save_player_data(save_data, player_node)
	_save_caravan_data(save_data)
	_save_hub_data(save_data)

	var file_path: String = SAVE_DIR + slot_name + SAVE_EXTENSION
	var file: FileAccess = FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		push_error("[SaveManager] Failed to open file for writing: %s" % file_path)
		return false

	var json_string: String = JSON.stringify(save_data, "\t")
	file.store_string(json_string)
	file.close()

	return true

func load_game(slot_name: String) -> bool:
	var file_path: String = SAVE_DIR + slot_name + SAVE_EXTENSION

	if not FileAccess.file_exists(file_path):
		push_error("[SaveManager] Save file does not exist: %s" % file_path)
		return false

	var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		push_error("[SaveManager] Failed to open file for reading: %s" % file_path)
		return false

	var json_string: String = file.get_as_text()
	file.close()

	var json: JSON = JSON.new()
	var parse_result: Error = json.parse(json_string)
	if parse_result != OK:
		push_error("[SaveManager] Failed to parse save file JSON: %s" % json.get_error_message())
		return false

	var save_data: Dictionary = json.data
	if save_data == null or save_data.is_empty():
		push_error("[SaveManager] Loaded save data is empty")
		return false

	_load_player_data(save_data)
	_load_hub_data(save_data)
	_load_caravan_data(save_data)

	var timekeeper: Node = get_node_or_null("/root/Timekeeper")
	if timekeeper != null and timekeeper.has_method("resume"):
		timekeeper.resume()

	return true

func _save_player_data(save_data: Dictionary, player_node: Bus) -> void:
	var player_data: Dictionary = {}

	player_data["position"] = {"x": player_node.global_position.x, "y": player_node.global_position.y}
	var player_sheet: Variant = null
	if player_node.charactersheet != null:
		player_sheet = _serialize_character_sheet(player_node.charactersheet)
	player_data["sheet"] = player_sheet
	player_data["inventory"] = player_node.inventory.duplicate(true)
	player_data["money"] = player_node.money
	player_data["max_unique_stacks"] = player_node.max_unique_stacks
	player_data["max_stack_size"] = player_node.max_stack_size

	if player_node.agent != null:
		player_data["nav_target"] = {"x": player_node.agent.target_position.x, "y": player_node.agent.target_position.y}

	save_data["player"] = player_data

func _save_caravan_data(save_data: Dictionary) -> void:
	var caravan_list: Array[Dictionary] = []

	var caravans: Array[Node] = get_tree().get_nodes_in_group("caravans")
	for caravan_node: Node in caravans:
		if caravan_node is Caravan:
			var caravan: Caravan = caravan_node as Caravan
			var caravan_data: Dictionary = {}

			caravan_data["position"] = {"x": caravan.global_position.x, "y": caravan.global_position.y}
			var caravan_state_data: Variant = null
			if caravan.caravan_state != null:
				caravan_state_data = _serialize_caravan_state(caravan.caravan_state)
			caravan_data["state"] = caravan_state_data
			var home_hub_id_str: String = ""
			if caravan.home_hub != null:
				home_hub_id_str = str(caravan.home_hub.state.hub_id)
			caravan_data["home_hub_id"] = home_hub_id_str
			var target_hub_id_str: String = ""
			if caravan.current_target_hub != null:
				target_hub_id_str = str(caravan.current_target_hub.state.hub_id)
			caravan_data["current_target_hub_id"] = target_hub_id_str
			caravan_data["current_state"] = caravan.current_state
			caravan_data["visited_hub_ids"] = _get_hub_ids_from_array(caravan.visited_hubs)
			caravan_data["purchase_prices"] = caravan.purchase_prices.duplicate(true)
			caravan_data["name"] = caravan.name

			if caravan.nav_agent != null:
				caravan_data["nav_target_position"] = {"x": caravan.nav_agent.target_position.x, "y": caravan.nav_agent.target_position.y}

			caravan_data["movement_speed"] = caravan.movement_speed

			caravan_list.append(caravan_data)

	save_data["caravans"] = caravan_list

func _save_hub_data(save_data: Dictionary) -> void:
	var hub_data: Dictionary = {}

	var overworld: Node = _get_overworld_node()
	if overworld == null:
		return

	for child: Node in overworld.get_children():
		if child is Hub:
			var hub: Hub = child as Hub
			if hub.state != null:
				hub_data[str(hub.state.hub_id)] = _serialize_hub_state(hub.state)

	save_data["hubs"] = hub_data

func _load_player_data(save_data: Dictionary) -> void:
	if not save_data.has("player"):
		push_error("[SaveManager] No player data in save file")
		return

	var player_node: Bus = _get_player_bus()
	if player_node == null:
		push_error("[SaveManager] Cannot load: Player Bus not found")
		return

	var player_data: Dictionary = save_data["player"]

	var pos_data: Variant = player_data.get("position", {"x": 0.0, "y": 0.0})
	if pos_data is Dictionary:
		player_node.global_position = Vector2(pos_data.get("x", 0.0), pos_data.get("y", 0.0))
	else:
		player_node.global_position = Vector2.ZERO

	var sheet_data: Variant = player_data.get("sheet", null)
	if sheet_data != null and sheet_data is Dictionary:
		player_node.charactersheet = _deserialize_character_sheet(sheet_data)
	else:
		player_node.charactersheet = CharacterSheet.new()

	player_node.inventory = player_data.get("inventory", {}).duplicate(true)
	player_node.money = player_data.get("money", 1000)
	player_node.max_unique_stacks = player_data.get("max_unique_stacks", 16)
	player_node.max_stack_size = player_data.get("max_stack_size", 100)

	if player_node.agent != null:
		var nav_target_data: Variant = player_data.get("nav_target", null)
		if nav_target_data is Dictionary:
			player_node.agent.target_position = Vector2(nav_target_data.get("x", 0.0), nav_target_data.get("y", 0.0))
		else:
			player_node.agent.target_position = player_node.global_position

	_clear_overworld_pathline()
	_reinitialize_player_health(player_node)

func _load_hub_data(save_data: Dictionary) -> void:
	if not save_data.has("hubs"):
		push_error("[SaveManager] No hub data in save file")
		return

	var hub_data: Dictionary = save_data["hubs"]
	var overworld: Node = _get_overworld_node()
	if overworld == null:
		return

	for child: Node in overworld.get_children():
		if child is Hub:
			var hub: Hub = child as Hub
			if hub.state != null:
				var hub_id_str: String = str(hub.state.hub_id)
				if hub_data.has(hub_id_str):
					var state_data: Variant = hub_data[hub_id_str]
					if state_data is Dictionary:
						hub.state = _deserialize_hub_state(state_data)

func _load_caravan_data(save_data: Dictionary) -> void:
	if not save_data.has("caravans"):
		return

	var overworld: Node = _get_overworld_node()
	if overworld == null:
		return

	_delete_all_existing_caravans()

	var caravan_list: Array = save_data["caravans"]
	var caravan_scene: PackedScene = load("res://Actors/Caravan.tscn")
	if caravan_scene == null:
		push_error("[SaveManager] Failed to load Caravan scene")
		return

	var item_db: ItemDB = load("res://data/Items/ItemsCatalog.tres")
	var all_hubs: Array[Hub] = _get_all_hubs()

	for caravan_data: Dictionary in caravan_list:
		var new_caravan: Caravan = caravan_scene.instantiate() as Caravan
		if new_caravan == null:
			continue

		new_caravan.name = caravan_data.get("name", "Caravan")

		var state_data: Variant = caravan_data.get("state", null)
		if state_data != null and state_data is Dictionary:
			new_caravan.caravan_state = _deserialize_caravan_state(state_data)

		new_caravan.current_state = caravan_data.get("current_state", Caravan.State.IDLE)
		new_caravan.purchase_prices = caravan_data.get("purchase_prices", {}).duplicate(true)

		var home_hub_id_str: String = caravan_data.get("home_hub_id", "")
		if not home_hub_id_str.is_empty():
			new_caravan.home_hub = _find_hub_by_id(StringName(home_hub_id_str), all_hubs)

		var target_hub_id_str: String = caravan_data.get("current_target_hub_id", "")
		if not target_hub_id_str.is_empty():
			new_caravan.current_target_hub = _find_hub_by_id(StringName(target_hub_id_str), all_hubs)

		var visited_hub_ids: Array = caravan_data.get("visited_hub_ids", [])
		new_caravan.visited_hubs = _get_hubs_from_ids(visited_hub_ids, all_hubs)

		overworld.add_child(new_caravan)

		var pos_data: Variant = caravan_data.get("position", {"x": 0.0, "y": 0.0})
		if pos_data is Dictionary:
			new_caravan.global_position = Vector2(pos_data.get("x", 0.0), pos_data.get("y", 0.0))
		else:
			new_caravan.global_position = Vector2.ZERO

		new_caravan.item_db = item_db
		new_caravan.all_hubs = all_hubs

		if caravan_data.has("movement_speed"):
			new_caravan.movement_speed = caravan_data.get("movement_speed", 100.0)

		if new_caravan.nav_agent != null:
			if caravan_data.has("nav_target_position"):
				var nav_pos_data: Variant = caravan_data.get("nav_target_position", null)
				if nav_pos_data is Dictionary:
					new_caravan.nav_agent.target_position = Vector2(nav_pos_data.get("x", 0.0), nav_pos_data.get("y", 0.0))
				else:
					new_caravan.nav_agent.target_position = new_caravan.global_position
			else:
				new_caravan.nav_agent.target_position = new_caravan.global_position

			if new_caravan.caravan_state != null and new_caravan.caravan_state.caravan_type != null:
				new_caravan.nav_agent.max_speed = new_caravan.movement_speed
				new_caravan.nav_agent.navigation_layers = new_caravan.caravan_state.caravan_type.navigation_layers

		if new_caravan.caravan_state != null and new_caravan.caravan_state.caravan_type != null:
			var sprite: Sprite2D = new_caravan.get_node_or_null("Sprite2D") as Sprite2D
			if sprite != null and new_caravan.caravan_state.caravan_type.sprite != null:
				sprite.texture = new_caravan.caravan_state.caravan_type.sprite

		_reinitialize_caravan_health(new_caravan)

		if new_caravan.has_signal("player_initiated_chase"):
			new_caravan.player_initiated_chase.connect(overworld._on_chase_initiated)

		if new_caravan.has_signal("tree_exited"):
			new_caravan.tree_exited.connect(overworld._on_caravan_removed.bind(new_caravan))

func _reinitialize_player_health(player_node: Bus) -> void:
	if player_node.charactersheet != null:
		player_node.charactersheet.initialize_health()

		if player_node._health_visual != null:
			if player_node.charactersheet.health_changed.is_connected(player_node._on_health_changed):
				player_node.charactersheet.health_changed.disconnect(player_node._on_health_changed)

			player_node.charactersheet.health_changed.connect(player_node._on_health_changed)
			player_node._on_health_changed(
				player_node.charactersheet.current_health,
				player_node.charactersheet.get_effective_health()
			)

func _reinitialize_caravan_health(caravan: Caravan) -> void:
	if caravan.caravan_state == null or caravan.caravan_state.leader_sheet == null:
		return

	caravan.caravan_state.leader_sheet.initialize_health()

	if caravan._health_visual == null:
		var health_visual_scene: PackedScene = preload("res://UI/ActorHealthVisual.tscn")
		caravan._health_visual = health_visual_scene.instantiate() as Control
		if caravan._health_visual != null:
			caravan.add_child(caravan._health_visual)
			caravan._health_visual.position = Vector2(-18, -35)

	if caravan._health_visual != null:
		if caravan.caravan_state.leader_sheet.health_changed.is_connected(caravan._on_health_changed):
			caravan.caravan_state.leader_sheet.health_changed.disconnect(caravan._on_health_changed)

		caravan.caravan_state.leader_sheet.health_changed.connect(caravan._on_health_changed)
		caravan._on_health_changed(
			caravan.caravan_state.leader_sheet.current_health,
			caravan.caravan_state.leader_sheet.get_effective_health()
		)

func _delete_all_existing_caravans() -> void:
	var caravans: Array[Node] = get_tree().get_nodes_in_group("caravans")
	for caravan_node: Node in caravans:
		caravan_node.queue_free()

func list_save_slots() -> Array[String]:
	var save_slots: Array[String] = []

	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		return save_slots

	var dir: DirAccess = DirAccess.open(SAVE_DIR)
	if dir == null:
		return save_slots

	dir.list_dir_begin()
	var file_name: String = dir.get_next()

	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(SAVE_EXTENSION):
			var slot_name: String = file_name.trim_suffix(SAVE_EXTENSION)
			save_slots.append(slot_name)
		file_name = dir.get_next()

	dir.list_dir_end()
	return save_slots

func delete_save(slot_name: String) -> bool:
	var file_path: String = SAVE_DIR + slot_name + SAVE_EXTENSION

	if not FileAccess.file_exists(file_path):
		push_warning("[SaveManager] Cannot delete non-existent save: %s" % slot_name)
		return false

	var error: Error = DirAccess.remove_absolute(file_path)
	if error != OK:
		push_error("[SaveManager] Failed to delete save file: %s (Error: %d)" % [file_path, error])
		return false

	return true

func get_save_info(slot_name: String) -> Dictionary:
	var file_path: String = SAVE_DIR + slot_name + SAVE_EXTENSION

	if not FileAccess.file_exists(file_path):
		return {}

	var info: Dictionary = {}
	info["slot_name"] = slot_name
	info["file_path"] = file_path
	info["modified_time"] = FileAccess.get_modified_time(file_path)

	var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
	if file != null:
		var json_string: String = file.get_as_text()
		file.close()

		var json: JSON = JSON.new()
		if json.parse(json_string) == OK:
			var save_data: Dictionary = json.data

			if save_data.has("player"):
				var player_data: Dictionary = save_data["player"]
				if player_data.has("sheet") and player_data["sheet"] is Dictionary:
					var sheet_data: Dictionary = player_data["sheet"]
					info["player_name"] = sheet_data.get("character_name", "Unknown")
					info["player_level"] = sheet_data.get("level", 1)
				info["player_money"] = player_data.get("money", 0)

			if save_data.has("caravans"):
				info["caravan_count"] = save_data["caravans"].size()

			if save_data.has("hubs"):
				info["hub_count"] = save_data["hubs"].size()

	return info

func _get_player_bus() -> Bus:
	var buses: Array[Node] = get_tree().get_nodes_in_group("player")
	if buses.is_empty():
		var overworld: Node = _get_overworld_node()
		if overworld != null:
			var bus_node: Node = overworld.get("bus")
			if bus_node != null and bus_node is Bus:
				return bus_node as Bus
		return null
	return buses[0] as Bus

func _get_overworld_node() -> Node:
	var root: Window = get_tree().root
	if root == null:
		return null

	var overworld: Node = root.get_node_or_null("Overworld")
	return overworld

func _get_all_hubs() -> Array[Hub]:
	var hubs: Array[Hub] = []
	var overworld: Node = _get_overworld_node()
	if overworld == null:
		return hubs

	for child: Node in overworld.get_children():
		if child is Hub:
			hubs.append(child as Hub)

	return hubs

func _find_hub_by_id(hub_id: StringName, hubs: Array[Hub]) -> Hub:
	for hub: Hub in hubs:
		if hub.state != null and hub.state.hub_id == hub_id:
			return hub
	return null

func _get_hub_ids_from_array(hub_array: Array[Hub]) -> Array[StringName]:
	var ids: Array[StringName] = []
	for hub: Hub in hub_array:
		if hub != null and hub.state != null:
			ids.append(hub.state.hub_id)
	return ids

func _get_hubs_from_ids(hub_ids: Array, all_hubs: Array[Hub]) -> Array[Hub]:
	var result: Array[Hub] = []
	for id in hub_ids:
		var hub_id: StringName = id if id is StringName else StringName(str(id))
		var hub: Hub = _find_hub_by_id(hub_id, all_hubs)
		if hub != null:
			result.append(hub)
	return result

func _serialize_character_sheet(sheet: CharacterSheet) -> Dictionary:
	if sheet == null:
		return {}

	var data: Dictionary = {}
	data["character_name"] = sheet.character_name
	data["character_description"] = sheet.character_description
	data["level"] = sheet.level
	data["base_health"] = sheet.base_health
	data["base_damage"] = sheet.base_damage
	data["base_defense"] = sheet.base_defense
	data["current_health"] = sheet.current_health
	data["attribute_health_multiplier"] = sheet.attribute_health_multiplier
	data["attribute_damage_multiplier"] = sheet.attribute_damage_multiplier
	data["attribute_defense_multiplier"] = sheet.attribute_defense_multiplier

	return data

func _deserialize_character_sheet(data: Dictionary) -> CharacterSheet:
	var sheet: CharacterSheet = CharacterSheet.new()
	sheet.character_name = data.get("character_name", "Nameless")
	sheet.character_description = data.get("character_description", "")
	sheet.level = data.get("level", 1)
	sheet.base_health = data.get("base_health", 100)
	sheet.base_damage = data.get("base_damage", 10)
	sheet.base_defense = data.get("base_defense", 5)
	sheet.current_health = data.get("current_health", 100)
	sheet.attribute_health_multiplier = data.get("attribute_health_multiplier", 5)
	sheet.attribute_damage_multiplier = data.get("attribute_damage_multiplier", 5)
	sheet.attribute_defense_multiplier = data.get("attribute_defense_multiplier", 5)

	return sheet

func _serialize_caravan_state(state: CaravanState) -> Dictionary:
	if state == null:
		return {}

	var data: Dictionary = {}
	data["home_hub_id"] = str(state.home_hub_id)
	data["destination_hub_id"] = str(state.destination_hub_id)
	data["inventory"] = state.inventory.duplicate(true)
	data["money"] = state.money
	data["profit_this_trip"] = state.profit_this_trip
	data["current_leg"] = state.current_leg
	var leader_sheet_data: Variant = null
	if state.leader_sheet != null:
		leader_sheet_data = _serialize_character_sheet(state.leader_sheet)
	data["leader_sheet"] = leader_sheet_data

	if state.caravan_type != null:
		data["caravan_type_path"] = state.caravan_type.resource_path

	return data

func _deserialize_caravan_state(data: Dictionary) -> CaravanState:
	var state: CaravanState = CaravanState.new()
	state.home_hub_id = StringName(data.get("home_hub_id", ""))
	state.destination_hub_id = StringName(data.get("destination_hub_id", ""))
	state.inventory = data.get("inventory", {}).duplicate(true)
	state.money = data.get("money", 0)
	state.profit_this_trip = data.get("profit_this_trip", 0)
	state.current_leg = data.get("current_leg", CaravanState.Leg.OUTBOUND)

	var leader_data: Variant = data.get("leader_sheet", null)
	if leader_data != null and leader_data is Dictionary:
		state.leader_sheet = _deserialize_character_sheet(leader_data)

	var caravan_type_path: String = data.get("caravan_type_path", "")
	if not caravan_type_path.is_empty():
		state.caravan_type = load(caravan_type_path)

	return state

func _serialize_hub_state(state: HubStates) -> Dictionary:
	if state == null:
		return {}

	var data: Dictionary = {}
	data["hub_id"] = str(state.hub_id)
	data["display_name"] = state.display_name
	data["governor_id"] = str(state.governor_id)
	data["money"] = state.money
	data["inventory"] = state.inventory.duplicate(true)
	data["base_population_cap"] = state.base_population_cap
	data["trade_prices"] = state.trade_prices.duplicate(true)

	return data

func _deserialize_hub_state(data: Dictionary) -> HubStates:
	var state: HubStates = HubStates.new()
	state.hub_id = StringName(data.get("hub_id", ""))
	state.display_name = data.get("display_name", "Settlement")
	state.governor_id = StringName(data.get("governor_id", ""))
	state.money = data.get("money", 0)
	state.inventory = data.get("inventory", {}).duplicate(true)
	state.base_population_cap = data.get("base_population_cap", 100)
	state.trade_prices = data.get("trade_prices", {}).duplicate(true)

	return state

func _clear_overworld_pathline() -> void:
	var overworld: Node = _get_overworld_node()
	if overworld == null:
		return

	var path_line: Line2D = overworld.get_node_or_null("PathLine")
	if path_line != null:
		path_line.points = PackedVector2Array()
		path_line.visible = false

	if overworld.get("_path_world") != null:
		overworld.set("_path_world", PackedVector2Array())
