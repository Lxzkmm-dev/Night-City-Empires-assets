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
// what remains. Flags: "fixed" (the region never scrolls: a Custom row in it
// can fill it, TKView.Width() x Height()).
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
      let fixed = StrContains(TKStr.Part(specs[i], "|", 3), "fixed");
      let v = i == 0 && IsDefined(first) ? first : new TKView();
      if i > 0 || !IsDefined(first) {
        v.SetFrame(frame);
        v.SetContent(provider);
        v.SetStyle(style);
      }
      this.Pane(parent, v, name, rects[i], fixed);
      ArrayPush(this.m_names, name);
      ArrayPush(this.m_views, v);
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

  // one region: a dark pane with a thin frame, its rows in a clipped area
  // (with a scroll bar unless fixed)
  private func Pane(parent: ref<inkCompoundWidget>, v: ref<TKView>, name: String, r: Vector4, fixed: Bool) -> Void {
    let box: ref<inkCanvas> = new inkCanvas();
    box.SetName(StringToName("region_" + name));
    box.SetSize(Vector2(r.Z, r.W));
    box.SetMargin(inkMargin(r.X, r.Y, 0.0, 0.0));
    box.Reparent(parent);
    let fill = TKInk.Rect(box, 0.0, 0.0, r.Z, r.W);
    fill.SetTintColor(new HDRColor(0.0, 0.0, 0.0, 1.0));
    fill.SetOpacity(TKScale.F("region.fill", 0.45));
    let edges = [Vector4(0.0, 0.0, r.Z, 2.0), Vector4(0.0, r.W - 2.0, r.Z, 2.0), Vector4(0.0, 0.0, 2.0, r.W), Vector4(r.Z - 2.0, 0.0, 2.0, r.W)];
    for e in edges {
      v.Chrome(TKInk.Rect(box, e.X, e.Y, e.Z, e.W), "rule");
    }
    let pad = TKScale.F("region.pad", 18.0);
    let barW = fixed ? 0.0 : 18.0;
    let innerW = MaxF(10.0, r.Z - pad * 2.0 - barW);
    let innerH = MaxF(10.0, r.W - pad * 2.0);
    let clip: ref<inkScrollArea> = new inkScrollArea();
    clip.SetAnchor(inkEAnchor.TopLeft);
    clip.SetAnchorPoint(Vector2(0.0, 0.0));
    clip.SetFitToContentDirection(inkFitToContentDirection.None);
    clip.SetConstrainContentPosition(false);
    clip.SetUseInternalMask(true);
    clip.SetSize(Vector2(innerW, innerH));
    clip.SetMargin(inkMargin(pad, pad, 0.0, 0.0));
    clip.Reparent(box);
    let content: ref<inkVerticalPanel> = new inkVerticalPanel();
    content.SetAnchor(inkEAnchor.TopLeft);
    content.SetAnchorPoint(Vector2(0.0, 0.0));
    content.Reparent(clip);
    let track: ref<inkRectangle>;
    let thumb: ref<inkRectangle>;
    if !fixed {
      track = TKInk.Rect(box, r.Z - pad - 4.0, pad, 4.0, innerH);
      track.SetOpacity(0.35);
      v.Chrome(track, "rule");
      thumb = TKInk.Rect(box, r.Z - pad - 4.0, pad, 4.0, 40.0);
      v.Chrome(thumb, "value");
    }
    // rows are drawn 40 narrower than the width they're given (RowWidth)
    v.BindRegion(this, name, content, innerW + 40.0, fixed);
    v.BindScroll(clip, innerH, track, thumb);
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
    let none: array<String>;
    this.Draw(page, arg, message, same, none);
  }

  // asks the provider for the page and draws the regions in `only` (all when empty)
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
        this.m_views[i].Present(parts[i], page, arg, keep);
      }
      i += 1;
    }
    if IsDefined(this.m_message) {
      this.m_message.SetText(TKScale.T(StrLen(data.message) > 0 ? data.message : message));
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

  public func Act(action: String, arg: String) -> Void {
    let act: ref<TKPage> = new TKPage();
    act.content = this.m_provider;
    act.page = this.m_page;
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
    let moved = StrLen(act.nextPage) > 0 && (NotEquals(act.nextPage, this.m_page) || NotEquals(act.nextArg, this.m_arg));
    if moved {
      this.Show(act.nextPage, act.nextArg, act.message);
    } else {
      this.Draw(this.m_page, this.m_arg, act.message, true, act.refresh);
    }
    if StrLen(act.confirmAction) > 0 && ArraySize(this.m_views) > 0 {
      this.m_views[0].Dialog(act.confirmText, StrLen(act.confirmYes) > 0 ? act.confirmYes : "CONFIRM", act.confirmAction, act.confirmArg);
    }
  }

  public func Back() -> Bool {
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

  public func Stop() -> Void {
    for v in this.m_views {
      v.StopCustom();
      v.StopLive();
    }
  }
}
