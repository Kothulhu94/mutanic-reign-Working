class_name OverworldUI
extends CanvasLayer

## UI for build mode status, button, and confirmation panel

@onready var build_button: Button = $VBoxContainer/BuildButton
@onready var status_label: Label = $VBoxContainer/StatusLabel
@onready var confirm_panel: PanelContainer = $ConfirmPanel
@onready var confirm_button: Button = $ConfirmPanel/VBoxContainer2/HBoxContainer/ConfirmButton
@onready var cancel_button: Button = $ConfirmPanel/VBoxContainer2/HBoxContainer/CancelButton

var _road_builder: RoadBuilder = null
var _road_manager: RoadManager = null
var _pending_network: RoadNetwork = null


func initialize(road_builder: RoadBuilder, road_manager: RoadManager) -> void:
	_road_builder = road_builder
	_road_manager = road_manager

	if _road_builder != null:
		_road_builder.building_started.connect(_on_building_started)
		_road_builder.building_cancelled.connect(_on_building_cancelled)
		_road_builder.building_confirmed.connect(_on_building_confirmed)


func _ready() -> void:
	build_button.pressed.connect(_on_build_button_pressed)
	confirm_button.pressed.connect(_on_confirm_button_pressed)
	cancel_button.pressed.connect(_on_cancel_button_pressed)
	confirm_panel.visible = false


func _on_build_button_pressed() -> void:
	if _road_builder != null:
		build_button.disabled = true
		status_label.text = "Press B to start building..."


func _on_building_started() -> void:
	status_label.text = "BUILD MODE: Click to place points. Double-click to finish. Right-click to cancel."
	build_button.disabled = true


func _on_building_cancelled() -> void:
	status_label.text = "Build cancelled."
	build_button.disabled = false


func _on_building_confirmed(network: RoadNetwork) -> void:
	_pending_network = network
	status_label.text = "Road placement ready. Segments: %d" % network.get_segment_count()
	confirm_panel.visible = true


func _on_confirm_button_pressed() -> void:
	if _pending_network != null and _road_manager != null:
		_pending_network.carve_all_segments()
		_road_manager.register_network(_pending_network)
		status_label.text = "Road built successfully! Segments: %d" % _pending_network.get_segment_count()
		_pending_network = null

	confirm_panel.visible = false
	build_button.disabled = false


func _on_cancel_button_pressed() -> void:
	_pending_network = null
	confirm_panel.visible = false
	status_label.text = "Road placement cancelled."
	build_button.disabled = false
