// =============================================================================
// HELLO TERMINAL - a TerminalKit example mod
// Press K (Input Loader) to open a terminal with four tabs: a home page, the
// controls, a map and the dev tools. Copy it as the start of your own mod.
// Needs TerminalKit (and TerminalKit Tools for the TOOLS tab), Codeware,
// RedFunctions and Input Loader.
// =============================================================================
module HelloTerminal

import TerminalKit.*
import TerminalKit.Tools.*

// ---- the frame: TerminalKit's ready-made one, named and given our pages ----
public class HelloTerminal extends TKPopup {
  public func Content() -> ref<TKContent> = new HelloContent()
  public func Tabs() -> array<String> = ["HOME|home", "CONTROLS|controls", "MAP|map", "TOOLS|tk_tools"]
  public func Brand() -> String = "TERMINAL KIT"
  public func Name() -> String = "HELLO TERMINAL"
  public func Status() -> String = "EXAMPLE // K TO CLOSE"
  public func StartPage() -> String = "home"
}

// ---- what the pages remember between clicks (not saved with the game) ----
public class HelloState extends ScriptableSystem {
  public let color: String = "cyan";
  public let loud: Bool;
  public let query: String;
  public let sortCol: Int32;
  public let sortDesc: Bool;
  public let sheetPage: Int32;
  public let timerEnds: Float;

  public static func Get() -> ref<HelloState> = GameInstance.GetScriptableSystemsContainer(GetGameInstance()).Get(n"HelloTerminal.HelloState") as HelloState
}

// ---- the pages ----
public class HelloContent extends TKContent {
  public func Request(p: ref<TKPage>, page: String, arg: String) -> Void {
    if TKTools.Request(p, page, arg) {
      p.SetSection("tk_tools");
      return;
    }
    switch page {
      case "controls": this.Controls(p); break;
      case "map": this.MapPage(p, arg); break;
      default: this.Home(p); break;
    }
  }

  private func Home(p: ref<TKPage>) -> Void {
    p.SetTitle("HOME", "Pages are rows you describe; TerminalKit draws them");
    p.Stat("EDDIES", "12,500", "*+2,100 today", 0.62);
    p.Stat("HEAT", "18%", "cooling", 0.18);
    p.Stat("CREW", "4 / 6", "!one wounded", 0.66);
    p.Heading("THE BOOKS");
    p.Ledger("head", "ITEM|IN|OUT", "L60|R20|R20");
    p.Ledger("line", "Courier run|+4,000|-", "L60|R20|R20");
    p.Ledger("line", "Safehouse rent|-|-1,900", "L60|R20|R20");
    p.Ledger("net", "TODAY|+4,000|-1,900", "L60|R20|R20");
    p.Heading("FOR SALE");
    p.Card("GARAGE|Kabuki Lock-Up|Watson|45,000 E$", "Room for two cars|*Near the market", "orange", "BUY|?SELL ALL", "hello_buy|hello_sell", "garage|garage", true);
    p.SetTip("Cards sit side by side and wrap; a '?' button asks first.");
    p.Item("A ROW WITH A BUTTON", "Text and a detail line on the left", "", "SAY HI", "hello_hi", "", true);
    p.SetTip("Rest the cursor on a title to see its tooltip.");
  }

  private func Controls(p: ref<TKPage>) -> Void {
    let st = HelloState.Get();
    p.SetTitle("CONTROLS", "Drop-downs, check boxes, search, sortable tables, live timers, messages");
    p.Dropdown("COLOUR", "Picked from a list", st.color, "CYAN|ORANGE|PURPLE", "cyan|orange|purple", "hello_color", "");
    p.Check("LOUD", "A check box", st.loud, "hello_loud", "");
    p.Search("SEARCH", st.query, "hello_query", "hello_search");
    if StrLen(st.query) > 0 {
      p.Text("You searched for: " + st.query, st.color);
    }
    // a sortable, paged table: add lines, TKSheet draws the head, the page and a pager
    let sheet = TKSheet.Make("NAME|DISTRICT|PRICE", "L45|L30|R25");
    sheet.Add("Kabuki Lock-Up|Watson|45,000");
    sheet.Add("Glen Stash|Heywood|18,500");
    sheet.Add("Arroyo Yard|Santo Domingo|120,000");
    sheet.Add("Charter Front|Westbrook|76,000");
    sheet.Add("Coastview Garage|Pacifica|9,900");
    sheet.Show(p, st.sortCol, st.sortDesc, st.sheetPage, 3, "hello_sort", "hello_page", "");
    // a countdown on game time, ticking without a redraw
    if st.timerEnds <= TKClock.Now() {
      st.timerEnds = TKClock.Now() + 7200.0;
    }
    p.Countdown("NEXT SHIPMENT", "two game hours from when you opened the page", st.timerEnds, 7200.0, "", "");
    p.Heading("MESSAGES");
    p.Message("ROGUE", "21:04", "Got a job for you. Quiet one. Don't make me regret it.", false, "");
    p.Message("V", "21:06", "Send the details.", true, "");
  }

  // the map row is drawn in Custom below
  private func MapPage(p: ref<TKPage>, arg: String) -> Void {
    p.SetTitle("MAP", "Drag to move, scroll to zoom, click a region or a pin");
    p.Custom("hello_map", arg, "", "", "", true);
  }

  public func Custom(v: ref<TKView>, parent: ref<inkCompoundWidget>, p: ref<TKPage>, r: ref<TKRow>) -> ref<TKCustom> {
    if !Equals(r.text, "hello_map") {
      return null;
    }
    // Night City's square, world metres; no images of our own, so the regions and
    // pins are drawn on the frame's dark background
    let s = TKMapSpec.Make(-3600.0, 3800.0, 7400.0);
    s.base = "";
    let zoom = StringToFloat(TKStr.Part(r.value, "|", 1), 1.0);
    let player = GetPlayer(GetGameInstance());
    let pos = IsDefined(player) ? player.GetWorldPosition() : Vector4(0.0, 0.0, 0.0, 1.0);
    let x = StrLen(TKStr.Part(r.value, "|", 3)) > 0 ? StringToFloat(TKStr.Part(r.value, "|", 3), pos.X) : pos.X;
    let y = StrLen(TKStr.Part(r.value, "|", 4)) > 0 ? StringToFloat(TKStr.Part(r.value, "|", 4), pos.Y) : pos.Y;
    s.View(zoom, StringToInt(TKStr.Part(r.value, "|", 2), 0), x, y, TKStr.Part(r.value, "|", 0), "map~%D|%Z|%M|%X|%Y");
    let a = s.AddRegion("north", "North Side", new HDRColor(0.35, 0.85, 1.0, 1.0));
    a.AddRing([-2400.0, 3000.0, -600.0, 3000.0, -600.0, 1200.0, -2400.0, 1200.0]);
    a.Label(-1500.0, 2100.0);
    let b = s.AddRegion("south", "South Side", new HDRColor(1.0, 0.6, 0.15, 1.0));
    b.AddRing([-1200.0, -600.0, 600.0, -600.0, 600.0, -2400.0, -1200.0, -2400.0]);
    b.Label(-300.0, -1500.0);
    s.AddPin(-1450.0, 1050.0, "A", "Afterlife", new HDRColor(1.0, 0.8, 0.25, 1.0), "home", "");
    s.AddPin(-300.0, -1500.0, "S", "Safehouse", new HDRColor(0.36, 0.94, 0.55, 1.0), "controls", "places");
    s.AddToggle(1, "HIDE PLACES", "SHOW PLACES", "places");
    s.AddLegend("LANDMARK", new HDRColor(1.0, 0.8, 0.25, 1.0), false, false);
    s.AddLegend("SAFEHOUSE", new HDRColor(0.36, 0.94, 0.55, 1.0), false, false);
    return TKMap.Place(v, parent, s, 1630.0, 1000.0);
  }

  public func Act(p: ref<TKPage>, action: String, arg: String) -> Void {
    if TKTools.Act(p, action, arg) {
      return;
    }
    let st = HelloState.Get();
    switch action {
      case "hello_hi": p.SetMessage("HI THERE"); break;
      case "hello_buy": p.SetMessage("BOUGHT THE " + StrUpper(arg)); break;
      case "hello_sell": p.SetMessage("SOLD EVERYTHING"); break;
      case "hello_color": st.color = arg; break;
      case "hello_loud": st.loud = Equals(arg, "1"); break;
      case "hello_search": st.query = arg; break;
      case "hello_sort":
        let col = StringToInt(arg, 0);
        st.sortDesc = col == st.sortCol ? !st.sortDesc : false;
        st.sortCol = col;
        break;
      case "hello_page": st.sheetPage = StringToInt(arg, 0); break;
    }
  }
}

// ---- the key (r6/input/HelloTerminal.xml) ----
public class HelloInput extends IScriptable {
  public let player: wref<PlayerPuppet>;
  public let open: wref<HelloTerminal>;

  protected cb func OnAction(action: ListenerAction, consumer: ListenerActionConsumer) -> Bool {
    if ListenerAction.IsButtonJustPressed(action) && Equals(ListenerAction.GetName(action), n"Hello_Open") {
      if IsDefined(this.open) && this.open.IsInitialized() {
        if !this.open.IsTyping() {
          this.open.Close();
        }
        return false;
      }
      if TKPopup.CanOpen(this.player) {
        let t = new HelloTerminal();
        this.open = t;
        TKPopup.Open(this.player, t);
      }
    }
    return false;
  }
}

@addField(PlayerPuppet)
private let m_helloInput: ref<HelloInput>;

@wrapMethod(PlayerPuppet)
protected cb func OnGameAttached() -> Bool {
  let result = wrappedMethod();
  this.m_helloInput = new HelloInput();
  this.m_helloInput.player = this;
  this.RegisterInputListener(this.m_helloInput, n"Hello_Open");
  return result;
}
