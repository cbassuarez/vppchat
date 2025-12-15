import Foundation

// MARK: - VPP Tags and Types

public enum VppTag: String, CaseIterable, Codable, Hashable {
    case g, q, o, c, o_f, e, e_o
}

public enum VppCorrectness: String, Codable, Hashable {
    case neutral
    case correct
    case incorrect
}

public enum VppSeverity: String, Codable, Hashable {
    case none
    case minor
    case major
}

public enum VppSources: String, Codable, Hashable {
    case none
    case web
    case mixed

    static func summary(for refs: [VppSourceRef]) -> VppSources {
        guard !refs.isEmpty else { return .none }
        let kinds = Set(refs.map(\.kind))
        return (kinds.count == 1 && kinds.contains(.web)) ? .web : .mixed
    }
}

public struct VppModifiers: Codable, Hashable {
    public var correctness: VppCorrectness
    public var severity: VppSeverity
    public var echoTarget: VppTag?

    public init(correctness: VppCorrectness = .neutral, severity: VppSeverity = .none, echoTarget: VppTag? = nil) {
        self.correctness = correctness
        self.severity = severity
        self.echoTarget = echoTarget
    }
}

public struct VppState: Codable, Hashable {
    public var currentTag: VppTag
    public var cycleIndex: Int
    public var assumptions: Int
    public var locus: String?
}

public struct VppFooter: Codable, Hashable {
    public var version: String
    public var tag: VppTag
    public var sources: VppSources
    public var assumptions: Int
    public var cycleIndex: Int
    public var locus: String?
}

public extension VppState {
    static var `default`: VppState {
        .init(
            currentTag: .g,
            cycleIndex: 1,
            assumptions: 0,
            locus: "VPPConsole"
        )
    }
}
