import SwiftUI

@main
struct CraftPromptApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 850, minHeight: 550)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: true))
        .commands {
            SidebarCommands()
            CommandGroup(replacing: .help) {
                Button("PhotoCraft Control Protocol Docs") {
                    if let url = URL(string: "https://github.com/storytold/photocraft") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
        }
    }
}
