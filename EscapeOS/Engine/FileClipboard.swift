import Combine
import Foundation
import UIKit

/// App-wide Copy/Cut buffer for container files (Filza-style).
///
/// Each folder push creates its own `FileBrowserViewModel`, so the buffer
/// cannot live on the view model. Paste works in any folder of any app.
final class FileClipboard: ObservableObject {
    static let shared = FileClipboard()

    enum Mode {
        case copy
        case cut
    }

    struct Payload {
        let containerPath: String
        let items: [FileItem]
        let mode: Mode
    }

    @Published private(set) var payload: Payload?

    var isEmpty: Bool { payload == nil }

    var pasteTitle: String {
        guard let payload else { return "Paste" }
        let n = payload.items.count
        let verb = payload.mode == .cut ? "Move here" : "Paste"
        if n == 1 {
            return "\(verb) “\(payload.items[0].name)”"
        }
        return "\(verb) \(n) items"
    }

    func copy(_ items: [FileItem], containerPath: String) {
        payload = Payload(containerPath: containerPath, items: items, mode: .copy)
    }

    func cut(_ items: [FileItem], containerPath: String) {
        payload = Payload(containerPath: containerPath, items: items, mode: .cut)
    }

    func clear() {
        payload = nil
    }

    static func copyText(_ text: String) {
        UIPasteboard.general.string = text
    }
}
