import SwiftUI

struct FileBrowserView: View {
    @ObservedObject var viewModel: ProfileViewModel
    let profile: Profile
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            FileBrowserHeader(
                viewModel: viewModel,
                profile: profile,
                onClose: { dismiss() }
            )
            
            Divider()
            
            // File List
            FileBrowserContent(
                viewModel: viewModel,
                profile: profile
            )
        }
        .frame(minWidth: 600, minHeight: 400)
        .onAppear {
            Task {
                await viewModel.openFileBrowser(for: profile)
            }
        }
    }
}

struct FileBrowserHeader: View {
    @ObservedObject var viewModel: ProfileViewModel
    let profile: Profile
    let onClose: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("File Browser")
                    .font(.headline)
                Text("\(profile.name) (\(profile.host))")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 12) {
                // Path display
                Text(viewModel.getDisplayPath())
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(4)
                
                // Parent directory button
                Button(action: {
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
                    Task {
                        await viewModel.openFileBrowser(for: profile)
                    }
                }) {
                    Image(systemName: "arrow.clockwise")
                        .help("Refresh")
                }
                .disabled(viewModel.isBrowsingFiles)
                
                Button("Close") {
                    onClose()
                }
            }
        }
        .padding()
    }
}

struct FileBrowserContent: View {
    @ObservedObject var viewModel: ProfileViewModel
    let profile: Profile
    
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
                        FileActionsCell(
                            file: file,
                            viewModel: viewModel,
                            profile: profile
                        )
                    }
                    .width(80)
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
    let profile: Profile
    
    var body: some View {
        HStack(spacing: 8) {
            if file.isDirectory {
                Button(action: {
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
                Button(action: {
                    Task {
                        await viewModel.openFileInFinder(profile, file: file)
                    }
                }) {
                    Image(systemName: "doc")
                        .help("Download and Open")
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(viewModel.isConnecting)
            }
        }
    }
}

#Preview {
    FileBrowserView(
        viewModel: ProfileViewModel(),
        profile: Profile(
            name: "Test Server",
            host: "example.com",
            username: "user"
        )
    )
}
