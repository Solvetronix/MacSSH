import SwiftUI

struct UpdateView: View {
    let updateInfo: UpdateInfo
    @State private var isDownloading = false
    @State private var downloadProgress: Double = 0.0
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
            
            // Download progress
            if isDownloading {
                VStack(spacing: 8) {
                    ProgressView(value: downloadProgress)
                        .progressViewStyle(LinearProgressViewStyle())
                    
                    Text("Downloading update... \(Int(downloadProgress * 100))%")
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
                
                Spacer()
                
                Button("Download & Install") {
                    downloadAndInstall()
                }
                .buttonStyle(.borderedProminent)
                .disabled(isDownloading)
                
                Button("View on GitHub") {
                    UpdateService.openGitHubReleases()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(24)
        .frame(width: 500)
        .alert("Download Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func downloadAndInstall() {
        isDownloading = true
        downloadProgress = 0.0
        
        Task {
            do {
                // Simulate download progress
                for i in 1...10 {
                    try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
                    await MainActor.run {
                        downloadProgress = Double(i) / 10.0
                    }
                }
                
                // Download the update
                guard let downloadedURL = await UpdateService.downloadUpdate(from: updateInfo.downloadUrl) else {
                    await MainActor.run {
                        errorMessage = "Failed to download the update. Please try again."
                        showError = true
                        isDownloading = false
                    }
                    return
                }
                
                // Install the update
                let success = await UpdateService.installUpdate(from: downloadedURL)
                
                await MainActor.run {
                    isDownloading = false
                    
                    if success {
                        dismiss()
                    } else {
                        errorMessage = "Failed to install the update. Please install it manually."
                        showError = true
                    }
                }
                
            } catch {
                await MainActor.run {
                    errorMessage = "An error occurred: \(error.localizedDescription)"
                    showError = true
                    isDownloading = false
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
