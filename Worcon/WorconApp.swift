import SwiftUI

@main
struct WorconApp: App {
    @AppStorage("appearance") private var appearance = "system"
    @StateObject private var store = ConversationStore()

    var body: some Scene {
        WindowGroup {
            ChatView(store: store)
                .preferredColorScheme(WorconAppearance(rawValue: appearance)?.colorScheme)
        }
    }
}

// Shared by the chat and its settings sheet so appearance stays consistent.
enum WorconAppearance: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var title: String {
        switch self { case .system: "跟随系统"; case .light: "浅色"; case .dark: "深色" }
    }
    var colorScheme: ColorScheme? {
        switch self { case .system: nil; case .light: .light; case .dark: .dark }
    }
}

extension Color {
    static let worconBackground = Color(uiColor: .systemBackground)
    static let worconAccent = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.55, green: 0.82, blue: 0.66, alpha: 1)
            : UIColor(red: 0.16, green: 0.43, blue: 0.29, alpha: 1)
    })
}
