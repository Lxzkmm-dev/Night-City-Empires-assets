# TerminalKit

A redscript framework for full in-game terminal UIs in Cyberpunk 2077: native, no CET, built by describing pages as rows instead of placing widgets. It ships a ready-made frame, a page renderer with about 35 row types, controls, a pan-and-zoom map, HUD pieces and a small data kit. Night City Empires' Fixer Link runs on it, and the kit knows nothing about that mod.

Needs **Codeware** (popups, buttons, text boxes) and **RedFunctions** (mouse state, files, the TweakDB name table). Copy `r6/scripts/TerminalKit` into your mod and `import TerminalKit.*`. The optional dev tools live next to it in `r6/scripts/TerminalKitTools` (see its README).

## Start here: the ready-made frame

```
public class MyTerminal extends TKPopup {
  public func Content() -> ref<TKContent> = new MyContent()
  public func Tabs() -> array<String> = ["HOME|home", "CREW|crew"]
  public func Name() -> String = "MY TERMINAL"
}

public class MyContent extends TKContent {
  public func Request(p: ref<TKPage>, page: String, arg: String) -> Void {
    p.SetTitle("HOME", "Welcome back");
    p.Stat("EDDIES", "12,500", "*+2,100 today", 0.6);
    p.Item("A ROW WITH A BUTTON", "a detail line", "", "PRESS", "press", "", true);
  }
  public func Act(p: ref<TKPage>, action: String, arg: String) -> Void {
    if Equals(action, "press") { p.SetMessage("PRESSED"); }
  }
}

// from your key: if TKPopup.CanOpen(player) { TKPopup.Open(player, new MyTerminal()); }
```

`TKPopup` gives you a lens tint over the world, HUD corner brackets, a brand line, sidebar tabs, a scrolling page with a scroll bar, tooltips, a footer and a boot flicker. The wheel scrolls, the right mouse button goes back a page (closing a dialog or a list first), Esc closes. Override `Brand`, `Status`, `Footer`, `BootText`, `StartPage`, `CornerTab` (a button top right), `Lens`, the sizes, and the hooks `Setup` (before building), `Icon` (an image left of the brand), `Opened` (the first page), `Closing` and `Closed`. `examples/HelloTerminal` is a complete mod to copy.

### A look of your own

All optional; without them a frame looks as it always has.

- **Palette**: subclass `TKPalette` (`Id()`, `Color(role)` for `title`, `accent`, `text`, `value`, `frame`, `rule`) and call `TKTheme.Register(new MyPalette())` when the player attaches. Pick it with `p.SetTheme("my_id")`. `TKTheme.Ids()` lists the built-ins, then the registered ones.
- **Style**: override `TKPopup.Style()` to return a `TKStyle`: `frame` (0 brackets, 1 notched corners, 2 armoured double border), `rivets`, `hazard` (stripe blocks in two corners), `scanlines` (overlay opacity), `headerPlates` (headings on a dark plate), `segmentedBars` (meters and stat bars in N cells), `openSound` / `closeSound` / `selectSound`.
- **Its own numbers and texts**: `TKScale.Use(source)` is one slot shared by every mod. A frame that overrides `ScaleSource()` uses its own source while it is open; return `new TKScaleDefaults()` to keep the kit's numbers whatever another mod plugged in. With TerminalKit Tools, call `TKTools.UseFor(myHost)` before `TKTools.Request` / `Act` so each mod's tools use its own storage folder.
- **Boot**: `BootLines()` shows several lines one after another in place of `BootText()`; `BootSeconds()` sets how long they stay.

## Pages

A page is a title, a subtitle (hidden when empty), a status message and rows (`TKPage.reds`). Your `TKContent` fills it in `Request` and runs buttons in `Act` (set `p.GoTo`, `p.SetMessage`, `p.Rebuild()` or `p.skipRedraw`).

- **Text and layout**: `Heading`, `Text`, `Pair`, `Note`, `Gap`, `Columns` (two columns of pairs), `Column` / `EndColumns` (side by side), `Section` (collapsible), `Links` (a tab row), `Dossier` (a header with a stamp), `Entry` (a feed entry), `Message` (a chat bubble; yours on the right).
- **Values**: `Meter`, `Track` (a meter with named marks), `Levels` (an item with a level track), `Stat` and `Ticker` tiles (a sparkline), `Gauge` (a dial tile with a needle), `Stack` (a bar split into coloured parts, with a legend), `Tile` (opens something), `Card` (a listing with buttons), `Ledger` (financial table lines: head, group, line, total, net), `Board` (a departures board).
- **Character cards** (in a grid like cards, sized by `p.SetExtra("w:h")`): `File` (a personnel file: number, barcode and stamp, a mugshot frame with the initials, stat bars out of 10, lines, a quote, buttons), `Posting` (a job posting: post number and time left, title, client, tag chips, the pay beside an odds meter, lines, buttons), `Run` (a job in progress: a live bar from start to end with the percent and the time left).
- **Buttons**: `Button`, `Item` (text left, a button right), `Buttons` (several).
- **Controls**: `Input` (a text box), `Search` (a box and its button), `Slider`, `Dropdown`, `Check`, `Choice` (a selectable list entry, for a list beside its detail), `SortHead` and `Pager`; `TKSheet` builds a sortable, paged table for you.
- **Live**: `Countdown` and `Progress` update every second from game time without redrawing, and can run an action when they finish.
- **Custom**: `Custom(tag, ...)` is drawn by your provider's `Custom()`, which returns a `TKCustom` the view stops when the page goes (the map is one).

Marks in text: a leading `!` shows red, `*` green (neither is shown), `+` amounts green; on boards `^` bright yellow and `~` grey. Button labels: `!` disables, `?` asks first ("?SELL ALL" shows a dialog). From `Act`, `p.Confirm(question, yes, action, arg)` asks before running something. `p.SetTip(text)` gives the row just added a tooltip on its title.

Action rows split their buttons once, typed: `row.labels`, `row.actions`, `row.args`. String builders take `"A|B"` labels, `"a|b"` actions and `"x|y"` args (or `"x\ny"` when an arg holds `|`). Controls hand their value on as `arg + ":" + value` (just the value when the row's arg is empty).

## The map (`TKMap`)

Describe it with a `TKMapSpec` (the map square in world units, a base image, tile layers per zoom level with `%C` / `%R` in the path, regions with rings, labels and tint masks, pins with letters, colours, links and groups, toggles, a legend) and draw it from your `Custom()` with `TKMap.Place(v, parent, spec, w, h)`. Drag with the left or middle button, scroll to zoom on the cursor, click a region to select it or a pin to open its page. A new view redraws the page through the spec's link (`%D` region, `%Z` zoom, `%M` toggle bits, `%X` / `%Y` the centre).

## HUD pieces (`TKHud`)

On the game's HUD layer, stacked at the top centre, in a TerminalKit palette:
- `TKHud.Strip(id, width)`: a tracker you keep up while it matters: `Set(title, right, sub)`, `Target(pos)` (a direction track that follows V's facing, and the distance), `Warn(on)`, `Fraction(f)` (a draining bar), `Show()` / `Hide()`.
- `TKHud.Toast(kicker, title, line, highlight, text, items, secs, bad)`: a card for a few seconds.

## Data

- `TKClock.Now()` (game seconds) and `TKClock.Left(secs)` ("2h 05m").
- `TKSheet`: add lines, `Show(p, col, desc, page, per, sortAction, pageAction, arg)`.
- `TKLog.Add(tag, text)`: a session log the Tools' console shows and saves.

## Pieces

`TKPage` (page model, row kinds, `TKContent`, `TKCustom`, `TKFrame`), `TKView` (renderer: scrolling, history, overlay for tooltips, dialogs and lists, live rows, sliders, text boxes), `TKRows` / `TKTables` / `TKTiles` / `TKControls` (components), `TKPopup` (the frame), `TKMap`, `TKHud`, `TKData`, `TKTheme` (palettes by role: `hud` follows the game's colours, plus kiroshi, arasaka, militech, netwatch, mono), `TKScale` (layout numbers and texts by key, from a `TKScaleSource` you can plug in with `TKScale.Use`), `TKInk` (widget builders), `TKButton`.

Add a row kind: a builder in `TKPage`, a case in `TKView.Draw`, a draw function.

## Conventions

- The canvas is 4K-sized and shrunk to the screen: 3000 x 1500 for the frame, a 2300-wide page.
- Ink blends premultiplied in linear light: colours brighter than white bloom, so `TKTheme.C` caps at white.
- Only unbind a style binding that exists; `TKTheme.Paint` handles that (unbinding on a fresh widget crashed the game).
- The right mouse button is also the popup's close action; `TKPopup` keeps its release for going back.
