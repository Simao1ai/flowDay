// EnergyCheckInView.swift
// FlowDay

import SwiftUI

struct EnergyCheckInView: View {
    let onSelect: (EnergyLevel) -> Void
    let onSkip: () -> Void

    @State private var selectedLevel: EnergyLevel?

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture { onSkip() }

            VStack(spacing: 24) {
                VStack(spacing: 6) {
                    Text("Good morning")
                        .font(.fdTitle2)
                        .foregroundStyle(Color.fdText)
                    Text("How are you feeling today?")
                        .font(.fdCaption)
                        .foregroundStyle(Color.fdTextMuted)
                }

                VStack(spacing: 10) {
                    ForEach(EnergyLevel.allCases, id: \.self) { level in
                        energyButton(level)
                    }
                }

                Button("Skip for now") {
                    onSkip()
                }
                .font(.fdCaption)
                .foregroundStyle(Color.fdTextMuted)
            }
            .padding(28)
            .background(Color.fdSurface)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .shadow(color: .black.opacity(0.15), radius: 40, y: 12)
            .padding(.horizontal, 28)
        }
    }

    private func energyButton(_ level: EnergyLevel) -> some View {
        let isSelected = selectedLevel == level
        let levelColor = energyColor(for: level)

        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.65)) {
                selectedLevel = level
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                onSelect(level)
            }
        } label: {
            HStack(spacing: 14) {
                Text(level.emoji)
                    .font(.title2)
                    .scaleEffect(isSelected ? 1.12 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
                VStack(alignment: .leading, spacing: 2) {
                    Text(level.label)
                        .font(.fdBodySemibold)
                        .foregroundStyle(Color.fdText)
                    Text(level.description)
                        .font(.fdMicro)
                        .foregroundStyle(Color.fdTextMuted)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(levelColor)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(16)
            .background(
                ZStack {
                    isSelected ? levelColor.opacity(0.1) : Color.fdSurfaceHover
                    if isSelected {
                        LinearGradient(
                            colors: [levelColor.opacity(0.08), levelColor.opacity(0)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? levelColor.opacity(0.6) : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.65), value: isSelected)
    }

    private func energyColor(for level: EnergyLevel) -> Color {
        switch level {
        case .high:   .fdAccent
        case .normal: .fdYellow
        case .low:    .fdBlue
        }
    }
}
