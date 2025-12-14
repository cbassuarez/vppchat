import Foundation
import SwiftUI
import Combine

@MainActor
final class AtlasFilterState: ObservableObject {
    @Published var selectedProjectID: Project.ID? = nil
    @Published var kind: BlockKind? = nil
    @Published var selectedTags: Set<VppTag> = []
    @Published var canonicalOnly: Bool = false
    @Published var searchText: String = ""
}
