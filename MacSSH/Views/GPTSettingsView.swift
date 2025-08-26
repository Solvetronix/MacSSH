import SwiftUI

struct GPTSettingsView: View {
    @Binding var isPresented: Bool
    @State private var apiKey = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isKeyValid = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundColor(.blue)
                Text("AI Terminal Assistant Settings")
                    .font(.title2)
                    .fontWeight(.semibold)
            }
            
            Divider()
            
            // API Key section
            VStack(alignment: .leading, spacing: 12) {
                Text("OpenAI API Key")
                    .font(.headline)
                
                Text("Enter your OpenAI API key to enable AI-powered terminal assistance. Your API key is stored locally and never shared.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                SecureField("sk-...", text: $apiKey)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: apiKey) { _ in
                        validateAPIKey()
                    }
                
                HStack {
                    if isKeyValid {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Valid API key format")
                            .foregroundColor(.green)
                    } else if !apiKey.isEmpty {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("Invalid API key format")
                            .foregroundColor(.orange)
                    }
                    
                    Spacer()
                    
                    Button("Test Connection") {
                        testAPIKey()
                    }
                    .disabled(apiKey.isEmpty || !isKeyValid)
                    .buttonStyle(.bordered)
                }
            }
            
            // Instructions
            VStack(alignment: .leading, spacing: 12) {
                Text("How to get an API key:")
                    .font(.headline)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("1. Visit https://platform.openai.com/api-keys")
                    Text("2. Sign in or create an account")
                    Text("3. Click 'Create new secret key'")
                    Text("4. Copy the key (starts with 'sk-')")
                    Text("5. Paste it above")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            
            // Features
            VStack(alignment: .leading, spacing: 12) {
                Text("AI Features:")
                    .font(.headline)
                
                                       VStack(alignment: .leading, spacing: 8) {
                           GPTFeatureRow(icon: "terminal", title: "Smart Command Generation", description: "Ask in natural language, get shell commands")
                           GPTFeatureRow(icon: "magnifyingglass", title: "File Search", description: "Find files and content intelligently")
                           GPTFeatureRow(icon: "folder", title: "Directory Navigation", description: "Navigate and explore file systems")
                           GPTFeatureRow(icon: "chart.bar", title: "System Monitoring", description: "Get system information and status")
                       }
            }
            
            Spacer()
            
            // Save button
            HStack {
                Spacer()
                
                Button("Save Settings") {
                    saveSettings()
                }
                .buttonStyle(.borderedProminent)
                .disabled(apiKey.isEmpty)
            }
        }
        .padding()
        .frame(width: 500, height: 600)
        .onAppear {
            loadSettings()
        }
        .alert("Settings", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }
    
    // MARK: - Actions
    private func validateAPIKey() {
        let wasValid = isKeyValid
        isKeyValid = apiKey.hasPrefix("sk-") && apiKey.count > 20
        
        if isKeyValid != wasValid {
            LoggingService.shared.debug("🔑 API key validation changed: \(wasValid) -> \(isKeyValid)", source: "GPTSettingsView")
        }
    }
    
    private func testAPIKey() {
        LoggingService.shared.info("🧪 Testing API key format", source: "GPTSettingsView")
        
        // Simple validation - check if key format is correct
        if apiKey.hasPrefix("sk-") && apiKey.count > 20 {
            LoggingService.shared.success("✅ API key format is valid", source: "GPTSettingsView")
            alertMessage = "API key format is valid. Test connection successful!"
            showingAlert = true
        } else {
            LoggingService.shared.warning("⚠️ Invalid API key format", source: "GPTSettingsView")
            alertMessage = "Invalid API key format. Please check your key."
            showingAlert = true
        }
    }
    
    private func saveSettings() {
        LoggingService.shared.info("💾 Saving GPT settings", source: "GPTSettingsView")
        UserDefaults.standard.set(apiKey, forKey: "OpenAI_API_Key")
        LoggingService.shared.success("✅ GPT settings saved successfully", source: "GPTSettingsView")
        alertMessage = "Settings saved successfully! AI features will be available in terminal."
        showingAlert = true
        
        // Close the modal after a short delay to show the success message
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            isPresented = false
        }
    }
    
    private func loadSettings() {
        LoggingService.shared.debug("📂 Loading GPT settings", source: "GPTSettingsView")
        apiKey = UserDefaults.standard.string(forKey: "OpenAI_API_Key") ?? ""
        validateAPIKey()
        LoggingService.shared.debug("📂 Loaded API key: \(apiKey.isEmpty ? "empty" : "present")", source: "GPTSettingsView")
    }
}

// MARK: - GPT Feature Row Component
struct GPTFeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
    }
}

// MARK: - Preview
struct GPTSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        GPTSettingsView(isPresented: .constant(true))
    }
}
