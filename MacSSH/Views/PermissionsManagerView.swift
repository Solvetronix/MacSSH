import SwiftUI
import AppKit

struct PermissionsManagerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var permissionsCheck: [String] = []
    @State private var showingInstructions = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Заголовок
            HStack {
                Text("SSH Tools Manager")
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
            .onAppear {
                // Автоматически проверяем инструменты при открытии
                permissionsCheck = SSHService.checkAllPermissions()
                
                // Если Full Disk Access не предоставлен, показываем предупреждение
                if !PermissionsService.forceCheckPermissions() {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        PermissionsService.requestFullDiskAccess()
                    }
                }
            }
            
            // Основной контент
            ScrollView {
                VStack(spacing: 16) {
                                        // Заголовок
                    Text("SSH Tools Status")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    // Статус SSH инструментов
                    VStack(alignment: .leading, spacing: 12) {
                        if permissionsCheck.isEmpty {
                            Text("Loading tools status...")
                                .foregroundColor(.secondary)
                        } else {
                            ForEach(permissionsCheck, id: \.self) { line in
                                if line.contains("⚠️") && line.contains("Install") {
                                    // Кликабельные строки для установки
                                    Button(action: {
                                        installPackage(from: line)
                                    }) {
                                        Text(line)
                                            .font(.system(.caption, design: .monospaced))
                                            .foregroundColor(.orange)
                                            .padding(.vertical, 1)
                                    }
                                    .buttonStyle(.plain)
                                } else if line.contains("⚠️") && line.contains("Grant Full Disk Access") {
                                    // Кликабельная строка для запроса Full Disk Access
                                    Button(action: {
                                        PermissionsService.requestFullDiskAccess()
                                    }) {
                                        Text(line)
                                            .font(.system(.caption, design: .monospaced))
                                            .foregroundColor(.orange)
                                            .padding(.vertical, 1)
                                    }
                                    .buttonStyle(.plain)
                                } else {
                                    Text(line)
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundColor(line.contains("❌") ? .red : 
                                                       line.contains("✅") ? .green : 
                                                       line.contains("⚠️") ? .orange : 
                                                       line.contains("===") ? .blue : .primary)
                                        .padding(.vertical, 1)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                }
                .padding()
            }
            
            // Кнопки внизу - всегда видимые
            HStack {
                Button("Check Tools") {
                    permissionsCheck = SSHService.checkAllPermissions()
                }
                .buttonStyle(.bordered)
                
                Button("Force Check Permissions") {
                    let hasAccess = PermissionsService.forceCheckPermissions()
                    if hasAccess {
                        permissionsCheck = SSHService.checkAllPermissions()
                    } else {
                        // Показываем предупреждение
                        let alert = NSAlert()
                        alert.messageText = "Permissions Check"
                        alert.informativeText = "Full Disk Access is still not granted. Please check System Settings."
                        alert.alertStyle = .warning
                        alert.addButton(withTitle: "OK")
                        alert.runModal()
                    }
                }
                .buttonStyle(.bordered)
                
                Button("Show Instructions") {
                    showingInstructions = true
                }
                .buttonStyle(.bordered)
                
                Button("Request Full Disk Access") {
                    PermissionsService.requestFullDiskAccess()
                    // Обновляем статус после запроса
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        permissionsCheck = SSHService.checkAllPermissions()
                    }
                }
                .buttonStyle(.bordered)
                .disabled(PermissionsService.forceCheckPermissions())
                
                Button("Close") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button("Restart MacSSH") {
                    restartApplication()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .background(Color.gray.opacity(0.05))
        }
        .frame(width: 550, height: 600)
        .background(Color.white)
        .onKeyPress(.escape) {
            dismiss()
            return .handled
        }
        .sheet(isPresented: $showingInstructions) {
            DetailedInstructionsView(permissionsCheck: permissionsCheck)
        }
    }
    

    
    private func restartApplication() {
        let alert = NSAlert()
        alert.messageText = "Restart MacSSH"
        alert.informativeText = "The application will restart to apply changes. Continue?"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Restart")
        alert.addButton(withTitle: "Cancel")
        
        if alert.runModal() == .alertFirstButtonReturn {
            // Перезапускаем приложение
            let task = Process()
            task.launchPath = "/usr/bin/open"
            task.arguments = [Bundle.main.bundlePath]
            try? task.run()
            
            // Закрываем текущее приложение
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                NSApplication.shared.terminate(nil)
            }
        }
    }
    
    private func installPackage(from line: String) {
        // Извлекаем команду установки из строки
        var command = ""
        
        if line.contains("sshpass") {
            command = "brew install sshpass"
        } else if line.contains("sshfs") {
            command = "echo 'SSHFS requires MacFUSE and is not available via Homebrew on macOS. Consider using alternative tools like rclone or Cyberduck for remote file access.'"
        }
        
        if !command.isEmpty {
            // Открываем Terminal.app с командой
            let script = """
            tell application "Terminal"
                activate
                do script "\(command)"
            end tell
            """
            
            let process = Process()
            process.launchPath = "/usr/bin/osascript"
            process.arguments = ["-e", script]
            
            do {
                try process.run()
                process.waitUntilExit()
            } catch {
                print("Failed to open Terminal: \(error)")
            }
        }
    }
    
    private func checkPermissionsAfterSetup() {
        // Проверяем разрешения после настройки
        let fullDiskAccess = PermissionsService.forceCheckPermissions()
        let sshKeyscanAvailable = SSHService.checkSSHKeyscanAvailability()
        let sshAvailable = SSHService.checkSSHAvailability()
        
        if fullDiskAccess && sshKeyscanAvailable && sshAvailable {
            // Если разрешения настроены, закрываем модальное окно
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                dismiss()
            }
        }
    }
}



struct InstructionStep: View {
    let number: String
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(number)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 20, height: 20)
                .background(Color.blue)
                .clipShape(Circle())
            
            Text(text)
                .font(.caption)
                .foregroundColor(.primary)
            
            Spacer()
        }
    }
}

struct DetailedInstructionsView: View {
    let permissionsCheck: [String]
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Заголовок с кнопкой закрытия
            HStack {
                Text("Detailed Permissions Instructions")
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
            
            // Основной контент с прокруткой
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    if !permissionsCheck.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Current Status:")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            ForEach(permissionsCheck, id: \.self) { line in
                                Text(line)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(line.contains("❌") ? .red : 
                                                   line.contains("✅") ? .green : 
                                                   line.contains("⚠️") ? .orange : 
                                                   line.contains("===") ? .blue : .primary)
                                    .padding(.vertical, 1)
                            }
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                    }
                    
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Step-by-Step Instructions:")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        DetailedStep(
                            number: "1",
                            title: "Open System Settings",
                            description: "Click the Apple menu → System Settings, or use Spotlight (⌘+Space) and search for 'Privacy'"
                        )
                        
                        DetailedStep(
                            number: "2",
                            title: "Go to Privacy & Security",
                            description: "Click on 'Privacy & Security' in the System Settings window"
                        )
                        
                        DetailedStep(
                            number: "3",
                            title: "Scroll to Full Disk Access",
                            description: "Scroll down to find 'Full Disk Access' in the list of privacy settings"
                        )
                        
                        DetailedStep(
                            number: "4",
                            title: "Add Full Disk Access (Required)",
                            description: "In the left sidebar, select 'Full Disk Access'. Click the lock icon 🔒 at the bottom, enter your password, then click the '+' button and add MacSSH. This permission is required for SSH operations."
                        )
                        
                        DetailedStep(
                            number: "5",
                            title: "Add Accessibility",
                            description: "In the left sidebar, select 'Accessibility'. Click the lock icon 🔒, enter your password, then click the '+' button and add MacSSH"
                        )
                        
                        DetailedStep(
                            number: "6",
                            title: "Add Automation (Optional)",
                            description: "In the left sidebar, select 'Automation'. Click the lock icon 🔒, enter your password, then click the '+' button and add MacSSH. Allow access to Terminal.app"
                        )
                        
                        DetailedStep(
                            number: "7",
                            title: "Restart MacSSH",
                            description: "Completely quit MacSSH and restart it for the changes to take effect"
                        )
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Troubleshooting:")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text("• If MacSSH doesn't appear in the list, make sure it's properly installed")
                            Text("• Try restarting your Mac if permissions don't take effect")
                            Text("• Check Console.app for any permission-related errors")
                            Text("• Make sure you're running the latest version of MacSSH")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                    
                    // Дополнительное пространство внизу для кнопки
                    Spacer(minLength: 80)
                }
                .padding()
            }
            .frame(maxHeight: .infinity)
            
            // Кнопка закрытия внизу - всегда видимая
            HStack {
                Spacer()
                
                Button("Close") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .frame(width: 100)
            }
            .padding()
            .background(Color.gray.opacity(0.05))
        }
        .frame(width: 600, height: 500)
        .background(Color.white)
        .onKeyPress(.escape) {
            dismiss()
            return .handled
        }
    }
}

struct DetailedStep: View {
    let number: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(Color.blue)
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    PermissionsManagerView()
}
