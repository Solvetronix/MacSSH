import Foundation
import SwiftUI
import AppKit

class WindowManager: ObservableObject {
    static let shared = WindowManager()
    
    @Published var currentProfile: Profile?
    private var terminalWindows: [String: NSWindow] = [:]
    private var windowDelegates: [String: TerminalWindowDelegate] = [:]
    private var terminalServices: [String: SwiftTermService] = [:]
    
    private init() {}
    
    func openFileBrowser(for profile: Profile) {
        currentProfile = profile
    }
    
    @MainActor
    func openTerminalWindow(for profile: Profile) {
        let windowId = "terminal_\(profile.id.uuidString)"
        
        // Проверяем, не открыто ли уже окно для этого профиля
        if let existingWindow = terminalWindows[windowId], existingWindow.isVisible {
            existingWindow.makeKeyAndOrderFront(nil)
            return
        }
        
        // Создаем сервис терминала
        let terminalService = SwiftTermService()
        terminalServices[windowId] = terminalService
        
        // Создаем новое окно
        let terminalView = ProfessionalTerminalView(profile: profile, terminalService: terminalService)
        let hostingController = NSHostingController(rootView: terminalView)
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        // Устанавливаем окно как неосновное, чтобы приложение не закрывалось при его закрытии
        window.isReleasedWhenClosed = false
        
        window.title = "\(profile.username)@\(profile.host) — Terminal"
        window.contentViewController = hostingController
        window.center()
        window.makeKeyAndOrderFront(nil)
        
        // Создаем делегат и сохраняем ссылку
        let delegate = TerminalWindowDelegate(windowManager: self, windowId: windowId)
        window.delegate = delegate
        windowDelegates[windowId] = delegate
        
        // Сохраняем ссылку на окно
        terminalWindows[windowId] = window
    }
    
    @MainActor
    func closeTerminalWindow(for profile: Profile) {
        let windowId = "terminal_\(profile.id.uuidString)"
        if let window = terminalWindows[windowId] {
            // Отключаем сервис терминала
            terminalServices[windowId]?.disconnect()
            terminalServices.removeValue(forKey: windowId)
            
            window.delegate = nil // Убираем делегат перед закрытием
            window.close()
            terminalWindows.removeValue(forKey: windowId)
            windowDelegates.removeValue(forKey: windowId)
        }
    }
    
    @MainActor
    func closeAllTerminalWindows() {
        // Отключаем все сервисы терминала
        for (_, service) in terminalServices {
            service.disconnect()
        }
        terminalServices.removeAll()
        
        for (_, window) in terminalWindows {
            window.delegate = nil // Убираем делегат перед закрытием
            window.close()
        }
        terminalWindows.removeAll()
        windowDelegates.removeAll()
    }
    
    // Метод для удаления окна из словарей (вызывается делегатом)
    @MainActor
    func removeWindow(withId windowId: String) {
        // Отключаем сервис терминала
        terminalServices[windowId]?.disconnect()
        terminalServices.removeValue(forKey: windowId)
        
        terminalWindows.removeValue(forKey: windowId)
        windowDelegates.removeValue(forKey: windowId)
    }
}

// Делегат для обработки закрытия окна терминала
class TerminalWindowDelegate: NSObject, NSWindowDelegate {
    private weak var windowManager: WindowManager?
    private let windowId: String
    
    init(windowManager: WindowManager, windowId: String) {
        self.windowManager = windowManager
        self.windowId = windowId
        super.init()
    }
    
    func windowWillClose(_ notification: Notification) {
        // Удаляем окно из словаря при закрытии
        windowManager?.removeWindow(withId: windowId)
    }
}
