// =============================================================================
// TERMINAL KIT - CONTROLS
// Drop-downs, check boxes, search boxes, sortable table heads, pagers, live
// countdowns and progress bars, and message threads. The clicks land on the
// view (TKView.OnControlRelease), which opens the drop-down lists and dialogs
// on its overlay and runs the rows' actions.
// =============================================================================
module TerminalKit

public abstract class TKControls {
  // ---- drop-down: the current choice on a button, the list on the overlay ----
  public static func Dropdown(v: ref<TKView>, i: Int32, r: ref<TKRow>) -> Void {
    let bw = TKScale.F("dropdown.w", 420.0);
    let line = v.RowBox(v.RowWidth() - bw - 40.0, r.text, r.value, r.color, r.tip);
    let current = r.extra;
    let k = 0;
    while k < ArraySize(r.args) {
      if Equals(r.args[k], r.extra) && k < ArraySize(r.labels) {
        current = r.labels[k];
      }
      k += 1;
    }
    let b = v.ControlButton(line, current + "   v", "dd_" + IntToString(i), bw, TKScale.ButtonH(), TKScale.I("button.font", 30));
    v.PinRight(b.GetRootWidget());
  }

  // ---- check box: a framed square, filled when on ----
  public static func Check(v: ref<TKView>, i: Int32, r: ref<TKRow>) -> Void {
    let size = TKScale.F("check.size", 48.0);
    let line = v.RowBox(v.RowWidth() - size - 60.0, r.text, r.value, r.color, r.tip);
    let box: ref<inkCanvas> = new inkCanvas();
    box.SetSize(Vector2(size, size));
    box.Reparent(line);
    v.PinRight(box);
    box.SetMargin(inkMargin(0.0, 8.0, 12.0, 0.0));
    let back = TKInk.Rect(box, 0.0, 0.0, size, size);
    back.SetTintColor(new HDRColor(0.0, 0.0, 0.0, 1.0));
    back.SetOpacity(0.6);
    v.Frame(box, size, size, 3.0, "value", 1.0);
    if r.on {
      let tick = TKInk.Rect(box, 10.0, 10.0, size - 20.0, size - 20.0);
      v.Paint(tick, "value");
    }
    v.Clickable(box, "ck_" + IntToString(i));
  }

  // ---- search box: a text box and its button ----
  public static func Search(v: ref<TKView>, i: Int32, r: ref<TKRow>) -> Void {
    let bw = TKScale.F("search.button", 240.0);
    let row: ref<inkCanvas> = new inkCanvas();
    row.SetSize(Vector2(v.RowWidth(), 96.0));
    row.SetMargin(inkMargin(0.0, TKScale.F("row.gap", 10.0), 0.0, 0.0));
    row.SetHAlign(inkEHorizontalAlign.Left);
    row.Reparent(v.Content());
    v.Grew(106.0);
    let name = v.Text(row, r.text, TKScale.I("row.title", 32), n"Medium", "value", 0.0);
    name.SetMargin(inkMargin(0.0, 24.0, 0.0, 0.0));
    v.TextBox(row, r.value, r.extra, 440.0, v.RowWidth() - 460.0 - bw - 24.0);
    v.PinRight(v.ActButton(row, i, 0, r.labels[0], true, bw, TKScale.ButtonH(), TKScale.I("button.font", 30)).GetRootWidget());
  }

  // ---- sortable head: each column a click target, the sorted one marked ----
  public static func SortHead(v: ref<TKView>, i: Int32, r: ref<TKRow>) -> Void {
    let size = Max(14, TKScale.I("table.font", 28) - 4);
    let w = v.RowWidth();
    let h = Cast<Float>(size) * 1.9;
    let c = v.Content();
    let row: ref<inkCanvas> = new inkCanvas();
    row.SetSize(Vector2(w, h));
    row.SetHAlign(inkEHorizontalAlign.Left);
    row.Reparent(c);
    v.Grew(h + 6.0);
    v.tableLine = 0;
    let spec = TKStr.Split(r.value, "|");
    let parts = TKStr.Split(r.text, "|");
    let sorted = RoundF(r.fraction);
    let x = 0.0;
    let k = 0;
    while k < ArraySize(spec) {
      let right = StrBeginsWith(spec[k], "R");
      let cw = w * StringToFloat(StrMid(spec[k], 1, StrLen(spec[k]) - 1), 0.0) / 100.0;
      let cell: ref<inkCanvas> = new inkCanvas();
      cell.SetSize(Vector2(MaxF(10.0, cw - 8.0), h));
      cell.SetMargin(inkMargin(x + 4.0, 0.0, 0.0, 0.0));
      cell.Reparent(row);
      if k == sorted {
        let lit = TKInk.Rect(cell, 0.0, 0.0, MaxF(10.0, cw - 8.0), h);
        v.Paint(lit, "rule");
        lit.SetOpacity(0.35);
      }
      let label = (k < ArraySize(parts) ? parts[k] : "") + (k == sorted ? (r.on ? "  v" : "  ^") : "");
      let t = v.Text(cell, label, size, n"Semi-Bold", k == sorted ? "value" : "text", 0.0);
      t.SetAnchor(right ? inkEAnchor.CenterRight : inkEAnchor.CenterLeft);
      t.SetAnchorPoint(Vector2(right ? 1.0 : 0.0, 0.5));
      t.SetMargin(inkMargin(right ? 0.0 : 8.0, 0.0, right ? 8.0 : 0.0, 0.0));
      if right {
        t.SetHorizontalAlignment(textHorizontalAlignment.Right);
      }
      v.Clickable(cell, "so_" + IntToString(i) + "_" + IntToString(k));
      x += cw;
      k += 1;
    }
    v.Rule(c, 0.0, 0.6);
  }

  // ---- pager: PREV  PAGE 2 OF 5  NEXT, centred ----
  public static func Pager(v: ref<TKView>, i: Int32, r: ref<TKRow>) -> Void {
    let bw = TKScale.F("pager.w", 220.0);
    let bh = TKScale.F("pager.h", 56.0);
    let strip = TKInk.Strip(v.Content(), 12.0);
    let label = 360.0;
    strip.SetMargin(inkMargin(MaxF(0.0, (v.RowWidth() - bw * 2.0 - label) / 2.0), 12.0, 0.0, 0.0));
    v.ActButton(strip, i, 0, r.labels[0], true, bw, bh, 24);
    let mid: ref<inkCanvas> = new inkCanvas();
    mid.SetSize(Vector2(label, bh));
    mid.Reparent(strip);
    let t = v.Text(mid, r.text, TKScale.I("row.detail", 29), n"Semi-Bold", "text", 0.0);
    t.SetAnchor(inkEAnchor.Centered);
    t.SetAnchorPoint(Vector2(0.5, 0.5));
    v.ActButton(strip, i, 1, r.labels[1], true, bw, bh, 24);
    v.Grew(bh + 12.0);
  }

  // ---- live row: a meter the view updates every second from game time ----
  public static func Live(v: ref<TKView>, i: Int32, r: ref<TKRow>) -> Void {
    let c = v.Content();
    let top = TKInk.Strip(c, 10.0);
    let font = TKScale.I("meter.font", 30);
    v.Hoverable(v.Text(top, r.text, font, n"Medium", "text", 0.0), r.tip);
    let readout = v.Text(top, "", font, n"Semi-Bold", "value", 0.0);
    readout.SetMargin(inkMargin(24.0, 0.0, 0.0, 0.0));
    if StrLen(r.value) > 0 {
      let note = v.Text(top, r.value, TKScale.I("row.detail", 29), n"Regular", "text", 0.0);
      note.SetMargin(inkMargin(24.0, 0.0, 0.0, 0.0));
      note.SetOpacity(0.8);
    }
    let w = MinF(TKScale.F("meter.w", 900.0), v.RowWidth());
    let h = TKScale.F("meter.h", 10.0) + 4.0;
    let track: ref<inkCanvas> = new inkCanvas();
    track.SetSize(Vector2(w, h));
    track.SetMargin(inkMargin(0.0, 6.0, 0.0, 0.0));
    track.SetHAlign(inkEHorizontalAlign.Left);
    track.Reparent(c);
    let bed = TKInk.Rect(track, 0.0, 0.0, w, h);
    v.Paint(bed, "rule");
    bed.SetOpacity(0.5);
    let fill = TKInk.Rect(track, 0.0, 0.0, 2.0, h);
    v.Fix(fill, TKTheme.Gold());
    let spec = TKStr.Split(r.label, "|");
    v.AddLive(i, fill, readout, w, StringToFloat(spec[0], 0.0), StringToFloat(TKStr.Part(r.label, "|", 1), 0.0), StringToInt(TKStr.Part(r.label, "|", 2), 0));
    v.Grew(Cast<Float>(font) * 1.4 + h + 20.0);
  }

  // ---- a message: a bubble with who and when over the text; V's own on the right ----
  public static func Message(v: ref<TKView>, r: ref<TKRow>) -> Void {
    let mine = r.on;
    let width = MinF(TKScale.F("message.w", 1300.0), v.RowWidth() * 0.75);
    let font = TKScale.I("note", 26) + 2;
    let small = TKScale.I("type.xs", 24) - 2;
    let pad = 22.0;
    let textH = TKInk.Lines(r.text, font, width - pad * 2.0) * Cast<Float>(font) * 1.35;
    let h = textH + Cast<Float>(small) * 1.4 + pad * 2.0 + 6.0;
    let line: ref<inkCanvas> = new inkCanvas();
    line.SetSize(Vector2(v.RowWidth(), h));
    line.SetMargin(inkMargin(0.0, 12.0, 0.0, 0.0));
    line.SetHAlign(inkEHorizontalAlign.Left);
    line.Reparent(v.Content());
    v.Grew(h + 12.0);
    let box: ref<inkCanvas> = new inkCanvas();
    box.SetSize(Vector2(width, h));
    if mine {
      box.SetAnchor(inkEAnchor.TopRight);
      box.SetAnchorPoint(Vector2(1.0, 0.0));
    }
    box.Reparent(line);
    let back = TKInk.Rect(box, 0.0, 0.0, width, h);
    back.SetTintColor(new HDRColor(0.0, 0.0, 0.0, 1.0));
    back.SetOpacity(mine ? 0.45 : 0.65);
    let edge = TKInk.Rect(box, mine ? width - 5.0 : 0.0, 0.0, 5.0, h);
    v.Paint(edge, mine ? "value" : "accent");
    v.Tone(edge, r.color);
    let head = v.Text(box, r.value + (StrLen(r.label) > 0 ? "   " + r.label : ""), small, n"Semi-Bold", mine ? "value" : "accent", 0.0);
    head.SetMargin(inkMargin(pad, pad - 6.0, 0.0, 0.0));
    v.Tone(head, r.color);
    let t = v.Text(box, r.text, font, n"Regular", "text", 0.0);
    t.SetLetterCase(textLetterCase.OriginalCase);
    t.SetWrapping(true, width - pad * 2.0);
    t.SetMargin(inkMargin(pad, pad + Cast<Float>(small) * 1.4, 0.0, 0.0));
    t.SetVAlign(inkEVerticalAlign.Top);
  }
}
