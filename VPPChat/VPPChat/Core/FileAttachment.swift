//
//  FileAttachment.swift
//  VPPChat
//
//  Created by Sebastian Suarez-Solis on 12/19/25.
//

import Foundation

struct FileIdentity: Hashable {
  var displayName: String
  var ext: String
  var contentType: String?
  var byteSize: Int64?
  var modifiedAt: Date?
}

enum ExcerptStrategy: String, Codable, Hashable {
  case full
  case headTail
  case outline
  case metadataOnly
}

struct FileExtractionResult: Hashable {
  var excerptText: String
  var strategy: ExcerptStrategy
  var charCount: Int
  var extractedAt: Date
  var warning: String?
}

enum AttachmentStatus: Hashable {
  case picked
  case needsAccess
  case reading(progress: Double, phase: String)
  case ready
  case changed
  case error(message: String)
}

struct FileAttachment: Hashable {
  var sourceID: String
  var bookmark: Data
  var resolvedURLPath: String?
  var identity: FileIdentity
  var status: AttachmentStatus
  var extraction: FileExtractionResult?
}
