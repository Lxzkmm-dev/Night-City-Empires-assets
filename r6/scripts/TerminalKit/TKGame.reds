// =============================================================================
// TERMINAL KIT - THE GAME'S OWN DATA, READY FOR A PAGE
// TKVersion: which kit is installed, so a mod can ask for a newer one.
// TKGame: what V's game says right now, already worded the way the game words
//   it: the district, money in E$, level and street cred, the clock, distances
//   in the player's own units. Every call is safe before a save is loaded (it
//   returns an empty text or 0).
//
//   p.Pair("DISTRICT", TKGame.District());
//   p.Pair("BALANCE", TKGame.MoneyText(TKGame.Money()));
//   if !TKVersion.AtLeast(1, 0) { p.Note("!Update TerminalKit to 1.0"); }
// =============================================================================
module TerminalKit

public abstract class TKVersion {
  public static func Major() -> Int32 = 1
  public static func Minor() -> Int32 = 1
  public static func Text() -> String = "1.1"

  // true when the installed kit is `major.minor` or newer
  public static func AtLeast(major: Int32, minor: Int32) -> Bool {
    return TKVersion.Major() > major || (TKVersion.Major() == major && TKVersion.Minor() >= minor);
  }
}

public abstract class TKGame {
  public static func Player() -> ref<PlayerPuppet> = GetPlayer(GetGameInstance())

  // ---- where V is ----
  // the district V is in, as the game names it ("Little China"): the innermost
  // one, so usually the sub-district; "" outside any district or before a save
  public static func District() -> String {
    let rec = TKGame.DistrictRecord();
    return IsDefined(rec) ? GetLocalizedText(rec.LocalizedName()) : "";
  }

  // the main district around it ("Watson" for Little China)
  public static func MainDistrict() -> String {
    let rec = TKGame.DistrictRecord();
    if !IsDefined(rec) {
      return "";
    }
    let parent = rec.ParentDistrict();
    return GetLocalizedText(IsDefined(parent) ? parent.LocalizedName() : rec.LocalizedName());
  }

  // the record behind District() (null outside any district)
  public static func DistrictRecord() -> ref<District_Record> {
    let player = TKGame.Player();
    if !IsDefined(player) {
      return null;
    }
    let prevention = GameInstance.GetScriptableSystemsContainer(player.GetGame()).Get(n"PreventionSystem") as PreventionSystem;
    if !IsDefined(prevention) {
      return null;
    }
    let district = prevention.GetCurrentDistrict();
    return IsDefined(district) ? district.GetDistrictRecord() : null;
  }

  // ---- money ----
  public static func Money() -> Int32 {
    let player = TKGame.Player();
    return IsDefined(player) ? GameInstance.GetTransactionSystem(player.GetGame()).GetItemQuantity(player, MarketSystem.Money()) : 0;
  }

  // "12,500 E$" in the game's own currency word
  public static func MoneyText(amount: Int32) -> String = TKGame.Group(amount) + " " + GetLocalizedText(UILocalizationKeys.Common_EuroDollar())

  // "12,500", "-3,040"
  public static func Group(n: Int32) -> String {
    let neg = n < 0;
    let digits = IntToString(neg ? -n : n);
    let out = "";
    let len = StrLen(digits);
    let i = 0;
    while i < len {
      if i > 0 && (len - i) % 3 == 0 {
        out += ",";
      }
      out += StrMid(digits, i, 1);
      i += 1;
    }
    return neg ? "-" + out : out;
  }

  // ---- V ----
  public static func Level() -> Int32 = TKGame.Proficiency(gamedataProficiencyType.Level)
  public static func StreetCred() -> Int32 = TKGame.Proficiency(gamedataProficiencyType.StreetCred)

  private static func Proficiency(type: gamedataProficiencyType) -> Int32 {
    let player = TKGame.Player();
    if !IsDefined(player) {
      return 0;
    }
    let dev = PlayerDevelopmentSystem.GetInstance(player);
    return IsDefined(dev) ? dev.GetProficiencyLevel(player, type) : 0;
  }

  // ---- the clock ----
  // the in-game time of day, "21:07"
  public static func Clock() -> String {
    let t = GameInstance.GetTimeSystem(GetGameInstance()).GetGameTime();
    return TKGame.Two(GameTime.Hours(t)) + ":" + TKGame.Two(GameTime.Minutes(t));
  }

  public static func Hour() -> Int32 = GameTime.Hours(GameInstance.GetTimeSystem(GetGameInstance()).GetGameTime())

  private static func Two(n: Int32) -> String = (n < 10 ? "0" : "") + IntToString(n)

  // ---- distances ----
  // true when the player picked imperial units in the game's settings
  public static func Imperial() -> Bool = Equals(UILocalizationHelper.GetSystemBaseUnit(), EMeasurementUnit.Feet)

  // "120 m" / "390 ft" (metres in, the player's units out), "1.4 km" / "0.9 mi" when far
  public static func Distance(metres: Float) -> String {
    if TKGame.Imperial() {
      let feet = metres * 3.28084;
      return feet >= 5280.0 ? FloatToStringPrec(feet / 5280.0, 1) + " mi" : IntToString(RoundF(feet)) + " ft";
    }
    return metres >= 1000.0 ? FloatToStringPrec(metres / 1000.0, 1) + " km" : IntToString(RoundF(metres)) + " m";
  }

  // how far V is from `pos`, in metres
  public static func DistanceTo(pos: Vector4) -> Float {
    let player = TKGame.Player();
    return IsDefined(player) ? Vector4.Distance(player.GetWorldPosition(), pos) : 0.0;
  }
}
