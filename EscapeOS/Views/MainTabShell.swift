import SwiftUI
import UIKit

/// UIKit tab bar host so EscapeOS uses the same navigation layer as system apps.
/// Native iOS 26 Liquid Glass requires linking with the Xcode 26 SDK (see docs/BUILD.md).
struct MainTabShell: UIViewControllerRepresentable {
    @ObservedObject var viewModel: AppListViewModel
    @Binding var selectedTab: MainTab
    @Binding var hasAcknowledgedLimits: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> UITabBarController {
        let controller = UITabBarController()
        controller.delegate = context.coordinator

        let apps = makeNavigationController(
            root: RootAppsContainer(viewModel: viewModel, hasAcknowledgedLimits: $hasAcknowledgedLimits),
            title: "Apps",
            systemImage: "square.grid.2x2.fill",
            tag: MainTab.apps.rawValue
        )

        let backups = makeNavigationController(
            root: BackupsListView(appList: viewModel),
            title: "Backups",
            systemImage: "externaldrive.fill.badge.timemachine",
            tag: MainTab.backups.rawValue
        )

        let settings = makeNavigationController(
            root: SettingsForm(onResetPairing: {
                viewModel.resetPairing()
                selectedTab = .apps
                controller.selectedIndex = MainTab.apps.rawValue
            }),
            title: "Settings",
            systemImage: "gearshape.fill",
            tag: MainTab.settings.rawValue
        )

        controller.viewControllers = [apps, backups, settings]
        controller.selectedIndex = selectedTab.rawValue
        EscapeOSConfigureTabBarController(controller)
        context.coordinator.tabController = controller
        return controller
    }

    func updateUIViewController(_ controller: UITabBarController, context: Context) {
        if controller.selectedIndex != selectedTab.rawValue {
            controller.selectedIndex = selectedTab.rawValue
        }
    }

    private func makeNavigationController<Content: View>(
        root: Content,
        title: String,
        systemImage: String,
        tag: Int
    ) -> UINavigationController {
        let host = UIHostingController(rootView: root.navigationTitle(title))
        host.tabBarItem = UITabBarItem(title: title, image: UIImage(systemName: systemImage), tag: tag)
        let nav = UINavigationController(rootViewController: host)
        nav.navigationBar.prefersLargeTitles = true
        return nav
    }

    final class Coordinator: NSObject, UITabBarControllerDelegate {
        var parent: MainTabShell
        weak var tabController: UITabBarController?

        init(parent: MainTabShell) {
            self.parent = parent
        }

        func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
            if let tab = MainTab(rawValue: tabBarController.selectedIndex) {
                parent.selectedTab = tab
            }
        }
    }
}

/// Apps tab content extracted so disclaimer + reload logic stay in one place.
private struct RootAppsContainer: View {
    @ObservedObject var viewModel: AppListViewModel
    @Binding var hasAcknowledgedLimits: Bool

    var body: some View {
        appsContent
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        viewModel.reload()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(viewModel.isLoading)
                }
            }
            .onAppear {
                if hasAcknowledgedLimits {
                    viewModel.reload()
                }
            }
            .onChange(of: hasAcknowledgedLimits) { acknowledged in
                if acknowledged {
                    viewModel.reload()
                }
            }
    }

    @ViewBuilder
    private var appsContent: some View {
        if viewModel.isLoading && viewModel.apps.isEmpty && !viewModel.needsPairing {
            ProgressView("Loading apps…")
        } else if viewModel.needsPairing {
            PairingSetupView(viewModel: viewModel)
        } else if let error = viewModel.errorMessage, viewModel.apps.isEmpty {
            ErrorStateView(message: error, onRetry: { viewModel.reload() })
        } else if viewModel.apps.isEmpty {
            EmptyStateView(diagnostics: "No user apps returned by the device.")
        } else {
            AppListView(viewModel: viewModel)
        }
    }
}

enum MainTab: Int, Hashable {
    case apps = 0
    case backups = 1
    case settings = 2
}
