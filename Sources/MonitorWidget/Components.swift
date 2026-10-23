import SwiftUI

/// Slider row with a drag track. Keyboard input is handled by the panel, which marks one row as focused.
struct ValueSlider: View {
    let title: String
    let symbol: String
    let value: Double
    let range: Double
    var tint: Color = .accentColor
    var isFocused = false
    var isEnabled = true
    let onChange: (Double) -> Void

    private var fraction: Double {
        guard range > 0 else { return 0 }
        return min(max(value / range, 0), 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 18)
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                Spacer()
                Text("\(Int(value))")
                    .font(.system(size: 13, weight: .semibold).monospacedDigit())
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.primary.opacity(0.10))
                    Capsule()
                        .fill(tint.gradient)
                        .frame(width: max(6, geo.size.width * fraction))
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { drag in
                            guard isEnabled, geo.size.width > 0 else { return }
                            let f = min(max(drag.location.x / geo.size.width, 0), 1)
                            onChange((f * range).rounded())
                        }
                )
            }
            .frame(height: 6)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isFocused ? tint.opacity(0.12) : Color.primary.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(isFocused ? tint.opacity(0.7) : .clear, lineWidth: 1.5)
        )
        .opacity(isEnabled ? 1 : 0.45)
        .animation(.easeOut(duration: 0.15), value: isFocused)
    }
}

/// Toggle row (mute) with the same card styling as the sliders.
struct ToggleRow: View {
    let title: String
    let symbol: String
    let isOn: Bool
    var tint: Color = .accentColor
    var isFocused = false
    let onChange: (Bool) -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 18)
            Text(title)
                .font(.system(size: 13, weight: .medium))
            Spacer()
            Toggle("", isOn: Binding(get: { isOn }, set: onChange))
                .toggleStyle(.switch)
                .controlSize(.small)
                .labelsHidden()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isFocused ? tint.opacity(0.12) : Color.primary.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(isFocused ? tint.opacity(0.7) : .clear, lineWidth: 1.5)
        )
        .animation(.easeOut(duration: 0.15), value: isFocused)
    }
}

/// Selectable chip for a monitor mode.
struct ModeChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .medium).monospacedDigit())
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .padding(.horizontal, 6)
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .background(
                    Capsule().fill(isSelected ? Color.accentColor : Color.primary.opacity(0.07))
                )
        }
        .buttonStyle(.plain)
        .help(isSelected ? "Current mode" : "Switch to \(title)")
    }
}

/// Titled group of controls.
struct Card<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
            content
        }
    }
}
