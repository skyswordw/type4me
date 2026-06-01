import SwiftUI

// MARK: - Recording Sheet Target

struct RecordingTarget: Identifiable {
    let id: UUID
    let name: String
    let currentStyle: ProcessingMode.HotkeyStyle
}

// MARK: - Drop Delegate

struct ModeDropDelegate: DropDelegate {
    let targetId: UUID
    @Binding var modes: [ProcessingMode]
    @Binding var draggingId: UUID?
    let onReorder: () -> Void

    func performDrop(info: DropInfo) -> Bool {
        draggingId = nil
        return true
    }

    func dropEntered(info: DropInfo) {
        guard let dragId = draggingId,
              dragId != targetId,
              let fromIndex = modes.firstIndex(where: { $0.id == dragId }),
              let toIndex = modes.firstIndex(where: { $0.id == targetId })
        else { return }

        withAnimation(.easeInOut(duration: 0.2)) {
            modes.move(fromOffsets: IndexSet(integer: fromIndex), toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex)
        }
        onReorder()
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }
}

// MARK: - Hotkey Recording Sheet

struct HotkeyRecordingSheet: View {

    let target: RecordingTarget
    let checkConflict: (Int?, UInt64?) -> ProcessingMode?
    let onConfirm: (Int, UInt64?, ProcessingMode.HotkeyStyle) -> Void
    let onCancel: () -> Void

    @State private var capturedKeyCode: Int?
    @State private var capturedModifiers: UInt64?
    @State private var hotkeyStyle: ProcessingMode.HotkeyStyle
    @State private var isListening = true
    @State private var eventMonitor: Any?
    @State private var pendingModifierCode: Int?
    @State private var pendingModifierModifiers: UInt64 = 0
    @State private var modifierCaptureTask: Task<Void, Never>?

    init(
        target: RecordingTarget,
        checkConflict: @escaping (Int?, UInt64?) -> ProcessingMode?,
        onConfirm: @escaping (Int, UInt64?, ProcessingMode.HotkeyStyle) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.target = target
        self.checkConflict = checkConflict
        self.onConfirm = onConfirm
        self.onCancel = onCancel
        _hotkeyStyle = State(initialValue: target.currentStyle)
    }

    private var conflict: ProcessingMode? {
        checkConflict(capturedKeyCode, capturedModifiers)
    }

    var body: some View {
        VStack(spacing: 20) {
            Text(L("为「\(target.name)」录制快捷键", "Record hotkey for \"\(target.name)\""))
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(TF.settingsText)

            VStack(spacing: 6) {
                if isListening {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(TF.settingsAccentRed)
                            .frame(width: 8, height: 8)
                            .opacity(0.8)
                        Text(L("按下快捷键、鼠标或耳机按键...", "Press a key, mouse or headphone button..."))
                            .font(.system(size: 14))
                            .foregroundStyle(TF.settingsTextSecondary)
                    }
                } else if let code = capturedKeyCode {
                    Text(HotkeyRecorderView.keyDisplayName(keyCode: code, modifiers: capturedModifiers))
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(TF.settingsText)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 50)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(TF.settingsBg)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(
                        isListening ? TF.settingsAccentRed.opacity(0.4) : TF.settingsTextTertiary.opacity(0.2),
                        lineWidth: isListening ? 2 : 1
                    )
            )

            if let conflict {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                    Text(L("「\(conflict.name)」正在使用此快捷键，确认后将移除其绑定",
                           "\"\(conflict.name)\" is using this hotkey. Confirming will unbind it."))
                        .font(.system(size: 11))
                }
                .foregroundStyle(TF.settingsAccentAmber)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(L("触发方式", "Trigger style"))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(TF.settingsTextTertiary)

                HStack(spacing: 0) {
                    ForEach([ProcessingMode.HotkeyStyle.hold, .toggle], id: \.self) { style in
                        let selected = hotkeyStyle == style
                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) { hotkeyStyle = style }
                        } label: {
                            Text(style == .hold ? L("按住录制", "Hold to record") : L("按下切换", "Toggle"))
                                .font(.system(size: 11, weight: selected ? .semibold : .regular))
                                .foregroundStyle(selected ? .white : TF.settingsTextSecondary)
                                .frame(maxWidth: .infinity, minHeight: 26)
                                .background(
                                    RoundedRectangle(cornerRadius: 5)
                                        .fill(selected ? TF.settingsNavActive : .clear)
                                )
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(2)
                .background(
                    RoundedRectangle(cornerRadius: 7)
                        .fill(TF.settingsBg)
                )
            }

            if capturedKeyCode == 63 {
                Text(L(
                    "⚠️ 请在系统设置 → 键盘中，将「按下 🌐 键时」改为「不执行任何操作」，否则会与系统功能冲突",
                    "⚠️ Go to System Settings → Keyboard and set \"Press 🌐 key to\" to \"Do Nothing\" to avoid conflicts"
                ))
                .font(.system(size: 11))
                .foregroundStyle(.orange)
                .fixedSize(horizontal: false, vertical: true)
            }

            if let kc = capturedKeyCode, ModeBinding.isMediaKeyCode(kc) {
                let keyType = ModeBinding.mediaKeyType(from: kc)
                if keyType == 0 || keyType == 1 || keyType == 7 {
                    Text(L(
                        "⚠️ 绑定音量/静音键后，按下该键时系统音量将不会改变",
                        "⚠️ When volume/mute key is bound, pressing it will not change system volume"
                    ))
                    .font(.system(size: 11))
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: 12) {
                if !isListening && capturedKeyCode != nil {
                    Button(L("重录", "Re-record")) {
                        capturedKeyCode = nil
                        capturedModifiers = nil
                        isListening = true
                        startListening()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(TF.settingsTextSecondary)
                }

                Spacer()

                Button(L("取消", "Cancel")) {
                    cleanup()
                    onCancel()
                }
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(TF.settingsTextSecondary)

                Button(L("确认", "Confirm")) {
                    guard let code = capturedKeyCode else { return }
                    cleanup()
                    onConfirm(code, capturedModifiers, hotkeyStyle)
                }
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 5)
                .background(RoundedRectangle(cornerRadius: 6).fill(TF.settingsNavActive))
                .disabled(capturedKeyCode == nil)
                .opacity(capturedKeyCode == nil ? 0.5 : 1)
            }
        }
        .padding(28)
        .frame(width: 360)
        .onAppear {
            NotificationCenter.default.post(name: .hotkeyRecordingDidStart, object: nil)
            startListening()
        }
        .onDisappear {
            cleanup()
            NotificationCenter.default.post(name: .hotkeyRecordingDidEnd, object: nil)
        }
    }

    // MARK: - Key Event Monitoring

    private func startListening() {
        cleanup()
        isListening = true

        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged, .keyDown, .otherMouseDown, .systemDefined]) { event in
            // Media key (headphone buttons, keyboard media keys)
            if event.type == .systemDefined {
                guard event.subtype.rawValue == 8 else { return event }
                let keyType = Int((event.data1 >> 16) & 0xFFFF)
                let keyState = Int((event.data1 >> 8) & 0xFF)
                guard keyState == 0x0A else { return event }  // key down only
                guard HotkeyRecorderView.isKnownMediaKeyType(keyType) else { return event }

                modifierCaptureTask?.cancel()
                modifierCaptureTask = nil
                pendingModifierCode = nil

                capturedKeyCode = ModeBinding.mediaKeyCode(for: keyType)
                capturedModifiers = 0
                isListening = false
                removeMonitor()
                return nil
            }

            // Mouse button (middle click, side buttons)
            if event.type == .otherMouseDown {
                let buttonNumber = event.buttonNumber
                modifierCaptureTask?.cancel()
                modifierCaptureTask = nil
                pendingModifierCode = nil

                capturedKeyCode = ModeBinding.mouseKeyCode(for: buttonNumber)
                capturedModifiers = 0
                isListening = false
                removeMonitor()
                return nil
            }

            if event.type == .flagsChanged {
                let kc = Int(event.keyCode)
                guard HotkeyRecorderView.modifierKeyCodes.contains(kc) else { return event }
                let pressed = isModifierPressed(keyCode: kc, flags: event.modifierFlags)

                if pressed {
                    pendingModifierCode = kc
                    pendingModifierModifiers = modifierComboModifiers(for: kc, flags: event.modifierFlags)
                    modifierCaptureTask?.cancel()
                    modifierCaptureTask = Task {
                        try? await Task.sleep(for: .milliseconds(400))
                        guard !Task.isCancelled else { return }
                        await MainActor.run {
                            guard let pending = pendingModifierCode else { return }
                            captureModifierOnlyHotkey(pending, modifiers: pendingModifierModifiers)
                        }
                    }
                } else {
                    if let pending = pendingModifierCode {
                        modifierCaptureTask?.cancel()
                        modifierCaptureTask = nil
                        capturedKeyCode = pending
                        capturedModifiers = pendingModifierModifiers
                        pendingModifierCode = nil
                        pendingModifierModifiers = 0
                        isListening = false
                        removeMonitor()
                    }
                }
                return event
            }

            if event.type == .keyDown {
                let kc = Int(event.keyCode)
                modifierCaptureTask?.cancel()
                modifierCaptureTask = nil
                pendingModifierCode = nil

                if kc == 53 && event.modifierFlags.intersection(.deviceIndependentFlagsMask).subtracting([.capsLock, .numericPad, .function]).isEmpty {
                    cleanup()
                    onCancel()
                    return nil
                }

                capturedKeyCode = kc
                let clean = sanitizedModifierFlags(event.modifierFlags)
                capturedModifiers = clean.isEmpty ? 0 : UInt64(clean.rawValue)
                isListening = false
                removeMonitor()
                return nil
            }

            return event
        }
    }

    @MainActor
    private func captureModifierOnlyHotkey(_ keyCode: Int, modifiers: UInt64) {
        capturedKeyCode = keyCode
        capturedModifiers = modifiers
        pendingModifierCode = nil
        pendingModifierModifiers = 0
        isListening = false
        removeMonitor()
    }

    private func removeMonitor() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }

    private func cleanup() {
        modifierCaptureTask?.cancel()
        modifierCaptureTask = nil
        pendingModifierCode = nil
        pendingModifierModifiers = 0
        removeMonitor()
    }

    private func sanitizedModifierFlags(_ flags: NSEvent.ModifierFlags) -> NSEvent.ModifierFlags {
        flags.intersection([.command, .shift, .option, .control])
    }

    private func modifierFlag(for keyCode: Int) -> NSEvent.ModifierFlags? {
        switch keyCode {
        case 54, 55: return .command
        case 56, 60: return .shift
        case 58, 61: return .option
        case 59, 62: return .control
        default: return nil
        }
    }

    private func modifierComboModifiers(for keyCode: Int, flags: NSEvent.ModifierFlags) -> UInt64 {
        var clean = sanitizedModifierFlags(flags)
        if let own = modifierFlag(for: keyCode) {
            clean.remove(own)
        }
        return UInt64(clean.rawValue)
    }

    private func isModifierPressed(keyCode: Int, flags: NSEvent.ModifierFlags) -> Bool {
        if keyCode == 63 { return flags.contains(.function) }
        guard let flag = modifierFlag(for: keyCode) else { return false }
        return flags.contains(flag)
    }
}

// MARK: - Mode Detail Inner

struct ModeDetailInner: View {

    let mode: ProcessingMode
    let onSave: (ProcessingMode) -> Void

    @AppStorage("tf_shortTextExemption") private var shortTextExemption = "0"
    @State private var name = ""
    @State private var processingLabel = ""
    @State private var prompt = ""
    @State private var saveStatus: SaveStatus = .clean

    private enum SaveStatus: Equatable {
        case clean, dirty, saved
    }

    private var isDirty: Bool {
        name != mode.name || processingLabel != mode.processingLabel || prompt != mode.prompt
    }

    private let exemptionOptions: [(value: String, label: String)] = [
        ("0", L("关闭", "Off")),
        ("10", L("10 字以下", "Under 10 chars")),
        ("20", L("20 字以下", "Under 20 chars")),
        ("30", L("30 字以下", "Under 30 chars")),
        ("40", L("40 字以下", "Under 40 chars")),
        ("50", L("50 字以下", "Under 50 chars")),
    ]

    private var shortTextExemptionSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(L("短文本跳过", "Short Text Skip").uppercased())
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(TF.settingsTextTertiary)
            exemptionDropdown
            Text(L("文本少于该字数时跳过润色，直接使用识别结果",
                     "Skip polishing for texts shorter than this threshold"))
                .font(.system(size: 10))
                .foregroundStyle(TF.settingsTextTertiary)
        }
    }

    private var exemptionDropdown: some View {
        let currentLabel = exemptionOptions.first(where: { $0.value == shortTextExemption })?.label ?? shortTextExemption
        return Menu {
            ForEach(exemptionOptions, id: \.value) { option in
                Button {
                    shortTextExemption = option.value
                } label: {
                    if option.value == shortTextExemption {
                        Label(option.label, systemImage: "checkmark")
                    } else {
                        Text(option.label)
                    }
                }
            }
        } label: {
            HStack(spacing: 8) {
                Text(currentLabel)
                    .font(.system(size: 13))
                    .foregroundStyle(TF.settingsText)
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(TF.settingsTextTertiary)
            }
            .padding(.horizontal, 12)
            .frame(height: 36)
            .background(RoundedRectangle(cornerRadius: 8).fill(TF.settingsCardAlt))
        }
        .buttonStyle(.plain)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header + save
            HStack(spacing: 6) {
                Text(name.isEmpty ? L("新模式", "New Mode") : name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(TF.settingsText)

                Spacer()

                if saveStatus == .saved {
                    HStack(spacing: 4) {
                        Circle().fill(TF.settingsAccentGreen).frame(width: 6, height: 6)
                        Text(L("已保存", "Saved")).font(.system(size: 10)).foregroundStyle(TF.settingsAccentGreen)
                    }
                    .transition(.opacity)
                }
                Button(L("保存", "Save")) {
                    var updated = mode
                    updated.name = name
                    updated.processingLabel = processingLabel
                    updated.prompt = prompt
                    onSave(updated)
                    withAnimation { saveStatus = .saved }
                }
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 5)
                .background(RoundedRectangle(cornerRadius: 6).fill(
                    isDirty ? TF.settingsNavActive : TF.settingsTextTertiary
                ))
                .disabled(!isDirty)
            }

            // Name
            VStack(alignment: .leading, spacing: 4) {
                Text(L("名称", "Name"))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(TF.settingsTextTertiary)
                TextField(L("模式名称", "Mode name"), text: $name)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .padding(.horizontal, 12)
                    .frame(height: 36)
                    .background(RoundedRectangle(cornerRadius: 8).fill(TF.settingsCardAlt))
            }

            // Processing label
            VStack(alignment: .leading, spacing: 4) {
                Text(L("处理标签", "Processing label"))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(TF.settingsTextTertiary)
                TextField(L("处理中", "Processing"), text: $processingLabel)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .padding(.horizontal, 12)
                    .frame(height: 36)
                    .background(RoundedRectangle(cornerRadius: 8).fill(TF.settingsCardAlt))
                Text(L("处理进行时浮窗显示的文案，如「翻译中」「修正中」", "Text shown in the floating bar during processing, e.g. \"Translating\" \"Correcting\""))
                    .font(.system(size: 10))
                    .foregroundStyle(TF.settingsTextTertiary)
            }

            // Prompt
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(L("Prompt 模板", "Prompt Template"))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(TF.settingsTextTertiary)
                    Group {
                        Text("{text}") + Text("  ") + Text("{selected}") + Text("  ") + Text("{clipboard}")
                    }
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(TF.settingsTextTertiary.opacity(0.6))
                }
                AutoSizingTextEditor(text: $prompt)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 8).fill(TF.settingsCardAlt))
            }

            Spacer()
        }
        .onAppear { syncFields() }
        .onChange(of: mode.id) { syncFields() }
        .onChange(of: name) { _, _ in if saveStatus == .saved { saveStatus = .dirty } }
        .onChange(of: processingLabel) { _, _ in if saveStatus == .saved { saveStatus = .dirty } }
        .onChange(of: prompt) { _, _ in if saveStatus == .saved { saveStatus = .dirty } }
    }

    private func syncFields() {
        name = mode.name
        processingLabel = mode.processingLabel
        prompt = mode.prompt
        saveStatus = .clean
    }
}

// MARK: - Formal Writing Detail Inner

struct FormalWritingDetailInner: View {

    let mode: ProcessingMode
    @Binding var shortTextExemption: String
    let onSave: (ProcessingMode) -> Void

    @State private var name = ""
    @State private var processingLabel = ""
    @State private var prompt = ""
    @State private var saveStatus: SaveStatus = .clean
    @State private var promptBeforeUpdate: String?

    private enum SaveStatus: Equatable {
        case clean, dirty, saved
    }

    private var isDirty: Bool {
        name != mode.name || processingLabel != mode.processingLabel || prompt != mode.prompt
    }

    private var isLatestPrompt: Bool {
        prompt == ProcessingMode.formalWritingPromptTemplate
    }

    private let exemptionOptions: [(value: String, label: String)] = [
        ("0", L("关闭", "Off")),
        ("10", L("10 字以下", "Under 10 chars")),
        ("20", L("20 字以下", "Under 20 chars")),
        ("30", L("30 字以下", "Under 30 chars")),
        ("40", L("40 字以下", "Under 40 chars")),
        ("50", L("50 字以下", "Under 50 chars")),
    ]

    private var shortTextExemptionSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(L("短文本跳过", "Short Text Skip").uppercased())
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(TF.settingsTextTertiary)
            exemptionDropdown
            Text(L("文本少于该字数时跳过润色，直接使用识别结果",
                     "Skip polishing for texts shorter than this threshold"))
                .font(.system(size: 10))
                .foregroundStyle(TF.settingsTextTertiary)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header + actions
            HStack(spacing: 6) {
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 14))
                    .foregroundStyle(TF.settingsAccentAmber)
                Text(mode.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(TF.settingsText)
                Text(L("内置", "BUILT-IN"))
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(TF.settingsTextTertiary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(TF.settingsCardAlt))

                Spacer()

                if !isLatestPrompt {
                    Button {
                        promptBeforeUpdate = prompt
                        prompt = ProcessingMode.formalWritingPromptTemplate
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 9))
                            Text(L("还原为官方版", "Restore to official"))
                                .font(.system(size: 10))
                        }
                        .foregroundStyle(TF.settingsAccentBlue)
                    }
                    .buttonStyle(.plain)
                }

                if promptBeforeUpdate != nil {
                    Button {
                        prompt = promptBeforeUpdate!
                        promptBeforeUpdate = nil
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "arrow.uturn.backward")
                                .font(.system(size: 9))
                            Text(L("撤销", "Undo"))
                                .font(.system(size: 10))
                        }
                        .foregroundStyle(TF.settingsTextSecondary)
                    }
                    .buttonStyle(.plain)
                }

                if saveStatus == .saved {
                    HStack(spacing: 4) {
                        Circle().fill(TF.settingsAccentGreen).frame(width: 6, height: 6)
                        Text(L("已保存", "Saved")).font(.system(size: 10)).foregroundStyle(TF.settingsAccentGreen)
                    }
                    .transition(.opacity)
                }

                Button(L("保存", "Save")) {
                    var updated = mode
                    updated.name = name
                    updated.processingLabel = processingLabel
                    updated.prompt = prompt
                    onSave(updated)
                    promptBeforeUpdate = nil
                    withAnimation { saveStatus = .saved }
                }
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 5)
                .background(RoundedRectangle(cornerRadius: 6).fill(
                    isDirty ? TF.settingsNavActive : TF.settingsTextTertiary
                ))
                .disabled(!isDirty)
            }

            // Name
            VStack(alignment: .leading, spacing: 4) {
                Text(L("名称", "Name"))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(TF.settingsTextTertiary)
                TextField(L("模式名称", "Mode name"), text: $name)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .padding(.horizontal, 12)
                    .frame(height: 36)
                    .background(RoundedRectangle(cornerRadius: 8).fill(TF.settingsCardAlt))
            }

            // Processing label
            VStack(alignment: .leading, spacing: 4) {
                Text(L("处理标签", "Processing label"))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(TF.settingsTextTertiary)
                TextField(L("处理中", "Processing"), text: $processingLabel)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .padding(.horizontal, 12)
                    .frame(height: 36)
                    .background(RoundedRectangle(cornerRadius: 8).fill(TF.settingsCardAlt))
                Text(L("处理进行时浮窗显示的文案，如「翻译中」「修正中」",
                         "Text shown in the floating bar during processing"))
                    .font(.system(size: 10))
                    .foregroundStyle(TF.settingsTextTertiary)
            }

            // Short text exemption
            shortTextExemptionSection

            // Prompt 模板
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(L("Prompt 模板", "Prompt Template"))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(TF.settingsTextTertiary)
                    Group {
                        Text("{text}") + Text("  ") + Text("{selected}") + Text("  ") + Text("{clipboard}")
                    }
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(TF.settingsTextTertiary.opacity(0.6))
                }
                AutoSizingTextEditor(text: $prompt)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 8).fill(TF.settingsCardAlt))
            }

            Spacer()
        }
        .onAppear { syncFields() }
        .onChange(of: mode.id) { syncFields() }
        .onChange(of: name) { _, _ in if saveStatus == .saved { saveStatus = .dirty } }
        .onChange(of: processingLabel) { _, _ in if saveStatus == .saved { saveStatus = .dirty } }
        .onChange(of: prompt) { _, _ in if saveStatus == .saved { saveStatus = .dirty } }
    }

    private var exemptionDropdown: some View {
        let currentLabel = exemptionOptions.first(where: { $0.value == shortTextExemption })?.label ?? shortTextExemption
        return Menu {
            ForEach(exemptionOptions, id: \.value) { option in
                Button {
                    shortTextExemption = option.value
                } label: {
                    if option.value == shortTextExemption {
                        Label(option.label, systemImage: "checkmark")
                    } else {
                        Text(option.label)
                    }
                }
            }
        } label: {
            HStack(spacing: 8) {
                Text(currentLabel)
                    .font(.system(size: 13))
                    .foregroundStyle(TF.settingsText)
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(TF.settingsTextTertiary)
            }
            .padding(.horizontal, 12)
            .frame(height: 36)
            .background(RoundedRectangle(cornerRadius: 8).fill(TF.settingsCardAlt))
        }
        .buttonStyle(.plain)
    }

    private func syncFields() {
        name = mode.name
        processingLabel = mode.processingLabel
        prompt = mode.prompt
        saveStatus = .clean
    }
}

// MARK: - Auto-sizing TextEditor without scrollbars

struct AutoSizingTextEditor: View {
    @Binding var text: String
    @State private var height: CGFloat = 80

    var body: some View {
        AutoSizingTextEditorRep(text: $text, height: $height)
            .frame(height: max(80, height))
    }
}

private struct AutoSizingTextEditorRep: NSViewRepresentable {
    @Binding var text: String
    @Binding var height: CGFloat

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false

        let textView = NSTextView()
        textView.isRichText = false
        textView.allowsUndo = true
        textView.font = .systemFont(ofSize: 13)
        textView.textColor = NSColor(TF.settingsText)
        textView.backgroundColor = .clear
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.lineFragmentPadding = 0
        textView.delegate = context.coordinator
        textView.postsFrameChangedNotifications = true

        scrollView.documentView = textView
        context.coordinator.scrollView = scrollView

        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.frameDidChange),
            name: NSView.frameDidChangeNotification,
            object: textView
        )
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        // Sync text container width to scroll view's content width
        let availableWidth = scrollView.contentSize.width
        if availableWidth > 0 {
            textView.textContainer?.containerSize = NSSize(width: availableWidth, height: CGFloat.greatestFiniteMagnitude)
        }
        if textView.string != text {
            textView.string = text
            DispatchQueue.main.async { recalcHeight(textView) }
        }
    }

    private func recalcHeight(_ textView: NSTextView) {
        textView.layoutManager?.ensureLayout(for: textView.textContainer!)
        let newHeight = textView.layoutManager?.usedRect(for: textView.textContainer!).height ?? 80
        let padded = ceil(newHeight) + 8
        if abs(padded - height) > 1 { height = padded }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: AutoSizingTextEditorRep
        weak var scrollView: NSScrollView?
        init(_ parent: AutoSizingTextEditorRep) { self.parent = parent }

        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            parent.text = tv.string
            recalc(tv)
        }

        @objc func frameDidChange(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            recalc(tv)
        }

        private func recalc(_ textView: NSTextView) {
            textView.layoutManager?.ensureLayout(for: textView.textContainer!)
            let newHeight = textView.layoutManager?.usedRect(for: textView.textContainer!).height ?? 80
            let padded = ceil(newHeight) + 8
            if abs(padded - parent.height) > 1 {
                DispatchQueue.main.async { self.parent.height = padded }
            }
        }
    }
}
