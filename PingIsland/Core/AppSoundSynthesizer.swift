import AVFAudio
import Foundation

struct SynthCueTone: Equatable {
    let frequency: Double
    let start: TimeInterval
    let duration: TimeInterval
    let amplitude: Double
    var attack: TimeInterval = 0.012
    var release: TimeInterval = 0.12
    var harmonicMix: Double = 0.14
    var pan: Double = 0
}

enum AppSoundCueRenderer {
    nonisolated static let sampleRate = 48_000.0
    nonisolated static let channelCount: AVAudioChannelCount = 2
    nonisolated static let onboardingCeremonyDuration: TimeInterval = 6.00
    nonisolated static let onboardingStageCueDuration: TimeInterval = 0.38
    nonisolated static let onboardingStageCueCount = 5

    nonisolated static func duration(for event: NotificationEvent) -> TimeInterval {
        switch event {
        case .sessionStarted: 0.48
        case .processingStarted: 0.24
        case .attentionRequired: 0.42
        case .taskCompleted: 0.52
        case .taskError: 0.46
        case .resourceLimit: 0.50
        case .idleReminder: 0.56
        case .usageWarning: 0.52
        case .usageReset: 0.58
        case .rapidSubmit: 0.38
        }
    }

    nonisolated static func tones(for event: NotificationEvent) -> [SynthCueTone] {
        switch event {
        case .sessionStarted:
            return [
                SynthCueTone(frequency: 329.63, start: 0.00, duration: 0.26, amplitude: 0.42, pan: -0.26),
                SynthCueTone(frequency: 493.88, start: 0.09, duration: 0.28, amplitude: 0.50, pan: 0.22),
                SynthCueTone(frequency: 659.25, start: 0.19, duration: 0.27, amplitude: 0.38)
            ]
        case .processingStarted:
            return [
                SynthCueTone(frequency: 659.25, start: 0.00, duration: 0.13, amplitude: 0.62),
                SynthCueTone(frequency: 783.99, start: 0.08, duration: 0.15, amplitude: 0.48)
            ]
        case .attentionRequired:
            return [
                SynthCueTone(frequency: 587.33, start: 0.00, duration: 0.19, amplitude: 0.54),
                SynthCueTone(frequency: 880.00, start: 0.15, duration: 0.25, amplitude: 0.72)
            ]
        case .taskCompleted:
            return [
                SynthCueTone(frequency: 523.25, start: 0.00, duration: 0.22, amplitude: 0.48),
                SynthCueTone(frequency: 659.25, start: 0.09, duration: 0.27, amplitude: 0.56),
                SynthCueTone(frequency: 783.99, start: 0.18, duration: 0.31, amplitude: 0.64)
            ]
        case .taskError:
            return [
                SynthCueTone(frequency: 392.00, start: 0.00, duration: 0.22, amplitude: 0.64),
                SynthCueTone(frequency: 277.18, start: 0.16, duration: 0.28, amplitude: 0.70)
            ]
        case .resourceLimit:
            return [
                SynthCueTone(frequency: 440.00, start: 0.00, duration: 0.18, amplitude: 0.58),
                SynthCueTone(frequency: 440.00, start: 0.26, duration: 0.20, amplitude: 0.66)
            ]
        case .idleReminder:
            return [
                SynthCueTone(frequency: 523.25, start: 0.00, duration: 0.23, amplitude: 0.40, release: 0.19, pan: -0.18),
                SynthCueTone(frequency: 659.25, start: 0.28, duration: 0.25, amplitude: 0.44, release: 0.20, pan: 0.18)
            ]
        case .usageWarning:
            return [
                SynthCueTone(frequency: 698.46, start: 0.00, duration: 0.20, amplitude: 0.54, pan: -0.20),
                SynthCueTone(frequency: 523.25, start: 0.14, duration: 0.22, amplitude: 0.58),
                SynthCueTone(frequency: 392.00, start: 0.29, duration: 0.21, amplitude: 0.50, pan: 0.20)
            ]
        case .usageReset:
            return [
                SynthCueTone(frequency: 392.00, start: 0.00, duration: 0.25, amplitude: 0.38, pan: -0.30),
                SynthCueTone(frequency: 587.33, start: 0.11, duration: 0.28, amplitude: 0.46),
                SynthCueTone(frequency: 880.00, start: 0.24, duration: 0.31, amplitude: 0.52, pan: 0.30)
            ]
        case .rapidSubmit:
            return [
                SynthCueTone(frequency: 587.33, start: 0.00, duration: 0.13, amplitude: 0.46, release: 0.08, pan: -0.26),
                SynthCueTone(frequency: 659.25, start: 0.11, duration: 0.13, amplitude: 0.50, release: 0.08),
                SynthCueTone(frequency: 783.99, start: 0.22, duration: 0.14, amplitude: 0.54, release: 0.09, pan: 0.26)
            ]
        }
    }

    static func makeBuffer(for event: NotificationEvent) -> AVAudioPCMBuffer? {
        makeBuffer(tones: tones(for: event), duration: duration(for: event), targetPeak: 0.68)
    }

    static func makeOnboardingCeremonyBuffer() -> AVAudioPCMBuffer? {
        let tones = [
            // Phase 1: a wide, slow ambient bed establishes the space.
            SynthCueTone(frequency: 130.81, start: 0.00, duration: 3.30, amplitude: 0.16, attack: 0.42, release: 1.05, harmonicMix: 0.08, pan: -0.44),
            SynthCueTone(frequency: 196.00, start: 0.12, duration: 3.18, amplitude: 0.14, attack: 0.52, release: 1.00, harmonicMix: 0.06, pan: 0.42),
            SynthCueTone(frequency: 261.63, start: 0.58, duration: 2.60, amplitude: 0.18, attack: 0.24, release: 0.82, harmonicMix: 0.12, pan: 0),

            // Phase 2: an ascending motif follows the visual brand reveal.
            SynthCueTone(frequency: 392.00, start: 1.22, duration: 0.82, amplitude: 0.26, attack: 0.025, release: 0.38, harmonicMix: 0.17, pan: -0.36),
            SynthCueTone(frequency: 523.25, start: 1.72, duration: 0.92, amplitude: 0.28, attack: 0.025, release: 0.42, harmonicMix: 0.16, pan: 0.32),
            SynthCueTone(frequency: 659.25, start: 2.22, duration: 1.06, amplitude: 0.30, attack: 0.022, release: 0.50, harmonicMix: 0.14, pan: -0.20),
            SynthCueTone(frequency: 783.99, start: 2.76, duration: 1.18, amplitude: 0.28, attack: 0.020, release: 0.60, harmonicMix: 0.12, pan: 0.24),

            // Phase 3: a restrained resolving bloom lands on AgentIsland.
            SynthCueTone(frequency: 261.63, start: 3.42, duration: 1.92, amplitude: 0.18, attack: 0.10, release: 0.78, harmonicMix: 0.08, pan: -0.32),
            SynthCueTone(frequency: 392.00, start: 3.48, duration: 1.86, amplitude: 0.16, attack: 0.12, release: 0.76, harmonicMix: 0.08, pan: 0.28),
            SynthCueTone(frequency: 523.25, start: 3.56, duration: 1.74, amplitude: 0.19, attack: 0.10, release: 0.72, harmonicMix: 0.10, pan: 0),
            SynthCueTone(frequency: 1046.50, start: 4.16, duration: 0.84, amplitude: 0.18, attack: 0.018, release: 0.52, harmonicMix: 0.05, pan: 0.40),
            SynthCueTone(frequency: 1318.51, start: 4.56, duration: 0.72, amplitude: 0.14, attack: 0.016, release: 0.48, harmonicMix: 0.04, pan: -0.38),
            SynthCueTone(frequency: 1567.98, start: 5.18, duration: 0.64, amplitude: 0.11, attack: 0.014, release: 0.50, harmonicMix: 0.03, pan: 0.18)
        ]
        return makeBuffer(
            tones: tones,
            duration: onboardingCeremonyDuration,
            targetPeak: 0.54
        )
    }

    static func makeOnboardingStageBuffer(for stage: Int) -> AVAudioPCMBuffer? {
        guard stage >= 1, stage <= onboardingStageCueCount else { return nil }
        let roots = [392.00, 440.00, 493.88, 523.25, 587.33]
        let root = roots[stage - 1]
        let direction = stage.isMultiple(of: 2) ? -0.32 : 0.32
        let tones = [
            SynthCueTone(frequency: root, start: 0.00, duration: 0.24, amplitude: 0.34, attack: 0.010, release: 0.15, harmonicMix: 0.12, pan: -direction),
            SynthCueTone(frequency: root * 1.25, start: 0.075, duration: 0.25, amplitude: 0.30, attack: 0.010, release: 0.16, harmonicMix: 0.10, pan: direction),
            SynthCueTone(frequency: root * 1.50, start: 0.145, duration: 0.22, amplitude: 0.24, attack: 0.008, release: 0.15, harmonicMix: 0.08, pan: 0)
        ]
        return makeBuffer(
            tones: tones,
            duration: onboardingStageCueDuration,
            targetPeak: 0.42
        )
    }

    static func makeWAVData(from buffer: AVAudioPCMBuffer) -> Data? {
        guard let channels = buffer.floatChannelData else { return nil }
        let channelCount = Int(buffer.format.channelCount)
        let frameCount = Int(buffer.frameLength)
        guard channelCount > 0, frameCount > 0 else { return nil }

        var pcmData = Data(capacity: frameCount * channelCount * MemoryLayout<Int16>.size)
        for frame in 0..<frameCount {
            for channel in 0..<channelCount {
                let clamped = min(max(channels[channel][frame], -1), 1)
                var sample = Int16((clamped * Float(Int16.max)).rounded()).littleEndian
                Swift.withUnsafeBytes(of: &sample) { bytes in
                    pcmData.append(contentsOf: bytes)
                }
            }
        }

        let sampleRate = UInt32(buffer.format.sampleRate.rounded())
        let channelsValue = UInt16(channelCount)
        let bitsPerSample: UInt16 = 16
        let blockAlign = channelsValue * (bitsPerSample / 8)
        let byteRate = sampleRate * UInt32(blockAlign)

        var data = Data(capacity: 44 + pcmData.count)
        data.append(contentsOf: "RIFF".utf8)
        appendLittleEndian(UInt32(36 + pcmData.count), to: &data)
        data.append(contentsOf: "WAVE".utf8)
        data.append(contentsOf: "fmt ".utf8)
        appendLittleEndian(UInt32(16), to: &data)
        appendLittleEndian(UInt16(1), to: &data)
        appendLittleEndian(channelsValue, to: &data)
        appendLittleEndian(sampleRate, to: &data)
        appendLittleEndian(byteRate, to: &data)
        appendLittleEndian(blockAlign, to: &data)
        appendLittleEndian(bitsPerSample, to: &data)
        data.append(contentsOf: "data".utf8)
        appendLittleEndian(UInt32(pcmData.count), to: &data)
        data.append(pcmData)
        return data
    }

    private static func appendLittleEndian<T: FixedWidthInteger>(_ value: T, to data: inout Data) {
        var littleEndianValue = value.littleEndian
        Swift.withUnsafeBytes(of: &littleEndianValue) { bytes in
            data.append(contentsOf: bytes)
        }
    }

    private static func makeBuffer(
        tones: [SynthCueTone],
        duration: TimeInterval,
        targetPeak: Float
    ) -> AVAudioPCMBuffer? {
        guard let format = AVAudioFormat(
            standardFormatWithSampleRate: sampleRate,
            channels: channelCount
        ) else {
            return nil
        }

        let frameCount = AVAudioFrameCount(ceil(duration * sampleRate))
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let channels = buffer.floatChannelData else {
            return nil
        }
        buffer.frameLength = frameCount

        var peak: Float = 0

        for frame in 0..<Int(frameCount) {
            let time = Double(frame) / sampleRate
            for channel in 0..<Int(channelCount) {
                var sample = 0.0

                for tone in tones {
                    let localTime = time - tone.start
                    guard localTime >= 0, localTime < tone.duration else { continue }

                    let attackDuration = min(tone.attack, tone.duration * 0.45)
                    let releaseDuration = min(tone.release, tone.duration * 0.72)
                    let attack = min(1, localTime / max(attackDuration, 0.001))
                    let release = min(1, (tone.duration - localTime) / max(releaseDuration, 0.001))
                    let envelope = pow(max(0, min(attack, release)), 1.45)
                    let phase = 2 * Double.pi * tone.frequency * localTime
                    let fundamentalMix = max(0, 1 - tone.harmonicMix)
                    let timbre = (sin(phase) * fundamentalMix) + (sin(phase * 2) * tone.harmonicMix)
                    let normalizedPan = max(-1, min(1, tone.pan))
                    let panGain = channel == 0
                        ? sqrt((1 - normalizedPan) / 2) * sqrt(2)
                        : sqrt((1 + normalizedPan) / 2) * sqrt(2)
                    sample += timbre * tone.amplitude * envelope * panGain
                }

                let floatSample = Float(sample)
                peak = max(peak, abs(floatSample))
                channels[channel][frame] = floatSample
            }
        }

        // Normalize each semantic cue to the same conservative peak so changing
        // events does not produce sudden loudness jumps or clipping.
        if peak > 0 {
            let scale = min(1.8, targetPeak / peak)
            for channel in 0..<Int(channelCount) {
                for frame in 0..<Int(frameCount) {
                    channels[channel][frame] *= scale
                }
            }
        }

        return buffer
    }
}

@MainActor
final class AppSoundSynthesizer {
    static let shared = AppSoundSynthesizer()

    private var eventPlayers: [NotificationEvent: AVAudioPlayer] = [:]
    private var onboardingCeremonyPlayer: AVAudioPlayer?
    private var onboardingStagePlayers: [Int: AVAudioPlayer] = [:]
    private weak var activePlayer: AVAudioPlayer?

    private init() {
        eventPlayers = Dictionary(uniqueKeysWithValues: NotificationEvent.allCases.compactMap { event in
            guard let buffer = AppSoundCueRenderer.makeBuffer(for: event),
                  let data = AppSoundCueRenderer.makeWAVData(from: buffer),
                  let player = try? AVAudioPlayer(data: data) else {
                return nil
            }
            return (event, player)
        })

        if let buffer = AppSoundCueRenderer.makeOnboardingCeremonyBuffer(),
           let data = AppSoundCueRenderer.makeWAVData(from: buffer) {
            onboardingCeremonyPlayer = try? AVAudioPlayer(data: data)
        }

        onboardingStagePlayers = Dictionary(uniqueKeysWithValues: (1...AppSoundCueRenderer.onboardingStageCueCount).compactMap { stage in
            guard let buffer = AppSoundCueRenderer.makeOnboardingStageBuffer(for: stage),
                  let data = AppSoundCueRenderer.makeWAVData(from: buffer),
                  let player = try? AVAudioPlayer(data: data) else {
                return nil
            }
            return (stage, player)
        })
    }

    func prepare() {
        eventPlayers.values.forEach { $0.prepareToPlay() }
        onboardingCeremonyPlayer?.prepareToPlay()
        onboardingStagePlayers.values.forEach { $0.prepareToPlay() }
    }

    @discardableResult
    func play(event: NotificationEvent, volume: Float) -> Bool {
        play(eventPlayers[event], volume: volume)
    }

    @discardableResult
    func playOnboardingCeremony(volume: Float) -> Bool {
        play(onboardingCeremonyPlayer, volume: volume)
    }

    @discardableResult
    func playOnboardingStage(_ stage: Int, volume: Float) -> Bool {
        play(onboardingStagePlayers[stage], volume: volume * 0.82)
    }

    func stopOnboardingCeremony() {
        activePlayer?.stop()
        activePlayer = nil
    }

    private func play(_ player: AVAudioPlayer?, volume: Float) -> Bool {
        guard let player else { return false }
        if activePlayer !== player {
            activePlayer?.stop()
        }
        if player.isPlaying {
            player.stop()
        }
        player.currentTime = 0
        player.volume = min(max(volume, 0), 1)
        player.prepareToPlay()
        let didPlay = player.play()
        activePlayer = didPlay ? player : nil
        return didPlay
    }
}
