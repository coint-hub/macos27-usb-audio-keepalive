// AudioKeepalive — keep the default output device's IO running by rendering silence.
//
// On macOS 27, usbaudiod starts and stops USB audio IO for every sound. A short
// sound such as a system alert finishes before the stream locks, so only a
// "tick" is heard. Rendering continuous silence through the default output
// keeps IO open so short sounds play in full.
//
// While IO is running, coreaudiod holds a "prevent idle sleep" assertion. To
// let the Mac idle-sleep normally, IO is released while the display is asleep
// and resumed when it wakes, so the assertion is only held while the screen is
// on. Display state is polled with CGDisplayIsAsleep because NSWorkspace's
// screensDidSleep/Wake notifications are not delivered to a command-line tool.

import AVFoundation
import CoreGraphics
import Foundation

@main
struct AudioKeepalive {
    @MainActor
    static func main() {
        let keepalive = Keepalive()
        keepalive.start()
        RunLoop.main.run()
    }
}

@MainActor
final class Keepalive {
    private let engine = AVAudioEngine()
    private var displayAsleep = false

    init() {
        let silence = AVAudioSourceNode { @Sendable _, _, _, audioBufferList -> OSStatus in
            for buffer in UnsafeMutableAudioBufferListPointer(audioBufferList) {
                memset(buffer.mData, 0, Int(buffer.mDataByteSize))
            }
            return noErr
        }
        engine.attach(silence)
        engine.connect(silence, to: engine.outputNode, format: nil)

        // On macOS, a default-output change stops the engine and posts this
        // notification. Restarting rebinds the engine to the new default device.
        NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: engine, queue: .main
        ) { [unowned self] _ in
            MainActor.assumeIsolated { start() }
        }

        Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [unowned self] _ in
            MainActor.assumeIsolated { pollDisplay() }
        }
    }

    func start() {
        guard !displayAsleep else { return }
        do {
            try engine.start()
            log("keeping IO running on default output")
        } catch {
            log("engine start failed: \(error)")
        }
    }

    private func pollDisplay() {
        let asleep = CGDisplayIsAsleep(CGMainDisplayID()) != 0
        guard asleep != displayAsleep else { return }
        displayAsleep = asleep
        if asleep {
            engine.stop()
            log("display asleep, released IO")
        } else {
            log("display awake")
            start()
        }
    }
}

private func log(_ message: String) {
    FileHandle.standardError.write(Data((message + "\n").utf8))
}
