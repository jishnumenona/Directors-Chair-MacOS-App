// DirectorsChairCore/Sources/DirectorsChairCore/EventBus/EventBus.swift
//
// Thread-safe event bus for application-wide event broadcasting

import Foundation

/// Thread-safe actor for publishing and subscribing to application events
public actor EventBus {

    // MARK: - Singleton

    /// Shared instance for application-wide event bus
    public static let shared = EventBus()

    // MARK: - Subscription Storage

    private var subscriptions: [UUID: EventSubscription] = [:]
    private var eventHistory: [TimestampedEvent] = []
    private let maxHistorySize: Int

    // MARK: - Configuration

    private let enableHistory: Bool
    private let enableLogging: Bool

    // MARK: - Initialization

    public init(
        maxHistorySize: Int = 100,
        enableHistory: Bool = true,
        enableLogging: Bool = false
    ) {
        self.maxHistorySize = maxHistorySize
        self.enableHistory = enableHistory
        self.enableLogging = enableLogging
    }

    // MARK: - Publishing

    /// Publish an event to all subscribed handlers
    /// - Parameter event: The event to publish
    public func publish(_ event: AppEvent) {
        if enableLogging {
            debugLog("📢 EventBus: Publishing \(event.category.rawValue) event")
        }

        // Add to history
        if enableHistory {
            addToHistory(event)
        }

        // Get matching subscriptions sorted by priority
        let matchingSubscriptions = subscriptions.values
            .filter { $0.matches(event) }
            .sorted { $0.priority > $1.priority }

        // Call handlers
        for subscription in matchingSubscriptions {
            Task {
                await subscription.handler(event)
            }
        }
    }

    /// Publish multiple events in sequence
    /// - Parameter events: Array of events to publish
    public func publishBatch(_ events: [AppEvent]) {
        for event in events {
            publish(event)
        }
    }

    // MARK: - Subscription

    /// Subscribe to events with optional filtering
    /// - Parameters:
    ///   - categories: Optional categories to filter (nil = all categories)
    ///   - priority: Priority for handler ordering (higher priority = called first)
    ///   - handler: Async handler to call when matching events occur
    /// - Returns: Subscription token for unsubscribing
    @discardableResult
    public func subscribe(
        categories: Set<EventCategory>? = nil,
        priority: EventPriority = .normal,
        handler: @escaping @Sendable (AppEvent) async -> Void
    ) -> EventSubscriptionToken {
        let id = UUID()
        let subscription = EventSubscription(
            id: id,
            categories: categories,
            priority: priority,
            handler: handler
        )

        subscriptions[id] = subscription

        if enableLogging {
            debugLog("📝 EventBus: New subscription \(id) for categories: \(categories?.map { $0.rawValue } ?? ["all"])")
        }

        return EventSubscriptionToken(id: id, eventBus: self)
    }

    /// Subscribe to specific event categories
    /// - Parameters:
    ///   - category: The category to subscribe to
    ///   - priority: Priority for handler ordering
    ///   - handler: Handler to call when matching events occur
    /// - Returns: Subscription token for unsubscribing
    @discardableResult
    public func subscribe(
        to category: EventCategory,
        priority: EventPriority = .normal,
        handler: @escaping @Sendable (AppEvent) async -> Void
    ) -> EventSubscriptionToken {
        subscribe(categories: [category], priority: priority, handler: handler)
    }

    /// Unsubscribe from events
    /// - Parameter token: The subscription token from subscribe()
    public func unsubscribe(_ token: EventSubscriptionToken) {
        subscriptions.removeValue(forKey: token.id)

        if enableLogging {
            debugLog("❌ EventBus: Unsubscribed \(token.id)")
        }
    }

    /// Unsubscribe all handlers
    public func unsubscribeAll() {
        subscriptions.removeAll()

        if enableLogging {
            debugLog("🗑️ EventBus: All subscriptions cleared")
        }
    }

    // MARK: - History

    /// Get event history
    /// - Parameters:
    ///   - limit: Maximum number of events to return
    ///   - category: Optional category filter
    /// - Returns: Array of timestamped events
    public func getHistory(limit: Int? = nil, category: EventCategory? = nil) -> [TimestampedEvent] {
        var filtered = eventHistory

        if let category = category {
            filtered = filtered.filter { $0.event.category == category }
        }

        if let limit = limit {
            return Array(filtered.suffix(limit))
        }

        return filtered
    }

    /// Clear event history
    public func clearHistory() {
        eventHistory.removeAll()
    }

    // MARK: - Statistics

    /// Get subscription count
    public var subscriptionCount: Int {
        subscriptions.count
    }

    /// Get history count
    public var historyCount: Int {
        eventHistory.count
    }

    /// Get subscriptions by category
    public func subscriptionCount(for category: EventCategory) -> Int {
        subscriptions.values.filter { subscription in
            subscription.categories?.contains(category) ?? true
        }.count
    }

    // MARK: - Private Helpers

    private func addToHistory(_ event: AppEvent) {
        let timestamped = TimestampedEvent(event: event, timestamp: Date())
        eventHistory.append(timestamped)

        // Trim history if needed
        if eventHistory.count > maxHistorySize {
            eventHistory.removeFirst(eventHistory.count - maxHistorySize)
        }
    }
}

// MARK: - EventSubscription

/// Internal subscription storage
private struct EventSubscription {
    let id: UUID
    let categories: Set<EventCategory>?
    let priority: EventPriority
    let handler: @Sendable (AppEvent) async -> Void

    func matches(_ event: AppEvent) -> Bool {
        guard let categories = categories else {
            return true // No filter = match all
        }
        return categories.contains(event.category)
    }
}

// MARK: - EventSubscriptionToken

/// Token for managing event subscriptions
public struct EventSubscriptionToken: Sendable {
    fileprivate let id: UUID
    fileprivate weak var eventBus: EventBus?

    /// Unsubscribe from events
    public func cancel() async {
        await eventBus?.unsubscribe(self)
    }
}

// MARK: - TimestampedEvent

/// Event with timestamp for history tracking
public struct TimestampedEvent: Sendable {
    public let event: AppEvent
    public let timestamp: Date

    public var age: TimeInterval {
        Date().timeIntervalSince(timestamp)
    }
}
