# CharacterSheetUI.gd
extends Control

# Get references to UI labels/elements using @onready or %UniqueName
@onready var name_label: Label = %CharacterName
@onready var level_label: Label = %CharacterLevel
@onready var health_stat: Label = %HealthStat
@onready var damage_stat: Label = %DamageStat
@onready var defense_stat: Label = %DefenseStat
@onready var might_value: Label = %MightValue
@onready var guile_value: Label = %GuileValue
@onready var intellect_value: Label = %IntellectValue
@onready var willpower_value: Label = %WillpowerValue
@onready var close_button: Button = %CloseButton
@onready var view_skills_button: Button = %ViewSkillsButton

# Reference to the SkillListUI scene
@export var skill_list_scene: PackedScene
var skill_list_instance: Control = null


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	close_button.pressed.connect(_on_close_pressed)
	view_skills_button.pressed.connect(_on_view_skills_pressed)
	hide() # Start hidden


# Store the current character sheet for the skills UI
var current_sheet: CharacterSheet = null

# Function to populate the UI with data from a CharacterSheet resource
func display_sheet(sheet: CharacterSheet) -> void:
	if not sheet:
		push_error("Invalid CharacterSheet passed to display_sheet")
		return

	# Store reference for skills UI
	current_sheet = sheet

	name_label.text = "Name: %s" % sheet.character_name
	level_label.text = "Level: %d" % sheet.level

	# --- Populate Combat Stats (includes troop bonuses) ---
	health_stat.text = "❤️ %d" % sheet.get_effective_health()
	damage_stat.text = "⚔️ %d" % sheet.get_effective_damage()
	defense_stat.text = "🛡️ %d" % sheet.get_effective_defense()

	# Set tooltips showing stat breakdowns
	health_stat.tooltip_text = _generate_health_tooltip(sheet)
	damage_stat.tooltip_text = _generate_damage_tooltip(sheet)
	defense_stat.tooltip_text = _generate_defense_tooltip(sheet)

	# --- Populate Attributes ---
	if sheet.attributes:
		var might_level: int = sheet.attributes.get_attribute_level(CharacterAttributes.ATTRIBUTE_MIGHT)
		var might_xp: float = sheet.attributes.get_attribute_xp(CharacterAttributes.ATTRIBUTE_MIGHT)
		var might_xp_needed: float = sheet.attributes.get_xp_to_next(CharacterAttributes.ATTRIBUTE_MIGHT)
		might_value.text = "Lv %d (%d/%d XP)" % [might_level, int(might_xp), int(might_xp_needed)]

		var guile_level: int = sheet.attributes.get_attribute_level(CharacterAttributes.ATTRIBUTE_GUILE)
		var guile_xp: float = sheet.attributes.get_attribute_xp(CharacterAttributes.ATTRIBUTE_GUILE)
		var guile_xp_needed: float = sheet.attributes.get_xp_to_next(CharacterAttributes.ATTRIBUTE_GUILE)
		guile_value.text = "Lv %d (%d/%d XP)" % [guile_level, int(guile_xp), int(guile_xp_needed)]

		var intellect_level: int = sheet.attributes.get_attribute_level(CharacterAttributes.ATTRIBUTE_INTELLECT)
		var intellect_xp: float = sheet.attributes.get_attribute_xp(CharacterAttributes.ATTRIBUTE_INTELLECT)
		var intellect_xp_needed: float = sheet.attributes.get_xp_to_next(CharacterAttributes.ATTRIBUTE_INTELLECT)
		intellect_value.text = "Lv %d (%d/%d XP)" % [intellect_level, int(intellect_xp), int(intellect_xp_needed)]

		var willpower_level: int = sheet.attributes.get_attribute_level(CharacterAttributes.ATTRIBUTE_WILLPOWER)
		var willpower_xp: float = sheet.attributes.get_attribute_xp(CharacterAttributes.ATTRIBUTE_WILLPOWER)
		var willpower_xp_needed: float = sheet.attributes.get_xp_to_next(CharacterAttributes.ATTRIBUTE_WILLPOWER)
		willpower_value.text = "Lv %d (%d/%d XP)" % [willpower_level, int(willpower_xp), int(willpower_xp_needed)]

	show()




func _on_close_pressed() -> void:
	# Also hide skills UI if it's open
	if skill_list_instance != null:
		skill_list_instance.hide()
	hide()

func _on_view_skills_pressed() -> void:
	if current_sheet == null:
		push_error("CharacterSheetUI: No character sheet loaded")
		return

	# Instantiate the skill list UI if needed
	if skill_list_instance == null and skill_list_scene:
		skill_list_instance = skill_list_scene.instantiate()
		add_child(skill_list_instance)

	# Display the skills
	if skill_list_instance != null and skill_list_instance.has_method("display_skills"):
		skill_list_instance.display_skills(current_sheet)

# --- Tooltip Generators ---

func _generate_health_tooltip(sheet: CharacterSheet) -> String:
	var entries: Array[String] = []

	# Base health
	entries.append("Base: +%d" % sheet.base_health)

	# Attribute bonuses
	if sheet.attributes:
		var might_level: int = sheet.attributes.get_attribute_level(&"Might")
		if might_level > 0:
			var might_bonus: int = might_level * sheet.attribute_health_multiplier
			entries.append("Might: +%d" % might_bonus)

		var willpower_level: int = sheet.attributes.get_attribute_level(&"Willpower")
		if willpower_level > 0:
			var willpower_bonus: int = willpower_level * sheet.attribute_health_multiplier
			entries.append("Willpower: +%d" % willpower_bonus)

	# Troop bonuses
	var troop_entries: Array[String] = _get_troop_bonus_entries(sheet, "health")
	entries.append_array(troop_entries)

	return _format_tooltip_columns(entries, "Health Breakdown")

func _generate_damage_tooltip(sheet: CharacterSheet) -> String:
	var entries: Array[String] = []

	# Base damage
	entries.append("Base: +%d" % sheet.base_damage)

	# Attribute bonuses
	if sheet.attributes:
		var might_level: int = sheet.attributes.get_attribute_level(&"Might")
		if might_level > 0:
			var might_bonus: int = might_level * sheet.attribute_damage_multiplier
			entries.append("Might: +%d" % might_bonus)

		var guile_level: int = sheet.attributes.get_attribute_level(&"Guile")
		if guile_level > 0:
			var guile_bonus: int = guile_level * sheet.attribute_damage_multiplier
			entries.append("Guile: +%d" % guile_bonus)

	# Troop bonuses
	var troop_entries: Array[String] = _get_troop_bonus_entries(sheet, "damage")
	entries.append_array(troop_entries)

	return _format_tooltip_columns(entries, "Damage Breakdown")

func _generate_defense_tooltip(sheet: CharacterSheet) -> String:
	var entries: Array[String] = []

	# Base defense
	entries.append("Base: +%d" % sheet.base_defense)

	# Attribute bonuses
	if sheet.attributes:
		var guile_level: int = sheet.attributes.get_attribute_level(&"Guile")
		if guile_level > 0:
			var guile_bonus: int = guile_level * sheet.attribute_defense_multiplier
			entries.append("Guile: +%d" % guile_bonus)

		var intellect_level: int = sheet.attributes.get_attribute_level(&"Intellect")
		if intellect_level > 0:
			var intellect_bonus: int = intellect_level * sheet.attribute_defense_multiplier
			entries.append("Intellect: +%d" % intellect_bonus)

	# Troop bonuses
	var troop_entries: Array[String] = _get_troop_bonus_entries(sheet, "defense")
	entries.append_array(troop_entries)

	return _format_tooltip_columns(entries, "Defense Breakdown")

func _get_troop_bonus_entries(sheet: CharacterSheet, stat_type: String) -> Array[String]:
	var entries: Array[String] = []
	var troop_db: Node = get_node_or_null("/root/TroopDatabase")

	if troop_db == null:
		return entries

	for troop_id: StringName in sheet.troop_inventory.keys():
		var count: int = sheet.troop_inventory.get(troop_id, 0)
		if count <= 0:
			continue

		var troop_type: TroopType = troop_db.get_troop(troop_id)
		if troop_type == null:
			continue

		var bonus: int = 0
		match stat_type:
			"health":
				bonus = troop_type.health_bonus * count
			"damage":
				bonus = troop_type.damage_bonus * count
			"defense":
				bonus = troop_type.defense_bonus * count

		if bonus != 0:
			var troop_name: String = troop_type.troop_name
			var sign: String = "+" if bonus > 0 else ""
			entries.append("%d %s: %s%d" % [count, troop_name, sign, bonus])

	return entries

func _format_tooltip_columns(entries: Array[String], title: String) -> String:
	if entries.is_empty():
		return title

	var result: String = title + "\n" + "─".repeat(20) + "\n"

	# If 10 or fewer entries, single column
	if entries.size() <= 10:
		for entry in entries:
			result += entry + "\n"
		return result.strip_edges()

	# More than 10 entries: split into two columns
	var half: int = ceili(entries.size() / 2.0)
	var max_lines: int = max(half, entries.size() - half)

	for i in range(max_lines):
		var line: String = ""

		# Left column
		if i < half:
			line += entries[i].rpad(25)
		else:
			line += " ".repeat(25)

		# Right column
		var right_idx: int = half + i
		if right_idx < entries.size():
			line += entries[right_idx]

		result += line.strip_edges() + "\n"

	return result.strip_edges()
