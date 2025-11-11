# Changelog

## [Unreleased]
- Updated police headcounts in `t1ger_bankrobbery` and `t1ger_keys` to use QBCore's duty tracking helpers instead of iterating all players.
- Normalised boss detection across deliveries, insurance, and tow trucker scripts to honour the `job.isBoss` flag while retaining legacy fallbacks.
- Replaced the chop shop vehicle list generator with a deterministic shuffle and migrated notifications to `ox_lib` helpers.
- Rebuilt `t1ger_deliveries` client utilities into a single, consistent module with ox_lib-powered helpers and job listeners.
- Optimised `t1ger_garage` spawn checks using `lib.getClosestVehicle` and added native support for `ox_fuel` when present.
- Moved gold currency job assignment to secure server callbacks, introduced global job state tracking, and hardened reward cleanup.
- Normalised random number seeding in the heist prep scripts and replaced tight loops with seeded helper utilities.
- Migrated the insurance menu hotkey to `RegisterKeyMapping` with language support for the binding label.
- Exposed on-demand police duty callbacks for the key resource and removed the background polling thread.
- Added native `ox_inventory` compatibility and disconnect cleanup to the miner job server logic.
- Routed pawnshop transactions through a single guarded server callback and enhanced client messaging.
- Improved shop blip updates, preserved stateful blips, and exposed boss/cashier interactions through `ox_target` zones.
