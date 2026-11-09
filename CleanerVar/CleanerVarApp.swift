import SwiftUI

@main
struct CleanerVarApp: App {
    var body: some Scene {
        WindowGroup {
            CleanerDashboardView()
                .preferredColorScheme(.dark)
        }
    }
}
