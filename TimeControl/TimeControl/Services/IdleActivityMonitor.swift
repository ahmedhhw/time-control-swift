//
//  IdleActivityMonitor.swift
//  TimeControl
//

import AppKit
import Combine

// MARK: - State

enum IdleActivityState: Equatable {
    case idle
    case active
    case promptShown
    case cooldown
    case snoozed
    case suppressed
}

// MARK: - RepeatTimer protocol

/// A cancellable repeating timer. Abstracted so tests can inject a controllable fake.
protocol RepeatTimer: AnyObject {
    func cancel()
}

// MARK: - IdleActivityMonitor

/// Watches global/local input events and, when the user is active with no task
/// running, shows the idle prompt after `config.activityThresholdSeconds`.
///
/// Injectable clock and timerFactory make the class fully testable without
/// real time delays.
final class IdleActivityMonitor: ObservableObject {

    // MARK: - Published

    @Published private(set) var state: IdleActivityState = .idle

    // MARK: - Configuration

    private var config: IdlePromptConfig

    // MARK: - Dependencies (injectable for tests)

    var clock: () -> Date
    private let timerFactory: (TimeInterval, @escaping () -> Void) -> any RepeatTimer
    private let userDefaults: UserDefaults

    // MARK: - Internal state

    private(set) var lastActivityAt: Date?
    /// When the current active streak started (transitions from idle→active).
    private var activeStartedAt: Date?
    private var cooldownStartedAt: Date?
    private var snoozeUntil: Date?
    private var promptsShownToday: Int = 0
    private var promptsShownDay: Int = -1  // calendar day component
    static let maxPromptsPerDay = 3

    // MARK: - Timer / event monitors

    private var pollTimer: (any RepeatTimer)?
    private var globalMonitors: [Any] = []
    private var localMonitor: Any?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Callback (set by owner; avoids hard coupling to window manager in tests)

    var onShowPrompt: (() -> Void)?

    // MARK: - Singleton

    static let shared = IdleActivityMonitor()

    // MARK: - Init

    /// Production init — uses real clock and a real Timer wrapper.
    convenience init() {
        self.init(
            config: IdlePromptConfig.load(),
            clock: { Date() },
            timerFactory: { interval, block in
                RealRepeatTimer(interval: interval, block: block)
            },
            userDefaults: .standard
        )
    }

    init(
        config: IdlePromptConfig,
        clock: @escaping () -> Date,
        timerFactory: @escaping (TimeInterval, @escaping () -> Void) -> any RepeatTimer,
        userDefaults: UserDefaults = .standard
    ) {
        self.config = config
        self.clock = clock
        self.timerFactory = timerFactory
        self.userDefaults = userDefaults
        loadSnoozeFromUserDefaults()
    }

    // MARK: - Public API

    func start(viewModel: TodoViewModel) {
        subscribeToViewModel(viewModel)
        startEventMonitors()
        startPollTimer()
    }

    func stop() {
        pollTimer?.cancel()
        pollTimer = nil
        removeEventMonitors()
        cancellables.removeAll()
    }

    /// Called by the prompt view when user taps "Not Now" or X.
    func handleDismiss() {
        cooldownStartedAt = clock()
        state = .cooldown
    }

    /// Called by the prompt view when user taps "Start a Task".
    func handleStartTask() {
        state = .suppressed
    }

    /// Called by the prompt view when user taps "Snooze N min".
    func handleSnooze(minutes: Int) {
        let until = clock().addingTimeInterval(Double(minutes) * 60)
        snoozeUntil = until
        saveSnoozeToUserDefaults(until)
        state = .snoozed
    }

    // MARK: - Private: subscriptions

    private func subscribeToViewModel(_ viewModel: TodoViewModel) {
        viewModel.$runningTaskId
            .receive(on: DispatchQueue.main)
            .sink { [weak self] taskId in
                guard let self else { return }
                if taskId != nil {
                    self.state = .suppressed
                } else {
                    // Only return to idle if we were suppressed (not in cooldown/snooze)
                    if self.state == .suppressed {
                        self.state = .idle
                    }
                }
            }
            .store(in: &cancellables)

        NSWorkspace.shared.notificationCenter
            .publisher(for: NSWorkspace.didWakeNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                // Reset activity tracking after wake so the threshold starts fresh
                self?.lastActivityAt = nil
                self?.activeStartedAt = nil
                if self?.state == .active { self?.state = .idle }
            }
            .store(in: &cancellables)
    }

    // MARK: - Private: event monitors

    private func startEventMonitors() {
        let mask: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDown, .keyDown, .scrollWheel]

        let global = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] _ in
            self?.recordActivity()
        }
        if let g = global { globalMonitors.append(g) }

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
            self?.recordActivity()
            return event
        }
    }

    private func removeEventMonitors() {
        globalMonitors.forEach { NSEvent.removeMonitor($0) }
        globalMonitors.removeAll()
        if let local = localMonitor {
            NSEvent.removeMonitor(local)
            localMonitor = nil
        }
    }

    private func recordActivity() {
        let now = clock()
        lastActivityAt = now
        if state == .idle {
            state = .active
            activeStartedAt = now
        }
    }

    // MARK: - Private: poll timer

    private func startPollTimer() {
        pollTimer = timerFactory(5) { [weak self] in
            self?.evaluateState()
        }
    }

    func evaluateState() {
        let now = clock()

        // Exit cooldown if it has expired
        if case .cooldown = state, let start = cooldownStartedAt {
            if now.timeIntervalSince(start) >= config.cooldownSeconds {
                cooldownStartedAt = nil
                state = .idle
                return
            }
        }

        // Exit snooze if it has expired
        if case .snoozed = state, let until = snoozeUntil {
            if now >= until {
                snoozeUntil = nil
                saveSnoozeToUserDefaults(nil)
                state = .idle
                // Fall through — allow prompt check if activity warrants it
            }
        }

        // Only consider showing a prompt when idle or active
        guard state == .active || state == .idle else { return }
        let enabled: Bool = {
            if userDefaults.object(forKey: IdlePromptConfig.enabledKey) != nil {
                return userDefaults.bool(forKey: IdlePromptConfig.enabledKey)
            }
            return config.enabled
        }()
        guard enabled else { return }

        // Check if activity streak is long enough.
        // `activeStartedAt` is set when we first transition idle→active.
        // We require the user to have been active for at least `activityThresholdSeconds`
        // before showing the prompt.
        guard let activeStart = activeStartedAt else {
            // No active streak recorded yet.
            if state == .active { state = .idle }
            return
        }
        let activeStreak = now.timeIntervalSince(activeStart)
        guard activeStreak >= config.activityThresholdSeconds else {
            // User hasn't been active long enough yet — wait.
            return
        }

        // Also verify the user is still recently active (last event within a reasonable window).
        // If lastActivityAt is nil or very old, don't prompt.
        if let lastActivity = lastActivityAt {
            // Allow up to 2x the threshold since last event (generous for mouse vs keyboard users)
            let staleAfter = config.activityThresholdSeconds * 2
            if now.timeIntervalSince(lastActivity) > staleAfter {
                // Activity streak has gone cold — reset
                activeStartedAt = nil
                if state == .active { state = .idle }
                return
            }
        }

        // Check daily cap
        let day = Calendar.current.component(.day, from: now)
        if day != promptsShownDay {
            promptsShownDay = day
            promptsShownToday = 0
        }
        guard promptsShownToday < IdleActivityMonitor.maxPromptsPerDay else { return }

        // All conditions met — show prompt
        promptsShownToday += 1
        state = .promptShown
        onShowPrompt?()
    }

    // MARK: - Snooze persistence

    private static let snoozeKey = "idlePromptSnoozeUntil"

    private func saveSnoozeToUserDefaults(_ date: Date?) {
        if let date = date {
            userDefaults.set(date.timeIntervalSince1970, forKey: Self.snoozeKey)
        } else {
            userDefaults.removeObject(forKey: Self.snoozeKey)
        }
    }

    private func loadSnoozeFromUserDefaults() {
        guard let interval = userDefaults.object(forKey: Self.snoozeKey) as? TimeInterval else { return }
        let date = Date(timeIntervalSince1970: interval)
        let now = clock()
        if date > now {
            snoozeUntil = date
            state = .snoozed
        }
    }

    // MARK: - Test-only hooks

    /// Records activity at the given date (bypasses real event system in tests).
    func testOnly_recordActivity(at date: Date? = nil) {
        let d = date ?? clock()
        lastActivityAt = d
        if state == .idle {
            state = .active
            activeStartedAt = d
        }
    }
}

// MARK: - RealRepeatTimer

private final class RealRepeatTimer: RepeatTimer {
    private var timer: Timer?

    init(interval: TimeInterval, block: @escaping () -> Void) {
        let t = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in block() }
        RunLoop.main.add(t, forMode: .common)
        self.timer = t
    }

    func cancel() {
        timer?.invalidate()
        timer = nil
    }
}
