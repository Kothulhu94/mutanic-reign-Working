# Hub.gd Refactoring Task

## Analysis Complete
- [x] Analyze Hub.gd structure (692 lines, 25+ functions)
- [x] Identify functional areas and dependencies
- [x] Map external dependencies (Bus, TroopDatabase, Timekeeper, etc.)

## Planning
- [ ] Create implementation plan
- [ ] Get user approval on component split

## Component Extraction
- [ ] Create HubEconomyManager component (economy tick, inventory)
- [ ] Create HubTradingSystem component (buy/sell API, pricing)
- [ ] Create HubTroopProduction component (troop production logic)
- [ ] Create HubUIController component (UI signal handling)
- [ ] Create HubBuildingManager component (building placement/management)

## Integration
- [ ] Update Hub.gd to use new components
- [ ] Wire component dependencies
- [ ] Test all functionality preserved

## Verification
- [ ] Test economy system
- [ ] Test trading with caravans
- [ ] Test UI flow (menu, market, recruitment)
- [ ] Test troop production
- [ ] Test building placement
- [ ] Verify no lost functionality
