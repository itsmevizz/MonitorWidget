import DDCKit
import SwiftUI

/// Every control the keyboard can reach, in top-to-bottom order.
enum Control: Hashable {
    case brightness, contrast, volume, mute
    case red, green, blue, input

    var code: UInt8? {
        switch self {
        case .brightness: return VCP.brightness
        case .contrast: return VCP.contrast
        case .volume: return VCP.volume
        case .red: return VCP.redGain
        case .green: return VCP.greenGain
        case .blue: return VCP.blueGain
        case .mute, .input: return nil
        }
    }
}

struct ContentView: View {
    @ObservedObject var model: MonitorModel
    let onQuit: () -> Void

    @State private var newPresetName = ""
    @State private var pendingInput: UInt8?
    @State private var focus: Control? = .brightness
    @State private var unlocked = false
    @State private var pendingMode: UInt8?
    @AppStorage("modesExpanded") private var modesExpanded = false
    @FocusState private var panelFocused: Bool

    static let width: CGFloat = 340

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 12)

            Divider().opacity(0.5)

            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 16) {
                    if model.connected {
                        pictureCard
                        audioCard
                        modesCard
                        presetsCard
                        advancedCard
                    } else {
                        disconnectedCard
                    }
                }
                .padding(14)
            }

            Divider().opacity(0.5)
            footer
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
        }
        .frame(width: Self.width)
        .focusable()
        .focused($panelFocused)
        .focusEffectDisabled()
        .onKeyPress { handleKey($0) }
        .onAppear {
            panelFocused = true
            unlocked = false
            focus = orderedControls.first
        }
        .confirmationDialog(
            "Switch picture mode?",
            isPresented: Binding(get: { pendingMode != nil }, set: { if !$0 { pendingMode = nil } }),
            titleVisibility: .visible
        ) {
            Button("Switch to Mode \(hex(pendingMode ?? 0))") {
                if let mode = pendingMode { model.setPictureMode(mode) }
                pendingMode = nil
            }
            Button("Cancel", role: .cancel) { pendingMode = nil }
        } message: {
            Text("The monitor resets brightness and contrast for the new mode. The panel re-reads values afterwards.")
        }
        .confirmationDialog(
            "Switch input source?",
            isPresented: Binding(get: { pendingInput != nil }, set: { if !$0 { pendingInput = nil } }),
            titleVisibility: .visible
        ) {
            Button("Switch to \(VCP.inputNames[pendingInput ?? 0] ?? "input")") {
                if let source = pendingInput { model.setInput(source) }
                pendingInput = nil
            }
            Button("Cancel", role: .cancel) { pendingInput = nil }
        } message: {
            Text("If nothing is connected to that input the screen will go blank. Recover with the monitor's physical buttons.")
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(LinearGradient(colors: [.accentColor, .accentColor.opacity(0.55)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                Image(systemName: "display")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 3) {
                Text(model.displayName)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
                HStack(spacing: 5) {
                    Circle()
                        .fill(model.connected ? Color.green : Color.orange)
                        .frame(width: 6, height: 6)
                    Text(statusText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 8)

            if let percent = model.brightnessPercent {
                Text("\(percent)%")
                    .font(.system(size: 12, weight: .semibold).monospacedDigit())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.primary.opacity(0.07)))
                    .contentTransition(.numericText())
            }

            Button {
                model.refresh()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                    .symbolEffect(.variableColor.iterative, isActive: model.refreshing)
                    .frame(width: 26, height: 26)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Re-read all values from the monitor (R)")
            .disabled(!model.connected)
        }
    }

    private var statusText: String {
        if !model.connected { return "Not connected" }
        if model.refreshing { return "Reading settings…" }
        return "DDC/CI connected"
    }

    // MARK: - Cards

    private var pictureCard: some View {
        Card(title: "Picture") {
            VStack(spacing: 8) {
                if model.has(VCP.brightness) {
                    slider(.brightness, "Brightness", "sun.max.fill")
                }
                if model.has(VCP.contrast) {
                    slider(.contrast, "Contrast", "circle.lefthalf.filled")
                }
            }
        }
    }

    @ViewBuilder
    private var audioCard: some View {
        if model.has(VCP.volume) || model.has(VCP.mute) {
            Card(title: "Audio") {
                VStack(spacing: 8) {
                    if model.has(VCP.volume) {
                        slider(.volume, "Volume", "speaker.wave.2.fill")
                    }
                    if model.has(VCP.mute) {
                        ToggleRow(title: "Mute", symbol: "speaker.slash.fill", isOn: model.muted,
                                  isFocused: focus == .mute) { model.setMuted($0) }
                    }
                }
            }
        }
    }

    private var presetsCard: some View {
        Card(title: "Presets") {
            VStack(alignment: .leading, spacing: 10) {
                if model.presets.isEmpty {
                    Text("Save your favourite brightness, contrast and volume as a preset.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 6)], alignment: .leading, spacing: 6) {
                        ForEach(model.presets) { preset in
                            Button {
                                model.applyPreset(preset)
                            } label: {
                                Text(preset.name)
                                    .font(.system(size: 12, weight: .medium))
                                    .lineLimit(1)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 7)
                                    .padding(.horizontal, 8)
                                    .background(Capsule().fill(Color.accentColor.opacity(0.14)))
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button("Delete preset", role: .destructive) { model.deletePreset(preset) }
                            }
                            .help("Apply \(preset.name) · right-click to delete")
                        }
                    }
                }

                HStack(spacing: 6) {
                    TextField("Name this preset", text: $newPresetName)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Color.primary.opacity(0.05)))
                        .onSubmit(savePreset)
                    Button(action: savePreset) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(Color.accentColor)
                    }
                    .buttonStyle(.plain)
                    .disabled(newPresetName.trimmingCharacters(in: .whitespaces).isEmpty)
                    .help("Save current picture as preset")
                }
            }
        }
    }

    @ViewBuilder
    private var modesCard: some View {
        if !model.pictureModeOptions.isEmpty || !model.colorPresetOptions.isEmpty {
            DisclosureGroup(isExpanded: $modesExpanded) {
                VStack(alignment: .leading, spacing: 14) {
                    if !model.pictureModeOptions.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            modeLabel("Picture mode", "rectangle.3.group")
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 76), spacing: 6)], spacing: 6) {
                                ForEach(model.pictureModeOptions, id: \.self) { mode in
                                    ModeChip(title: "Mode \(hex(mode))", isSelected: model.pictureMode == mode) {
                                        if mode != model.pictureMode { pendingMode = mode }
                                    }
                                }
                            }
                        }
                    }

                    if !model.colorPresetOptions.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            modeLabel("Color user mode", "paintpalette")
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 76), spacing: 6)], spacing: 6) {
                                ForEach(model.colorPresetOptions, id: \.self) { preset in
                                    ModeChip(title: VCP.colorPresetNames[preset] ?? hex(preset), isSelected: model.colorPreset == preset) {
                                        model.setColorPreset(preset)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.top, 12)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "slider.horizontal.below.rectangle")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 18)
                    Text("Monitor user modes")
                        .font(.system(size: 13, weight: .semibold))
                    Spacer()
                }
                .contentShape(Rectangle())
                .onTapGesture { withAnimation(.easeInOut(duration: 0.2)) { modesExpanded.toggle() } }
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.primary.opacity(0.04)))
        }
    }

    private func modeLabel(_ title: String, _ symbol: String) -> some View {
        Label(title, systemImage: symbol)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
    }

    private func hex(_ value: UInt8) -> String {
        String(format: "0x%02X", value)
    }

    private var advancedCard: some View {
        Card(title: "Advanced") {
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: unlocked ? "lock.open.fill" : "lock.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(unlocked ? Color.orange : Color.secondary)
                        .frame(width: 18)
                    Text(unlocked ? "Unlocked — changes apply live" : "Locked to prevent accidental changes")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Toggle("", isOn: $unlocked)
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .labelsHidden()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.primary.opacity(0.04)))
                .onChange(of: unlocked) { _, _ in
                    if let f = focus, !orderedControls.contains(f) { focus = orderedControls.first }
                }

                if unlocked {
                    if model.has(VCP.redGain) { slider(.red, "Red gain", "circle.fill", tint: .red) }
                    if model.has(VCP.greenGain) { slider(.green, "Green gain", "circle.fill", tint: .green) }
                    if model.has(VCP.blueGain) { slider(.blue, "Blue gain", "circle.fill", tint: .blue) }
                    if !model.inputOptions.isEmpty { inputRow }
                }
            }
        }
    }

    private var disconnectedCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: "display.trianglebadge.exclamationmark")
                .font(.system(size: 28))
                .foregroundStyle(.orange)
            Text("No external monitor found")
                .font(.system(size: 14, weight: .semibold))
            Text("Connect the monitor over USB-C or DisplayPort, then retry. Its DDC/CI setting must be on.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button("Retry") { model.discover() }
                .controlSize(.regular)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.primary.opacity(0.04)))
    }

    // MARK: - Rows

    private func slider(_ control: Control, _ title: String, _ symbol: String, tint: Color = .accentColor) -> some View {
        let code = control.code ?? 0
        return ValueSlider(
            title: title,
            symbol: symbol,
            value: model.level(code),
            range: model.maxValue(code),
            tint: tint,
            isFocused: focus == control,
            isEnabled: unlocked || !Self.advancedControls.contains(control)
        ) { model.setLevel(code, $0) }
        .onTapGesture { focus = control }
    }

    private var inputRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "rectangle.on.rectangle")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 18)
            Text("Input")
                .font(.system(size: 13, weight: .medium))
            Spacer()
            Picker("Input", selection: Binding(
                get: { model.input },
                set: { if $0 != model.input { pendingInput = $0 } }
            )) {
                ForEach(model.inputOptions, id: \.self) { option in
                    Text(VCP.inputNames[option] ?? String(format: "0x%02X", option)).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(focus == .input ? Color.accentColor.opacity(0.12) : Color.primary.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(focus == .input ? Color.accentColor.opacity(0.7) : .clear, lineWidth: 1.5)
        )
        .onTapGesture { focus = .input }
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Toggle("Open at login", isOn: Binding(get: { model.launchAtLogin }, set: { model.setLaunchAtLogin($0) }))
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .font(.caption)
                Spacer()
                iconButton("moon.fill", help: "Sleep displays") { model.sleepDisplays() }
                iconButton("power", help: "Quit", tint: .red) { onQuit() }
            }
            Text("↑↓ select · ←→ adjust · ⇧ ±10 · Home/End min/max · M mute · R refresh")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
    }

    private func iconButton(_ symbol: String, help: String, tint: Color = .primary, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(tint)
                .frame(width: 28, height: 28)
                .background(Circle().fill(Color.primary.opacity(0.06)))
        }
        .buttonStyle(.plain)
        .help(help)
    }

    // MARK: - Keyboard

    static let advancedControls: Set<Control> = [.red, .green, .blue, .input]

    /// Controls the keyboard can reach right now (advanced ones only while unlocked).
    private var orderedControls: [Control] {
        guard model.connected else { return [] }
        var list: [Control] = []
        if model.has(VCP.brightness) { list.append(.brightness) }
        if model.has(VCP.contrast) { list.append(.contrast) }
        if model.has(VCP.volume) { list.append(.volume) }
        if model.has(VCP.mute) { list.append(.mute) }
        if unlocked {
            if model.has(VCP.redGain) { list.append(.red) }
            if model.has(VCP.greenGain) { list.append(.green) }
            if model.has(VCP.blueGain) { list.append(.blue) }
            if !model.inputOptions.isEmpty { list.append(.input) }
        }
        return list
    }

    private func handleKey(_ press: KeyPress) -> KeyPress.Result {
        guard model.connected else { return .ignored }
        let order = orderedControls
        guard !order.isEmpty else { return .ignored }
        if let f = focus, !order.contains(f) { focus = order.first }
        let step: Double = press.modifiers.contains(.shift) ? 10 : 1

        switch press.key {
        case .upArrow: moveFocus(by: -1, in: order)
        case .downArrow: moveFocus(by: 1, in: order)
        case .leftArrow: nudge(by: -step)
        case .rightArrow: nudge(by: step)
        case .home: jump(toMax: false)
        case .end: jump(toMax: true)
        case .space, .return:
            guard focus == .mute else { return .ignored }
            model.setMuted(!model.muted)
        default:
            switch press.characters.lowercased() {
            case "m": model.setMuted(!model.muted)
            case "r": model.refresh()
            default: return .ignored
            }
        }
        return .handled
    }

    private func moveFocus(by delta: Int, in order: [Control]) {
        guard let current = focus, let index = order.firstIndex(of: current) else {
            focus = order.first
            return
        }
        focus = order[min(max(index + delta, 0), order.count - 1)]
    }

    private func nudge(by delta: Double) {
        guard let control = focus else { return }
        switch control {
        case .mute:
            model.setMuted(delta > 0 ? false : true)
        case .input:
            guard let index = model.inputOptions.firstIndex(of: model.input) else { return }
            let next = min(max(index + (delta > 0 ? 1 : -1), 0), model.inputOptions.count - 1)
            if model.inputOptions[next] != model.input { pendingInput = model.inputOptions[next] }
        default:
            guard let code = control.code else { return }
            let value = min(max(model.level(code) + delta, 0), model.maxValue(code))
            model.setLevel(code, value)
        }
    }

    private func jump(toMax: Bool) {
        guard let control = focus else { return }
        switch control {
        case .mute:
            model.setMuted(toMax)
        case .input:
            return
        default:
            guard let code = control.code else { return }
            model.setLevel(code, toMax ? model.maxValue(code) : 0)
        }
    }

    private func savePreset() {
        let name = newPresetName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        model.savePreset(named: name)
        newPresetName = ""
    }
}
