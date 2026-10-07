// =============================================================================
// TERMINAL KIT - THE READY-MADE FRAME
// A full-screen in-game terminal: a Codeware popup with a cursor, a faint lens
// tint over the world, HUD corner brackets, a brand line, sidebar tabs, a
// scrolling page with a scroll bar, tooltips, a footer and a short boot flicker.
// The mouse wheel scrolls, the right mouse button goes back a page, Esc closes.
//
// A mod subclasses it and overrides what it needs (only Content() is required):
//
//   public class MyTerminal extends TKPopup {
//     public func Content() -> ref<TKContent> = new MyContent()
//     public func Tabs() -> array<String> = ["HOME|home", "CREW|crew"]
//     public func Name() -> String = "MY TERMINAL"
//   }
//   TKPopup.Open(player, new MyTerminal());
//
// Layout numbers come through TKScale (keys "frame.w", "side.w", "content.h"...),
// so a mod's scale source or tuner reaches the frame too.
// =============================================================================
module TerminalKit

import Codeware.UI.*
import RedFunctions.*

public class TKPopup extends InGamePopup {
  protected let m_player: wref<PlayerPuppet>;
  protected let m_view: ref<TKView>;
  protected let m_regions: ref<TKRegions>;
  protected let m_frame: wref<inkCompoundWidget>;
  protected let m_boot: wref<inkText>;
  protected let m_bootProxy: ref<inkAnimProxy>;
  protected let m_bootLines: array<wref<inkText>>;
  protected let m_lens: wref<inkWidget>;
  protected let m_hideable: array<wref<inkWidget>>;   // everything a bare page hides
  protected let m_bare: Bool;
  protected let m_rightDown: Bool;   // a right click (back) is held: its release mustn't close the frame

  // ---------------------------------------------------------------------------
  // What a mod sets (override any of these)
  // ---------------------------------------------------------------------------
  public func Content() -> ref<TKContent> = null
  // the sidebar: "LABEL|page" or "LABEL|page~arg"
  public func Tabs() -> array<String> {
    let none: array<String>;
    return none;
  }
  public func Brand() -> String = "TERMINAL KIT"                    // small, left of the name
  public func Name() -> String = "TERMINAL"                         // large, top left
  public func Status() -> String = ""                               // small, top right
  public func Footer() -> String = "[ESC] CLOSE    [RIGHT CLICK] BACK"
  // the game's own key prompts in place of the footer text, "action|LABEL"
  // (["back|BACK", "cancel|CLOSE"]): each shows the key or pad button the player
  // has bound to that input action (empty: the Footer() text, as before)
  public func Hints() -> array<String> {
    let none: array<String>;
    return none;
  }
  public func BootText() -> String = "CONNECTING..."
  // several boot lines, shown one after another (empty: BootText alone, as before)
  public func BootLines() -> array<String> {
    let none: array<String>;
    return none;
  }
  public func BootSeconds() -> Float = 0.0                          // how long the boot text stays (0: the kit's timing)
  public func Style() -> ref<TKStyle> = null                        // the frame's look (null: the kit's normal look)
  // this frame's own layout numbers and texts while it is open (null: the shared
  // TKScale.Use slot; `new TKScaleDefaults()`: the kit's own, whatever other mods set)
  public func ScaleSource() -> ref<TKScaleSource> = null
  // regions instead of the sidebar and the one page, "name|side|size|flags"
  // (see TKRegions): rows go to a region after p.Region(name). Empty: the
  // sidebar and the page, as before. Tabs() isn't drawn with a layout.
  public func Layout() -> array<String> {
    let none: array<String>;
    return none;
  }
  // the layout's regions while the frame is open (null without a layout)
  public func Regions() -> ref<TKRegions> = this.m_regions
  public func StartPage() -> String = "home"
  public func StartArg() -> String = ""
  public func CornerTab() -> String = ""                            // "LABEL|page": a button top right
  public func Lens() -> Bool = true                                 // the lens tint and vignette over the world
  public func FrameWidth() -> Float = TKScale.F("frame.w", 3000.0)
  public func FrameHeight() -> Float = TKScale.F("frame.h", 1500.0)
  public func PageWidth() -> Float = TKScale.F("content.w", 2300.0)
  public func PageHeight() -> Float = TKScale.F("content.h", 1080.0)
  protected func Setup() -> Void {}                                  // before the frame is built (a scale source...)
  protected func Icon(bar: ref<inkHorizontalPanel>) -> Void {}       // an icon left of the brand
  protected func Opened() -> Void {                                  // the first page
    this.m_view.Show(this.StartPage(), this.StartArg(), "");
  }
  protected func Closing() -> Void {}                                // before it goes (remember the page)
  protected func Closed() -> Void {}                                 // after (a menu that needs the input back)

  // ---------------------------------------------------------------------------
  // Opening and state
  // ---------------------------------------------------------------------------
  // Only from plain gameplay: opening over a menu (pause, inventory, map, hub),
  // while paused or in photo mode leaves the popup queued under it and the UI
  // context stuck, which locks every control
  public static func CanOpen(player: ref<PlayerPuppet>) -> Bool {
    if !IsDefined(player) {
      return false;
    }
    let game = player.GetGame();
    let ui = GameInstance.GetBlackboardSystem(game).Get(GetAllBlackboardDefs().UI_System);
    if IsDefined(ui) && ui.GetBool(GetAllBlackboardDefs().UI_System.IsInMenu) {
      return false;
    }
    if GameInstance.GetTimeSystem(game).IsPausedState() {
      return false;
    }
    if GameInstance.GetPhotoModeSystem(game).IsPhotoModeActive() {
      return false;
    }
    return true;
  }

  // shows `popup` (check CanOpen first)
  public static func Open(player: ref<PlayerPuppet>, popup: ref<TKPopup>) -> Void {
    if !IsDefined(player) || !IsDefined(popup) {
      return;
    }
    popup.m_player = player;
    GameInstance.GetUISystem(player.GetGame()).QueueEvent(ShowCustomPopupEvent.Create(popup));
  }

  public func View() -> ref<TKView> = this.m_view
  public func Player() -> wref<PlayerPuppet> = this.m_player
  public func IsTyping() -> Bool = IsDefined(this.m_regions) ? this.m_regions.IsTyping() : IsDefined(this.m_view) && this.m_view.IsTyping()

  public func UseCursor() -> Bool = true

  // Input context only: the popup's usual "inkModalPopupState" visual state froze
  // and blurred the world, and kept the frame from the first opening
  protected func SetUIContext() -> Void {
    GameInstance.GetUISystem(this.GetGame()).PushGameContext(UIGameContext.ModalPopup);
  }

  protected func ResetUIContext() -> Void {
    GameInstance.GetUISystem(this.GetGame()).PopGameContext(UIGameContext.ModalPopup);
  }

  protected func PlayShowSound() -> Void {
    if IsDefined(this.m_player) {
      let style = this.Style();
      GameObject.PlaySound(this.m_player, IsDefined(style) && NotEquals(style.openSound, n"") ? style.openSound : n"ui_hacking_access_granted");
    }
  }

  protected func PlayHideSound() -> Void {
    if IsDefined(this.m_player) {
      let style = this.Style();
      GameObject.PlaySound(this.m_player, IsDefined(style) && NotEquals(style.closeSound, n"") ? style.closeSound : n"ui_menu_onpress");
    }
  }

  // ---------------------------------------------------------------------------
  // Look: a faint lens tint and edge vignette instead of the popup backdrop
  // ---------------------------------------------------------------------------
  protected func CreateVignette() -> Void {
    let tint: ref<inkRectangle> = new inkRectangle();
    tint.SetName(n"lens");
    tint.SetAnchor(inkEAnchor.Fill);
    tint.SetTintColor(new HDRColor(0.02, 0.07, 0.09, 1.0));
    tint.SetOpacity(0.55);
    tint.Reparent(this.GetRootCompoundWidget());
    this.m_lens = tint;

    let edge: ref<inkImage> = new inkImage();
    edge.SetName(n"vignette");
    edge.SetAtlasResource(r"base\\gameplay\\gui\\widgets\\notifications\\vignette.inkatlas");
    edge.SetTexturePart(n"vignette_1");
    edge.SetNineSliceScale(true);
    edge.SetAnchor(inkEAnchor.Fill);
    edge.SetStyle(r"base\\gameplay\\gui\\common\\main_colors.inkstyle");
    edge.BindProperty(n"tintColor", n"MainColors.Blue");
    edge.SetOpacity(0.35);
    edge.Reparent(this.GetRootCompoundWidget());
    this.m_vignette = edge;
    if !this.Lens() {
      tint.SetVisible(false);
      edge.SetVisible(false);
    }
  }

  protected func CreateContainer() -> Void {
    let frame: ref<inkCanvas> = new inkCanvas();
    frame.SetName(n"container");
    frame.SetAnchor(inkEAnchor.Centered);
    frame.SetAnchorPoint(Vector2(0.5, 0.5));
    frame.SetSize(Vector2(this.FrameWidth(), this.FrameHeight()));
    frame.Reparent(this.GetRootCompoundWidget());
    this.m_container = frame;
    this.m_frame = frame;
    this.SetContainerWidget(frame);
  }

  protected cb func OnCreate() -> Void {
    super.OnCreate();
    TKScale.Activate(this.ScaleSource());
    let look = this.Style();
    TKInk.UseFont(IsDefined(look) ? look.fontFamily : "", IsDefined(look) ? look.fontStyle : n"");
    this.Setup();
    this.RegisterToGlobalInputCallback(n"OnPostOnRelative", this, n"OnFrameRelative");
    this.RegisterToGlobalInputCallback(n"OnPostOnPress", this, n"OnFramePress");
    this.BuildFrame();
    this.Opened();
  }

  // rebuild the whole frame (a changed layout), same page
  public func Rebuild() -> Void {
    let page = this.m_view.CurrentPage();
    let arg = this.m_view.CurrentArg();
    this.SetBare(false);
    this.m_view.StopCustom();
    this.m_frame.RemoveAllChildren();
    this.BuildFrame();
    this.m_boot.SetOpacity(0.0);
    this.m_view.Show(page, arg, "");
  }

  // ---------------------------------------------------------------------------
  // The frame
  // ---------------------------------------------------------------------------
  private func BuildFrame() -> Void {
    let frame = this.m_frame;
    let fw = this.FrameWidth();
    ArrayClear(this.m_hideable);
    this.m_regions = null;
    this.m_view = new TKView();
    let adapter = new TKPopupFrame();
    adapter.popup = this;
    this.m_view.SetFrame(adapter);
    this.m_view.SetContent(this.Content());
    this.m_view.SetStyle(this.Style());
    this.m_view.Chrome(this.m_vignette, "frame");
    this.Brackets(frame);
    this.Decor(frame);

    // top bar: icon, BRAND // NAME
    let bar: ref<inkHorizontalPanel> = new inkHorizontalPanel();
    bar.SetMargin(inkMargin(70.0, 30.0, 0.0, 0.0));
    bar.Reparent(frame);
    ArrayPush(this.m_hideable, bar);
    this.Icon(bar);
    let brand = TKInk.Line(bar, TKScale.T(this.Brand()), TKScale.I("frame.brand", 30), n"Medium", n"MainColors.PanelBlue", 0.0);
    brand.SetVAlign(inkEVerticalAlign.Center);
    this.m_view.Chrome(brand, "text");
    let slash = TKInk.Line(bar, "   //   ", 30, n"Regular", n"MainColors.DarkRed", 0.0);
    slash.SetVAlign(inkEVerticalAlign.Center);
    this.m_view.Chrome(slash, "rule");
    let name = TKInk.Line(bar, TKScale.T(this.Name()), TKScale.I("frame.name", 64), n"Semi-Bold", n"MainColors.Red", 0.0);
    name.SetVAlign(inkEVerticalAlign.Center);
    this.m_view.Chrome(name, "accent");

    // top right: the corner button and the status line
    let corner = this.CornerTab();
    let right = 70.0;
    if StrLen(corner) > 0 {
      let w = TKScale.F("settings.w", 280.0);
      let b = this.m_view.AddTab(frame, StrBeforeFirst(corner, "|"), StrAfterFirst(corner, "|"), w, TKScale.F("settings.h", 64.0), TKScale.I("side.font", 30));
      let root = b.GetRootWidget();
      root.SetAnchor(inkEAnchor.TopRight);
      root.SetAnchorPoint(Vector2(1.0, 0.0));
      root.SetMargin(inkMargin(0.0, 52.0, 70.0, 0.0));
      ArrayPush(this.m_hideable, root);
      right += w + 40.0;
    }
    if StrLen(this.Status()) > 0 {
      let status: ref<inkText> = TKInk.Line(frame, TKScale.T(this.Status()), 26, n"Regular", n"MainColors.PanelBlue", 0.0);
      status.SetAnchor(inkEAnchor.TopRight);
      status.SetAnchorPoint(Vector2(1.0, 0.0));
      status.SetMargin(inkMargin(0.0, 70.0, right, 0.0));
      status.SetOpacity(0.7);
      this.m_view.Chrome(status, "text");
      ArrayPush(this.m_hideable, status);
    }

    let rule: ref<inkRectangle> = new inkRectangle();
    rule.SetSize(Vector2(fw - 140.0, 2.0));
    rule.SetMargin(inkMargin(70.0, 150.0, 0.0, 0.0));
    rule.Reparent(frame);
    this.m_view.Chrome(rule, "rule");
    ArrayPush(this.m_hideable, rule);

    // body: the regions a layout lists, or tabs on the left and the page on the right
    if ArraySize(this.Layout()) > 0 {
      this.BuildRegions(frame);
    } else {
      this.BuildPage(frame);
    }
    // footer: the game's own key prompts when the frame lists them, else the text
    let hints = this.Hints();
    if ArraySize(hints) > 0 {
      this.KeyHints(frame, hints);
    } else if StrLen(this.Footer()) > 0 {
      let foot: ref<inkText> = TKInk.Line(frame, TKScale.T(this.Footer()), 26, n"Medium", n"MainColors.PanelBlue", 0.0);
      foot.SetAnchor(inkEAnchor.BottomLeft);
      foot.SetAnchorPoint(Vector2(0.0, 1.0));
      foot.SetMargin(inkMargin(70.0, 0.0, 0.0, 40.0));
      foot.SetOpacity(0.7);
      this.m_view.Chrome(foot, "text");
      ArrayPush(this.m_hideable, foot);
    }

    // a static scanline overlay, over everything (it takes no clicks)
    let lines = this.m_view.Style().scanlines;
    if lines > 0.0 {
      let scan: ref<inkCanvas> = new inkCanvas();
      scan.SetSize(Vector2(fw, this.FrameHeight()));
      scan.SetOpacity(MinF(lines, 0.6));
      scan.Reparent(frame);
      ArrayPush(this.m_hideable, scan);
      let y = 0.0;
      while y < this.FrameHeight() {
        TKInk.Rect(scan, 0.0, y, fw, 3.0).SetTintColor(new HDRColor(0.0, 0.0, 0.0, 1.0));
        y += 9.0;
      }
    }

    // boot text, shown over the frame while it flickers in: one line, or several
    // that come up one after another
    let boots = this.BootLines();
    ArrayClear(this.m_bootLines);
    this.m_boot = TKInk.Line(frame, ArraySize(boots) > 0 ? "" : TKScale.T(this.BootText()), 40, n"Medium", n"MainColors.Blue", 0.0);
    this.m_boot.SetAnchor(inkEAnchor.BottomRight);
    this.m_boot.SetAnchorPoint(Vector2(1.0, 1.0));
    this.m_boot.SetMargin(inkMargin(0.0, 0.0, 70.0, 40.0));
    this.m_view.Chrome(this.m_boot, "value");
    if ArraySize(boots) > 0 {
      let stack: ref<inkVerticalPanel> = new inkVerticalPanel();
      stack.SetAnchor(inkEAnchor.BottomRight);
      stack.SetAnchorPoint(Vector2(1.0, 1.0));
      stack.SetMargin(inkMargin(0.0, 0.0, 70.0, 40.0));
      stack.Reparent(frame);
      for text in boots {
        let line = TKInk.Line(stack, TKScale.T(text), 32, n"Medium", n"MainColors.Blue", 2.0);
        line.SetHAlign(inkEHorizontalAlign.Right);
        line.SetOpacity(0.0);
        this.m_view.Chrome(line, "value");
        ArrayPush(this.m_bootLines, line);
      }
    }
  }

  // the regions of Layout() under the top rule, the page's message bottom right
  private func BuildRegions(frame: ref<inkCompoundWidget>) -> Void {
    let message = TKInk.Line(frame, "", TKScale.I("message", 30), n"Medium", n"MainColors.Blue", 0.0);
    message.SetAnchor(inkEAnchor.BottomRight);
    message.SetAnchorPoint(Vector2(1.0, 1.0));
    message.SetMargin(inkMargin(0.0, 0.0, 70.0, 40.0));
    this.m_view.Chrome(message, "value");
    this.m_regions = new TKRegions();
    let top = TKScale.F("layout.top", 180.0);
    let foot = TKScale.F("layout.foot", 110.0);
    this.m_regions.Build(frame, 70.0, top, this.FrameWidth() - 140.0, this.FrameHeight() - top - foot, this.Layout(),
      this.m_view, this.m_view.FrameOf(), this.Content(), this.Style(), message);
  }

  // the sidebar tabs and the one scrolling page (a frame without Layout())
  private func BuildPage(frame: ref<inkCompoundWidget>) -> Void {
    let body: ref<inkHorizontalPanel> = new inkHorizontalPanel();
    body.SetMargin(inkMargin(70.0, 190.0, 0.0, 0.0));
    body.Reparent(frame);
    let tabs = this.Tabs();
    if ArraySize(tabs) > 0 {
      let side: ref<inkVerticalPanel> = new inkVerticalPanel();
      side.SetMargin(inkMargin(0.0, 0.0, 80.0, 0.0));
      side.Reparent(body);
      ArrayPush(this.m_hideable, side);
      for pair in tabs {
        this.m_view.AddTab(side, StrBeforeFirst(pair, "|"), StrAfterFirst(pair, "|"), TKScale.F("side.w", 460.0), TKScale.F("side.h", 74.0), TKScale.I("side.font", 30))
          .GetRootWidget().SetMargin(inkMargin(0.0, 0.0, 0.0, TKScale.F("side.gap", 12.0)));
      }
    }

    let page: ref<inkVerticalPanel> = new inkVerticalPanel();
    page.Reparent(body);
    let title = TKInk.Line(page, "", TKScale.I("title", 56), n"Medium", n"MainColors.Blue", 0.0);
    let subtitle = TKInk.Line(page, "", TKScale.I("subtitle", 28), n"Regular", n"MainColors.PanelBlue", 2.0);
    ArrayPush(this.m_hideable, title);
    ArrayPush(this.m_hideable, subtitle);
    // the page scrolls: its rows sit in a clipped area the wheel moves, a thin
    // bar on the right shows where in the page the view is
    let contentW = this.PageWidth();
    let contentH = this.PageHeight();
    let viewport: ref<inkCanvas> = new inkCanvas();
    viewport.SetSize(Vector2(contentW + 30.0, contentH));
    viewport.SetMargin(inkMargin(0.0, 12.0, 0.0, 0.0));
    viewport.Reparent(page);
    let clip: ref<inkScrollArea> = new inkScrollArea();
    clip.SetAnchor(inkEAnchor.TopLeft);
    clip.SetAnchorPoint(Vector2(0.0, 0.0));
    clip.SetFitToContentDirection(inkFitToContentDirection.None);
    clip.SetConstrainContentPosition(false);
    clip.SetUseInternalMask(true);
    clip.SetSize(Vector2(contentW, contentH));
    clip.Reparent(viewport);
    let content: ref<inkVerticalPanel> = new inkVerticalPanel();
    content.SetAnchor(inkEAnchor.TopLeft);
    content.SetAnchorPoint(Vector2(0.0, 0.0));
    content.Reparent(clip);
    let track: ref<inkRectangle> = new inkRectangle();
    track.SetSize(Vector2(4.0, contentH));
    track.SetMargin(inkMargin(contentW + 20.0, 0.0, 0.0, 0.0));
    track.SetOpacity(0.35);
    track.Reparent(viewport);
    this.m_view.Chrome(track, "rule");
    let thumb: ref<inkRectangle> = new inkRectangle();
    thumb.SetSize(Vector2(4.0, 40.0));
    thumb.SetMargin(inkMargin(contentW + 20.0, 0.0, 0.0, 0.0));
    thumb.Reparent(viewport);
    this.m_view.Chrome(thumb, "value");
    let message = TKInk.Line(page, "", TKScale.I("message", 30), n"Medium", n"MainColors.Blue", 8.0);
    this.m_view.Bind(content, title, subtitle, message, contentW);
    this.m_view.BindScroll(clip, contentH, track, thumb);
    // tooltips, dialogs and drop-down lists float over the page
    let overlay: ref<inkCanvas> = new inkCanvas();
    overlay.SetSize(Vector2(contentW + 30.0, contentH));
    overlay.SetAnchor(inkEAnchor.TopLeft);
    overlay.SetAnchorPoint(Vector2(0.0, 0.0));
    overlay.Reparent(viewport);
    this.m_view.SetTipLayer(overlay);
  }

  // the game's button-hint bar (the one under the pause menu), bottom left
  private func KeyHints(frame: ref<inkCompoundWidget>, hints: array<String>) -> Void {
    let bar = this.SpawnFromExternal(frame, r"base\\gameplay\\gui\\common\\buttonhints.inkwidget", n"Root");
    if !IsDefined(bar) {
      return;
    }
    bar.SetAnchor(inkEAnchor.BottomLeft);
    bar.SetAnchorPoint(Vector2(0.0, 1.0));
    bar.SetMargin(inkMargin(70.0, 0.0, 0.0, 40.0));
    ArrayPush(this.m_hideable, bar);
    let ctrl = bar.GetController() as ButtonHints;
    if !IsDefined(ctrl) {
      return;
    }
    ctrl.SetInverted(true);
    for pair in hints {
      ctrl.AddButtonHint(StringToName(StrBeforeFirst(pair, "|")), TKScale.T(StrAfterFirst(pair, "|")));
    }
  }

  // ---------------------------------------------------------------------------
  // The style's frame options: all static, built once with the frame
  // ---------------------------------------------------------------------------
  private func Decor(frame: ref<inkCompoundWidget>) -> Void {
    let style = this.m_view.Style();
    let w = this.FrameWidth();
    let h = this.FrameHeight();
    if style.frame == 1 {
      // notched: a cut across each corner
      let n = 70.0;
      this.Diag(frame, 0.0, n, n, 0.0);
      this.Diag(frame, w - n, 0.0, w, n);
      this.Diag(frame, 0.0, h - n, n, h);
      this.Diag(frame, w - n, h, w, h - n);
    }
    if style.frame == 2 {
      // armoured: a full border, a second line inside it, heavy corners
      this.Bar(frame, 0.0, 0.0, w, 3.0);
      this.Bar(frame, 0.0, h - 3.0, w, 3.0);
      this.Bar(frame, 0.0, 0.0, 3.0, h);
      this.Bar(frame, w - 3.0, 0.0, 3.0, h);
      let o = 16.0;
      this.Bar(frame, o, o, w - o * 2.0, 2.0).SetOpacity(0.4);
      this.Bar(frame, o, h - o - 2.0, w - o * 2.0, 2.0).SetOpacity(0.4);
      this.Bar(frame, o, o, 2.0, h - o * 2.0).SetOpacity(0.4);
      this.Bar(frame, w - o - 2.0, o, 2.0, h - o * 2.0).SetOpacity(0.4);
      let len = 170.0;
      let t = 10.0;
      this.Bar(frame, 0.0, 0.0, len, t);
      this.Bar(frame, 0.0, 0.0, t, len);
      this.Bar(frame, w - len, 0.0, len, t);
      this.Bar(frame, w - t, 0.0, t, len);
      this.Bar(frame, 0.0, h - t, len, t);
      this.Bar(frame, 0.0, h - len, t, len);
      this.Bar(frame, w - len, h - t, len, t);
      this.Bar(frame, w - t, h - len, t, len);
    }
    if style.rivets {
      // a row of rivets inside the top and bottom edges
      let x = 260.0;
      while x < w - 260.0 {
        this.Rivet(frame, x, 12.0);
        this.Rivet(frame, x, h - 22.0);
        x += 150.0;
      }
    }
    if style.hazard {
      // hazard stripes: top right and bottom left, clear of the brand and the footer
      this.Hazard(frame, w - 470.0, 10.0);
      this.Hazard(frame, 230.0, h - 30.0);
    }
  }

  private func Rivet(frame: ref<inkCompoundWidget>, x: Float, y: Float) -> Void {
    let r = this.Bar(frame, x, y, 10.0, 10.0);
    r.SetRenderTransformPivot(Vector2(0.5, 0.5));
    r.SetRotation(45.0);
    r.SetOpacity(0.7);
  }

  // six slanted bars in the accent colour
  private func Hazard(frame: ref<inkCompoundWidget>, x: Float, y: Float) -> Void {
    let k = 0;
    while k < 6 {
      let r: ref<inkRectangle> = new inkRectangle();
      r.SetSize(Vector2(12.0, 26.0));
      r.SetMargin(inkMargin(x + Cast<Float>(k) * 26.0, y, 0.0, 0.0));
      r.SetRenderTransformPivot(Vector2(0.5, 0.5));
      r.SetRotation(35.0);
      r.SetOpacity(0.85);
      r.Reparent(frame);
      this.m_view.Chrome(r, "accent");
      ArrayPush(this.m_hideable, r);
      k += 1;
    }
  }

  // a line from (x1, y1) to (x2, y2) in the frame colour
  private func Diag(frame: ref<inkCompoundWidget>, x1: Float, y1: Float, x2: Float, y2: Float) -> Void {
    let dx = x2 - x1;
    let dy = y2 - y1;
    let len = SqrtF(dx * dx + dy * dy);
    let r = this.Bar(frame, (x1 + x2) / 2.0 - len / 2.0, (y1 + y2) / 2.0 - 2.0, len, 4.0);
    r.SetRenderTransformPivot(Vector2(0.5, 0.5));
    r.SetRotation(Rad2Deg(AtanF(dy, dx)));
  }

  // HUD corner brackets
  private func Brackets(frame: ref<inkCompoundWidget>) -> Void {
    let len: Float = 120.0;
    let t: Float = 4.0;
    let w = this.FrameWidth();
    let h = this.FrameHeight();
    this.Bar(frame, 0.0, 0.0, len, t);
    this.Bar(frame, 0.0, 0.0, t, len);
    this.Bar(frame, w - len, 0.0, len, t);
    this.Bar(frame, w - t, 0.0, t, len);
    this.Bar(frame, 0.0, h - t, len, t);
    this.Bar(frame, 0.0, h - len, t, len);
    this.Bar(frame, w - len, h - t, len, t);
    this.Bar(frame, w - t, h - len, t, len);
  }

  private func Bar(frame: ref<inkCompoundWidget>, x: Float, y: Float, w: Float, h: Float) -> ref<inkRectangle> {
    let r: ref<inkRectangle> = new inkRectangle();
    r.SetSize(Vector2(w, h));
    r.SetMargin(inkMargin(x, y, 0.0, 0.0));
    r.SetOpacity(0.8);
    r.Reparent(frame);
    this.m_view.Chrome(r, "frame");
    ArrayPush(this.m_hideable, r);
    return r;
  }

  // Bare pages (placing something in the world) show only their own controls: no
  // frame, no lens tint, no background blur, so the world behind stays in view
  public func SetBare(bare: Bool) -> Void {
    if Equals(bare, this.m_bare) {
      return;
    }
    this.m_bare = bare;
    for w in this.m_hideable {
      w.SetVisible(!bare);
    }
    let lens = this.Lens() && !bare;
    this.m_lens.SetVisible(lens);
    this.m_vignette.SetVisible(lens);
    if bare {
      this.ResetBackgroundBlur();
    } else {
      this.SetBackgroundBlur();
    }
  }

  // ---------------------------------------------------------------------------
  // Boot: the frame flickers on and settles from a slight zoom, then the boot
  // line fades out
  // ---------------------------------------------------------------------------
  protected cb func OnShow() -> Void {
    super.OnShow();
    let flicker: ref<inkAnimDef> = new inkAnimDef();
    TKPopup.Fade(flicker, 0.0, 0.7, 0.05, 0.0);
    TKPopup.Fade(flicker, 0.7, 0.15, 0.05, 0.05);
    TKPopup.Fade(flicker, 0.15, 1.0, 0.18, 0.10);
    let zoom: ref<inkAnimScale> = new inkAnimScale();
    zoom.SetStartScale(Vector2(1.04, 1.04));
    zoom.SetEndScale(Vector2(1.0, 1.0));
    zoom.SetDuration(0.3);
    zoom.SetType(inkanimInterpolationType.Quadratic);
    zoom.SetMode(inkanimInterpolationMode.EasyOut);
    flicker.AddInterpolator(zoom);
    this.m_frame.PlayAnimation(flicker);

    let n = ArraySize(this.m_bootLines);
    let stay = this.BootSeconds() > 0.0 ? this.BootSeconds() : (n > 0 ? 0.6 + 0.3 * Cast<Float>(n) : 0.9);
    let boot: ref<inkAnimDef> = new inkAnimDef();
    TKPopup.Fade(boot, 1.0, 0.0, 0.4, stay);
    this.m_bootProxy = this.m_boot.PlayAnimation(boot);
    // several lines: each comes up in turn, then they all go together
    let step = n > 0 ? (stay - 0.2) / Cast<Float>(n) : 0.0;
    let i = 0;
    while i < n {
      let line: ref<inkAnimDef> = new inkAnimDef();
      TKPopup.Fade(line, 0.0, 1.0, 0.08, 0.1 + step * Cast<Float>(i));
      TKPopup.Fade(line, 1.0, 0.0, 0.4, stay);
      this.m_bootLines[i].PlayAnimation(line);
      i += 1;
    }
  }

  public static func Fade(def: ref<inkAnimDef>, from: Float, to: Float, duration: Float, delay: Float) -> Void {
    let a: ref<inkAnimTransparency> = new inkAnimTransparency();
    a.SetStartTransparency(from);
    a.SetEndTransparency(to);
    a.SetDuration(duration);
    a.SetStartDelay(delay);
    def.AddInterpolator(a);
  }

  // ---------------------------------------------------------------------------
  // Input
  // ---------------------------------------------------------------------------
  // the mouse wheel anywhere scrolls the page (a row that takes the wheel reserves it)
  protected cb func OnFrameRelative(e: ref<inkPointerEvent>) -> Bool {
    if IsDefined(this.m_view) && !IsDefined(this.m_regions) {   // regions scroll under the cursor only
      this.m_view.OnWheel(e);
    }
    return false;
  }

  // the right mouse button goes back to the page before (closing a dialog or
  // a drop-down list first)
  protected cb func OnFramePress(e: ref<inkPointerEvent>) -> Bool {
    if IsDefined(this.m_view) && RedFunc.MouseButton(2) && !e.IsAction(n"click") && !e.IsAction(n"mouse_left") {
      if !this.m_rightDown {
        if !this.m_view.CloseOverlay() {
          this.m_view.Back();
        }
      }
      this.m_rightDown = true;
    } else {
      this.m_rightDown = false;   // any other press (Esc included) clears it
    }
    return false;
  }

  // the right mouse button is also bound to "cancel", which closes the popup on
  // release: that release belongs to the back step; Esc still closes
  protected cb func OnGlobalReleaseInput(evt: ref<inkPointerEvent>) -> Bool {
    if this.m_rightDown && (evt.IsAction(this.m_closeAction) || !RedFunc.MouseButton(2)) {
      this.m_rightDown = false;
      evt.Handle();
      return true;
    }
    return super.OnGlobalReleaseInput(evt);
  }

  protected cb func OnHidden() -> Void {
    this.UnregisterFromGlobalInputCallback(n"OnPostOnRelative", this, n"OnFrameRelative");
    this.UnregisterFromGlobalInputCallback(n"OnPostOnPress", this, n"OnFramePress");
    if IsDefined(this.m_view) {
      this.m_view.StopCustom();
      this.m_view.StopLive();
    }
    if IsDefined(this.m_regions) {
      this.m_regions.Stop();
    }
    this.Closing();
    TKScale.Activate(null);
    TKInk.UseFont("", n"");
    super.OnHidden();
    this.Closed();
  }
}

// what the view needs from the frame
public class TKPopupFrame extends TKFrame {
  public let popup: wref<TKPopup>;
  public func Owner() -> ref<inkCustomController> {
    let owner: ref<TKPopup> = this.popup;
    return owner;
  }
  public func SetBare(bare: Bool) -> Void {
    if IsDefined(this.popup) {
      this.popup.SetBare(bare);
    }
  }
}
