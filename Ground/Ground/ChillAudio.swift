import AVFoundation
import Combine

// Holds all real-time synthesis state — captured by the audio thread closure directly,
// avoiding the Swift init-phase restriction on capturing `self` before all properties are set.
private let kSampleRate = 22050.0   // 528 Hz max tone needs < 11 kHz Nyquist

private final class SynthState {
    var targetFreq:     Double = 285
    var targetTriGain:  Double = 0
    var currentFreq:    Double = 285
    var currentTriGain: Double = 0
    var tonePhase:      Double = 0
    var triPhase:       Double = 0
    let freqSmooth = 1.0 - exp(-1.0 / (kSampleRate * 0.08))
    let gainSmooth = 1.0 - exp(-1.0 / (kSampleRate * 0.12))

    // Vibrato (active while dragging)
    var vibratoDepth:        Double = 0
    var currentVibratoDepth: Double = 0
    var vibratoPhase:        Double = 0
    let vibratoRate:         Double = 4.5
    let vibratoSmooth = 1.0 - exp(-1.0 / (kSampleRate * 0.35))
}

final class ChillAudio: ObservableObject {

    private let engine:     AVAudioEngine
    private let toneNode:   AVAudioSourceNode
    private let reverb:     AVAudioUnitReverb
    private let dropPlayer: AVAudioPlayerNode
    private let synth:      SynthState

    // Volume — main thread only
    private var breathTimer: Timer?
    private var breathPhase: Double = 0
    private var fadeVol:     Float  = 0
    private var keyDecay:    Float  = 0

    private let baseVol:   Float = 0.35
    private let breathAmp: Float = 0.08
    private let keyBoost:  Float = 0.12

    init() {
        let format = AVAudioFormat(standardFormatWithSampleRate: kSampleRate, channels: 2)!

        // Create synth state first so the closure can capture it without touching `self`
        let s = SynthState()

        toneNode = AVAudioSourceNode(format: format) { [s] _, _, frameCount, audioBufferList in
            let abl = UnsafeMutableAudioBufferListPointer(audioBufferList)
            for frame in 0..<Int(frameCount) {
                s.currentFreq    += (s.targetFreq    - s.currentFreq)    * s.freqSmooth
                s.currentTriGain += (s.targetTriGain - s.currentTriGain) * s.gainSmooth

                // Vibrato LFO — smoothly fades in/out when dragging starts/stops
                s.currentVibratoDepth += (s.vibratoDepth - s.currentVibratoDepth) * s.vibratoSmooth
                s.vibratoPhase        += 2 * .pi * s.vibratoRate / kSampleRate
                if s.vibratoPhase > 2 * .pi { s.vibratoPhase -= 2 * .pi }
                let vibratoMod = sin(s.vibratoPhase) * s.currentVibratoDepth

                // Sine oscillator
                s.tonePhase += 2 * .pi * max(1, s.currentFreq + vibratoMod) / kSampleRate
                if s.tonePhase > 2 * .pi { s.tonePhase -= 2 * .pi }
                let sine = sin(s.tonePhase)

                // Triangle one octave below — fast formula, no arcsin
                s.triPhase += 2 * .pi * max(1, (s.currentFreq + vibratoMod) / 2) / kSampleRate
                if s.triPhase > 2 * .pi { s.triPhase -= 2 * .pi }
                let tn = s.triPhase / (2 * .pi)          // normalised 0→1
                let tri = tn < 0.5 ? 4 * tn - 1 : 3 - 4 * tn   // -1→1→-1

                let sample = Float((sine * 0.6 + tri * s.currentTriGain) * 0.55)
                for buf in abl { UnsafeMutableBufferPointer<Float>(buf)[frame] = sample }
            }
            return noErr
        }

        reverb = AVAudioUnitReverb()
        reverb.loadFactoryPreset(.mediumHall)
        reverb.wetDryMix = 50

        dropPlayer = AVAudioPlayerNode()
        engine     = AVAudioEngine()
        synth      = s

        engine.attach(toneNode)
        engine.attach(reverb)
        engine.attach(dropPlayer)
        engine.connect(toneNode,   to: reverb,               format: format)
        engine.connect(reverb,     to: engine.mainMixerNode, format: format)
        engine.connect(dropPlayer, to: engine.mainMixerNode, format: format)
        engine.mainMixerNode.outputVolume = 0
    }

    deinit {
        breathTimer?.invalidate()
        engine.stop()
    }

    // MARK: - Lifecycle

    func start() {
        guard !engine.isRunning else { return }
        do { try engine.start() } catch { print("ChillAudio: \(error)"); return }
        fadeVol     = 0
        breathPhase = 0
        breathTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 10, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    func stop() {
        breathTimer?.invalidate()
        breathTimer = nil
        engine.mainMixerNode.outputVolume = 0
        engine.stop()
    }

    // MARK: - Volume tick (30 fps, main thread)

    private func tick() {
        fadeVol = min(1, fadeVol + 0.0067)  // ~5s fade in

        breathPhase += (1.0 / 10.0) * (2 * .pi / 8.0)
        let breathFac = Float((1 - cos(breathPhase)) / 2)

        keyDecay = max(0, keyDecay - 0.035)

        let vol = (baseVol + breathAmp * breathFac + keyBoost * keyDecay) * fadeVol
        engine.mainMixerNode.outputVolume = min(0.85, vol)
    }

    // MARK: - Public API

    func updateMousePosition(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) {
        guard width > 0, height > 0 else { return }

        // X → solfeggio frequency, piecewise linear through three anchors:
        //   left  → 174 Hz (grounding)   center → 432 Hz (natural)   right → 528 Hz (open)
        let tx = Double(max(0, min(1, x / width)))
        synth.targetFreq = tx <= 0.5
            ? 174.0 + tx * 2.0 * (432.0 - 174.0)
            : 432.0 + (tx - 0.5) * 2.0 * (528.0 - 432.0)

        // Y → triangle overtone blend (top=pure sine, bottom=sine+triangle)
        let ty = Double(max(0, min(1, y / height)))  // 0=top, 1=bottom
        synth.targetTriGain = ty * 0.4
    }

    func onKeyPress() { keyDecay = 1.0 }

    func onTap() {
        keyDecay = min(1, keyDecay + 0.45)
        playDroplet()
    }

    func setDragging(_ active: Bool) {
        synth.vibratoDepth = active ? 14.0 : 0.0
    }

    // MARK: - Synthesized water droplet

    private func playDroplet() {
        let sr       = kSampleRate
        let duration = 0.35
        let frames   = Int(sr * duration)
        let baseFreq = 750.0
        let format   = AVAudioFormat(standardFormatWithSampleRate: sr, channels: 2)!

        guard let buf = AVAudioPCMBuffer(pcmFormat: format,
                                         frameCapacity: AVAudioFrameCount(frames)) else { return }
        buf.frameLength = AVAudioFrameCount(frames)

        for ch in 0..<2 {
            let data  = buf.floatChannelData![ch]
            var phase = 0.0
            for i in 0..<frames {
                let t = Double(i) / sr

                // Upward pitch bend — what makes it sound like water, not a bell
                let pitchBend = 1.0 + 0.5 * (1.0 - exp(-t / 0.025))
                phase        += 2 * .pi * (baseFreq * pitchBend) / sr
                let tone      = sin(phase)

                let attack    = min(1.0, t / 0.005)    // 5ms ramp avoids click
                let decay     = exp(-t / 0.18)          // 180ms decay
                let impact: Float = t < 0.015
                    ? Float.random(in: -1...1) * Float(exp(-t / 0.003)) * 0.3
                    : 0

                data[i] = Float(tone * attack * decay) * 0.4 + impact * 0.4
            }
        }

        dropPlayer.stop()
        dropPlayer.scheduleBuffer(buf)
        if !dropPlayer.isPlaying { dropPlayer.play() }
    }
}
