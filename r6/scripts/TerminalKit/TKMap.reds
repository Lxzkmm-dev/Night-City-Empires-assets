// =============================================================================
// TERMINAL KIT - THE MAP
// A pan-and-zoom map on a page, drawn from your own images:
//   - a base image of the whole map, and optional tile layers that fill in as
//     you zoom (a grid of images per level, created as they come into view);
//   - regions: outlines (rotated bars), a name, an optional tint image, click
//     to select;
//   - pins: a diamond (or a square) in a colour, a letter in it, a name beside
//     it, click to open a page; pins in a group can be switched off;
//   - the player's marker, zoom and find-me buttons, your toggles, a legend.
// Drag with the left or middle mouse button, scroll to zoom on the cursor.
//
// Describe it with a TKMapSpec and draw it from your content provider's
// Custom row:
//   let s = TKMapSpec.Make(-3600.0, 3800.0, 7400.0);     // west, north, metres across
//   s.base = "mymod\\ui\\map\\base.inkatlas";
//   s.AddLayer(2.0, 8, "mymod\\ui\\map\\t1\\%C_%R.inkatlas", n"t", "");
//   let r = s.AddRegion("watson", "Watson", color); r.AddRing(points);
//   s.AddPin(x, y, "S", "Stash", color, "network~12", "own");
//   s.View(zoom, mode, x, y, selected, "mappage~%D|%Z|%M|%X|%Y");
//   return TKMap.Place(v, parent, s, 1630.0, 1060.0);
// A new view (zoom, select, toggle) redraws the page through the link (%D the
// selected region, %Z zoom, %M the toggle bits, %X / %Y the world spot in the
// middle); a drag only updates the page's arg.
// =============================================================================
module TerminalKit

import Codeware.UI.*
import RedFunctions.*

public class TKMapRegion extends IScriptable {
  public let id: String;
  public let name: String;
  public let color: HDRColor;
  public let tint: Bool;              // its tint image shows (when the tint toggle is on)
  public let surround: Bool;          // it surrounds others: clicks find it last
  public let rings: array<Float>;     // x, y, x, y ... (world)
  public let ringEnds: array<Int32>;  // where each ring ends in `rings`
  public let label: Vector2;          // where its name goes (world)
  public let hasLabel: Bool;
  public let maskAtlas: String;       // the tint image ("" = none) and the world rectangle it covers
  public let maskPart: CName;
  public let maskRect: Vector4;       // x west, y north, width, height (metres)

  public func AddRing(points: array<Float>) -> Void {
    for f in points {
      ArrayPush(this.rings, f);
    }
    ArrayPush(this.ringEnds, ArraySize(this.rings));
  }
  public func Label(x: Float, y: Float) -> Void {
    this.label = Vector2(x, y);
    this.hasLabel = true;
  }
  public func Mask(atlas: String, part: CName, west: Float, north: Float, width: Float, height: Float) -> Void {
    this.maskAtlas = atlas;
    this.maskPart = part;
    this.maskRect = Vector4(west, north, width, height);
  }
}

public class TKMapPin extends IScriptable {
  public let x: Float;
  public let y: Float;
  public let letter: String;
  public let label: String;
  public let color: HDRColor;
  public let link: String;            // "page" or "page~arg" ("" = not clickable)
  public let group: String;           // a toggle can hide a group
  public let square: Bool;            // a square instead of a diamond
  public let faint: Bool;             // smaller and see-through (a site for sale)
  public let id: String;              // a name to move it by (TKMap.MovePin)
  public let ring: Float;             // a dashed circle this many metres around it (0 = none)
  public let iconAtlas: String;       // an image instead of the diamond ("" = the diamond)
  public let iconPart: CName;
  public let follow: String;          // a TKPins pin it follows while the map is open

  public func Ring(metres: Float) -> ref<TKMapPin> { this.ring = metres; return this; }
  public func Icon(atlas: String, part: String) -> ref<TKMapPin> { this.iconAtlas = atlas; this.iconPart = StringToName(part); return this; }
  public func Named(id: String) -> ref<TKMapPin> { this.id = id; return this; }
  // keeps to the TKPins pin `key` (its position checked twice a second)
  public func Follow(key: String) -> ref<TKMapPin> { this.follow = key; return this; }
}

public class TKMapLayer extends IScriptable {
  public let minZoom: Float;
  public let grid: Int32;             // n x n tiles
  public let path: String;            // atlas path, %C column and %R row
  public let part: CName;
  public let exists: String;          // "" = every tile, else "0110..." row by row
  public let head: String;            // the path split around %C and %R (AddLayer)
  public let middle: String;
  public let tail: String;

  // "...\t1\%C_%R.inkatlas" -> head "...\t1\", middle "_", tail ".inkatlas"
  public func Split() -> Void {
    this.head = StrBeforeFirst(this.path, "%C");
    let rest = StrAfterFirst(this.path, "%C");
    this.middle = StrBeforeFirst(rest, "%R");
    this.tail = StrAfterFirst(rest, "%R");
  }

  // the tile at column c, row r: the path put together piece by piece
  public func Tile(c: Int32, r: Int32) -> String = this.head + IntToString(c) + this.middle + IntToString(r) + this.tail
}

public class TKMapToggle extends IScriptable {
  public let bit: Int32;              // its bit in the mode (on = the bit clear)
  public let offLabel: String;        // shown while on ("HIDE TINT")
  public let onLabel: String;         // shown while off ("SHOW TINT")
  public let target: String;          // "tint" or a pin group
}

public class TKMapLegendItem extends IScriptable {
  public let label: String;
  public let color: HDRColor;
  public let square: Bool;
  public let faint: Bool;
}

public class TKMapSpec extends IScriptable {
  // the map square, world units
  public let west: Float;
  public let north: Float;
  public let span: Float;
  public let zooms: array<Float>;
  public let base: String;            // the whole map's atlas
  public let basePart: CName;
  public let layers: array<ref<TKMapLayer>>;
  public let regions: array<ref<TKMapRegion>>;
  public let pins: array<ref<TKMapPin>>;
  public let toggles: array<ref<TKMapToggle>>;
  public let legend: array<ref<TKMapLegendItem>>;
  public let legendTitle: String;
  public let legendHint: String;
  // the view
  public let zoom: Float;
  public let mode: Int32;
  public let centreX: Float;
  public let centreY: Float;
  public let selected: String;
  public let link: String;
  // looks
  public let showPlayer: Bool;
  public let playerLabel: String;
  public let findLabel: String;       // "" = no find button
  public let tintOpacity: Float;
  public let selectedTint: Float;
  public let buttonW: Float;
  public let buttonH: Float;
  public let buttonFont: Int32;
  public let clickAction: String;     // a click on open map calls Act(this, "x|y") in world metres ("" = none)

  public static func Make(west: Float, north: Float, span: Float) -> ref<TKMapSpec> {
    let s = new TKMapSpec();
    s.west = west;
    s.north = north;
    s.span = span;
    s.zooms = [1.0, 2.0, 4.0, 8.0, 16.0, 32.0];
    s.basePart = n"city";
    s.zoom = 1.0;
    s.showPlayer = true;
    s.playerLabel = "V";
    s.findLabel = "FIND V";
    s.tintOpacity = 0.075;
    s.selectedTint = 0.14;
    s.legendTitle = "PINS";
    s.legendHint = "CLICK A PIN TO OPEN IT";
    s.buttonW = 180.0;
    s.buttonH = 56.0;
    s.buttonFont = 26;
    return s;
  }

  public func AddLayer(minZoom: Float, grid: Int32, path: String, part: CName, exists: String) -> ref<TKMapLayer> {
    let l = new TKMapLayer();
    l.minZoom = minZoom; l.grid = grid; l.path = path; l.part = part; l.exists = exists;
    l.Split();
    ArrayPush(this.layers, l);
    return l;
  }

  public func AddRegion(id: String, name: String, color: HDRColor) -> ref<TKMapRegion> {
    let r = new TKMapRegion();
    r.id = id; r.name = name; r.color = color; r.tint = true;
    ArrayPush(this.regions, r);
    return r;
  }

  public func AddPin(x: Float, y: Float, letter: String, label: String, color: HDRColor, link: String, group: String) -> ref<TKMapPin> {
    let p = new TKMapPin();
    p.x = x; p.y = y; p.letter = letter; p.label = label; p.color = color; p.link = link; p.group = group;
    ArrayPush(this.pins, p);
    return p;
  }

  public func AddToggle(bit: Int32, offLabel: String, onLabel: String, target: String) -> Void {
    let t = new TKMapToggle();
    t.bit = bit; t.offLabel = offLabel; t.onLabel = onLabel; t.target = target;
    ArrayPush(this.toggles, t);
  }

  public func AddLegend(label: String, color: HDRColor, square: Bool, faint: Bool) -> Void {
    let l = new TKMapLegendItem();
    l.label = label; l.color = color; l.square = square; l.faint = faint;
    ArrayPush(this.legend, l);
  }

  // a left click on the map (not on a pin) calls Act(action, "x|y"), the spot in
  // world metres, instead of selecting a region
  public func OnClick(action: String) -> Void { this.clickAction = action; }

  public func View(zoom: Float, mode: Int32, x: Float, y: Float, selected: String, link: String) -> Void {
    this.zoom = zoom; this.mode = mode; this.centreX = x; this.centreY = y; this.selected = selected; this.link = link;
  }

  // a toggle's state: on unless its bit is set in the mode
  public func On(target: String) -> Bool {
    for t in this.toggles {
      if Equals(t.target, target) {
        return (this.mode / t.bit) % 2 == 0;
      }
    }
    return true;
  }
}

public class TKMap extends TKCustom {
  private let m_view: wref<TKView>;
  private let m_owner: wref<inkCustomController>;   // the frame's global mouse input (dragging)
  private let m_spec: ref<TKMapSpec>;
  private let m_clip: wref<inkWidget>;
  private let m_map: wref<inkCanvas>;
  private let m_layers: array<wref<inkCanvas>>;
  private let m_have: array<String>;                 // per layer: "0"/"1" per tile made
  private let m_buttons: array<ref<TKButton>>;
  private let m_viewW: Float;
  private let m_viewH: Float;
  private let m_size: Float;         // the map square's side on screen at this zoom
  private let m_zoom: Float;
  private let m_mode: Int32;
  private let m_dragging: Bool;
  private let m_button: Int32;       // the button dragging: 1 left, 3 middle
  private let m_moved: Bool;
  private let m_pressHooked: Bool;
  private let m_dragHooked: Bool;
  private let m_dragStart: Vector2;
  private let m_dragFrom: Vector2;
  private let m_pinAt: array<Vector2>;
  private let m_pinLinks: array<String>;
  private let m_pinIds: array<String>;
  private let m_pinFollow: array<String>;
  private let m_pinHolders: array<wref<inkCanvas>>;
  private let m_followGen: Int32;

  // centred on the page, `w` x `h` (narrowed to the page), its height counted for scrolling
  public static func Place(v: ref<TKView>, parent: ref<inkCompoundWidget>, spec: ref<TKMapSpec>, w: Float, h: Float) -> ref<TKMap> {
    let width = MinF(w, v.RowWidth());
    let strip = TKInk.Strip(parent, 6.0);
    strip.SetMargin(inkMargin(MaxF(0.0, (v.RowWidth() - width) / 2.0), 6.0, 0.0, 0.0));
    v.Grew(h + 12.0);
    return TKMap.Create(v, v.Owner(), strip, width, h, spec, v.Theme());
  }

  public static func Create(view: ref<TKView>, owner: ref<inkCustomController>, parent: ref<inkCompoundWidget>, viewW: Float, viewH: Float,
      spec: ref<TKMapSpec>, theme: String) -> ref<TKMap> {
    let m = new TKMap();
    m.m_view = view;
    m.m_owner = owner;
    m.m_spec = spec;
    m.m_viewW = viewW;
    m.m_viewH = viewH;
    m.m_zoom = m.Snap(spec.zoom);
    m.m_mode = spec.mode;
    m.m_size = MaxF(viewW, viewH) * m.m_zoom;
    m.Build(parent, theme);
    m.HookPress(true);
    return m;
  }

  // ---- world to map pixels and back ----
  public func ToPx(x: Float, y: Float) -> Vector2 = this.ToPxAt(x, y, this.m_size)
  private func ToPxAt(x: Float, y: Float, size: Float) -> Vector2 {
    return Vector2((x - this.m_spec.west) / this.m_spec.span * size, (this.m_spec.north - y) / this.m_spec.span * size);
  }
  private func ToWorld(p: Vector2, size: Float) -> Vector2 {
    return Vector2(this.m_spec.west + p.X / size * this.m_spec.span, this.m_spec.north - p.Y / size * this.m_spec.span);
  }

  private func Level(z: Float) -> Int32 {
    let levels = this.m_spec.zooms;
    let best = 0;
    let i = 1;
    while i < ArraySize(levels) {
      if AbsF(levels[i] - z) < AbsF(levels[best] - z) {
        best = i;
      }
      i += 1;
    }
    return best;
  }
  private func Snap(z: Float) -> Float = ArraySize(this.m_spec.zooms) > 0 ? this.m_spec.zooms[this.Level(z)] : 1.0

  private func ToggleOn(target: String) -> Bool {
    for t in this.m_spec.toggles {
      if Equals(t.target, target) {
        return (this.m_mode / t.bit) % 2 == 0;
      }
    }
    return true;
  }

  // ---- building ----
  private func Build(parent: ref<inkCompoundWidget>, theme: String) -> Void {
    let s = this.m_spec;
    let w = this.m_viewW;
    let h = this.m_viewH;
    let size = this.m_size;
    let box: ref<inkCanvas> = new inkCanvas();
    box.SetSize(Vector2(w, h));
    box.Reparent(parent);

    // the viewport: anything outside it is clipped
    let clip: ref<inkScrollArea> = new inkScrollArea();
    clip.SetAnchor(inkEAnchor.TopLeft);
    clip.SetAnchorPoint(Vector2(0.0, 0.0));
    clip.SetRenderTransformPivot(Vector2(0.0, 0.0));
    clip.SetFitToContentDirection(inkFitToContentDirection.None);
    clip.SetConstrainContentPosition(true);
    clip.SetUseInternalMask(true);
    clip.SetSize(Vector2(w, h));
    clip.Reparent(box);
    this.m_clip = clip;

    let map: ref<inkCanvas> = new inkCanvas();
    map.SetAnchor(inkEAnchor.TopLeft);
    map.SetAnchorPoint(Vector2(0.0, 0.0));
    map.SetRenderTransformPivot(Vector2(0.0, 0.0));
    map.SetSize(Vector2(size, size));
    map.Reparent(clip);
    this.m_map = map;
    let focus = this.ToPx(s.centreX, s.centreY);
    map.SetTranslation(this.Keep(Vector2(w / 2.0 - focus.X, h / 2.0 - focus.Y)));

    // the whole map, then the tile layers over it
    if StrLen(s.base) > 0 {
      this.Picture(map, s.base, s.basePart, 0.0, 0.0, size);
    }
    for l in s.layers {
      let layer: ref<inkCanvas> = new inkCanvas();
      layer.SetAnchor(inkEAnchor.TopLeft);
      layer.SetSize(Vector2(size, size));
      layer.Reparent(map);
      ArrayPush(this.m_layers, layer);
      ArrayPush(this.m_have, "");
    }

    // regions: tints, outlines (the selected one last, on top), names
    let deep = this.m_zoom >= 15.9 ? 0.75 : 1.0;   // tint edges soften up close
    for r in s.regions {
      if r.tint && this.ToggleOn("tint") && StrLen(r.maskAtlas) > 0 {
        this.Tint(map, r, (Equals(r.id, s.selected) ? s.selectedTint : s.tintOpacity) * deep);
      }
    }
    let top: ref<TKMapRegion>;
    for r in s.regions {
      if Equals(r.id, s.selected) {
        top = r;
      } else {
        this.Outline(map, r, 2.0, 0.85);
      }
    }
    if IsDefined(top) {
      this.Outline(map, top, 4.0, 1.0);
    }
    for r in s.regions {
      if r.hasLabel {
        this.Label(map, r, Equals(r.id, s.selected));
      }
    }
    this.Pins(map);
    if s.showPlayer {
      this.Player(map);
    }
    this.EnsureTiles();

    // mouse input: a see-through layer over the whole view
    let catcher: ref<inkCanvas> = new inkCanvas();
    catcher.SetSize(Vector2(w, h));
    catcher.SetInteractive(true);
    catcher.Reparent(box);
    catcher.RegisterToCallback(n"OnPress", this, n"OnMapPress");
    catcher.RegisterToCallback(n"OnRelease", this, n"OnMapRelease");
    catcher.RegisterToCallback(n"OnRelative", this, n"OnMapRelative");

    // the map's own buttons, top right over the map
    let bar: ref<inkVerticalPanel> = new inkVerticalPanel();
    bar.SetAnchor(inkEAnchor.TopRight);
    bar.SetAnchorPoint(Vector2(1.0, 0.0));
    bar.SetMargin(inkMargin(0.0, 20.0, 20.0, 0.0));
    bar.Reparent(box);
    this.MapButton(bar, "ZOOM +", "zoom_in", theme);
    this.MapButton(bar, "ZOOM -", "zoom_out", theme);
    if s.showPlayer && StrLen(s.findLabel) > 0 {
      this.MapButton(bar, s.findLabel, "find", theme);
    }
    let k = 0;
    for t in s.toggles {
      this.MapButton(bar, this.ToggleOn(t.target) ? t.offLabel : t.onLabel, "tog" + IntToString(k), theme);
      k += 1;
    }
    if ArraySize(s.legend) > 0 {
      this.Legend(box, h, theme);
    }

    // a thin frame around the viewport
    let edges = [Vector4(0.0, 0.0, w, 2.0), Vector4(0.0, h - 2.0, w, 2.0), Vector4(0.0, 0.0, 2.0, h), Vector4(w - 2.0, 0.0, 2.0, h)];
    for e in edges {
      let r: ref<inkRectangle> = new inkRectangle();
      r.SetMargin(inkMargin(e.X, e.Y, 0.0, 0.0));
      r.SetSize(Vector2(e.Z, e.W));
      r.Reparent(box);
      TKTheme.PaintNew(r, theme, "frame");
    }
  }

  private func Picture(parent: ref<inkCanvas>, atlas: String, part: CName, x: Float, y: Float, size: Float) -> Void {
    let img: ref<inkImage> = new inkImage();
    img.SetAtlasResource(ResRef.FromString(atlas));
    img.SetTexturePart(part);
    img.SetAnchor(inkEAnchor.TopLeft);
    img.SetMargin(inkMargin(x, y, 0.0, 0.0));
    img.SetSize(Vector2(size, size));
    img.Reparent(parent);
  }

  // a button over the map, named "tk_map_<cmd>"
  private func MapButton(bar: ref<inkVerticalPanel>, label: String, cmd: String, theme: String) -> Void {
    let s = this.m_spec;
    let b = TKButton.Make(bar, label, "tk_map_" + cmd, TKScale.F("map.button.w", s.buttonW), TKScale.F("map.button.h", s.buttonH), TKScale.I("map.button.font", s.buttonFont));
    b.GetRootWidget().SetMargin(inkMargin(0.0, 0.0, 0.0, 10.0));
    b.RegisterToCallback(n"OnBtnClick", this, n"OnMapButton");
    TKTheme.Paint(b.GetLabel(), theme, "value");
    ArrayPush(this.m_buttons, b);
  }

  protected cb func OnMapButton(widget: wref<inkWidget>) -> Bool {
    this.Command(StrAfterFirst(NameToString(widget.GetName()), "tk_map_"));
    return true;
  }

  // the map's offset clamped so it always covers the view
  private func Keep(t: Vector2) -> Vector2 {
    return Vector2(ClampF(t.X, this.m_viewW - this.m_size, 0.0), ClampF(t.Y, this.m_viewH - this.m_size, 0.0));
  }

  private func Centre() -> Vector2 {
    let t = IsDefined(this.m_map) ? this.m_map.GetTranslation() : Vector2(0.0, 0.0);
    return this.ToWorld(Vector2(this.m_viewW / 2.0 - t.X, this.m_viewH / 2.0 - t.Y), this.m_size);
  }

  // ---- tiles: every tile of the zoom's layers in or near the view ----
  private func EnsureTiles() -> Void {
    if !IsDefined(this.m_map) {
      return;
    }
    let t = this.m_map.GetTranslation();
    let margin = MaxF(this.m_viewW, this.m_viewH) * 0.25;
    let x0 = -t.X - margin;
    let y0 = -t.Y - margin;
    let x1 = -t.X + this.m_viewW + margin;
    let y1 = -t.Y + this.m_viewH + margin;
    let i = 0;
    while i < ArraySize(this.m_spec.layers) {
      if this.m_zoom >= this.m_spec.layers[i].minZoom - 0.1 {
        this.Cover(i, x0, y0, x1, y1);
      }
      i += 1;
    }
  }

  private func Cover(i: Int32, x0: Float, y0: Float, x1: Float, y1: Float) -> Void {
    let l = this.m_spec.layers[i];
    let n = Max(1, l.grid);
    if StrLen(this.m_have[i]) != n * n {
      let blank = "";
      let k = 0;
      while k < n * n {
        blank += "0";
        k += 1;
      }
      this.m_have[i] = blank;
    }
    let ts = this.m_size / Cast<Float>(n);
    let c0 = Max(0, Cast<Int32>(x0 / ts));
    let c1 = Min(n - 1, Cast<Int32>(x1 / ts));
    let r0 = Max(0, Cast<Int32>(y0 / ts));
    let r1 = Min(n - 1, Cast<Int32>(y1 / ts));
    let r = r0;
    while r <= r1 {
      let c = c0;
      while c <= c1 {
        let k = r * n + c;
        if Equals(StrMid(this.m_have[i], k, 1), "0") && (StrLen(l.exists) == 0 || Equals(StrMid(l.exists, k, 1), "1")) {
          // a hair of overlap: no seams
          this.Picture(this.m_layers[i], l.Tile(c, r), l.part, Cast<Float>(c) * ts, Cast<Float>(r) * ts, ts + 1.0);
          this.m_have[i] = StrLeft(this.m_have[i], k) + "1" + StrRight(this.m_have[i], n * n - k - 1);
        }
        c += 1;
      }
      r += 1;
    }
  }

  // ---- regions ----
  private func Tint(map: ref<inkCanvas>, r: ref<TKMapRegion>, opacity: Float) -> Void {
    let m = r.maskRect;
    if m.Z <= 0.0 {
      return;
    }
    let at = this.ToPx(m.X, m.Y);
    let img: ref<inkImage> = new inkImage();
    img.SetAtlasResource(ResRef.FromString(r.maskAtlas));
    img.SetTexturePart(r.maskPart);
    img.SetAnchor(inkEAnchor.TopLeft);
    img.SetMargin(inkMargin(at.X, at.Y, 0.0, 0.0));
    img.SetSize(Vector2(m.Z / this.m_spec.span * this.m_size, m.W / this.m_spec.span * this.m_size));
    img.SetTintColor(r.color);
    img.SetOpacity(opacity);
    img.Reparent(map);
  }

  // one bar per edge of each ring
  private func Outline(map: ref<inkCanvas>, r: ref<TKMapRegion>, thick: Float, opacity: Float) -> Void {
    let start = 0;
    for end in r.ringEnds {
      let k = start;
      while k + 1 < end {
        let next = k + 2 < end ? k + 2 : start;   // the last point closes the ring
        TKMap.Edge(map, this.ToPx(r.rings[k], r.rings[k + 1]), this.ToPx(r.rings[next], r.rings[next + 1]), thick, r.color, opacity);
        k += 2;
      }
      start = end;
    }
  }

  // a bar from a to b, a little longer so neighbouring bars meet at the corner
  private static func Edge(map: ref<inkCanvas>, a: Vector2, b: Vector2, t: Float, color: HDRColor, opacity: Float) -> Void {
    let dx = b.X - a.X;
    let dy = b.Y - a.Y;
    let len = SqrtF(dx * dx + dy * dy);
    if len < 0.5 {
      return;
    }
    let w = len + t;
    let bar: ref<inkRectangle> = new inkRectangle();
    bar.SetAnchor(inkEAnchor.TopLeft);
    bar.SetAnchorPoint(Vector2(0.0, 0.0));
    bar.SetRenderTransformPivot(Vector2(0.5, 0.5));
    bar.SetSize(Vector2(w, t));
    bar.SetMargin(inkMargin((a.X + b.X) / 2.0 - w / 2.0, (a.Y + b.Y) / 2.0 - t / 2.0, 0.0, 0.0));
    bar.SetRotation(Rad2Deg(AtanF(dy, dx)));   // positive turns clockwise on screen
    bar.SetTintColor(color);
    bar.SetOpacity(opacity);
    bar.Reparent(map);
  }

  private func Label(map: ref<inkCanvas>, r: ref<TKMapRegion>, selected: Bool) -> Void {
    let at = this.ToPx(r.label.X, r.label.Y);
    let font = selected ? 36 : 26;
    let t = TKInk.Tinted(map, StrUpper(r.name), font, n"Semi-Bold", r.color, 0.0);
    t.SetMargin(inkMargin(at.X - Cast<Float>(StrLen(r.name) * font) * 0.28, at.Y - Cast<Float>(font) * 0.7, 0.0, 0.0));
    t.SetOpacity(selected ? 1.0 : 0.85);
  }

  // the player: a white diamond with a dark rim and a label
  private func Player(map: ref<inkCanvas>) -> Void {
    let player = GetPlayer(GetGameInstance());
    if !IsDefined(player) {
      return;
    }
    let pos = player.GetWorldPosition();
    let at = this.ToPx(pos.X, pos.Y);
    if at.X < 0.0 || at.Y < 0.0 || at.X > this.m_size || at.Y > this.m_size {
      return;
    }
    let rim: ref<inkRectangle> = new inkRectangle();
    rim.SetSize(Vector2(26.0, 26.0));
    rim.SetMargin(inkMargin(at.X - 13.0, at.Y - 13.0, 0.0, 0.0));
    rim.SetRenderTransformPivot(Vector2(0.5, 0.5));
    rim.SetRotation(45.0);
    rim.SetTintColor(new HDRColor(0.02, 0.05, 0.08, 1.0));
    rim.Reparent(map);
    let dot: ref<inkRectangle> = new inkRectangle();
    dot.SetSize(Vector2(16.0, 16.0));
    dot.SetMargin(inkMargin(at.X - 8.0, at.Y - 8.0, 0.0, 0.0));
    dot.SetRenderTransformPivot(Vector2(0.5, 0.5));
    dot.SetRotation(45.0);
    dot.SetTintColor(new HDRColor(1.0, 1.0, 1.0, 1.0));
    dot.Reparent(map);
    let v = TKInk.Tinted(map, this.m_spec.playerLabel, 30, n"Semi-Bold", new HDRColor(1.0, 1.0, 1.0, 1.0), 0.0);
    v.SetMargin(inkMargin(at.X + 16.0, at.Y - 22.0, 0.0, 0.0));
  }

  // ---- pins ----
  private func Pins(map: ref<inkCanvas>) -> Void {
    ArrayClear(this.m_pinAt);
    ArrayClear(this.m_pinLinks);
    ArrayClear(this.m_pinIds);
    ArrayClear(this.m_pinFollow);
    ArrayClear(this.m_pinHolders);
    let following = false;
    for p in this.m_spec.pins {
      if StrLen(p.group) == 0 || this.ToggleOn(p.group) {
        let at = this.ToPx(p.x, p.y);
        // each pin in its own holder at its spot, so it can move without a redraw
        let holder: ref<inkCanvas> = new inkCanvas();
        holder.SetAnchor(inkEAnchor.TopLeft);
        holder.SetSize(Vector2(0.0, 0.0));
        holder.SetMargin(inkMargin(at.X, at.Y, 0.0, 0.0));
        holder.Reparent(map);
        if p.ring > 0.0 {
          this.RingAround(holder, p.ring / this.m_spec.span * this.m_size, p.color);
        }
        this.Pin(holder, Vector2(0.0, 0.0), p);
        ArrayPush(this.m_pinAt, at);
        ArrayPush(this.m_pinLinks, p.link);
        ArrayPush(this.m_pinIds, p.id);
        ArrayPush(this.m_pinFollow, p.follow);
        ArrayPush(this.m_pinHolders, holder);
        if StrLen(p.follow) > 0 {
          following = true;
        }
      }
    }
    if following {
      this.m_followGen += 1;
      this.FollowStep(this.m_followGen);
    }
  }

  // a dashed circle `radius` map pixels around (0, 0)
  private func RingAround(holder: ref<inkCanvas>, radius: Float, color: HDRColor) -> Void {
    if radius < 4.0 {
      return;
    }
    let n = Clamp(RoundF(radius / 6.0), 16, 96);
    let k = 0;
    while k < n {
      if k % 2 == 0 {
        let a0 = 6.2831853 * Cast<Float>(k) / Cast<Float>(n);
        let a1 = 6.2831853 * Cast<Float>(k + 1) / Cast<Float>(n);
        TKInk.Seg(holder, Vector2(CosF(a0) * radius, SinF(a0) * radius), Vector2(CosF(a1) * radius, SinF(a1) * radius), 2.0, color, 0.9);
      }
      k += 1;
    }
  }

  // moves the pin named `id` to a world spot, without redrawing the map
  public func MovePin(id: String, x: Float, y: Float) -> Void {
    let i = 0;
    while i < ArraySize(this.m_pinIds) {
      if Equals(this.m_pinIds[i], id) {
        let at = this.ToPx(x, y);
        this.m_pinAt[i] = at;
        if IsDefined(this.m_pinHolders[i]) {
          this.m_pinHolders[i].SetMargin(inkMargin(at.X, at.Y, 0.0, 0.0));
        }
      }
      i += 1;
    }
  }

  // pins that follow a TKPins pin: checked twice a second while the map is up
  public func FollowStep(gen: Int32) -> Void {
    if gen != this.m_followGen || !IsDefined(this.m_map) {
      return;
    }
    let i = 0;
    while i < ArraySize(this.m_pinFollow) {
      let pos: Vector4;
      if StrLen(this.m_pinFollow[i]) > 0 && TKPins.Position(this.m_pinFollow[i], pos) {
        let at = this.ToPx(pos.X, pos.Y);
        this.m_pinAt[i] = at;
        if IsDefined(this.m_pinHolders[i]) {
          this.m_pinHolders[i].SetMargin(inkMargin(at.X, at.Y, 0.0, 0.0));
        }
      }
      i += 1;
    }
    let cb = new TKMapFollowTick();
    cb.map = this;
    cb.gen = gen;
    GameInstance.GetDelaySystem(GetGameInstance()).DelayCallback(cb, 0.5, false);
  }

  private func Pin(map: ref<inkCanvas>, at: Vector2, p: ref<TKMapPin>) -> Void {
    if StrLen(p.iconAtlas) > 0 {
      // the mod's own icon in the pin's colour, its name beside it
      let isize = p.faint ? 32.0 : 44.0;
      let img: ref<inkImage> = new inkImage();
      img.SetAtlasResource(ResRef.FromString(p.iconAtlas));
      img.SetTexturePart(p.iconPart);
      img.SetAnchor(inkEAnchor.TopLeft);
      img.SetSize(Vector2(isize, isize));
      img.SetMargin(inkMargin(at.X - isize / 2.0, at.Y - isize / 2.0, 0.0, 0.0));
      img.SetTintColor(p.color);
      img.Reparent(map);
      if StrLen(p.label) > 0 {
        let label = TKInk.Tinted(map, StrUpper(p.label), 24, n"Semi-Bold", p.color, 0.0);
        label.SetMargin(inkMargin(at.X + isize / 2.0 + 10.0, at.Y - 15.0, 0.0, 0.0));
      }
      return;
    }
    let faint = p.faint;
    let color = p.color;
    let dark = new HDRColor(0.02, 0.04, 0.06, 1.0);
    let turn = p.square ? 0.0 : 45.0;
    let size = faint ? 24.0 : 32.0;
    let rim: ref<inkRectangle> = new inkRectangle();
    rim.SetSize(Vector2(size + 8.0, size + 8.0));
    rim.SetMargin(inkMargin(at.X - (size + 8.0) / 2.0, at.Y - (size + 8.0) / 2.0, 0.0, 0.0));
    rim.SetRenderTransformPivot(Vector2(0.5, 0.5));
    rim.SetRotation(turn);
    rim.SetTintColor(faint ? color : dark);
    rim.SetOpacity(faint ? 0.8 : 0.9);
    rim.Reparent(map);
    let body: ref<inkRectangle> = new inkRectangle();
    body.SetSize(Vector2(size, size));
    body.SetMargin(inkMargin(at.X - size / 2.0, at.Y - size / 2.0, 0.0, 0.0));
    body.SetRenderTransformPivot(Vector2(0.5, 0.5));
    body.SetRotation(turn);
    body.SetTintColor(faint ? dark : color);
    body.SetOpacity(faint ? 0.85 : 1.0);
    body.Reparent(map);
    let font = faint ? 16 : 20;
    let t = TKInk.Tinted(map, p.letter, font, n"Semi-Bold", faint ? color : dark, 0.0);
    t.SetMargin(inkMargin(at.X - Cast<Float>(StrLen(p.letter) * font) * 0.3, at.Y - Cast<Float>(font) * 0.66, 0.0, 0.0));
    if StrLen(p.label) > 0 && (!faint || this.m_zoom >= 3.9) {
      let name = TKInk.Tinted(map, StrUpper(p.label), faint ? 20 : 24, n"Semi-Bold", color, 0.0);
      name.SetMargin(inkMargin(at.X + size / 2.0 + 12.0, at.Y - 15.0, 0.0, 0.0));
      name.SetOpacity(faint ? 0.75 : 1.0);
    }
  }

  // the pin nearest a spot on the map (map pixels), within reach of a click; -1 if none
  private func PinAt(p: Vector2) -> Int32 {
    let best = -1;
    let bestD = 24.0 * 24.0;
    let i = 0;
    while i < ArraySize(this.m_pinAt) {
      let dx = this.m_pinAt[i].X - p.X;
      let dy = this.m_pinAt[i].Y - p.Y;
      if dx * dx + dy * dy < bestD {
        best = i;
        bestD = dx * dx + dy * dy;
      }
      i += 1;
    }
    return best;
  }

  // what the pins mean, in the view's bottom left corner
  private func Legend(box: ref<inkCanvas>, h: Float, theme: String) -> Void {
    let s = this.m_spec;
    let rowH = 30.0;
    let w = 250.0;
    let lh = Cast<Float>(ArraySize(s.legend)) * rowH + 64.0;
    let panel: ref<inkCanvas> = new inkCanvas();
    panel.SetSize(Vector2(w, lh));
    panel.SetMargin(inkMargin(20.0, h - lh - 20.0, 0.0, 0.0));
    panel.Reparent(box);
    let bg: ref<inkRectangle> = new inkRectangle();
    bg.SetSize(Vector2(w, lh));
    bg.SetTintColor(new HDRColor(0.0, 0.0, 0.0, 1.0));
    bg.SetOpacity(0.6);
    bg.Reparent(panel);
    let title = TKInk.Plain(panel, s.legendTitle, 22, n"Semi-Bold", 0.0);
    title.SetMargin(inkMargin(16.0, 10.0, 0.0, 0.0));
    TKTheme.PaintNew(title, theme, "accent");
    let i = 0;
    for item in s.legend {
      let y = 44.0 + Cast<Float>(i) * rowH;
      let chip: ref<inkRectangle> = new inkRectangle();
      chip.SetSize(Vector2(14.0, 14.0));
      chip.SetMargin(inkMargin(20.0, y + 4.0, 0.0, 0.0));
      chip.SetRenderTransformPivot(Vector2(0.5, 0.5));
      chip.SetRotation(item.square ? 0.0 : 45.0);
      chip.SetTintColor(item.color);
      chip.SetOpacity(item.faint ? 0.5 : 1.0);
      chip.Reparent(panel);
      let t = TKInk.Tinted(panel, item.label, 20, n"Medium", item.color, 0.0);
      t.SetMargin(inkMargin(48.0, y, 0.0, 0.0));
      i += 1;
    }
    let hint = TKInk.Plain(panel, s.legendHint, 16, n"Regular", 0.0);
    hint.SetMargin(inkMargin(16.0, lh - 26.0, 0.0, 0.0));
    hint.SetOpacity(0.7);
    TKTheme.PaintNew(hint, theme, "text");
  }

  // the region at a world spot ("" for none): even-odd over its rings, surrounding regions last
  private func RegionAt(w: Vector2) -> String {
    let outer = "";
    for r in this.m_spec.regions {
      if TKMap.Inside(w, r) {
        if !r.surround {
          return r.id;
        }
        if StrLen(outer) == 0 {
          outer = r.id;
        }
      }
    }
    return outer;
  }

  private static func Inside(p: Vector2, r: ref<TKMapRegion>) -> Bool {
    let inside = false;
    let start = 0;
    for end in r.ringEnds {
      let j = end - 2;   // the ring's last point
      let k = start;
      while k + 1 < end {
        let ax = r.rings[k];
        let ay = r.rings[k + 1];
        let bx = r.rings[j];
        let by = r.rings[j + 1];
        if !Equals(ay > p.Y, by > p.Y) && p.X < (bx - ax) * (p.Y - ay) / (by - ay) + ax {
          inside = !inside;
        }
        j = k;
        k += 2;
      }
      start = end;
    }
    return inside;
  }

  // ---- the map's own buttons ----
  private func Command(cmd: String) -> Void {
    let centre = this.Centre();
    let levels = this.m_spec.zooms;
    let z = this.Level(this.m_zoom);
    if Equals(cmd, "zoom_in") {
      this.Go(levels[Min(z + 1, ArraySize(levels) - 1)], centre, this.m_spec.selected);
      return;
    }
    if Equals(cmd, "zoom_out") {
      this.Go(levels[Max(z - 1, 0)], centre, this.m_spec.selected);
      return;
    }
    if Equals(cmd, "find") {
      let player = GetPlayer(GetGameInstance());
      if IsDefined(player) {
        let pos = player.GetWorldPosition();
        this.Go(MaxF(this.m_zoom, 8.0), Vector2(pos.X, pos.Y), this.m_spec.selected);
      }
      return;
    }
    if StrBeginsWith(cmd, "tog") {
      let k = StringToInt(StrAfterFirst(cmd, "tog"), -1);
      if k >= 0 && k < ArraySize(this.m_spec.toggles) {
        let t = this.m_spec.toggles[k];
        this.m_mode += this.ToggleOn(t.target) ? t.bit : -t.bit;
        this.Go(this.m_zoom, centre, this.m_spec.selected);
      }
    }
  }

  private func Arg(zoom: Float, centre: Vector2, region: String) -> String {
    let target = this.m_spec.link;
    target = StrReplace(target, "%D", region);
    target = StrReplace(target, "%Z", FloatToString(zoom));
    target = StrReplace(target, "%M", IntToString(this.m_mode));
    target = StrReplace(target, "%X", IntToString(RoundF(centre.X)));
    target = StrReplace(target, "%Y", IntToString(RoundF(centre.Y)));
    return target;
  }

  private func Go(zoom: Float, centre: Vector2, region: String) -> Void {
    let target = this.Arg(zoom, centre, region);
    let view = this.m_view;
    if IsDefined(view) {
      view.Show(StrBeforeFirst(target, "~"), StrAfterFirst(target, "~"), "");
    }
  }

  // the page remembers the view without a redraw (after a drag)
  private func Remember() -> Void {
    let view = this.m_view;
    if IsDefined(view) {
      view.SetArg(StrAfterFirst(this.Arg(this.m_zoom, this.Centre(), this.m_spec.selected), "~"));
    }
  }

  // ---- mouse ----
  private func Cursor(e: ref<inkPointerEvent>) -> Vector2 {
    return WidgetUtils.GlobalToLocal(this.m_clip, e.GetScreenSpacePosition());
  }

  private func InView(p: Vector2) -> Bool {
    return p.X >= 0.0 && p.Y >= 0.0 && p.X <= this.m_viewW && p.Y <= this.m_viewH;
  }

  // the middle button has no fixed action name in every input context, so the
  // button itself is checked (RedFunctions)
  private static func Middle(e: ref<inkPointerEvent>) -> Bool {
    return RedFunc.MouseButton(3) || e.IsAction(n"UI_vehicle_customization_fake_slider_value") || e.IsAction(n"world_map_menu_zoom_to_mappin");
  }

  private static func Left(e: ref<inkPointerEvent>) -> Bool {
    return e.IsAction(n"mouse_left") || e.IsAction(n"click");
  }

  private func StartDrag(e: ref<inkPointerEvent>, button: Int32) -> Void {
    if this.m_dragging || !IsDefined(this.m_map) || !IsDefined(this.m_clip) {
      return;
    }
    this.m_dragging = true;
    this.m_button = button;
    this.m_moved = false;
    this.m_dragStart = this.Cursor(e);
    this.m_dragFrom = this.m_map.GetTranslation();
    this.HookDrag(true);
  }

  protected cb func OnMapPress(e: ref<inkPointerEvent>) -> Bool {
    if TKMap.Left(e) {
      this.StartDrag(e, 1);
      return true;
    }
    if TKMap.Middle(e) {
      this.StartDrag(e, 3);
      return true;
    }
    return false;
  }

  // presses anywhere (the middle button may only arrive here): the ones on the map count
  protected cb func OnGlobalPress(e: ref<inkPointerEvent>) -> Bool {
    if this.m_dragging || !IsDefined(this.m_clip) || !this.InView(this.Cursor(e)) {
      return false;
    }
    if TKMap.Middle(e) && !TKMap.Left(e) {
      this.StartDrag(e, 3);
    }
    return false;
  }

  protected cb func OnMapRelease(e: ref<inkPointerEvent>) -> Bool {
    if this.m_dragging && (this.m_button == 1 ? TKMap.Left(e) : TKMap.Middle(e) || !RedFunc.MouseButton(3)) {
      this.EndDrag();
    }
    return true;
  }

  protected cb func OnGlobalRelease(e: ref<inkPointerEvent>) -> Bool {
    if this.m_dragging && (this.m_button == 1 ? TKMap.Left(e) : !RedFunc.MouseButton(3)) {
      this.EndDrag();
    }
    return false;
  }

  // the wheel zooms; moving with the middle button held starts a drag even if its
  // press never arrived; without the frame's global input, moves while dragging land here
  protected cb func OnMapRelative(e: ref<inkPointerEvent>) -> Bool {
    if e.IsAction(n"mouse_wheel") {
      let d = e.GetAxisData();
      if d != 0.0 && !this.m_dragging {
        this.Wheel(d > 0.0, this.Cursor(e));
      }
      return true;
    }
    if e.IsAction(n"mouse_x") || e.IsAction(n"mouse_y") {
      if !this.m_dragging && RedFunc.MouseButton(3) {
        this.StartDrag(e, 3);
      } else {
        if this.m_dragging && !this.m_dragHooked {
          this.Drag(e);
        }
      }
    }
    return false;
  }

  protected cb func OnGlobalMove(e: ref<inkPointerEvent>) -> Bool {
    if !this.m_dragging {
      this.HookDrag(false);
      return false;
    }
    if e.IsAction(n"mouse_x") || e.IsAction(n"mouse_y") {
      // a release that never reached us: the button is up
      if !RedFunc.MouseButton(this.m_button) {
        this.EndDrag();
        return false;
      }
      this.Drag(e);
    }
    return false;
  }

  private func Drag(e: ref<inkPointerEvent>) -> Void {
    if !IsDefined(this.m_map) || !IsDefined(this.m_clip) {
      this.Stop();
      return;
    }
    let cur = this.Cursor(e);
    let dx = cur.X - this.m_dragStart.X;
    let dy = cur.Y - this.m_dragStart.Y;
    if AbsF(dx) + AbsF(dy) > 8.0 {
      this.m_moved = true;
    }
    this.m_map.SetTranslation(this.Keep(Vector2(this.m_dragFrom.X + dx, this.m_dragFrom.Y + dy)));
    this.EnsureTiles();
  }

  // a drag keeps the new view; a left click without moving opens a pin or selects a region
  private func EndDrag() -> Void {
    if !this.m_dragging || !IsDefined(this.m_map) {
      return;
    }
    this.m_dragging = false;
    this.HookDrag(false);
    let centre = this.Centre();
    if this.m_moved {
      this.Remember();
      return;
    }
    if this.m_button == 1 {
      let t = this.m_map.GetTranslation();
      let spot = Vector2(this.m_dragStart.X - t.X, this.m_dragStart.Y - t.Y);
      let pin = this.PinAt(spot);
      let view = this.m_view;
      if pin >= 0 && StrLen(this.m_pinLinks[pin]) > 0 && IsDefined(view) {
        let link = this.m_pinLinks[pin];
        view.Show(StrContains(link, "~") ? StrBeforeFirst(link, "~") : link, StrContains(link, "~") ? StrAfterFirst(link, "~") : "", "");
        return;
      }
      if StrLen(this.m_spec.clickAction) > 0 && IsDefined(view) {
        let w = this.ToWorld(spot, this.m_size);
        this.Remember();
        view.Act(this.m_spec.clickAction, IntToString(RoundF(w.X)) + "|" + IntToString(RoundF(w.Y)));
        return;
      }
      let hit = this.RegionAt(this.ToWorld(spot, this.m_size));
      if StrLen(hit) > 0 && !Equals(hit, this.m_spec.selected) {
        this.Go(this.m_zoom, centre, hit);
      }
    }
  }

  // one zoom level in or out, keeping the spot under the cursor where it is
  private func Wheel(zoomIn: Bool, cursor: Vector2) -> Void {
    let levels = this.m_spec.zooms;
    let z = this.Level(this.m_zoom);
    let k = zoomIn ? Min(z + 1, ArraySize(levels) - 1) : Max(z - 1, 0);
    if k == z || !IsDefined(this.m_map) {
      return;
    }
    let next = levels[k];
    let t = this.m_map.GetTranslation();
    let f = next / this.m_zoom;
    let spot = Vector2((cursor.X - t.X) * f, (cursor.Y - t.Y) * f);
    let nt = Vector2(cursor.X - spot.X, cursor.Y - spot.Y);
    this.Go(next, this.ToWorld(Vector2(this.m_viewW / 2.0 - nt.X, this.m_viewH / 2.0 - nt.Y), this.m_size * f), this.m_spec.selected);
  }

  // the frame's global mouse input: presses for the map's whole life, moves and releases while dragging
  private func HookPress(on: Bool) -> Void {
    let owner = this.m_owner;
    if Equals(on, this.m_pressHooked) || !IsDefined(owner) {
      return;
    }
    this.m_pressHooked = on;
    if on {
      owner.RegisterToGlobalInputCallback(n"OnPostOnPress", this, n"OnGlobalPress");
    } else {
      owner.UnregisterFromGlobalInputCallback(n"OnPostOnPress", this, n"OnGlobalPress");
    }
  }

  private func HookDrag(on: Bool) -> Void {
    let owner = this.m_owner;
    if Equals(on, this.m_dragHooked) || !IsDefined(owner) {
      return;
    }
    this.m_dragHooked = on;
    if on {
      owner.RegisterToGlobalInputCallback(n"OnPostOnRelative", this, n"OnGlobalMove");
      owner.RegisterToGlobalInputCallback(n"OnPostOnRelease", this, n"OnGlobalRelease");
    } else {
      owner.UnregisterFromGlobalInputCallback(n"OnPostOnRelative", this, n"OnGlobalMove");
      owner.UnregisterFromGlobalInputCallback(n"OnPostOnRelease", this, n"OnGlobalRelease");
    }
  }

  // the page is going away
  public func Stop() -> Void {
    this.m_followGen += 1;
    this.m_dragging = false;
    this.HookDrag(false);
    this.HookPress(false);
  }
}

// the map's follow tick (stops when the map goes)
public class TKMapFollowTick extends DelayCallback {
  public let map: wref<TKMap>;
  public let gen: Int32;
  public func Call() -> Void {
    if IsDefined(this.map) {
      this.map.FollowStep(this.gen);
    }
  }
}