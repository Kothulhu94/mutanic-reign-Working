# res://Characters/CharacterProgression.gd
extends RefCounted
class_name CharacterProgression

## Main character progression orchestrator
## Owns attributes and skills, coordinates XP distribution
## Provides save/load functionality for persistence

# Core components
var _attributes: CharacterAttributes = CharacterAttributes.new()
var _skills: Dictionary = {}  # skill_id: StringName -> SkillSpec

# Domain lookup (set externally or loaded from database)
var _domains: Dictionary = {}  # domain_id: StringName -> DomainSpec

## Initialize with empty attributes and skills
func _init() -> void:
	_attributes.attribute_leveled.connect(_on_attribute_leveled)

## Grant skill XP and distribute to attributes
## event: "use", "success", "failure", "challenge"
## difficulty: 0.0 to 1.0
func grant_skill_xp(skill_id: StringName, event: String, difficulty: float, base_xp: int = 100) -> void:
	if not _skills.has(skill_id):
		push_error("CharacterProgression: Unknown skill '%s'" % skill_id)
		return

	var skill: SkillSpec = _skills[skill_id]

	# Step 1: Calculate skill XP
	var skill_xp: int = XPCalculator.calculate_skill_xp(base_xp, event, difficulty, skill.current_rank)

	# Step 2: Award XP to skill
	skill.add_xp(float(skill_xp))

	# Step 3: Split XP to attributes (50/50 for now)
	var split: Dictionary = XPCalculator.split_to_attributes(skill_xp)
	var primary_xp: int = int(split["primary"])
	var secondary_xp: int = int(split["secondary"])

	# Step 4: Apply difficulty modifier
	primary_xp = XPCalculator.apply_difficulty_modifier(primary_xp, difficulty)
	secondary_xp = XPCalculator.apply_difficulty_modifier(secondary_xp, difficulty)

	# Step 5: Distribute to attributes
	# For now, distributing to first two attributes (Might, Guile) as placeholder
	# In phase 2, this will lookup domain's primary/secondary attributes
	_distribute_attribute_xp(primary_xp, secondary_xp)

## Distribute attribute XP (placeholder - will use domain lookup in phase 2)
func _distribute_attribute_xp(primary_xp: int, secondary_xp: int) -> void:
	# Placeholder: distribute to Might and Guile
	# Phase 2: lookup skill's domain, use primary/secondary attributes
	_attributes.add_attribute_xp(&"Might", float(primary_xp))
	_attributes.add_attribute_xp(&"Guile", float(secondary_xp))

## Add a skill to this character
func add_skill(skill: SkillSpec) -> void:
	if skill == null or not skill.is_valid():
		push_error("CharacterProgression: Cannot add invalid skill")
		return

	_skills[skill.skill_id] = skill
	skill.skill_ranked_up.connect(_on_skill_ranked_up)

## Register a domain (for attribute lookup in phase 2)
func register_domain(domain: DomainSpec) -> void:
	if domain == null or not domain.is_valid():
		push_error("CharacterProgression: Cannot register invalid domain")
		return

	_domains[domain.domain_id] = domain

## Get attribute level
func get_attribute(name: StringName) -> int:
	return _attributes.get_attribute_level(name)

## Get skill by ID
func get_skill(skill_id: StringName) -> SkillSpec:
	return _skills.get(skill_id, null)

## Get all skills in a specific domain
func get_skills_by_domain(domain_id: StringName) -> Array[SkillSpec]:
	var result: Array[SkillSpec] = []
	for skill: SkillSpec in _skills.values():
		if skill.domain_id == domain_id:
			result.append(skill)
	return result

## Get all skills
func get_all_skills() -> Array[SkillSpec]:
	var result: Array[SkillSpec] = []
	for skill: SkillSpec in _skills.values():
		result.append(skill)
	return result

## Get attribute progress percentage
func get_attribute_progress(name: StringName) -> float:
	return _attributes.get_progress_percent(name)

## Serialize to dictionary (for save game)
func to_dict() -> Dictionary:
	var skills_data: Dictionary = {}
	for skill_id: StringName in _skills.keys():
		var skill: SkillSpec = _skills[skill_id]
		skills_data[skill_id] = skill.to_dict()

	return {
		"attributes": _attributes.to_dict(),
		"skills": skills_data
	}

## Load from dictionary (for load game)
func from_dict(data: Dictionary) -> void:
	if data.is_empty():
		return

	# Load attributes
	if data.has("attributes"):
		_attributes.from_dict(data["attributes"])

	# Load skills
	if data.has("skills"):
		var skills_data: Dictionary = data["skills"]
		for skill_id: StringName in skills_data.keys():
			var skill_data: Dictionary = skills_data[skill_id]

			# Create or get existing skill
			var skill: SkillSpec
			if _skills.has(skill_id):
				skill = _skills[skill_id]
			else:
				skill = SkillSpec.new()
				_skills[skill_id] = skill
				skill.skill_ranked_up.connect(_on_skill_ranked_up)

			skill.from_dict(skill_data)

## Signal handlers
func _on_attribute_leveled(attribute_name: StringName, new_level: int) -> void:
	pass  # Can be used for notifications later

func _on_skill_ranked_up(skill_id: StringName, new_rank: int) -> void:
	pass  # Can be used for notifications later

## Test method (commented, not executed by default)
## Demonstrates the XP system with all modifiers
#func _test_progression() -> void:
#	print("\n=== Character Progression Test ===\n")
#
#	# Create test attributes
#	print("Initial Attributes:")
#	print("  Might: Level %d" % get_attribute(&"Might"))
#	print("  Guile: Level %d" % get_attribute(&"Guile"))
#	print("  Intellect: Level %d" % get_attribute(&"Intellect"))
#	print("  Willpower: Level %d" % get_attribute(&"Willpower"))
#
#	# Create test skill
#	var test_skill: SkillSpec = SkillSpec.new()
#	test_skill.skill_id = &"Swordplay"
#	test_skill.display_name = "Swordplay"
#	test_skill.domain_id = &"Melee"
#	add_skill(test_skill)
#
#	print("\nCreated skill: %s (Rank %d)" % [test_skill.display_name, test_skill.current_rank])
#
#	# Example 1: Basic use
#	print("\n--- Example 1: Basic Use (event='use', difficulty=0.5) ---")
#	grant_skill_xp(&"Swordplay", "use", 0.5, 100)
#	print("  Skill Rank: %d (XP: %.1f/%.1f)" % [test_skill.current_rank, test_skill.current_xp, test_skill.xp_to_next_rank])
#	print("  Might Level: %d (%.1f%%)" % [get_attribute(&"Might"), get_attribute_progress(&"Might") * 100])
#	print("  Guile Level: %d (%.1f%%)" % [get_attribute(&"Guile"), get_attribute_progress(&"Guile") * 100])
#
#	# Example 2: Successful action
#	print("\n--- Example 2: Success (event='success', difficulty=0.8) ---")
#	grant_skill_xp(&"Swordplay", "success", 0.8, 100)
#	print("  Skill Rank: %d (XP: %.1f/%.1f)" % [test_skill.current_rank, test_skill.current_xp, test_skill.xp_to_next_rank])
#	print("  Might Level: %d (%.1f%%)" % [get_attribute(&"Might"), get_attribute_progress(&"Might") * 100])
#	print("  Guile Level: %d (%.1f%%)" % [get_attribute(&"Guile"), get_attribute_progress(&"Guile") * 100])
#
#	# Example 3: Challenge (high multiplier)
#	print("\n--- Example 3: Challenge (event='challenge', difficulty=1.0) ---")
#	grant_skill_xp(&"Swordplay", "challenge", 1.0, 100)
#	print("  Skill Rank: %d (XP: %.1f/%.1f)" % [test_skill.current_rank, test_skill.current_xp, test_skill.xp_to_next_rank])
#	print("  Might Level: %d (%.1f%%)" % [get_attribute(&"Might"), get_attribute_progress(&"Might") * 100])
#	print("  Guile Level: %d (%.1f%%)" % [get_attribute(&"Guile"), get_attribute_progress(&"Guile") * 100])
#
#	# Example 4: Difficulty modifier demonstration
#	print("\n--- Example 4: Difficulty Modifier Comparison ---")
#	var easy_xp: int = XPCalculator.apply_difficulty_modifier(100, 0.1)
#	var medium_xp: int = XPCalculator.apply_difficulty_modifier(100, 0.5)
#	var hard_xp: int = XPCalculator.apply_difficulty_modifier(100, 1.0)
#	print("  Easy task (0.1): %d XP" % easy_xp)
#	print("  Medium task (0.5): %d XP" % medium_xp)
#	print("  Hard task (1.0): %d XP" % hard_xp)
#
#	# Example 5: Challenge modifier demonstration
#	print("\n--- Example 5: Challenge Modifier (task vs. attribute level) ---")
#	var trivial: int = XPCalculator.apply_challenge_modifier(100, 5, 2.0)
#	var sweet_spot: int = XPCalculator.apply_challenge_modifier(100, 5, 4.0)
#	var very_hard: int = XPCalculator.apply_challenge_modifier(100, 5, 8.0)
#	print("  Trivial (level 5 doing diff 2): %d XP" % trivial)
#	print("  Sweet spot (level 5 doing diff 4): %d XP" % sweet_spot)
#	print("  Very hard (level 5 doing diff 8): %d XP" % very_hard)
#
#	# Example 6: Soft cap demonstration
#	print("\n--- Example 6: Soft Cap Penalties ---")
#	var level_3: int = XPCalculator.apply_attribute_level_penalty(100, 3)
#	var level_7: int = XPCalculator.apply_attribute_level_penalty(100, 7)
#	var level_12: int = XPCalculator.apply_attribute_level_penalty(100, 12)
#	print("  Level 3 (no cap): %d XP" % level_3)
#	print("  Level 7 (80%% cap): %d XP" % level_7)
#	print("  Level 12 (30%% + decay): %d XP" % level_12)
#
#	# Example 7: Save/Load test
#	print("\n--- Example 7: Save/Load Test ---")
#	var save_data: Dictionary = to_dict()
#	print("  Saved data keys: %s" % save_data.keys())
#	print("  Attributes in save: %s" % save_data["attributes"].keys())
#	print("  Skills in save: %s" % save_data["skills"].keys())
#
#	# Create new character and load
#	var loaded_char: CharacterProgression = CharacterProgression.new()
#	loaded_char.from_dict(save_data)
#	print("  Loaded Might Level: %d" % loaded_char.get_attribute(&"Might"))
#	print("  Loaded Skill Rank: %d" % loaded_char.get_skill(&"Swordplay").current_rank)
#
#	print("\n=== Test Complete ===\n")
