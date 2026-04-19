// SettingsComponents.swift
// FlowDay
//
// Shared row/group builders used by every Settings sub-screen.
// Wrapped in the `FDSettingsUI` enum namespace so the helper names don't
// pollute the module scope or collide with private helpers of the same
// names elsewhere in the codebase.

import SwiftUI

enum FDSettingsUI {

    static func backButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: "chevron.left")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.fdText)
                .frame(width: 36, height: 36)
                .background(Color.fdSurfaceHover)
                .clipShape(Circle())
        }
    }

    static func group<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            content()
        }
        .background(Color.fdSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.03), radius: 4, y: 2)
    }

    static func toggleRow(title: String, isOn: Binding<Bool>, subtitle: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.fdBody)
                    .foregroundStyle(Color.fdText)
                Spacer()
                Toggle("", isOn: isOn)
                    .tint(Color.fdAccent)
                    .labelsHidden()
            }
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.fdCaption)
                    .foregroundStyle(Color.fdTextSecondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    static func pickerRow(title: String, selection: Binding<String>, options: [String]) -> some View {
        HStack {
            Text(title)
                .font(.fdBody)
                .foregroundStyle(Color.fdText)
            Spacer()
            Menu {
                ForEach(options, id: \.self) { option in
                    Button(option) { selection.wrappedValue = option }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(selection.wrappedValue)
                        .font(.fdCaption)
                        .foregroundStyle(Color.fdTextMuted)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.fdTextMuted)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    static func stepperRow(title: String, value: Binding<Int>, range: ClosedRange<Int>) -> some View {
        HStack {
            Text(title)
                .font(.fdBody)
                .foregroundStyle(Color.fdText)
            Spacer()
            HStack(spacing: 12) {
                Button {
                    if value.wrappedValue > range.lowerBound { value.wrappedValue -= 1 }
                } label: {
                    Image(systemName: "minus.circle")
                        .font(.system(size: 20))
                        .foregroundStyle(Color.fdTextMuted)
                }
                Text("\(value.wrappedValue)")
                    .font(.fdBodySemibold)
                    .foregroundStyle(Color.fdText)
                    .frame(minWidth: 24)
                Button {
                    if value.wrappedValue < range.upperBound { value.wrappedValue += 1 }
                } label: {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 20))
                        .foregroundStyle(Color.fdAccent)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    static func infoCard(icon: String, title: String, message: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundStyle(Color.fdAccent)
            Text(title)
                .font(.fdBodySemibold)
                .foregroundStyle(Color.fdText)
            Text(message)
                .font(.fdCaption)
                .foregroundStyle(Color.fdTextSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(Color.fdAccentLight)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    static func navRow(title: String, subtitle: String?, value: String?) -> some View {
        VStack(alignment: .leading, spacing: subtitle != nil ? 4 : 0) {
            HStack {
                Text(title)
                    .font(.fdBody)
                    .foregroundStyle(Color.fdText)
                Spacer()
                if let value = value {
                    Text(value)
                        .font(.fdCaption)
                        .foregroundStyle(Color.fdTextMuted)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.fdTextMuted)
            }
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.fdCaption)
                    .foregroundStyle(Color.fdTextSecondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    static func sectionHeader(_ title: String, color: Color = Color.fdText) -> some View {
        Text(title)
            .font(.fdCaptionBold)
            .foregroundStyle(color)
            .tracking(0.5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 8)
    }

    static func proUpsellCard(icon: String, title: String, message: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(Color(hex: "B8860B"))
                Text(title)
                    .font(.fdBodySemibold)
                    .foregroundStyle(Color.fdText)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.fdTextMuted)
            }
            Text(message)
                .font(.fdCaption)
                .foregroundStyle(Color.fdTextSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(LinearGradient(gradient: Gradient(colors: [Color(hex: "FDF8E8"), Color(hex: "FEF3C7")]), startPoint: .topLeading, endPoint: .bottomTrailing))
        .border(Color(hex: "FCD34D"), width: 1)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    static func proUpsellBanner(icon: String, title: String, message: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(Color.fdAccent)
                Text(title)
                    .font(.fdBodySemibold)
                    .foregroundStyle(Color.fdText)
            }
            Text(message)
                .font(.fdCaption)
                .foregroundStyle(Color.fdTextSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.fdAccentLight)
        .border(Color.fdBorder, width: 1)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
