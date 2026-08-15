import SwiftUI

/// Honest product limits. Shown on first launch and in Settings.
enum ProductLimits {
    static let title = "Sandbox access with limits"

    static let body = """
EscapeOS lists installed apps through LocalDevVPN and a pairing file (iOS 18 and iOS 26), then opens another app's Data container: Documents, Library, and tmp. House Arrest is only how a PC can drop that pairing file into EscapeOS Documents — it does not replace pairing, and it cannot list or open other apps from inside EscapeOS.

You can browse, preview, edit, back up, and restore those files. Keychain items, App Groups, and system folders are not included.

Close the target app before restoring or editing live databases. A restore overwrites files in that container.
"""
}

struct LimitsDisclaimerView: View {
    var onAcknowledge: () -> Void

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 16) {
                Text(ProductLimits.title)
                    .font(.title2).bold()
                Text(ProductLimits.body)
                    .font(.body)
                    .foregroundColor(.secondary)
                Spacer()
                Button("I understand", action: onAcknowledge)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)
            }
            .padding()
            .navigationTitle("Before you start")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
