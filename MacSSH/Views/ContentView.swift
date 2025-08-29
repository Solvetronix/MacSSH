import SwiftUI

struct ContentView: View {
    @EnvironmentObject var viewModel: ProfileViewModel
    @State private var showingAddProfile = false
    @State private var selectedProfile: Profile?
    @State private var showingPermissionsManager = false
    
    var body: some View {
        NavigationSplitView {
            ConnectionListView(
                viewModel: viewModel,
                showingAddProfile: $showingAddProfile,
                selectedProfile: $selectedProfile,
                showingPermissionsManager: $showingPermissionsManager
            )
            .frame(minWidth: 400, idealWidth: 500)
        } detail: {
            LogView(viewModel: viewModel)
                .frame(minWidth: 300, idealWidth: 400)
        }
        .navigationSplitViewStyle(.balanced)
        .sheet(isPresented: $showingAddProfile) {
            ProfileFormView(viewModel: viewModel)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $selectedProfile) { profile in
            ProfileFormView(viewModel: viewModel, editingProfile: profile)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingPermissionsManager) {
            PermissionsManagerView()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $viewModel.showingPermissionsManager) {
            PermissionsManagerView()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }

        // Sparkle handles update UI automatically - no need for custom sheet
        .alert("Permissions Required", isPresented: $viewModel.showingPermissionsWarning) {
            Button("Open Permissions Manager") {
                viewModel.showingPermissionsManager = true
                viewModel.showingPermissionsWarning = false
            }
            Button("Remind Me Later") {
                viewModel.showingPermissionsWarning = false
            }
            Button("Don't Show Again", role: .cancel) {
                viewModel.showingPermissionsWarning = false
                UserDefaults.standard.set(true, forKey: "hasDeclinedPermissionsWarning")
            }
        } message: {
            Text("MacSSH requires special permissions to execute external commands (ssh, sftp, scp). Please configure permissions to use all features.")
        }
    }
}

struct ConnectionListView: View {
    @ObservedObject var viewModel: ProfileViewModel
    @Binding var showingAddProfile: Bool
    @Binding var selectedProfile: Profile?
    @Binding var showingPermissionsManager: Bool
    @State private var profileToDelete: Profile? = nil
    @State private var showingAboutDialog = false
    @State private var showingGPTSettings = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Table(viewModel.profiles) {
                TableColumn("Name") { profile in
                    ConnectionNameCell(profile: profile)
                }
                
                TableColumn("Host") { profile in
                    ConnectionHostCell(profile: profile)
                }
                
                TableColumn("Port") { profile in
                    ConnectionPortCell(profile: profile)
                }
                .width(min: 30, ideal: 35)
                
                TableColumn("Options") { profile in
                    ConnectionActionsCell(
                        profile: profile,
                        viewModel: viewModel,
                        selectedProfile: $selectedProfile,
                        profileToDelete: $profileToDelete
                    )
                }
                .width(200)
            }
            .frame(minHeight: 200)
        }
        .navigationTitle("MacSSH Terminal")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: 12) {
                    Menu {
                        Button("Check for Updates") {
                            Task {
                                await viewModel.forceCheckForUpdates()
                            }
                        }
                        .disabled(viewModel.isCheckingForUpdates)
                        
                        Button("View on GitHub") {
                            viewModel.openGitHubReleases()
                        }
                        
                        Divider()
                        
                        Button("About MacSSH") {
                            showingAboutDialog = true
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .help("More Options")
                    
                    Button(action: { showingPermissionsManager = true }) {
                        Image(systemName: "lock.shield")
                    }
                    .help("macOS Permissions Manager")
                    
                    Button(action: { showingGPTSettings = true }) {
                        Image(systemName: "brain.head.profile")
                    }
                    .help("AI Terminal Assistant Settings")
                    
                    Button(action: { showingAddProfile = true }) {
                        Image(systemName: "plus")
                    }.disabled(viewModel.isConnecting)
                }
            }
        }
        .alert("Are you sure you want to delete this connection?", isPresented: Binding<Bool>(
            get: { profileToDelete != nil },
            set: { if !$0 { profileToDelete = nil } }
        ), actions: {
            Button("Cancel", role: .cancel) { profileToDelete = nil }
            Button("Delete", role: .destructive) {
                if let profile = profileToDelete {
                    viewModel.deleteProfile(profile)
                    profileToDelete = nil
                }
            }
        }, message: {
            Text("This action cannot be undone.")
        })
        .sheet(isPresented: $showingAboutDialog) {
            AboutView(viewModel: viewModel)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingGPTSettings) {
            GPTSettingsView(isPresented: $showingGPTSettings)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }
}

struct ConnectionNameCell: View {
    let profile: Profile
    
    var body: some View {
        Text(profile.name)
            .font(.headline)
    }
}

struct ConnectionHostCell: View {
    let profile: Profile
    
    var body: some View {
        Text(profile.host)
            .font(.system(.body, design: .monospaced))
    }
}

struct ConnectionPortCell: View {
    let profile: Profile
    
    var body: some View {
        Text("\(profile.port)")
            .font(.system(.body, design: .monospaced))
    }
}

struct ConnectionUsernameCell: View {
    let profile: Profile
    
    var body: some View {
        Text(profile.username)
            .font(.system(.body, design: .monospaced))
    }
}

struct ConnectionAuthCell: View {
    let profile: Profile
    
    var body: some View {
        HStack {
            Image(systemName: profile.keyType == .password ? "key.fill" : "key")
                .foregroundColor(profile.keyType == .password ? .orange : .green)
            Text(profile.keyType.rawValue)
                .font(.caption)
        }
    }
}

struct ConnectionLastCell: View {
    let profile: Profile
    
    var body: some View {
        if let date = profile.lastConnectionDate {
            Text(date, style: .date)
                + Text(" ") + Text(date, style: .time)
        } else {
            Text("—")
        }
    }
}

struct ConnectionActionsCell: View {
    let profile: Profile
    @ObservedObject var viewModel: ProfileViewModel
    @Binding var selectedProfile: Profile?
    @Binding var profileToDelete: Profile?
    @Environment(\.openWindow) private var openWindow
    
    var body: some View {
        HStack(spacing: 12) {
            Button(action: { selectedProfile = profile }) {
                HoverableIcon(systemName: "pencil", help: "Edit")
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(viewModel.isConnecting)
            
            Button(action: { profileToDelete = profile }) {
                HoverableIcon(systemName: "trash", help: "Delete")
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(viewModel.isConnecting)
            
            Button(action: {
                Task { await viewModel.testConnection(profile) }
            }) {
                HoverableIcon(systemName: "network", help: "Test Connection & Open Terminal")
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(viewModel.isConnecting)
            
            Button(action: {
                viewModel.openProfessionalTerminal(for: profile)
            }) {
                HoverableIcon(systemName: "terminal", help: "Open Professional Terminal")
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(viewModel.isConnecting)
            
            Button(action: { 
                let timestamp = Date().timeIntervalSince1970
                print("🕐 [\(timestamp)] Button: Opening file browser for profile: \(profile.name) (\(profile.host))")
                Task {
                    print("🕐 [\(timestamp)] Button: Setting fileBrowserProfile to: \(profile.name)")
                    
                    print("🕐 [\(timestamp)] Button: About to open window")
                    // Устанавливаем профиль в менеджере и открываем новое окно
                    WindowManager.shared.openFileBrowser(for: profile)
                    openWindow(id: "fileBrowser")
                    print("🕐 [\(timestamp)] Button: Window opened")
                }
            }) {
                HoverableIcon(systemName: "folder", help: "Open File Browser")
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(viewModel.isConnecting)
        }
    }
}

struct LogView: View {
    @ObservedObject var viewModel: ProfileViewModel
    @State private var showCopyAlert = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            LogToolbar(showCopyAlert: $showCopyAlert)
            LogContent()
        }
        .background(Color(NSColor.controlBackgroundColor))
        .alert("Connection Error", isPresented: .constant(viewModel.connectionError != nil)) {
            Button("OK") {
                viewModel.connectionError = nil
            }
        } message: {
            if let error = viewModel.connectionError {
                ScrollView { Text(error).textSelection(.enabled) }
            }
        }
    }
}

struct LogToolbar: View {
    @ObservedObject var loggingService = LoggingService.shared
    @Binding var showCopyAlert: Bool
    
    var body: some View {
        HStack {
            Button(action: {
                let logText = loggingService.getLogsAsText()
                #if os(macOS)
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(logText, forType: .string)
                #else
                UIPasteboard.general.string = logText
                #endif
                showCopyAlert = true
            }) {
                Image(systemName: "doc.on.doc")
            }
            .help("Copy all log to clipboard")
            .alert("Log copied", isPresented: $showCopyAlert) {
                Button("OK", role: .cancel) {}
            }
            Button(action: {
                loggingService.clear()
            }) {
                Image(systemName: "trash")
            }
            .help("Clear operation log")
            
            Spacer()
            
            // Log count indicator
            Text("\(loggingService.logs.count) logs")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .padding(.bottom, 6)
        Divider()
    }
}

struct LogContent: View {
    @ObservedObject var loggingService = LoggingService.shared
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(loggingService.logs) { log in
                        LogMessageView(log: log)
                            .id(log.id)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 12)
            }
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(NSColor.textBackgroundColor))
            )
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            .onChange(of: loggingService.logs.count) { _, newCount in
                if let last = loggingService.logs.last {
                    withAnimation(.easeInOut(duration: 0.3)) { 
                        proxy.scrollTo(last.id, anchor: .bottom) 
                    }
                }
            }
        }
        .frame(minHeight: 120, maxHeight: .infinity)
    }
}

struct LogMessageView: View {
    let log: LogMessage
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // Timestamp
            Text(log.formattedTimestamp)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 60, alignment: .leading)
            
            // Message content with type prefix
            HStack(alignment: .top, spacing: 4) {
                Text(log.level.icon)
                    .font(.system(size: 12))
                    .foregroundColor(log.level.color)
                    .frame(width: 20, alignment: .leading)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(log.displayMessage)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.primary)
                        .textSelection(.enabled)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Source information
                    Text("[\(log.source)]")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                        .opacity(0.7)
                }
            }
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(log.id.hashValue % 2 == 0 ? Color.clear : Color.gray.opacity(0.03))
        )
    }
    
    private func getMessageColor(_ message: String) -> Color {
        if message.hasPrefix("[green]") {
            return .green
        } else if message.hasPrefix("[yellow]") {
            return .yellow
        } else if message.hasPrefix("[blue]") {
            return .blue
        } else if message.contains("✅") {
            return .green
        } else if message.contains("❌") {
            return .red
        } else if message.contains("ERROR") || message.contains("error") {
            return .red
        } else if message.contains("WARNING") || message.contains("warning") {
            return .orange
        } else if message.contains("INFO") || message.contains("info") {
            return .blue
        } else {
            return .primary
        }
    }
    

}

struct HoverableIcon: View {
    let systemName: String
    let help: String
    @State private var isHovered = false
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(isHovered ? Color.gray.opacity(0.18) : Color.clear)
                .frame(width: 28, height: 28)
            Image(systemName: systemName)
                .help(help)
        }
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: ProfileViewModel
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Text("About MacSSH")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button("✕") {
                    dismiss()
                }
                .buttonStyle(.plain)
                .font(.title2)
                .foregroundColor(.secondary)
                .frame(width: 30, height: 30)
                .background(Color.gray.opacity(0.1))
                .clipShape(Circle())
            }
            .padding()
            .background(Color.gray.opacity(0.05))
            
            // Content
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("MacSSH Terminal")
                        .font(.title3)
                        .fontWeight(.semibold)
                    
                    Text("Version \(viewModel.getCurrentVersion())")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Professional SSH connection manager for macOS")
                        .font(.body)
                        .fontWeight(.medium)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        FeatureRow(icon: "lock.shield", text: "Secure SSH connections with password and key authentication")
                        FeatureRow(icon: "folder", text: "Integrated file browser with SFTP support")
                        FeatureRow(icon: "chevron.left.forwardslash.chevron.right", text: "VS Code integration for remote development")
                        FeatureRow(icon: "arrow.clockwise", text: "Automatic updates via Sparkle")
                        FeatureRow(icon: "list.bullet.clipboard", text: "Centralized logging system")
                    }
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Looking for developers to help improve this app!")
                        .font(.body)
                        .foregroundColor(.blue)
                        .fontWeight(.medium)
                    
                    Text("Visit GitHub to contribute and report issues")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            
            Spacer()
        }
        .frame(width: 480, height: 400)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 16)
            
            Text(text)
                .font(.body)
                .foregroundColor(.primary)
            
            Spacer()
        }
    }
}

#Preview {
    ContentView()
} 
