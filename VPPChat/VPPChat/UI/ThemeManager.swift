//
//  ThemeManager.swift
//  VPPChat
//
//  Created by Sebastian Suarez-Solis on 12/13/25.
//

import SwiftUI
import Combine

final class ThemeManager: ObservableObject {
    @Published var palette: AccentPalette = .graphite

    var structuralAccent: Color { palette.structural }
    var exceptionAccent: Color { palette.exception }
}
