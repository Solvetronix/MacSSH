import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = ProfileViewModel()
    @State private var showingAddProfile = false
    @State private var selectedProfile: Profile?
    @State private var showingToolsInfo = false
    
    var body: some View {
        NavigationSplitView {
            ConnectionListView(
                viewModel: viewModel,
                showingAddProfile: $showingAddProfile,
                selectedProfile: $selectedProfile,
                showingToolsInfo: $showingToolsInfo
            )
            .frame(minWidth: 400, idealWidth: 500)
        } detail: {
            LogView(viewModel: viewModel)
                .frame(minWidth: 300, idealWidth: 400)
        }
        .navigationSplitViewStyle(.balanced)
        .sheet(isPresented: $showingAddProfile) {
            ProfileFormView(viewModel: viewModel)
        }
        .sheet(item: $selectedProfile) { profile in
            ProfileFormView(viewModel: viewModel, editingProfile: profile)
        }
        .sheet(isPresented: $showingToolsInfo) {
            ToolsInfoView()
        }
    }
}

struct ConnectionListView: View {
    @ObservedObject var viewModel: ProfileViewModel
    @Binding var showingAddProfile: Bool
    @Binding var selectedProfile: Profile?
    @Binding var showingToolsInfo: Bool
    @State private var profileToDelete: Profile? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Table(viewModel.profiles) {
                TableColumn("Name") { profile in
                    ConnectionNameCell(profile: profile)
                }
                
                TableColumn("") { profile in
                    ConnectionActionsCell(
                        profile: profile,
                        viewModel: viewModel,
                        selectedProfile: $selectedProfile,
                        profileToDelete: $profileToDelete
                    )
                }
                .width(160)
                
                TableColumn("Host") { profile in
                    ConnectionHostCell(profile: profile)
                }
                TableColumn("Port") { profile in
                    ConnectionPortCell(profile: profile)
                }
                TableColumn("Username") { profile in
                    ConnectionUsernameCell(profile: profile)
                }
                TableColumn("Auth") { profile in
                    ConnectionAuthCell(profile: profile)
                }
                TableColumn("Last Connection") { profile in
                    ConnectionLastCell(profile: profile)
                }
            }
            .frame(minHeight: 200)
        }
        .navigationTitle("MacSSH Terminal")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: 12) {
                    Button(action: { showingToolsInfo = true }) {
                        Image(systemName: "info.circle")
                    }
                    .help("Tools Information")
                    
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
    @State private var showingFileBrowser = false
    
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
            
            Button(action: { showingFileBrowser = true }) {
                HoverableIcon(systemName: "folder", help: "Open File Browser")
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(viewModel.isConnecting)
        }
        .sheet(isPresented: $showingFileBrowser) {
            FileBrowserView(viewModel: viewModel, profile: profile)
        }
    }
}

struct LogView: View {
    @ObservedObject var viewModel: ProfileViewModel
    @State private var showCopyAlert = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            LogToolbar(viewModel: viewModel, showCopyAlert: $showCopyAlert)
            LogContent(viewModel: viewModel)
        }
        .alert("Connection Error", isPresented: .constant(viewModel.connectionError != nil)) {
            Button("OK") {
                viewModel.connectionError = nil
            }
        } message: {
            if let error = viewModel.connectionError {
                ScrollView { Text(error).textSelection(.enabled) }
            }
        }
        .onReceive(viewModel.objectWillChange) { _ in
            print("DEBUG: ViewModel changed, log count: \(viewModel.connectionLog.count)")
        }
    }
}

struct LogToolbar: View {
    @ObservedObject var viewModel: ProfileViewModel
    @Binding var showCopyAlert: Bool
    
    var body: some View {
        HStack {
            Button(action: {
                let logText = viewModel.connectionLog.joined(separator: "\n")
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
                viewModel.connectionLog.removeAll()
            }) {
                Image(systemName: "trash")
            }
            .help("Clear operation log")
            .disabled(viewModel.isConnecting)
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .padding(.bottom, 6)
        Divider()
    }
}

struct LogContent: View {
    @ObservedObject var viewModel: ProfileViewModel
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(viewModel.connectionLog.indices, id: \.self) { idx in
                        LogMessageView(message: viewModel.connectionLog[idx])
                            .id(idx)
                    }
                }
                .padding(.bottom)
            }
            .background(Color(NSColor.textBackgroundColor))
            .onChange(of: viewModel.connectionLog.count) { _, newCount in
                print("DEBUG: Log count changed to \(newCount)")
                if let last = viewModel.connectionLog.indices.last {
                    withAnimation { proxy.scrollTo(last, anchor: .bottom) }
                }
            }
            .onAppear {
                print("DEBUG: LogContent appeared, log count: \(viewModel.connectionLog.count)")
            }
        }
        .frame(minHeight: 120, maxHeight: .infinity)
        .padding(.bottom)
    }
}

struct LogMessageView: View {
    let message: String
    
    var body: some View {
        let color: Color = getMessageColor(message)
        let cleanMsg = cleanMessage(message)
        
        return Text(cleanMsg)
            .font(.system(size: 13, design: .monospaced))
            .foregroundColor(color)
            .textSelection(.enabled)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
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
        } else {
            return .primary
        }
    }
    
    private func cleanMessage(_ message: String) -> String {
        return message
            .replacingOccurrences(of: "[green]", with: "")
            .replacingOccurrences(of: "[yellow]", with: "")
            .replacingOccurrences(of: "[blue]", with: "")
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

#Preview {
    ContentView()
} 
