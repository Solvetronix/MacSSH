import SwiftUI

struct UpdateView: View {
    let updateInfo: UpdateInfo
    @State private var isInstalling = false
    @State private var showError = false
    @State private var errorMessage = ""
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.blue)
                
                Text("Update Available")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Version \(updateInfo.version) is now available")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // Version comparison
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Current Version")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(UpdateService.getCurrentVersion())
                        .font(.body)
                        .fontWeight(.medium)
                }
                
                Spacer()
                
                Image(systemName: "arrow.right")
                    .foregroundColor(.secondary)
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("New Version")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(updateInfo.version)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                }
            }
            .padding()
            .background(Color(.controlBackgroundColor))
            .cornerRadius(8)
            
            // Release notes
            if !updateInfo.releaseNotes.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("What's New")
                        .font(.headline)
                    
                    ScrollView {
                        Text(updateInfo.releaseNotes)
                            .font(.body)
                            .textSelection(.enabled)
                    }
                    .frame(maxHeight: 200)
                }
            }
            
            // Installation progress
            if isInstalling {
                VStack(spacing: 8) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                    
                    Text("Installing update...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Buttons
            HStack(spacing: 12) {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                .disabled(isInstalling)
                
                Spacer()
                
                Button("Install Update") {
                    installUpdate()
                }
                .buttonStyle(.borderedProminent)
                .disabled(isInstalling)
                
                Button("View on GitHub") {
                    UpdateService.openGitHubReleases()
                }
                .buttonStyle(.bordered)
                .disabled(isInstalling)
            }
        }
        .padding(24)
        .frame(width: 500)
        .alert("Installation Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func installUpdate() {
        isInstalling = true
        
        Task {
            do {
                // Initialize Sparkle updater
                UpdateService.initializeUpdater()
                
                // Try automatic installation first
                let success = await UpdateService.installUpdate()
                
                if success {
                    // Update installed successfully, app will restart automatically
                    await MainActor.run {
                        isInstalling = false
                        dismiss()
                    }
                } else {
                    // Fallback to manual installation
                    await MainActor.run {
                        isInstalling = false
                        errorMessage = "Automatic installation failed. Please download and install the update manually from GitHub."
                        showError = true
                    }
                }
                
            } catch {
                await MainActor.run {
                    isInstalling = false
                    errorMessage = "An error occurred: \(error.localizedDescription)"
                    showError = true
                }
            }
        }
    }
}

#Preview {
    UpdateView(updateInfo: UpdateInfo(
        version: "1.1.0",
        downloadUrl: "https://example.com/MacSSH-1.1.0.dmg",
        releaseNotes: "• Bug fixes and improvements\n• New features added\n• Performance enhancements",
        isNewer: true,
        publishedAt: Date()
    ))
}
