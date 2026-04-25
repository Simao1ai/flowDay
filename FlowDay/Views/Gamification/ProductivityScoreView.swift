// ProductivityScoreView.swift
// FlowDay — Level, XP, streak, and achievements overview

import SwiftUI

struct ProductivityScoreView: View {
    @Environment(\.dismiss) private var dismiss

    private var gam: GamificationService { GamificationService.shared }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 28) {
                    levelCard
                    streakCard
                    achievementsSection
                }
                .padding(20)
                .padding(.bottom, 40)
            }
            .background(Color.fdBackground)
            .navigationTitle("Productivity Score")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(Color.fdTextMuted)
                            .font(.system(size: 22))
                    }
                }
            }
        }
    }

    // MARK: - Level Card

    private var levelCard: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .stroke(Color.fdBorderLight, lineWidth: 12)
                    .frame(width: 140, height: 140)
                Circle()
                    .trim(from: 0, to: CGFloat(gam.xpProgress))
                    .stroke(
                        LinearGradient(
                            colors: [Color.fdAccent, Color.fdPurple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .frame(width: 140, height: 140)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.6), value: gam.xpProgress)

                VStack(spacing: 4) {
                    Text("Level")
                        .font(.fdMicro)
                        .foregroundStyle(Color.fdTextMuted)
                    Text("\(gam.level)")
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.fdText)
                }
            }

            VStack(spacing: 6) {
                Text("\(gam.xpInCurrentLevel) / 100 XP")
                    .font(.fdCaptionBold)
                    .foregroundStyle(Color.fdTextSecondary)
                Text("\(gam.totalXP) total XP earned")
                    .font(.fdMicro)
                    .foregroundStyle(Color.fdTextMuted)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .background(Color.fdSurface)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.04), radius: 6, y: 3)
    }

    // MARK: - Streak Card

    private var streakCard: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.fdAccent.opacity(0.1))
                    .frame(width: 56, height: 56)
                Text("🔥")
                    .font(.system(size: 28))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("\(gam.currentStreak)-Day Streak")
                    .font(.fdTitle3)
                    .foregroundStyle(Color.fdText)
                Text(gam.currentStreak > 0 ? "Keep it up! Check in tomorrow." : "Complete a task to start your streak.")
                    .font(.fdCaption)
                    .foregroundStyle(Color.fdTextMuted)
            }

            Spacer()
        }
        .padding(16)
        .background(Color.fdSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
    }

    // MARK: - Achievements

    private var achievementsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ACHIEVEMENTS")
                .fdSectionHeader()

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(Achievement.allCases, id: \.self) { achievement in
                    achievementBadge(achievement)
                }
            }
        }
    }

    private func achievementBadge(_ achievement: Achievement) -> some View {
        let unlocked = gam.unlockedAchievements.contains(achievement)

        return VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(unlocked ? Color.fdAccent.opacity(0.12) : Color.fdSurface)
                    .frame(width: 60, height: 60)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(unlocked ? Color.fdAccent.opacity(0.3) : Color.fdBorderLight, lineWidth: 1)
                    )

                Image(systemName: achievement.icon)
                    .font(.system(size: 24))
                    .foregroundStyle(unlocked ? Color.fdAccent : Color.fdTextMuted.opacity(0.4))
            }

            Text(achievement.title)
                .font(.fdMicro)
                .foregroundStyle(unlocked ? Color.fdText : Color.fdTextMuted)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .opacity(unlocked ? 1 : 0.5)
    }
}

// MARK: - XP Toast Banner

struct XPToastBanner: View {
    let item: GamificationService.ToastItem
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.fdAccent.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: item.icon)
                    .font(.system(size: 18))
                    .foregroundStyle(Color.fdAccent)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.fdCaptionBold)
                    .foregroundStyle(Color.fdText)
                Text(item.subtitle)
                    .font(.fdMicro)
                    .foregroundStyle(Color.fdTextMuted)
            }

            Spacer()

            Text("+\(item.xp) XP")
                .font(.fdCaptionBold)
                .foregroundStyle(Color.fdAccent)
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
        .padding(.horizontal, 16)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                withAnimation(.easeOut(duration: 0.3)) { onDismiss() }
            }
        }
    }
}

#Preview {
    ProductivityScoreView()
}
