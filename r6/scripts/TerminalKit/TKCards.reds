// =============================================================================
// TERMINAL KIT - FILES AND POSTINGS
// Two grid cards with a character of their own:
//   File: a personnel file. A file number, a barcode and a status stamp along
//     the top, a mugshot frame with the initials, the name large beside it, a
//     block of stats as segmented bars, a few lines, a quote, buttons.
//   Posting: a job posting on a dark-net board. A post number and the time it
//     has left, the title, the client, tag chips, the pay large beside an odds
//     meter, a few lines, buttons.
// Both sit side by side like cards (p.SetExtra("w:h") sizes them).
// =============================================================================
module TerminalKit

public abstract class TKCards {
  private static func Size(r: ref<TKRow>, w: script_ref<Float>, h: script_ref<Float>) -> Void {
    if StrContains(r.extra, ":") {
      Deref(w) = StringToFloat(StrBeforeFirst(r.extra, ":"), Deref(w));
      Deref(h) = StringToFloat(StrAfterFirst(r.extra, ":"), Deref(h));
    }
  }

  // HUD corner brackets around a w x h box at (x, y)
  public static func Brackets(v: ref<TKView>, box: ref<inkCanvas>, x: Float, y: Float, w: Float, h: Float, len: Float, t: Float, color: String) -> Void {
    let marks = [
      Vector4(x, y, len, t), Vector4(x, y, t, len),
      Vector4(x + w - len, y, len, t), Vector4(x + w - t, y, t, len),
      Vector4(x, y + h - t, len, t), Vector4(x, y + h - len, t, len),
      Vector4(x + w - len, y + h - t, len, t), Vector4(x + w - t, y + h - len, t, len)
    ];
    for m in marks {
      let r = TKInk.Rect(box, m.X, m.Y, m.Z, m.W);
      v.Paint(r, "value");
      v.Tone(r, color);
    }
  }

  // A crisp stamp: a dark box with a clean frame, the text centred, pinned
  // `right` from the right edge and `top` from the top
  public static func Stamp(v: ref<TKView>, parent: ref<inkCanvas>, text: String, color: String, right: Float, top: Float, size: Int32) -> Void {
    if StrLen(text) == 0 {
      return;
    }
    let w = Cast<Float>(StrLen(text)) * 0.62 * Cast<Float>(size) + 32.0;
    let h = Cast<Float>(size) + 16.0;
    let box: ref<inkCanvas> = new inkCanvas();
    box.SetSize(Vector2(w, h));
    box.SetAnchor(inkEAnchor.TopRight);
    box.SetAnchorPoint(Vector2(1.0, 0.0));
    box.SetMargin(inkMargin(0.0, top, right, 0.0));
    box.Reparent(parent);
    let fill = TKInk.Rect(box, 0.0, 0.0, w, h);
    fill.SetTintColor(new HDRColor(0.0, 0.0, 0.0, 1.0));
    fill.SetOpacity(0.75);
    v.TonedFrame(box, w, h, 2.0, color);
    let t = v.Text(box, text, size, n"Semi-Bold", "value", 0.0);
    t.SetAnchor(inkEAnchor.Centered);
    t.SetAnchorPoint(Vector2(0.5, 0.5));
    t.SetHorizontalAlignment(textHorizontalAlignment.Center);
    v.Tone(t, color);
  }

  // No photo on file: an emblem faint behind, a bust silhouette with a thin rim
  // in the card's colour (longer hair for `female`), a "NO IMAGE" strip along
  // the bottom. Drawn in 3 px slices so it works on any size.
  public static func Portrait(v: ref<TKView>, box: ref<inkCanvas>, w: Float, h: Float, female: Bool, atlas: String, part: String, color: String) -> Void {
    if StrLen(atlas) > 0 && StrLen(part) > 0 {
      let size = MinF(w, h) * 0.86;
      let img: ref<inkImage> = new inkImage();
      img.SetAtlasResource(ResRef.FromString(atlas));
      img.SetTexturePart(StringToName(part));
      img.SetAnchor(inkEAnchor.Centered);
      img.SetAnchorPoint(Vector2(0.5, 0.5));
      img.SetSize(Vector2(size, size));
      img.SetOpacity(0.22);
      img.Reparent(box);
      v.Paint(img, "value");
      v.Tone(img, color);
    }
    // one plain bust for everyone (hair shapes read as a hood); a woman's is a
    // touch slimmer: a smaller head, narrower shoulders
    let cx = w / 2.0;
    let headY = h * 0.36;
    let rx = w * (female ? 0.175 : 0.19);
    let ry = h * (female ? 0.19 : 0.2);
    let neck = h * 0.58;
    let shoulders = h * 0.66;
    let step = 3.0;
    // the rim first, one step wider, then the fill over it
    let pass = 0;
    while pass < 2 {
      let grow = pass == 0 ? 3.0 : 0.0;
      let y = headY - ry - grow;
      while y < h {
        let half = 0.0;
        let dy = (y - headY) / (ry + grow);
        if AbsF(dy) <= 1.0 {
          half = (rx + grow) * SqrtF(1.0 - dy * dy);
        }
        if y >= headY + ry * 0.8 && y < shoulders {
          half = MaxF(half, w * (female ? 0.08 : 0.09) + grow);   // the neck
        }
        if y >= shoulders - 6.0 {
          let t = ClampF((y - shoulders + 6.0) / (h - shoulders), 0.0, 1.0);
          let span = female ? 0.37 : 0.42;
          half = MaxF(half, (w * (0.2 + (span - 0.2) * SqrtF(t))) + grow);
        }
        if half > 0.5 {
          let slice = TKInk.Rect(box, cx - half, y, half * 2.0, step + 0.5);
          if pass == 0 {
            v.Paint(slice, "value");
            v.Tone(slice, color);
            slice.SetOpacity(0.35);
          } else {
            slice.SetTintColor(new HDRColor(0.07, 0.08, 0.1, 1.0));
          }
        }
        y += step;
      }
      pass += 1;
    }
    // the strip along the bottom
    let band = TKInk.Rect(box, 0.0, h - 30.0, w, 30.0);
    band.SetTintColor(new HDRColor(0.0, 0.0, 0.0, 1.0));
    band.SetOpacity(0.8);
    let t = v.Text(box, "NO IMAGE", 20, n"Semi-Bold", "text", 0.0);
    t.SetAnchor(inkEAnchor.BottomCenter);
    t.SetAnchorPoint(Vector2(0.5, 1.0));
    t.SetHorizontalAlignment(textHorizontalAlignment.Center);
    t.SetMargin(inkMargin(0.0, 0.0, 0.0, 4.0));
    t.SetOpacity(0.8);
  }

  // the first letter of the first two words ("JACKIE WELLES" gives "JW")
  private static func Initials(name: String) -> String {
    let clean = StrReplaceAll(name, "\"", "");
    let out = StrLeft(clean, 1);
    let at = StrFindFirst(clean, " ");
    if at > 0 && at + 1 < StrLen(clean) {
      out += StrMid(clean, at + 1, 1);
    }
    return out;
  }

  // ---- the personnel file ----
  // head "FILE #|NAME|ROLE LINE|STAMP"; value "stats\nlines\nquote":
  // stats "HP:3|STR:2" (out of 10), lines "a|b" (card marks), a quote
  public static func File(v: ref<TKView>, i: Int32, r: ref<TKRow>) -> Void {
    let w = TKScale.F("file.w", 520.0);
    let h = TKScale.F("file.h", 660.0);
    TKCards.Size(r, w, h);
    let card = v.GridCell(TKKind.File(), w, h);
    if !r.on {
      card.SetOpacity(0.6);
    }
    let color = r.color;
    let framed = StrBeginsWith(color, "*");
    if framed {
      color = StrMid(color, 1, StrLen(color) - 1);
    }
    if StrLen(color) == 0 {
      color = "blue";
    }
    v.Panel(card, w, h, 0.6);
    if framed {
      v.TonedFrame(card, w, h, 4.0, color);
    }
    let head = TKStr.Split(r.text, "|");
    let name = ArraySize(head) > 1 ? head[1] : "";
    // the top band: the file number and a barcode on the left, the stamp on the right
    let band = TKInk.Rect(card, 0.0, 0.0, w, 56.0);
    band.SetTintColor(new HDRColor(0.0, 0.0, 0.0, 1.0));
    band.SetOpacity(0.7);
    let spine = TKInk.Rect(card, 0.0, 0.0, 6.0, h);
    v.Paint(spine, "value");
    v.Tone(spine, color);
    let number = v.Text(card, head[0], 24, n"Semi-Bold", "text", 0.0);
    number.SetMargin(inkMargin(24.0, 14.0, 0.0, 0.0));
    let bx = 24.0 + Cast<Float>(StrLen(head[0])) * 0.6 * 24.0 + 16.0;
    let k = 0;
    let seed = StrLen(name) + 3;
    let stampText = ArraySize(head) > 3 ? head[3] : "";
    let stop = w - 16.0 - (StrLen(stampText) > 0 ? Cast<Float>(StrLen(stampText)) * 0.62 * 24.0 + 32.0 : 0.0) - 24.0;
    while k < 16 && bx < stop - 8.0 {
      let bw = Cast<Float>((k * seed + k / 2) % 3 + 1) * 2.0;
      let bar = TKInk.Rect(card, bx, 16.0, bw, 24.0);
      v.Paint(bar, "text");
      bar.SetOpacity(0.55);
      bx += bw + 3.0;
      k += 1;
    }
    TKCards.Stamp(v, card, ArraySize(head) > 3 ? head[3] : "", color, 16.0, 10.0, 24);
    // the mugshot: a dark frame with brackets, the initials, scan lines
    let px = 24.0;
    let py = 72.0;
    let pw = 132.0;
    let ph = 152.0;
    let shot = TKInk.Rect(card, px, py, pw, ph);
    shot.SetTintColor(new HDRColor(0.0, 0.0, 0.0, 1.0));
    shot.SetOpacity(0.8);
    let face: ref<inkCanvas> = new inkCanvas();
    face.SetSize(Vector2(pw, ph));
    face.SetMargin(inkMargin(px, py, 0.0, 0.0));
    face.Reparent(card);
    let kind = TKStr.Part(r.image, "|", 0);
    if Equals(kind, "m") || Equals(kind, "f") {
      TKCards.Portrait(v, face, pw, ph, Equals(kind, "f"), TKStr.Part(r.image, "|", 1), TKStr.Part(r.image, "|", 2), color);
    } else {
      let ini = v.Text(face, TKCards.Initials(name), 64, n"Semi-Bold", "value", 0.0);
      ini.SetAnchor(inkEAnchor.Centered);
      ini.SetAnchorPoint(Vector2(0.5, 0.5));
      ini.SetHorizontalAlignment(textHorizontalAlignment.Center);
      v.Tone(ini, color);
    }
    let s = 1;
    while s < 12 {
      let scan = TKInk.Rect(card, px + 4.0, py + Cast<Float>(s) * ph / 12.0, pw - 8.0, 2.0);
      scan.SetTintColor(new HDRColor(0.0, 0.0, 0.0, 1.0));
      scan.SetOpacity(0.35);
      s += 1;
    }
    TKCards.Brackets(v, card, px, py, pw, ph, 22.0, 3.0, color);
    // the name and role beside it
    let nx = px + pw + 20.0;
    let nw = w - nx - 20.0;
    let who: ref<inkVerticalPanel> = new inkVerticalPanel();
    who.SetMargin(inkMargin(nx, py - 4.0, 0.0, 0.0));
    who.Reparent(card);
    let title = v.Wrap(v.Text(who, name, 34, n"Semi-Bold", "value", 0.0), nw);
    v.Hoverable(title, r.tip);
    if ArraySize(head) > 2 && StrLen(head[2]) > 0 {
      v.Marked(who, head[2], 24, n"Medium", 6.0, nw);
    }
    // under the mugshot: the stats, the lines, the quote
    let parts = TKStr.Split(r.value, "\n");
    let tw = w - 48.0;
    let body: ref<inkVerticalPanel> = new inkVerticalPanel();
    body.SetMargin(inkMargin(24.0, py + ph + 14.0, 0.0, 0.0));
    body.Reparent(card);
    if StrLen(parts[0]) > 0 {
      for stat in TKStr.Split(parts[0], "|") {
        let n = Min(10, StringToInt(StrAfterFirst(stat, ":"), 0));
        let line = TKInk.Strip(body, 4.0);
        let lbox: ref<inkCanvas> = new inkCanvas();
        lbox.SetSize(Vector2(78.0, 30.0));
        lbox.Reparent(line);
        v.Text(lbox, StrBeforeFirst(stat + ":", ":"), 24, n"Semi-Bold", "text", 0.0);
        let segs: ref<inkCanvas> = new inkCanvas();
        let sw = MinF(26.0, (tw - 78.0 - 60.0) / 10.0);
        segs.SetSize(Vector2(sw * 10.0, 30.0));
        segs.SetMargin(inkMargin(8.0, 0.0, 12.0, 0.0));
        segs.Reparent(line);
        let q = 0;
        while q < 10 {
          let seg = TKInk.Rect(segs, Cast<Float>(q) * sw, 8.0, sw - 5.0, 16.0);
          if q < n {
            v.Paint(seg, "value");
            v.Tone(seg, color);
          } else {
            v.Paint(seg, "rule");
            seg.SetOpacity(0.4);
          }
          q += 1;
        }
        v.Text(line, IntToString(n), 24, n"Semi-Bold", "value", 0.0);
      }
    }
    if ArraySize(parts) > 1 && StrLen(parts[1]) > 0 {
      let first = true;
      for d in TKStr.Split(parts[1], "|") {
        if StrLen(d) > 0 {
          v.Marked(body, d, 24, n"Medium", first ? 12.0 : 2.0, tw);
          first = false;
        }
      }
    }
    if ArraySize(parts) > 2 && StrLen(parts[2]) > 0 {
      let quote = v.Wrap(v.Text(body, "\"" + parts[2] + "\"", 24, n"Regular", "text", 12.0), tw);
      quote.SetLetterCase(textLetterCase.OriginalCase);
      quote.SetOpacity(0.75);
    }
    TKCards.ButtonBar(v, card, i, r, w);
  }

  // ---- the job posting ----
  // head "POST #|TITLE|CLIENT|PAY|TIME LEFT"; value "chips\nlines": chips
  // "HEIST|TIER 3|!HOT" (a mark colours a chip), lines "a|b" (card marks);
  // fraction the odds (below 0: no meter)
  public static func Posting(v: ref<TKView>, i: Int32, r: ref<TKRow>) -> Void {
    let w = TKScale.F("post.w", 560.0);
    let h = TKScale.F("post.h", 430.0);
    TKCards.Size(r, w, h);
    let card = v.GridCell(TKKind.Posting(), w, h);
    if !r.on {
      card.SetOpacity(0.6);
    }
    let color = r.color;
    let framed = StrBeginsWith(color, "*");
    if framed {
      color = StrMid(color, 1, StrLen(color) - 1);
    }
    if StrLen(color) == 0 {
      color = "blue";
    }
    v.Panel(card, w, h, 0.6);
    if framed {
      v.TonedFrame(card, w, h, 4.0, color);
    }
    let head = TKStr.Split(r.text, "|");
    // the post header: a dark band, a line in the post's colour, the post number, the time left
    let band = TKInk.Rect(card, 0.0, 0.0, w, 46.0);
    band.SetTintColor(new HDRColor(0.0, 0.0, 0.0, 1.0));
    band.SetOpacity(0.75);
    let edge = TKInk.Rect(card, 0.0, 46.0, w, 3.0);
    v.Paint(edge, "value");
    v.Tone(edge, color);
    let dot = TKInk.Rect(card, 18.0, 17.0, 12.0, 12.0);
    dot.SetRenderTransformPivot(Vector2(0.5, 0.5));
    dot.SetRotation(45.0);
    v.Paint(dot, "value");
    v.Tone(dot, color);
    let post = v.Text(card, head[0], 24, n"Semi-Bold", "value", 0.0);
    post.SetMargin(inkMargin(42.0, 9.0, 0.0, 0.0));
    v.Tone(post, color);
    let red: Bool;
    let green: Bool;
    let left = v.Text(card, TKTheme.Unmark(ArraySize(head) > 4 ? head[4] : "", red, green), 24, n"Semi-Bold", "text", 0.0);
    left.SetAnchor(inkEAnchor.TopRight);
    left.SetAnchorPoint(Vector2(1.0, 0.0));
    left.SetHorizontalAlignment(textHorizontalAlignment.Right);
    left.SetMargin(inkMargin(0.0, 9.0, 18.0, 0.0));
    v.Mark(left, red, green);
    // the title, the client, the chips
    let tw = w - 40.0;
    let body: ref<inkVerticalPanel> = new inkVerticalPanel();
    body.SetMargin(inkMargin(20.0, 60.0, 0.0, 0.0));
    body.Reparent(card);
    let title = v.Wrap(v.Text(body, ArraySize(head) > 1 ? head[1] : "", 32, n"Semi-Bold", "value", 0.0), tw);
    v.Hoverable(title, r.tip);
    if ArraySize(head) > 2 && StrLen(head[2]) > 0 {
      v.Marked(body, head[2], 24, n"Medium", 2.0, tw);
    }
    let parts = TKStr.Split(r.value, "\n");
    if StrLen(parts[0]) > 0 {
      let chips = TKInk.Strip(body, 10.0);
      let used = 0.0;
      for chip in TKStr.Split(parts[0], "|") {
        if StrLen(chip) > 0 {
          let cr: Bool;
          let cg: Bool;
          let label = TKTheme.Unmark(chip, cr, cg);
          let cw = Cast<Float>(StrLen(label)) * 0.6 * 22.0 + 24.0;
          // a chip that won't fit starts a new line of chips
          if used > 0.0 && used + cw > tw {
            chips = TKInk.Strip(body, 8.0);
            used = 0.0;
          }
          used += cw + 10.0;
          let box: ref<inkCanvas> = new inkCanvas();
          box.SetSize(Vector2(cw, 34.0));
          box.SetMargin(inkMargin(0.0, 0.0, 10.0, 0.0));
          box.Reparent(chips);
          let tone = cr ? "red" : (cg ? "green" : color);
          let back = TKInk.Rect(box, 0.0, 0.0, cw, 34.0);
          back.SetTintColor(new HDRColor(0.0, 0.0, 0.0, 1.0));
          back.SetOpacity(0.6);
          v.TonedFrame(box, cw, 34.0, 2.0, tone);
          let t = v.Text(box, label, 22, n"Semi-Bold", "value", 0.0);
          t.SetAnchor(inkEAnchor.Centered);
          t.SetAnchorPoint(Vector2(0.5, 0.5));
          t.SetHorizontalAlignment(textHorizontalAlignment.Center);
          v.Tone(t, tone);
        }
      }
    }
    // the pay large on the left, the odds meter on the right
    let row = TKInk.Strip(body, 12.0);
    let half = tw * 0.5;
    let payCol: ref<inkCanvas> = new inkCanvas();
    payCol.SetSize(Vector2(half, 80.0));
    payCol.Reparent(row);
    let pays = v.Text(payCol, "PAYS", 22, n"Semi-Bold", "text", 0.0);
    pays.SetOpacity(0.7);
    let money = ArraySize(head) > 3 ? head[3] : "";
    let pay = v.Marked(payCol, money, 42, n"Semi-Bold", 0.0, half - 10.0);
    pay.SetMargin(inkMargin(0.0, 26.0, 0.0, 0.0));
    if !StrBeginsWith(money, "!") && !StrBeginsWith(money, "*") {
      v.Fix(pay, TKTheme.Gold());
    }
    if r.fraction >= 0.0 {
      let odds: ref<inkCanvas> = new inkCanvas();
      odds.SetSize(Vector2(half, 80.0));
      odds.Reparent(row);
      let f = ClampF(r.fraction, 0.0, 1.0);
      let label = v.Text(odds, "ODDS", 22, n"Semi-Bold", "text", 0.0);
      label.SetOpacity(0.7);
      let tone = f < 0.4 ? TKTheme.Loss() : (f < 0.7 ? TKTheme.Amber() : TKTheme.Gain());
      let pct = v.Text(odds, IntToString(RoundF(f * 100.0)) + "%", 30, n"Semi-Bold", "value", 0.0);
      pct.SetAnchor(inkEAnchor.TopRight);
      pct.SetAnchorPoint(Vector2(1.0, 0.0));
      pct.SetHorizontalAlignment(textHorizontalAlignment.Right);
      v.Fix(pct, tone);
      // a segmented meter, 20 cells
      let cells = 20;
      let cw = half / Cast<Float>(cells);
      let q = 0;
      while q < cells {
        let cell = TKInk.Rect(odds, Cast<Float>(q) * cw, 48.0, cw - 4.0, 22.0);
        if (Cast<Float>(q) + 0.5) / Cast<Float>(cells) <= f {
          cell.SetTintColor(tone);
        } else {
          v.Paint(cell, "rule");
          cell.SetOpacity(0.4);
        }
        q += 1;
      }
    }
    if ArraySize(parts) > 1 && StrLen(parts[1]) > 0 {
      let first = true;
      for d in TKStr.Split(parts[1], "|") {
        if StrLen(d) > 0 {
          v.Marked(body, d, 24, n"Regular", first ? 10.0 : 2.0, tw);
          first = false;
        }
      }
    }
    TKCards.ButtonBar(v, card, i, r, w);
  }

  // ---- a run in progress ----
  // head "TAG|TITLE|SUB|STAMP"; value "lines\nstart|end": lines "a|b" (card
  // marks), start and end on TKClock's clock. A live bar fills from start to
  // end with the percent large on its left and the time left on its right.
  public static func Run(v: ref<TKView>, i: Int32, r: ref<TKRow>) -> Void {
    let w = TKScale.F("run.w", 560.0);
    let h = TKScale.F("run.h", 330.0);
    TKCards.Size(r, w, h);
    let card = v.GridCell(TKKind.Run(), w, h);
    if !r.on {
      card.SetOpacity(0.6);
    }
    let color = StrLen(r.color) > 0 ? r.color : "blue";
    v.Panel(card, w, h, 0.6);
    let head = TKStr.Split(r.text, "|");
    let band = TKInk.Rect(card, 0.0, 0.0, w, 50.0);
    band.SetTintColor(new HDRColor(0.0, 0.0, 0.0, 1.0));
    band.SetOpacity(0.75);
    let spine = TKInk.Rect(card, 0.0, 0.0, 6.0, h);
    v.Paint(spine, "value");
    v.Tone(spine, color);
    let tag = v.Text(card, head[0], 24, n"Semi-Bold", "value", 0.0);
    tag.SetMargin(inkMargin(24.0, 11.0, 0.0, 0.0));
    v.Tone(tag, color);
    TKCards.Stamp(v, card, ArraySize(head) > 3 ? head[3] : "", color, 14.0, 7.0, 22);
    let tw = w - 48.0;
    let body: ref<inkVerticalPanel> = new inkVerticalPanel();
    body.SetMargin(inkMargin(24.0, 62.0, 0.0, 0.0));
    body.Reparent(card);
    let title = v.Wrap(v.Text(body, ArraySize(head) > 1 ? head[1] : "", 30, n"Semi-Bold", "value", 0.0), tw);
    v.Hoverable(title, r.tip);
    if ArraySize(head) > 2 && StrLen(head[2]) > 0 {
      v.Marked(body, head[2], 24, n"Medium", 2.0, tw);
    }
    let parts = TKStr.Split(r.value, "\n");
    if StrLen(parts[0]) > 0 {
      let first = true;
      for d in TKStr.Split(parts[0], "|") {
        if StrLen(d) > 0 {
          v.Marked(body, d, 24, n"Regular", first ? 8.0 : 2.0, tw);
          first = false;
        }
      }
    }
    // the live block along the bottom (above the buttons when there are any)
    let buttons = ArraySize(r.labels) > 0 && StrLen(r.label) > 0;
    let base = h - (buttons ? 88.0 : 22.0);
    let spec = ArraySize(parts) > 1 ? parts[1] : "";
    let start = StringToFloat(TKStr.Part(spec, "|", 0), 0.0);
    let end = StringToFloat(TKStr.Part(spec, "|", 1), 0.0);
    let pct = v.Text(card, "", 40, n"Semi-Bold", "value", 0.0);
    pct.SetMargin(inkMargin(24.0, base - 76.0, 0.0, 0.0));
    v.Tone(pct, color);
    let left = v.Text(card, "", 24, n"Semi-Bold", "text", 0.0);
    left.SetAnchor(inkEAnchor.TopRight);
    left.SetAnchorPoint(Vector2(1.0, 0.0));
    left.SetHorizontalAlignment(textHorizontalAlignment.Right);
    left.SetMargin(inkMargin(0.0, base - 60.0, 24.0, 0.0));
    let bw = w - 48.0;
    let bed = TKInk.Rect(card, 24.0, base - 18.0, bw, 18.0);
    v.Paint(bed, "rule");
    bed.SetOpacity(0.45);
    let fill = TKInk.Rect(card, 24.0, base - 18.0, 2.0, 18.0);
    v.Paint(fill, "value");
    v.Tone(fill, color);
    // notches over the bar so it reads as cells
    let cells = 24;
    let q = 1;
    while q < cells {
      let notch = TKInk.Rect(card, 24.0 + bw * Cast<Float>(q) / Cast<Float>(cells) - 2.0, base - 18.0, 4.0, 18.0);
      notch.SetTintColor(new HDRColor(0.0, 0.0, 0.0, 1.0));
      notch.SetOpacity(0.85);
      q += 1;
    }
    v.AddLive(i, fill, pct, bw, start, end, 1);
    v.AddLive(i, null, left, bw, start, end, 0);
    TKCards.ButtonBar(v, card, i, r, w);
  }

  // buttons along the bottom, sharing the width
  private static func ButtonBar(v: ref<TKView>, card: ref<inkCanvas>, i: Int32, r: ref<TKRow>, w: Float) -> Void {
    let n = ArraySize(r.labels);
    if n == 0 || StrLen(r.label) == 0 {
      return;
    }
    let bar: ref<inkHorizontalPanel> = new inkHorizontalPanel();
    bar.SetAnchor(inkEAnchor.BottomLeft);
    bar.SetAnchorPoint(Vector2(0.0, 1.0));
    bar.SetMargin(inkMargin(20.0, 0.0, 0.0, 16.0));
    bar.Reparent(card);
    let bw = (w - 40.0 - 12.0 * Cast<Float>(n - 1)) / Cast<Float>(n);
    let k = 0;
    while k < n {
      let b = v.ActButton(bar, i, k, r.labels[k], true, bw, 56.0, 24);
      b.GetRootWidget().SetMargin(inkMargin(k > 0 ? 12.0 : 0.0, 0.0, 0.0, 0.0));
      k += 1;
    }
  }
}
