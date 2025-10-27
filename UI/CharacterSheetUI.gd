# CharacterSheetUI.gd
extends Control

# Get references to UI labels/elements using @onready or %UniqueName
@onready var name_label: Label = %CharacterName
@onready var level_label: Label = %CharacterLevel
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
