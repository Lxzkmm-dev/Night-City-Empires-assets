// =============================================================================
// TERMINAL KIT - DATA HELPERS
// TKClock: game time, and "2h 05m" for what's left.
// TKSheet: a sortable, paged table: add lines, then Show draws a sortable head,
//   the lines of the current page and a pager.
// TKLog: a small in-memory log any mod can write to (the Tools pack shows it
//   in its log console page and saves it to a file).
// =============================================================================
module TerminalKit

import RedFunctions.*

public abstract class TKClock {
  // game time in seconds (runs while playing, jumps when V sleeps or waits)
  public static func Now() -> Float = GameInstance.GetTimeSystem(GetGameInstance()).GetGameTimeStamp()

  // "2h 05m", "14m", "40s"
  public static func Left(secs: Float) -> String {
    let s = Max(0, CeilF(secs));
    if s >= 3600 {
      let m = (s % 3600) / 60;
      return IntToString(s / 3600) + "h " + (m < 10 ? "0" : "") + IntToString(m) + "m";
    }
    if s >= 60 {
      return IntToString(s / 60) + "m";
    }
    return IntToString(s) + "s";
  }
}

// ---- a sortable, paged table --------------------------------------------------------
public class TKSheet extends IScriptable {
  public let head: String;          // "NAME|DISTRICT|PRICE"
  public let cols: String;          // "L50|L25|R25" (as TKPage.Ledger)
  private let m_lines: array<String>;

  public static func Make(head: String, cols: String) -> ref<TKSheet> {
    let s = new TKSheet();
    s.head = head;
    s.cols = cols;
    return s;
  }

  public func Add(cells: String) -> Void { ArrayPush(this.m_lines, cells); }
  public func Count() -> Int32 = ArraySize(this.m_lines)
  public func Line(i: Int32) -> String = i >= 0 && i < ArraySize(this.m_lines) ? this.m_lines[i] : ""

  // Sorts by column `col`: cells that hold a number compare as numbers
  // ("12,500 E$", "-40", "3.5"), the rest as text. Stable.
  public func Sort(col: Int32, desc: Bool) -> Void {
    let n = ArraySize(this.m_lines);
    let i = 1;
    while i < n {
      let line = this.m_lines[i];
      let j = i - 1;
      while j >= 0 && TKSheet.After(this.m_lines[j], line, col, desc) {
        this.m_lines[j + 1] = this.m_lines[j];
        j -= 1;
      }
      this.m_lines[j + 1] = line;
      i += 1;
    }
  }

  // Draws the sortable head, page `page` of `per` lines and (with more than one
  // page) a pager. Clicking a column calls Act(sortAction, arg + ":" + column),
  // the pager Act(pageAction, arg + ":" + page).
  public func Show(p: ref<TKPage>, col: Int32, desc: Bool, page: Int32, per: Int32, sortAction: String, pageAction: String, arg: String) -> Void {
    this.Sort(col, desc);
    p.SortHead(this.head, this.cols, col, desc, sortAction, arg);
    let n = ArraySize(this.m_lines);
    let pages = TKSheet.Pages(n, per);
    let at = Clamp(page, 0, pages - 1);
    let i = at * per;
    while i < n && i < (at + 1) * per {
      p.Ledger("line", this.m_lines[i], this.cols);
      i += 1;
    }
    if pages > 1 {
      p.Pager(at, pages, pageAction, arg);
    }
  }

  public static func Pages(count: Int32, per: Int32) -> Int32 = Max(1, (count + Max(1, per) - 1) / Max(1, per))

  // true when line a belongs after line b
  private static func After(a: String, b: String, col: Int32, desc: Bool) -> Bool {
    let x = TKStr.Part(a, "|", col);
    let y = TKStr.Part(b, "|", col);
    let nx: Float;
    let ny: Float;
    let c: Int32;
    if TKSheet.Number(x, nx) && TKSheet.Number(y, ny) {
      c = nx > ny ? 1 : (nx < ny ? -1 : 0);
    } else {
      let d = StrCmp(StrLower(TKSheet.Bare(x)), StrLower(TKSheet.Bare(y)));
      c = d > 0 ? 1 : (d < 0 ? -1 : 0);
    }
    return desc ? c < 0 : c > 0;
  }

  // the cell without its colour mark
  private static func Bare(s: String) -> String {
    let m = StrLeft(s, 1);
    return Equals(m, "!") || Equals(m, "*") || Equals(m, "^") || Equals(m, "~") ? StrMid(s, 1, StrLen(s) - 1) : s;
  }

  // the number in a cell, if it holds one (digits with commas, a sign, a point)
  private static func Number(s: String, out value: Float) -> Bool {
    let t = TKSheet.Bare(s);
    let digits = "";
    let seen = false;
    let i = 0;
    while i < StrLen(t) {
      let ch = StrMid(t, i, 1);
      if StrContains("0123456789", ch) {
        digits += ch;
        seen = true;
      } else {
        if Equals(ch, ".") || (Equals(ch, "-") && !seen) {
          digits += ch;
        }
      }
      i += 1;
    }
    if !seen {
      return false;
    }
    value = StringToFloat(digits, 0.0);
    return true;
  }
}

// ---- the log ------------------------------------------------------------------------
public class TKLogSystem extends ScriptableSystem {
  public let lines: array<String>;

  public static func Get() -> ref<TKLogSystem> = GameInstance.GetScriptableSystemsContainer(GetGameInstance()).Get(n"TerminalKit.TKLogSystem") as TKLogSystem
}

public abstract class TKLog {
  public static func Max() -> Int32 = 500

  // "2026-09-30 01:12:44  ESCORT  the truck was brought round"
  public static func Add(tag: String, text: String) -> Void {
    let sys = TKLogSystem.Get();
    if !IsDefined(sys) {
      return;
    }
    ArrayPush(sys.lines, RedFunc.RealDate() + "  " + StrUpper(tag) + "  " + text);
    while ArraySize(sys.lines) > TKLog.Max() {
      ArrayErase(sys.lines, 0);
    }
  }

  public static func Lines() -> array<String> {
    let sys = TKLogSystem.Get();
    let none: array<String>;
    return IsDefined(sys) ? sys.lines : none;
  }

  public static func Clear() -> Void {
    let sys = TKLogSystem.Get();
    if IsDefined(sys) {
      ArrayClear(sys.lines);
    }
  }
}
