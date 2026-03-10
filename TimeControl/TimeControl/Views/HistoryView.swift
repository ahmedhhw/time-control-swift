//
//  HistoryView.swift
//  TimeControl
//
//  Created on 3/10/26.
//

import SwiftUI
import AppKit

// MARK: - Data Types

private struct GanttBar {
    let startSeconds: Double  // seconds from midnight of selected day
    let endSeconds: Double    // capped to 86400
    var duration: Double { endSeconds - startSeconds }
}

private struct TimelineEvent: Identifiable {
    let id: UUID
    let label: String
    let colorIndex: Int
    let bar: GanttBar
    let isSubtask: Bool
}

// MARK: - Color Palette

private let ganttPalette: [Color] = [
    Color(red: 0.27, green: 0.52, blue: 0.95),
    Color(red: 0.18, green: 0.72, blue: 0.54),
    Color(red: 0.93, green: 0.56, blue: 0.17),
    Color(red: 0.82, green: 0.30, blue: 0.44),
    Color(red: 0.62, green: 0.42, blue: 0.87),
    Color(red: 0.33, green: 0.68, blue: 0.31),
    Color(red: 0.95, green: 0.77, blue: 0.18),
    Color(red: 0.45, green: 0.70, blue: 0.88),
]

// MARK: - Calendar Day Cell

private struct CalendarDayCell: View {
    let day: Date
    let isSelected: Bool
    let isToday: Bool
    let hasSessions: Bool
    let isFuture: Bool
    let isAdjacentMonth: Bool
    let onTap: () -> Void

    var body: some View {
        VStack(spacing: 2) {
            Text("\(Calendar.current.component(.day, from: day))")
                .font(.system(size: 12, weight: isToday ? .bold : .regular))
                .foregroundColor(labelColor)
                .frame(width: 24, height: 24)
                .background(isSelected ? Color.accentColor : Color.clear)
                .clipShape(Circle())

            Circle()
                .fill(hasSessions && !isAdjacentMonth ? Color.accentColor.opacity(0.7) : Color.clear)
                .frame(width: 4, height: 4)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            guard !isFuture && !isAdjacentMonth else { return }
            onTap()
        }
        .opacity(isAdjacentMonth || isFuture ? 0.25 : 1.0)
    }

    private var labelColor: Color {
        if isSelected { return .white }
        if isToday { return .accentColor }
        return .primary
    }
}

// MARK: - History View

struct HistoryView: View {
    let todos: [TodoItem]

    @State private var displayedMonth: Date = Calendar.current.startOfMonth(for: Date())
    @State private var selectedDay: Date? = nil

    private let hourHeight: CGFloat = 64
    private let timeLabelWidth: CGFloat = 52

    // MARK: - Computed: days with any session data (for dot indicators)

    private var daysWithSessions: Set<String> {
        let cal = Calendar.current
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        var result = Set<String>()

        func markSession(_ session: TaskSession) {
            let startDate = Date(timeIntervalSince1970: session.startedAt)
            result.insert(fmt.string(from: startDate))
            if let stopped = session.stoppedAt {
                let endDate = Date(timeIntervalSince1970: stopped)
                if !cal.isDate(startDate, inSameDayAs: endDate) {
                    result.insert(fmt.string(from: endDate))
                }
            }
        }

        for todo in todos {
            todo.sessions.forEach { markSession($0) }
            for subtask in todo.subtasks {
                subtask.sessions.forEach { markSession($0) }
            }
        }
        return result
    }

    // MARK: - Session Clipping

    private func clipSession(_ session: TaskSession, to day: Date) -> GanttBar? {
        let cal = Calendar.current
        let dayStart = cal.startOfDay(for: day).timeIntervalSince1970
        let dayEnd = dayStart + 86400

        let rawStart = session.startedAt

        // Only extend an open session to "now" if it actually started on the selected day.
        // Sessions with no stoppedAt that started on a different day are orphaned/corrupted — skip them.
        let sessionStartDate = Date(timeIntervalSince1970: rawStart)
        let sessionStartedOnThisDay = cal.isDate(sessionStartDate, inSameDayAs: day)
        guard session.stoppedAt != nil || sessionStartedOnThisDay else { return nil }

        let rawEnd = session.stoppedAt ?? Date().timeIntervalSince1970

        guard rawStart < dayEnd && rawEnd > dayStart else { return nil }

        let clippedStart = max(rawStart, dayStart) - dayStart
        let clippedEnd   = min(rawEnd, dayEnd)   - dayStart

        guard clippedEnd > clippedStart else { return nil }
        return GanttBar(startSeconds: clippedStart, endSeconds: clippedEnd)
    }

    // MARK: - Timeline events (one per session, sorted by time)

    private var timelineEvents: [TimelineEvent] {
        guard let day = selectedDay else { return [] }
        var events: [TimelineEvent] = []
        var colorIdx = 0

        for todo in todos {
            var hasSessions = false

            for session in todo.sessions {
                if let bar = clipSession(session, to: day) {
                    events.append(TimelineEvent(id: UUID(), label: todo.text, colorIndex: colorIdx, bar: bar, isSubtask: false))
                    hasSessions = true
                }
            }

            for subtask in todo.subtasks {
                for session in subtask.sessions {
                    if let bar = clipSession(session, to: day) {
                        events.append(TimelineEvent(id: UUID(), label: subtask.title, colorIndex: colorIdx, bar: bar, isSubtask: true))
                        hasSessions = true
                    }
                }
            }

            if hasSessions { colorIdx += 1 }
        }

        return events.sorted { $0.bar.startSeconds < $1.bar.startSeconds }
    }

    // MARK: - Timeline hour range

    private var timelineHourRange: (start: Int, end: Int) {
        guard !timelineEvents.isEmpty else { return (8, 20) }
        let earliest = timelineEvents.map(\.bar.startSeconds).min() ?? 0
        let latest   = timelineEvents.map(\.bar.endSeconds).max() ?? 86400
        let startHour = max(0, Int(earliest / 3600) - 1)
        let endHour   = min(24, Int(ceil(latest / 3600)) + 1)
        return (startHour, endHour)
    }

    private var totalTime: Double {
        timelineEvents.reduce(0) { $0 + $1.bar.duration }
    }

    // MARK: - Calendar helpers

    private var calendarDays: [Date] {
        let cal = Calendar.current
        guard let monthInterval = cal.dateInterval(of: .month, for: displayedMonth) else { return [] }
        let firstWeekday = cal.component(.weekday, from: monthInterval.start)
        let leadingBlanks = (firstWeekday - 1 + 7) % 7
        guard let start = cal.date(byAdding: .day, value: -leadingBlanks, to: monthInterval.start) else { return [] }
        return (0..<42).compactMap { cal.date(byAdding: .day, value: $0, to: start) }
    }

    private var isCurrentMonth: Bool {
        Calendar.current.isDate(displayedMonth, equalTo: Date(), toGranularity: .month)
    }

    private var monthTitle: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMMM yyyy"
        return fmt.string(from: displayedMonth)
    }

    private func dayHasSessions(_ day: Date) -> Bool {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return daysWithSessions.contains(fmt.string(from: day))
    }

    private func isAdjacentMonth(_ day: Date) -> Bool {
        !Calendar.current.isDate(day, equalTo: displayedMonth, toGranularity: .month)
    }

    private func shiftMonth(by delta: Int) {
        let cal = Calendar.current
        if let newMonth = cal.date(byAdding: .month, value: delta, to: displayedMonth) {
            displayedMonth = cal.startOfMonth(for: newMonth)
        }
    }

    // MARK: - Body

    var body: some View {
        HStack(spacing: 0) {
            calendarPanel
            Divider()
            ganttPanel
        }
        .onAppear {
            displayedMonth = Calendar.current.startOfMonth(for: Date())
        }
    }

    // MARK: - Calendar Panel

    @ViewBuilder private var calendarPanel: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: { shiftMonth(by: -1) }) {
                    Image(systemName: "chevron.left").font(.body)
                }
                .buttonStyle(.plain)
                Spacer()
                Text(monthTitle).font(.headline)
                Spacer()
                Button(action: { shiftMonth(by: 1) }) {
                    Image(systemName: "chevron.right").font(.body)
                }
                .buttonStyle(.plain)
                .disabled(isCurrentMonth)
                .opacity(isCurrentMonth ? 0.3 : 1.0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            let daySymbols = ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7), spacing: 2) {
                ForEach(daySymbols, id: \.self) { sym in
                    Text(sym)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 4)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7), spacing: 4) {
                ForEach(calendarDays, id: \.self) { day in
                    CalendarDayCell(
                        day: day,
                        isSelected: selectedDay.map { Calendar.current.isDate($0, inSameDayAs: day) } ?? false,
                        isToday: Calendar.current.isDateInToday(day),
                        hasSessions: dayHasSessions(day),
                        isFuture: day > Date(),
                        isAdjacentMonth: isAdjacentMonth(day),
                        onTap: { selectedDay = Calendar.current.startOfDay(for: day) }
                    )
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 8)

            Spacer()
        }
        .frame(width: 220)
        .background(Color(NSColor.controlBackgroundColor))
    }

    // MARK: - Gantt Panel (vertical timeline)

    @ViewBuilder private var ganttPanel: some View {
        if selectedDay == nil {
            VStack {
                Spacer()
                Image(systemName: "calendar")
                    .font(.system(size: 40))
                    .foregroundColor(.secondary.opacity(0.35))
                Text("Select a day to view sessions")
                    .foregroundColor(.secondary)
                    .font(.body)
                    .padding(.top, 8)
                Spacer()
            }
        } else if timelineEvents.isEmpty {
            VStack {
                Spacer()
                Image(systemName: "clock.badge.xmark")
                    .font(.system(size: 40))
                    .foregroundColor(.secondary.opacity(0.35))
                Text("No sessions on this day")
                    .foregroundColor(.secondary)
                    .font(.body)
                    .padding(.top, 8)
                Spacer()
            }
        } else {
            VStack(spacing: 0) {
                HStack {
                    Text(dayTitle)
                        .font(.headline)
                    Spacer()
                    Text("Total: \(TimeFormatter.formatTime(totalTime))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                Divider()

                ScrollView(.vertical) {
                    verticalTimeline
                        .padding(.vertical, 12)
                        .padding(.trailing, 12)
                }
            }
        }
    }

    // MARK: - Event Groups

    private struct EventGroup: Identifiable {
        var id: Int { colorIndex }
        let colorIndex: Int
        let parentEvents: [TimelineEvent]
        let subtaskEvents: [TimelineEvent]
    }

    private var groupedEventSets: [EventGroup] {
        var dict: [Int: ([TimelineEvent], [TimelineEvent])] = [:]
        for event in timelineEvents {
            var pair = dict[event.colorIndex] ?? ([], [])
            if event.isSubtask { pair.1.append(event) } else { pair.0.append(event) }
            dict[event.colorIndex] = pair
        }
        return dict
            .map { EventGroup(colorIndex: $0.key, parentEvents: $0.value.0, subtaskEvents: $0.value.1) }
            .sorted { $0.colorIndex < $1.colorIndex }
    }

    // MARK: - Vertical Timeline

    @ViewBuilder private var verticalTimeline: some View {
        let (startHour, endHour) = timelineHourRange
        let totalHeight = CGFloat(endHour - startHour) * hourHeight
        let groups = groupedEventSets

        GeometryReader { geo in
            let blockAreaWidth = geo.size.width - timeLabelWidth - 8
            let gap: CGFloat = 4

            ZStack(alignment: .topLeading) {
                // Invisible spacer to define the ZStack size
                Color.clear
                    .frame(width: geo.size.width, height: totalHeight)

                // Hour grid lines + labels
                ForEach(startHour...endHour, id: \.self) { hour in
                    hourRow(hour: hour, startHour: startHour)
                }

                // Session blocks, split into left (parent) / right (subtask) lanes per group
                ForEach(groups, id: \.id) { group in
                    groupLaneBlocks(group, startHour: startHour, blockAreaWidth: blockAreaWidth, gap: gap)
                }

                // Current time indicator (today only)
                if let day = selectedDay, Calendar.current.isDateInToday(day) {
                    currentTimeIndicator(startHour: startHour)
                }
            }
        }
        .frame(minHeight: totalHeight)
    }

    @ViewBuilder
    private func groupLaneBlocks(_ group: EventGroup, startHour: Int, blockAreaWidth: CGFloat, gap: CGFloat) -> some View {
        let hasBoth = !group.parentEvents.isEmpty && !group.subtaskEvents.isEmpty
        let laneWidth = hasBoth ? (blockAreaWidth - gap) / 2 : blockAreaWidth
        let subtaskXOffset: CGFloat = hasBoth ? laneWidth + gap : 0

        ForEach(group.parentEvents) { event in
            sessionBlock(event: event, startHour: startHour, xOffset: 0, width: laneWidth)
        }
        ForEach(group.subtaskEvents) { event in
            sessionBlock(event: event, startHour: startHour, xOffset: subtaskXOffset, width: laneWidth)
        }
    }

    private func hourRow(hour: Int, startHour: Int) -> some View {
        let yOffset = CGFloat(hour - startHour) * hourHeight
        return HStack(spacing: 0) {
            Text(hourLabel(hour))
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .frame(width: timeLabelWidth, alignment: .trailing)
                .padding(.trailing, 8)
            Rectangle()
                .fill(Color.secondary.opacity(0.15))
                .frame(height: 1)
        }
        .frame(maxWidth: .infinity)
        .offset(y: yOffset)
    }

    private func sessionBlock(event: TimelineEvent, startHour: Int, xOffset: CGFloat, width: CGFloat) -> some View {
        let yOffset = CGFloat(event.bar.startSeconds / 3600 - Double(startHour)) * hourHeight
        let blockH  = max(24, CGFloat(event.bar.duration / 3600) * hourHeight)
        let color   = ganttPalette[event.colorIndex % ganttPalette.count]

        let startH = Int(event.bar.startSeconds) / 3600
        let startM = Int(event.bar.startSeconds) / 60 % 60
        let endH   = Int(event.bar.endSeconds) / 3600
        let endM   = Int(event.bar.endSeconds) / 60 % 60
        let timeStr = String(format: "%d:%02d – %d:%02d", startH, startM, endH, endM)

        return VStack(alignment: .leading, spacing: 2) {
            Text(event.label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(1)
            if blockH >= 38 {
                Text(timeStr)
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.85))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .frame(width: width, height: blockH, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(color.opacity(event.isSubtask ? 0.75 : 1.0))
        )
        .offset(x: timeLabelWidth + 8 + xOffset, y: yOffset)
    }

    private func currentTimeIndicator(startHour: Int) -> some View {
        let cal = Calendar.current
        let now = Date()
        let secondsSinceMidnight = now.timeIntervalSince(cal.startOfDay(for: now))
        let yOffset = CGFloat(secondsSinceMidnight / 3600 - Double(startHour)) * hourHeight

        return HStack(spacing: 0) {
            Spacer().frame(width: timeLabelWidth + 2)
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.red)
                    .frame(height: 1.5)
                Circle()
                    .fill(Color.red)
                    .frame(width: 9, height: 9)
                    .offset(x: -4)
            }
        }
        .frame(maxWidth: .infinity)
        .offset(y: yOffset)
    }

    // MARK: - Helpers

    private var dayTitle: String {
        guard let day = selectedDay else { return "" }
        let fmt = DateFormatter()
        fmt.dateStyle = .full
        return fmt.string(from: day)
    }

    private func hourLabel(_ hour: Int) -> String {
        let h = hour % 24
        if h == 0  { return "12 AM" }
        if h < 12  { return "\(h) AM" }
        if h == 12 { return "12 PM" }
        return "\(h - 12) PM"
    }
}

// MARK: - Calendar Extension

private extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        let comps = dateComponents([.year, .month], from: date)
        return self.date(from: comps) ?? date
    }
}
