// DirectorsChairServices/Storyboard/MLXMemoryPolicy.swift
//
// One place that decides how much memory MLX may hold on to (DC-0070).
// MLX's allocator keeps every freed buffer in a cache for reuse and, left
// unbounded, a process sits at its historical peak forever: measured on
// the owner's Mac, one 1024² edit left 22 GB of cache behind (footprint
// 26.6 GB) with under 4 GB of live weights. The policy: a small cache
// while working, nothing kept between jobs, weights dropped after idling.

#if arch(arm64)
import Foundation
import MLX

public enum MLXMemoryPolicy {
    /// Freed buffers MLX may keep between operations — enough to reuse
    /// the per-step working set, far below a whole picture's history.
    public static let cacheLimitBytes = 1 << 30            // 1 GiB

    /// Resident weights are dropped after this long without a render;
    /// the next render reloads from the OS file cache (~1 s).
    nonisolated(unsafe) public static var idleReleaseInterval: TimeInterval = 300

    private static let applied: Void = {
        GPU.set(cacheLimit: cacheLimitBytes)
    }()

    /// Idempotent; call before any MLX work.
    public static func apply() { _ = applied }

    /// Return every cached buffer to the system now.
    public static func releaseCache() { GPU.clearCache() }
}
#endif
