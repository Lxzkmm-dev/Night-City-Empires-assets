// =============================================================================
// TERMINAL KIT - CONSOLE PIECES
// Rows for an operator console (a fleet rack, a command deck, a status ribbon):
//   - Key: a keycap button showing the player's own key or pad button for an
//     input action; pressing that key runs it too
//   - Bay: a unit card for a rack: a wireframe thumbnail, an id line, the name,
//     a stamp, a 10-cell bar, a selected state; the whole card is a button
//   - Leds: a row of small status lights (any can blink)
//   - Ring: a radial meter tile with the value in the middle
//   - Compare: a value bar with a tick at the current value (a part on sale
//     against the fitted one)
//   - Feed: a one-line strip that scrolls (an ops feed)
//   - Wave: a small line through values, with a sweep running along it when live
// Keys, bays' neighbours and rings sit side by side like cards.
// =============================================================================
module TerminalKit

import Codeware.UI.*

public abstract class TKConsole {
  // ---- keycap: [glyph] LABEL, a short reason under it when it can't be used ----
  public static func Key(v: ref<TKView>, i: Int32, r: ref<TKRow>) -> Void {
    let red: Bool;
    let primary: Bool;
    let label = TKTheme.Unmark(r.text, red, primary);   // "!" off, "*" the primary key
    let off = red || !r.on;
    let w = TKScale.F("key.w", 330.0);
    let h = TKScale.F("key.h", StrLen(r.value) > 0 ? 104.0 : 84.0);
    let cell = v.GridCell(TKKind.Key(), w, h);
    v.Panel(cell, w, h, 0.6);
    if primary && !off {
      v.Frame(cell, w, h, 2.0, "accent", 1.0);
    }
    cell.SetOpacity(off ? 0.45 : 1.0);
    // the game's own key prompt (glyph and label); plain text when it can't be spawned
    let shown = false;
    let owner = v.Owner();
    if IsDefined(owner) && StrLen(r.label) > 0 {
      let hint = owner.SpawnFromExternal(cell, r"base\\gameplay\\gui\\common\\buttons\\base_buttons.inkwidget", n"inputDisplayLabelFlex");
      let ctrl = IsDefined(hint) ? hint.GetController() as LabelInputDisplayController : null;
      if IsDefined(ctrl) {
        hint.SetAnchor(inkEAnchor.TopLeft);
        hint.SetMargin(inkMargin(16.0, 14.0, 0.0, 0.0));
        ctrl.SetInputActionLabel(StringToName(r.label), TKScale.T(label));
        shown = true;
      }
    }
    if !shown {
      let t = v.Text(cell, "[" + StrUpper(r.label) + "]  " + label, TKScale.I("key.font", 28), n"Semi-Bold", primary ? "accent" : "value", 0.0);
      t.SetMargin(inkMargin(18.0, 18.0, 0.0, 0.0));
    }
    if StrLen(r.value) > 0 {
      let why = v.Text(cell, r.value, TKScale.TypeXS() - 4, n"Medium", "text", 0.0);
      why.SetMargin(inkMargin(18.0, h - 34.0, 0.0, 0.0));
      if off {
        v.Fix(why, TKTheme.Loss());
      }
    }
    v.Hit(cell, r.action, r.arg, r.tip, off);
    v.AddKey(StringToName(r.label), r.action, r.arg, off);
  }

  // ---- bay card: thumbnail, "BAY 01 · MINOTAUR", name, stamp, a 10-cell bar ----
  public static func Bay(v: ref<TKView>, i: Int32, r: ref<TKRow>) -> Void {
    let w = v.RowWidth();
    let h = TKScale.F("bay.h", 150.0);
    let box: ref<inkCanvas> = new inkCanvas();
    box.SetSize(Vector2(w, h));
    box.SetMargin(inkMargin(0.0, TKScale.F("row.gap", 10.0), 0.0, 0.0));
    box.SetHAlign(inkEHorizontalAlign.Left);
    box.Reparent(v.Content());
    v.Grew(h + TKScale.F("row.gap", 10.0));
    v.Panel(box, w, h, r.on ? 0.75 : 0.5);
    if r.on {
      // selected: a bar down the left edge and a frame in the accent colour
      v.Frame(box, w, h, 2.0, "accent", 1.0);
      v.Paint(TKInk.Rect(box, 0.0, 0.0, 6.0, h), "accent");
    }
    // the thumbnail: a wireframe (white lines on transparent) in the card's colour
    let t = h - 28.0;
    let frame: ref<inkCanvas> = new inkCanvas();
    frame.SetSize(Vector2(t, t));
    frame.SetMargin(inkMargin(18.0, 14.0, 0.0, 0.0));
    frame.Reparent(box);
    v.Frame(frame, t, t, 2.0, "rule", 0.8);
    let atlas = TKStr.Part(r.value, "|", 0);
    let part = TKStr.Part(r.value, "|", 1);
    if StrLen(atlas) > 0 && StrLen(part) > 0 {
      let img: ref<inkImage> = new inkImage();
      img.SetAtlasResource(ResRef.FromString(atlas));
      img.SetTexturePart(StringToName(part));
      img.SetAnchor(inkEAnchor.Centered);
      img.SetAnchorPoint(Vector2(0.5, 0.5));
      img.SetSize(Vector2(t - 16.0, t - 16.0));
      img.Reparent(frame);
      v.Paint(img, "value");
      v.Tone(img, r.color);
    }
    let x = t + 40.0;
    let parts = TKStr.Split(r.text, "|");
    let id = v.Text(box, ArraySize(parts) > 0 ? parts[0] : "", TKScale.TypeXS(), n"Medium", "text", 0.0);
    id.SetMargin(inkMargin(x, 14.0, 0.0, 0.0));
    let name = v.Text(box, ArraySize(parts) > 1 ? parts[1] : "", TKScale.I("bay.name", 36), n"Semi-Bold", "value", 0.0);
    name.SetMargin(inkMargin(x, 40.0, 0.0, 0.0));
    v.Hoverable(name, r.tip);
    if ArraySize(parts) > 2 && StrLen(parts[2]) > 0 {
      TKConsole.Stamp(v, box, parts[2], r.color, x, 86.0);
    }
    // the 10-cell bar along the bottom
    let bw = w - x - 24.0;
    let cells = 10;
    let lit = RoundF(ClampF(r.fraction, 0.0, 1.0) * Cast<Float>(cells));
    let cw = bw / Cast<Float>(cells);
    let k = 0;
    while k < cells {
      let c = TKInk.Rect(box, x + Cast<Float>(k) * cw, h - 22.0, cw - 3.0, 8.0);
      v.Paint(c, k < lit ? "value" : "rule");
      if k < lit {
        v.Tone(c, r.color);
      } else {
        c.SetOpacity(0.5);
      }
      k += 1;
    }
    if StrLen(r.action) > 0 {
      v.Hit(box, r.action, r.arg, "", false);
    }
  }

  // a small framed stamp in a colour
  public static func Stamp(v: ref<TKView>, parent: ref<inkCanvas>, text: String, color: String, x: Float, y: Float) -> Void {
    let size = TKScale.TypeXS() - 2;
    let sw = Cast<Float>(StrLen(text)) * Cast<Float>(size) * 0.58 + 24.0;
    let sh = Cast<Float>(size) + 12.0;
    let s: ref<inkCanvas> = new inkCanvas();
    s.SetSize(Vector2(sw, sh));
    s.SetMargin(inkMargin(x, y, 0.0, 0.0));
    s.Reparent(parent);
    v.TonedFrame(s, sw, sh, 2.0, color);
    let t = v.Text(s, text, size, n"Semi-Bold", "value", 0.0);
    t.SetAnchor(inkEAnchor.Centered);
    t.SetAnchorPoint(Vector2(0.5, 0.5));
    v.Tone(t, color);
  }

  // ---- status lights: a label, then one light per colour (blinking where asked) ----
  public static func Leds(v: ref<TKView>, r: ref<TKRow>) -> Void {
    let colors = TKStr.Split(r.label, "|");
    let blinks = TKStr.Split(r.action, "|");
    let size = TKScale.F("led.size", 22.0);
    let lightsW = Cast<Float>(ArraySize(colors)) * (size + 10.0);
    let line = v.RowBox(v.RowWidth() - lightsW - 20.0, r.text, r.value, "", r.tip);
    let strip: ref<inkHorizontalPanel> = new inkHorizontalPanel();
    strip.Reparent(line);
    v.PinRight(strip);
    strip.SetMargin(inkMargin(0.0, 14.0, 0.0, 0.0));
    let k = 0;
    while k < ArraySize(colors) {
      let led: ref<inkRectangle> = new inkRectangle();
      led.SetSize(Vector2(size, size));
      led.SetMargin(inkMargin(k > 0 ? 10.0 : 0.0, 0.0, 0.0, 0.0));
      led.Reparent(strip);
      v.Paint(led, "rule");
      if NotEquals(colors[k], "off") && StrLen(colors[k]) > 0 {
        v.Tone(led, colors[k]);
      } else {
        led.SetOpacity(0.4);
      }
      if k < ArraySize(blinks) && Equals(blinks[k], "1") {
        TKConsole.Blink(led, 1.0);
      }
      k += 1;
    }
  }

  // fades a widget down and back for ever, `period` seconds a cycle
  public static func Blink(w: ref<inkWidget>, period: Float) -> Void {
    let def: ref<inkAnimDef> = new inkAnimDef();
    TKPopup.Fade(def, 1.0, 0.2, period / 2.0, 0.0);
    let opts: inkAnimOptions;
    opts.loopType = inkanimLoopType.PingPong;
    opts.loopInfinite = true;
    w.PlayAnimationWithOptions(def, opts);
  }

  // ---- ring tile: a full circle of cells lit to `fraction`, the value inside ----
  public static func Ring(v: ref<TKView>, r: ref<TKRow>) -> Void {
    let w = TKScale.F("ring.w", 300.0);
    let h = TKScale.F("ring.h", 300.0);
    let tile = v.GridCell(TKKind.Ring(), w, h);
    v.Panel(tile, w, h, 0.45);
    let parts = TKStr.Split(r.text, "|");
    let name = v.Text(tile, parts[0], 22, n"Semi-Bold", "text", 0.0);
    name.SetMargin(inkMargin(18.0, 14.0, 0.0, 0.0));
    v.Hoverable(name, r.tip);
    let cx = w / 2.0;
    let cy = h / 2.0 + 14.0;
    let radius = MinF(w, h) * 0.34;
    let n = 40;
    let f = ClampF(r.fraction, 0.0, 1.0);
    let color = TKConsole.Shade(v, r.color);
    let dim = new HDRColor(0.3, 0.33, 0.36, 1.0);
    let k = 0;
    while k < n {
      let t = Cast<Float>(k) / Cast<Float>(n);
      let angle = Deg2Rad(90.0 - 360.0 * t);   // from the top, clockwise
      let a = Vector2(cx + CosF(angle) * radius, cy - SinF(angle) * radius);
      let b = Vector2(cx + CosF(angle) * (radius - 16.0), cy - SinF(angle) * (radius - 16.0));
      let on = t < f - 0.0001;
      TKInk.Seg(tile, a, b, 6.0, on ? color : dim, on ? 1.0 : 0.5);
      k += 1;
    }
    let red: Bool;
    let green: Bool;
    let value = v.Text(tile, TKTheme.Unmark(ArraySize(parts) > 1 ? parts[1] : "", red, green), 40, n"Semi-Bold", "value", 0.0);
    value.SetAnchor(inkEAnchor.TopCenter);
    value.SetAnchorPoint(Vector2(0.5, 0.5));
    value.SetHorizontalAlignment(textHorizontalAlignment.Center);
    value.SetMargin(inkMargin(0.0, cy, 0.0, 0.0));
    v.Mark(value, red, green);
    if ArraySize(parts) > 2 && StrLen(parts[2]) > 0 {
      let sub = v.Marked(tile, parts[2], 20, n"Medium", 0.0, w - 36.0);
      sub.SetAnchor(inkEAnchor.TopCenter);
      sub.SetAnchorPoint(Vector2(0.5, 0.0));
      sub.SetHorizontalAlignment(textHorizontalAlignment.Center);
      sub.SetMargin(inkMargin(0.0, h - 34.0, 0.0, 0.0));
    }
  }

  // a row colour name as a colour (for drawing that can't be re-toned later)
  public static func Shade(v: ref<TKView>, color: String) -> HDRColor {
    switch color {
      case "green": return TKTheme.Gain();
      case "red": return TKTheme.Loss();
      case "amber": return TKTheme.Amber();
      case "yellow": return TKTheme.Gold();
      case "orange": return new HDRColor(1.0, 0.55, 0.15, 1.0);
      case "cyan": return new HDRColor(0.15, 0.86, 0.8, 1.0);
      case "grey": return new HDRColor(0.45, 0.45, 0.45, 1.0);
      case "white": return new HDRColor(0.92, 0.94, 0.96, 1.0);
      default: return TKTheme.Color(v.Theme(), "value");
    }
  }

  // ---- compare bar: label, a bar to `fraction`, a tick at `current`, the value ----
  public static func Compare(v: ref<TKView>, r: ref<TKRow>) -> Void {
    let bw = TKScale.F("compare.w", 560.0);
    let line = v.RowBox(v.RowWidth() - bw - 140.0, r.text, "", r.color, r.tip);
    let group: ref<inkCanvas> = new inkCanvas();
    group.SetSize(Vector2(bw + 120.0, 40.0));
    group.Reparent(line);
    v.PinRight(group);
    let bed = TKInk.Rect(group, 0.0, 14.0, bw, 12.0);
    bed.SetOpacity(0.5);
    v.Paint(bed, "rule");
    let fill = TKInk.Rect(group, 0.0, 14.0, MaxF(2.0, bw * ClampF(r.fraction, 0.0, 1.0)), 12.0);
    v.Paint(fill, "value");
    v.Tone(fill, r.color);
    let at = bw * ClampF(StringToFloat(r.label, 0.0), 0.0, 1.0);
    let tick = TKInk.Rect(group, at - 2.0, 4.0, 4.0, 32.0);
    v.Fix(tick, TKTheme.Amber());
    let value = v.Text(group, r.value, TKScale.I("row.detail", 29), n"Semi-Bold", "value", 0.0);
    value.SetMargin(inkMargin(bw + 20.0, 2.0, 0.0, 0.0));
  }

  // ---- feed: a label, then a line that scrolls right to left for ever ----
  public static func Feed(v: ref<TKView>, r: ref<TKRow>) -> Void {
    let w = v.RowWidth();
    let size = TKScale.I("feed.font", 28);
    let h = Cast<Float>(size) + 20.0;
    let row: ref<inkCanvas> = new inkCanvas();
    row.SetSize(Vector2(w, h));
    row.SetMargin(inkMargin(0.0, TKScale.F("row.gap", 10.0), 0.0, 0.0));
    row.SetHAlign(inkEHorizontalAlign.Left);
    row.Reparent(v.Content());
    v.Grew(h + TKScale.F("row.gap", 10.0));
    let lw = 0.0;
    if StrLen(r.value) > 0 {
      let label = v.Text(row, r.value, TKScale.TypeXS(), n"Semi-Bold", "text", 0.0);
      label.SetMargin(inkMargin(0.0, 12.0, 0.0, 0.0));
      lw = Cast<Float>(StrLen(r.value)) * Cast<Float>(TKScale.TypeXS()) * 0.6 + 24.0;
    }
    let clip: ref<inkScrollArea> = new inkScrollArea();
    clip.SetAnchor(inkEAnchor.TopLeft);
    clip.SetFitToContentDirection(inkFitToContentDirection.None);
    clip.SetConstrainContentPosition(false);
    clip.SetUseInternalMask(true);
    clip.SetSize(Vector2(w - lw, h));
    clip.SetMargin(inkMargin(lw, 0.0, 0.0, 0.0));
    clip.Reparent(row);
    let text = v.Text(clip, r.text, size, n"Medium", "value", 0.0);
    text.SetAnchor(inkEAnchor.TopLeft);
    text.SetMargin(inkMargin(0.0, 8.0, 0.0, 0.0));
    v.Tone(text, StrLen(r.color) > 0 ? r.color : "amber");
    let tw = Cast<Float>(StrLen(r.text)) * Cast<Float>(size) * 0.55;
    let def: ref<inkAnimDef> = new inkAnimDef();
    let move: ref<inkAnimTranslation> = new inkAnimTranslation();
    move.SetStartTranslation(Vector2(w - lw, 0.0));
    move.SetEndTranslation(Vector2(-tw, 0.0));
    move.SetDuration((w - lw + tw) / TKScale.F("feed.speed", 120.0));
    def.AddInterpolator(move);
    let opts: inkAnimOptions;
    opts.loopType = inkanimLoopType.Cycle;
    opts.loopInfinite = true;
    text.PlayAnimationWithOptions(def, opts);
  }

  // ---- wave: a label, a line through `series` ("0.4,0.7,..." 0..1), a sweep when live ----
  public static func Wave(v: ref<TKView>, r: ref<TKRow>) -> Void {
    let gw = TKScale.F("wave.w", 360.0);
    let gh = TKScale.F("wave.h", 56.0);
    let line = v.RowBox(v.RowWidth() - gw - 20.0, r.text, r.value, "", r.tip);
    let g: ref<inkCanvas> = new inkCanvas();
    g.SetSize(Vector2(gw, gh));
    g.Reparent(line);
    v.PinRight(g);
    let color = TKConsole.Shade(v, StrLen(r.color) > 0 ? r.color : "cyan");
    let pts = StrSplit(r.label, ",");
    let n = ArraySize(pts);
    let k = 1;
    while k < n {
      let x0 = gw * Cast<Float>(k - 1) / Cast<Float>(Max(1, n - 1));
      let x1 = gw * Cast<Float>(k) / Cast<Float>(Max(1, n - 1));
      let y0 = gh - 4.0 - (gh - 8.0) * ClampF(StringToFloat(pts[k - 1], 0.0), 0.0, 1.0);
      let y1 = gh - 4.0 - (gh - 8.0) * ClampF(StringToFloat(pts[k], 0.0), 0.0, 1.0);
      TKInk.Seg(g, Vector2(x0, y0), Vector2(x1, y1), 3.0, color, 1.0);
      k += 1;
    }
    if r.on {
      // live: a bright sweep runs along the line
      let sweep = TKInk.Rect(g, 0.0, 0.0, 6.0, gh);
      sweep.SetTintColor(color);
      sweep.SetOpacity(0.5);
      let def: ref<inkAnimDef> = new inkAnimDef();
      let move: ref<inkAnimTranslation> = new inkAnimTranslation();
      move.SetStartTranslation(Vector2(0.0, 0.0));
      move.SetEndTranslation(Vector2(gw - 6.0, 0.0));
      move.SetDuration(TKScale.F("wave.secs", 1.6));
      def.AddInterpolator(move);
      let opts: inkAnimOptions;
      opts.loopType = inkanimLoopType.Cycle;
      opts.loopInfinite = true;
      sweep.PlayAnimationWithOptions(def, opts);
    }
  }
}
