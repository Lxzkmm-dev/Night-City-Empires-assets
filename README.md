# Lxzkmm's common resources

Shared pieces for Cyberpunk 2077 mods, by Lxzkmm.

## TerminalKit (`r6/scripts/TerminalKit`)

A redscript framework for in-game terminal UIs: a page model (headings, text,
pairs, meters, buttons, notes, items with level pips, tables, ledgers, cards,
tiles, tickers with sparklines, tracks, sliders, inputs, dossiers, columns,
custom rows), a renderer with scrolling, tooltips and page history (right mouse
button goes back), colour themes and a font scale. A mod supplies a frame (any
Codeware `inkCustomController`, an `InGamePopup` for example) and a content
provider that answers page requests; the kit draws the rest.

It is the engine behind Night City Empires' Fixer Link. `TerminalKit/README.md`
documents the pieces and shows a minimal frame.

Requires redscript, Codeware and RedFunctions.

## Branches

- `main`: the framework, nothing mod-specific.
- `nce-assets`: the images Night City Empires fetches at runtime (the Fixer Net icon).
