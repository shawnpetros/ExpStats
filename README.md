# ExpStats 0.7.2

A small Ashita v4 companion overlay for an existing EXP bar. It displays:

- Session EXP per hour (timing begins on the first EXP gain)
- EXP from the last kill
- Rolling average of the last three EXP gains
- Rolling average of the last ten EXP gains, shown after Avg(3)
- EXP remaining to the next level (`TNL`)
- Estimated time to level at the current session EXP/hour (`ETA`)
- EXP earned while the `Dedication` effect is active, shown beside ETA

After 20 minutes without an EXP gain, the next gain automatically starts a fresh session.
EXP/hour remains `--` until the second gain, avoiding a meaningless first-kill spike.
ETA is rounded up and shown as minutes below one hour, then hours and minutes (for example, `42m` or `1h 18m`). It remains `--` until a meaningful EXP/hour rate exists.
The Band counter appears only while the client reports the `Dedication` status effect. It starts at zero when the effect is detected, counts awarded EXP while active, and disappears when the effect wears. It intentionally reports total EXP earned rather than claiming an exact bonus remainder: multiple bands share the same status effect but have different bonus percentages and caps, which the client buff list does not identify.

## HorizonXI policy status

**Pending review — do not load on HorizonXI yet.** HorizonXI's live addon policy says unlisted custom addons are prohibited. Custom addons must be publicly hosted and submitted through a Community Team Ticket in Discord `#other-support` for review.

Policy: https://horizonxi.com/addons

This addon reads incoming `0x02D` action-message packets using the same local-player and field layout as XIUI's approved EXP bar. It recognizes normal EXP and EXP-chain message IDs, and reads the client's current/needed EXP values through Ashita's player memory API. On the explicit `/expstats partyreport` command, it queues one ordinary `/p` message containing the current statistics. It does not enumerate entities, inspect targets, write memory, send packets, access the network, or automate gameplay actions.

## Install after approval

Extract `ExpStats/` into Ashita's `addons/` directory, then run:

    /addon load ExpStats

## Commands

- `/expstats status` (alias `/xs`) — print current statistics
- `/expstats partyreport` (short form `/expstats party`) — post the current statistics to party chat
- `/expstats show` / `/expstats hide`
- `/expstats move` — unlock/lock the draggable window
- `/expstats reset` — start a fresh session
- `/expstats test` — load ten deterministic test values from 100 through 190

Settings persist per Ashita's stock settings library. Session EXP does not persist across addon/game restarts.

Window coordinates are saved when `/expstats move` is used to lock the window and restored on the first rendered frame after a reload or restart.

ExpStats respects both Ashita's global custom-UI visibility and FFXI's native ScrollLock interface toggle. Pressing ScrollLock temporarily hides or restores ExpStats without changing its saved `/expstats show|hide` setting. Reload ExpStats while the native interface is visible so its initial toggle state is synchronized.

## Review scope

- `ExpStats.lua`: Ashita events, commands, settings, and ImGui overlay
- `core.lua`: message cleaning/parsing and arithmetic
- No bundled binaries or network access
