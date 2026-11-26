import SwiftUI

@main
struct TSMateApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            AppView(model: model)
                .preferredColorScheme(.light)
        }
    }
}
