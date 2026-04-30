import SwiftUI

/// A beautiful 4-screen onboarding flow for FlowDay
/// Showcases: energy-aware scheduling, unified timeline, natural language input, and habit tracking
struct OnboardingView: View {
    @AppStorage("hasSeenOnboarding") var hasSeenOnboarding = false
    @State private var currentPage = 0

    var body: some View {
        ZStack {
            Color.fdBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                TabView(selection: $currentPage) {
                    EnergyAwareScreen()
                        .tag(0)

                    UnifiedTimelineScreen()
                        .tag(1)

                    NaturalLanguageScreen()
                        .tag(2)

                    ReadyToFlowScreen()
                        .tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .ignoresSafeArea()

                VStack(spacing: 24) {
                    // Page indicators
                    HStack(spacing: 8) {
                        ForEach(0..<4, id: \.self) { page in
                            Capsule()
                                .fill(page == currentPage ? Color.fdAccent : Color.fdTextMuted.opacity(0.3))
                                .frame(width: page == currentPage ? 24 : 8, height: 8)
                                .animation(.easeInOut(duration: 0.3), value: currentPage)
                        }
                        Spacer()
                    }

                    // Action buttons
                    HStack(spacing: 12) {
                        Button(action: {
                            hasSeenOnboarding = true
                        }) {
                            Text("Skip")
                                .font(.fdBody)
                                .foregroundColor(.fdTextSecondary)
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(Color.fdSurface)
                                .cornerRadius(12)
                        }

                        if currentPage == 3 {
                            Button(action: {
                                hasSeenOnboarding = true
                            }) {
                                HStack(spacing: 8) {
                                    Text("Get Started")
                                        .font(.fdBodySemibold)
                                    Image(systemName: "arrow.right")
                                        .font(.system(size: 14, weight: .semibold))
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(Color.fdAccent)
                                .cornerRadius(12)
                            }
                        } else {
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    currentPage += 1
                                }
                            }) {
                                HStack(spacing: 8) {
                                    Text("Next")
                                        .font(.fdBodySemibold)
                                    Image(systemName: "arrow.right")
                                        .font(.system(size: 14, weight: .semibold))
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(Color.fdAccent)
                                .cornerRadius(12)
                            }
                        }
                    }
                }
                .padding(24)
                .background(Color.fdBackground)
            }
        }
    }
}

// MARK: - Screen 1: Your Day, Your Energy
struct EnergyAwareScreen: View {
    @State private var scale: CGFloat = 0.8
    @State private var opacity: Double = 0

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 40) {
                    Spacer()
                        .frame(height: 20)

                    // Illustration with animated battery icon
                    ZStack {
                        // Background gradient circle
                        Circle()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color.fdAccent.opacity(0.1),
                                        Color.fdPurple.opacity(0.05)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 220, height: 220)

                        VStack(spacing: 16) {
                            Image(systemName: "battery.100")
                                .font(.system(size: 80, weight: .thin))
                                .foregroundStyle(
                                    LinearGradient(
                                        gradient: Gradient(colors: [Color.fdAccent, Color.fdPurple]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )

                            Image(systemName: "bolt.fill")
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundColor(.fdAccent)
                                .offset(y: -30)
                        }
                    }
                    .scaleEffect(scale)
                    .opacity(opacity)
                    .onAppear {
                        withAnimation(.easeOut(duration: 0.8).delay(0.2)) {
                            scale = 1
                            opacity = 1
                        }
                    }

                    VStack(spacing: 16) {
                        Text("Your Day, Your Energy")
                            .font(.fdTitle)
                            .foregroundColor(.fdText)
                            .multilineTextAlignment(.center)

                        Text("FlowDay plans your tasks around your natural energy rhythms. No more forcing yourself through mismatched work.")
                            .font(.fdBody)
                            .foregroundColor(.fdTextSecondary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(2)
                    }
                    .padding(.horizontal, 24)

                    Spacer()
                        .frame(height: 40)
                }
            }
        }
    }
}

// MARK: - Screen 2: One Timeline for Everything
struct UnifiedTimelineScreen: View {
    @State private var showTimeline = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 40) {
                    Spacer()
                        .frame(height: 20)

                    // Timeline visualization
                    VStack(spacing: 24) {
                        OnboardingTimelineRow(
                            icon: "checkmark.circle.fill",
                            color: .fdGreen,
                            time: "9:00 AM",
                            title: "Review slides",
                            delay: 0.1,
                            show: $showTimeline
                        )

                        TimelineDivider()

                        OnboardingTimelineRow(
                            icon: "calendar",
                            color: .fdBlue,
                            time: "10:30 AM",
                            title: "Team standup",
                            delay: 0.2,
                            show: $showTimeline
                        )

                        TimelineDivider()

                        OnboardingTimelineRow(
                            icon: "flame.fill",
                            color: .fdAccent,
                            time: "2:00 PM",
                            title: "Build habit streak",
                            delay: 0.3,
                            show: $showTimeline
                        )
                    }
                    .padding(20)
                    .background(Color.fdSurface)
                    .cornerRadius(16)
                    .padding(.horizontal, 24)
                    .onAppear {
                        withAnimation(.easeOut(duration: 0.6).delay(0.3)) {
                            showTimeline = true
                        }
                    }

                    VStack(spacing: 16) {
                        Text("One Timeline for Everything")
                            .font(.fdTitle)
                            .foregroundColor(.fdText)
                            .multilineTextAlignment(.center)

                        Text("Tasks, calendar events, and habits live together in one unified view. See your complete day at a glance.")
                            .font(.fdBody)
                            .foregroundColor(.fdTextSecondary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(2)
                    }
                    .padding(.horizontal, 24)

                    Spacer()
                        .frame(height: 40)
                }
            }
        }
    }
}

// MARK: - Screen 3: Natural Language Input
struct NaturalLanguageScreen: View {
    @State private var showInput = false
    @State private var showChips = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 40) {
                    Spacer()
                        .frame(height: 20)

                    VStack(spacing: 24) {
                        // Input demonstration
                        VStack(spacing: 12) {
                            HStack(spacing: 12) {
                                Image(systemName: "mic.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.fdAccent)

                                Text("Review contract by Friday 2pm p1 #Work 45m")
                                    .font(.fdBody)
                                    .foregroundColor(.fdText)

                                Spacer()

                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.fdGreen)
                                    .opacity(showInput ? 1 : 0)
                            }
                            .padding(16)
                            .background(Color.fdSurface)
                            .cornerRadius(12)
                            .onAppear {
                                withAnimation(.easeOut(duration: 0.6).delay(0.2)) {
                                    showInput = true
                                }
                            }

                            // Parsed chips
                            VStack(spacing: 8) {
                                Text("Automatically parsed:")
                                    .font(.fdCaption)
                                    .foregroundColor(.fdTextMuted)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                FlowWrap(spacing: 8) {
                                    ChipView(
                                        text: "Friday",
                                        icon: "calendar",
                                        color: .fdBlue,
                                        delay: 0.3
                                    )

                                    ChipView(
                                        text: "2:00 PM",
                                        icon: "clock",
                                        color: .fdPurple,
                                        delay: 0.35
                                    )

                                    ChipView(
                                        text: "Urgent",
                                        icon: "flag.fill",
                                        color: .fdRed,
                                        delay: 0.4
                                    )

                                    ChipView(
                                        text: "Work",
                                        icon: "tag.fill",
                                        color: .fdGreen,
                                        delay: 0.45
                                    )

                                    ChipView(
                                        text: "45m",
                                        icon: "hourglass.bottomhalf.fill",
                                        color: .fdAccent,
                                        delay: 0.5
                                    )
                                }
                            }
                            .padding(16)
                            .background(Color.fdSurface)
                            .cornerRadius(12)
                        }
                        .padding(.horizontal, 24)
                    }

                    VStack(spacing: 16) {
                        Text("Just Type It")
                            .font(.fdTitle)
                            .foregroundColor(.fdText)
                            .multilineTextAlignment(.center)

                        Text("Use natural language. FlowDay understands dates, times, priorities, projects, and durations. No complex syntax required.")
                            .font(.fdBody)
                            .foregroundColor(.fdTextSecondary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(2)
                    }
                    .padding(.horizontal, 24)

                    Spacer()
                        .frame(height: 40)
                }
            }
        }
    }
}

// MARK: - Screen 4: Ready to Flow
struct ReadyToFlowScreen: View {
    @State private var logoScale: CGFloat = 0
    @State private var logoRotation: Double = -10
    @State private var textOpacity: Double = 0

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 40) {
                    Spacer()
                        .frame(height: 40)

                    // FlowDay logo
                    ZStack {
                        RoundedRectangle(cornerRadius: 24)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.fdAccent, Color.fdAccent.opacity(0.6)]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 140, height: 140)
                            .shadow(color: Color.fdAccent.opacity(0.4), radius: 20, x: 0, y: 12)

                        Text("F")
                            .font(.system(size: 72, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .scaleEffect(logoScale)
                    .rotation3DEffect(
                        .degrees(logoRotation),
                        axis: (x: 0, y: 1, z: 0)
                    )
                    .onAppear {
                        withAnimation(.easeOut(duration: 0.8).delay(0.2)) {
                            logoScale = 1
                            logoRotation = 0
                        }
                    }

                    VStack(spacing: 16) {
                        Text("Ready to Flow?")
                            .font(.fdTitle)
                            .foregroundColor(.fdText)
                            .multilineTextAlignment(.center)

                        Text("You're all set. Let's transform the way you work with your energy, not against it.")
                            .font(.fdBody)
                            .foregroundColor(.fdTextSecondary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(2)
                    }
                    .padding(.horizontal, 24)
                    .opacity(textOpacity)
                    .onAppear {
                        withAnimation(.easeOut(duration: 0.6).delay(0.6)) {
                            textOpacity = 1
                        }
                    }

                    Spacer()
                        .frame(height: 60)
                }
            }
        }
    }
}

// MARK: - Supporting Views

// Renamed to avoid conflict with the app's enum TimelineItem in TimelineItem.swift
struct OnboardingTimelineRow: View {
    let icon: String
    let color: Color
    let time: String
    let title: String
    let delay: Double
    @Binding var show: Bool

    @State private var localShow = false

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(color)
                .frame(width: 40, height: 40)
                .background(color.opacity(0.1))
                .cornerRadius(8)

            VStack(alignment: .leading, spacing: 4) {
                Text(time)
                    .font(.fdCaption)
                    .foregroundColor(.fdTextMuted)

                Text(title)
                    .font(.fdBodySemibold)
                    .foregroundColor(.fdText)
            }

            Spacer()
        }
        .opacity(localShow ? 1 : 0)
        .offset(y: localShow ? 0 : 16)
        .onChange(of: show) { oldValue, newValue in
            if newValue {
                withAnimation(.easeOut(duration: 0.4).delay(delay)) {
                    localShow = true
                }
            }
        }
    }
}

struct TimelineDivider: View {
    var body: some View {
        HStack {
            RoundedRectangle(cornerRadius: 1)
                .fill(Color.fdTextMuted.opacity(0.2))
                .frame(width: 2, height: 16)
                .padding(.leading, 19)

            Spacer()
        }
    }
}

struct ChipView: View {
    let text: String
    let icon: String
    let color: Color
    let delay: Double

    @State private var show = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))

            Text(text)
                .font(.fdCaption)
                .fontWeight(.semibold)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(color)
        .cornerRadius(8)
        .opacity(show ? 1 : 0)
        .scaleEffect(show ? 1 : 0.8)
        .onAppear {
            withAnimation(.easeOut(duration: 0.3).delay(delay)) {
                show = true
            }
        }
    }
}

// Simple flow layout for chips
struct FlowWrap<Content: View>: View {
    let spacing: CGFloat
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
            content()
        }
    }
}

// MARK: - Preview
#Preview {
    OnboardingView()
}
