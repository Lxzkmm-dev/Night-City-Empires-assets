// =============================================================================
// TERMINAL KIT TOOLS - THE PAGES AND WHAT THEY KEEP
// A pack of developer pages any TerminalKit terminal can show: a position
// logger, a route recorder, a look-at inspector, a spawn tester, a TweakDB
// browser and a log console. Optional: a mod that doesn't want them leaves this
// folder out.
//
// Plug it into your content provider (pages and actions start with "tk_"):
//   public func Request(p: ref<TKPage>, page: String, arg: String) -> Void {
//     if TKTools.Request(p, page, arg) { return; }
//     ...your pages...
//   }
//   public func Act(p: ref<TKPage>, action: String, arg: String) -> Void {
//     if TKTools.Act(p, action, arg) { return; }
//     ...your actions...
//   }
// and link to "tk_tools". Tell it about your mod once with TKTools.Use(host)
// (a TKToolsHost subclass: the storage folder, position kinds, what to do when
// a position or a route is saved). Files go to r6/storages/<folder>:
// positions.json, routes.json, inspect.txt, tweak_search.txt, tweak_record.txt,
// log.txt. To log route stops with a key while the terminal is closed, call
// TKTools.LogStop() from your key.
// Needs RedFunctions (files, JSON, the TweakDB name table, the clipboard).
// =============================================================================
module TerminalKit.Tools

import TerminalKit.*
import RedFunctions.*
import RedFunctions.Json.*
import RedFunctions.Storage.*

// What the tools need from the mod (override what differs)
public class TKToolsHost extends IScriptable {
  public func Storage() -> String = "TerminalKit"          // the folder under r6/storages
  public func Kinds() -> array<String> = ["Spot", "Spawn point", "Patrol point", "Entrance", "Drop point", "Other"]
  public func Sizes() -> array<String> = ["", "Small", "Medium", "Large", "Huge"]
  // where V stands, for the logger ("" = the game's district)
  public func District() -> String = ""
  public func Logged(entry: ref<JsonMap>) -> Void {}       // a position was added to positions.json
  public func Routed(entry: ref<JsonMap>) -> Void {}       // a route was added to routes.json
  public func Changed() -> Void {}                          // either file changed (a delete)
  public func Warn(text: String) -> Void {                 // a short on-screen message
    let p = GetPlayer(GetGameInstance());
    if IsDefined(p) {
      p.SetWarningMessage(text);
    }
  }
}

// the tools' state (not saved with the game)
public class TKToolsSystem extends ScriptableSystem {
  public let host: ref<TKToolsHost>;
  public let kind: Int32;
  public let size: Int32;
  public let posPage: Int32;
  public let positions: ref<JsonList>;
  public let routes: ref<JsonList>;
  public let routeOn: Bool;
  public let routeNodes: array<Vector4>;
  public let routeLooks: array<Vector4>;
  public let routePage: Int32;
  public let inspect: array<String>;           // "LABEL|value" lines of the last look-at
  public let inspectRecord: String;
  public let inspectLook: String;
  public let flats: array<String>;
  public let flatsOf: String;
  public let spawnFriendly: Bool;
  public let spawned: array<EntityID>;
  public let spawnedNames: array<String>;
  public let tweakQuery: String;
  public let tweakKind: Int32;
  public let tweakPage: Int32;
  public let tweakHits: array<String>;
  public let logFilter: String;
  public let logPage: Int32;

  public static func Get() -> ref<TKToolsSystem> = GameInstance.GetScriptableSystemsContainer(GetGameInstance()).Get(n"TerminalKit.Tools.TKToolsSystem") as TKToolsSystem

  private func OnAttach() -> Void {
    GameInstance.GetDynamicEntitySystem().RegisterListener(n"TKSpawnTest", this, n"OnSpawnEvent");
  }

  private func OnDetach() -> Void {
    GameInstance.GetDynamicEntitySystem().UnregisterListener(n"TKSpawnTest", this, n"OnSpawnEvent");
  }

  private func OnPlayerAttach(request: ref<PlayerAttachRequest>) -> Void {
    this.routeOn = false;
    ArrayClear(this.routeNodes);
    ArrayClear(this.routeLooks);
    ArrayClear(this.spawned);
    ArrayClear(this.spawnedNames);
  }

  public func Host() -> ref<TKToolsHost> {
    if !IsDefined(this.host) {
      this.host = new TKToolsHost();
    }
    return this.host;
  }

  // a spawned test NPC: on V's side when asked
  private cb func OnSpawnEvent(event: ref<DynamicEntityEvent>) {
    if NotEquals(event.GetEventType(), DynamicEntityEventType.Spawned) || !this.spawnFriendly {
      return;
    }
    let npc = GameInstance.GetDynamicEntitySystem().GetEntity(event.GetEntityID()) as NPCPuppet;
    let player = GetPlayer(this.GetGameInstance());
    if IsDefined(npc) && IsDefined(player) {
      let a = npc.GetAttitudeAgent();
      if IsDefined(a) {
        a.SetAttitudeGroup(player.GetAttitudeAgent().GetAttitudeGroup());
        a.SetAttitudeTowards(player.GetAttitudeAgent(), EAIAttitude.AIA_Friendly);
      }
    }
  }
}

public abstract class TKTools {
  // ---- set-up ----
  public static func Use(host: ref<TKToolsHost>) -> Void {
    let sys = TKToolsSystem.Get();
    if IsDefined(sys) {
      sys.host = host;
      sys.positions = null;
      sys.routes = null;
    }
  }

  // Several mods can share the tools: each calls this with its own host before
  // TKTools.Request / Act (and before LogStop from a key). It switches only when
  // the tools were last used for another storage folder, so it is cheap to repeat.
  public static func UseFor(host: ref<TKToolsHost>) -> Void {
    let sys = TKToolsSystem.Get();
    if !IsDefined(sys) || !IsDefined(host) {
      return;
    }
    if !IsDefined(sys.host) || NotEquals(sys.host.Storage(), host.Storage()) {
      TKTools.Use(host);
    }
  }

  public static func Sys() -> ref<TKToolsSystem> = TKToolsSystem.Get()
  public static func Store() -> ref<ModStorage> = ModStorage.Open(TKTools.Sys().Host().Storage())
  private static func Warn(text: String) -> Void { TKTools.Sys().Host().Warn(text); }

  // ---- the page router ----
  public static func Request(p: ref<TKPage>, page: String, arg: String) -> Bool {
    if !StrBeginsWith(page, "tk_") || !IsDefined(TKTools.Sys()) {
      return false;
    }
    switch page {
      case "tk_tools": TKTools.Home(p); break;
      case "tk_positions": TKTools.Positions(p); break;
      case "tk_routes": TKTools.Routes(p); break;
      case "tk_inspect": TKToolsWorld.Inspect(p); break;
      case "tk_spawn": TKToolsWorld.Spawn(p); break;
      case "tk_tweak": TKToolsWorld.Tweak(p); break;
      case "tk_flats": TKToolsWorld.Flats(p); break;
      case "tk_log": TKToolsWorld.Log(p); break;
      default: return false;
    }
    return true;
  }

  public static func Act(p: ref<TKPage>, action: String, arg: String) -> Bool {
    if !StrBeginsWith(action, "tk_") || !IsDefined(TKTools.Sys()) {
      return false;
    }
    let sys = TKTools.Sys();
    let v = TKTools.Value(arg);
    switch action {
      case "tk_go": p.GoTo(StrBeforeFirst(arg + "~", "~"), StrAfterFirst(arg, "~")); break;
      case "tk_copy":
        RedFunc.SetClipboardText(arg);
        p.SetMessage("COPIED: " + arg);
        break;
      // positions
      case "tk_kind": sys.kind = v; break;
      case "tk_size": sys.size = v; break;
      case "tk_log": TKTools.LogHere(p, p.GetField("tk_posname")); break;
      case "tk_posdel": TKTools.DeletePosition(StringToInt(arg, -1)); p.SetMessage("POSITION DELETED"); break;
      case "tk_pospage": sys.posPage = v; break;
      // routes
      case "tk_route": TKTools.RouteAction(p, arg); break;
      case "tk_routepage": sys.routePage = v; break;
      default: return TKToolsWorld.Act(p, action, arg);
    }
    return true;
  }

  // the number a control hands over: "3", or "arg:3"
  public static func Value(arg: String) -> Int32 = StringToInt(StrContains(arg, ":") ? StrAfterLast(arg, ":") : arg, 0)

  // the tools' own tab row
  public static func Nav(p: ref<TKPage>, current: String) -> Void {
    p.Links("TOOLS|POSITIONS|ROUTES|INSPECT|SPAWN|TWEAKDB|LOG", "tk_tools|tk_positions|tk_routes|tk_inspect|tk_spawn|tk_tweak|tk_log", current);
  }

  // ---------------------------------------------------------------------------
  // The tools' home: one tile each
  // ---------------------------------------------------------------------------
  private static func Home(p: ref<TKPage>) -> Void {
    let sys = TKTools.Sys();
    p.SetTitle("DEV TOOLS", "TerminalKit Tools: files go to r6/storages/" + sys.Host().Storage());
    TKTools.Nav(p, "tk_tools");
    p.Tile("POSITIONS", IntToString(TKTools.PositionList().Size()) + " LOGGED", "Stand somewhere, name it, log it", "cyan", "OPEN", "tk_go", "tk_positions", true);
    p.Tile("ROUTES", sys.routeOn ? "RECORDING" : IntToString(TKTools.RouteList().Size()) + " SAVED", "Walk a route, log each stop", "green", "OPEN", "tk_go", "tk_routes", true);
    p.Tile("INSPECT", ArraySize(sys.inspect) > 0 ? "LAST: " + StrUpper(StrAfterLast(sys.inspectRecord, ".")) : "LOOK AT IT", "Record, look, faction, attitude", "yellow", "OPEN", "tk_go", "tk_inspect", true);
    p.Tile("SPAWN", IntToString(ArraySize(sys.spawned)) + " OUT", "Any NPC or vehicle record ahead of V", "orange", "OPEN", "tk_go", "tk_spawn", true);
    p.Tile("TWEAKDB", RedFunc.TweakNamesReady() ? IntToString(RedFunc.TweakNamesCount()) + " NAMES" : "!NAMES LOADING", "Search records and their flats", "purple", "OPEN", "tk_go", "tk_tweak", true);
    p.Tile("LOG", IntToString(ArraySize(TKLog.Lines())) + " LINES", "What mods wrote with TKLog.Add", "blue", "OPEN", "tk_go", "tk_log", true);
  }

  // ---------------------------------------------------------------------------
  // Position logger: positions.json
  // ---------------------------------------------------------------------------
  public static func PositionList() -> ref<JsonList> {
    let sys = TKTools.Sys();
    if !IsDefined(sys.positions) {
      let data = TKTools.Store().ReadJson("positions.json");
      sys.positions = IsDefined(data) && data.IsList() ? data.AsList() : JsonList.Make();
    }
    return sys.positions;
  }

  // the game's district where V stands ("Watson", "Kabuki")
  public static func GameDistrict() -> String {
    let prevention = GameInstance.GetScriptableSystemsContainer(GetGameInstance()).Get(n"PreventionSystem") as PreventionSystem;
    let district = IsDefined(prevention) ? prevention.GetCurrentDistrict() : null;
    if !IsDefined(district) {
      return "";
    }
    let record = TweakDBInterface.GetDistrictRecord(district.GetDistrictID());
    return IsDefined(record) ? StrAfterLast(TDBID.ToStringDEBUG(record.GetID()), ".") : "";
  }

  private static func Positions(p: ref<TKPage>) -> Void {
    let sys = TKTools.Sys();
    let host = sys.Host();
    let kinds = host.Kinds();
    let sizes = host.Sizes();
    sys.kind = Clamp(sys.kind, 0, ArraySize(kinds) - 1);
    sys.size = Clamp(sys.size, 0, ArraySize(sizes) - 1);
    p.SetTitle("POSITION LOGGER", "Stand on the spot, face the way it should face, name it and log it (positions.json)");
    TKTools.Nav(p, "tk_positions");
    p.Input("NAME", "", "tk_posname");
    p.Dropdown("KIND", "What the spot is for", IntToString(sys.kind), TKStr.Join(kinds, "|"), TKTools.Indices(ArraySize(kinds)), "tk_kind", "");
    let names = sizes;
    names[0] = "None";
    p.Dropdown("SIZE", "For places that come in sizes", IntToString(sys.size), TKStr.Join(names, "|"), TKTools.Indices(ArraySize(sizes)), "tk_size", "");
    p.Button("LOG THIS POSITION", "tk_log", "", true);
    let list = TKTools.PositionList();
    let per = 6;
    let pages = TKSheet.Pages(list.Size(), per);
    let page = Clamp(sys.posPage, 0, pages - 1);
    p.Heading("LOGGED (" + IntToString(list.Size()) + ")");
    // newest first
    let i = list.Size() - 1 - page * per;
    let stop = Max(-1, i - per);
    while i > stop {
      let pos = list.MapAt(i);
      let tag = pos.Text("type", "?") + (StrLen(pos.Text("size", "")) > 0 ? ", " + pos.Text("size", "") : "");
      let at = FloatToStringPrec(pos.Float("x", 0.0), 1) + ", " + FloatToStringPrec(pos.Float("y", 0.0), 1) + ", " + FloatToStringPrec(pos.Float("z", 0.0), 1);
      p.Buttons(IntToString(i + 1) + ". [" + tag + "] " + pos.Text("name", "?"), pos.Text("district", "") + "  (" + at + ")  yaw " + FloatToStringPrec(pos.Float("yaw", 0.0), 0), "",
        "COPY|?DELETE", "tk_copy|tk_posdel", at + "\n" + IntToString(i));
      i -= 1;
    }
    if pages > 1 {
      p.Pager(page, pages, "tk_pospage", "");
    }
  }

  // "0|1|2..."
  public static func Indices(n: Int32) -> String {
    let parts: array<String>;
    let i = 0;
    while i < n {
      ArrayPush(parts, IntToString(i));
      i += 1;
    }
    return TKStr.Join(parts, "|");
  }

  private static func LogHere(p: ref<TKPage>, name: String) -> Void {
    let sys = TKTools.Sys();
    let host = sys.Host();
    let player = GetPlayer(GetGameInstance());
    if !IsDefined(player) {
      return;
    }
    let pos = player.GetWorldPosition();
    let rot = player.GetWorldOrientation();
    let list = TKTools.PositionList();
    let kinds = host.Kinds();
    let sizes = host.Sizes();
    let entry = JsonMap.Make();
    entry.PutText("name", StrLen(name) > 0 ? name : "Position " + IntToString(list.Size() + 1));
    entry.PutText("type", kinds[Clamp(sys.kind, 0, ArraySize(kinds) - 1)]);
    let size = sizes[Clamp(sys.size, 0, ArraySize(sizes) - 1)];
    if StrLen(size) > 0 {
      entry.PutText("size", size);
    }
    let district = host.District();
    entry.PutText("district", StrLen(district) > 0 ? district : TKTools.GameDistrict());
    entry.PutFloat("x", pos.X);
    entry.PutFloat("y", pos.Y);
    entry.PutFloat("z", pos.Z);
    entry.PutFloat("yaw", player.GetWorldYaw());
    entry.PutFloat("qi", rot.i);
    entry.PutFloat("qj", rot.j);
    entry.PutFloat("qk", rot.k);
    entry.PutFloat("qr", rot.r);
    entry.PutText("time", RedFunc.RealDate());
    list.Push(entry);
    TKTools.Store().WriteJson("positions.json", list);
    host.Logged(entry);
    TKLog.Add("TOOLS", "position logged: " + entry.Text("name", ""));
    p.SetMessage("POSITION LOGGED: " + StrUpper(entry.Text("name", "")));
  }

  private static func DeletePosition(i: Int32) -> Void {
    let list = TKTools.PositionList();
    if list.RemoveAt(i) {
      TKTools.Store().WriteJson("positions.json", list);
      TKTools.Sys().Host().Changed();
    }
  }

  // ---------------------------------------------------------------------------
  // Route recorder: routes.json
  // ---------------------------------------------------------------------------
  public static func RouteList() -> ref<JsonList> {
    let sys = TKTools.Sys();
    if !IsDefined(sys.routes) {
      let data = TKTools.Store().ReadJson("routes.json");
      sys.routes = IsDefined(data) && data.IsList() ? data.AsList() : JsonList.Make();
    }
    return sys.routes;
  }

  public static func Recording() -> Bool {
    let sys = TKTools.Sys();
    return IsDefined(sys) && sys.routeOn;
  }

  // a stop where V stands, facing where V faces (call it from your own key)
  public static func LogStop() -> Void {
    let sys = TKTools.Sys();
    let player = GetPlayer(GetGameInstance());
    if !IsDefined(sys) || !IsDefined(player) {
      return;
    }
    if !sys.routeOn {
      TKTools.Warn("NOT RECORDING A ROUTE");
      return;
    }
    let pos = player.GetWorldPosition();
    let fw = player.GetWorldForward();
    ArrayPush(sys.routeNodes, pos);
    ArrayPush(sys.routeLooks, Vector4(pos.X + fw.X * 5.0, pos.Y + fw.Y * 5.0, pos.Z, 1.0));
    TKTools.Warn("ROUTE STOP " + IntToString(ArraySize(sys.routeNodes)) + " LOGGED");
  }

  private static func Routes(p: ref<TKPage>) -> Void {
    let sys = TKTools.Sys();
    p.SetTitle("ROUTE RECORDER", "Walk a route and log each stop: here, or with your mod's key (TKTools.LogStop) with the terminal closed (routes.json)");
    TKTools.Nav(p, "tk_routes");
    if sys.routeOn {
      p.Input("ROUTE NAME", "", "tk_routename");
      p.Buttons("RECORDING: " + IntToString(ArraySize(sys.routeNodes)) + " STOPS", "Log a stop where you stand, or close the terminal and use your key.", "green",
        "LOG STOP HERE|UNDO LAST|SAVE|CANCEL", "tk_route|tk_route|tk_route|tk_route", "stop|undo|save|cancel");
      let k = 0;
      while k < ArraySize(sys.routeNodes) {
        let n = sys.routeNodes[k];
        p.Pair("STOP " + IntToString(k + 1), FloatToStringPrec(n.X, 1) + ", " + FloatToStringPrec(n.Y, 1) + ", " + FloatToStringPrec(n.Z, 1), "");
        k += 1;
      }
    } else {
      p.Buttons("RECORD A ROUTE", "Start, walk the route logging each stop, then save and name it.", "", "START RECORDING", "tk_route", "start");
    }
    let list = TKTools.RouteList();
    let per = 5;
    let pages = TKSheet.Pages(list.Size(), per);
    let page = Clamp(sys.routePage, 0, pages - 1);
    p.Heading("SAVED ROUTES (" + IntToString(list.Size()) + ")");
    let i = list.Size() - 1 - page * per;
    let stop = Max(-1, i - per);
    while i > stop {
      let r = list.MapAt(i);
      let nodes = r.List("nodes");
      p.Buttons(StrUpper(r.Text("name", "?")), IntToString(IsDefined(nodes) ? nodes.Size() : 0) + " stops  |  " + r.Text("time", ""), "", "?DELETE", "tk_route", "del" + IntToString(i));
      i -= 1;
    }
    if pages > 1 {
      p.Pager(page, pages, "tk_routepage", "");
    }
  }

  private static func RouteAction(p: ref<TKPage>, arg: String) -> Void {
    let sys = TKTools.Sys();
    if Equals(arg, "start") {
      sys.routeOn = true;
      ArrayClear(sys.routeNodes);
      ArrayClear(sys.routeLooks);
      return;
    }
    if Equals(arg, "stop") {
      TKTools.LogStop();
      return;
    }
    if Equals(arg, "undo") {
      if ArraySize(sys.routeNodes) > 0 {
        ArrayPop(sys.routeNodes);
        ArrayPop(sys.routeLooks);
      }
      return;
    }
    if Equals(arg, "cancel") {
      sys.routeOn = false;
      return;
    }
    if Equals(arg, "save") {
      if ArraySize(sys.routeNodes) < 2 {
        p.SetMessage("LOG AT LEAST TWO STOPS FIRST");
        return;
      }
      let name = p.GetField("tk_routename");
      let list = TKTools.RouteList();
      let entry = JsonMap.Make();
      entry.PutText("name", StrLen(name) > 0 ? name : "Route " + IntToString(list.Size() + 1));
      entry.PutText("time", RedFunc.RealDate());
      let nodes = JsonList.Make();
      let k = 0;
      while k < ArraySize(sys.routeNodes) {
        let m = JsonMap.Make();
        let n = sys.routeNodes[k];
        let l = sys.routeLooks[k];
        m.PutFloat("x", n.X); m.PutFloat("y", n.Y); m.PutFloat("z", n.Z);
        m.PutFloat("lx", l.X); m.PutFloat("ly", l.Y); m.PutFloat("lz", l.Z);
        nodes.Push(m);
        k += 1;
      }
      entry.Put("nodes", nodes);
      list.Push(entry);
      TKTools.Store().WriteJson("routes.json", list);
      sys.routeOn = false;
      sys.Host().Routed(entry);
      TKLog.Add("TOOLS", "route saved: " + entry.Text("name", ""));
      p.SetMessage("ROUTE SAVED: " + StrUpper(entry.Text("name", "")) + " (" + IntToString(ArraySize(sys.routeNodes)) + " STOPS)");
      return;
    }
    if StrBeginsWith(arg, "del") {
      let list = TKTools.RouteList();
      if list.RemoveAt(StringToInt(StrAfterFirst(arg, "del"), -1)) {
        TKTools.Store().WriteJson("routes.json", list);
        sys.Host().Changed();
      }
    }
  }
}
