// =============================================================================
// TERMINAL KIT TOOLS - INSPECTOR, SPAWN TESTER, TWEAKDB BROWSER, LOG CONSOLE
// Inspector: what V is looking at (record, appearance, faction, reaction
//   preset, NPC type, attitude to V, level, entity, position), copied to the
//   clipboard or appended to inspect.txt.
// Spawn tester: any NPC or vehicle record a few metres ahead of V, optionally
//   on V's side; deleted again with one button.
// TweakDB browser: search the record names (RedFunctions' name table), page
//   through the hits, show a record's flats, copy or spawn it, dump to a file.
// Log console: what mods wrote with TKLog.Add, filtered, saved to log.txt.
// =============================================================================
module TerminalKit.Tools

import TerminalKit.*
import RedFunctions.*
import RedFunctions.Storage.*

public abstract class TKToolsWorld {
  public static func Act(p: ref<TKPage>, action: String, arg: String) -> Bool {
    let sys = TKTools.Sys();
    switch action {
      case "tk_look": TKToolsWorld.LookAt(p); break;
      case "tk_insp_log":
        if ArraySize(sys.inspect) > 0 {
          let lines: array<String>;
          ArrayPush(lines, "# " + RedFunc.RealDate());
          for l in sys.inspect {
            ArrayPush(lines, StrReplace(l, "|", ": "));
          }
          ArrayPush(lines, "");
          TKTools.Store().WriteLines("inspect.txt", lines, true);
          p.SetMessage("ADDED TO INSPECT.TXT");
        }
        break;
      case "tk_spawn": TKToolsWorld.SpawnIt(p, p.GetField("tk_record"), p.GetField("tk_appearance")); break;
      case "tk_tspawn":
        TKToolsWorld.SpawnIt(p, arg, "");
        break;
      case "tk_despawn": TKToolsWorld.Despawn(Equals(arg, "all")); break;
      case "tk_friend": sys.spawnFriendly = TKTools.Value(arg) == 1; break;
      case "tk_tsearch":
        sys.tweakQuery = arg;
        sys.tweakPage = 0;
        TKToolsWorld.Search();
        break;
      case "tk_tkind":
        sys.tweakKind = TKTools.Value(arg);
        TKToolsWorld.Search();
        break;
      case "tk_tpage": sys.tweakPage = TKTools.Value(arg); break;
      case "tk_tdump":
        let lines: array<String>;
        ArrayPush(lines, "# TweakSearch \"" + sys.tweakQuery + "\" | " + RedFunc.RealDate() + " | " + IntToString(ArraySize(sys.tweakHits)) + " hits");
        for h in sys.tweakHits {
          ArrayPush(lines, h);
        }
        TKTools.Store().WriteLines("tweak_search.txt", lines);
        p.SetMessage("WROTE TWEAK_SEARCH.TXT");
        break;
      case "tk_tflats":
        sys.flatsOf = arg;
        sys.flats = RedFunc.TweakChildren(arg, 400);
        p.GoTo("tk_flats", "");
        break;
      case "tk_fdump":
        let lines: array<String>;
        ArrayPush(lines, "# " + sys.flatsOf + " | " + RedFunc.RealDate() + " | " + IntToString(ArraySize(sys.flats)) + " flats");
        for f in sys.flats {
          ArrayPush(lines, f);
        }
        TKTools.Store().WriteLines("tweak_record.txt", lines);
        p.SetMessage("WROTE TWEAK_RECORD.TXT");
        break;
      case "tk_lfilter":
        sys.logFilter = arg;
        sys.logPage = 0;
        break;
      case "tk_lpage": sys.logPage = TKTools.Value(arg); break;
      case "tk_lclear": TKLog.Clear(); break;
      case "tk_lsave":
        TKTools.Store().WriteLines("log.txt", TKLog.Lines());
        p.SetMessage("WROTE LOG.TXT");
        break;
      default: return false;
    }
    return true;
  }

  // ---------------------------------------------------------------------------
  // Inspector
  // ---------------------------------------------------------------------------
  public static func Inspect(p: ref<TKPage>) -> Void {
    let sys = TKTools.Sys();
    p.SetTitle("INSPECTOR", "Look straight at an NPC, a vehicle or an object, then inspect it");
    TKTools.Nav(p, "tk_inspect");
    p.Buttons("LOOK-AT", ArraySize(sys.inspect) > 0 ? "The last thing inspected is below." : "Nothing inspected yet.", "",
      "INSPECT|ADD TO INSPECT.TXT", "tk_look|tk_insp_log", "\n");
    if ArraySize(sys.inspect) == 0 {
      return;
    }
    p.Ledger("head", "WHAT|VALUE", "L28|L72");
    for l in sys.inspect {
      p.Ledger("line", l, "L28|L72");
    }
    if StrLen(sys.inspectRecord) > 0 {
      p.Buttons("RECORD", sys.inspectRecord, "", "COPY RECORD|COPY LOOK|SHOW FLATS|SPAWN ANOTHER", "tk_copy|tk_copy|tk_tflats|tk_tspawn",
        sys.inspectRecord + "\n" + sys.inspectLook + "\n" + sys.inspectRecord + "\n" + sys.inspectRecord);
    }
  }

  private static func Attitude(a: EAIAttitude) -> String {
    switch a {
      case EAIAttitude.AIA_Friendly: return "Friendly";
      case EAIAttitude.AIA_Hostile: return "Hostile";
      default: return "Neutral";
    }
  }

  private static func LookAt(p: ref<TKPage>) -> Void {
    let sys = TKTools.Sys();
    let player = GetPlayer(GetGameInstance());
    if !IsDefined(player) {
      return;
    }
    let obj = GameInstance.GetTargetingSystem(GetGameInstance()).GetLookAtObject(player);
    if !IsDefined(obj) {
      p.SetMessage("LOOK STRAIGHT AT SOMETHING FIRST (CLOSE THE TERMINAL, AIM, OPEN IT AGAIN)");
      return;
    }
    ArrayClear(sys.inspect);
    sys.inspectRecord = "";
    sys.inspectLook = "";
    ArrayPush(sys.inspect, "CLASS|" + NameToString(obj.GetClassName()));
    let npc = obj as NPCPuppet;
    let veh = obj as VehicleObject;
    if IsDefined(npc) {
      let id = npc.GetRecordID();
      sys.inspectRecord = TDBID.ToStringDEBUG(id);
      sys.inspectLook = NameToString(npc.GetCurrentAppearanceName());
      ArrayPush(sys.inspect, "RECORD|" + sys.inspectRecord);
      ArrayPush(sys.inspect, "APPEARANCE|" + sys.inspectLook);
      let rec = TweakDBInterface.GetCharacterRecord(id);
      if IsDefined(rec) {
        ArrayPush(sys.inspect, "NAME|" + GetLocalizedTextByKey(rec.DisplayName()));
        if IsDefined(rec.Affiliation()) {
          ArrayPush(sys.inspect, "AFFILIATION|" + TDBID.ToStringDEBUG(rec.Affiliation().GetID()));
        }
        if IsDefined(rec.ReactionPreset()) {
          ArrayPush(sys.inspect, "REACTION PRESET|" + TDBID.ToStringDEBUG(rec.ReactionPreset().GetID()));
        }
      }
      ArrayPush(sys.inspect, "NPC TYPE|" + EnumValueToString("gamedataNPCType", Cast<Int64>(EnumInt(npc.GetNPCType()))));
      ArrayPush(sys.inspect, "LEVEL|" + IntToString(Cast<Int32>(GameInstance.GetStatsSystem(GetGameInstance()).GetStatValue(Cast<StatsObjectID>(npc.GetEntityID()), gamedataStatType.Level))));
      ArrayPush(sys.inspect, "STATE|" + (npc.IsDead() ? "Dead" : "Alive") + (npc.IsCivilian() ? ", civilian" : "") + (npc.IsCrowd() ? ", crowd" : ""));
    } else {
      if IsDefined(veh) {
        sys.inspectRecord = TDBID.ToStringDEBUG(veh.GetRecordID());
        ArrayPush(sys.inspect, "RECORD|" + sys.inspectRecord);
      }
    }
    ArrayPush(sys.inspect, "ATTITUDE TO V|" + TKToolsWorld.Attitude(obj.GetAttitudeTowards(player)));
    ArrayPush(sys.inspect, "ENTITY|" + ToString(EntityID.GetHash(obj.GetEntityID())));
    let pos = obj.GetWorldPosition();
    ArrayPush(sys.inspect, "POSITION|" + FloatToStringPrec(pos.X, 2) + ", " + FloatToStringPrec(pos.Y, 2) + ", " + FloatToStringPrec(pos.Z, 2));
    ArrayPush(sys.inspect, "DISTANCE|" + FloatToStringPrec(Vector4.Distance(pos, player.GetWorldPosition()), 1) + " m");
    TKLog.Add("TOOLS", "inspected " + (StrLen(sys.inspectRecord) > 0 ? sys.inspectRecord : NameToString(obj.GetClassName())));
  }

  // ---------------------------------------------------------------------------
  // Spawn tester
  // ---------------------------------------------------------------------------
  public static func Spawn(p: ref<TKPage>) -> Void {
    let sys = TKTools.Sys();
    p.SetTitle("SPAWN TESTER", "Any NPC or vehicle record, a few metres ahead of V (not saved with the game)");
    TKTools.Nav(p, "tk_spawn");
    p.Input("RECORD", sys.inspectRecord, "tk_record");
    p.Input("APPEARANCE", "", "tk_appearance");
    p.Check("ON V'S SIDE", "Spawned NPCs join V's attitude group", sys.spawnFriendly, "tk_friend", "");
    p.Buttons("SPAWN", IntToString(ArraySize(sys.spawned)) + " out now", "", "SPAWN|DELETE LAST|DELETE ALL", "tk_spawn|tk_despawn|tk_despawn", "\nlast\nall");
    let k = ArraySize(sys.spawnedNames) - 1;
    while k >= 0 {
      p.Pair(IntToString(k + 1) + ".", sys.spawnedNames[k], "");
      k -= 1;
    }
  }

  private static func SpawnIt(p: ref<TKPage>, record: String, look: String) -> Void {
    let sys = TKTools.Sys();
    let player = GetPlayer(GetGameInstance());
    if !IsDefined(player) || StrLen(record) == 0 {
      p.SetMessage("TYPE A RECORD FIRST (Character.xxx or Vehicle.xxx)");
      return;
    }
    let id = TDBID.Create(record);
    if !IsDefined(TweakDBInterface.GetCharacterRecord(id)) && !IsDefined(TweakDBInterface.GetVehicleRecord(id)) {
      p.SetMessage("NO SUCH NPC OR VEHICLE RECORD: " + record);
      return;
    }
    let pos = player.GetWorldPosition();
    let fw = player.GetWorldForward();
    let ahead = IsDefined(TweakDBInterface.GetVehicleRecord(id)) ? 7.0 : 3.0;
    let spec = new DynamicEntitySpec();
    spec.recordID = id;
    if StrLen(look) > 0 {
      spec.appearanceName = StringToName(look);
    }
    spec.position = Vector4(pos.X + fw.X * ahead, pos.Y + fw.Y * ahead, pos.Z + 0.2, 1.0);
    spec.orientation = player.GetWorldOrientation();
    spec.persistState = false;
    spec.persistSpawn = false;
    spec.alwaysSpawned = true;
    spec.tags = [n"TKSpawnTest"];
    let entity = GameInstance.GetDynamicEntitySystem().CreateEntity(spec);
    if !EntityID.IsDefined(entity) {
      p.SetMessage("COULDN'T SPAWN " + record);
      return;
    }
    ArrayPush(sys.spawned, entity);
    ArrayPush(sys.spawnedNames, record + (StrLen(look) > 0 ? " / " + look : ""));
    TKLog.Add("TOOLS", "spawned " + record);
    p.SetMessage("SPAWNED " + StrUpper(StrAfterLast(record, ".")));
    p.GoTo("tk_spawn", "");
  }

  private static func Despawn(all: Bool) -> Void {
    let sys = TKTools.Sys();
    while ArraySize(sys.spawned) > 0 {
      let n = ArraySize(sys.spawned) - 1;
      GameInstance.GetDynamicEntitySystem().DeleteEntity(sys.spawned[n]);
      ArrayPop(sys.spawned);
      ArrayPop(sys.spawnedNames);
      if !all {
        return;
      }
    }
  }

  // ---------------------------------------------------------------------------
  // TweakDB browser
  // ---------------------------------------------------------------------------
  private static func Search() -> Void {
    let sys = TKTools.Sys();
    ArrayClear(sys.tweakHits);
    if StrLen(sys.tweakQuery) >= 2 && RedFunc.TweakNamesReady() {
      sys.tweakHits = RedFunc.TweakSearch(sys.tweakQuery, sys.tweakKind, 2000);
    }
  }

  public static func Tweak(p: ref<TKPage>) -> Void {
    let sys = TKTools.Sys();
    p.SetTitle("TWEAKDB", "Search the game's records by name (at least two letters); copy, open or spawn a hit");
    TKTools.Nav(p, "tk_tweak");
    if !RedFunc.TweakNamesReady() {
      p.Text("!The TweakDB name table is still loading. Try again in a moment.", "red");
    }
    p.Search("SEARCH", sys.tweakQuery, "tk_query", "tk_tsearch");
    p.Dropdown("LOOK IN", "What the search covers", IntToString(sys.tweakKind), "RECORDS|FLATS|QUERIES|EVERYTHING", "0|1|2|3", "tk_tkind", "");
    let n = ArraySize(sys.tweakHits);
    p.Buttons("RESULTS", IntToString(n) + (n >= 2000 ? "+ (the first 2,000)" : "") + " for \"" + sys.tweakQuery + "\"", "", (n > 0 ? "" : "!") + "DUMP TO FILE", "tk_tdump", "");
    let per = 10;
    let pages = TKSheet.Pages(n, per);
    let page = Clamp(sys.tweakPage, 0, pages - 1);
    let i = page * per;
    while i < n && i < (page + 1) * per {
      let hit = sys.tweakHits[i];
      let spawnable = StrBeginsWith(hit, "Character.") || StrBeginsWith(hit, "Vehicle.");
      p.Buttons(hit, "", "", "COPY|FLATS|" + (spawnable ? "" : "!") + "SPAWN", "tk_copy|tk_tflats|tk_tspawn", hit + "\n" + hit + "\n" + hit);
      i += 1;
    }
    if pages > 1 {
      p.Pager(page, pages, "tk_tpage", "");
    }
  }

  // a record's flats
  public static func Flats(p: ref<TKPage>) -> Void {
    let sys = TKTools.Sys();
    p.SetTitle("RECORD", sys.flatsOf);
    TKTools.Nav(p, "tk_tweak");
    p.Buttons(sys.flatsOf, IntToString(ArraySize(sys.flats)) + " flats", "", "COPY NAME|DUMP TO FILE|BACK TO SEARCH", "tk_copy|tk_fdump|tk_go", sys.flatsOf + "\n\ntk_tweak");
    for f in sys.flats {
      p.Note(f);
    }
  }

  // ---------------------------------------------------------------------------
  // Log console
  // ---------------------------------------------------------------------------
  public static func Log(p: ref<TKPage>) -> Void {
    let sys = TKTools.Sys();
    p.SetTitle("LOG", "What mods wrote with TKLog.Add, newest first (kept for this session)");
    TKTools.Nav(p, "tk_log");
    p.Search("FILTER", sys.logFilter, "tk_filter", "tk_lfilter");
    let all = TKLog.Lines();
    let shown: array<String>;
    let k = ArraySize(all) - 1;
    let needle = StrLower(sys.logFilter);
    while k >= 0 {
      if StrLen(needle) == 0 || StrContains(StrLower(all[k]), needle) {
        ArrayPush(shown, all[k]);
      }
      k -= 1;
    }
    p.Buttons("LINES", IntToString(ArraySize(shown)) + " of " + IntToString(ArraySize(all)), "", "SAVE TO LOG.TXT|?CLEAR", "tk_lsave|tk_lclear", "\n");
    let per = 20;
    let pages = TKSheet.Pages(ArraySize(shown), per);
    let page = Clamp(sys.logPage, 0, pages - 1);
    let i = page * per;
    while i < ArraySize(shown) && i < (page + 1) * per {
      p.Note(shown[i]);
      i += 1;
    }
    if pages > 1 {
      p.Pager(page, pages, "tk_lpage", "");
    }
  }
}
