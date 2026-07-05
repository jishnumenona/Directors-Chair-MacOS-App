// SnapshotTestHelpers.swift
// NSHostingView wrapper for snapshot testing SwiftUI views on macOS

import XCTest
import SwiftUI
import AppKit
import SnapshotTesting

extension XCTestCase {

    /// Asserts a snapshot of the given SwiftUI view rendered in an NSHostingView.
    /// - Parameters:
    ///   - view: The SwiftUI view to snapshot.
    ///   - name: Optional snapshot name (defaults to function name).
    ///   - size: Frame size for the hosting view (default 400x300).
    ///   - record: Set to true to record/update reference images.
    ///   - file: Source file (auto-filled).
    ///   - testName: Test function name (auto-filled).
    ///   - line: Source line (auto-filled).
    func assertViewSnapshot<V: View>(
        _ view: V,
        named name: String? = nil,
        size: CGSize = CGSize(width: 400, height: 300),
        record: Bool = false,
        file: StaticString = #file,
        testName: String = #function,
        line: UInt = #line
    ) {
        let wrapped = view
            .preferredColorScheme(.dark)
            .frame(width: size.width, height: size.height)
            .transaction { $0.animation = nil }

        let hostingView = NSHostingView(rootView: wrapped)
        hostingView.frame = CGRect(origin: .zero, size: size)

        // Force layout
        hostingView.layoutSubtreeIfNeeded()

        // Allow batch re-recording via the environment (e.g. RECORD_SNAPSHOTS=1 swift test)
        // so reference images can be regenerated on the CI runner image without editing call sites.
        let shouldRecord = record || ProcessInfo.processInfo.environment["RECORD_SNAPSHOTS"] == "1"

        assertSnapshot(
            of: hostingView,
            as: .image,
            named: name,
            record: shouldRecord,
            file: file,
            testName: testName,
            line: line
        )
    }

    /// Asserts a snapshot with a compact size suitable for small components (e.g. pills, avatars).
    func assertCompactSnapshot<V: View>(
        _ view: V,
        named name: String? = nil,
        size: CGSize = CGSize(width: 200, height: 60),
        record: Bool = false,
        file: StaticString = #file,
        testName: String = #function,
        line: UInt = #line
    ) {
        assertViewSnapshot(
            view,
            named: name,
            size: size,
            record: record,
            file: file,
            testName: testName,
            line: line
        )
    }
}
