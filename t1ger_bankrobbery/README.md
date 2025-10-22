# T1GER BANK ROBBERY

## SHOWCASE:
https://youtu.be/a1pgPkVVKvE

## CFX FORUM POST:
https://forum.cfx.re/t/esx-t1ger-bank-robbery-unique-features-8-pre-configured-banks-minigames-and-much-more/4774063

## FRAMEWORK:
- [QBCore](https://github.com/qbcore-framework)

## DEPENCENCIES:
- [`ox_lib` (REQUIRED)](https://github.com/overextended/ox_lib)
- [`oxmysql` (REQUIRED)](https://github.com/overextended/oxmysql)
- [`qb-core` (REQUIRED)](https://github.com/qbcore-framework/qb-core)
- [mHacking (OPTIONAL)](https://github.com/justgreatgaming/FiveM-Scripts-2/tree/master/mhacking)
- [uTKU Finger Print (OPTIONAL)](https://github.com/utkuali/Finger-Print-Hacking-Game)
- [progressBars (OPTIONAL)](https://gitlab.com/t1ger-scripts/t1ger-requirements/-/tree/main/progressBars)

## ENTRY POINTS
- **Client:** `client/main.lua` bootstraps interaction zones, synchronization handlers and power box timers. Supporting logic for animations and minigames lives in `client/drilling.lua`, `client/safecrack.lua`, and shared helpers in `client/utils.lua`.
- **Server:** `server/main.lua` exposes every network event, inventory validation, reward payout and synchronization callback. The server is responsible for anti-abuse checks, cooldown resets and broadcasting heist state back to clients.

## DOCUMENTATION:
https://docs.t1ger.net/free-resources/t1ger-bank-robbery

## DISCORD:
https://discord.gg/FdHkq5q
