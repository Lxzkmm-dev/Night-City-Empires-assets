# Lxzkmm's common resources

Shared pieces for Cyberpunk 2077 mods, by Lxzkmm.

## TerminalKit (`r6/scripts/TerminalKit/TerminalKit.reds`)

A redscript framework for full in-game terminal UIs: native, no CET, built by describing pages as rows instead of placing widgets.

- **A ready-made frame** (`TKPopup`): subclass it, give it your pages, open it from a key. Lens tint, sidebar tabs, a scrolling page, tooltips, right click back, Esc close.
- **About 35 row types**: headings, pairs, meters, tracks, level tracks, items and buttons, financial ledgers, departures boards, listing cards, stat and market tiles with sparklines, dossiers, feed entries, message threads, columns and sections.
- **Controls**: text boxes, search, sliders, drop-downs, check boxes, sortable and paged tables, confirm dialogs, live countdowns and progress bars on game time.
- **A pan-and-zoom map** (`TKMap`): your images and tile layers, regions with outlines and tints, pins that open pages, toggles, a legend.
- **HUD pieces** (`TKHud`): tracker strips with a direction track and distance, toast cards.
- **Palettes** (the game's own colours, Kiroshi, Arasaka, Militech, NetWatch, mono) and a pluggable size scale for a live UI tuner.
- **The game's own pieces** (1.0): its data worded the game's way (district, money, level, street cred, clock, distances in the player's units), its notifications, its key prompts and pins on its map.

Version 1.1, which adds console layouts: panes, overlays, keycaps, console rows, map clicks and controller navigation. Mods can check the installed kit with `TKVersion.AtLeast(1, 1)`.

The reference is below.

## TerminalKit Tools (`r6/scripts/TerminalKitTools/TerminalKitTools.reds`, optional)

Developer pages for any TerminalKit terminal: a position logger, a route recorder, a look-at inspector, a spawn tester, a TweakDB browser and a log console. The reference below shows how to plug them in.

## Example (`examples/HelloTerminal`)

A complete little mod: K opens a terminal with a home page, the controls, the game's own data, messages and pins, a map and the dev tools. Copy it to start your own.

Requires redscript, Codeware and RedFunctions (and Input Loader for the example's key).

Built for Night City Empires' Fixer Link and Mechs of Night City's Robot Link. Until Night City Empires is out, TerminalKit ships with Mechs of Night City.

## Branches

- `main`: the framework, nothing mod-specific.
- `nce-assets`: the images Night City Empires fetches at runtime (the Fixer Net icon).

# TerminalKit reference

A redscript framework for full in-game terminal UIs in Cyberpunk 2077: native, no CET, built by describing pages as rows instead of placing widgets. It ships a ready-made frame, a page renderer with about 35 row types, controls, a pan-and-zoom map, HUD pieces and a small data kit. Night City Empires' Fixer Link runs on it, and the kit knows nothing about that mod.

Needs **Codeware** (popups, buttons, text boxes) and **RedFunctions** (mouse state, files, the TweakDB name table). The kit is one file, `r6/scripts/TerminalKit/TerminalKit.reds`: copy it into your mod and `import TerminalKit.*`. The optional dev tools are one more file, `r6/scripts/TerminalKitTools/TerminalKitTools.reds` (see TerminalKit Tools below).

### Start here: the ready-made frame

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

**With a controller**, the d-pad moves a highlight through the page's buttons, controls and hit areas in the order they were drawn. Select (or A) runs the highlighted one. The bumpers move to the next pane in a layout, or to the next sidebar tab without one. A mouse click takes the highlight away. Dialogs and drop-down lists still need the mouse, and the highlight doesn't scroll a long pane yet.

`TKPopup` gives you a lens tint over the world, HUD corner brackets, a brand line, sidebar tabs, a scrolling page with a scroll bar, tooltips, a footer and a boot flicker. The wheel scrolls, the right mouse button goes back a page (closing a dialog or a list first), Esc closes. Override `Brand`, `Status`, `Footer`, `BootText`, `StartPage`, `CornerTab` (a button top right), `Lens`, the sizes, and the hooks `Setup` (before building), `Icon` (an image left of the brand), `Opened` (the first page), `Closing` and `Closed`. `examples/HelloTerminal` is a complete mod to copy.

### A look of your own

All optional; without them a frame looks as it always has.

- **Palette**: subclass `TKPalette` (`Id()`, `Color(role)` for `title`, `accent`, `text`, `value`, `frame`, `rule`) and call `TKTheme.Register(new MyPalette())` when the player attaches. Pick it with `p.SetTheme("my_id")`. `TKTheme.Ids()` lists the built-ins, then the registered ones.
- **Style**: override `TKPopup.Style()` to return a `TKStyle`: `frame` (0 brackets, 1 notched corners, 2 armoured double border), `rivets`, `hazard` (stripe blocks in two corners), `scanlines` (overlay opacity), `headerPlates` (headings on a dark plate), `segmentedBars` (meters and stat bars in N cells), `openSound` / `closeSound` / `selectSound` / `denySound` (a disabled button pressed), `fontFamily` (an `.inkfontfamily` path used for every text and button while the frame is open) and `fontStyle` (one style for everything, for a family that lacks Regular / Medium / Semi-Bold).
- **Its own numbers and texts**: `TKScale.Use(source)` is one slot shared by every mod. A frame that overrides `ScaleSource()` uses its own source while it is open; return `new TKScaleDefaults()` to keep the kit's numbers whatever another mod plugged in. With TerminalKit Tools, call `TKTools.UseFor(myHost)` before `TKTools.Request` / `Act` so each mod's tools use its own storage folder.
- **Boot**: `BootLines()` shows several lines one after another in place of `BootText()`; `BootSeconds()` sets how long they stay.
- **Key prompts**: override `Hints()` with `"action|LABEL"` pairs (`["back|CLOSE"]`) and the footer becomes the game's own button-hint bar, each prompt showing the key or pad button the player bound to that input action. Without it the footer is the `Footer()` text.

### The game's own pieces (1.0)

Read from or fed to the game the way the game itself does it, so they match what players already see. All safe to call before a save is loaded.

- **`TKVersion`**: `Major()`, `Minor()`, `Text()` ("1.0") and `AtLeast(major, minor)`, so a mod can tell a player their TerminalKit is too old.
- **`TKGame`**: `District()` (where V is, as the game names it; usually the sub-district), `MainDistrict()`, `DistrictRecord()`, `Money()` and `MoneyText(n)` ("12,500" plus the game's own E$ word), `Group(n)` ("12,500"), `Level()`, `StreetCred()`, `Clock()` ("21:07") and `Hour()`, `Imperial()`, `Distance(metres)` ("120 m", "1.4 km", or ft / mi when the player picked imperial units) and `DistanceTo(pos)`.
- **`TKNotify`**: the game's messages. `Warning(text, secs, bad)` (the line near the top of the screen; `WarningOfType` takes one of the game's `SimpleMessageType` looks), `Onscreen(text, secs)` (the big centred line), `Side(title)` (the small side popup) and `Quest(header, text)` (the quest-update toast). Texts can be plain or `LocKey#` keys. `TKHud.Toast` stays the kit's own card.
- **`TKPins`**: pins on the game's world map, minimap and in the world, kept by a name you pick: `Add(key, pos)` (the custom-waypoint look), `AddAs(key, pos, variant)`, `Move`, `Show(key, on)`, `Remove`, `RemoveAll(prefix)`, `Has`, `Position(key, out pos)`. The game doesn't save script pins, so add them again after a load. `TKHud.Strip(...).TargetPin(key)` points a strip at one.

The game's own scripts (decompiled, for reading only) are the reference for these: every call above is one the game makes itself.

### Regions: one screen in several panes

Override `Layout()` to get panes instead of the sidebar and the one scrolling page, such as a ribbon, a rack, a stage, a panel and a deck:

```
public func Layout() -> array<String> = [
  "ribbon|top|150", "deck|bottom|140|fixed", "rack|left|560", "panel|right|680", "stage|fill|0|fixed"]
```

Each spec is `"name|side|size|flags|title"`. `top`, `bottom`, `left` and `right` take `size` from what is left, in the order listed, and `fill` takes the rest. Flags are comma separated:
- `fixed`: the pane never scrolls.
- `cut`: chamfered corners. Every pane gets them when `TKStyle.cutCorner` is set, and `square` opts a pane out.

A title puts a header plate across the top of the pane, for example `"rack|left|560|cut|BAYS"`.

The provider still answers one page. `p.Region("rack")` sends the rows after it to that pane, and rows before the first `Region` go to the first pane. In `Act`, `p.Refresh("stage")` (once per pane) redraws only those panes, so the others keep their scroll position. Without it every pane redraws, and going to another page always redraws them all. The page's message shows bottom right. `Tabs()` isn't drawn with a layout, so put a `Links` row in a pane instead. `Regions()` gives the panes while the frame is open, and `Regions().Find("stage")` gives one pane's view.

**Overlays.** From `Act`, `p.Overlay(page, arg)` slides a page over the stage (the first `fill` pane) and `p.OverlayOn(region, page, arg)` slides one over any pane. The overlay shows the page's title and a BACK button, then its rows (`Region` rows are ignored). Right click and Esc close it before the frame. Actions from inside it see its page in `p.page`, and `GoTo` there moves the overlay. A page that draws its own way back calls `p.SetOverlayBack(false)` in `Request`. It then gets a heading with its title instead of the kit's header and BACK button, and right click and Esc still close it. `p.EndOverlay(region)` closes it (`""` closes the one the action came from, or all of them). Going to another page closes every overlay.

**A pane as a canvas.** A `Custom` row in a `fixed` pane can fill it: draw `v.Width()` by `v.Height()`. Then call `v.Hit(widget, action, arg, tip)` on any widget you drew (a hardpoint tag, part of a schematic). The kit shows the tooltip, plays the select sound (or the deny sound when the optional last argument `off` is true) and runs `Act(action, arg)` on a click. Your provider hears the pointer in `HitHover(v, action, arg, over)` and the wheel in `HitWheel(v, action, arg, delta)`; return true from `HitWheel` when you used it. `Hit` works in any custom row, with or without regions.

### Pages

A page is a title, a subtitle (hidden when empty), a status message and rows (`TKPage`). Your `TKContent` fills it in `Request` and runs buttons in `Act` (set `p.GoTo`, `p.SetMessage`, `p.Rebuild()` or `p.skipRedraw`).

- **Text and layout**: `Heading`, `Text`, `Pair`, `Note`, `Gap`, `Columns` (two columns of pairs), `Column` / `EndColumns` (side by side), `Section` (collapsible), `Links` (a tab row), `Dossier` (a header with a stamp), `Entry` (a feed entry), `Message` (a chat bubble; yours on the right).
- **Values**: `Meter`, `Track` (a meter with named marks), `Levels` (an item with a level track), `Stat` and `Ticker` tiles (a sparkline), `Gauge` (a dial tile with a needle), `Stack` (a bar split into coloured parts, with a legend), `Tile` (opens something), `Card` (a listing with buttons), `Ledger` (financial table lines: head, group, line, total, net), `Board` (a departures board).
- **Character cards** (in a grid like cards, sized by `p.SetExtra("w:h")`): `File` (a personnel file: number, barcode and stamp, a mugshot frame with the initials, stat bars out of 10, lines, a quote, buttons), `Posting` (a job posting: post number and time left, title, client, tag chips, the pay beside an odds meter, lines, buttons), `Run` (a job in progress: a live bar from start to end with the percent and the time left).
- **Buttons**: `Button`, `Item` (text left, a button right), `Buttons` (several).
- **Controls**: `Input` (a text box), `Search` (a box and its button), `Slider`, `Dropdown`, `Check`, `Choice` (a selectable list entry, for a list beside its detail), `SortHead` and `Pager`; `TKSheet` builds a sortable, paged table for you.
- **Live**: `Countdown` and `Progress` update every second from game time without redrawing, and can run an action when they finish.
- **Console pieces** (`TKConsole`):
  - `Key(inputAction, label, action, arg)` is a keycap that shows the player's own key or pad button for that input action. Pressing that key while the frame is open runs it too. Use `"*LABEL"` for the primary key and `"!LABEL|reason"` when it can't be used.
  - `Bay(head, atlas, part, fraction, color, selected, action, arg)` is a unit card for a rack: a wireframe thumbnail, an id line, the name, a stamp and a 10-cell bar. The whole card is a button.
  - `Leds(label, value, colors, blinks)` shows status lights; any light can blink.
  - `Ring(name, value, sub, fraction, color)` is a radial meter tile.
  - `Compare(label, value, fraction, current, color)` is a bar with an amber tick at the current value.
  - `Feed(label, text, color)` is a strip that scrolls.
  - `Wave(label, value, series, color, live)` is a small line through values, with a sweep running along it when live.
- **Custom**: `Custom(tag, ...)` is drawn by your provider's `Custom()`, which returns a `TKCustom` the view stops when the page goes (the map is one).

Marks in text: a leading `!` shows red, `*` green (neither is shown), `+` amounts green; on boards `^` bright yellow and `~` grey. Button labels: `!` disables, `?` asks first ("?SELL ALL" shows a dialog), `~` must be held ("~REPAIR ALL" fills while held and cancels on release). From `Act`, `p.Confirm(question, yes, action, arg)` asks before running something. `p.SetTip(text)` gives the row just added a tooltip on its title.

Action rows split their buttons once, typed: `row.labels`, `row.actions`, `row.args`. String builders take `"A|B"` labels, `"a|b"` actions and `"x|y"` args (or `"x\ny"` when an arg holds `|`). Controls hand their value on as `arg + ":" + value` (just the value when the row's arg is empty).

### The map (`TKMap`)

Describe it with a `TKMapSpec` (the map square in world units, a base image, tile layers per zoom level with `%C` / `%R` in the path, regions with rings, labels and tint masks, pins with letters, colours, links and groups, toggles, a legend) and draw it from your `Custom()` with `TKMap.Place(v, parent, spec, w, h)`. Drag with the left or middle button, scroll to zoom on the cursor, click a region to select it or a pin to open its page.

Map options:
- **Clicks on the map:** `spec.OnClick(action)` makes a left click anywhere except on a pin call `Act(action, "x|y")` with the spot in world metres, for example a drone's loiter point. It replaces selecting a region.
- **Pin rings and icons:** `pin.Ring(metres)` draws a dashed circle around a pin (an orbit, a loiter area), and `pin.Icon(atlas, part)` draws your own image in the pin's colour instead of the diamond.
- **Live pins:** name a pin with `pin.Named(id)`, keep the `TKMap` that `TKMap.Place` returns, and call `map.MovePin(id, x, y)` to move the pin without redrawing. `pin.Follow(key)` keeps a pin on a `TKPins` pin by itself, checked twice a second. A new view redraws the page through the spec's link (`%D` region, `%Z` zoom, `%M` toggle bits, `%X` / `%Y` the centre).

### HUD pieces (`TKHud`)

On the game's HUD layer, stacked at the top centre, in a TerminalKit palette:
- `TKHud.Strip(id, width)`: a tracker you keep up while it matters: `Set(title, right, sub)`, `Target(pos)` (a direction track that follows V's facing, and the distance), `Warn(on)`, `Fraction(f)` (a draining bar), `Show()` / `Hide()`.
- `TKHud.Toast(kicker, title, line, highlight, text, items, secs, bad)`: a card for a few seconds.

A strip's distance is in the player's chosen units (`TKGame.Distance`).

### Data

- `TKClock.Now()` (game seconds) and `TKClock.Left(secs)` ("2h 05m").
- `TKSheet`: add lines, `Show(p, col, desc, page, per, sortAction, pageAction, arg)`.
- `TKLog.Add(tag, text)`: a session log the Tools' console shows and saves.

### Pieces

`TKGame` (the version and the game's data), `TKNotify`, `TKPins`, `TKPage` (page model, row kinds, `TKContent`, `TKCustom`, `TKFrame`), `TKView` (renderer: scrolling, history, overlay for tooltips, dialogs and lists, live rows, sliders, text boxes), `TKRows` / `TKTables` / `TKTiles` / `TKControls` (components), `TKPopup` (the frame), `TKMap`, `TKHud`, `TKData`, `TKTheme` (palettes by role: `hud` follows the game's colours, plus kiroshi, arasaka, militech, netwatch, mono), `TKScale` (layout numbers and texts by key, from a `TKScaleSource` you can plug in with `TKScale.Use`), `TKInk` (widget builders), `TKButton`.

Add a row kind: a builder in `TKPage`, a case in `TKView.Draw`, a draw function.

### Conventions

- The canvas is 4K-sized and shrunk to the screen: 3000 x 1500 for the frame, a 2300-wide page.
- Ink blends premultiplied in linear light: colours brighter than white bloom, so `TKTheme.C` caps at white.
- Only unbind a style binding that exists; `TKTheme.Paint` handles that (unbinding on a fresh widget crashed the game).
- The right mouse button is also the popup's close action; `TKPopup` keeps its release for going back.

## TerminalKit Tools

Developer pages for any TerminalKit terminal (module `TerminalKit.Tools`, optional). Needs TerminalKit and RedFunctions.

- **Positions**: stand somewhere, face the way it should face, name it, pick a kind and a size, log it. `positions.json` gets name, type, size, district, x, y, z, yaw, the rotation and the time. Copy coordinates, delete entries.
- **Routes**: start, walk, log each stop (on the page, or with your own key calling `TKTools.LogStop()` while the terminal is closed), save and name it. `routes.json` gets each stop's position and a look point.
- **Inspect**: what V is looking at: class, record, appearance, name, affiliation, reaction preset, NPC type, level, alive or dead, civilian or crowd, attitude to V, entity, position, distance. Copy the record or look, show its flats, spawn another, append to `inspect.txt`.
- **Spawn**: any `Character.` or `Vehicle.` record (with an appearance) a few metres ahead of V, optionally on V's side; delete the last or all.
- **TweakDB**: search the record names (records, flats, queries or everything), page through the hits, copy one, open its flats, spawn it, dump to `tweak_search.txt` / `tweak_record.txt`.
- **Log**: everything written with `TKLog.Add(tag, text)`, filtered, saved to `log.txt`.

### Plugging it in

```
public func Request(p: ref<TKPage>, page: String, arg: String) -> Void {
  if TKTools.Request(p, page, arg) { return; }
  ...
}
public func Act(p: ref<TKPage>, action: String, arg: String) -> Void {
  if TKTools.Act(p, action, arg) { return; }
  ...
}
```

Link to `tk_tools` (or a tool: `tk_positions`, `tk_routes`, `tk_inspect`, `tk_spawn`, `tk_tweak`, `tk_log`). Tell it about your mod with `TKTools.Use(new MyHost())`, a `TKToolsHost` subclass: `Storage()` (the folder under `r6/storages`, default `TerminalKit`), `Kinds()` and `Sizes()` for the logger, `District()`, and `Logged` / `Routed` / `Changed` to hear when a file changed. Gate the pages behind your own developer switch if players shouldn't see them.
