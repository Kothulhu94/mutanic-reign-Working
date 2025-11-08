class_name RoadManager
extends Node

## Global singleton to manage all roads, persistence, and navmesh state
## Loads roads on startup and re-carves all segments to restore navmesh

var _all_networks: Array[RoadNetwork] = []
var _road_save_dir: String = "res://data/Roads/"
var _overworld: Node2D = null


func initialize(overworld: Node2D) -> void:
	_overworld = overworld
	load_roads_from_disk()


func register_network(network: RoadNetwork) -> void:
	_all_networks.append(network)
	var timestamp: int = Time.get_unix_time_from_system()
	var filepath: String = _road_save_dir + "road_%d.tres" % timestamp
	network.save_network(filepath)


func get_all_networks() -> Array[RoadNetwork]:
	return _all_networks


func load_roads_from_disk() -> void:
	var dir: DirAccess = DirAccess.open(_road_save_dir)

	if dir == null:
		push_warning("RoadManager: Could not open directory %s" % _road_save_dir)
		return

	dir.list_dir_begin()
	var filename: String = dir.get_next()

	while filename != "":
		if filename.ends_with(".tres"):
			var filepath: String = _road_save_dir + filename
			var network: RoadNetwork = load(filepath) as RoadNetwork

			if network != null:
				_all_networks.append(network)
				_restore_nav_region_references(network)
				network.carve_all_segments()

		filename = dir.get_next()

	dir.list_dir_end()


func get_networks_in_chunk(chunk_coords: Vector2i) -> Array[RoadNetwork]:
	var networks_in_chunk: Array[RoadNetwork] = []

	for network in _all_networks:
		for segment in network.segments:
			if segment.chunk_coords == chunk_coords:
				networks_in_chunk.append(network)
				break

	return networks_in_chunk


func save_all_to_disk() -> void:
	for network in _all_networks:
		var timestamp: int = int(network.created_at)
		var filepath: String = _road_save_dir + "road_%d.tres" % timestamp
		network.save_network(filepath)


func _restore_nav_region_references(network: RoadNetwork) -> void:
	if _overworld == null:
		return

	for segment in network.segments:
		if segment.parent_nav_region_path == NodePath():
			continue

		var nav_region: NavigationRegion2D = _overworld.get_node_or_null(segment.parent_nav_region_path) as NavigationRegion2D

		if nav_region != null:
			segment.parent_nav_region = nav_region
		else:
			var chunk_x: int = segment.chunk_coords.x
			var chunk_y: int = segment.chunk_coords.y
			var chunker: Node = _overworld.get_node_or_null("Chunker")

			if chunker != null:
				var sprite_node: Node = chunker.get_node_or_null("Sprite_%d_%d" % [chunk_x, chunk_y])

				if sprite_node != null:
					nav_region = sprite_node.get_node_or_null("Nav_%d_%d" % [chunk_x, chunk_y]) as NavigationRegion2D

					if nav_region != null:
						segment.set_parent_nav_region(nav_region)
