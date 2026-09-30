# TerminalKit Tools

Developer pages for any TerminalKit terminal (module `TerminalKit.Tools`, optional). Needs TerminalKit and RedFunctions.

- **Positions**: stand somewhere, face the way it should face, name it, pick a kind and a size, log it. `positions.json` gets name, type, size, district, x, y, z, yaw, the rotation and the time. Copy coordinates, delete entries.
- **Routes**: start, walk, log each stop (on the page, or with your own key calling `TKTools.LogStop()` while the terminal is closed), save and name it. `routes.json` gets each stop's position and a look point.
- **Inspect**: what V is looking at: class, record, appearance, name, affiliation, reaction preset, NPC type, level, alive or dead, civilian or crowd, attitude to V, entity, position, distance. Copy the record or look, show its flats, spawn another, append to `inspect.txt`.
- **Spawn**: any `Character.` or `Vehicle.` record (with an appearance) a few metres ahead of V, optionally on V's side; delete the last or all.
- **TweakDB**: search the record names (records, flats, queries or everything), page through the hits, copy one, open its flats, spawn it, dump to `tweak_search.txt` / `tweak_record.txt`.
- **Log**: everything written with `TKLog.Add(tag, text)`, filtered, saved to `log.txt`.

## Plugging it in

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
