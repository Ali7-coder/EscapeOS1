import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// Filza-style file browser for a single app container.
struct FileBrowserView: View {
    let app: InstalledApp

    @StateObject private var vm: FileBrowserViewModel
    @State private var createKind: CreateKind?
    @State private var createName = ""
    @State private var renameItem: FileItem?
    @State private var renameName = ""
    @State private var deleteItem: FileItem?
    @State private var searchText = ""
    @State private var openRequest: OpenRequest?
    @State private var propertiesItem: FileItem?
    @State private var showImporter = false

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
        .navigationTitle(vm.displayTitle)
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Filter this folder")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack {
                    if vm.canGoUp {
                        Button("Up") { vm.goUp() }
                    }
                    Menu {
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
        .alert("Delete \(deleteItem?.name ?? "item")?", isPresented: Binding(
            get: { deleteItem != nil },
            set: { if !$0 { deleteItem = nil } }
        )) {
            Button("Cancel", role: .cancel) { deleteItem = nil }
            Button("Delete", role: .destructive) {
                if let item = deleteItem {
                    vm.delete(item: item)
                }
                deleteItem = nil
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

    private var fileList: some View {
        List {
            ForEach(visibleItems) { item in
                if item.isDirectory {
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
            .onDelete { offsets in
                let snapshot = visibleItems
                for index in offsets where index < snapshot.count {
                    deleteItem = snapshot[index]
                }
            }
        }
        .refreshable {
            vm.open(vm.currentPath)
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
            deleteItem = item
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

    var canGoUp: Bool {
        currentPath != app.containerPath && currentPath != "/"
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

    func goUp() {
        let parent = (currentPath as NSString).deletingLastPathComponent
        open(parent.isEmpty ? "/" : parent)
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
        mutate {
            try self.files.deleteItem(at: item.path)
        }
    }

    func duplicate(item: FileItem) {
        mutate {
            let parent = (item.path as NSString).deletingLastPathComponent
            let ns = item.name as NSString
            let ext = ns.pathExtension
            let base = ns.deletingPathExtension
            let preferred = ext.isEmpty ? "\(item.name) copy" : "\(base) copy.\(ext)"
            let dest = self.files.uniqueDestination(in: parent, preferredName: preferred)
            try self.files.copyItem(at: item.path, to: dest)
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
