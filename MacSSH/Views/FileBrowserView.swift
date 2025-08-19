import SwiftUI

struct FileBrowserView: View {
    @ObservedObject var viewModel: ProfileViewModel
    
    private var profile: Profile? {
        viewModel.fileBrowserProfile
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if viewModel.fileBrowserProfile == nil {
                VStack {
                    Text("Loading...")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Header
                FileBrowserHeader(viewModel: viewModel)
                
                Divider()
                
                // File List
                FileBrowserContent(viewModel: viewModel)
            }
        }
        .frame(minWidth: 600, minHeight: 400)
    }
}

struct FileBrowserHeader: View {
    @ObservedObject var viewModel: ProfileViewModel
    @State private var pathInput: String = ""
    
    private var profile: Profile? {
        viewModel.fileBrowserProfile
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("File Browser")
                    .font(.headline)
                if let profile = profile {
                    Text("\(profile.name) (\(profile.host))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } else {
                    Text("Loading...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            HStack(spacing: 12) {
                // Editable path field
                TextField("Path", text: $pathInput, onCommit: {
                    guard let profile = profile else { return }
                    let trimmed = pathInput.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty && trimmed != viewModel.currentDirectory {
                        let timestamp = Date().timeIntervalSince1970
                        print("🎯 [\(timestamp)] TextField navigation to: \(trimmed) (current: \(viewModel.currentDirectory))")
                        Task { await viewModel.navigateToDirectory(profile, path: trimmed) }
                    } else {
                        let timestamp = Date().timeIntervalSince1970
                        print("🎯 [\(timestamp)] TextField navigation SKIPPED: \(trimmed) (same as current: \(viewModel.currentDirectory))")
                    }
                })
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .font(.system(.body, design: .monospaced))
                .frame(minWidth: 320)
                .disabled(viewModel.isBrowsingFiles)
                
                // Parent directory button
                if let profile = profile {
                    Button(action: {
                        let timestamp = Date().timeIntervalSince1970
                        print("🎯 [\(timestamp)] Parent directory button clicked")
                        Task {
                            await viewModel.navigateToParentDirectory(profile)
                        }
                    }) {
                        Image(systemName: "arrow.up")
                            .help("Go to parent directory")
                    }
                    .disabled(!viewModel.canNavigateToParent() || viewModel.isBrowsingFiles)
                    
                    // Refresh button
                    Button(action: {
                        let timestamp = Date().timeIntervalSince1970
                        print("🎯 [\(timestamp)] Refresh button clicked, current dir: \(viewModel.currentDirectory)")
                        Task {
                            await viewModel.navigateToDirectory(profile, path: viewModel.currentDirectory)
                        }
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .help("Refresh")
                    }
                    .disabled(viewModel.isBrowsingFiles)
                }
                

            }
        }
        .padding()
        .onAppear {
            // Initialize with the current directory
            self.pathInput = viewModel.currentDirectory
        }
        .onChange(of: viewModel.currentDirectory) { _ in
            // Keep the input in sync when navigation happens elsewhere
            self.pathInput = viewModel.currentDirectory
        }
    }
}

struct FileBrowserContent: View {
    @ObservedObject var viewModel: ProfileViewModel
    
    private var profile: Profile? {
        viewModel.fileBrowserProfile
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if viewModel.isBrowsingFiles {
                ProgressView("Loading files...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.remoteFiles.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "folder")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("No files found")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Table(viewModel.remoteFiles, selection: $viewModel.selectedFileID) {
                                    TableColumn("Name") { file in
                    HStack {
                        Image(systemName: file.isDirectory ? "folder" : "doc")
                            .foregroundColor(file.isDirectory ? .blue : .primary)
                        Text(file.name)
                            .font(.system(.body, design: .monospaced))
                    }
                    .onTapGesture(count: 2) {
                        if let profile = profile, file.isDirectory {
                            let timestamp = Date().timeIntervalSince1970
                            print("🎯 [\(timestamp)] Double-tap navigation to: \(file.path)")
                            Task { await viewModel.navigateToDirectory(profile, path: file.path) }
                        }
                    }
                }
                    
                    TableColumn("Size") { file in
                        if let size = file.size {
                            Text(formatFileSize(size))
                                .font(.system(.body, design: .monospaced))
                        } else {
                            Text("—")
                                .foregroundColor(.secondary)
                        }
                    }
                    .width(100)
                    
                    TableColumn("Permissions") { file in
                        if let permissions = file.permissions {
                            Text(permissions)
                                .font(.system(.caption, design: .monospaced))
                        } else {
                            Text("—")
                                .foregroundColor(.secondary)
                        }
                    }
                    .width(100)
                    
                    TableColumn("Modified") { file in
                        if let date = file.modifiedDate {
                            Text(date, style: .date)
                                + Text(" ") + Text(date, style: .time)
                        } else {
                            Text("—")
                                .foregroundColor(.secondary)
                        }
                    }
                    .width(150)
                    
                    TableColumn("Actions") { file in
                        FileActionsCell(file: file, viewModel: viewModel)
                    }
                    .width(120)
                }
            }
        }
        .alert("File Browser Error", isPresented: .constant(viewModel.fileBrowserError != nil)) {
            Button("OK") {
                viewModel.fileBrowserError = nil
            }
        } message: {
            if let error = viewModel.fileBrowserError {
                Text(error)
            }
        }
    }
    
    private func handleFileAction(_ file: RemoteFile) {
        guard let profile = profile else { return }
        
        if file.isDirectory {
            Task {
                await viewModel.navigateToDirectory(profile, path: file.path)
            }
        } else {
            Task {
                await viewModel.openFileInFinder(profile, file: file)
            }
        }
    }
    
    private func formatFileSize(_ size: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
}

struct FileActionsCell: View {
    let file: RemoteFile
    @ObservedObject var viewModel: ProfileViewModel
    
    private var profile: Profile? {
        viewModel.fileBrowserProfile
    }
    
    var body: some View {
        HStack(spacing: 8) {
            if let profile = profile {
                if file.isDirectory {
                    Button(action: {
                        let timestamp = Date().timeIntervalSince1970
                        print("🎯 [\(timestamp)] Button navigation to: \(file.path)")
                        Task {
                            await viewModel.navigateToDirectory(profile, path: file.path)
                        }
                    }) {
                        Image(systemName: "folder")
                            .help("Open directory")
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(viewModel.isBrowsingFiles)
                } else {
                    // Кнопка для открытия в VS Code
                    Button(action: {
                        Task {
                            await viewModel.openFileInVSCode(profile, file: file)
                        }
                    }) {
                        Image(systemName: "doc.text")
                            .help("Open in VS Code/Cursor")
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(viewModel.isConnecting)
                    
                    // Кнопка для открытия в Finder
                    Button(action: {
                        Task {
                            await viewModel.openFileInFinder(profile, file: file)
                        }
                    }) {
                        Image(systemName: "doc")
                            .help("Download and Open in Finder")
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(viewModel.isConnecting)
                }
            }
        }
    }
}

#Preview {
    FileBrowserView(viewModel: ProfileViewModel())
}
