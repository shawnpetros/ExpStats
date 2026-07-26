# ExpStats 0.1.0

A small Ashita v4 companion overlay for an existing EXP bar. It displays:

- Session EXP per hour (total EXP since load/reset divided by elapsed session time)
- EXP from the last kill
- Rolling average of the last three EXP gains

## HorizonXI policy status

**Pending review — do not load on HorizonXI yet.** HorizonXI's live addon policy says unlisted custom addons are prohibited. Custom addons must be publicly hosted and submitted through a Community Team Ticket in Discord `#other-support` for review.

Policy: https://horizonxi.com/addons

This addon only reads local incoming chat messages matching `You gain N experience points.` It does not inspect entities, memory, targets, packets, or perform automation.

## Install after approval

Extract `ExpStats/` into Ashita's `addons/` directory, then run:

    /addon load ExpStats

## Commands

- `/expstats status` (alias `/xs`) — print current statistics
- `/expstats show` / `/expstats hide`
- `/expstats move` — unlock/lock the draggable window
- `/expstats reset` — start a fresh session
- `/expstats test` — load deterministic 120/150/180 test values

Settings persist per Ashita's stock settings library. Session EXP does not persist across addon/game restarts.

## Review scope

- `ExpStats.lua`: Ashita events, commands, settings, and ImGui overlay
- `core.lua`: message cleaning/parsing and arithmetic
- No bundled binaries or network access
