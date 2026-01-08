// DirectorsChairCore/Sources/DirectorsChairCore/EventBus/EventPublisher.swift
//
// SwiftUI-compatible event publisher for observing events in views

import Foundation
import Combine

/// SwiftUI-compatible publisher for observing events
/// Use in @StateObject or @ObservedObject to react to events in SwiftUI views
@MainActor
public class EventPublisher: ObservableObject {

    // MARK: - Published Properties

    /// Most recent event received
    @Published public private(set) var latestEvent: AppEvent?

    /// Event history for this publisher
    @Published public private(set) var events: [TimestampedEvent] = []

    /// Whether this publisher is actively listening
    @Published public private(set) var isActive: Bool = false

    // MARK: - Configuration

    private let categories: Set<EventCategory>?
    private let maxEventHistory: Int
    private let eventBus: EventBus

    // MARK: - State

    private var subscriptionToken: EventSubscriptionToken?

    // MARK: - Initialization

    /// Create an event publisher
    /// - Parameters:
    ///   - categories: Optional categories to filter (nil = all events)
    ///   - maxEventHistory: Maximum events to keep in history
    ///   - eventBus: Event bus to subscribe to (defaults to shared instance)
    public init(
        categories: Set<EventCategory>? = nil,
        maxEventHistory: Int = 50,
        eventBus: EventBus = .shared
    ) {
        self.categories = categories
        self.maxEventHistory = maxEventHistory
        self.eventBus = eventBus
    }

    /// Subscribe to a single category
    /// - Parameters:
    ///   - category: The category to observe
    ///   - maxEventHistory: Maximum events to keep
    ///   - eventBus: Event bus instance
    public convenience init(
        category: EventCategory,
        maxEventHistory: Int = 50,
        eventBus: EventBus = .shared
    ) {
        self.init(
            categories: [category],
            maxEventHistory: maxEventHistory,
            eventBus: eventBus
        )
    }

    // MARK: - Lifecycle

    /// Start listening to events
    public func start() {
        guard !isActive else { return }

        Task {
            subscriptionToken = await eventBus.subscribe(
                categories: categories,
                priority: .normal
            ) { [weak self] event in
                await self?.handleEvent(event)
            }
            isActive = true
        }
    }

    /// Stop listening to events
    public func stop() {
        guard isActive else { return }

        Task {
            if let token = subscriptionToken {
                await token.cancel()
            }
            subscriptionToken = nil
            isActive = false
        }
    }

    // MARK: - Event Handling

    private func handleEvent(_ event: AppEvent) async {
        await MainActor.run {
            latestEvent = event

            // Add to history
            let timestamped = TimestampedEvent(event: event, timestamp: Date())
            events.append(timestamped)

            // Trim history if needed
            if events.count > maxEventHistory {
                events.removeFirst(events.count - maxEventHistory)
            }
        }
    }

    // MARK: - Utility

    /// Clear event history
    public func clearHistory() {
        events.removeAll()
        latestEvent = nil
    }

    /// Get events matching a specific category
    /// - Parameter category: Category to filter
    /// - Returns: Array of matching events
    public func events(in category: EventCategory) -> [TimestampedEvent] {
        events.filter { $0.event.category == category }
    }

    /// Get most recent event in a category
    /// - Parameter category: Category to search
    /// - Returns: Most recent event or nil
    public func latestEvent(in category: EventCategory) -> AppEvent? {
        events.last { $0.event.category == category }?.event
    }

    deinit {
        Task { [subscriptionToken] in
            if let token = subscriptionToken {
                await token.cancel()
            }
        }
    }
}

// MARK: - Convenience Publishers

extension EventPublisher {
    /// Create a publisher for project events only
    public static func projectEvents(eventBus: EventBus = .shared) -> EventPublisher {
        EventPublisher(category: .project, eventBus: eventBus)
    }

    /// Create a publisher for data model events only
    public static func dataModelEvents(eventBus: EventBus = .shared) -> EventPublisher {
        EventPublisher(category: .dataModel, eventBus: eventBus)
    }

    /// Create a publisher for AI service events only
    public static func aiServiceEvents(eventBus: EventBus = .shared) -> EventPublisher {
        EventPublisher(category: .aiService, eventBus: eventBus)
    }

    /// Create a publisher for UI events only
    public static func uiEvents(eventBus: EventBus = .shared) -> EventPublisher {
        EventPublisher(category: .ui, eventBus: eventBus)
    }

    /// Create a publisher for system events only
    public static func systemEvents(eventBus: EventBus = .shared) -> EventPublisher {
        EventPublisher(category: .system, eventBus: eventBus)
    }
}
