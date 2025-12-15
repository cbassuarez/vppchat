//
//  SettingLLLMPane.swift
//  VPPChat
//
//  Created by Sebastian Suarez-Solis on 12/14/25.
//

import SwiftUI

struct SettingsLLMPane: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            LLMSettingsPanel()
            LLMDefaultsCard()
        }
    }
}

