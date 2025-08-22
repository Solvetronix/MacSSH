import SwiftUI

struct ToolsInfoView: View {
    @State private var toolsAvailability: (sshpass: Bool, sshfs: Bool, vscode: Bool) = (false, false, false)
    @State private var permissionsCheck: [String] = []
    @State private var showingPermissionsCheck = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Required Tools")
                .font(.title2)
                .fontWeight(.bold)
            
            VStack(alignment: .leading, spacing: 16) {
                ToolStatusRow(
                    name: "sshpass",
                    description: "For password-based authentication",
                    isAvailable: toolsAvailability.sshpass,
                    installCommand: "brew install sshpass"
                )
                
                ToolStatusRow(
                    name: "sshfs",
                    description: "For mounting remote directories in Finder",
                    isAvailable: toolsAvailability.sshfs,
                    installCommand: "brew install --cask macfuse && brew install sshfs"
                )
                
                ToolStatusRow(
                    name: "VS Code/Cursor",
                    description: "For editing files with automatic sync",
                    isAvailable: toolsAvailability.vscode,
                    installCommand: "Download VS Code from https://code.visualstudio.com/ or Cursor from https://cursor.sh/"
                )
            }
            
            VStack(spacing: 12) {
                Text("Installation Instructions")
                    .font(.headline)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("1. Install Homebrew if not already installed:")
                        .font(.caption)
                    Text("   /bin/bash -c \"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\"")
                        .font(.system(.caption, design: .monospaced))
                        .padding(.leading, 16)
                        .padding(.vertical, 4)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(4)
                    
                    Text("2. Install required tools:")
                        .font(.caption)
                    Text("   brew install sshpass")
                        .font(.system(.caption, design: .monospaced))
                        .padding(.leading, 16)
                        .padding(.vertical, 4)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(4)
                    
                    Text("3. Install SSHFS (optional, for mounting directories):")
                        .font(.caption)
                    Text("   brew install --cask macfuse")
                        .font(.system(.caption, design: .monospaced))
                        .padding(.leading, 16)
                        .padding(.vertical, 4)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(4)
                    Text("   brew install sshfs")
                        .font(.system(.caption, design: .monospaced))
                        .padding(.leading, 16)
                        .padding(.vertical, 4)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(4)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.05))
            .cornerRadius(8)
            
            Spacer()
            
            HStack {
                Button("Check Permissions") {
                    permissionsCheck = SSHService.checkAllPermissions()
                    showingPermissionsCheck = true
                }
                .buttonStyle(.borderedProminent)
                
                Button("Refresh") {
                    toolsAvailability = SSHService.checkToolsAvailability()
                }
                
                Spacer()
                
                Button("Close") {
                    dismiss()
                }
            }
        }
        .padding()
        .frame(width: 500, height: 400)
        .onAppear {
            toolsAvailability = SSHService.checkToolsAvailability()
        }
        .sheet(isPresented: $showingPermissionsCheck) {
            PermissionsCheckView(permissionsCheck: permissionsCheck)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }
}

struct ToolStatusRow: View {
    let name: String
    let description: String
    let isAvailable: Bool
    let installCommand: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isAvailable ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(isAvailable ? .green : .red)
                .font(.title2)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(name)
                        .font(.headline)
                    if !isAvailable {
                        Text("(Not installed)")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if !isAvailable {
                    Text("Install: \(installCommand)")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.blue)
                        .padding(.top, 2)
                }
            }
            
            Spacer()
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }
}

struct PermissionsCheckView: View {
    let permissionsCheck: [String]
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Permissions Check Results")
                .font(.title2)
                .fontWeight(.bold)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(permissionsCheck, id: \.self) { line in
                        Text(line)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(line.contains("❌") ? .red : 
                                           line.contains("✅") ? .green : 
                                           line.contains("⚠️") ? .orange : 
                                           line.contains("===") ? .blue : .primary)
                    }
                }
                .padding()
            }
            .frame(maxHeight: 400)
            
            Button("Close") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(width: 600, height: 500)
    }
}

#Preview {
    ToolsInfoView()
}
