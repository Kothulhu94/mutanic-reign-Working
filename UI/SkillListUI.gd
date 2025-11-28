# uid://7hwqum185vfm
extends Control

## UI for displaying all skills organized by domain with tabbed pages
## Shows all skills from SkillDatabase, displaying learned skills with actual ranks
## and unlearned skills at rank 0

@onready var tab_container: TabContainer = %TabContainer
@onready var close_button: Button = %CloseButton

# Reference to the SkillDatabase resource
@export var skill_database: SkillDatabase

func _ready() -> void:
	close_button.pressed.connect(_on_close_pressed)
	hide() # Start hidden


## Display all skills from the database, organized by domain tabs
func display_skills(sheet: CharacterSheet) -> void:
	if not sheet:
		push_error("SkillListUI: Invalid CharacterSheet passed to display_skills")
		return

	if not skill_database:
		push_error("SkillListUI: No SkillDatabase assigned to skill_database export variable")
		return

	# Clear previous tabs
	_clear_tab_container()

	# Get all domains from the database
	var all_domains: Array[SkillDomain] = skill_database.get_all_domains()

	# Create a tab for each domain
	for domain in all_domains:
		if domain == null:
			continue

		_create_domain_tab(domain, sheet)

	show()


## Clear all children from the tab container
func _clear_tab_container() -> void:
	for child in tab_container.get_children():
		child.queue_free()


## Create a tab page for a single domain
func _create_domain_tab(domain: SkillDomain, sheet: CharacterSheet) -> void:
	# Calculate total domain ranks for the tab title
	var total_ranks: int = _calculate_total_domain_ranks(domain, sheet)

	# Create a ScrollContainer for this tab
	var scroll_container: ScrollContainer = ScrollContainer.new()
	scroll_container.name = str(domain.display_name)
	tab_container.add_child(scroll_container)

	# Set the tab title to show domain name and total ranks
	var tab_index: int = tab_container.get_tab_count() - 1
	tab_container.set_tab_title(tab_index, "%s (%d)" % [domain.display_name, total_ranks])

	# Create main content container
	var content_vbox: VBoxContainer = VBoxContainer.new()
	content_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_container.add_child(content_vbox)

	# --- Domain Header ---
	var header_label: Label = Label.new()
	header_label.text = domain.display_name
	header_label.add_theme_font_size_override("font_size", 20)
	header_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content_vbox.add_child(header_label)

	# --- Domain Description ---
	var desc_label: Label = Label.new()
	desc_label.text = domain.description
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.modulate = Color(0.9, 0.9, 0.9)
	content_vbox.add_child(desc_label)

	# Add spacing
	var spacer1: Control = Control.new()
	spacer1.custom_minimum_size = Vector2(0, 10)
	content_vbox.add_child(spacer1)

	# --- Domain Bonuses ---
	var bonuses_label: Label = Label.new()
	bonuses_label.text = "Domain Bonuses:"
	bonuses_label.add_theme_font_size_override("font_size", 16)
	content_vbox.add_child(bonuses_label)

	if domain.has_bonus_rank_5():
		var bonus5_label: Label = Label.new()
		bonus5_label.text = "  ★ Rank 5: %s" % domain.bonus_at_rank_5
		bonus5_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		bonus5_label.modulate = Color(0.2, 1.0, 0.2) if total_ranks >= 5 else Color(0.5, 0.5, 0.5)
		content_vbox.add_child(bonus5_label)

	if domain.has_bonus_rank_10():
		var bonus10_label: Label = Label.new()
		bonus10_label.text = "  ★★ Rank 10: %s" % domain.bonus_at_rank_10
		bonus10_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		bonus10_label.modulate = Color(1.0, 0.8, 0.0) if total_ranks >= 10 else Color(0.5, 0.5, 0.5)
		content_vbox.add_child(bonus10_label)

	# Add separator
	var separator1: HSeparator = HSeparator.new()
	content_vbox.add_child(separator1)

	# --- Skills Header ---
	var skills_header: Label = Label.new()
	skills_header.text = "Skills:"
	skills_header.add_theme_font_size_override("font_size", 16)
	content_vbox.add_child(skills_header)

	# Add all skills from this domain
	for skill in domain.skills:
		if skill == null:
			continue

		_create_skill_entry(skill, sheet, content_vbox)

	# Add bottom spacer
	var spacer2: Control = Control.new()
	spacer2.custom_minimum_size = Vector2(0, 20)
	content_vbox.add_child(spacer2)


## Calculate total ranks for a domain based on learned skills in character sheet
func _calculate_total_domain_ranks(domain: SkillDomain, sheet: CharacterSheet) -> int:
	var total: int = 0

	for skill in domain.skills:
		if skill == null:
			continue

		# Check if skill is learned by the character
		var skill_spec: SkillSpec = sheet.get_skill_spec(skill.skill_id)
		if skill_spec != null:
			total += skill_spec.current_rank
		# If not learned, rank is 0, so no addition

	return total


## Create a single skill entry (learned or unlearned)
func _create_skill_entry(skill: Skill, sheet: CharacterSheet, parent: VBoxContainer) -> void:
	# Check if the character has learned this skill
	var skill_spec: SkillSpec = sheet.get_skill_spec(skill.skill_id)

	var rank: int = 0
	var current_xp: float = 0.0
	var xp_needed: float = 100.0

	if skill_spec != null:
		# Skill is learned - use actual values
		rank = skill_spec.current_rank
		current_xp = skill_spec.current_xp
		xp_needed = skill_spec.xp_to_next_rank
	# else: skill not learned, defaults are rank 0, 0 XP

	# Create a panel for each skill for better visibility
	var skill_panel: PanelContainer = PanelContainer.new()
	skill_panel.custom_minimum_size = Vector2(0, 60)
	parent.add_child(skill_panel)

	# Main skill container
	var skill_vbox: VBoxContainer = VBoxContainer.new()
	skill_panel.add_child(skill_vbox)

	# Top row: Name and XP
	var top_hbox: HBoxContainer = HBoxContainer.new()
	skill_vbox.add_child(top_hbox)

	# Skill name and rank
	var name_label: Label = Label.new()
	name_label.text = "%s [Rank %d]" % [skill.display_name, rank]
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_hbox.add_child(name_label)

	# XP Progress
	var xp_label: Label = Label.new()
	xp_label.text = "XP: %d/%d" % [int(current_xp), int(xp_needed)]
	xp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top_hbox.add_child(xp_label)

	# Skill description
	var desc_label: Label = Label.new()
	desc_label.text = skill.description
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.modulate = Color(0.8, 0.8, 0.8)
	desc_label.add_theme_font_size_override("font_size", 12)
	skill_vbox.add_child(desc_label)

	# Effect info (if applicable)
	if rank > 0:
		var effect_value: float = skill.get_effect_at_rank(rank)
		if effect_value != 0.0:
			var effect_label: Label = Label.new()
			var effect_text: String = ""
			if skill.is_multiplicative:
				effect_text = "Effect: +%.1f%%" % (effect_value * 100.0)
			else:
				effect_text = "Effect: +%.1f" % effect_value
			effect_label.text = effect_text
			effect_label.modulate = Color(0.5, 1.0, 0.5)
			effect_label.add_theme_font_size_override("font_size", 12)
			skill_vbox.add_child(effect_label)

	# Add small spacing after each skill
	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(0, 5)
	parent.add_child(spacer)


func _on_close_pressed() -> void:
	hide()
