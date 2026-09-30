// =============================================================================
// TERMINAL KIT - THE PAGE MODEL
// A page is a list of rows a content provider (TKContent) fills in and TKView
// draws. Rows are data: a kind, texts, a colour, and for action rows a typed
// list of buttons (label, action, args) split once here, so the renderer never
// re-parses a packed string. The string builders below ("A|B" labels, "a|b"
// actions, "x|y" or "x\ny" args) stay for convenience; the typed builders take
// arrays. TerminalKit has no dependency on the mod using it: it needs only
// Codeware (buttons, text boxes) and RedFunctions (the mouse state).
// =============================================================================
module TerminalKit

import Codeware.UI.*

// row kinds
public abstract class TKKind {
  public static func Heading() -> Int32 = 1
  public static func Text() -> Int32 = 2
  public static func Pair() -> Int32 = 3
  public static func Meter() -> Int32 = 4
  public static func Button() -> Int32 = 5
  public static func Note() -> Int32 = 6
  public static func Gap() -> Int32 = 7
  public static func Item() -> Int32 = 8
  public static func Links() -> Int32 = 9
  public static func Buttons() -> Int32 = 12
  public static func Slider() -> Int32 = 13
  public static func Track() -> Int32 = 14
  public static func Section() -> Int32 = 15
  public static func Input() -> Int32 = 16
  public static func Entry() -> Int32 = 17
  public static func Dossier() -> Int32 = 18
  public static func Columns() -> Int32 = 19
  public static func Custom() -> Int32 = 20
  public static func Table() -> Int32 = 21
  public static func Card() -> Int32 = 22
  public static func Board() -> Int32 = 23
  public static func ColumnStart() -> Int32 = 24
  public static func ColumnsEnd() -> Int32 = 25
  public static func Ticker() -> Int32 = 26
  public static func Stat() -> Int32 = 27
  public static func Tile() -> Int32 = 28
  public static func Dropdown() -> Int32 = 29
  public static func Check() -> Int32 = 30
  public static func Search() -> Int32 = 31
  public static func SortHead() -> Int32 = 32
  public static func Pager() -> Int32 = 33
  public static func Live() -> Int32 = 34
  public static func Message() -> Int32 = 35
  public static func Choice() -> Int32 = 36
  public static func Gauge() -> Int32 = 37
  public static func Stack() -> Int32 = 38
  public static func File() -> Int32 = 39
  public static func Posting() -> Int32 = 40
  public static func Run() -> Int32 = 41
}

public class TKRow extends IScriptable {
  public let kind: Int32;
  public let text: String;
  public let value: String;
  public let color: String;
  public let label: String;      // raw: labels, or a data field for data rows (see each builder)
  public let action: String;     // raw actions, or data
  public let arg: String;        // raw args, or data
  public let fraction: Float;
  public let on: Bool;
  public let extra: String;      // what a row needs beyond the rest (Levels: "level:max"; a custom row's payload)
  public let tip: String;        // shown when the cursor rests on the row's title
  public let image: String;      // a File's portrait: "kind|atlas|part" (SetPortrait)
  // action rows only: the buttons, typed
  public let labels: array<String>;
  public let actions: array<String>;
  public let args: array<String>;

  public func IsAction() -> Bool = ArraySize(this.actions) > 0
}

// String helpers the kit needs (empty parts count, unlike StrSplit)
public abstract class TKStr {
  public static func Split(s: String, sep: String) -> array<String> {
    let parts: array<String>;
    let n = StrLen(sep);
    let at = n > 0 ? StrFindFirst(s, sep) : -1;
    while at >= 0 {
      ArrayPush(parts, StrLeft(s, at));
      s = StrMid(s, at + n, StrLen(s) - at - n);
      at = StrFindFirst(s, sep);
    }
    ArrayPush(parts, s);
    return parts;
  }

  public static func Part(s: String, sep: String, i: Int32) -> String {
    let parts = TKStr.Split(s, sep);
    return i < ArraySize(parts) ? parts[i] : "";
  }

  public static func Join(parts: array<String>, sep: String) -> String {
    let out = "";
    let i = 0;
    while i < ArraySize(parts) {
      out += (i > 0 ? sep : "") + parts[i];
      i += 1;
    }
    return out;
  }
}

public class TKPage extends IScriptable {
  public let page: String;
  public let answered: Bool;
  public let title: String;
  public let subtitle: String;
  public let message: String;
  public let nextPage: String;
  public let nextArg: String;
  public let theme: String;        // palette id (TKTheme), "" = keep the current one
  public let rebuild: Bool;        // an action changed the layout: rebuild the whole frame
  public let skipRedraw: Bool;     // an action handled everything itself: don't redraw
  public let section: String;      // sidebar tab to highlight ("" = the page itself)
  public let bare: Bool;           // hide the frame around the page (a page that needs the world in view)
  public let wheelReserved: Bool;  // a row on this page uses the mouse wheel itself: the page doesn't scroll
  public let rows: array<ref<TKRow>>;
  // text boxes on the page (Input rows), handed to Act with every action
  public let fieldKeys: array<String>;
  public let fieldValues: array<String>;
  public let content: ref<TKContent>;   // who fills and acts on it (set by the view)
  // an action asking for a yes first (Confirm): the view shows the dialog after the redraw
  public let confirmText: String;
  public let confirmYes: String;
  public let confirmAction: String;
  public let confirmArg: String;

  public func Request(page: String, arg: String) -> Void {
    if IsDefined(this.content) {
      this.content.Request(this, page, arg);
    }
  }

  public func Act(action: String, arg: String) -> Void {
    if IsDefined(this.content) {
      this.content.Act(this, action, arg);
    }
  }

  public func SetTitle(title: String, subtitle: String) -> Void {
    this.title = title;
    this.subtitle = subtitle;
    this.answered = true;
  }
  public func SetMessage(text: String) -> Void { this.message = text; this.answered = true; }
  public func GoTo(page: String, arg: String) -> Void { this.nextPage = page; this.nextArg = arg; }
  public func SetTheme(id: String) -> Void { this.theme = id; }
  public func Rebuild() -> Void { this.rebuild = true; }
  public func SetSection(id: String) -> Void { this.section = id; }
  public func Bare() -> Void { this.bare = true; }
  public func GetField(key: String) -> String {
    let i = 0;
    while i < ArraySize(this.fieldKeys) {
      if Equals(this.fieldKeys[i], key) {
        return this.fieldValues[i];
      }
      i += 1;
    }
    return "";
  }

  public func Row(i: Int32) -> ref<TKRow> = i >= 0 && i < ArraySize(this.rows) ? this.rows[i] : new TKRow()
  public func Count() -> Int32 = ArraySize(this.rows)

  // ---- raw rows: data in label / action / arg ----
  private func Push(kind: Int32, text: String, value: String, color: String, label: String, action: String, arg: String, fraction: Float, on: Bool) -> ref<TKRow> {
    let r = new TKRow();
    r.kind = kind; r.text = text; r.value = value; r.color = color;
    r.label = label; r.action = action; r.arg = arg;
    r.fraction = fraction; r.on = on;
    ArrayPush(this.rows, r);
    this.answered = true;
    return r;
  }

  // ---- action rows: the buttons split once, typed ----
  // labels "A|B" (a leading "!" = disabled), actions "a|b", args "x|y" or
  // "x\ny" (when an arg itself holds "|"). A row with one action keeps its
  // whole arg string, "|" and all.
  private func PushAct(kind: Int32, text: String, value: String, color: String, labels: String, actions: String, args: String, fraction: Float, on: Bool) -> ref<TKRow> {
    let r = this.Push(kind, text, value, color, labels, actions, args, fraction, on);
    let names = TKStr.Split(labels, "|");
    let acts = TKStr.Split(actions, "|");
    let vals = ArraySize(acts) > 1 ? (StrContains(args, "\n") ? TKStr.Split(args, "\n") : TKStr.Split(args, "|")) : [args];
    let k = 0;
    while k < ArraySize(acts) {
      ArrayPush(r.labels, k < ArraySize(names) ? names[k] : "");
      ArrayPush(r.actions, acts[k]);
      ArrayPush(r.args, k < ArraySize(vals) ? vals[k] : "");
      k += 1;
    }
    return r;
  }

  // the typed builder: one entry per button
  public func Actions(kind: Int32, text: String, value: String, color: String, labels: array<String>, actions: array<String>, args: array<String>, fraction: Float, on: Bool) -> ref<TKRow> {
    let r = this.Push(kind, text, value, color, TKStr.Join(labels, "|"), TKStr.Join(actions, "|"), TKStr.Join(args, "\n"), fraction, on);
    r.labels = labels; r.actions = actions; r.args = args;
    return r;
  }

  public func Heading(text: String) -> Void { this.Push(TKKind.Heading(), text, "", "red", "", "", "", 0.0, false); }
  public func Text(text: String, color: String) -> Void { this.Push(TKKind.Text(), text, "", color, "", "", "", 0.0, false); }
  public func Pair(label: String, value: String, color: String) -> Void { this.Push(TKKind.Pair(), label, value, color, "", "", "", 0.0, false); }
  public func Meter(label: String, value: String, fraction: Float) -> Void { this.Push(TKKind.Meter(), label, value, "yellow", "", "", "", fraction, false); }
  public func Button(label: String, action: String, arg: String, on: Bool) -> Void { this.PushAct(TKKind.Button(), "", "", "", label, action, arg, 0.0, on); }
  public func Note(text: String) -> Void { this.Push(TKKind.Note(), text, "", "dim", "", "", "", 0.0, false); }
  // A note under an item row, wrapped at the row's text width (clear of its button)
  public func ItemNote(text: String) -> Void { this.Push(TKKind.Note(), text, "item", "dim", "", "", "", 0.0, false); }
  public func Gap() -> Void { this.Push(TKKind.Gap(), "", "", "", "", "", "", 0.0, false); }
  public func Item(text: String, value: String, color: String, label: String, action: String, arg: String, on: Bool) -> Void {
    this.PushAct(TKKind.Item(), text, value, color, label, action, arg, 0.0, on);
  }
  // An item with a level track left of its button: boxes I, II, III... up to
  // `max`, the first `level` filled
  public func Levels(text: String, value: String, color: String, level: Int32, max: Int32, label: String, action: String, arg: String, on: Bool) -> Void {
    this.PushAct(TKKind.Item(), text, value, color, label, action, arg, 0.0, on).extra = IntToString(level) + ":" + IntToString(max);
  }
  // A table line: cells "a|b|c" across the columns `cols` ("L50|R25|R25": each
  // cell left or right aligned in its share of the row's width, in %). Styles:
  // "head" column titles, "group" a small heading inside the table, "line"
  // (every other one shaded), "total" (a rule above), "net" (larger, a double
  // rule under). Amounts starting with "+" show green, with "-" red, a lone "-"
  // dim; a cell starting with "!" shows red (the "!" isn't shown).
  public func Ledger(style: String, cells: String, cols: String) -> Void {
    this.Push(TKKind.Table(), cells, cols, style, "", "", "", 0.0, true);
  }
  // A listing card. Cards sit side by side and wrap to a new line when the row
  // is full. head "tag|title|sub|price": the tag in `color` over a dark strip,
  // the price large; details "a|b|c", a line each. In both, a leading "!" shows
  // red and "*" green (neither is shown), "+" amounts green. Buttons along the
  // bottom as in Buttons; `bright` false dims the card; a "*colour" frames it.
  public func Card(head: String, details: String, color: String, labels: String, actions: String, args: String, bright: Bool) -> Void {
    this.PushAct(TKKind.Card(), head, details, color, labels, actions, args, 0.0, bright);
  }
  // A personnel file, laid out in a grid like cards. head "FILE #|NAME|ROLE
  // LINE|STAMP": the number and a barcode along the top, the stamp top right, a
  // mugshot frame with the initials, the name and role beside it. stats
  // "HP:3|STR:2" as bars out of 10; lines "a|b" (card marks); a quote. Buttons
  // along the bottom as in Card; a "*colour" frames it.
  public func File(head: String, stats: String, lines: String, quote: String, color: String, labels: String, actions: String, args: String, bright: Bool) -> Void {
    this.PushAct(TKKind.File(), head, stats + "\n" + lines + "\n" + quote, color, labels, actions, args, 0.0, bright);
  }
  // A job posting on a board, laid out in a grid like cards. head "POST #|TITLE|
  // CLIENT|PAY|TIME LEFT"; chips "HEIST|TIER 3|!HOT" (a mark colours a chip);
  // lines "a|b" (card marks); odds 0..1 on a meter (below 0: none). Buttons
  // along the bottom as in Card; a "*colour" frames it.
  public func Posting(head: String, chips: String, lines: String, odds: Float, color: String, labels: String, actions: String, args: String, bright: Bool) -> Void {
    this.PushAct(TKKind.Posting(), head, chips + "\n" + lines, color, labels, actions, args, odds, bright);
  }
  // A run in progress, laid out in a grid like cards. head "TAG|TITLE|SUB|STAMP";
  // lines "a|b" (card marks); a live bar fills from `start` to `end` (TKClock
  // time) with the percent and the time left. Buttons along the bottom as in Card.
  public func Run(head: String, lines: String, start: Float, end: Float, color: String, labels: String, actions: String, args: String, bright: Bool) -> Void {
    this.PushAct(TKKind.Run(), head, lines + "\n" + FloatToString(start) + "|" + FloatToString(end), color, labels, actions, args, 0.0, bright);
  }
  // A departures board line: cells across the columns `cols` (as Ledger) on dark
  // split-flap tiles in amber; style "title" (large, no tiles, a rule under it),
  // "head" (column titles) or "line". A cell mark "!" shows red, "*" green, "^"
  // bright yellow, "~" grey. A button on the right when `label` isn't empty.
  public func Board(style: String, cells: String, cols: String, label: String, action: String, arg: String, on: Bool) -> Void {
    this.PushAct(TKKind.Board(), cells, cols, style, label, action, arg, 0.0, on);
  }
  // A market tile, laid out in a grid like cards: the name, today's value large,
  // the change ("*UP 6%" green, "!DOWN 9%" red), a line through `series`
  // ("0.92,1.04,..." oldest first) with a faint mark at 1.00, and a note under it
  public func Ticker(name: String, value: String, change: String, series: String, note: String) -> Void {
    this.Push(TKKind.Ticker(), name + "|" + value + "|" + change + "|" + note, series, "", "", "", "", 0.0, true);
  }
  // A dial tile in a grid (like cards): the name, a half-circle of ticks lit up to
  // `fraction` (red, amber, green from low to high; one colour when `color` is set)
  // with a needle, the value under it (card marks) and a line along the bottom
  public func Gauge(name: String, value: String, sub: String, fraction: Float, color: String) -> Void {
    this.Push(TKKind.Gauge(), name + "|" + value + "|" + sub, "", color, "", "", "", fraction, true);
  }
  // A bar split into parts, a legend under it: names "A|B", shares "0.2|0.35"
  // (0..1 of the whole bar, the rest left empty), colours "cyan|red"
  public func Stack(label: String, value: String, names: String, shares: String, colors: String) -> Void {
    this.Push(TKKind.Stack(), label, value, "", names, shares, colors, 0.0, true);
  }
  // A stat tile in a grid (like cards): the name, the value large, a line under
  // it (card marks: "!" red, "*" green) and a bar filled to `fraction` (below 0: none)
  public func Stat(name: String, value: String, sub: String, fraction: Float) -> Void {
    this.Push(TKKind.Stat(), name + "|" + value + "|" + sub, "", "", "", "", "", fraction, true);
  }
  // A small tile in a grid (like cards) that opens something: a bar and the name in
  // `color`, the value large, a line under it (card marks), a button along the bottom
  public func Tile(name: String, value: String, sub: String, color: String, label: String, action: String, arg: String, on: Bool) -> Void {
    this.PushAct(TKKind.Tile(), name + "|" + value + "|" + sub, "", color, label, action, arg, 0.0, on);
  }
  // The rows after this go in a column `share` (0..1) of the page's width, to the
  // right of the column before it; EndColumns goes back to the full width
  public func Column(share: Float) -> Void { this.Push(TKKind.ColumnStart(), "", "", "", "", "", "", share, true); }
  public func EndColumns() -> Void { this.Push(TKKind.ColumnsEnd(), "", "", "", "", "", "", 0.0, true); }
  // Item with several buttons on the right: labels "A|B", actions "a|b", args
  // "x|y" (same order). A label starting with "!" is shown disabled.
  public func Buttons(text: String, value: String, color: String, labels: String, actions: String, args: String) -> Void {
    this.PushAct(TKKind.Buttons(), text, value, color, labels, actions, args, 0.0, true);
  }
  // A slider: spec "min|max|step|value|suffix" (e.g. "0|50|1|25|%"). Click or drag
  // on the bar; letting go calls Act(action, arg + ":" + value).
  public func Slider(text: String, value: String, color: String, spec: String, action: String, arg: String) -> Void {
    this.PushAct(TKKind.Slider(), text, value, color, spec, action, arg, 0.0, true);
  }
  // A meter with named marks under it: names "A|B|C", marks "0|0.2|0.4" (0..1, same order)
  public func Track(text: String, value: String, fraction: Float, names: String, marks: String) -> Void {
    this.Push(TKKind.Track(), text, value, "", names, marks, "", fraction, true);
  }
  // A text box: label on the left, the box starts with `value`; its text reaches
  // the provider as GetField(field) when any button on the page is pressed
  public func Input(label: String, value: String, field: String) -> Void {
    this.Push(TKKind.Input(), label, value, "", "", "", field, 0.0, true);
  }
  // A collapsible section heading: clicking it (or its button) runs action / arg
  public func Section(text: String, value: String, open: Bool, action: String, arg: String) -> Void {
    this.PushAct(TKKind.Section(), text, value, "", open ? "CLOSE" : "OPEN", action, arg, 0.0, open);
  }
  // A feed entry: time, status, tag, headline (coloured), details "a|b|c" set
  // apart by separator bars, and a quoted report under it
  public func Entry(time: String, status: String, tag: String, head: String, details: String, quote: String, color: String) -> Void {
    this.Push(TKKind.Entry(), head, details, color, time + "|" + status + "|" + tag, quote, "", 0.0, true);
  }
  // A dossier header: name, the line under it, a status stamp in `color`
  public func Dossier(name: String, line: String, stamp: String, color: String) -> Void {
    this.Push(TKKind.Dossier(), name, line, color, stamp, "", "", 0.0, true);
  }
  // Two columns of label / value pairs ("A|B", "1|2" per side); a label starting
  // with "#" is a small heading
  public func Columns(leftLabels: String, leftValues: String, rightLabels: String, rightValues: String) -> Void {
    this.Push(TKKind.Columns(), leftLabels, leftValues, "", rightLabels, rightValues, "", 0.0, true);
  }
  // labels "A|B|C", targets "page|page~arg|..." (same order), current = the target shown as selected
  public func Links(labels: String, targets: String, current: String) -> Void {
    this.Push(TKKind.Links(), labels, targets, "", current, "", "", 0.0, true);
  }
  // A row the content provider draws itself (TKContent.Custom): `tag` says what,
  // the rest is its data; `wheel` true when it takes the mouse wheel
  public func Custom(tag: String, a: String, b: String, c: String, d: String, wheel: Bool) -> Void {
    this.Push(TKKind.Custom(), tag, a, b, c, d, "", 0.0, true);
    if wheel {
      this.wheelReserved = true;
    }
  }
  // ---- controls ----
  // A drop-down: the current choice on a button; clicking lists `labels` ("A|B|C");
  // picking one calls Act(action, arg + ":" + its value from `values` ("a|b|c"))
  public func Dropdown(text: String, value: String, current: String, labels: String, values: String, action: String, arg: String) -> Void {
    let r = this.Push(TKKind.Dropdown(), text, value, "", labels, action, arg, 0.0, true);
    r.labels = TKStr.Split(labels, "|");
    r.args = TKStr.Split(values, "|");
    r.extra = current;
  }
  // A check box: clicking calls Act(action, arg + ":1") to tick it, ":0" to clear it
  public func Check(text: String, value: String, on: Bool, action: String, arg: String) -> Void {
    this.Push(TKKind.Check(), text, value, "", "", action, arg, 0.0, on);
  }
  // A search box with its button: pressing it (or any button on the page) hands
  // the text to Act as GetField(field); the button calls Act(action, text)
  public func Search(label: String, value: String, field: String, action: String) -> Void {
    let r = this.PushAct(TKKind.Search(), label, value, "", "SEARCH", action, "", 0.0, true);
    r.extra = field;
  }
  // A table head whose columns sort: cells and cols as Ledger; the sorted column
  // `col` shows ^ (ascending) or v (descending); clicking column k calls
  // Act(action, arg + ":" + k). TKSheet builds these for you.
  public func SortHead(cells: String, cols: String, col: Int32, desc: Bool, action: String, arg: String) -> Void {
    this.Push(TKKind.SortHead(), cells, cols, "", "", action, arg, Cast<Float>(col), desc);
  }
  // PREV / PAGE x OF y / NEXT: calls Act(action, arg + ":" + the new page), pages from 0
  public func Pager(page: Int32, pages: Int32, action: String, arg: String) -> Void {
    let prefix = StrLen(arg) > 0 ? arg + ":" : "";
    let r = this.PushAct(TKKind.Pager(), "PAGE " + IntToString(page + 1) + " OF " + IntToString(Max(1, pages)), "", "",
      (page > 0 ? "" : "!") + "PREV|" + (page < pages - 1 ? "" : "!") + "NEXT", action + "|" + action,
      prefix + IntToString(Max(0, page - 1)) + "\n" + prefix + IntToString(Min(Max(0, pages - 1), page + 1)), 0.0, true);
    r.fraction = Cast<Float>(page);
  }
  // A countdown that ticks on game time without redrawing: the time left to
  // `endsAt` (TKClock.Now() seconds) and a bar of what's left of `total`. When it
  // runs out it calls Act(action, arg) once (none when `action` is empty).
  public func Countdown(text: String, value: String, endsAt: Float, total: Float, action: String, arg: String) -> Void {
    this.Push(TKKind.Live(), text, value, "", FloatToString(endsAt - total) + "|" + FloatToString(endsAt) + "|0", action, arg, 0.0, true);
  }
  // A progress bar from `start` to `end` (game seconds) with its percentage, live
  public func Progress(text: String, value: String, start: Float, end: Float, action: String, arg: String) -> Void {
    this.Push(TKKind.Live(), text, value, "", FloatToString(start) + "|" + FloatToString(end) + "|1", action, arg, 0.0, true);
  }
  // One entry of a selectable list (a master list beside its detail): a small
  // label over the value, a bar in `color`, the chosen one filled and framed.
  // Clicking it calls Act(action, arg).
  public func Choice(label: String, value: String, color: String, chosen: Bool, action: String, arg: String) -> Void {
    this.Push(TKKind.Choice(), value, label, color, "", action, arg, 0.0, chosen);
  }
  // A message in a thread: `who` and `time` over the text, V's own (`mine`) on the right
  public func Message(who: String, time: String, text: String, mine: Bool, color: String) -> Void {
    this.Push(TKKind.Message(), text, who, color, time, "", "", 0.0, mine);
  }
  // From Act: ask first. The page redraws, then a dialog asks `text`; `yes`
  // (the button) runs Act(action, arg). A button label starting with "?" does
  // the same by itself ("?SELL ALL" asks "SELL ALL?").
  public func Confirm(text: String, yes: String, action: String, arg: String) -> Void {
    this.confirmText = text;
    this.confirmYes = yes;
    this.confirmAction = action;
    this.confirmArg = arg;
  }

  // a tooltip on the row just added: shown when the cursor rests on its title
  public func SetTip(tip: String) -> Void {
    if ArraySize(this.rows) > 0 {
      this.rows[ArraySize(this.rows) - 1].tip = tip;
    }
  }
  // extra data on the row just added
  public func SetExtra(extra: String) -> Void {
    if ArraySize(this.rows) > 0 {
      this.rows[ArraySize(this.rows) - 1].extra = extra;
    }
  }
  // The portrait on the File just added: `kind` "m" or "f" draws a bust
  // silhouette ("" keeps the initials), with an emblem from `atlas` / `part`
  // behind it when given ("" for none)
  public func SetPortrait(kind: String, atlas: String, part: String) -> Void {
    if ArraySize(this.rows) > 0 {
      this.rows[ArraySize(this.rows) - 1].image = kind + "|" + atlas + "|" + part;
    }
  }
}

// What the kit needs from the mod: pages and actions, custom rows, and a word
// when the layout has to be rebuilt
public abstract class TKContent extends IScriptable {
  public func Request(p: ref<TKPage>, page: String, arg: String) -> Void {}
  public func Act(p: ref<TKPage>, action: String, arg: String) -> Void {}
  // draws a Custom row into `parent`; what it returns is stopped when the page goes away
  public func Custom(v: ref<TKView>, parent: ref<inkCompoundWidget>, p: ref<TKPage>, r: ref<TKRow>) -> ref<TKCustom> { return null; }
  // the layout changed under an open frame: rebuild it once the current callback is done
  public func Rebuild() -> Void {}
}

// a custom row's live object (a map, a chart...): told when its page is left
public abstract class TKCustom extends IScriptable {
  public func Stop() -> Void {}
}

// The frame around a view: the owner for global input, and whether the frame
// can hide itself around a bare page
public abstract class TKFrame extends IScriptable {
  public func Owner() -> ref<inkCustomController> { return null; }
  public func SetBare(bare: Bool) -> Void {}
}
