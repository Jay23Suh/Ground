import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var supabase: SupabaseManager

    var body: some View {
        if supabase.user == nil {
            Button("set up reflect…") { notify("showSetupWindow") }
        } else {
            Button("reflect now")   { notify("showJournalPopup") }
            Button("open reflect")  { notify("showMainWindow") }
            Divider()
            Button("sign out") {
                Task { try? await supabase.signOut() }
            }
            Divider()
            Button("quit reflect") { NSApp.terminate(nil) }
        }
    }

    private func notify(_ name: String) {
        NotificationCenter.default.post(
            name: NSNotification.Name(rawValue: name), object: nil
        )
    }
}
