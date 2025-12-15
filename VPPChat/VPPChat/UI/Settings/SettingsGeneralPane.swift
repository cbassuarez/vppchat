//
//  SettingsGeneralPane.swift
//  VPPChat
//
//  Created by Sebastian Suarez-Solis on 12/14/25.
//


// SettingsGeneralPane.swift
// VPPChat

import SwiftUI

struct SettingsGeneralPane: View {
    @AppStorage("settings.general.launchBehavior") private var launchBehaviorRaw: String = "last"
    
        private enum LaunchBehavior: String, CaseIterable, Identifiable {
            case last
            case atlas
            case console
            case studio
            var id: String { rawValue }
    
            var label: String {
                switch self {
                case .last:    return "Last used"
                case .atlas:   return "Atlas"
                case .console: return "Console"
                case .studio:  return "Studio"
                }
            }
    
            var hint: String {
                switch self {
                case .last:    return "Start where you left off."
                case .atlas:   return "Start in Atlas."
                case .console: return "Start in Console."
                case .studio:  return "Start in Studio."
                }
            }
        }
    
    private var launchBehavior: LaunchBehavior {
                LaunchBehavior(rawValue: launchBehaviorRaw) ?? .last
            }
 
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("General")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(AppTheme.Colors.textPrimary)
                            Text("Lightweight preferences for this app.")
                                .font(.system(size: 11))
                                .foregroundStyle(AppTheme.Colors.textSecondary)
                        }
                        Spacer()
                    }
        
                    Divider()
                        .overlay(AppTheme.Colors.borderSoft.opacity(0.7))
        
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Launch behavior")
                            .font(.system(size: 11, weight: .semibold))
                            .textCase(.uppercase)
                            .foregroundStyle(AppTheme.Colors.textSubtle)
        
                        HStack(spacing: 8) {
                            ForEach(LaunchBehavior.allCases) { option in
                                launchChip(option)
                            }
                        }
        
                        Text(launchBehavior.hint + " (Applies on next launch.)")
                            .font(.system(size: 11))
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.Radii.panel, style: .continuous)
                        .fill(AppTheme.Colors.surface0)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppTheme.Radii.panel, style: .continuous)
                                .stroke(AppTheme.Colors.borderSoft, lineWidth: 1)
                        )
                )
    }
    private func launchChip(_ option: LaunchBehavior) -> some View {
        let isSelected = (option == launchBehavior)
            return Button {
                launchBehaviorRaw = option.rawValue
            } label: {
                Text(option.label)
                    .font(.system(size: 11, weight: .semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(isSelected ? StudioTheme.Colors.accentSoft : AppTheme.Colors.surface1)
                    )
                    .overlay(
                        Capsule()
                            .stroke(isSelected ? StudioTheme.Colors.accent : AppTheme.Colors.borderSoft, lineWidth: 1)
                    )
                    .foregroundStyle(isSelected ? StudioTheme.Colors.textPrimary : AppTheme.Colors.textSecondary)
            }
            .buttonStyle(.plain)
        }
}
