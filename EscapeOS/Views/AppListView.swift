import SwiftUI

/// View model for the app picker.
final class AppListViewModel: ObservableObject {
    @Published var apps: [InstalledApp] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var needsPairing = false
    @Published var icons: [String: UIImage] = [:]

    private let discovery = AppDiscovery()

    var hasPairingFile: Bool { discovery.hasPairingFile }

    func reload() {
        isLoading = true
        errorMessage = nil
        needsPairing = false
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            do {
                let found = try self.discovery.fetchInstalledApps()
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.apps = found
                    self.errorMessage = nil
                    self.icons = [:]
                }
                self.loadIcons(for: found)
            } catch let e as AppDiscoveryError {
                DispatchQueue.main.async {
                    self.isLoading = false
                    if case .noPairingFile = e {
                        self.needsPairing = true
                    } else {
                        self.errorMessage = e.localizedDescription
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    /// Fetch icons concurrently and publish each one as soon as it arrives.
    private func loadIcons(for apps: [InstalledApp]) {
        let ids = apps.map { $0.bundleIdentifier }
        guard !ids.isEmpty else { return }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            DispatchQueue.concurrentPerform(iterations: ids.count) { index in
                let bundleId = ids[index]
                guard let icon = self.discovery.appIcon(for: bundleId) else { return }
                DispatchQueue.main.async {
                    self.icons[bundleId] = icon
                }
            }
        }
    }

    func importPairingFile(_ contents: String) throws {
        try discovery.importPairingFile(contents)
    }

    func resetPairing() {
        discovery.resetPairing()
        apps = []
        icons = [:]
        reload()
    }

    /// Load a single icon on demand (e.g. when opening app detail before batch fetch finishes).
    func ensureIcon(for bundleId: String) {
        guard icons[bundleId] == nil else { return }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            guard let icon = self.discovery.appIcon(for: bundleId) else { return }
            DispatchQueue.main.async {
                self.icons[bundleId] = icon
            }
        }
    }
}

/// Scrollable list of installed user apps.
struct AppListView: View {
    @ObservedObject var viewModel: AppListViewModel

    var body: some View {
        List(viewModel.apps) { app in
            NavigationLink(destination: AppDetailView(app: app, viewModel: viewModel)) {
                HStack(spacing: 12) {
                    AppIconView(icon: viewModel.icons[app.bundleIdentifier])
                    VStack(alignment: .leading, spacing: 2) {
                        Text(app.name)
                            .font(.body)
                        Text(app.bundleIdentifier)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
            .contextMenu {
                Button {
                    FileClipboard.copyText(app.bundleIdentifier)
                } label: {
                    Label("Copy Bundle ID", systemImage: "doc.on.doc")
                }
                Button {
                    FileClipboard.copyText(app.name)
                } label: {
                    Label("Copy Name", systemImage: "character.cursor.ibeam")
                }
            }
        }
    }
}
