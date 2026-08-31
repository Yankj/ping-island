import XCTest
@testable import Ping_Island

final class SessionStoreCompletionSequenceTests: XCTestCase {
    func testHookCompletionSequenceStaysStableForReplayAndAdvancesForNewTurn() async throws {
        let sessionId = "kimi-completion-sequence-\(UUID().uuidString)"
        let store = SessionStore.shared

        await store.process(.hookReceived(makeKimiEvent(
            sessionId: sessionId,
            event: "UserPromptSubmit",
            status: "processing"
        )))
        await store.process(.hookReceived(makeKimiEvent(
            sessionId: sessionId,
            event: "Stop",
            status: "waiting_for_input"
        )))

        let firstSession = await awaitSession(store, sessionId: sessionId)
        let firstCompletion = try XCTUnwrap(firstSession)
        let firstKey = try XCTUnwrap(SessionCompletionKey.make(for: firstCompletion))
        XCTAssertEqual(firstCompletion.completionSequence, 0)

        await store.process(.hookReceived(makeKimiEvent(
            sessionId: sessionId,
            event: "Stop",
            status: "waiting_for_input"
        )))

        let replayedSession = await awaitSession(store, sessionId: sessionId)
        let replayedCompletion = try XCTUnwrap(replayedSession)
        XCTAssertEqual(replayedCompletion.completionSequence, 0)
        XCTAssertEqual(SessionCompletionKey.make(for: replayedCompletion), firstKey)

        await store.process(.hookReceived(makeKimiEvent(
            sessionId: sessionId,
            event: "UserPromptSubmit",
            status: "processing"
        )))
        await store.process(.hookReceived(makeKimiEvent(
            sessionId: sessionId,
            event: "Stop",
            status: "waiting_for_input"
        )))

        let secondSession = await awaitSession(store, sessionId: sessionId)
        let secondCompletion = try XCTUnwrap(secondSession)
        XCTAssertEqual(secondCompletion.completionSequence, 1)
        XCTAssertNotEqual(SessionCompletionKey.make(for: secondCompletion), firstKey)

        await store.process(.sessionArchived(sessionId: sessionId))
    }

    private func awaitSession(_ store: SessionStore, sessionId: String) async -> SessionState? {
        await store.session(for: sessionId)
    }

    private func makeKimiEvent(
        sessionId: String,
        event: String,
        status: String
    ) -> HookEvent {
        HookEvent(
            sessionId: sessionId,
            cwd: "/tmp/ping-island-kimi",
            event: event,
            status: status,
            provider: .kimi,
            clientInfo: SessionClientInfo.default(for: .kimi),
            pid: nil,
            tty: nil,
            tool: nil,
            toolInput: nil,
            toolUseId: nil,
            notificationType: nil,
            message: nil
        )
    }
}
