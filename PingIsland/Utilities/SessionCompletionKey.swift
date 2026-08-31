import Foundation

/// Stable identity for one completed assistant turn.
///
/// Phase transitions are deliberately excluded: app-server polling can replay an
/// old idle snapshot after a session has returned to processing. The turn and
/// assistant-item identifiers remain stable across those replays, so consumers can
/// make completion side effects idempotent.
nonisolated struct SessionCompletionKey: Hashable, Sendable {
    let sessionId: String
    let turnId: String
    let assistantItemId: String?

    nonisolated static func make(for session: SessionState) -> SessionCompletionKey? {
        guard SessionCompletionStateEvaluator.isCompletedReadySession(session) else {
            return nil
        }

        let assistantItemId = latestAssistantItemId(in: session)
        let stableTurnId: String
        if session.provider == .codex,
           let latestTurnId = normalized(session.latestTurnId) {
            stableTurnId = latestTurnId
        } else if let assistantItemId {
            stableTurnId = assistantItemId
        } else if let latestTurnId = normalized(session.latestTurnId) {
            stableTurnId = latestTurnId
        } else {
            stableTurnId = "completion-\(session.completionSequence)"
        }

        return SessionCompletionKey(
            sessionId: session.sessionId,
            turnId: stableTurnId,
            assistantItemId: assistantItemId
        )
    }

    private nonisolated static func latestAssistantItemId(in session: SessionState) -> String? {
        for item in session.chatItems.reversed() {
            switch item.type {
            case .assistant:
                return normalized(item.id)
            case .user, .thinking, .toolCall, .interrupted:
                return nil
            }
        }
        return nil
    }

    private nonisolated static func normalized(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else {
            return nil
        }
        return value
    }
}
