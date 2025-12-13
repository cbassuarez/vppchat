import Foundation

enum ShellMode: String, CaseIterable, Codable, Hashable {
    case console   // VPP Console — daily driver chat
    case studio    // VPP Studio — projects/tracks/scenes/blocks
    case atlas     // VPP Atlas — cross-session browser
}
