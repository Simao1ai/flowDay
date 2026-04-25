// DailyBriefView.swift
// FlowDay — Morning AI briefing card, shown above stats in TodayView

import SwiftUI

struct DailyBriefView: View {
    let brief: DailyBrief
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "sun.horizon.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.fdAccent)
                    Text("Daily Brief")
                        .font(.fdMicroBold)
                        .foregroundStyle(Color.fdAccent)
                }

                Spacer()

                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.fdTextMuted)
                        .padding(6)
                        .background(Color.fdBorderLight)
                        .clipShape(Circle())
                }
            }

            Text(brief.greeting)
                .font(.fdTitle3)
                .foregroundStyle(Color.fdText)

            VStack(alignment: .leading, spacing: 8) {
                briefLine(icon: "star.fill", text: brief.topPriority, color: Color.fdAccent)
                briefLine(icon: "calendar", text: brief.scheduleSummary, color: Color.fdBlue)
                briefLine(icon: "flame.fill", text: brief.streakMessage, color: Color(hex: "FF6B35"))
            }

            Text(brief.motivationalLine)
                .font(.fdCaption)
                .foregroundStyle(Color.fdTextSecondary)
                .italic()
                .padding(.top, 2)
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [Color.fdAccent.opacity(0.08), Color.fdPurple.opacity(0.06)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.fdAccent.opacity(0.15), lineWidth: 1)
        )
    }

    private func briefLine(icon: String, text: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(color)
                .frame(width: 16)
                .padding(.top, 2)
            Text(text)
                .font(.fdCaption)
                .foregroundStyle(Color.fdTextSecondary)
        }
    }
}

// MARK: - Loading Skeleton

struct DailyBriefSkeletonView: View {
    @State private var shimmer = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                RoundedRectangle(cornerRadius: 4).fill(Color.fdBorderLight).frame(width: 80, height: 12)
                Spacer()
                Circle().fill(Color.fdBorderLight).frame(width: 22, height: 22)
            }
            RoundedRectangle(cornerRadius: 4).fill(Color.fdBorderLight).frame(height: 18)
            RoundedRectangle(cornerRadius: 4).fill(Color.fdBorderLight).frame(height: 12)
            RoundedRectangle(cornerRadius: 4).fill(Color.fdBorderLight).frame(width: 200, height: 12)
        }
        .padding(16)
        .background(Color.fdSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .opacity(shimmer ? 0.5 : 1)
        .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: shimmer)
        .onAppear { shimmer = true }
    }
}
