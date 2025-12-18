//
//  WorkspaceLexicon.swift
//  VPPChat
//
//  Created by Sebastian Suarez-Solis on 12/17/25.
//


import Foundation

enum WorkspaceLexicon {
  // Nouns (Title Case) — use for labels/buttons
  static let environment = "Environment"
  static let environments = "Environments"

  static let project = "Project"
  static let projects = "Projects"

  static let topic = "Topic"          // was Track
  static let topics = "Topics"

  static let chat = "Chat"            // was Scene
  static let chats = "Chats"

  static let message = "Message"      // was Block
  static let messages = "Messages"

  // Hierarchy strings used in wizards/onboarding
  static let hierarchyShort = "\(environment) ▸ \(project) ▸ \(topic) ▸ \(chat)"
  static let hierarchyLong  = "\(environment) ▸ \(project) ▸ \(topic) ▸ \(chat) ▸ \(messages)"

  // Common UI verbs
  static let newEnvironmentEllipsis = "New \(environment)…"
  static let newProjectEllipsis     = "New \(project)…"
  static let newTopicEllipsis       = "New \(topic)…"
  static let newChatEllipsis        = "New \(chat)…"

  // Console (nominal copy)
  static let noChatSelectedTitle = "No chat selected"
  static let noChatSelectedBody  = "Create or select a chat in the sidebar to begin."
}
