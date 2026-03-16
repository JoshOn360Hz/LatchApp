import SwiftUI

@main
struct LatchApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var model = LatchAppModel()

    var body: some Scene {
        WindowGroup {
            ContentView(model: model)
                .onChange(of: scenePhase, initial: true) { _, newValue in
                    model.handleScenePhaseChange(newValue)
                }
        }
    }
}
