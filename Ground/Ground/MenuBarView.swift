import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var supabase: SupabaseManager

    var body: some View {
        Group {
            if supabase.user == nil {
                Button("set up ground…") { notify("showSetupWindow") }
            } else {
                Button("ground now")   { notify("showJournalPopup") }
                Button("open ground")  { notify("showMainWindow") }
                Divider()
                Button("sign out") {
                    Task { try? await supabase.signOut() }
                }
                Divider()
                Button("quit ground") { NSApp.terminate(nil) }
            }
        }
    }

    private func notify(_ name: String) {
        NotificationCenter.default.post(
            name: NSNotification.Name(rawValue: name), object: nil
        )
    }
}
