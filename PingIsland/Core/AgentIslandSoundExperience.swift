import Foundation

enum UsageSoundTransitionEvaluator {
    nonisolated static func maximumUsedPercentage(
        claude: ClaudeUsageSnapshot?,
        codex: CodexUsageSnapshot?
    ) -> Double? {
        let claudeValues = [claude?.fiveHour?.usedPercentage, claude?.sevenDay?.usedPercentage]
            .compactMap { $0 }
        let codexValues = codex?.windows.map(\.usedPercentage) ?? []
        return (claudeValues + codexValues).max()
    }

    nonisolated static func event(previous: Double?, current: Double?) -> NotificationEvent? {
        guard let previous, let current else { return nil }

        if previous < 90, current >= 90 {
            return .usageWarning
        }
        if previous >= 50, current <= 20 {
            return .usageReset
        }
        return nil
    }
}

struct RapidSubmitSoundTracker {
    private var hasPrimed = false
    private var lastObservedMessageDate: [String: Date] = [:]
    private var recentSubmissions: [String: [Date]] = [:]
    private var lastTriggeredAt: [String: Date] = [:]

    mutating func observe(_ sessions: [SessionState], now: Date = Date()) -> [SessionState] {
        let activeIDs = Set(sessions.map(\.stableId))
        lastObservedMessageDate = lastObservedMessageDate.filter { activeIDs.contains($0.key) }
        recentSubmissions = recentSubmissions.filter { activeIDs.contains($0.key) }
        lastTriggeredAt = lastTriggeredAt.filter { activeIDs.contains($0.key) }

        guard hasPrimed else {
            for session in sessions {
                lastObservedMessageDate[session.stableId] = session.lastUserMessageDate
            }
            hasPrimed = true
            return []
        }

        var triggered: [SessionState] = []
        for session in sessions {
            guard let messageDate = session.lastUserMessageDate else { continue }
            let id = session.stableId
            defer { lastObservedMessageDate[id] = messageDate }

            guard messageDate > (lastObservedMessageDate[id] ?? .distantPast),
                  abs(now.timeIntervalSince(messageDate)) <= 12 else {
                continue
            }

            var timestamps = recentSubmissions[id] ?? []
            timestamps.append(messageDate)
            timestamps.removeAll { now.timeIntervalSince($0) > 10 }
            recentSubmissions[id] = timestamps

            if timestamps.count >= 3,
               now.timeIntervalSince(lastTriggeredAt[id] ?? .distantPast) >= 10 {
                lastTriggeredAt[id] = now
                recentSubmissions[id] = []
                triggered.append(session)
            }
        }
        return triggered
    }
}

struct IdleReminderSoundTracker {
    nonisolated static let reminderDelay: TimeInterval = 5 * 60
    private var remindedSessionIDs: Set<String> = []

    mutating func sessionsNeedingReminder(
        from sessions: [SessionState],
        now: Date = Date()
    ) -> [SessionState] {
        let eligible = sessions.filter { session in
            session.phase == .waitingForInput
                && now.timeIntervalSince(session.lastActivity) >= Self.reminderDelay
        }
        let eligibleIDs = Set(eligible.map(\.stableId))
        remindedSessionIDs.formIntersection(eligibleIDs)

        let result = eligible.filter { !remindedSessionIDs.contains($0.stableId) }
        remindedSessionIDs.formUnion(result.map(\.stableId))
        return result
    }
}
