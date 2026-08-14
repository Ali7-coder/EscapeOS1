import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// Filza-style file browser for a single app container.
struct FileBrowserView: View {
    let app: InstalledApp

    @StateObject private var vm: FileBrowserViewModel
    @ObservedObject private var clipboard = FileClipboard.shared
    @State private var createKind: CreateKind?
    @State private var createName = ""
    @State private var renameItem: FileItem?
    @State private var renameName = ""
    @State private var searchText = ""
    @State private var openRequest: OpenRequest?
    @State private var propertiesItem: FileItem?
    @State private var showImporter = false
    @State private var selecting = false
    @State private var selected = Set<String>()
    @State private var pendingDelete: [FileItem] = []

    init(app: InstalledApp) {
        self.app = app
        _vm = StateObject(wrappedValue: FileBrowserViewModel(app: app))
    }

    init(app: InstalledApp, initialPath: String) {
        self.app = app
        _vm = StateObject(wrappedValue: FileBrowserViewModel(app: app, initialPath: initialPath))
    }

    var body: some View {
        Group {
            if vm.isLoading && vm.items.isEmpty {
                ProgressView("Opening container…")
            } else if let error = vm.errorMessage, vm.items.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    Text(error)
                        .multilineTextAlignment(.center)
                        .padding()
                    Button("Retry") { vm.open(vm.currentPath) }
                }
            } else {
                fileList
            }
        }
        .navigationTitle(selecting ? selectionTitle : vm.displayTitle)
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Filter this folder")
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                if selecting {
                    Button(allVisibleSelected ? "Deselect All" : "Select All") {
                        if allVisibleSelected {
                            selected.removeAll()
                        } else {
                            selected.formUnion(visibleItems.map(\.path))
                        }
                    }
                    .disabled(visibleItems.isEmpty)
                    Button("Done") { exitSelection() }
                } else {
                    if !clipboard.isEmpty {
                        Button {
                            vm.paste()
                        } label: {
                            Image(systemName: clipboard.payload?.mode == .cut ? "scissors" : "doc.on.clipboard")
                        }
                        .disabled(vm.isPasting)
                        .accessibilityLabel(clipboard.pasteTitle)
                    }
                    Button("Select") { enterSelection() }
                    Menu {
                        if !clipboard.isEmpty {
                            Button {
                                vm.paste()
                            } label: {
                                Label(clipboard.pasteTitle, systemImage: "doc.on.clipboard")
                            }
                            .disabled(vm.isPasting)
                            Button("Clear Clipboard", role: .destructive) {
                                clipboard.clear()
                            }
                        }
                        Button {
                            createName = "New File.txt"
                            createKind = .file
                        } label: {
                            Label("New File", systemImage: "doc.badge.plus")
                        }
                        Button {
                            createName = "New Folder"
                            createKind = .folder
                        } label: {
                            Label("New Folder", systemImage: "folder.badge.plus")
                        }
                        Button {
                            showImporter = true
                        } label: {
                            Label("Import from Files", systemImage: "square.and.arrow.down")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if selecting {
                selectionBar
            }
        }
        .onAppear { vm.open(vm.currentPath) }
        .background(
            NavigationLink(
                destination: Group {
                    if let request = openRequest {
                        FileViewerView(app: app, item: request.item, mode: request.mode)
                    }
                },
                isActive: Binding(
                    get: { openRequest != nil },
                    set: { if !$0 { openRequest = nil } }
                )
            ) { EmptyView() }
            .hidden()
        )
        .sheet(item: $vm.sharePayload) { payload in
            ActivityShareView(url: payload.url)
        }
        .alert(item: $vm.exportError) { err in
            Alert(title: Text("Could not share file"), message: Text(err.message), dismissButton: .default(Text("OK")))
        }
        .alert(item: $vm.operationError) { err in
            Alert(title: Text("File Operation Failed"), message: Text(err.message), dismissButton: .default(Text("OK")))
        }
        .alert("New \(createKind == .folder ? "Folder" : "File")", isPresented: Binding(
            get: { createKind != nil },
            set: { if !$0 { createKind = nil } }
        )) {
            TextField("Name", text: $createName)
                .disableAutocorrection(true)
                .autocapitalization(.none)
            Button("Cancel", role: .cancel) { createKind = nil }
            Button("Create") {
                if let kind = createKind {
                    vm.create(name: createName, kind: kind)
                }
                createKind = nil
            }
        }
        .alert("Rename", isPresented: Binding(
            get: { renameItem != nil },
            set: { if !$0 { renameItem = nil } }
        )) {
            TextField("New name", text: $renameName)
                .disableAutocorrection(true)
                .autocapitalization(.none)
            Button("Cancel", role: .cancel) { renameItem = nil }
            Button("Rename") {
                if let item = renameItem {
                    vm.rename(item: item, to: renameName)
                }
                renameItem = nil
            }
        }
        .alert(deleteTitle, isPresented: Binding(
            get: { !pendingDelete.isEmpty },
            set: { if !$0 { pendingDelete = [] } }
        )) {
            Button("Cancel", role: .cancel) { pendingDelete = [] }
            Button("Delete", role: .destructive) {
                vm.delete(items: pendingDelete)
                selected.subtract(pendingDelete.map(\.path))
                pendingDelete = []
            }
        } message: {
            Text("This cannot be undone. Close the target app first if the file might be in use.")
        }
        .sheet(item: $propertiesItem) { item in
            FilePropertiesView(app: app, item: item)
        }
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [.item, .data, .content, .archive, .image, .text, .sourceCode, .propertyList],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                vm.importFiles(from: urls)
            case .failure(let error):
                vm.operationError = IdentifiedError(message: error.localizedDescription)
            }
        }
    }

    private var visibleItems: [FileItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return vm.items }
        return vm.items.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    private var selectedItems: [FileItem] {
        visibleItems.filter { selected.contains($0.path) }
    }

    private var allVisibleSelected: Bool {
        !visibleItems.isEmpty && visibleItems.allSatisfy { selected.contains($0.path) }
    }

    private var selectionTitle: String {
        let n = selectedItems.count
        if n == 0 { return "Select Items" }
        return n == 1 ? "1 Selected" : "\(n) Selected"
    }

    private var deleteTitle: String {
        let items = pendingDelete
        if items.count == 1 { return "Delete \(items[0].name)?" }
        if items.isEmpty { return "Delete?" }
        return "Delete \(items.count) items?"
    }

    private var fileList: some View {
        List {
            ForEach(visibleItems) { item in
                if selecting {
                    Button {
                        toggleSelection(item)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: selected.contains(item.path) ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(selected.contains(item.path) ? .accentColor : .secondary)
                                .imageScale(.large)
                            FileRow(item: item)
                            Spacer(minLength: 0)
                        }
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(selected.contains(item.path) ? Color.accentColor.opacity(0.12) : nil)
                } else if item.isDirectory {
                    NavigationLink(destination: FileBrowserView(app: app, initialPath: item.path)) {
                        FileRow(item: item)
                    }
                    .contextMenu { itemMenu(for: item) }
                } else {
                    NavigationLink(destination: FileViewerView(app: app, item: item, mode: .auto)) {
                        FileRow(item: item)
                    }
                    .contextMenu { itemMenu(for: item) }
                }
            }
            .onDelete(perform: deleteAtOffsets)
        }
        .environment(\.editMode, .constant(.inactive))
        .refreshable {
            vm.open(vm.currentPath)
        }
        .onChange(of: vm.items.map(\.path)) { paths in
            selected.formIntersection(Set(paths))
        }
    }

    private func deleteAtOffsets(_ offsets: IndexSet) {
        guard !selecting else { return }
        let snapshot = visibleItems
        pendingDelete = offsets.compactMap { $0 < snapshot.count ? snapshot[$0] : nil }
    }

    private var selectionBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 0) {
                selectionAction("Copy", "doc.on.doc", enabled: !selectedItems.isEmpty) {
                    FileClipboard.shared.copy(selectedItems, containerPath: app.containerPath)
                }
                selectionAction("Cut", "scissors", enabled: !selectedItems.isEmpty) {
                    FileClipboard.shared.cut(selectedItems, containerPath: app.containerPath)
                }
                selectionAction("Paste", "doc.on.clipboard", enabled: !clipboard.isEmpty && !vm.isPasting) {
                    vm.paste()
                }
                Menu {
                    Button {
                        vm.duplicate(items: selectedItems)
                    } label: {
                        Label("Duplicate", systemImage: "plus.square.on.square")
                    }
                    .disabled(selectedItems.isEmpty)
                    Button {
                        FileClipboard.copyText(selectedItems.map(\.path).joined(separator: "\n"))
                    } label: {
                        Label(selectedItems.count == 1 ? "Copy Path" : "Copy Paths", systemImage: "list.clipboard")
                    }
                    .disabled(selectedItems.isEmpty)
                    if selectedItems.count == 1, let item = selectedItems.first {
                        Button {
                            renameName = item.name
                            renameItem = item
                        } label: {
                            Label("Rename", systemImage: "pencil")
                        }
                        Button {
                            propertiesItem = item
                        } label: {
                            Label("Properties", systemImage: "info.circle")
                        }
                        if !item.isDirectory {
                            Button {
                                vm.export(item: item)
                            } label: {
                                Label("Share / Save to Files", systemImage: "square.and.arrow.up")
                            }
                            .disabled(vm.isExporting)
                        }
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "ellipsis.circle")
                            .font(.title3)
                        Text("More")
                            .font(.caption2)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .disabled(selectedItems.isEmpty)
                selectionAction("Delete", "trash", enabled: !selectedItems.isEmpty, destructive: true) {
                    pendingDelete = selectedItems
                }
            }
            .padding(.horizontal, 4)
        }
        .background(.bar)
    }

    private func selectionAction(
        _ title: String,
        _ systemImage: String,
        enabled: Bool,
        destructive: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.title3)
                Text(title)
                    .font(.caption2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .foregroundColor(destructive && enabled ? .red : nil)
        }
        .disabled(!enabled)
    }

    private func enterSelection(preselect item: FileItem? = nil) {
        selecting = true
        selected = Set(item.map { [$0.path] } ?? [])
    }

    private func exitSelection() {
        selecting = false
        selected.removeAll()
    }

    private func toggleSelection(_ item: FileItem) {
        if selected.contains(item.path) {
            selected.remove(item.path)
        } else {
            selected.insert(item.path)
        }
    }

    @ViewBuilder
    private func itemMenu(for item: FileItem) -> some View {
        if !item.isDirectory {
            Button {
                openRequest = OpenRequest(item: item, mode: .auto)
            } label: {
                Label("Open", systemImage: "eye")
            }
            Button {
                openRequest = OpenRequest(item: item, mode: .preview)
            } label: {
                Label("Preview", systemImage: "doc.viewfinder")
            }
            Button {
                openRequest = OpenRequest(item: item, mode: .text)
            } label: {
                Label("Open as Text", systemImage: "doc.plaintext")
            }
            Button {
                openRequest = OpenRequest(item: item, mode: .hex)
            } label: {
                Label("Open as Hex", systemImage: "number")
            }
            Button {
                vm.export(item: item)
            } label: {
                Label("Share / Save to Files", systemImage: "square.and.arrow.up")
            }
            .disabled(vm.isExporting)
        }
        Button {
            enterSelection(preselect: item)
        } label: {
            Label("Select", systemImage: "checkmark.circle")
        }
        Button {
            FileClipboard.shared.copy([item], containerPath: app.containerPath)
        } label: {
            Label("Copy", systemImage: "doc.on.doc")
        }
        Button {
            FileClipboard.shared.cut([item], containerPath: app.containerPath)
        } label: {
            Label("Cut", systemImage: "scissors")
        }
        Button {
            FileClipboard.copyText(item.path)
        } label: {
            Label("Copy Path", systemImage: "list.clipboard")
        }
        Button {
            vm.duplicate(item: item)
        } label: {
            Label("Duplicate", systemImage: "plus.square.on.square")
        }
        Button {
            propertiesItem = item
        } label: {
            Label("Properties", systemImage: "info.circle")
        }
        Button {
            renameName = item.name
            renameItem = item
        } label: {
            Label("Rename", systemImage: "pencil")
        }
        Button(role: .destructive) {
            pendingDelete = [item]
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }
}

enum CreateKind {
    case file
    case folder
}

private struct OpenRequest: Identifiable {
    let id = UUID()
    let item: FileItem
    let mode: FileOpenMode
}

struct FileRow: View {
    let item: FileItem

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: kind.symbolName)
                .foregroundColor(iconColor)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name).font(.body)
                HStack(spacing: 8) {
                    if !item.isDirectory {
                        Text(formatBytes(item.size))
                    }
                    if let modified = item.modified {
                        Text(Self.stamp.string(from: modified))
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    private var kind: FileContentKind {
        FileContentKind.classify(name: item.name, isDirectory: item.isDirectory)
    }

    private var iconColor: Color {
        switch kind {
        case .directory: return .accentColor
        case .image: return .green
        case .pdf: return .red
        case .audio, .video: return .purple
        case .text, .json, .xml, .plist: return .orange
        default: return .secondary
        }
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    private static let stamp: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()
}

/// View model driving the file browser.
final class FileBrowserViewModel: ObservableObject {
    @Published var items: [FileItem] = []
    @Published var currentPath: String = "/"
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var sharePayload: SharePayload?
    @Published var isExporting = false
    @Published var exportError: IdentifiedError?
    @Published var operationError: IdentifiedError?
    @Published var isPasting = false

    let app: InstalledApp
    private let escape = SandboxEscape()
    private let files = FileService()

    init(app: InstalledApp, initialPath: String? = nil) {
        self.app = app
        if let initialPath = initialPath {
            self.currentPath = initialPath
        } else {
            self.currentPath = app.containerPath
        }
    }

    var displayTitle: String {
        let last = (currentPath as NSString).lastPathComponent
        return last.isEmpty ? app.name : last
    }

    func open(_ path: String) {
        isLoading = true
        errorMessage = nil
        currentPath = path
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let listed = try self.escape.withHandle(for: self.app.containerPath) { _ in
                    try self.files.list(directory: path)
                }
                DispatchQueue.main.async {
                    self.items = listed
                    self.isLoading = false
                }
            } catch let e as SandboxEscapeError {
                DispatchQueue.main.async {
                    self.errorMessage = e.localizedDescription
                    self.isLoading = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }

    func create(name: String, kind: CreateKind) {
        guard let safe = FileNameRules.sanitize(name) else {
            operationError = IdentifiedError(message: "Enter a file name without slashes.")
            return
        }
        let dest = (currentPath as NSString).appendingPathComponent(safe)
        mutate {
            if kind == .folder {
                try self.files.createDirectory(at: dest)
            } else {
                try self.files.createEmptyFile(at: dest)
            }
        }
    }

    func rename(item: FileItem, to newName: String) {
        guard let safe = FileNameRules.sanitize(newName) else {
            operationError = IdentifiedError(message: "Enter a file name without slashes.")
            return
        }
        mutate {
            try self.files.renameItem(at: item.path, to: safe)
        }
    }

    func delete(item: FileItem) {
        delete(items: [item])
    }

    func delete(items: [FileItem]) {
        guard !items.isEmpty else { return }
        mutate {
            for item in items {
                try self.files.deleteItem(at: item.path)
            }
        }
    }

    func paste() {
        guard let clip = FileClipboard.shared.payload, !clip.items.isEmpty else { return }
        isPasting = true
        let destDir = currentPath
        let destContainer = app.containerPath
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try self.paste(clip, into: destDir, destContainer: destContainer)
                DispatchQueue.main.async {
                    self.isPasting = false
                    if clip.mode == .cut {
                        FileClipboard.shared.clear()
                    }
                    self.open(self.currentPath)
                }
            } catch {
                DispatchQueue.main.async {
                    self.isPasting = false
                    self.operationError = IdentifiedError(message: error.localizedDescription)
                }
            }
        }
    }

    private func paste(_ clip: FileClipboard.Payload, into destDir: String, destContainer: String) throws {
        for item in clip.items {
            if Self.wouldNest(source: item.path, inside: destDir) {
                throw FileServiceError.operationFailed("Can't paste a folder into itself.")
            }
        }
        if clip.containerPath == destContainer {
            try escape.withHandle(for: destContainer) { _ in
                try self.transferSameContainer(clip, destDir: destDir)
            }
            return
        }

        let staging = FileManager.default.temporaryDirectory
            .appendingPathComponent("escapeos-clip-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: staging) }

        try escape.withHandle(for: clip.containerPath) { _ in
            for item in clip.items {
                try self.files.copyItem(
                    at: item.path,
                    to: staging.appendingPathComponent(item.name).path
                )
            }
        }
        try escape.withHandle(for: destContainer) { _ in
            for item in clip.items {
                let dest = self.files.uniqueDestination(in: destDir, preferredName: item.name)
                try self.files.copyItem(
                    at: staging.appendingPathComponent(item.name).path,
                    to: dest
                )
            }
        }
        if clip.mode == .cut {
            try escape.withHandle(for: clip.containerPath) { _ in
                for item in clip.items {
                    try self.files.deleteItem(at: item.path)
                }
            }
        }
    }

    private func transferSameContainer(_ clip: FileClipboard.Payload, destDir: String) throws {
        let destNorm = (destDir as NSString).standardizingPath
        for item in clip.items {
            let parent = ((item.path as NSString).deletingLastPathComponent as NSString).standardizingPath
            if clip.mode == .cut && parent == destNorm {
                continue
            }
            let dest = files.uniqueDestination(in: destDir, preferredName: item.name)
            if clip.mode == .cut {
                try files.moveItem(at: item.path, to: dest)
            } else {
                try files.copyItem(at: item.path, to: dest)
            }
        }
    }

    private static func wouldNest(source: String, inside destDir: String) -> Bool {
        let src = (source as NSString).standardizingPath
        let dest = (destDir as NSString).standardizingPath
        return dest == src || dest.hasPrefix(src + "/")
    }

    func duplicate(item: FileItem) {
        duplicate(items: [item])
    }

    func duplicate(items: [FileItem]) {
        guard !items.isEmpty else { return }
        mutate {
            for item in items {
                let parent = (item.path as NSString).deletingLastPathComponent
                let ns = item.name as NSString
                let ext = ns.pathExtension
                let base = ns.deletingPathExtension
                let preferred = ext.isEmpty ? "\(item.name) copy" : "\(base) copy.\(ext)"
                let dest = self.files.uniqueDestination(in: parent, preferredName: preferred)
                try self.files.copyItem(at: item.path, to: dest)
            }
        }
    }

    func importFiles(from urls: [URL]) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try self.escape.withHandle(for: self.app.containerPath) { _ in
                    for url in urls {
                        let accessing = url.startAccessingSecurityScopedResource()
                        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
                        let data = try Data(contentsOf: url)
                        let dest = self.files.uniqueDestination(
                            in: self.currentPath,
                            preferredName: url.lastPathComponent
                        )
                        try self.files.writeFile(data: data, to: dest)
                    }
                }
                DispatchQueue.main.async {
                    self.open(self.currentPath)
                }
            } catch {
                DispatchQueue.main.async {
                    self.operationError = IdentifiedError(message: error.localizedDescription)
                }
            }
        }
    }

    func export(item: FileItem) {
        isExporting = true
        exportError = nil
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let data = try self.escape.withHandle(for: self.app.containerPath) { _ in
                    try self.files.readFile(at: item.path)
                }
                let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                let safeName = item.name.replacingOccurrences(of: "/", with: "_")
                let dest = docs.appendingPathComponent("shared_\(safeName)")
                if FileManager.default.fileExists(atPath: dest.path) {
                    try FileManager.default.removeItem(at: dest)
                }
                try data.write(to: dest, options: .atomic)
                DispatchQueue.main.async {
                    self.isExporting = false
                    self.sharePayload = SharePayload(url: dest)
                }
            } catch {
                DispatchQueue.main.async {
                    self.isExporting = false
                    self.exportError = IdentifiedError(message: error.localizedDescription)
                }
            }
        }
    }

    private func mutate(_ body: @escaping () throws -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try self.escape.withHandle(for: self.app.containerPath) { _ in
                    try body()
                }
                DispatchQueue.main.async {
                    self.open(self.currentPath)
                }
            } catch {
                DispatchQueue.main.async {
                    self.operationError = IdentifiedError(message: error.localizedDescription)
                }
            }
        }
    }
}

struct SharePayload: Identifiable {
    let id = UUID()
    let url: URL
}

struct IdentifiedError: Identifiable {
    let id = UUID()
    let message: String
}

struct ActivityShareView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
