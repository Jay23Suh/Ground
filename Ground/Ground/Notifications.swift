import Foundation

extension Notification.Name {
    static let showJournalPopup   = Notification.Name("showJournalPopup")
    static let showMainWindow     = Notification.Name("showMainWindow")
    static let showSetupWindow    = Notification.Name("showSetupWindow")
    static let didJournal         = Notification.Name("didJournal")  // reset active timer
    static let showIntroOverlay   = Notification.Name("showIntroOverlay")
    static let prepareJournalPopup = Notification.Name("prepareJournalPopup")
}
