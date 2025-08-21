import Foundation
import SwiftUI

class WindowManager: ObservableObject {
    static let shared = WindowManager()
    
    @Published var currentProfile: Profile?
    
    private init() {}
    
    func openFileBrowser(for profile: Profile) {
        currentProfile = profile
    }
}
