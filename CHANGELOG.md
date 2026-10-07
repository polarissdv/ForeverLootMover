# ForeverLootMover - Changelog

## 1.0
- **First version.** The group loot roll bars can be put anywhere on the screen,
  at any size between 50 % and 300 %, stacking up or down with the gap you
  choose.
- **The bars themselves are left alone.** Nothing is redrawn or reskinned: the
  roll bar keeps the look this client gives it.
- **A test button**: two of the game's own roll bars, borrowed and filled with
  a real item, so the placement is judged on the real frame rather than on a
  lookalike. Their scripts are taken off and their buttons go deaf for the
  length of the test, so nothing is ever asked of the loot API about a roll that
  is not happening, and they are handed back untouched after thirty seconds, on
  a second click, or the moment a real roll starts.
- **A placement frame in the usual World of Warcraft look** - stone border, gold
  title, an arrow for the stacking direction - showing the exact footprint the
  bar will take, so the spot can be chosen from a town instead of waiting for a
  dungeon to hand out loot. Drag it, wheel over it to resize, right-click when
  it is good.
- **The "You received" toast lands in the same spot.** It belongs to the game's
  alert system, not to the roll bars, so it is handled on its own: the alert
  subsystems are told to measure from our anchor, and failing that the alert
  host frame is pinned to it. Optional.
- **The fourth square is taken off the bar.** This build draws a transmog
  button next to need, greed and pass; it is hidden on every pass, since the
  game puts it back on every roll. The buttons are not children of the bar but
  of a container inside it, so the whole little tree is walked, and each button
  is read by the art it wears - this build names its atlases by role
  (lootroll-toast-icon-need-up, -greed-up, -transmog-up), older ones use the
  UI-GroupLoot-Dice / Coin / Pass files, and both are understood. Only what is
  positively recognised as transmog or disenchant is hidden: a roll button whose
  art says nothing is kept, because an unknown button on the bar is better than
  a missing need or greed.
- **Smooth and alive.** A bar is placed in the very frame it is shown - the
  OnShow hook does the work right there instead of waiting for the next frame -
  so it never flashes at its default spot first, and it fades in over a sixth of
  a second. The bars are each pinned to the anchor at their own offset rather
  than chained to one another, so when a roll ends the ones left slide into
  their new slot instead of snapping. The driver only runs while something is
  actually moving.
- **Nothing is hooked by name.** The bars are found by name, then through the
  loot container, then by looking for any frame holding a roll; their own
  SetPoint is hooked on the object itself, and a watchdog re-checks the layout
  five times a second while a roll is on screen. That is the part the older
  movers get wrong on Forever: they hook Blizzard functions that this client no
  longer has, so they quietly do nothing.
- **Settings survive a restart** through the CVar and macro copies used by the
  other Forever addons, so the position is not lost to the beta saving bug.
- **Options menu** in the World of Warcraft style, English and French, with a
  minimap button and an addon compartment entry.
- **`/flm scan`** lists the loot frames the current build actually has, so a
  future patch can be sorted out quickly.
