// =============================================================================
// TERMINAL KIT - PINS ON THE GAME'S OWN MAP
// A pin at a world position, shown by the game itself on the world map, the
// minimap and in the world, kept by a name of your choosing so a mod never
// holds the game's pin ids. Pins live for the session: the game doesn't save
// script pins, so add them again after a load (OnPlayerAttach is a good place).
//
//   TKPins.Add("nce_drop", dropPos);                       // the custom-waypoint look
//   TKPins.AddAs("nce_job", jobPos, gamedataMappinVariant.DefaultQuestVariant);
//   TKHud.Strip("escort", 760.0).TargetPin("nce_drop");   // a strip follows it
//   TKPins.Remove("nce_drop");
// =============================================================================
module TerminalKit

public abstract class TKPins {
  public static func Get() -> ref<TKPinSystem> = GameInstance.GetScriptableSystemsContainer(GetGameInstance()).Get(n"TerminalKit.TKPinSystem") as TKPinSystem

  // a pin named `key` at `pos` (moved there if it exists), in the look of the
  // player's own custom waypoint
  public static func Add(key: String, pos: Vector4) -> Void {
    TKPins.AddAs(key, pos, gamedataMappinVariant.CustomPositionVariant);
  }

  // the same in one of the game's pin looks (a quest, a vehicle, a fixer...)
  public static func AddAs(key: String, pos: Vector4, variant: gamedataMappinVariant) -> Void {
    let sys = TKPins.Get();
    if IsDefined(sys) {
      sys.Put(key, pos, variant);
    }
  }

  public static func Move(key: String, pos: Vector4) -> Void {
    let sys = TKPins.Get();
    if IsDefined(sys) {
      sys.Move(key, pos);
    }
  }

  // shows or hides a pin without removing it
  public static func Show(key: String, on: Bool) -> Void {
    let sys = TKPins.Get();
    if IsDefined(sys) {
      sys.Show(key, on);
    }
  }

  public static func Remove(key: String) -> Void {
    let sys = TKPins.Get();
    if IsDefined(sys) {
      sys.Remove(key);
    }
  }

  // removes every pin whose name starts with `prefix` ("" removes all of them)
  public static func RemoveAll(prefix: String) -> Void {
    let sys = TKPins.Get();
    if IsDefined(sys) {
      sys.RemoveAll(prefix);
    }
  }

  public static func Has(key: String) -> Bool {
    let sys = TKPins.Get();
    return IsDefined(sys) && sys.Find(key) >= 0;
  }

  // where the pin is (false when there is no such pin)
  public static func Position(key: String, out pos: Vector4) -> Bool {
    let sys = TKPins.Get();
    return IsDefined(sys) && sys.Where(key, pos);
  }
}

public class TKPinSystem extends ScriptableSystem {
  private let m_keys: array<String>;
  private let m_ids: array<NewMappinID>;
  private let m_positions: array<Vector4>;

  // a new session: the game dropped every script pin
  private func OnPlayerAttach(request: ref<PlayerAttachRequest>) -> Void {
    ArrayClear(this.m_keys);
    ArrayClear(this.m_ids);
    ArrayClear(this.m_positions);
  }

  private func Mappins() -> ref<MappinSystem> = GameInstance.GetMappinSystem(this.GetGameInstance())

  public func Find(key: String) -> Int32 {
    let i = 0;
    while i < ArraySize(this.m_keys) {
      if Equals(this.m_keys[i], key) {
        return i;
      }
      i += 1;
    }
    return -1;
  }

  public func Put(key: String, pos: Vector4, variant: gamedataMappinVariant) -> Void {
    let i = this.Find(key);
    if i >= 0 {
      this.Mappins().ChangeMappinVariant(this.m_ids[i], variant);
      this.Move(key, pos);
      return;
    }
    let data: MappinData;
    data.mappinType = t"Mappins.QuestStaticMappinDefinition";
    data.variant = variant;
    data.active = true;
    data.visibleThroughWalls = true;
    ArrayPush(this.m_keys, key);
    ArrayPush(this.m_ids, this.Mappins().RegisterMappin(data, pos));
    ArrayPush(this.m_positions, pos);
  }

  public func Move(key: String, pos: Vector4) -> Void {
    let i = this.Find(key);
    if i >= 0 {
      this.Mappins().SetMappinPosition(this.m_ids[i], pos);
      this.m_positions[i] = pos;
    }
  }

  public func Show(key: String, on: Bool) -> Void {
    let i = this.Find(key);
    if i >= 0 {
      this.Mappins().SetMappinActive(this.m_ids[i], on);
    }
  }

  public func Remove(key: String) -> Void {
    let i = this.Find(key);
    if i >= 0 {
      this.Mappins().UnregisterMappin(this.m_ids[i]);
      ArrayErase(this.m_keys, i);
      ArrayErase(this.m_ids, i);
      ArrayErase(this.m_positions, i);
    }
  }

  public func RemoveAll(prefix: String) -> Void {
    let i = ArraySize(this.m_keys) - 1;
    while i >= 0 {
      if StrBeginsWith(this.m_keys[i], prefix) {
        this.Remove(this.m_keys[i]);
      }
      i -= 1;
    }
  }

  public func Where(key: String, out pos: Vector4) -> Bool {
    let i = this.Find(key);
    if i < 0 {
      return false;
    }
    pos = this.m_positions[i];
    return true;
  }
}
