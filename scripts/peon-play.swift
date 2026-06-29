/// peon-play — macOS audio player that routes through the System Sound Effects device.
///
/// Drop-in replacement for `afplay -v <volume> <file>`.
/// Build: swiftc -O -o peon-play peon-play.swift -framework AVFoundation -framework CoreAudio -framework AudioToolbox

import AVFoundation
import CoreAudio
import AudioToolbox
import Foundation

// MARK: - Argument parsing (-v <volume> [-p <prerollMs>] <file>)

var volume: Float = 1.0
var prerollMs: Double = 300   // silence pushed before the file to cover device wake-up
var filePath: String?

var args = Array(CommandLine.arguments.dropFirst())
while !args.isEmpty {
    let arg = args.removeFirst()
    if arg == "-v", !args.isEmpty {
        volume = max(0, min(1, Float(args.removeFirst()) ?? 1.0))
    } else if arg == "-p", !args.isEmpty {
        prerollMs = max(0, Double(args.removeFirst()) ?? prerollMs)
    } else if filePath == nil {
        filePath = arg
    }
}

guard let filePath = filePath else {
    fputs("Usage: peon-play [-v volume] [-p prerollMs] <file>\n", stderr)
    exit(1)
}

let url = URL(fileURLWithPath: filePath)
guard FileManager.default.fileExists(atPath: filePath) else {
    fputs("Error: file not found: \(filePath)\n", stderr)
    exit(1)
}

// MARK: - Query the System Sound Effects output device

func systemOutputDeviceID() -> AudioDeviceID? {
    var address = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDefaultSystemOutputDevice,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )
    var deviceID: AudioDeviceID = 0
    var size = UInt32(MemoryLayout<AudioDeviceID>.size)
    let status = AudioObjectGetPropertyData(
        AudioObjectID(kAudioObjectSystemObject),
        &address, 0, nil, &size, &deviceID
    )
    guard status == noErr, deviceID != 0 else { return nil }
    return deviceID
}

// MARK: - Set up AVAudioEngine

let engine = AVAudioEngine()
let playerNode = AVAudioPlayerNode()
engine.attach(playerNode)

// Route to the Sound Effects device if available
if let deviceID = systemOutputDeviceID(),
   let audioUnit = engine.outputNode.audioUnit {
    var devID = deviceID
    let status = AudioUnitSetProperty(
        audioUnit,
        kAudioOutputUnitProperty_CurrentDevice,
        kAudioUnitScope_Global,
        0,
        &devID,
        UInt32(MemoryLayout<AudioDeviceID>.size)
    )
    if status != noErr {
        // Fall back to default output (same behaviour as afplay)
    }
}

// MARK: - Load and play

let audioFile: AVAudioFile
do {
    audioFile = try AVAudioFile(forReading: url)
} catch {
    fputs("Error: cannot open audio file: \(error.localizedDescription)\n", stderr)
    exit(1)
}

let format = audioFile.processingFormat
engine.connect(playerNode, to: engine.mainMixerNode, format: format)
engine.mainMixerNode.outputVolume = volume

do {
    try engine.start()
} catch {
    fputs("Error: cannot start audio engine: \(error.localizedDescription)\n", stderr)
    exit(1)
}

// Pre-roll: schedule a short silent buffer before the file. An idle output
// device (notably Bluetooth A2DP, which suspends within seconds) does not
// stream PCM the instant engine.start() returns — it needs ~100-300ms to wake.
// Without this, the first samples are fed to a sink that isn't live yet and the
// leading syllable is clipped ("appy to" instead of "Happy to"). The silence
// gives the device time to come up so the file starts on a live stream.
let prerollFrames = AVAudioFrameCount((format.sampleRate * prerollMs / 1000.0).rounded())
if prerollFrames > 0,
   let silence = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: prerollFrames) {
    silence.frameLength = prerollFrames   // zeroed on allocation == silence
    playerNode.scheduleBuffer(silence, at: nil, options: [])
}

playerNode.scheduleFile(audioFile, at: nil, completionCallbackType: .dataPlayedBack) { _ in
    // Dispatch exit off the audio thread to avoid deadlock
    DispatchQueue.main.async { exit(0) }
}
playerNode.play()

// MARK: - Signal handling (clean shutdown when kill_previous_sound fires)

let sigterm = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
sigterm.setEventHandler {
    playerNode.stop()
    engine.stop()
    exit(0)
}
sigterm.resume()
signal(SIGTERM, SIG_IGN) // Let DispatchSource handle it

let sigint = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
sigint.setEventHandler {
    playerNode.stop()
    engine.stop()
    exit(0)
}
sigint.resume()
signal(SIGINT, SIG_IGN)

// Keep alive until playback finishes or signal received
dispatchMain()
