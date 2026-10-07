<div align="center">

<img src="Media/logo.png" width="200" alt="ForeverLootMover logo">

# ForeverLootMover

**Move, resize and stack the group loot roll bars in World of Warcraft: Forever.**

![Version](https://img.shields.io/badge/version-1.0-9966ff)
![Interface](https://img.shields.io/badge/WoW%3A%20Forever-1.60.x%20(16001)-c8a14a)
[![Support](https://img.shields.io/badge/Support-TipeeeStream-ff7b00)](https://www.tipeeestream.com/polarzz88/)

</div>

---

The group loot roll bars appear in the middle of your screen, right on top of the boss you are
fighting and the raid frames you are watching. ForeverLootMover pins them wherever you want, at the
size you want, stacking in the direction you want — and keeps them there no matter how often the
game tries to put them back.

It is a rewrite of the idea behind LootRollMover, built from scratch for the Forever client. No
libraries, no dependencies.

## Why a new addon

The older movers hook the game's own loot functions by name (`GroupLootContainer_Update`,
`GroupLootFrame_OnShow`, …). The moment a build renames or rewrites that code, those hooks are
never called and the addon silently does nothing — which is what happens on Forever.

ForeverLootMover never looks up a Blizzard function by name:

- the roll bars are found by name, then by walking the loot container, then by looking for any frame
  holding a `rollID`;
- their **own** `SetPoint` is hooked on the object itself, so the addon is told whenever the game
  moves them, whatever code did it;
- a watchdog re-checks the layout five times a second while a roll is on screen, and only ever
  writes a position that is actually wrong — a layout that is already right costs nothing.

## Features

- **The game's own bars, untouched.** Nothing is redrawn or reskinned: the roll bar keeps the look
  this client gives it, it just lands where you put it.
- **No fourth square.** The transmog button this build draws next to need, greed and pass is taken
  off the bar, on every roll.
- **The loot toast follows.** The "You received" panel the game shows once an item is yours lands on
  the same spot as the roll bars, instead of somewhere else on the screen. Optional.
- **Smooth.** A bar appearing is placed in the same frame it is shown, so it never flashes at its
  default spot first, and it fades in; when a roll is over, the bars left slide into their new slot
  instead of snapping.
- **A test button.** Two of the game's own roll bars, borrowed and filled with a real item, so the
  size and the spot are judged on the real frame. They are inert — no roll is started, nothing can be
  clicked — and they are handed back after 30 seconds, on a second click, or the moment a real roll
  starts.
- **Place them from anywhere.** A stone frame in the usual World of Warcraft look shows the exact
  footprint the bar will take, with an arrow for the stacking direction — so the spot can be chosen
  standing in a town, without waiting for a dungeon to hand out loot.
- **Drag anywhere on the stack**, and the real bars follow while you drag.
- **Size from 50 % to 300 %**, with the mouse wheel over the preview or with the slider.
- **Stacking direction** — new rolls pile up above or below the first bar.
- **Gap between bars**, 0 to 30 px.
- **Settings that stick** — position, size and options survive a reload, a relog and a full restart
  of the game, even with the Forever beta bug that resets other addons (see below).
- **Options menu** in the World of Warcraft style, in English and French.
- **Minimap button** and addon compartment entry.
- **`/flm scan`** prints what the current build actually has, so a future patch can be sorted out in
  minutes.

## Options menu

Open it from the **minimap button** (right-click) or with **`/flm options`**.

| Section | What you can change |
| --- | --- |
| General | Addon on / off, minimap button, keep the bars on screen, move the loot toast too, smooth movement |
| Position | Stacking direction, bar size, gap between bars, place the bars, test with an item, default position |

## Installation

1. Extract the `ForeverLootMover` folder into your WoW Forever `Interface\AddOns` directory:
   `World of Warcraft\_classic_beta_\Interface\AddOns\ForeverLootMover`
2. Launch the game. The folder **must** be named `ForeverLootMover`.

## Controls

- **`/flm`** shows the placement frame. **Drag** it where you want, **wheel** over it to resize,
  **right-click** it when you are done.
- **Left-click** the minimap button to show the placement frame.
- **Right-click** the minimap button to open the options.

## Slash commands

| Command | Description |
| --- | --- |
| `/flm` or `/lootmover` | Show / hide the placement frame |
| `/flm options` | Open the options menu |
| `/flm scale 120` | Size of the bars, in percent (50 to 300) |
| `/flm spacing 6` | Gap between two stacked bars, in pixels |
| `/flm up` / `/flm down` | Stacking direction |
| `/flm test` | Two real roll bars, filled with an item, for 30 seconds |
| `/flm minimap` | Show or hide the minimap button |
| `/flm reset` | Position back to the middle of the screen |
| `/flm resetall` | Every setting back to default |
| `/flm on` / `/flm off` | Turn the addon on or off |
| `/flm scan` | List the loot roll frames this build has |
| `/flm debug` | The scan, plus the state of the settings backup |

## About the Forever beta saving bug

During the WoW Forever beta, the client writes addon settings at logout but never reads them back
after a relog or a restart, so every addon starts from defaults. ForeverLootMover keeps two extra
copies of its settings:

- **Addon CVars** — they stay in memory while the game runs, which covers a relog. The client never
  writes them to disk, so they are gone once the game is closed.
- **One account macro named `ForeverLootMover`** — macros are stored by the server and are always
  there after a restart. It holds a single line of settings and does nothing if you click it. If you
  delete it, the addon puts it back a few seconds later.

At login, the most recent copy wins. When Blizzard fixes the bug, the normal saved variables take
over again — nothing to change.

## Turning it off

With the addon off, the game keeps the bars where they currently are until the next `/reload`, which
puts them back to their default spot. Nothing is permanently changed.

## Compatibility

- **World of Warcraft: Forever** — 1.60.x, Interface `16001`
- Works alongside any other addon that does not move the loot bars itself. If one does, the two will
  fight over the position — turn one of them off.

## Changelog

See [CHANGELOG.md](CHANGELOG.md).

## Support

ForeverLootMover is free, and it stays free and complete. If it got the roll bars out of your way
and you feel like saying thanks, you can leave a tip on
**[TipeeeStream](https://www.tipeeestream.com/polarzz88/)**. Entirely optional.

## License

Free to use and modify. If you share a modified version, please credit the original addon.

---

<div align="center">

Made by **Polarz141** · [Support me](https://www.tipeeestream.com/polarzz88/)

</div>
