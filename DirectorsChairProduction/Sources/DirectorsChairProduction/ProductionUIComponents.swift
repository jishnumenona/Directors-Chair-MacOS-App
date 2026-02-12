// DirectorsChairProduction/Sources/DirectorsChairProduction/ProductionUIComponents.swift
//
// Shared styled UI components for Production views.
// Matches the app's design system (AttributeCard, chip selections, icon-driven headers).

import SwiftUI

// MARK: - ProductionCard

/// Rounded card container matching AttributeCard style from StoryDesign
public struct ProductionCard<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: () -> Content

    public init(icon: String, title: String, @ViewBuilder content: @escaping () -> Content) {
        self.icon = icon
        self.title = title
        self.content = content
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundColor(.accentColor)
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                    .tracking(1.2)
            }

            content()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(nsColor: .separatorColor).opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - ProductionSectionHeader

/// Uppercase tracked section header with icon
public struct ProductionSectionHeader: View {
    let title: String
    let icon: String

    public init(icon: String, title: String) {
        self.icon = icon
        self.title = title
    }

    public var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundColor(.accentColor)
            Text(title)
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(.secondary)
                .tracking(1.2)
        }
    }
}

// MARK: - ProductionActionButton

/// Styled action button replacing .borderedProminent / .bordered
public struct ProductionActionButton: View {
    let icon: String
    let label: String
    let prominent: Bool
    let disabled: Bool
    let action: () -> Void

    @State private var isHovered = false

    public init(icon: String, _ label: String, prominent: Bool = false, disabled: Bool = false, action: @escaping () -> Void) {
        self.icon = icon
        self.label = label
        self.prominent = prominent
        self.disabled = disabled
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                Text(label)
                    .font(.system(size: 12, weight: .medium))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(buttonBackground)
            )
            .foregroundColor(buttonForeground)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.4 : 1.0)
        .onHover { hovering in
            isHovered = hovering
        }
    }

    private var buttonBackground: Color {
        if prominent {
            return isHovered ? Color.accentColor.opacity(0.9) : Color.accentColor.opacity(0.8)
        } else {
            return isHovered ? Color(nsColor: .quaternarySystemFill) : Color.clear
        }
    }

    private var buttonForeground: Color {
        if prominent {
            return .white
        } else {
            return .primary
        }
    }
}

// MARK: - ProductionChip

/// Tappable chip for filters, tabs, and selections
public struct ProductionChip: View {
    let label: String
    let icon: String?
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    public init(icon: String? = nil, _ label: String, selected: Bool, action: @escaping () -> Void) {
        self.icon = icon
        self.label = label
        self.isSelected = selected
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 10))
                }
                Text(label)
                    .font(.system(size: 10, weight: .medium))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(chipBackground)
            )
            .foregroundColor(chipForeground)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }

    private var chipBackground: Color {
        if isSelected {
            return .accentColor
        } else {
            return isHovered ? Color(nsColor: .quaternarySystemFill).opacity(0.8) : Color(nsColor: .quaternarySystemFill)
        }
    }

    private var chipForeground: Color {
        isSelected ? .white : .primary
    }
}

// MARK: - ProductionStatBadge

/// Bold stat value with label below
public struct ProductionStatBadge: View {
    let value: String
    let label: String
    let color: Color

    public init(value: String, label: String, color: Color = .accentColor) {
        self.value = value
        self.label = label
        self.color = color
    }

    public init(intValue: Int, label: String, color: Color = .accentColor) {
        self.value = "\(intValue)"
        self.label = label
        self.color = color
    }

    public init(currencyValue: Double, label: String, color: Color = .accentColor, currencyCode: String = "USD") {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        self.value = formatter.string(from: NSNumber(value: currencyValue)) ?? "$\(currencyValue)"
        self.label = label
        self.color = color
    }

    public var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .tracking(0.8)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(color.opacity(0.1))
        )
    }
}

// MARK: - ProductionSearchField

/// Styled search field with magnifying glass icon and clear button
public struct ProductionSearchField: View {
    @Binding var text: String

    public init(text: Binding<String>) {
        self._text = text
    }

    public var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            TextField("Search...", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .quaternarySystemFill))
        )
    }
}

// MARK: - ProductionListRow

/// Styled list row with hover highlight
public struct ProductionListRow<Leading: View, Trailing: View>: View {
    let isSelected: Bool
    @ViewBuilder let leading: () -> Leading
    @ViewBuilder let trailing: () -> Trailing

    @State private var isHovered = false

    public init(
        isSelected: Bool = false,
        @ViewBuilder leading: @escaping () -> Leading,
        @ViewBuilder trailing: @escaping () -> Trailing
    ) {
        self.isSelected = isSelected
        self.leading = leading
        self.trailing = trailing
    }

    public var body: some View {
        HStack(spacing: 12) {
            leading()
            Spacer()
            trailing()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(rowBackground)
        )
        .onHover { hovering in
            isHovered = hovering
        }
    }

    private var rowBackground: Color {
        if isSelected {
            return Color.accentColor.opacity(0.15)
        } else if isHovered {
            return Color(nsColor: .quaternarySystemFill)
        } else {
            return Color.clear
        }
    }
}

// MARK: - ProductionTabButton

/// Custom tab button with icon, label, and accent bottom line when selected
public struct ProductionTabButton: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    public init(icon: String, title: String, isSelected: Bool, action: @escaping () -> Void) {
        self.icon = icon
        self.title = title
        self.isSelected = isSelected
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.system(size: 12))
                    Text(title)
                        .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                }
                .foregroundColor(isSelected ? .accentColor : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isSelected ? Color.accentColor.opacity(0.1) : (isHovered ? Color(nsColor: .quaternarySystemFill) : Color.clear))
                )

                // Bottom accent line
                Rectangle()
                    .fill(isSelected ? Color.accentColor : Color.clear)
                    .frame(height: 2)
                    .padding(.horizontal, 8)
            }
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - StyledTextField

/// Production-styled text field with plain style + quaternarySystemFill background
public struct StyledTextField: View {
    let placeholder: String
    @Binding var text: String

    public init(_ placeholder: String, text: Binding<String>) {
        self.placeholder = placeholder
        self._text = text
    }

    public var body: some View {
        TextField(placeholder, text: $text)
            .textFieldStyle(.plain)
            .font(.system(size: 12))
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(nsColor: .quaternarySystemFill))
            )
    }
}

// MARK: - StyledNumberField

/// Production-styled number field
public struct StyledNumberField: View {
    let label: String
    @Binding var value: Double
    let format: String

    public init(_ label: String, value: Binding<Double>, format: String = "%.1f") {
        self.label = label
        self._value = value
        self.format = format
    }

    public var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
            Spacer()
            TextField("", value: $value, format: .number)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .multilineTextAlignment(.trailing)
                .frame(width: 80)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(nsColor: .quaternarySystemFill))
                )
        }
    }
}

// MARK: - InitialsAvatar

/// Circle avatar showing initials
public struct InitialsAvatar: View {
    let name: String
    let size: CGFloat
    let color: Color

    public init(name: String, size: CGFloat = 36, color: Color = .accentColor) {
        self.name = name
        self.size = size
        self.color = color
    }

    public var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.15))
                .frame(width: size, height: size)
            Text(initials)
                .font(.system(size: size * 0.35, weight: .semibold))
                .foregroundColor(color)
        }
    }

    private var initials: String {
        let components = name.components(separatedBy: " ")
        return components.prefix(2).compactMap { $0.first }.map(String.init).joined().uppercased()
    }
}

// MARK: - ProductionProgressBar

/// Styled progress bar
public struct ProductionProgressBar: View {
    let value: Double // 0.0 to 1.0
    let color: Color

    public init(value: Double, color: Color = .accentColor) {
        self.value = value
        self.color = color
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(nsColor: .quaternarySystemFill))

                RoundedRectangle(cornerRadius: 4)
                    .fill(color)
                    .frame(width: max(0, min(geometry.size.width * CGFloat(value), geometry.size.width)))
            }
        }
        .frame(height: 8)
    }
}

// MARK: - ProductionEditorHeader

/// Styled editor sheet header with title, cancel & save buttons
public struct ProductionEditorHeader: View {
    let title: String
    let canSave: Bool
    let onCancel: () -> Void
    let onSave: () -> Void

    public init(title: String, canSave: Bool = true, onCancel: @escaping () -> Void, onSave: @escaping () -> Void) {
        self.title = title
        self.canSave = canSave
        self.onCancel = onCancel
        self.onSave = onSave
    }

    public var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
            Spacer()
            Button("Cancel") { onCancel() }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
            ProductionActionButton(icon: "checkmark", "Save", prominent: true, disabled: !canSave) {
                onSave()
            }
        }
        .padding(16)
    }
}
