// DirectorsChairServices/Storyboard/LocalModelIdleRelease.swift
//
// One release-on-idle rule for every resident local model. DC-0070 gave
// it to the image core (KleinCore); DC-0079 shares it with the text model
// (MLXInsightEngine) — with both models resident the app sat at ~8 GB
// between jobs. A job marks its beginning and its end; the weights are
// dropped only when the idle interval passes with no newer job begun.
// Arch-neutral so the engines' Intel builds compile; the interval itself
// lives in MLXMemoryPolicy on Apple Silicon.

import Foundation

public final class LocalModelIdleRelease: @unchecked Sendable {
    /// Identifies the job generation a release was armed for.
    public typealias Token = Int

    private let lock = NSLock()
    private var generation = 0
    private let interval: @Sendable () -> TimeInterval
    private let release: @Sendable (Token) async -> Void

    /// The shipped interval: MLXMemoryPolicy's on Apple Silicon.
    public static var defaultInterval: TimeInterval {
        #if arch(arm64)
        return MLXMemoryPolicy.idleReleaseInterval
        #else
        return 300
        #endif
    }

    /// `release` runs after the interval with the token of the job that
    /// armed it. The engine re-checks `isCurrent` on its own executor
    /// before dropping anything, so a job that began meanwhile is safe.
    public init(interval: @escaping @Sendable () -> TimeInterval = { LocalModelIdleRelease.defaultInterval },
                release: @escaping @Sendable (Token) async -> Void) {
        self.interval = interval
        self.release = release
    }

    /// A job starts: whatever release was armed is now stale.
    public func begin() {
        lock.lock(); generation += 1; lock.unlock()
    }

    /// A job ended: arm the release for the current generation.
    public func end() {
        let token = current
        let seconds = interval()
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(max(0, seconds) * 1_000_000_000))
            guard let self, self.isCurrent(token) else { return }
            await self.release(token)
        }
    }

    /// The generation of the latest job to begin.
    public var current: Token {
        lock.lock(); defer { lock.unlock() }
        return generation
    }

    /// Whether no job has begun since `token` was issued.
    public func isCurrent(_ token: Token) -> Bool { current == token }
}
