// AutoScheduleView.swift
// FlowDay — Wave 5b
//
// 7-day AI auto-schedule sheet. Shows AI-suggested time blocks per day,
// lets the user swipe-to-reject individual blocks, then applies all accepted
// blocks to the task timeline via TaskService.

import SwiftUI
import SwiftData

struct AutoScheduleView: View {
    let taskService: TaskService?
    let calendarService: CalendarService
    let energyLevel: EnergyLevel?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query private var allTasksRaw: [FDTask]
    private var allTasks: [FDTask] { allTasksRaw.filter { !$0.isDeleted } }

    @State private var service = AutoScheduleService()
    @State private var showSuccess = false

    private var resolvedTaskService: TaskService {
        taskService ?? TaskService(modelContext: modelContext)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if showSuccess {
                        successView
                    } else if service.isLoading {
                        loadingView
                    } else if let errorMsg = service.errorMessage {
                        errorView(errorMsg)
                    } else if let week = service.schedule {
                        if week.days.isEmpty {
                            emptyState
                        } else {
                            scheduleContent(week)
                        }
                    }
                }
                .padding(20)
            }
            .background(Color.fdBackground)
            .navigationTitle("Auto-Schedule Week")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.fdTextSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if service.schedule != nil && !showSuccess {
                        Button("Regenerate") {
                            Task { await regenerate() }
                        }
                        .foregroundStyle(Color.fdAccent)
                        .font(.fdCaption)
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if service.schedule != nil && !showSuccess && !service.isLoading {
                    acceptAllBar
                }
            }
            .task { await regenerate() }
        }
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: 20) {
            aiHeader

            VStack(spacing: 12) {
                ForEach(0..<4, id: \.self) { _ in
                    skeletonBlock
                }
            }
        }
    }

    private var skeletonBlock: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.fdSurface)
                .frame(width: 48, height: 14)
            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.fdSurface)
                    .frame(height: 12)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.fdSurface)
                    .frame(width: 120, height: 10)
            }
            Spacer()
        }
        .padding(14)
        .background(Color.fdSurface.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .redacted(reason: .placeholder)
        .shimmer()
    }

    // MARK: - Schedule Content

    private func scheduleContent(_ week: ScheduledWeek) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            aiHeader

            Text("Swipe left to reject a block. Tap Accept All to apply.")
                .font(.fdCaption)
                .foregroundStyle(Color.fdTextMuted)

            ForEach(week.days) { day in
                daySection(day)
            }

            Spacer(minLength: 80)
        }
    }

    private func daySection(_ day: ScheduledDay) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "calendar")
                    .font(.system(size: 11))
                Text("\(day.dayLabel) · \(day.dateLabel)")
            }
            .fdSectionHeader()

            let accepted = day.blocks.filter(\.isAccepted)
            if accepted.isEmpty {
                Text("All blocks rejected")
                    .font(.fdMicro)
                    .foregroundStyle(Color.fdTextMuted)
                    .padding(.leading, 4)
            } else {
                ForEach(accepted) { block in
                    timeBlockRow(block)
                }
            }
        }
    }

    private func timeBlockRow(_ block: TimeBlock) -> some View {
        HStack(spacing: 14) {
            // Time pill
            Text(block.time.formatted(.dateTime.hour().minute()))
                .font(.fdCaptionBold)
                .foregroundStyle(Color.fdAccent)
                .frame(width: 50, alignment: .leading)

            VStack(alignment: .leading, spacing: 3) {
                Text(block.taskTitle)
                    .font(.fdBodySemibold)
                    .foregroundStyle(Color.fdText)
                    .lineLimit(1)
                Text(block.reason)
                    .font(.fdMicro)
                    .foregroundStyle(Color.fdTextMuted)
                    .lineLimit(2)
            }

            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 18))
                .foregroundStyle(Color.fdGreen.opacity(0.7))
        }
        .padding(14)
        .background(Color.fdSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.fdBorderLight, lineWidth: 1)
        )
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                withAnimation { service.rejectBlock(id: block.id) }
            } label: {
                Label("Reject", systemImage: "xmark")
            }
        }
    }

    // MARK: - Accept All Bar

    private var acceptAllBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(service.acceptedCount) block\(service.acceptedCount == 1 ? "" : "s") accepted")
                        .font(.fdCaptionBold)
                        .foregroundStyle(Color.fdText)
                }

                Spacer()

                Button {
                    service.acceptAll()
                } label: {
                    Text("Accept All")
                        .font(.fdMicro)
                        .foregroundStyle(Color.fdAccent)
                }

                Button {
                    applySchedule()
                } label: {
                    Text("Apply")
                        .font(.fdBodySemibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(service.acceptedCount == 0 ? Color.fdTextMuted : Color.fdAccent)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .disabled(service.acceptedCount == 0)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color.fdBackground)
        }
    }

    // MARK: - AI Header

    private var aiHeader: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        LinearGradient(
                            colors: [Color.fdAccent, Color.fdPurple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 48, height: 48)
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("AI Auto-Schedule")
                    .font(.fdTitle3)
                    .foregroundStyle(Color.fdText)
                HStack(spacing: 4) {
                    Circle()
                        .fill(service.isLoading ? Color.fdYellow : Color.fdGreen)
                        .frame(width: 6, height: 6)
                    Text(service.isLoading ? "Generating schedule…" : "Schedule ready")
                        .font(.fdMicro)
                        .foregroundStyle(Color.fdTextMuted)
                }
            }
        }
    }

    // MARK: - Empty / Error / Success

    private var emptyState: some View {
        VStack(spacing: 12) {
            aiHeader
            VStack(spacing: 8) {
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 44))
                    .foregroundStyle(Color.fdGreen.opacity(0.5))
                Text("All caught up!")
                    .font(.fdTitle3).foregroundStyle(Color.fdText)
                Text("No unscheduled tasks to plan.")
                    .font(.fdCaption).foregroundStyle(Color.fdTextMuted)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
        }
    }

    private func errorView(_ msg: String) -> some View {
        VStack(spacing: 12) {
            aiHeader
            VStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 36))
                    .foregroundStyle(Color.fdYellow)
                Text("Couldn't generate schedule")
                    .font(.fdTitle3).foregroundStyle(Color.fdText)
                Text(msg)
                    .font(.fdCaption).foregroundStyle(Color.fdTextMuted)
                    .multilineTextAlignment(.center)
                Button("Try Again") {
                    Task { await regenerate() }
                }
                .font(.fdCaptionBold)
                .foregroundStyle(Color.fdAccent)
                .padding(.top, 4)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
        }
    }

    private var successView: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(Color.fdGreen)
            Text("Schedule Applied!")
                .font(.fdTitle2).foregroundStyle(Color.fdText)
            Text("Your tasks have been scheduled. Check your timeline to see the week ahead.")
                .font(.fdCaption).foregroundStyle(Color.fdTextMuted)
                .multilineTextAlignment(.center)
            Button {
                dismiss()
            } label: {
                Text("View Timeline")
                    .font(.fdBodySemibold)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.fdAccent)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - Actions

    private func regenerate() async {
        let events = calendarService.allTodayEvents.map { e in
            (start: e.startDate, end: e.endDate, title: e.title)
        }
        await service.generateSchedule(
            tasks: allTasks,
            calendarEvents: events,
            energyLevel: energyLevel
        )
    }

    private func applySchedule() {
        service.applyAccepted(allTasks: allTasks, using: resolvedTaskService)
        withAnimation(.easeInOut(duration: 0.4)) {
            showSuccess = true
        }
    }
}

// MARK: - Shimmer Modifier

private extension View {
    func shimmer() -> some View {
        self.overlay(
            LinearGradient(
                colors: [.clear, Color.white.opacity(0.15), .clear],
                startPoint: .leading,
                endPoint: .trailing
            )
            .rotationEffect(.degrees(20))
        )
    }
}
