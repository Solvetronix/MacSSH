import Foundation
import SwiftUI
import AppKit

class WindowManager: ObservableObject {
    static let shared = WindowManager()
    
    @Published var currentProfile: Profile?
    private var terminalWindows: [String: NSWindow] = [:]
    private var windowDelegates: [String: TerminalWindowDelegate] = [:]
    private var terminalServices: [String: SwiftTermProfessionalService] = [:]
    private var aiChatWindows: [String: NSWindow] = [:]
    
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
        let terminalService = SwiftTermProfessionalService()
        terminalServices[windowId] = terminalService
        
        // Создаем новое окно
        let terminalView = SwiftTermProfessionalTerminalView(profile: profile, terminalService: terminalService)
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

        // Автоматически открываем окно ассистента рядом
        openMultiStepAIChatWindow(for: profile)
        // Если получилось найти оба окна, расположим их рядом
        if let ai = aiChatWindows["ai_chat_\(profile.id.uuidString)"] {
            tileAIWindowNextToTerminal(profile: profile, aiWindow: ai)
        }
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
        
        // Закрываем все окна AI чата
        for (_, window) in aiChatWindows {
            window.close()
        }
        aiChatWindows.removeAll()
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
    
    @MainActor
    func openMultiStepAIChatWindow(for profile: Profile) {
        let windowId = "ai_chat_\(profile.id.uuidString)"
        
        // Проверяем, не открыто ли уже окно для этого профиля
        if let existingWindow = aiChatWindows[windowId], existingWindow.isVisible {
            existingWindow.makeKeyAndOrderFront(nil)
            return
        }
        
        // Find existing terminal service for this profile
        let terminalWindowId = "terminal_\(profile.id.uuidString)"
        guard let terminalService = terminalServices[terminalWindowId] else {
            print("No terminal service found for profile \(profile.host)")
            return
        }
        
        // Создаем новое окно
        let aiChatView = MultiStepAIChatWindow(profile: profile, terminalService: terminalService)
        let hostingController = NSHostingController(rootView: aiChatView)
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 700),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        // Устанавливаем окно как неосновное, чтобы приложение не закрывалось при его закрытии
        window.isReleasedWhenClosed = false
        
        window.title = "Multi-Step AI Assistant — \(profile.username)@\(profile.host)"
        window.contentViewController = hostingController
        // Пытаемся расположить рядом с окном терминала, если оно уже существует
        if let _ = terminalWindows["terminal_\(profile.id.uuidString)"] {
            // Поставим временно в (0,0), затем выровняем
            window.setFrame(NSRect(x: 0, y: 0, width: 900, height: 700), display: false)
        } else {
            window.center()
        }
        window.makeKeyAndOrderFront(nil)
        
        // Сохраняем ссылку на окно
        aiChatWindows[windowId] = window

        // Финальное выравнивание возле терминала, если он есть
        tileAIWindowNextToTerminal(profile: profile, aiWindow: window)
    }

    // Размещает окно ассистента справа от терминала (или слева, если не помещается)
    @MainActor
    private func tileAIWindowNextToTerminal(profile: Profile, aiWindow: NSWindow) {
        let termId = "terminal_\(profile.id.uuidString)"
        guard let termWindow = terminalWindows[termId], termWindow.isVisible else { return }
        guard let screen = termWindow.screen?.visibleFrame ?? NSScreen.main?.visibleFrame else { return }
        let gap: CGFloat = 8
        let termFrame = termWindow.frame
        var newFrame = aiWindow.frame
        // Подгоняем размер ассистента под размер терминала
        newFrame.size = termFrame.size
        newFrame.origin.y = max(screen.minY, min(termFrame.origin.y, screen.maxY - newFrame.height))
        newFrame.origin.x = termFrame.maxX + gap
        // Если не помещается справа — ставим слева
        if newFrame.maxX > screen.maxX {
            newFrame.origin.x = termFrame.origin.x - gap - newFrame.width
        }
        // Клэмп по экрану
        if newFrame.origin.x < screen.minX { newFrame.origin.x = screen.minX }
        if newFrame.maxX > screen.maxX { newFrame.origin.x = screen.maxX - newFrame.width }
        aiWindow.setFrame(newFrame, display: true, animate: true)
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
