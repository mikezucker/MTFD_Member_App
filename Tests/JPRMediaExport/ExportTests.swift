import Foundation
import AVFoundation

@main struct MediaExportTests {
    @MainActor static func main() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let input = folder.appendingPathComponent("source.wav")
        // One second of silent PCM, generated locally; no member media involved.
        let samples = 44100
        let size = UInt32(samples * 2)
        var wav = Data("RIFF".utf8)
        func append<T: FixedWidthInteger>(_ value: T) { var little = value.littleEndian; withUnsafeBytes(of: &little) { wav.append(contentsOf: $0) } }
        append(size + 36); wav.append(Data("WAVEfmt ".utf8)); append(UInt32(16)); append(UInt16(1)); append(UInt16(1)); append(UInt32(44100)); append(UInt32(88200)); append(UInt16(2)); append(UInt16(16)); wav.append(Data("data".utf8)); append(size); wav.append(Data(count: Int(size)))
        try wav.write(to: input)
        func makeSession(_ output: URL) -> AVAssetExportSession {
            let session = AVAssetExportSession(asset: AVURLAsset(url: input), presetName: AVAssetExportPresetAppleM4A)!
            session.outputURL = output
            session.outputFileType = .m4a
            return session
        }
        let output = folder.appendingPathComponent("output.m4a")
        let success = makeSession(output)
        try await JPRVideoExport(session: success).run()
        precondition(success.status == .completed && FileManager.default.fileExists(atPath: output.path))
        print("PASS: native export completes and produces output")

        let failed = makeSession(folder.appendingPathComponent("missing/output.m4a"))
        do { try await JPRVideoExport(session: failed).run(); preconditionFailure("Export failure must propagate") }
        catch { precondition(failed.status == .failed); print("PASS: native export failure reaches the caller") }

        let cancelled = makeSession(folder.appendingPathComponent("cancelled.m4a"))
        let task = Task { @MainActor in try await JPRVideoExport(session: cancelled).run() }
        task.cancel()
        do { try await task.value; preconditionFailure("Cancelled task must not succeed") }
        catch is CancellationError { precondition(cancelled.status == .unknown); print("PASS: cancellation before start does not start export") }

        let active = makeSession(folder.appendingPathComponent("active.m4a"))
        let activeTask = Task { @MainActor in try await JPRVideoExport(session: active).run() }
        while active.status == .unknown { await Task.yield() }
        activeTask.cancel()
        do { try await activeTask.value; preconditionFailure("Cancellation must reach the caller") }
        catch { precondition(active.status == .cancelled || active.status == .completed); print("PASS: cancellation after export starts terminates without hanging") }
    }
}
