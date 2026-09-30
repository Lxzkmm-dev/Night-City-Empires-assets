# Lxzkmm's common resources

Shared pieces for Cyberpunk 2077 mods, by Lxzkmm.

## TerminalKit (`r6/scripts/TerminalKit`)

A redscript framework for full in-game terminal UIs: native, no CET, built by describing pages as rows instead of placing widgets.

- **A ready-made frame** (`TKPopup`): subclass it, give it your pages, open it from a key. Lens tint, sidebar tabs, a scrolling page, tooltips, right click back, Esc close.
- **About 35 row types**: headings, pairs, meters, tracks, level tracks, items and buttons, financial ledgers, departures boards, listing cards, stat and market tiles with sparklines, dossiers, feed entries, message threads, columns and sections.
- **Controls**: text boxes, search, sliders, drop-downs, check boxes, sortable and paged tables, confirm dialogs, live countdowns and progress bars on game time.
- **A pan-and-zoom map** (`TKMap`): your images and tile layers, regions with outlines and tints, pins that open pages, toggles, a legend.
- **HUD pieces** (`TKHud`): tracker strips with a direction track and distance, toast cards.
- **Palettes** (the game's own colours, Kiroshi, Arasaka, Militech, NetWatch, mono) and a pluggable size scale for a live UI tuner.

`r6/scripts/TerminalKit/README.md` documents it.

## TerminalKit Tools (`r6/scripts/TerminalKitTools`, optional)

Developer pages for any TerminalKit terminal: a position logger, a route recorder, a look-at inspector, a spawn tester, a TweakDB browser and a log console. `r6/scripts/TerminalKitTools/README.md` shows how to plug them in.

## Example (`examples/HelloTerminal`)

A complete little mod: K opens a terminal with a home page, the controls, a map and the dev tools. Copy it to start your own.

Requires redscript, Codeware and RedFunctions (and Input Loader for the example's key).

Built for and used by Night City Empires' Fixer Link.

## Branches

- `main`: the framework, nothing mod-specific.
- `nce-assets`: the images Night City Empires fetches at runtime (the Fixer Net icon).
