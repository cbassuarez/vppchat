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

    var hasActiveFilters: Bool {
        selectedProjectID != nil ||
        kind != nil ||
        !selectedTags.isEmpty ||
        canonicalOnly ||
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func reset() {
        selectedProjectID = nil
        kind = nil
        selectedTags.removeAll()
        canonicalOnly = false
        searchText = ""
    }
}
