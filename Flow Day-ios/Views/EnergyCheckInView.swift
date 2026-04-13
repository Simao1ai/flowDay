// EnergyCheckInView.swift
// FlowDay

import SwiftUI

struct EnergyCheckInView: View {
    let onSelect: (EnergyLevel) -> Void
    let onSkip: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
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
            .shadow(color: .black.opacity(0.12), radius: 30, y: 10)
            .padding(.horizontal, 32)
        }
    }

    private func energyButton(_ level: EnergyLevel) -> some View {
        Button {
            onSelect(level)
        } label: {
            HStack(spacing: 14) {
                Text(level.emoji)
                    .font(.title2)
                VStack(alignment: .leading, spacing: 2) {
                    Text(level.label)
                        .font(.fdBodySemibold)
                        .foregroundStyle(Color.fdText)
                    Text(level.description)
                        .font(.fdMicro)
                        .foregroundStyle(Color.fdTextMuted)
                }
                Spacer()
            }
            .padding(16)
            .background(Color.fdSurfaceHover)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
}
