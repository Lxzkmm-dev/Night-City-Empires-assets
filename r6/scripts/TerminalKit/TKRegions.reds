// =============================================================================
// TERMINAL KIT - REGIONS: ONE SCREEN IN SEVERAL PANES
// A frame whose Layout() lists regions gets them instead of the sidebar and the
// one scrolling page: a ribbon, a rack, a stage, a panel, a deck... each its own
// pane that scrolls on its own (or not, "fixed"). The provider still answers
// one page; p.Region("rack") sends the rows after it to that region. An action
// can redraw only some regions (p.Refresh("stage")), so the others keep their
// scroll position and don't flicker.
//
//   public func Layout() -> array<String> = [
//     "ribbon|top|150", "deck|bottom|140|fixed",
//     "rack|left|560", "panel|right|680", "stage|fill|0|fixed"];
//
// A spec is "name|side|size|flags": side top, bottom, left or right takes `size`
// (a height or a width) from what is left, in the order listed; "fill" takes
// what remains. Flags (comma separated): "fixed" (the region never scrolls: a
// Custom row in it can fill it, TKView.Width() x Height()), "cut" (chamfered
// corners; every pane has them when TKStyle.cutCorner is set, "square" opts
// out). A fifth part is a title on a header plate: "rack|left|560||BAYS".
// =============================================================================
module TerminalKit

public class TKRegions extends IScriptable {
  private let m_names: array<String>;
  private let m_views: array<ref<TKView>>;
  private let m_provider: ref<TKContent>;
  private let m_message: wref<inkText>;
  private let m_page: String;
  private let m_arg: String;
  private let m_history: array<String>;
  private let m_noPush: Bool;
  private let m_sides: array<String>;
  // a page slid over a region (Overlay): its page and arg, "" for none
  private let m_overPages: array<String>;
  private let m_overArgs: array<String>;
  private let m_focusRegion: Int32;          // the region the pad's focus is in (-1: none)

  public func Count() -> Int32 = ArraySize(this.m_views)
  public func View(i: Int32) -> ref<TKView> = i >= 0 && i < ArraySize(this.m_views) ? this.m_views[i] : null
  public func CurrentPage() -> String = this.m_page
  public func CurrentArg() -> String = this.m_arg

  // the region's view (null: no such region)
  public func Find(name: String) -> ref<TKView> {
    let i = this.IndexOf(name);
    return i >= 0 ? this.m_views[i] : null;
  }

  private func IndexOf(name: String) -> Int32 {
    let i = 0;
    while i < ArraySize(this.m_names) {
      if Equals(this.m_names[i], name) {
        return i;
      }
      i += 1;
    }
    return -1;
  }

  // ---------------------------------------------------------------------------
  // Building: the panes inside (x, y, w, h) of `parent`. `first` is the frame's
  // own view (its chrome stays registered on it); the others are made alike.
  // ---------------------------------------------------------------------------
  public func Build(parent: ref<inkCompoundWidget>, x: Float, y: Float, w: Float, h: Float, specs: array<String>,
    first: ref<TKView>, frame: ref<TKFrame>, provider: ref<TKContent>, style: ref<TKStyle>, message: ref<inkText>) -> Void {
    this.m_provider = provider;
    this.m_message = message;
    this.m_focusRegion = -1;
    let gap = TKScale.F("region.gap", 20.0);
    // the docks carve the rest in the order listed; "fill" waits for what remains
    let left = x;
    let top = y;
    let right = x + w;
    let bottom = y + h;
    let rects: array<Vector4>;
    let i = 0;
    while i < ArraySize(specs) {
      let side = TKStr.Part(specs[i], "|", 1);
      let size = StringToFloat(TKStr.Part(specs[i], "|", 2), 0.0);
      let r = Vector4(0.0, 0.0, 0.0, 0.0);
      switch side {
        case "top":
          r = Vector4(left, top, right - left, size);
          top += size + gap;
          break;
        case "bottom":
          r = Vector4(left, bottom - size, right - left, size);
          bottom -= size + gap;
          break;
        case "left":
          r = Vector4(left, top, size, bottom - top);
          left += size + gap;
          break;
        case "right":
          r = Vector4(right - size, top, size, bottom - top);
          right -= size + gap;
          break;
        default:
          break;
      }
      ArrayPush(rects, r);
      i += 1;
    }
    i = 0;
    while i < ArraySize(specs) {
      let side = TKStr.Part(specs[i], "|", 1);
      if !Equals(side, "top") && !Equals(side, "bottom") && !Equals(side, "left") && !Equals(side, "right") {
        rects[i] = Vector4(left, top, MaxF(0.0, right - left), MaxF(0.0, bottom - top));
      }
      i += 1;
    }
    // the panes, then one overlay over all of them (tooltips, dialogs, lists)
    i = 0;
    while i < ArraySize(specs) {
      let name = TKStr.Part(specs[i], "|", 0);
      let v = i == 0 && IsDefined(first) ? first : new TKView();
      if i > 0 || !IsDefined(first) {
        v.SetFrame(frame);
        v.SetContent(provider);
        v.SetStyle(style);
      }
      this.Pane(parent, v, specs[i], rects[i], style);
      ArrayPush(this.m_names, name);
      ArrayPush(this.m_views, v);
      ArrayPush(this.m_sides, TKStr.Part(specs[i], "|", 1));
      ArrayPush(this.m_overPages, "");
      ArrayPush(this.m_overArgs, "");
      i += 1;
    }
    let overlay: ref<inkCanvas> = new inkCanvas();
    overlay.SetSize(Vector2(w, h));
    overlay.SetMargin(inkMargin(x, y, 0.0, 0.0));
    overlay.Reparent(parent);
    for v in this.m_views {
      v.SetTipLayer(overlay);
    }
  }

  // one region: a dark pane with a thin frame (its corners cut when the style or
  // the spec asks), a header plate when the spec names a title, its rows in a
  // clipped area (with a scroll bar unless fixed)
  private func Pane(parent: ref<inkCompoundWidget>, v: ref<TKView>, spec: String, r: Vector4, style: ref<TKStyle>) -> Void {
    let name = TKStr.Part(spec, "|", 0);
    let flags = TKStr.Part(spec, "|", 3);
    let title = TKStr.Part(spec, "|", 4);
    let fixed = StrContains(flags, "fixed");
    let cut = 0.0;
    if !StrContains(flags, "square") {
      cut = IsDefined(style) && style.cutCorner > 0.0 ? style.cutCorner : (StrContains(flags, "cut") ? 24.0 : 0.0);
    }
    cut = MinF(cut, MinF(r.Z, r.W) / 3.0);
    let box: ref<inkCanvas> = new inkCanvas();
    box.SetName(StringToName("region_" + name));
    box.SetSize(Vector2(r.Z, r.W));
    box.SetMargin(inkMargin(r.X, r.Y, 0.0, 0.0));
    box.Reparent(parent);
    this.Shell(v, box, r.Z, r.W, cut);
    let pad = TKScale.F("region.pad", 18.0);
    let head = 0.0;
    if StrLen(title) > 0 {
      // the header plate: a dark plate across the top, an accent bar at its left
      head = TKScale.F("region.head", 58.0);
      let plate = TKInk.Rect(box, pad, pad, r.Z - pad * 2.0 - cut * 0.5, head);
      plate.SetTintColor(new HDRColor(0.0, 0.0, 0.0, 1.0));
      plate.SetOpacity(0.8);
      v.Chrome(TKInk.Rect(box, pad, pad, 8.0, head), "accent");
      let t = TKInk.Plain(box, TKScale.T(title), TKScale.I("region.title", 30), n"Semi-Bold", 0.0);
      t.SetVAlign(inkEVerticalAlign.Top);
      t.SetMargin(inkMargin(pad + 26.0, pad + (head - Cast<Float>(TKScale.I("region.title", 30))) / 2.0 - 2.0, 0.0, 0.0));
      v.Chrome(t, "title");
      head += 10.0;
    }
    let barW = fixed ? 0.0 : 18.0;
    let innerW = MaxF(10.0, r.Z - pad * 2.0 - barW);
    let innerH = MaxF(10.0, r.W - pad * 2.0 - head);
    let clip: ref<inkScrollArea> = new inkScrollArea();
    clip.SetAnchor(inkEAnchor.TopLeft);
    clip.SetAnchorPoint(Vector2(0.0, 0.0));
    clip.SetFitToContentDirection(inkFitToContentDirection.None);
    clip.SetConstrainContentPosition(false);
    clip.SetUseInternalMask(true);
    clip.SetSize(Vector2(innerW, innerH));
    clip.SetMargin(inkMargin(pad, pad + head, 0.0, 0.0));
    clip.Reparent(box);
    let content: ref<inkVerticalPanel> = new inkVerticalPanel();
    content.SetAnchor(inkEAnchor.TopLeft);
    content.SetAnchorPoint(Vector2(0.0, 0.0));
    content.Reparent(clip);
    let track: ref<inkRectangle>;
    let thumb: ref<inkRectangle>;
    if !fixed {
      track = TKInk.Rect(box, r.Z - pad - 4.0, pad + head, 4.0, innerH);
      track.SetOpacity(0.35);
      v.Chrome(track, "rule");
      thumb = TKInk.Rect(box, r.Z - pad - 4.0, pad + head, 4.0, 40.0);
      v.Chrome(thumb, "value");
    }
    // rows are drawn 40 narrower than the width they're given (RowWidth)
    v.BindRegion(this, name, content, innerW + 40.0, fixed);
    v.BindScroll(clip, innerH, track, thumb);
  }

  // the pane's dark fill and thin frame; with `cut` > 0 the top-right and
  // bottom-left corners are chamfered (the fill steps in 3 px slices there)
  private func Shell(v: ref<TKView>, box: ref<inkCanvas>, w: Float, h: Float, cut: Float) -> Void {
    let opacity = TKScale.F("region.fill", 0.45);
    if cut <= 0.0 {
      let fill = TKInk.Rect(box, 0.0, 0.0, w, h);
      fill.SetTintColor(new HDRColor(0.0, 0.0, 0.0, 1.0));
      fill.SetOpacity(opacity);
      let edges = [Vector4(0.0, 0.0, w, 2.0), Vector4(0.0, h - 2.0, w, 2.0), Vector4(0.0, 0.0, 2.0, h), Vector4(w - 2.0, 0.0, 2.0, h)];
      for e in edges {
        v.Chrome(TKInk.Rect(box, e.X, e.Y, e.Z, e.W), "rule");
      }
      return;
    }
    let mid = TKInk.Rect(box, 0.0, cut, w, h - cut * 2.0);
    mid.SetTintColor(new HDRColor(0.0, 0.0, 0.0, 1.0));
    mid.SetOpacity(opacity);
    let y = 0.0;
    while y < cut {
      let s = MinF(3.0, cut - y);
      let top = TKInk.Rect(box, 0.0, y, w - (cut - y), s);           // the top-right corner cut away
      top.SetTintColor(new HDRColor(0.0, 0.0, 0.0, 1.0));
      top.SetOpacity(opacity);
      let bottom = TKInk.Rect(box, cut - y - s, h - cut + y, w - (cut - y - s), s);   // the bottom-left one
      bottom.SetTintColor(new HDRColor(0.0, 0.0, 0.0, 1.0));
      bottom.SetOpacity(opacity);
      y += s;
    }
    v.Chrome(TKInk.Rect(box, 0.0, 0.0, w - cut, 2.0), "rule");          // top
    v.Chrome(TKInk.Rect(box, w - 2.0, cut, 2.0, h - cut), "rule");      // right
    v.Chrome(TKInk.Rect(box, cut, h - 2.0, w - cut, 2.0), "rule");      // bottom
    v.Chrome(TKInk.Rect(box, 0.0, 0.0, 2.0, h - cut), "rule");          // left
    let color = TKTheme.Color(v.Theme(), "rule");
    TKInk.Seg(box, Vector2(w - cut, 1.0), Vector2(w - 1.0, cut), 2.0, color, 1.0);
    TKInk.Seg(box, Vector2(1.0, h - cut), Vector2(cut, h - 1.0), 2.0, color, 1.0);
  }
  // ---------------------------------------------------------------------------
  // Pages and actions
  // ---------------------------------------------------------------------------
  public func Show(page: String, arg: String, message: String) -> Void {
    let same = Equals(page, this.m_page) && Equals(arg, this.m_arg);
    if !same && StrLen(this.m_page) > 0 && !this.m_noPush {
      ArrayPush(this.m_history, this.m_page + "~" + this.m_arg);
      while ArraySize(this.m_history) > 30 {
        ArrayErase(this.m_history, 0);
      }
    }
    this.m_noPush = false;
    if !same {
      this.EndOverlays();   // another page: what was slid over it goes
    }
    let none: array<String>;
    this.Draw(page, arg, message, same, none);
  }

  // asks the provider for the page and draws the regions in `only` (all when
  // empty); a region with a page slid over it draws that page instead
  private func Draw(page: String, arg: String, message: String, keep: Bool, only: array<String>) -> Void {
    this.m_page = page;
    this.m_arg = arg;
    let data = new TKPage();
    data.content = this.m_provider;
    data.page = page;
    data.Request(page, arg);
    let parts = this.Split(data);
    let i = 0;
    while i < ArraySize(this.m_views) {
      if ArraySize(only) == 0 || ArrayContains(only, this.m_names[i]) {
        if StrLen(this.m_overPages[i]) > 0 {
          this.m_views[i].Present(this.OverlayPage(i), this.m_overPages[i], this.m_overArgs[i], keep);
        } else {
          this.m_views[i].Present(parts[i], page, arg, keep);
        }
      }
      i += 1;
    }
    if IsDefined(this.m_message) {
      this.m_message.SetText(TKScale.T(StrLen(data.message) > 0 ? data.message : message));
    }
  }

  // ---------------------------------------------------------------------------
  // Overlays: a page slid over one region (a map, a catalogue over the stage),
  // with its title and a BACK button on top. Right click and Esc close it before
  // the frame; actions from it see its page in p.page.
  // ---------------------------------------------------------------------------
  public func HasOverlay() -> Bool {
    for p in this.m_overPages {
      if StrLen(p) > 0 {
        return true;
      }
    }
    return false;
  }

  // the region an Overlay() without a region goes over: the first "fill" one
  private func DefaultOverlay() -> Int32 {
    let i = 0;
    while i < ArraySize(this.m_sides) {
      if Equals(this.m_sides[i], "fill") {
        return i;
      }
      i += 1;
    }
    return 0;
  }

  // the overlay page of region i: its title and BACK, then its rows
  private func OverlayPage(i: Int32) -> ref<TKPage> {
    let data = new TKPage();
    data.content = this.m_provider;
    data.page = this.m_overPages[i];
    data.Request(this.m_overPages[i], this.m_overArgs[i]);
    let p = new TKPage();
    p.content = this.m_provider;
    p.page = data.page;
    p.answered = true;
    p.theme = data.theme;
    p.wheelReserved = data.wheelReserved;
    p.Actions(TKKind.Item(), StrLen(data.title) > 0 ? data.title : StrUpper(data.page), data.subtitle, "", ["BACK"], ["tk_overlay_back"], [this.m_names[i]], 0.0, true);
    for r in data.rows {
      if r.kind != TKKind.Region() {
        ArrayPush(p.rows, r);
      }
    }
    return p;
  }

  // slides `page` over region `region` ("" = the first fill region); redraws it
  public func Overlay(region: String, page: String, arg: String) -> Void {
    let i = StrLen(region) > 0 ? this.IndexOf(region) : this.DefaultOverlay();
    if i < 0 {
      return;
    }
    let opening = StrLen(this.m_overPages[i]) == 0;
    this.m_overPages[i] = page;
    this.m_overArgs[i] = arg;
    this.m_views[i].Present(this.OverlayPage(i), page, arg, false);
    if opening {
      this.m_views[i].SlideIn();
    }
  }

  // closes the overlay over region `region` ("" = every one): true when one was open
  public func EndOverlay(region: String) -> Bool {
    let had = false;
    let i = 0;
    while i < ArraySize(this.m_overPages) {
      if StrLen(this.m_overPages[i]) > 0 && (StrLen(region) == 0 || Equals(this.m_names[i], region)) {
        this.m_overPages[i] = "";
        this.m_overArgs[i] = "";
        had = true;
        let only = [this.m_names[i]];
        this.Draw(this.m_page, this.m_arg, "", true, only);
      }
      i += 1;
    }
    return had;
  }

  private func EndOverlays() -> Void {
    let i = 0;
    while i < ArraySize(this.m_overPages) {
      this.m_overPages[i] = "";
      this.m_overArgs[i] = "";
      i += 1;
    }
  }

  // one page per region: the rows after each Region row go to that region
  private func Split(data: ref<TKPage>) -> array<ref<TKPage>> {
    let parts: array<ref<TKPage>>;
    for name in this.m_names {
      let p = new TKPage();
      p.content = data.content;
      p.page = data.page;
      p.answered = data.answered;
      p.title = data.title;
      p.subtitle = data.subtitle;
      p.theme = data.theme;
      p.section = data.section;
      ArrayPush(parts, p);
    }
    if ArraySize(parts) == 0 {
      return parts;
    }
    let at = 0;
    for r in data.rows {
      if r.kind == TKKind.Region() {
        at = Max(0, this.IndexOf(r.text));
      } else {
        ArrayPush(parts[at].rows, r);
        if r.kind == TKKind.Custom() && r.fraction > 0.0 {
          parts[at].wheelReserved = true;
        }
      }
    }
    return parts;
  }

  public func Act(action: String, arg: String) -> Void { this.ActFrom(null, action, arg); }

  // an action from region view `from` (null: the page's own)
  public func ActFrom(from: ref<TKView>, action: String, arg: String) -> Void {
    if Equals(action, "tk_overlay_back") {
      this.EndOverlay(arg);
      return;
    }
    let at = IsDefined(from) ? this.IndexOf(from.Region()) : -1;
    let over = at >= 0 && StrLen(this.m_overPages[at]) > 0;
    let act: ref<TKPage> = new TKPage();
    act.content = this.m_provider;
    act.page = over ? this.m_overPages[at] : this.m_page;
    for v in this.m_views {
      v.AddFields(act);
    }
    act.Act(action, arg);
    if act.rebuild && IsDefined(this.m_provider) {
      this.m_provider.Rebuild();
    }
    if act.skipRedraw {
      return;
    }
    let only = act.refresh;
    // the overlays the action opened, moved or closed
    if act.overlayEnd {
      let target = StrLen(act.overlayRegion) > 0 ? act.overlayRegion : (over ? this.m_names[at] : "");
      this.EndOverlay(target);
    }
    if StrLen(act.overlayPage) > 0 {
      this.Overlay(act.overlayRegion, act.overlayPage, act.overlayArg);
    }
    if over && StrLen(act.nextPage) > 0 && !act.overlayEnd {
      // GoTo from inside an overlay moves the overlay
      this.Overlay(this.m_names[at], act.nextPage, act.nextArg);
    } else {
      let moved = StrLen(act.nextPage) > 0 && (NotEquals(act.nextPage, this.m_page) || NotEquals(act.nextArg, this.m_arg));
      if moved {
        this.Show(act.nextPage, act.nextArg, act.message);
      } else {
        // a named refresh redraws those regions; with an overlay change and no
        // names, the rest stays as it is
        if ArraySize(only) > 0 || (!act.overlayEnd && StrLen(act.overlayPage) == 0) {
          this.Draw(this.m_page, this.m_arg, act.message, true, only);
        } else {
          if IsDefined(this.m_message) {
            this.m_message.SetText(TKScale.T(act.message));
          }
        }
      }
    }
    if StrLen(act.confirmAction) > 0 && ArraySize(this.m_views) > 0 {
      (IsDefined(from) ? from : this.m_views[0]).Dialog(act.confirmText, StrLen(act.confirmYes) > 0 ? act.confirmYes : "CONFIRM", act.confirmAction, act.confirmArg);
    }
  }

  // right click: an overlay closes first, then the page before
  public func Back() -> Bool {
    if this.EndOverlay("") {
      return true;
    }
    let n = ArraySize(this.m_history);
    if n == 0 {
      return false;
    }
    let last = this.m_history[n - 1];
    ArrayPop(this.m_history);
    this.m_noPush = true;
    this.Show(StrBeforeFirst(last, "~"), StrAfterFirst(last, "~"), "");
    return true;
  }

  public func CloseOverlay() -> Bool {
    let had = false;
    for v in this.m_views {
      if v.CloseOwnOverlay() {
        had = true;
      }
    }
    return had;
  }

  public func IsTyping() -> Bool {
    for v in this.m_views {
      if v.IsTyping() {
        return true;
      }
    }
    return false;
  }

  // ---------------------------------------------------------------------------
  // Controller focus: the d-pad moves within a region, the bumpers between them
  // ---------------------------------------------------------------------------
  public func HasFocus() -> Bool = this.m_focusRegion >= 0

  public func FocusStep(step: Int32) -> Bool {
    if this.m_focusRegion < 0 || this.m_focusRegion >= ArraySize(this.m_views) {
      return this.FocusRegion(1);
    }
    return this.m_views[this.m_focusRegion].FocusStep(step);
  }

  // to the next (1) or previous (-1) region that has something to focus
  public func FocusRegion(dir: Int32) -> Bool {
    let n = ArraySize(this.m_views);
    if n == 0 {
      return false;
    }
    let at = this.m_focusRegion;
    let k = 0;
    while k < n {
      at = at < 0 ? (dir > 0 ? 0 : n - 1) : (at + dir + n) % n;
      if this.m_views[at].Focusables() > 0 {
        if this.m_focusRegion >= 0 && this.m_focusRegion < n {
          this.m_views[this.m_focusRegion].Focus(-1);
        }
        this.m_focusRegion = at;
        this.m_views[at].FocusStep(1);
        return true;
      }
      k += 1;
    }
    return false;
  }

  public func Activate() -> Bool {
    return this.m_focusRegion >= 0 && this.m_focusRegion < ArraySize(this.m_views) && this.m_views[this.m_focusRegion].Activate();
  }

  public func ClearFocus() -> Void {
    for v in this.m_views {
      v.Focus(-1);
    }
    this.m_focusRegion = -1;
  }

  public func Stop() -> Void {
    for v in this.m_views {
      v.StopCustom();
      v.StopLive();
    }
  }
}