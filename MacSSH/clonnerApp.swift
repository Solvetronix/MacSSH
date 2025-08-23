//
//  MacSSHApp.swift
//  MacSSH Terminal
//
//  Created by Dmitry Borisenko on 15.06.25.
//

import SwiftUI
import Sparkle

@main
struct MacSSHApp: App {
    @StateObject private var viewModel = ProfileViewModel()
    
    init() {
        // Initialize Sparkle updater on app launch
        UpdateService.initializeUpdater()
        
        // Test logging
        print("🔄 🚀 === APP STARTUP VERSION INFO ===")
        print("🔄 📋 Bundle.main CFBundleShortVersionString: \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown")")
        print("🔄 📋 Bundle.main CFBundleVersion: \(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown")")
        print("🔄 📋 Info.plist CFBundleShortVersionString: \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown")")
        print("🔄 📋 Info.plist CFBundleVersion: \(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown")")
        print("🔄 📋 Info.plist SUFeedURL: \(Bundle.main.infoDictionary?["SUFeedURL"] as? String ?? "Unknown")")
        print("🔄 🚀 === END VERSION INFO ===")
        
        // Test LoggingService
        LoggingService.shared.info("🔄 🚀 === APP STARTUP VERSION INFO ===", source: "MacSSHApp")
        LoggingService.shared.info("🔄 📋 Bundle.main CFBundleShortVersionString: \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown")", source: "MacSSHApp")
        LoggingService.shared.info("🔄 📋 Bundle.main CFBundleVersion: \(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown")", source: "MacSSHApp")
        LoggingService.shared.info("🔄 📋 Info.plist CFBundleShortVersionString: \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown")", source: "MacSSHApp")
        LoggingService.shared.info("🔄 📋 Info.plist CFBundleVersion: \(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown")", source: "MacSSHApp")
        LoggingService.shared.info("🔄 📋 Info.plist SUFeedURL: \(Bundle.main.infoDictionary?["SUFeedURL"] as? String ?? "Unknown")", source: "MacSSHApp")
        LoggingService.shared.info("🔄 🚀 === END VERSION INFO ===", source: "MacSSHApp")
        
        // Test simple logging
        print("🔄 🔧 Testing simple logging...")
        LoggingService.shared.debug("🔄 🔧 Testing debug logging", source: "MacSSHApp")
        LoggingService.shared.info("🔄 🔧 Testing info logging", source: "MacSSHApp")
        LoggingService.shared.success("🔄 🔧 Testing success logging", source: "MacSSHApp")
        LoggingService.shared.warning("🔄 🔧 Testing warning logging", source: "MacSSHApp")
        LoggingService.shared.error("🔄 🔧 Testing error logging", source: "MacSSHApp")
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                .onAppear {
                    // Sparkle handles automatic update checks internally
                    // No need to manually check for updates
                }
        }
        
        // Окно файлового менеджера
        WindowGroup("File Browser", id: "fileBrowser") {
            FileBrowserWindowContent()
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 800, height: 600)
        .windowResizability(.contentSize)
        .defaultPosition(.center)
        .handlesExternalEvents(matching: Set(arrayLiteral: "fileBrowser"))
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
    }
}

struct FileBrowserWindowContent: View {
    @StateObject private var fileBrowserViewModel = ProfileViewModel()
    @StateObject private var windowManager = WindowManager.shared
    
    var body: some View {
        Group {
            if let profile = windowManager.currentProfile {
                FileBrowserView(viewModel: fileBrowserViewModel)
                    .onAppear {
                        let timestamp = Date().timeIntervalSince1970
                        print("🕐 [\(timestamp)] FileBrowserWindow: Profile loaded: \(profile.name)")
                        
                        // Устанавливаем профиль и загружаем файлы
                        fileBrowserViewModel.fileBrowserProfile = profile
                        Task {
                            await fileBrowserViewModel.openFileBrowser(for: profile)
                        }
                    }
            } else {
                VStack {
                    Text("No profile selected")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    Text("Please select a profile and click 'Open File Browser'")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}
