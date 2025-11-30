# CaravanSkillSystem.gd
extends Node
class_name CaravanSkillSystem

## Manages skills, XP awards, and bonuses for a Caravan.
## Handles interaction with the leader's CharacterSheet.

var caravan_state: CaravanState

# Calculated bonuses
var price_modifier_bonus: float = 0.0
var speed_bonus: float = 0.0
var capacity_bonus: float = 0.0

func setup(state: CaravanState) -> void:
	caravan_state = state
	if caravan_state != null and caravan_state.leader_sheet != null:
		_initialize_trading_skills()
		recalculate_bonuses()

func recalculate_bonuses() -> void:
	if caravan_state == null or caravan_state.leader_sheet == null:
		return
		
	var sheet: CharacterSheet = caravan_state.leader_sheet
	
	# Reset
	price_modifier_bonus = 0.0
	speed_bonus = 0.0
	capacity_bonus = 0.0
	
	# NegotiationTactics
	var neg_spec: SkillSpec = sheet.get_skill_spec(&"negotiation_tactics")
	if neg_spec != null and neg_spec.current_rank > 0:
		var skill: Skill = Skills.get_skill(&"negotiation_tactics")
		if skill != null:
			price_modifier_bonus = skill.get_effect_at_rank(neg_spec.current_rank)
			
	# MasterMerchant
	var merch_spec: SkillSpec = sheet.get_skill_spec(&"master_merchant")
	if merch_spec != null and merch_spec.current_rank > 0:
		var skill: Skill = Skills.get_skill(&"master_merchant")
		if skill != null:
			price_modifier_bonus += skill.get_effect_at_rank(merch_spec.current_rank)
			
	# CaravanLogistics
	var log_spec: SkillSpec = sheet.get_skill_spec(&"caravan_logistics")
	if log_spec != null and log_spec.current_rank > 0:
		var skill: Skill = Skills.get_skill(&"caravan_logistics")
		if skill != null:
			var val: float = skill.get_effect_at_rank(log_spec.current_rank)
			speed_bonus = val
			capacity_bonus = val
			
	# EstablishedRoutes
	var route_spec: SkillSpec = sheet.get_skill_spec(&"established_routes")
	if route_spec != null and route_spec.current_rank > 0:
		var skill: Skill = Skills.get_skill(&"established_routes")
		if skill != null:
			capacity_bonus += skill.get_effect_at_rank(route_spec.current_rank)
			
	# EconomicDominance
	var dom_spec: SkillSpec = sheet.get_skill_spec(&"economic_dominance")
	if dom_spec != null and dom_spec.current_rank > 0:
		price_modifier_bonus += 1.0
		speed_bonus += 0.5
		capacity_bonus += 0.5
		
	# MarketMonopoly
	var mono_spec: SkillSpec = sheet.get_skill_spec(&"market_monopoly")
	if mono_spec != null and mono_spec.current_rank > 0:
		price_modifier_bonus += 0.4

func award_xp(skill_id: StringName, value: float) -> void:
	if caravan_state == null or caravan_state.leader_sheet == null:
		return
		
	var spec: SkillSpec = caravan_state.leader_sheet.get_skill_spec(skill_id)
	if spec == null:
		return
		
	var def: Skill = Skills.get_skill(skill_id)
	if def == null:
		return
		
	# 1 XP per 100 PACs
	var xp: float = value / 100.0
	if xp > 0.0:
		spec.current_xp += xp
		
		# Rank up check
		while spec.current_rank < def.max_rank:
			var needed: int = def.get_xp_for_rank(spec.current_rank + 1)
			if needed <= 0 or spec.current_xp < float(needed):
				break
			spec.current_xp -= float(needed)
			spec.current_rank += 1
			
			# Recalculate on rank up
			recalculate_bonuses()

func _initialize_trading_skills() -> void:
	if caravan_state == null or caravan_state.leader_sheet == null:
		return
		
	var skills: Array[StringName] = [
		&"market_analysis", &"caravan_logistics", &"negotiation_tactics",
		&"market_monopoly", &"established_routes", &"master_merchant",
		&"economic_dominance"
	]
	
	for s in skills:
		caravan_state.leader_sheet.add_skill(s, Skills.database)
