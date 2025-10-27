# res://tests/test_save_load.gd
extends Node

## Test script for verifying save/load system with ProgressionManager integration
## Usage: Attach to a Node in a test scene and run

func _ready() -> void:
	print("\n=== Save/Load System Test ===\n")

	# Wait one frame for singletons to initialize
	await get_tree().process_frame

	run_test()


func run_test() -> void:
	print("Step 1: Creating test character with skills")

	# Create a test character sheet
	var test_char: CharacterSheet = CharacterSheet.new()
	test_char.character_name = "Test Governor"
	test_char.level = 5

	# Set some attribute levels (would normally use add_attribute_xp)
	test_char.attributes.set_attribute_level(&"Might", 3)
	test_char.attributes.set_attribute_level(&"Intellect", 4)

	# Create test skills
	var skill1: SkillSpec = SkillSpec.new()
	skill1.skill_id = &"quality_tools"
	skill1.current_rank = 5
	skill1.current_xp = 250.0
	test_char.skills[&"quality_tools"] = skill1

	var skill2: SkillSpec = SkillSpec.new()
	skill2.skill_id = &"industrial_planning"
	skill2.current_rank = 3
	skill2.current_xp = 100.0
	test_char.skills[&"industrial_planning"] = skill2

	print("  Character: %s (Level %d)" % [test_char.character_name, test_char.level])
	print("  Might: %d, Intellect: %d" % [test_char.get_attribute_level(&"Might"), test_char.get_attribute_level(&"Intellect")])
	print("  QualityTools: Rank %d (%.1f XP)" % [skill1.current_rank, skill1.current_xp])
	print("  IndustrialPlanning: Rank %d (%.1f XP)" % [skill2.current_rank, skill2.current_xp])

	print("\nStep 2: Registering character with ProgressionManager")
	ProgressionManager.register_character(&"test_governor_001", test_char)

	print("\nStep 3: Modifying GameState values")
	GameState.fuel = 75.5
	GameState.rations = 42.3
	print("  Fuel: %.1f, Rations: %.1f" % [GameState.fuel, GameState.rations])

	print("\nStep 4: Saving game...")
	var save_success: bool = GameState.save_game("user://test_save.json")
	if save_success:
		print("  ✓ Save successful")
	else:
		print("  ✗ Save failed!")
		return

	print("\nStep 5: Clearing data (simulating fresh load)")
	ProgressionManager.unregister_character(&"test_governor_001")
	GameState.fuel = 0.0
	GameState.rations = 0.0
	print("  Fuel: %.1f, Rations: %.1f" % [GameState.fuel, GameState.rations])
	print("  Characters in PM: %d" % ProgressionManager.character_sheets.size())

	print("\nStep 6: Loading game...")
	var load_success: bool = GameState.load_game("user://test_save.json")
	if load_success:
		print("  ✓ Load successful")
	else:
		print("  ✗ Load failed!")
		return

	print("\nStep 7: Verifying loaded data")
	print("  Fuel: %.1f (expected 75.5)" % GameState.fuel)
	print("  Rations: %.1f (expected 42.3)" % GameState.rations)

	var loaded_char: CharacterSheet = ProgressionManager.get_character_sheet(&"test_governor_001")
	if loaded_char == null:
		print("  ✗ Character not found!")
		return

	print("  Character: %s (Level %d)" % [loaded_char.character_name, loaded_char.level])
	print("  Might: %d (expected 3)" % loaded_char.get_attribute_level(&"Might"))
	print("  Intellect: %d (expected 4)" % loaded_char.get_attribute_level(&"Intellect"))

	var loaded_skill1: SkillSpec = loaded_char.get_skill_spec(&"quality_tools")
	var loaded_skill2: SkillSpec = loaded_char.get_skill_spec(&"industrial_planning")

	if loaded_skill1:
		print("  QualityTools: Rank %d (%.1f XP) - expected Rank 5 (250.0 XP)" % [loaded_skill1.current_rank, loaded_skill1.current_xp])
	else:
		print("  ✗ QualityTools skill not found!")

	if loaded_skill2:
		print("  IndustrialPlanning: Rank %d (%.1f XP) - expected Rank 3 (100.0 XP)" % [loaded_skill2.current_rank, loaded_skill2.current_xp])
	else:
		print("  ✗ IndustrialPlanning skill not found!")

	# Verification
	var all_pass: bool = true
	all_pass = all_pass and abs(GameState.fuel - 75.5) < 0.1
	all_pass = all_pass and abs(GameState.rations - 42.3) < 0.1
	all_pass = all_pass and loaded_char != null
	all_pass = all_pass and loaded_char.character_name == "Test Governor"
	all_pass = all_pass and loaded_char.level == 5
	all_pass = all_pass and loaded_char.get_attribute_level(&"Might") == 3
	all_pass = all_pass and loaded_char.get_attribute_level(&"Intellect") == 4
	all_pass = all_pass and loaded_skill1 != null and loaded_skill1.current_rank == 5
	all_pass = all_pass and loaded_skill2 != null and loaded_skill2.current_rank == 3

	if all_pass:
		print("\n✓ ALL TESTS PASSED")
	else:
		print("\n✗ SOME TESTS FAILED")

	print("\n=== Test Complete ===\n")

	# Show save file location
	print("Save file location: %s" % ProjectSettings.globalize_path("user://test_save.json"))
