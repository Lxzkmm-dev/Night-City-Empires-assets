// =============================================================================
// TERMINAL KIT - HUD PIECES
// Native widgets on the game's HUD layer (hidden in menus by the game itself),
// stacked down from the top centre of the screen, in a TerminalKit palette:
//   - strips: a tracker that stays up while the mod keeps it shown (an
//     objective, an alert): a title, a note on the right, a direction track
//     that follows V's facing toward a target, a line under it, the distance,
//     and an optional draining bar along the bottom;
//   - toasts: a card that shows for a few seconds (a report, a debrief) with a
//     small kicker, a title, a line, a text and a short list, and a timer bar.
//
//   let s = TKHud.Strip("escort", 760.0);        // made once, kept by id
//   s.Set("ESCORT: 8X RIFLES", "TRUCK 92%", "Drop: Watson");
//   s.Target(dropPos); s.Show();                  // Hide() when it's over
//   TKHud.Toast("MY MOD // REPORT", "JOB DONE", "Courier run", "+12,000 E$", "", items, 8.0, false);
//
// A 0.1 s tick runs only while something is up.
// =============================================================================
module TerminalKit

public class TKHudTick extends DelayCallback {
  public let hud: wref<TKHudSystem>;
  public let generation: Int32;
  public func Call() -> Void {
    if IsDefined(this.hud) {
      this.hud.Step(this.generation);
    }
  }
}

// ---- a strip: kept by id, the mod sets its texts and target ----
public class TKHudStrip extends IScriptable {
  public let id: String;
  public let width: Float;
  public let shown: Bool;
  public let title: String;
  public let right: String;
  public let sub: String;
  public let warn: Bool;
  public let hasTarget: Bool;
  public let target: Vector4;
  public let showDistance: Bool;
  public let fraction: Float;         // the bottom bar (below 0: none)
  // widgets (rebuilt with the palette)
  public let box: ref<inkCanvas>;
  public let line: ref<inkRectangle>;
  public let titleText: ref<inkText>;
  public let rightText: ref<inkText>;
  public let subText: ref<inkText>;
  public let distText: ref<inkText>;
  public let track: ref<inkCanvas>;
  public let marker: ref<inkRectangle>;
  public let leftArrow: ref<inkText>;
  public let rightArrow: ref<inkText>;
  public let bar: ref<inkRectangle>;
  public let warned: Bool;            // the widgets are in the warning colour

  public func Set(title: String, right: String, sub: String) -> Void {
    this.title = title;
    this.right = right;
    this.sub = sub;
  }
  // the direction track points at `pos` and the distance shows (`distance` false hides it)
  public func Target(pos: Vector4, opt noDistance: Bool) -> Void {
    this.target = pos;
    this.hasTarget = true;
    this.showDistance = !noDistance;
  }
  // the same toward a TKPins pin (no pin by that name: no target)
  public func TargetPin(key: String, opt noDistance: Bool) -> Void {
    let pos: Vector4;
    if TKPins.Position(key, pos) {
      this.Target(pos, noDistance);
    } else {
      this.NoTarget();
    }
  }
  public func NoTarget() -> Void { this.hasTarget = false; }
  public func Warn(on: Bool) -> Void { this.warn = on; }
  public func Fraction(f: Float) -> Void { this.fraction = f; }
  public func Show() -> Void {
    this.shown = true;
    TKHud.Poll();
  }
  public func Hide() -> Void { this.shown = false; }
}

public abstract class TKHud {
  public static func Get() -> ref<TKHudSystem> = GameInstance.GetScriptableSystemsContainer(GetGameInstance()).Get(n"TerminalKit.TKHudSystem") as TKHudSystem

  // the strip `id` (made on first use, `width` wide)
  public static func Strip(id: String, width: Float) -> ref<TKHudStrip> {
    let hud = TKHud.Get();
    return IsDefined(hud) ? hud.GetStrip(id, width) : new TKHudStrip();
  }

  // a card for `secs` seconds: kicker (small, top), title, a line, a highlight
  // (a payout, in the accent), a text and a short list; `bad` shows it in the
  // warning colour
  public static func Toast(kicker: String, title: String, line: String, highlight: String, text: String, items: array<String>, secs: Float, bad: Bool) -> Void {
    let hud = TKHud.Get();
    if IsDefined(hud) {
      hud.ShowToast(kicker, title, line, highlight, text, items, secs, bad);
    }
  }

  public static func SetTheme(theme: String) -> Void {
    let hud = TKHud.Get();
    if IsDefined(hud) {
      hud.SetTheme(theme);
    }
  }

  public static func Poll() -> Void {
    let hud = TKHud.Get();
    if IsDefined(hud) {
      hud.Poll();
    }
  }

  // where `target` sits across V's view: 0 = 90 degrees left, 0.5 = ahead, 1 = 90 right
  public static func Along(target: Vector4) -> Float {
    let p = GetPlayer(GetGameInstance());
    if !IsDefined(p) {
      return 0.5;
    }
    let pos = p.GetWorldPosition();
    let fw = p.GetWorldForward();
    let rel = Rad2Deg(AtanF(target.X - pos.X, target.Y - pos.Y)) - Rad2Deg(AtanF(fw.X, fw.Y));
    while rel > 180.0 { rel -= 360.0; }
    while rel < -180.0 { rel += 360.0; }
    return ClampF((rel + 90.0) / 180.0, 0.0, 1.0);
  }

  public static func Warning() -> HDRColor = new HDRColor(1.0, 0.22, 0.2, 1.0)
}

public class TKHudSystem extends ScriptableSystem {
  private let m_root: ref<inkCanvas>;
  private let m_generation: Int32;
  private let m_ticking: Bool;
  private let m_theme: String = "hud";
  private let m_built: String;              // the palette the strips were built in
  private let m_strips: array<ref<TKHudStrip>>;
  // the toast (one at a time: a new one replaces it)
  private let m_toast: ref<inkCanvas>;
  private let m_toastTime: ref<inkRectangle>;
  private let m_toastW: Float;
  private let m_hideAt: Float;
  private let m_length: Float;

  private func OnPlayerAttach(request: ref<PlayerAttachRequest>) -> Void {
    this.m_generation += 1;
    this.m_ticking = false;
    this.m_root = null;   // the HUD layer is rebuilt with each session
    this.m_toast = null;
    this.m_hideAt = 0.0;
    for s in this.m_strips {
      s.box = null;
      s.shown = false;
    }
  }

  private func Now() -> Float = EngineTime.ToFloat(GameInstance.GetEngineTime(this.GetGameInstance()))

  public func SetTheme(theme: String) -> Void {
    if StrLen(theme) > 0 {
      this.m_theme = theme;
    }
  }

  public func GetStrip(id: String, width: Float) -> ref<TKHudStrip> {
    for s in this.m_strips {
      if Equals(s.id, id) {
        return s;
      }
    }
    let s = new TKHudStrip();
    s.id = id;
    s.width = width;
    s.fraction = -1.0;
    ArrayPush(this.m_strips, s);
    return s;
  }

  // ---- ink ----
  private func Paint(w: ref<inkWidget>, role: String) -> Void { TKTheme.Paint(w, this.m_theme, role); }

  private func Fixed(w: ref<inkWidget>, color: HDRColor) -> Void {
    TKTheme.Paint(w, "mono", "text");   // drops the HUD style binding, if any
    w.SetTintColor(color);
  }

  private func Text(parent: ref<inkCompoundWidget>, size: Int32, style: CName, role: String, x: Float, y: Float, right: Bool) -> ref<inkText> {
    let t = new inkText();
    t.SetFontFamily("base\\gameplay\\gui\\fonts\\raj\\raj.inkfontfamily");
    t.SetFontStyle(style);
    t.SetFontSize(size);
    t.SetLetterCase(textLetterCase.OriginalCase);
    if right {
      t.SetAnchor(inkEAnchor.TopRight);
      t.SetAnchorPoint(Vector2(1.0, 0.0));
      t.SetHorizontalAlignment(textHorizontalAlignment.Right);
      t.SetMargin(inkMargin(0.0, y, x, 0.0));
    } else {
      t.SetAnchor(inkEAnchor.TopLeft);
      t.SetMargin(inkMargin(x, y, 0.0, 0.0));
    }
    t.Reparent(parent);
    this.Paint(t, role);
    return t;
  }

  // role "" = the dark card background
  private func Rect(parent: ref<inkCompoundWidget>, x: Float, y: Float, w: Float, h: Float, role: String, opacity: Float) -> ref<inkRectangle> {
    let r = new inkRectangle();
    r.SetAnchor(inkEAnchor.TopLeft);
    r.SetMargin(inkMargin(x, y, 0.0, 0.0));
    r.SetSize(Vector2(w, h));
    r.SetOpacity(opacity);
    r.Reparent(parent);
    if StrLen(role) > 0 {
      this.Paint(r, role);
    } else {
      r.SetTintColor(new HDRColor(0.02, 0.02, 0.03, 1.0));
    }
    return r;
  }

  private func Panel(w: Float, h: Float) -> ref<inkCanvas> {
    let c = new inkCanvas();
    c.SetSize(Vector2(w, h));
    c.SetAnchor(inkEAnchor.TopCenter);
    c.SetAnchorPoint(Vector2(0.5, 0.0));
    c.SetMargin(inkMargin(0.0, 20.0, 0.0, 0.0));
    c.SetVisible(false);
    c.Reparent(this.m_root);
    return c;
  }

  private func Build() -> Bool {
    if !IsDefined(this.m_root) {
      let layer = GameInstance.GetInkSystem().GetLayer(n"inkHUDLayer");
      if !IsDefined(layer) {
        return false;
      }
      this.m_root = new inkCanvas();
      this.m_root.SetName(n"TKHud");
      this.m_root.SetAnchor(inkEAnchor.Fill);
      this.m_root.Reparent(layer.GetVirtualWindow());
      this.m_built = "";
    }
    if !Equals(this.m_built, this.m_theme) {
      this.m_built = this.m_theme;
      for s in this.m_strips {
        if IsDefined(s.box) {
          this.m_root.RemoveChild(s.box);
          s.box = null;
        }
      }
    }
    return true;
  }

  private func BuildStrip(s: ref<TKHudStrip>) -> Void {
    let w = s.width;
    let h = 112.0;
    s.box = this.Panel(w, h);
    this.Rect(s.box, 0.0, 0.0, w, h, "", 0.62);
    s.line = this.Rect(s.box, 0.0, 0.0, w, 3.0, "accent", 1.0);
    s.titleText = this.Text(s.box, 28, n"Semi-Bold", "accent", 20.0, 10.0, false);
    s.rightText = this.Text(s.box, 24, n"Medium", "text", 20.0, 13.0, true);
    // the direction track: a line, a centre tick, a diamond sliding toward the target
    let x = 40.0;
    let y = 58.0;
    let tw = w - 80.0;
    s.track = new inkCanvas();
    s.track.SetSize(Vector2(w, 30.0));
    s.track.Reparent(s.box);
    this.Rect(s.track, x, y, tw, 2.0, "text", 0.45);
    this.Rect(s.track, x + tw / 2.0 - 1.0, y - 6.0, 2.0, 14.0, "text", 0.6);
    s.marker = this.Rect(s.track, x, y - 4.0, 10.0, 10.0, "accent", 1.0);
    s.marker.SetRotation(45.0);
    s.leftArrow = this.Text(s.track, 26, n"Semi-Bold", "accent", x - 24.0, y - 17.0, false);
    s.leftArrow.SetText("<");
    s.rightArrow = this.Text(s.track, 26, n"Semi-Bold", "accent", x + tw + 10.0, y - 17.0, false);
    s.rightArrow.SetText(">");
    s.subText = this.Text(s.box, 22, n"Regular", "text", 20.0, 74.0, false);
    s.distText = this.Text(s.box, 26, n"Semi-Bold", "value", 20.0, 71.0, true);
    s.bar = this.Rect(s.box, 0.0, h - 4.0, w, 4.0, "accent", 0.9);
    s.warned = false;
  }

  // ---- the toast: sized to what it holds ----
  public func ShowToast(kicker: String, title: String, line: String, highlight: String, text: String, items: array<String>, secs: Float, bad: Bool) -> Void {
    if !this.Build() {
      return;
    }
    if !IsDefined(this.m_toast) {
      this.m_toast = this.Panel(880.0, 200.0);
    }
    let w = 880.0;
    let pad = 36.0;
    let tw = w - pad * 2.0;
    let c = this.m_toast;
    c.RemoveAllChildren();
    let back = this.Rect(c, 0.0, 0.0, w, 100.0, "", 0.93);
    let edge = this.Rect(c, 0.0, 0.0, 5.0, 100.0, "accent", 1.0);
    this.Text(c, 18, n"Medium", "text", pad, 18.0, false).SetText(kicker);
    let head = this.Text(c, 38, n"Semi-Bold", "title", pad, 42.0, false);
    head.SetText(title);
    if bad {
      this.Fixed(head, TKHud.Warning());
      this.Fixed(edge, TKHud.Warning());
    }
    let y = 94.0;
    if StrLen(line) > 0 {
      let t = this.Text(c, 24, n"Medium", "value", pad, y, false);
      t.SetText(line);
      t.SetWrapping(true, tw);
      y += 34.0 * TKInk.Lines(line, 24, tw);
    }
    if StrLen(highlight) > 0 {
      let m = this.Text(c, 24, n"Semi-Bold", "accent", pad, y, false);
      m.SetText(highlight);
      if bad {
        this.Fixed(m, TKHud.Warning());
      }
      y += 34.0;
    }
    if StrLen(text) > 0 {
      y += 10.0;
      let t = this.Text(c, 21, n"Regular", "text", pad, y, false);
      t.SetText(text);
      t.SetWrapping(true, tw);
      y += 29.0 * TKInk.Lines(text, 21, tw);
    }
    if ArraySize(items) > 0 {
      y += 10.0;
      for item in items {
        this.Rect(c, pad + 1.0, y + 12.0, 7.0, 7.0, "accent", 1.0).SetRotation(45.0);
        let t = this.Text(c, 22, n"Medium", "value", pad + 22.0, y, false);
        t.SetText(item);
        t.SetWrapping(true, tw - 22.0);
        y += 31.0 * TKInk.Lines(item, 22, tw - 22.0);
      }
    }
    let h = y + 28.0;
    back.SetSize(Vector2(w, h));
    edge.SetSize(Vector2(5.0, h));
    this.m_toastTime = this.Rect(c, 5.0, h - 4.0, w - 5.0, 4.0, "accent", 0.7);
    c.SetSize(Vector2(w, h));
    this.m_toastW = w - 5.0;
    this.m_length = MaxF(1.0, secs);
    this.m_hideAt = this.Now() + this.m_length;
    c.SetVisible(true);
    this.Poll();
  }

  // starts the fast tick when something needs drawing
  public func Poll() -> Void {
    if this.m_ticking {
      return;
    }
    let any = this.m_hideAt > 0.0;
    for s in this.m_strips {
      if s.shown {
        any = true;
      }
    }
    if any {
      this.m_ticking = true;
      this.Step(this.m_generation);
    }
  }

  // everything stacks down from the top centre: the strips in the order they were made, then the toast
  public func Step(generation: Int32) -> Void {
    if generation != this.m_generation {
      return;
    }
    if !this.Build() {
      this.m_ticking = false;   // no HUD layer yet: the next Poll tries again
      return;
    }
    let y = 20.0;
    let busy = false;
    for s in this.m_strips {
      if s.shown {
        if !IsDefined(s.box) {
          this.BuildStrip(s);
        }
        this.DrawStrip(s, y);
        y += 124.0;
        busy = true;
      } else {
        if IsDefined(s.box) {
          s.box.SetVisible(false);
        }
      }
    }
    if this.StepToast(y) {
      busy = true;
    }
    this.m_ticking = busy;
    if busy {
      let cb = new TKHudTick();
      cb.hud = this;
      cb.generation = this.m_generation;
      GameInstance.GetDelaySystem(this.GetGameInstance()).DelayCallback(cb, 0.1, false);
    }
  }

  private func DrawStrip(s: ref<TKHudStrip>, y: Float) -> Void {
    if !Equals(s.warn, s.warned) {
      if s.warn {
        this.Fixed(s.titleText, TKHud.Warning());
        this.Fixed(s.line, TKHud.Warning());
      } else {
        this.Paint(s.titleText, "accent");
        this.Paint(s.line, "accent");
      }
      s.warned = s.warn;
    }
    s.titleText.SetText(s.title);
    s.rightText.SetText(s.right);
    s.subText.SetText(s.sub);
    s.track.SetVisible(s.hasTarget);
    s.distText.SetVisible(s.hasTarget && s.showDistance);
    if s.hasTarget {
      let along = TKHud.Along(s.target);
      let tw = s.width - 80.0;
      s.marker.SetMargin(inkMargin(40.0 + along * (tw - 10.0), s.marker.GetMargin().top, 0.0, 0.0));
      s.leftArrow.SetVisible(along <= 0.0);
      s.rightArrow.SetVisible(along >= 1.0);
      let p = GetPlayer(this.GetGameInstance());
      if IsDefined(p) {
        let pos = p.GetWorldPosition();
        let dx = pos.X - s.target.X;
        let dy = pos.Y - s.target.Y;
        s.distText.SetText(TKGame.Distance(SqrtF(dx * dx + dy * dy)));   // the player's own units
      }
    }
    s.bar.SetVisible(s.fraction >= 0.0);
    if s.fraction >= 0.0 {
      s.bar.SetSize(Vector2(s.width * ClampF(s.fraction, 0.0, 1.0), 4.0));
    }
    s.box.SetMargin(inkMargin(0.0, y, 0.0, 0.0));
    s.box.SetVisible(true);
  }

  private func StepToast(y: Float) -> Bool {
    if !IsDefined(this.m_toast) {
      return false;
    }
    let left = this.m_hideAt - this.Now();
    if this.m_hideAt <= 0.0 || left <= 0.0 {
      this.m_hideAt = 0.0;
      this.m_toast.SetVisible(false);
      return false;
    }
    this.m_toast.SetMargin(inkMargin(0.0, y, 0.0, 0.0));
    this.m_toastTime.SetSize(Vector2(this.m_toastW * left / this.m_length, 4.0));
    return true;
  }
}
