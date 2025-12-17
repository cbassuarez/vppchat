//
//  SceneWizardTypes.swift
//  VPPChat
//
//  Created by Sebastian Suarez-Solis on 12/16/25.
//


import Foundation


public enum SceneWizardGoal: Equatable {
    case newScene
    case newChat
}


public enum SceneWizardStep: Int, CaseIterable, Equatable {
    case goal
    case targetTrack


    case createEnvironment
    case populateEnvironment


    case createProject
    case populateProject


    case createTrack
    case populateTrack


    case createScene
}


public struct SceneWizardState: Equatable {
    public var goal: SceneWizardGoal = .newScene
    public var step: SceneWizardStep = .targetTrack


    // chosen chain
    public var envID: UUID?
    public var projectID: UUID?
    public var trackID: UUID?


    // names
    public var envName: String = ""
    public var projectName: String = ""
    public var trackName: String = ""
    public var sceneName: String = ""


    // populate steps
    public var selectedProjectIDsToMove: Set<UUID> = []
    public var selectedTrackIDsToMove: Set<UUID> = []
    public var selectedSceneIDsToMove: Set<UUID> = []


    public var choseCreateNewProject: Bool = false
    public var choseCreateNewTrack: Bool = false
    public var choseCreateNewScene: Bool = true // keep invariant visible; completion still creates a new scene


    // completion invariant
    public var pendingNewSceneID: UUID?


    // UX
    public var errorText: String?
    public var isBusy: Bool = false


    public init() {}
}


public struct SceneWizardOption: Identifiable, Equatable {
    public var id: UUID
    public var title: String


    public init(id: UUID, title: String) {
        self.id = id
        self.title = title
    }
}


public struct SceneWizardOptionsSnapshot: Equatable {
    public var environments: [SceneWizardOption] = []
    public var projects: [SceneWizardOption] = []
    public var tracks: [SceneWizardOption] = []
    public var scenes: [SceneWizardOption] = []


    public init() {}
}


/// The wizard is UI + reducer + async effects.
/// This protocol is the ONLY dependency on your app layer.
/// Implement it with WorkspaceViewModel (or an adapter) without modifying the wizard itself.
public protocol SceneWizardAPI: Sendable {
    // Options
    func listEnvironments() async throws -> [SceneWizardOption]
    func listProjects() async throws -> [SceneWizardOption]
    func listTracks() async throws -> [SceneWizardOption]
    func listScenes() async throws -> [SceneWizardOption]


    // Create
    func createEnvironment(name: String) async throws -> UUID
    func createProject(envID: UUID, name: String) async throws -> UUID
    func createTrack(projectID: UUID, name: String) async throws -> UUID
    func createScene(trackID: UUID, name: String) async throws -> UUID


    // Move
    func moveProjects(projectIDs: [UUID], to envID: UUID) async throws
    func moveTracks(trackIDs: [UUID], to projectID: UUID) async throws
    func moveScenes(sceneIDs: [UUID], to trackID: UUID) async throws


    // Navigation
    func selectScene(_ sceneID: UUID) async
    func goToStudio() async
    func goToConsole() async
}
