// DirectorsChairViews/Sources/DirectorsChairViews/Bubble/BubbleCardSizing.swift
//
// Bubble cards hug their text (owner 2026-08-29). A card is only as wide as
// its content plus padding — in display AND edit mode — up to a share of the
// row it sits in, after which the text wraps. Before this, a card in edit
// mode stretched to the full row (a text field takes whatever width it is
// offered) and a dialogue bubble always filled its 500 pt cap (the Spacers
// in its header and tags rows are greedy).

import SwiftUI

/// Sizing rules shared by every bubble card.
public enum BubbleCardSizing {
    /// A bubble never grows past this share of the row it sits in.
    public static let maxRowFraction: CGFloat = 0.7

    /// Cap used when the row width is unknown (previews, snapshots, standalone use).
    public static let fallbackMaxWidth: CGFloat = 560

    /// An empty edit field stays at least this wide so it is still usable.
    public static let editFieldMinWidth: CGFloat = 160

    /// The widest a bubble may be in a row of the given width.
    public static func maxWidth(forRowWidth rowWidth: CGFloat) -> CGFloat {
        guard rowWidth.isFinite, rowWidth > 0 else { return fallbackMaxWidth }
        return (rowWidth * maxRowFraction).rounded(.down)
    }
}

// MARK: - Row width (environment)

private struct BubbleRowWidthKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

extension EnvironmentValues {
    /// Width of the row the bubble cards are laid out in (0 = unknown, cards use the fallback cap).
    public var bubbleRowWidth: CGFloat {
        get { self[BubbleRowWidthKey.self] }
        set { self[BubbleRowWidthKey.self] = newValue }
    }
}

// MARK: - Hugging layout

/// Sizes its single child to the child's ideal width, capped.
///
/// The child is proposed at most `maxWidth` (and never more than the parent
/// offered) and the layout takes the size the child then reports — so a
/// `Text` hugs when it fits and wraps when it doesn't. `frame(maxWidth:)`
/// can't do this: it *expands* to the cap whenever the parent offers more,
/// which is exactly what made the bubbles wider than their text.
struct HugWidthLayout: Layout {
    var maxWidth: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard let child = subviews.first else { return .zero }
        return child.sizeThatFits(childProposal(for: proposal, child: child))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard let child = subviews.first else { return }
        child.place(at: bounds.origin, anchor: .topLeading, proposal: ProposedViewSize(bounds.size))
    }

    private func childProposal(for proposal: ProposedViewSize, child: LayoutSubview) -> ProposedViewSize {
        let ideal = child.sizeThatFits(.unspecified).width
        var width = min(ideal, maxWidth)
        if let offered = proposal.width { width = min(width, offered) }
        return ProposedViewSize(width: width, height: proposal.height)
    }
}

extension View {
    /// Hug the content's width; text wraps once `maxWidth` is reached.
    func hugWidth(max maxWidth: CGFloat) -> some View {
        HugWidthLayout(maxWidth: maxWidth) { self }
    }
}
