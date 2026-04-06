import SwiftUI

@main
struct ScreenPutApp: App {
    @State private var viewModel = AppViewModel()

    var body: some Scene {
        MenuBarExtra("ScreenPut", systemImage: "camera.viewfinder") {
            MenuBarPopover(viewModel: viewModel)
                .frame(width: 360, height: 420)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(viewModel: viewModel)
        }
    }
}
