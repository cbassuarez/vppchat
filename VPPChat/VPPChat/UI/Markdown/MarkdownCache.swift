//
//  MarkdownCache.swift
//  VPPChat
//
//  Created by Sebastian Suarez-Solis on 12/15/25.
//


import Foundation

final class MarkdownCache {
    static let shared = MarkdownCache()

    private let cache = NSCache<NSString, Box>()

    final class Box: NSObject {
        let doc: MarkdownDocument
        init(_ doc: MarkdownDocument) { self.doc = doc }
    }

    func document(for text: String) -> MarkdownDocument {
        let key = text as NSString
        if let hit = cache.object(forKey: key) {
            return hit.doc
        }
        let parsed = MarkdownParser().parse(text)
        cache.setObject(Box(parsed), forKey: key)
        return parsed
    }
}
