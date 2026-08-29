import Foundation

/// Declares a user-initiated activity for the duration of a local-model
/// job so macOS App Nap does not throttle it while the window is hidden or
/// the display is asleep.
///
/// DC-0071 measurement: with the display off, one 8-second location plate
/// took 479 s and a 10-second prop concept took 272 s — sporadic 30× stalls
/// with memory 85% free and no swap pressure; with the display awake none
/// occurred. A render or a text generation is a user-requested job, and
/// App Nap only stands down when the process says so.
public enum LocalModelActivity {
    public static let options: ProcessInfo.ActivityOptions = [.userInitiated, .idleSystemSleepDisabled]

    /// Runs `body` inside a declared activity; the activity ends however
    /// the body exits.
    public static func perform<T>(_ reason: String, _ body: () async throws -> T) async rethrows -> T {
        let token = ProcessInfo.processInfo.beginActivity(options: options, reason: reason)
        defer { ProcessInfo.processInfo.endActivity(token) }
        return try await body()
    }
}
