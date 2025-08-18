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
        
        Window("File Browser", id: "fileBrowser") {
            FileBrowserWindowContent(viewModel: viewModel)
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 800, height: 600)
        .windowResizability(.contentSize)
        .defaultPosition(.center)
    }
}

struct FileBrowserWindowContent: View {
    @ObservedObject var viewModel: ProfileViewModel
    
    var body: some View {
        let timestamp = Date().timeIntervalSince1970
        print("🕐 [\(timestamp)] FileBrowserWindow: Evaluating condition")
        print("🕐 [\(timestamp)] FileBrowserWindow: viewModel.fileBrowserProfile: \(viewModel.fileBrowserProfile?.name ?? "nil")")
        
        if viewModel.fileBrowserProfile != nil {
            print("🕐 [\(timestamp)] FileBrowserWindow: Rendering FileBrowserView")
            return AnyView(FileBrowserView(viewModel: viewModel))
        } else {
            print("🕐 [\(timestamp)] FileBrowserWindow: Rendering 'No profile selected'")
            return AnyView(VStack {
                Text("No profile selected")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity))
        }
    }
}
