//
//  WorkspaceDragPayload.swift
//  VPPChat
//
//  Created by Sebastian Suarez-Solis on 12/15/25.
//


import Foundation
import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static let vppWorkspaceDragPayload = UTType(exportedAs: "com.stagedevices.vppchat.dragpayload")
}

struct WorkspaceDragPayload: Codable, Hashable, Transferable {
    enum Kind: String, Codable, Hashable {
        case project
        case track
        case scene
    }

    var kind: Kind
    var id: UUID

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .vppWorkspaceDragPayload)
    }
}
