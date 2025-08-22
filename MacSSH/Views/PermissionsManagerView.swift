import SwiftUI
import AppKit

// Структура для отслеживания статуса каждой проверки
struct CheckItem: Identifiable {
    let id = UUID()
    let name: String
    let category: String
    var status: CheckStatus = .pending
    var details: String = ""
    
    enum CheckStatus {
        case pending
        case checking
        case success
        case failed
    }
}

struct PermissionsManagerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var checkItems: [CheckItem] = []
    @State private var showingInstructions = false
    @State private var isChecking = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Заголовок
            HStack {
                Text("SSH Tools Manager")
                    .font(.headline)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button("✕") {
                    dismiss()
                }
                .buttonStyle(.plain)
                .font(.title3)
                .foregroundColor(.secondary)
                .frame(width: 24, height: 24)
                .background(Color.gray.opacity(0.1))
                .clipShape(Circle())
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.gray.opacity(0.05))
            .onAppear {
                // Автоматически проверяем инструменты при открытии асинхронно
                Task {
                    await performInitialCheck()
                }
            }
            
            // Основной контент
            ScrollView {
                VStack(spacing: 12) {
                    // Заголовок
                    Text("SSH Tools Status")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    // Проверки по категориям
                    if checkItems.isEmpty && !isChecking {
                        Text("Click 'Check Tools' to start verification")
                            .foregroundColor(.secondary)
                            .font(.system(size: 12))
                    } else {
                        // System Permissions
                        let systemItems = checkItems.filter { $0.category == "System Permissions" }
                        if !systemItems.isEmpty {
                            CategorySection(title: "System Permissions", items: systemItems)
                        }
                        
                        // SSH Tools
                        let sshItems = checkItems.filter { $0.category == "SSH Tools" }
                        if !sshItems.isEmpty {
                            CategorySection(title: "Required SSH Tools", items: sshItems)
                        }
                        
                        // Actions Needed
                        let actionItems = checkItems.filter { $0.category == "Actions" && $0.status == .failed }
                        if !actionItems.isEmpty {
                            CategorySection(title: "Actions Needed", items: actionItems)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            
            // Кнопки внизу - всегда видимые
            HStack(spacing: 8) {
                Button("Check Tools") {
                    Task {
                        await performCheck()
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(isChecking)
                
                Button("Force Check Permissions") {
                    Task {
                        await performForceCheck()
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(isChecking)
                
                Button("Show Instructions") {
                    showingInstructions = true
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                Button("Request Full Disk Access") {
                    Task {
                        await performRequestAccess()
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(PermissionsService.forceCheckPermissions() || isChecking)
                
                Button("Close") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                
                Spacer()
                
                Button("Restart MacSSH") {
                    restartApplication()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.gray.opacity(0.05))
        }
        .frame(width: 480, height: 450)
        .background(Color.white)
        .onKeyPress(.escape) {
            dismiss()
            return .handled
        }
        .sheet(isPresented: $showingInstructions) {
            DetailedInstructionsView(checkItems: checkItems)
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
    
    // MARK: - Async Methods
    
    private func performInitialCheck() async {
        await initializeCheckItems()
        await performAllChecks()
    }
    
    private func initializeCheckItems() async {
        await MainActor.run {
            checkItems = [
                // System Permissions
                CheckItem(name: "Full Disk Access", category: "System Permissions"),
                
                // SSH Tools
                CheckItem(name: "ssh-keyscan", category: "SSH Tools"),
                CheckItem(name: "ssh", category: "SSH Tools"),
                CheckItem(name: "sftp", category: "SSH Tools"),
                CheckItem(name: "scp", category: "SSH Tools"),
                CheckItem(name: "sshpass", category: "SSH Tools"),
                CheckItem(name: "VS Code/Cursor", category: "SSH Tools")
            ]
            isChecking = true
        }
    }
    
    private func performAllChecks() async {
        // Проверяем каждый элемент по очереди
        await checkFullDiskAccess()
        await checkSSHKeyscan()
        await checkSSH()
        await checkSFTP()
        await checkSCP()
        await checkSSHPass()
        await checkVSCode()
        
        await MainActor.run {
            isChecking = false
        }
    }
    
    private func checkFullDiskAccess() async {
        await updateItemStatus(name: "Full Disk Access", category: "System Permissions", status: .checking)
        
        let hasAccess = PermissionsService.forceCheckPermissions()
        
        await updateItemStatus(
            name: "Full Disk Access", 
            category: "System Permissions", 
            status: hasAccess ? .success : .failed,
            details: hasAccess ? "Granted" : "Not granted"
        )
        
        // Небольшая задержка для визуального эффекта
        try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 секунды
    }
    
    private func checkSSHKeyscan() async {
        await updateItemStatus(name: "ssh-keyscan", category: "SSH Tools", status: .checking)
        
        let available = SSHService.checkSSHKeyscanAvailability()
        
        await updateItemStatus(
            name: "ssh-keyscan", 
            category: "SSH Tools", 
            status: available ? .success : .failed,
            details: available ? "Available" : "Not found"
        )
        
        try? await Task.sleep(nanoseconds: 300_000_000)
    }
    
    private func checkSSH() async {
        await updateItemStatus(name: "ssh", category: "SSH Tools", status: .checking)
        
        let available = SSHService.checkSSHAvailability()
        
        await updateItemStatus(
            name: "ssh", 
            category: "SSH Tools", 
            status: available ? .success : .failed,
            details: available ? "Available" : "Not found"
        )
        
        try? await Task.sleep(nanoseconds: 300_000_000)
    }
    
    private func checkSFTP() async {
        await updateItemStatus(name: "sftp", category: "SSH Tools", status: .checking)
        
        let available = FileManager.default.fileExists(atPath: "/usr/bin/sftp")
        
        await updateItemStatus(
            name: "sftp", 
            category: "SSH Tools", 
            status: available ? .success : .failed,
            details: available ? "Available" : "Not found"
        )
        
        try? await Task.sleep(nanoseconds: 300_000_000)
    }
    
    private func checkSCP() async {
        await updateItemStatus(name: "scp", category: "SSH Tools", status: .checking)
        
        let available = FileManager.default.fileExists(atPath: "/usr/bin/scp")
        
        await updateItemStatus(
            name: "scp", 
            category: "SSH Tools", 
            status: available ? .success : .failed,
            details: available ? "Available" : "Not found"
        )
        
        try? await Task.sleep(nanoseconds: 300_000_000)
    }
    
    private func checkSSHPass() async {
        await updateItemStatus(name: "sshpass", category: "SSH Tools", status: .checking)
        
        let available = SSHService.checkSSHPassAvailability()
        
        await updateItemStatus(
            name: "sshpass", 
            category: "SSH Tools", 
            status: available ? .success : .failed,
            details: available ? "Available" : "Not found"
        )
        
        try? await Task.sleep(nanoseconds: 300_000_000)
    }
    
    private func checkVSCode() async {
        await updateItemStatus(name: "VS Code/Cursor", category: "SSH Tools", status: .checking)
        
        let available = VSCodeService.checkVSCodeAvailability()
        
        await updateItemStatus(
            name: "VS Code/Cursor", 
            category: "SSH Tools", 
            status: available ? .success : .failed,
            details: available ? "Available" : "Not found"
        )
        
        try? await Task.sleep(nanoseconds: 300_000_000)
    }
    
    private func updateItemStatus(name: String, category: String, status: CheckItem.CheckStatus, details: String = "") async {
        await MainActor.run {
            if let index = checkItems.firstIndex(where: { $0.name == name && $0.category == category }) {
                checkItems[index].status = status
                if !details.isEmpty {
                    checkItems[index].details = details
                }
            }
        }
    }
    
    private func performCheck() async {
        await initializeCheckItems()
        await performAllChecks()
    }
    
    private func performForceCheck() async {
        await MainActor.run {
            isChecking = true
        }
        
        let hasAccess = PermissionsService.forceCheckPermissions()
        
        if hasAccess {
            await performAllChecks()
        } else {
            await MainActor.run {
                isChecking = false
                // Показываем предупреждение
                let alert = NSAlert()
                alert.messageText = "Permissions Check"
                alert.informativeText = "Full Disk Access is still not granted. Please check System Settings."
                alert.alertStyle = .warning
                alert.addButton(withTitle: "OK")
                alert.runModal()
            }
        }
    }
    
    private func performRequestAccess() async {
        await MainActor.run {
            isChecking = true
        }
        
        PermissionsService.requestFullDiskAccess()
        
        // Ждем немного и обновляем статус
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 секунда
        
        await performAllChecks()
    }
}

// Компонент для отображения категории проверок
struct CategorySection: View {
    let title: String
    let items: [CheckItem]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Заголовок категории
            Text("=== \(title) ===")
                .font(.system(size: 11, design: .monospaced))
                .fontWeight(.medium)
                .foregroundColor(.blue)
            
            // Элементы проверки
            ForEach(items) { item in
                CheckItemRow(item: item)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(6)
    }
}

// Компонент для отображения отдельного элемента проверки
struct CheckItemRow: View {
    let item: CheckItem
    
    var body: some View {
        HStack(spacing: 8) {
            // Иконка статуса
            statusIcon
            
            // Название и детали
            VStack(alignment: .leading, spacing: 2) {
                Text("\(item.name): \(item.details)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(statusColor)
            }
            
            Spacer()
        }
        .padding(.vertical, 1)
    }
    
    @ViewBuilder
    private var statusIcon: some View {
        switch item.status {
        case .pending:
            Image(systemName: "circle")
                .foregroundColor(.gray)
                .font(.system(size: 10))
        case .checking:
            ProgressView()
                .scaleEffect(0.6)
                .frame(width: 12, height: 12)
        case .success:
            Text("✅")
                .font(.system(size: 10))
        case .failed:
            Text("❌")
                .font(.system(size: 10))
        }
    }
    
    private var statusColor: Color {
        switch item.status {
        case .pending:
            return .gray
        case .checking:
            return .blue
        case .success:
            return .green
        case .failed:
            return .red
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
    let checkItems: [CheckItem]
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
                    if !checkItems.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Current Status:")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            // System Permissions
                            let systemItems = checkItems.filter { $0.category == "System Permissions" }
                            if !systemItems.isEmpty {
                                CategorySection(title: "System Permissions", items: systemItems)
                            }
                            
                            // SSH Tools
                            let sshItems = checkItems.filter { $0.category == "SSH Tools" }
                            if !sshItems.isEmpty {
                                CategorySection(title: "Required SSH Tools", items: sshItems)
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
