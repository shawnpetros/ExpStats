# ExpStats 0.4.2

A small Ashita v4 companion overlay for an existing EXP bar. It displays:

- Session EXP per hour (timing begins on the first EXP gain)
- EXP from the last kill
- Rolling average of the last three EXP gains
- Rolling average of the last ten EXP gains, shown after Avg(3)

After 20 minutes without an EXP gain, the next gain automatically starts a fresh session.
EXP/hour remains `--` until the second gain, avoiding a meaningless first-kill spike.

## HorizonXI policy status

**Pending review — do not load on HorizonXI yet.** HorizonXI's live addon policy says unlisted custom addons are prohibited. Custom addons must be publicly hosted and submitted through a Community Team Ticket in Discord `#other-support` for review.

Policy: https://horizonxi.com/addons

This addon reads incoming `0x02D` action-message packets using the same local-player and field layout as XIUI's approved EXP bar. It recognizes normal EXP and EXP-chain message IDs. It does not enumerate entities, inspect targets, write memory, send packets, access the network, or automate actions.

## Install after approval

Extract `ExpStats/` into Ashita's `addons/` directory, then run:

    /addon load ExpStats

## Commands

- `/expstats status` (alias `/xs`) — print current statistics
- `/expstats show` / `/expstats hide`
- `/expstats move` — unlock/lock the draggable window
- `/expstats reset` — start a fresh session
- `/expstats test` — load ten deterministic test values from 100 through 190

Settings persist per Ashita's stock settings library. Session EXP does not persist across addon/game restarts.

Window coordinates are saved when `/expstats move` is used to lock the window and restored on the first rendered frame after a reload or restart.

## Review scope

- `ExpStats.lua`: Ashita events, commands, settings, and ImGui overlay
- `core.lua`: message cleaning/parsing and arithmetic
- No bundled binaries or network access
