import Foundation

enum ShellMode: String, CaseIterable, Codable, Hashable {
    case console   // VPP Console — daily driver chat
    case studio    // VPP Studio — projects/topics/chats/messages
    case atlas     // VPP Atlas — cross-session browser
}
