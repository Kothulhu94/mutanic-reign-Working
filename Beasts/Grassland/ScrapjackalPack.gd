class_name ScrapjackalPack extends Beast

## T1 Grassland - Scrapjackal Pack
## Fast nippers with modest damage and low staying power
## Future: +25% resource detection radius (scrap, parts)

const BASE_HEALTH: int = 15
const BASE_DAMAGE: int = 6
const BASE_DEFENSE: int = 2

func _ready() -> void:
	super._ready()
	initialize_charactersheet(BASE_HEALTH, BASE_DAMAGE, BASE_DEFENSE)
	movement_speed = 90.0
	ai_behavior = "roam"
