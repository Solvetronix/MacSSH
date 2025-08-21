//
//  MacSSHApp.swift
//  MacSSH Terminal
//
//  Created by Dmitry Borisenko on 15.06.25.
//

import SwiftUI

@main
struct MacSSHApp: App {
    @StateObject private var viewModel = ProfileViewModel()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
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
