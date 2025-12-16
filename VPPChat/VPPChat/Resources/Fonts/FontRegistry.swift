//
//  FontRegistry.swift
//  VPPChat
//
//  Created by Sebastian Suarez-Solis on 12/16/25.
//


import Foundation
import CoreText

enum FontRegistry {
  static let psNames = [
    "IBMPlexMono-Regular",
    "IBMPlexMono-Italic",
    "IBMPlexMono-Medium",
    "IBMPlexMono-MediumItalic",
    "IBMPlexMono-SemiBold",
    "IBMPlexMono-SemiBoldItalic",
    "IBMPlexMono-Bold",
    "IBMPlexMono-BoldItalic",
  ]

  static func registerAll() {
    for ps in psNames {
      guard let url = Bundle.main.url(forResource: ps, withExtension: "ttf", subdirectory: "Fonts") else { continue }
      CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
    }
  }
}
