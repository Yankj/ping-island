import AVFAudio
import XCTest
@testable import Ping_Island

final class AppSoundSynthesizerTests: XCTestCase {
    func testEverySemanticCueRendersAValidNormalizedBuffer() throws {
        for event in NotificationEvent.allCases {
            let buffer = try XCTUnwrap(AppSoundCueRenderer.makeBuffer(for: event))
            let channels = try XCTUnwrap(buffer.floatChannelData)

            XCTAssertEqual(buffer.format.sampleRate, AppSoundCueRenderer.sampleRate)
            XCTAssertEqual(buffer.format.channelCount, AppSoundCueRenderer.channelCount)
            XCTAssertGreaterThan(buffer.frameLength, 0)

            var peak: Float = 0
            for channel in 0..<Int(buffer.format.channelCount) {
                for frame in 0..<Int(buffer.frameLength) {
                    let sample = channels[channel][frame]
                    XCTAssertTrue(sample.isFinite)
                    peak = max(peak, abs(sample))
                }
            }

            XCTAssertGreaterThan(peak, 0.5, "\(event) should be clearly audible")
            XCTAssertLessThanOrEqual(peak, 0.681, "\(event) should retain headroom")
        }
    }

    func testEverySemanticCueProducesPlayableWaveData() throws {
        for event in NotificationEvent.allCases {
            let buffer = try XCTUnwrap(AppSoundCueRenderer.makeBuffer(for: event))
            let data = try XCTUnwrap(AppSoundCueRenderer.makeWAVData(from: buffer))
            XCTAssertEqual(String(data: data.prefix(4), encoding: .ascii), "RIFF")
            XCTAssertNoThrow(try AVAudioPlayer(data: data), "\(event) should produce playable WAV data")
        }
    }

    func testSemanticCuesStayWithinMicroInteractionLength() {
        for event in NotificationEvent.allCases {
            XCTAssertGreaterThanOrEqual(AppSoundCueRenderer.duration(for: event), 0.15)
            XCTAssertLessThanOrEqual(AppSoundCueRenderer.duration(for: event), 0.6)
        }
    }

    func testOnboardingCeremonyRendersAQuietFiniteBuffer() throws {
        let buffer = try XCTUnwrap(AppSoundCueRenderer.makeOnboardingCeremonyBuffer())
        let channels = try XCTUnwrap(buffer.floatChannelData)
        let duration = Double(buffer.frameLength) / buffer.format.sampleRate
        var peak: Float = 0

        for channel in 0..<Int(buffer.format.channelCount) {
            for frame in 0..<Int(buffer.frameLength) {
                let sample = channels[channel][frame]
                XCTAssertTrue(sample.isFinite)
                peak = max(peak, abs(sample))
            }
        }

        XCTAssertEqual(duration, AppSoundCueRenderer.onboardingCeremonyDuration, accuracy: 0.001)
        XCTAssertGreaterThan(peak, 0.40)
        XCTAssertLessThanOrEqual(peak, 0.541)
    }

    func testEveryOnboardingStageCueRendersAQuietFiniteBuffer() throws {
        for stage in 1...AppSoundCueRenderer.onboardingStageCueCount {
            let buffer = try XCTUnwrap(AppSoundCueRenderer.makeOnboardingStageBuffer(for: stage))
            let channels = try XCTUnwrap(buffer.floatChannelData)
            var peak: Float = 0

            for channel in 0..<Int(buffer.format.channelCount) {
                for frame in 0..<Int(buffer.frameLength) {
                    let sample = channels[channel][frame]
                    XCTAssertTrue(sample.isFinite)
                    peak = max(peak, abs(sample))
                }
            }

            XCTAssertGreaterThan(peak, 0.30)
            XCTAssertLessThanOrEqual(peak, 0.421)
        }
        XCTAssertNil(AppSoundCueRenderer.makeOnboardingStageBuffer(for: 0))
        XCTAssertNil(AppSoundCueRenderer.makeOnboardingStageBuffer(for: 6))
    }

    @MainActor
    func testNotificationSoundGateDebouncesSameEventWithoutSuppressingDifferentEvents() {
        let gate = NotificationSoundGate()
        let start = Date(timeIntervalSince1970: 100)

        XCTAssertTrue(gate.shouldPlay(.attentionRequired, at: start))
        XCTAssertFalse(gate.shouldPlay(.attentionRequired, at: start.addingTimeInterval(0.2)))
        XCTAssertTrue(gate.shouldPlay(.taskCompleted, at: start.addingTimeInterval(0.2)))
        XCTAssertTrue(gate.shouldPlay(.attentionRequired, at: start.addingTimeInterval(0.8)))
    }
}
