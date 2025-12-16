//
//  WorkspaceLibrarySheets.swift
//  VPPChat
//
//  Created by Sebastian Suarez-Solis on 12/15/25.
//


import SwiftUI

struct RenameRequest: Identifiable {
    enum Kind { case environment, project, track, scene }
    var id: UUID { entityID }
    let kind: Kind
    let entityID: UUID
    let currentName: String
}

struct RestoreRequest: Identifiable {
    enum Kind { case environment, project, track, scene, block }
    var id: UUID { entityID }
    let kind: Kind
    let entityID: UUID
    let title: String
}
