import Foundation
import XCTest
@testable import Ping_Island

@MainActor
final class AgentIslandExperienceTests: XCTestCase {
    func testVersionedOnboardingRemainsPendingUntilCompleted() {
        let suiteName = "AgentIslandExperienceTests.onboarding.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        var pendingCount = 0

        XCTAssertTrue(
            AgentIslandOnboardingExperience.prepareForLaunch(
                defaults: defaults,
                currentIdentifier: "welcome-v2",
                markPending: { pendingCount += 1 }
            )
        )
        XCTAssertEqual(pendingCount, 1)

        AgentIslandOnboardingExperience.markCompleted(
            defaults: defaults,
            currentIdentifier: "welcome-v2"
        )
        XCTAssertFalse(
            AgentIslandOnboardingExperience.prepareForLaunch(
                defaults: defaults,
                currentIdentifier: "welcome-v2",
                markPending: { pendingCount += 1 }
            )
        )
        XCTAssertEqual(pendingCount, 1)
    }

    func testUsageSoundTransitionsDetectWarningAndResetEdges() {
        XCTAssertEqual(
            UsageSoundTransitionEvaluator.event(previous: 84, current: 92),
            .usageWarning
        )
        XCTAssertEqual(
            UsageSoundTransitionEvaluator.event(previous: 72, current: 14),
            .usageReset
        )
        XCTAssertNil(UsageSoundTransitionEvaluator.event(previous: 91, current: 95))
    }

    func testIdleReminderOnlyFiresOncePerWaitingPeriod() {
        let now = Date(timeIntervalSince1970: 1_000)
        var tracker = IdleReminderSoundTracker()
        var session = makeSession(
            id: "idle-reminder",
            phase: .waitingForInput,
            lastActivity: now.addingTimeInterval(-IdleReminderSoundTracker.reminderDelay - 1)
        )

        XCTAssertEqual(tracker.sessionsNeedingReminder(from: [session], now: now).count, 1)
        XCTAssertTrue(tracker.sessionsNeedingReminder(from: [session], now: now).isEmpty)

        session.phase = .processing
        XCTAssertTrue(tracker.sessionsNeedingReminder(from: [session], now: now).isEmpty)
        session.phase = .waitingForInput
        XCTAssertEqual(tracker.sessionsNeedingReminder(from: [session], now: now).count, 1)
    }

    func testRapidSubmitFiresAfterThreeNewMessagesWithinTenSeconds() {
        let now = Date(timeIntervalSince1970: 2_000)
        var tracker = RapidSubmitSoundTracker()
        var session = makeSession(id: "rapid", lastUserMessageDate: now.addingTimeInterval(-5))

        XCTAssertTrue(tracker.observe([session], now: now).isEmpty)
        session = makeSession(id: "rapid", lastUserMessageDate: now.addingTimeInterval(-3))
        XCTAssertTrue(tracker.observe([session], now: now).isEmpty)
        session = makeSession(id: "rapid", lastUserMessageDate: now.addingTimeInterval(-2))
        XCTAssertTrue(tracker.observe([session], now: now).isEmpty)
        session = makeSession(id: "rapid", lastUserMessageDate: now.addingTimeInterval(-1))
        XCTAssertEqual(tracker.observe([session], now: now).map(\.sessionId), ["rapid"])
    }

    private func makeSession(
        id: String,
        phase: SessionPhase = .idle,
        lastActivity: Date = Date(),
        lastUserMessageDate: Date? = nil
    ) -> SessionState {
        SessionState(
            sessionId: id,
            cwd: "/tmp/\(id)",
            phase: phase,
            conversationInfo: ConversationInfo(
                summary: nil,
                lastMessage: nil,
                lastMessageRole: nil,
                lastToolName: nil,
                firstUserMessage: nil,
                lastUserMessageDate: lastUserMessageDate
            ),
            lastActivity: lastActivity
        )
    }
}
