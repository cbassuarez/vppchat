import Foundation

// Console message and session models for the chat surface.
// Primary definitions now live in Core/ConsoleSessionModels.swift. This file retains
// supporting enums used by Console presentation.

enum ConsoleMessageState: Equatable, Codable {
    case normal
    case pending
    case error(message: String)

    var isError: Bool {
        if case .error = self { return true }
        return false
    }

    var errorMessage: String? {
        if case let .error(msg) = self { return msg }
        return nil
    }

    var isPending: Bool {
        if case .pending = self { return true }
        return false
    }
}

enum RequestStatus: Equatable, Codable {
    case idle
    case inFlight
    case error(message: String?)
}
