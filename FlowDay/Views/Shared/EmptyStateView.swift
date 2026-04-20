// EmptyStateView.swift
// FlowDay
//
// Reusable empty state with a SwiftUI-rendered illustration.
// Picks copy + iconography based on the user's logged energy level so the
// message lands as personal advice instead of a generic "you have no tasks".

import SwiftUI

struct EmptyStateView: View {
    let mood: Mood
    let title: String
    let message: String
    var ctaTitle: String? = nil
    var ctaAction: (() -> Void)? = nil

    enum Mood {
        case calm           // generic "all caught up"
        case lowEnergy      // suggest light work
        case highEnergy     // hint at deep work / planning
        case dayOff         // celebration
        case allDone        // streak / completion
        case overdueClean   // freshly caught up
    }

    var body: some View {
        VStack(spacing: 18) {
            illustration
                .frame(width: 180, height: 180)

            VStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 22, weight: .bold, design: .serif))
                    .foregroundStyle(Color.fdText)
                    .multilineTextAlignment(.center)
                Text(message)
                    .font(.fdBody)
                    .foregroundStyle(Color.fdTextSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }

            if let ctaTitle, let ctaAction {
                Button {
                    Haptics.tap()
                    ctaAction()
                } label: {
                    Text(ctaTitle)
                        .font(.fdBodySemibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 12)
                        .background(Color.fdAccent)
                        .clipShape(Capsule())
                        .shadow(color: Color.fdAccent.opacity(0.35), radius: 12, y: 4)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    // MARK: - Illustration

    @ViewBuilder
    private var illustration: some View {
        switch mood {
        case .calm:         CalmIllustration()
        case .lowEnergy:    LowEnergyIllustration()
        case .highEnergy:   HighEnergyIllustration()
        case .dayOff:       DayOffIllustration()
        case .allDone:      AllDoneIllustration()
        case .overdueClean: OverdueCleanIllustration()
        }
    }
}

// MARK: - Energy-Aware Today Empty State

extension EmptyStateView {

    /// Picks copy that matches the user's logged energy. If no energy is
    /// logged, defaults to a calm "all set" tone.
    static func todayEmpty(energy: EnergyLevel?, onAdd: (() -> Void)? = nil) -> EmptyStateView {
        switch energy {
        case .high:
            return EmptyStateView(
                mood: .highEnergy,
                title: "You're firing on all cylinders",
                message: "Nothing scheduled — perfect window for a deep-work block or planning the week ahead.",
                ctaTitle: onAdd != nil ? "Add a focus task" : nil,
                ctaAction: onAdd
            )
        case .low:
            return EmptyStateView(
                mood: .lowEnergy,
                title: "Take it easy today",
                message: "Low energy detected. Pick a small win — clear your inbox, reply to one message, or take a walk.",
                ctaTitle: onAdd != nil ? "Add a quick task" : nil,
                ctaAction: onAdd
            )
        case .normal:
            return EmptyStateView(
                mood: .calm,
                title: "Steady as she goes",
                message: "Nothing scheduled. What's the one thing you'd like to move forward today?",
                ctaTitle: onAdd != nil ? "Plan today" : nil,
                ctaAction: onAdd
            )
        case nil:
            return EmptyStateView(
                mood: .calm,
                title: "Nothing on your plate",
                message: "Tap the mic to ramble through your day, or add a task below.",
                ctaTitle: nil,
                ctaAction: nil
            )
        }
    }
}

// MARK: - Illustrations (SwiftUI-rendered, no asset dependency)

private struct CalmIllustration: View {
    @State private var sway: CGFloat = -3
    var body: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(colors: [Color.fdAccentLight, Color.fdSurface],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: 160, height: 160)
            Image(systemName: "leaf.fill")
                .font(.system(size: 64))
                .foregroundStyle(Color.fdGreen)
                .rotationEffect(.degrees(sway))
                .onAppear {
                    withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                        sway = 3
                    }
                }
        }
    }
}

private struct LowEnergyIllustration: View {
    @State private var pulse: CGFloat = 1.0
    var body: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(colors: [Color.fdBlueLight, Color.fdSurface],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: 160, height: 160)
            Image(systemName: "moon.zzz.fill")
                .font(.system(size: 60))
                .foregroundStyle(Color.fdBlue)
                .scaleEffect(pulse)
                .onAppear {
                    withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                        pulse = 1.06
                    }
                }
        }
    }
}

private struct HighEnergyIllustration: View {
    @State private var rotate = false
    var body: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(colors: [Color.fdAccentLight, Color.fdYellowLight],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: 160, height: 160)
            Image(systemName: "sparkles")
                .font(.system(size: 60))
                .foregroundStyle(Color.fdAccent)
                .rotationEffect(.degrees(rotate ? 14 : -14))
                .onAppear {
                    withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                        rotate.toggle()
                    }
                }
        }
    }
}

private struct DayOffIllustration: View {
    @State private var bob: CGFloat = -4
    var body: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(colors: [Color.fdGreenLight, Color.fdSurface],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: 160, height: 160)
            Image(systemName: "cup.and.saucer.fill")
                .font(.system(size: 56))
                .foregroundStyle(Color.fdAccent)
                .offset(y: bob)
                .onAppear {
                    withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                        bob = 4
                    }
                }
        }
    }
}

private struct AllDoneIllustration: View {
    @State private var scale: CGFloat = 0.92
    var body: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(colors: [Color.fdGreenLight, Color.fdSurface],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: 160, height: 160)
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 64))
                .foregroundStyle(Color.fdGreen)
                .scaleEffect(scale)
                .onAppear {
                    withAnimation(.spring(response: 1.4, dampingFraction: 0.5).repeatForever(autoreverses: true)) {
                        scale = 1.05
                    }
                }
        }
    }
}

private struct OverdueCleanIllustration: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(colors: [Color.fdGreenLight, Color.fdSurface],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: 160, height: 160)
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(Color.fdGreen)
        }
    }
}
