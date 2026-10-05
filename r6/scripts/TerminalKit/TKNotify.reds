// =============================================================================
// TERMINAL KIT - THE GAME'S OWN NOTIFICATIONS
// The messages the game itself shows, fed the same way the game feeds them (so
// they look, sound and queue exactly like the game's):
//   - Warning: the line under the top of the screen ("Combat zone", "Wanted")
//   - Onscreen: the big centred line the game uses for cinematic messages
//   - Side: the small side popup ("Action blocked")
//   - Quest: the quest-update toast, a header and a line
// Texts may be plain text or "LocKey#1234" keys. TKHud.Toast stays the kit's own
// card; these are for when a message should look like the game's.
//
//   TKNotify.Warning("Unit lost", 4.0, true);
//   TKNotify.Quest("CONTRACT SIGNED", "Escort the truck to Watson");
// =============================================================================
module TerminalKit

public abstract class TKNotify {
  // the warning line for `secs`; `bad` shows it in red (else the neutral style)
  public static func Warning(text: String, secs: Float, bad: Bool) -> Void {
    TKNotify.WarningOfType(text, secs, bad ? SimpleMessageType.Negative : SimpleMessageType.Neutral);
  }

  // the same in one of the game's own looks (Money, Police, Vehicle, Relic...)
  public static func WarningOfType(text: String, secs: Float, type: SimpleMessageType) -> Void {
    let msg: SimpleScreenMessage;
    msg.isShown = true;
    msg.duration = secs > 0.0 ? secs : 5.0;
    msg.message = text;
    msg.type = type;
    TKNotify.Post(GetAllBlackboardDefs().UI_Notifications.WarningMessage, msg);
  }

  // the big centred line (the game upper-cases it) for `secs`
  public static func Onscreen(text: String, secs: Float) -> Void {
    let msg: SimpleScreenMessage;
    msg.isShown = true;
    msg.duration = secs > 0.0 ? secs : 4.0;
    msg.message = text;
    TKNotify.Post(GetAllBlackboardDefs().UI_Notifications.OnscreenMessage, msg);
  }

  // the small side popup with one title (shown about five seconds)
  public static func Side(title: String) -> Void {
    let evt = new UIInGameNotificationEvent();
    evt.m_notificationType = UIInGameNotificationType.GenericNotification;
    evt.m_title = title;
    GameInstance.GetUISystem(GetGameInstance()).QueueEvent(evt);
  }

  // the quest-update toast: a header and a line under it
  public static func Quest(header: String, text: String) -> Void {
    let data: CustomQuestNotificationData;
    data.header = header;
    data.desc = text;
    let bb = GameInstance.GetBlackboardSystem(GetGameInstance()).Get(GetAllBlackboardDefs().UI_CustomQuestNotification);
    if IsDefined(bb) {
      bb.SetVariant(GetAllBlackboardDefs().UI_CustomQuestNotification.data, ToVariant(data), true);
    }
  }

  private static func Post(id: BlackboardID_Variant, msg: SimpleScreenMessage) -> Void {
    let bb = GameInstance.GetBlackboardSystem(GetGameInstance()).Get(GetAllBlackboardDefs().UI_Notifications);
    if IsDefined(bb) {
      bb.SetVariant(id, ToVariant(msg), true);
    }
  }
}
