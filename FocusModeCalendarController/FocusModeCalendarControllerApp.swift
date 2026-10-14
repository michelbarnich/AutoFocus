import SwiftUI

@main
struct FocusModeCalendarControllerApp: App {
    var body: some Scene {
        MenuBarExtra("Calendar Focus", systemImage: "moon.stars.fill") {
            ContentView()
        }
        .menuBarExtraStyle(.window)
    }
}
